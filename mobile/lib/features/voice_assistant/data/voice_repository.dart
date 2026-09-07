import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import 'voice_models.dart';

class VoiceRepository {
  final ApiClient _apiClient;

  VoiceRepository(this._apiClient);

  Future<AiActionModel> sendTextCommand(String text) async {
    final response = await _apiClient.post(
      ApiEndpoints.textToAction,
      data: {'text': text},
    );
    return AiActionModel.fromJson(response.data);
  }

  Future<AiActionModel> sendAudioCommand(String audioPath) async {
    final fileName = audioPath.split('/').last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        audioPath,
        filename: fileName,
      ),
    });

    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.voiceToAction,
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        ),
      );
      return AiActionModel.fromJson(response.data);
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['detail'] != null) {
        throw Exception(data['detail'].toString());
      }
      throw Exception(e.message ?? 'Erreur lors de l’envoi du fichier audio.');
    }
  }
}
