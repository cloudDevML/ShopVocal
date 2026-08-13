import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/network/api_client.dart';
import '../data/voice_models.dart';
import '../data/voice_repository.dart';

final voiceRepositoryProvider = Provider<VoiceRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return VoiceRepository(apiClient);
});

// Sentinel pour distinguer "param non fourni" de "param = null"
const _absent = Object();

class VoiceState {
  final bool isRecording;
  final bool isProcessing;
  final String? recordingPath;
  final AiActionModel? lastAction;
  final String? errorMessage;

  VoiceState({
    this.isRecording = false,
    this.isProcessing = false,
    this.recordingPath,
    this.lastAction,
    this.errorMessage,
  });

  VoiceState copyWith({
    bool? isRecording,
    bool? isProcessing,
    Object? recordingPath = _absent,
    Object? lastAction = _absent,
    Object? errorMessage = _absent,
  }) {
    return VoiceState(
      isRecording: isRecording ?? this.isRecording,
      isProcessing: isProcessing ?? this.isProcessing,
      // Si le param vaut _absent (non fourni), on garde l'ancienne valeur
      // Si le param vaut null (fourni explicitement), on efface
      recordingPath: identical(recordingPath, _absent)
          ? this.recordingPath
          : recordingPath as String?,
      lastAction: identical(lastAction, _absent)
          ? this.lastAction
          : lastAction as AiActionModel?,
      errorMessage: identical(errorMessage, _absent)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class VoiceNotifier extends StateNotifier<VoiceState> {
  final VoiceRepository _repository;
  final AudioRecorder _audioRecorder = AudioRecorder();

  VoiceNotifier(this._repository) : super(VoiceState());

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> startRecording() async {
    state = state.copyWith(errorMessage: null);
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        state = state.copyWith(errorMessage: "Permission de microphone refusée.");
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/voice_command.m4a';

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );

      state = state.copyWith(isRecording: true, recordingPath: path);
    } catch (e) {
      state = state.copyWith(isRecording: false, errorMessage: "Impossible de démarrer l'enregistrement: $e");
    }
  }

  Future<void> stopRecording() async {
    if (!state.isRecording) return;
    try {
      final path = await _audioRecorder.stop();
      state = state.copyWith(isRecording: false);

      if (path != null) {
        await processAudioCommand(path);
      }
    } catch (e) {
      state = state.copyWith(isRecording: false, errorMessage: "Erreur lors de l'arrêt de l'enregistrement: $e");
    }
  }

  Future<void> processAudioCommand(String path) async {
    state = state.copyWith(isProcessing: true, errorMessage: null, lastAction: null);
    try {
      final action = await _repository.sendAudioCommand(path);
      state = state.copyWith(isProcessing: false, lastAction: action);
    } catch (e) {
      state = state.copyWith(isProcessing: false, errorMessage: _translateError(e));
    }
  }

  String _translateError(Object e) {
    final raw = e.toString();

    // Extraire le message "detail" de la réponse JSON du backend (erreurs Dio)
    final detailMatch = RegExp(r'"detail"\s*:\s*"([^"]+)"').firstMatch(raw);
    if (detailMatch != null) {
      return '⚠️ ${detailMatch.group(1)}';
    }

    // Erreurs réseau
    if (raw.contains('receive timeout') || raw.contains('timed out')) {
      return '⏱️ Le serveur a mis trop longtemps à répondre. Réessayez dans un instant.';
    }
    if (raw.contains('SocketException') || raw.contains('connection refused') ||
        raw.contains('Connection refused')) {
      return '🌐 Impossible de joindre le serveur. Vérifiez que le backend est démarré.';
    }
    if (raw.contains('NetworkException') || raw.contains('connection')) {
      return '🌐 Problème de connexion réseau. Vérifiez le Wi-Fi.';
    }

    // Erreurs quota / crédits
    if (raw.contains('quota') || raw.contains('402') || raw.contains('429')) {
      return '💳 Service IA temporairement indisponible. Un mode de secours est actif.';
    }

    // Erreurs audio
    if (raw.contains('transcription') || raw.contains('audio')) {
      return '🎤 Problème de transcription audio. Parlez plus clairement et réessayez.';
    }

    // Stock insuffisant (message du serveur)
    if (raw.contains('Stock insuffisant') || raw.contains('stock')) {
      return '📦 $raw';
    }

    // Fallback : message brut raccourci
    if (raw.length > 120) return '❌ ${raw.substring(0, 120)}…';
    return '❌ $raw';
  }

  Future<void> processTextCommand(String text) async {
    state = VoiceState(isProcessing: true);
    try {
      final action = await _repository.sendTextCommand(text);
      state = state.copyWith(isProcessing: false, lastAction: action);
    } catch (e) {
      state = state.copyWith(isProcessing: false, errorMessage: e.toString());
    }
  }

  void clearLastAction() {
    // Recrée un état complètement vierge — évite tout résidu
    state = VoiceState();
  }
}

final voiceProvider = StateNotifierProvider<VoiceNotifier, VoiceState>((ref) {
  final repository = ref.watch(voiceRepositoryProvider);
  return VoiceNotifier(repository);
});
