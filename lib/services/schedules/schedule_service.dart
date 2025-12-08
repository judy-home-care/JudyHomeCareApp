import '../../models/schedules/schedule_models.dart';
import '../../utils/api_client.dart';
import '../../utils/api_config.dart';

class ScheduleException implements Exception {
  final String message;
  final Map<String, dynamic>? errors;
  final int statusCode;

  ScheduleException({
    required this.message,
    this.errors,
    required this.statusCode,
  });

  @override
  String toString() => message;
}

class ScheduleService {
  static final ScheduleService _instance = ScheduleService._internal();
  factory ScheduleService() => _instance;
  ScheduleService._internal();

  final _apiClient = ApiClient();

  /// Get schedules for the authenticated nurse
  Future<NurseScheduleResponse> getNurseSchedules({
    String? status,
    String? shiftType,
    String? startDate,
    String? endDate,
    String? search,
  }) async {
    try {
      final queryParams = <String, String>{};
      
      if (status != null && status != 'all') {
        queryParams['status'] = status;
      }
      
      if (shiftType != null && shiftType != 'All Shifts') {
        queryParams['shift_type'] = shiftType;
      }
      
      if (startDate != null) {
        queryParams['start_date'] = startDate;
      }
      
      if (endDate != null) {
        queryParams['end_date'] = endDate;
      }
      
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final endpoint = ApiConfig.nurseSchedulesEndpoint;
      final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      final fullUri = uri.replace(queryParameters: queryParams);

      final response = await _apiClient.get(
        fullUri.toString().replaceFirst(ApiConfig.baseUrl, ''),
        requiresAuth: true,
      );

      return NurseScheduleResponse.fromJson(response);
    } on ApiError catch (e) {
      throw ScheduleException(
        message: e.displayMessage,
        errors: e.errors,
        statusCode: e.statusCode,
      );
    } catch (e) {
      throw ScheduleException(
        message: 'An unexpected error occurred. Please try again.',
        statusCode: 0,
      );
    }
  }

    /// Request a reschedule for a schedule (Patient only)
  ///
  /// API Body format:
  /// - Single period: {"reason": "...", "preferred_date": "2025-12-15", "preferred_time": "Morning", "additional_notes": "..."}
  /// - Multi-period: adds "preferred_end_date": "2025-12-20" (must be >= preferred_date)
  Future<RescheduleRequestResponse> requestReschedule({
    required int scheduleId,
    required String reason,
    String? preferredDate,
    String? preferredEndDate,
    String? preferredTime,
    String? additionalNotes,
  }) async {
    try {
      final body = <String, dynamic>{
        'reason': reason,
      };

      if (preferredDate != null) {
        body['preferred_date'] = preferredDate;
      }
      if (preferredEndDate != null) {
        body['preferred_end_date'] = preferredEndDate;
      }
      if (preferredTime != null) {
        body['preferred_time'] = preferredTime;
      }
      if (additionalNotes != null && additionalNotes.isNotEmpty) {
        body['additional_notes'] = additionalNotes;
      }

      final response = await _apiClient.post(
        ApiConfig.scheduleRescheduleRequestEndpoint(scheduleId),
        body: body,
        requiresAuth: true,
      );

      return RescheduleRequestResponse.fromJson(response);
    } on ApiError catch (e) {
      throw ScheduleException(
        message: e.displayMessage,
        errors: e.errors,
        statusCode: e.statusCode,
      );
    } catch (e) {
      throw ScheduleException(
        message: 'Failed to submit reschedule request. Please try again.',
        statusCode: 0,
      );
    }
  }
}

/// Response model for reschedule request
class RescheduleRequestResponse {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;

  RescheduleRequestResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory RescheduleRequestResponse.fromJson(Map<String, dynamic> json) {
    return RescheduleRequestResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'],
    );
  }
}