// lib/services/survey_service.dart

import '../utils/api_client.dart';
import '../utils/api_config.dart';
import '../models/survey/survey_models.dart';

class SurveyService {
  final ApiClient _apiClient = ApiClient();

  // Singleton pattern
  static final SurveyService _instance = SurveyService._internal();
  factory SurveyService() => _instance;
  SurveyService._internal();

  /// Get pending surveys for the patient
  Future<PendingSurveysResponse> getPendingSurveys() async {
    try {
      final response = await _apiClient.get(
        ApiConfig.pendingSurveysEndpoint,
        requiresAuth: true,
      );
      return PendingSurveysResponse.fromJson(response);
    } catch (e) {
      return PendingSurveysResponse(
        success: false,
        surveys: [],
        total: 0,
        message: e.toString(),
      );
    }
  }

  /// Get survey details with questions
  Future<SurveyDetailsResponse> getSurveyDetails(int responseId) async {
    try {
      final response = await _apiClient.get(
        ApiConfig.surveyDetailEndpoint(responseId),
        requiresAuth: true,
      );
      return SurveyDetailsResponse.fromJson(response);
    } catch (e) {
      return SurveyDetailsResponse(
        success: false,
        details: null,
        message: e.toString(),
      );
    }
  }

  /// Submit survey answers
  Future<SurveySubmitResponse> submitSurvey({
    required int responseId,
    required List<SurveyAnswer> answers,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiConfig.submitSurveyEndpoint(responseId),
        body: {
          'answers': answers.map((a) => a.toJson()).toList(),
        },
        requiresAuth: true,
      );
      return SurveySubmitResponse.fromJson(response);
    } catch (e) {
      return SurveySubmitResponse(
        success: false,
        message: e.toString(),
      );
    }
  }

  /// Get completed surveys history
  Future<CompletedSurveysResponse> getCompletedSurveys() async {
    try {
      final response = await _apiClient.get(
        ApiConfig.completedSurveysEndpoint,
        requiresAuth: true,
      );
      return CompletedSurveysResponse.fromJson(response);
    } catch (e) {
      return CompletedSurveysResponse(
        success: false,
        surveys: [],
        message: e.toString(),
      );
    }
  }
}
