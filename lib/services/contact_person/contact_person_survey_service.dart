// lib/services/contact_person/contact_person_survey_service.dart

import '../../utils/api_client.dart';
import '../../utils/api_config.dart';
import '../../models/survey/survey_models.dart';

class ContactPersonSurveyService {
  final ApiClient _apiClient = ApiClient();

  // Singleton pattern
  static final ContactPersonSurveyService _instance = ContactPersonSurveyService._internal();
  factory ContactPersonSurveyService() => _instance;
  ContactPersonSurveyService._internal();

  /// Get pending surveys for a patient
  Future<PendingSurveysResponse> getPendingSurveys(int patientId) async {
    try {
      final response = await _apiClient.get(
        ApiConfig.contactPersonPendingSurveysEndpoint(patientId),
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

  /// Get completed surveys for a patient
  Future<CompletedSurveysResponse> getCompletedSurveys(int patientId) async {
    try {
      final response = await _apiClient.get(
        ApiConfig.contactPersonCompletedSurveysEndpoint(patientId),
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

  /// Get survey details with questions
  Future<SurveyDetailsResponse> getSurveyDetails(int patientId, int responseId) async {
    try {
      final response = await _apiClient.get(
        ApiConfig.contactPersonSurveyDetailEndpoint(patientId, responseId),
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
    required int patientId,
    required int responseId,
    required List<SurveyAnswer> answers,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiConfig.contactPersonSubmitSurveyEndpoint(patientId, responseId),
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
}
