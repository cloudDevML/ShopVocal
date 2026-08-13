import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../dashboard/presentation/dashboard_state.dart';
import '../../inventory/presentation/inventory_state.dart';
import 'voice_state.dart';

class VoiceAssistantOverlay extends ConsumerStatefulWidget {
  const VoiceAssistantOverlay({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // Empêche la fermeture accidentelle par glissement
      isDismissible: true,
      builder: (context) => const VoiceAssistantOverlay(),
    );
  }

  @override
  ConsumerState<VoiceAssistantOverlay> createState() =>
      _VoiceAssistantOverlayState();
}

class _VoiceAssistantOverlayState extends ConsumerState<VoiceAssistantOverlay> {
  @override
  void initState() {
    super.initState();
    // Reset systématique à chaque ouverture du modal
    // pour ne pas afficher la transaction précédente
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(voiceProvider.notifier).clearLastAction();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(voiceProvider);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: MainContent(state: state, ref: ref),
    );
  }
}

class MainContent extends StatelessWidget {
  const MainContent({
    super.key,
    required this.state,
    required this.ref,
  });

  final VoiceState state;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Poignée supérieure du bottom sheet
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Titre de l'Assistant
        Text(
          'Assistant Vocal IA',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Dictez votre commande (ex: "J\'ai vendu 3 Coca à 3000 FCFA")',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 32),

        // Zone centrale changeante
        if (state.isProcessing) ...[
          const Center(
            child: Column(
              children: [
                CircularProgressIndicator(color: AppTheme.primaryColor),
                SizedBox(height: 16),
                Text(
                  'Transcription & Analyse IA en cours...',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ] else if (state.lastAction != null) ...[
          // Carte de confirmation du résultat de la transaction
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.successColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.check_circle, color: AppTheme.successColor),
                    SizedBox(width: 8),
                    Text(
                      'Transaction enregistrée !',
                      style: TextStyle(color: AppTheme.successColor, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const Divider(height: 24),
                if (state.lastAction?.description.isNotEmpty ?? false)
                  Text(
                    'Entendu : "${state.lastAction?.description}"',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
                  ),
                const SizedBox(height: 12),
                Text('Type : ${state.lastAction?.type == 'SALE' ? 'Vente' : state.lastAction?.type == 'PURCHASE' ? 'Achat Stock' : 'Dépense'}'),
                if (state.lastAction?.productName != null)
                  Text('Article : ${state.lastAction?.productName}'),
                if (state.lastAction?.quantity != null)
                  Text('Quantité : ${state.lastAction?.quantity?.toStringAsFixed(0)} unités'),
                Text(
                  'Montant : ${state.lastAction?.amount.toStringAsFixed(0)} FCFA',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (state.lastAction?.clientName != null)
                  Text('Client débiteur : ${state.lastAction?.clientName}'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Bouton : nouvelle commande sans fermer le modal
          OutlinedButton.icon(
            onPressed: () {
              ref.read(voiceProvider.notifier).clearLastAction();
            },
            icon: const Icon(Icons.mic),
            label: const Text('Nouvelle commande vocale'),
          ),
          const SizedBox(height: 8),
          // Bouton : terminer et fermer
          ElevatedButton(
            onPressed: () {
              ref.read(dashboardProvider.notifier).loadDashboard();
              ref.read(inventoryProvider.notifier).loadInventory();
              ref.read(voiceProvider.notifier).clearLastAction();
              Navigator.pop(context);
            },
            child: const Text('Terminer'),
          ),
        ] else ...[
          // Zone interactive d'enregistrement
          Center(
            child: GestureDetector(
              onTap: () {
                if (state.isRecording) {
                  ref.read(voiceProvider.notifier).stopRecording();
                } else {
                  ref.read(voiceProvider.notifier).startRecording();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: state.isRecording 
                      ? AppTheme.errorColor.withValues(alpha: 0.15) 
                      : AppTheme.primaryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: state.isRecording ? AppTheme.errorColor : AppTheme.primaryColor,
                    width: state.isRecording ? 4 : 2,
                  ),
                ),
                child: Icon(
                  state.isRecording ? Icons.stop : Icons.mic,
                  size: 56,
                  color: state.isRecording ? AppTheme.errorColor : AppTheme.primaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            state.isRecording ? 'Enregistrement en cours...\nAppuyez à nouveau pour arrêter.' : 'Appuyez pour commencer à parler',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: state.isRecording ? AppTheme.errorColor : Colors.grey,
              fontWeight: state.isRecording ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],

        if (state.errorMessage != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.errorColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              state.errorMessage!,
              style: const TextStyle(color: AppTheme.errorColor, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}
