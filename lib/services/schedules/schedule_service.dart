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
}