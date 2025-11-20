import '../../utils/api_client.dart';
import '../../utils/api_config.dart';

class PatientFeedbackService {
  static final PatientFeedbackService _instance = PatientFeedbackService._internal();
  factory PatientFeedbackService() => _instance;
  PatientFeedbackService._internal();

  final _apiClient = ApiClient();

  /// Get all feedback submitted by the patient
  Future<Map<String, dynamic>> getFeedbackList() async {
    try {
      final response = await _apiClient.get(
        ApiConfig.getFeedbackListEndpoint,
        requiresAuth: true,
      );

      if (response is! Map<String, dynamic>) {
        throw FeedbackException(
          message: 'Invalid response type',
          statusCode: 0,
        );
      }

      if (!response.containsKey('success')) {
        throw FeedbackException(
          message: 'Response missing "success" field',
          statusCode: 0,
        );
      }

      return {
        'success': response['success'],
        'data': response['data'] ?? [],
        'total': response['total'] ?? 0,
      };

    } on ApiError catch (e) {
      throw FeedbackException(
        message: e.displayMessage,
        statusCode: e.statusCode,
      );
    } on FeedbackException {
      rethrow;
    } catch (e) {
      throw FeedbackException(
        message: 'Failed to fetch feedback. Please try again.',
        statusCode: 0,
      );
    }
  }

  /// Get nurses that can be rated
  Future<Map<String, dynamic>> getNursesForFeedback() async {
    try {
      final response = await _apiClient.get(
        ApiConfig.getNursesForFeedbackEndpoint,
        requiresAuth: true,
      );

      if (response is! Map<String, dynamic>) {
        throw FeedbackException(
          message: 'Invalid response type',
          statusCode: 0,
        );
      }

      if (!response.containsKey('success')) {
        throw FeedbackException(
          message: 'Response missing "success" field',
          statusCode: 0,
        );
      }

      return {
        'success': response['success'],
        'nurses': response['data'] ?? [],
        'total': response['total'] ?? 0,
      };

    } on ApiError catch (e) {
      throw FeedbackException(
        message: e.displayMessage,
        statusCode: e.statusCode,
      );
    } on FeedbackException {
      rethrow;
    } catch (e) {
      throw FeedbackException(
        message: 'Failed to fetch nurses. Please try again.',
        statusCode: 0,
      );
    }
  }

  /// Submit feedback for a nurse
  Future<Map<String, dynamic>> submitFeedback({
    required int nurseId,
    int? scheduleId,
    required int rating,
    required String feedbackText,
    required bool wouldRecommend,
    String? careDate,
  }) async {
    try {
      final body = {
        'nurse_id': nurseId,
        'rating': rating,
        'feedback_text': feedbackText,
        'would_recommend': wouldRecommend,
        if (scheduleId != null) 'schedule_id': scheduleId,
        if (careDate != null) 'care_date': careDate,
      };

      final response = await _apiClient.post(
        ApiConfig.submitFeedbackEndpoint,
        body: body,
        requiresAuth: true,
      );

      if (response is! Map<String, dynamic>) {
        throw FeedbackException(
          message: 'Invalid response type',
          statusCode: 0,
        );
      }

      return {
        'success': response['success'] ?? false,
        'message': response['message'] ?? 'Feedback submitted successfully',
        'data': response['data'],
      };

    } on ApiError catch (e) {
      throw FeedbackException(
        message: e.displayMessage,
        statusCode: e.statusCode,
      );
    } on FeedbackException {
      rethrow;
    } catch (e) {
      throw FeedbackException(
        message: 'Failed to submit feedback. Please try again.',
        statusCode: 0,
      );
    }
  }

  /// Get feedback statistics
  Future<Map<String, dynamic>> getFeedbackStatistics() async {
    try {
      final response = await _apiClient.get(
        ApiConfig.getFeedbackStatisticsEndpoint,
        requiresAuth: true,
      );

      if (response is! Map<String, dynamic>) {
        throw FeedbackException(
          message: 'Invalid response type',
          statusCode: 0,
        );
      }

      if (!response.containsKey('success')) {
        throw FeedbackException(
          message: 'Response missing "success" field',
          statusCode: 0,
        );
      }

      return {
        'success': response['success'],
        'data': response['data'],
      };

    } on ApiError catch (e) {
      throw FeedbackException(
        message: e.displayMessage,
        statusCode: e.statusCode,
      );
    } on FeedbackException {
      rethrow;
    } catch (e) {
      throw FeedbackException(
        message: 'Failed to fetch statistics. Please try again.',
        statusCode: 0,
      );
    }
  }
}

/// Custom exception for feedback operations
class FeedbackException implements Exception {
  final String message;
  final int statusCode;

  FeedbackException({
    required this.message,
    required this.statusCode,
  });

  @override
  String toString() => message;
}