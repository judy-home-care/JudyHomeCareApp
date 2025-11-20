import '../utils/api_client.dart';

class TimeTrackingService {
  static final TimeTrackingService _instance = TimeTrackingService._internal();
  factory TimeTrackingService() => _instance;
  TimeTrackingService._internal();

  final _apiClient = ApiClient();

  /// Clock in for a specific schedule
  /// 
  /// UPDATED: schedule_id is now in the request body instead of URL
  Future<Map<String, dynamic>> clockIn({
    required int scheduleId,
    String? location,
    double? latitude,
    double? longitude,
    String? deviceInfo,
  }) async {
    try {
      final body = <String, dynamic>{
        'schedule_id': scheduleId, // ✅ CHANGED: Now in body instead of URL
      };
      
      if (location != null) body['location'] = location;
      if (latitude != null) body['latitude'] = latitude;
      if (longitude != null) body['longitude'] = longitude;
      if (deviceInfo != null) body['device_info'] = deviceInfo;

      final response = await _apiClient.post(
        '/api/mobile/nurse/time-tracking/clock-in', // ✅ CHANGED: Removed /schedules/$scheduleId
        body: body,
        requiresAuth: true,
      );

      return response;
    } on ApiError catch (e) {
      return {
        'success': false,
        'message': e.displayMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to clock in. Please try again.',
      };
    }
  }

  /// Clock out from active session
  Future<Map<String, dynamic>> clockOut({
    String? location,
    double? latitude,
    double? longitude,
    String? workNotes,
    List<String>? activitiesPerformed,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (location != null) body['location'] = location;
      if (latitude != null) body['latitude'] = latitude;
      if (longitude != null) body['longitude'] = longitude;
      if (workNotes != null) body['work_notes'] = workNotes;
      if (activitiesPerformed != null) body['activities_performed'] = activitiesPerformed;

      final response = await _apiClient.post(
        '/api/mobile/nurse/time-tracking/clock-out',
        body: body,
        requiresAuth: true,
      );

      return response;
    } on ApiError catch (e) {
      return {
        'success': false,
        'message': e.displayMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to clock out. Please try again.',
      };
    }
  }

  /// Get active time tracking session
  Future<Map<String, dynamic>?> getActiveSession() async {
    try {
      final response = await _apiClient.get(
        '/api/mobile/nurse/time-tracking/active',
        requiresAuth: true,
      );

      if (response['success'] == true) {
        return response['data'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Pause active session
  Future<Map<String, dynamic>> pauseSession({String? reason}) async {
    try {
      final body = <String, dynamic>{};
      if (reason != null) body['reason'] = reason;

      final response = await _apiClient.post(
        '/api/mobile/nurse/time-tracking/pause',
        body: body,
        requiresAuth: true,
      );

      return response;
    } on ApiError catch (e) {
      return {
        'success': false,
        'message': e.displayMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to pause session. Please try again.',
      };
    }
  }

  /// Resume paused session
  Future<Map<String, dynamic>> resumeSession() async {
    try {
      final response = await _apiClient.post(
        '/api/mobile/nurse/time-tracking/resume',
        requiresAuth: true,
      );

      return response;
    } on ApiError catch (e) {
      return {
        'success': false,
        'message': e.displayMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to resume session. Please try again.',
      };
    }
  }

  /// Get time logs with filters and pagination
  /// 
  /// Parameters:
  /// - [status]: Filter by status ('completed', 'in_progress', or null for all)
  /// - [startDate]: Filter logs starting from this date (format: 'YYYY-MM-DD')
  /// - [endDate]: Filter logs up to this date (format: 'YYYY-MM-DD')
  /// - [period]: Quick filter for time periods ('today', 'week', 'month', or 'all')
  /// - [sort]: Sort order ('newest', 'oldest', 'longest', 'shortest')
  /// - [page]: Page number for pagination (default: 1)
  /// - [perPage]: Number of items per page (default: 10)
  Future<Map<String, dynamic>> getTimeLogs({
    String? status,
    String? startDate,
    String? endDate,
    String? period,
    String? sort,
    int page = 1,
    int perPage = 10,
  }) async {
    try {
      // Build query string
      final queryParams = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };

      if (status != null && status != 'all') {
        queryParams['status'] = status;
      }
      if (startDate != null) {
        queryParams['start_date'] = startDate;
      }
      if (endDate != null) {
        queryParams['end_date'] = endDate;
      }
      if (period != null && period != 'all') {
        queryParams['period'] = period;
      }
      if (sort != null) {
        queryParams['sort'] = sort;
      }

      // Convert query params to URL query string
      String queryString = '';
      if (queryParams.isNotEmpty) {
        queryString = '?' + queryParams.entries
            .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
            .join('&');
      }

      print('🔗 [TimeTrackingService] GET Request: /api/mobile/nurse/time-tracking/logs$queryString');

      final response = await _apiClient.get(
        '/api/mobile/nurse/time-tracking/logs$queryString',
        requiresAuth: true,
      );

      print('✅ [TimeTrackingService] Response received');
      print('📊 [TimeTrackingService] Data count: ${(response['data'] as List?)?.length ?? 0}');
      
      if (response['pagination'] != null) {
        final pagination = response['pagination'] as Map<String, dynamic>;
        print('📄 [TimeTrackingService] Pagination: Page ${pagination['current_page']} of ${pagination['last_page']} (Total: ${pagination['total']})');
      }

      return response;
    } on ApiError catch (e) {
      print('❌ [TimeTrackingService] ApiError: ${e.message}');
      return {
        'success': false,
        'message': e.displayMessage,
      };
    } catch (e) {
      print('❌ [TimeTrackingService] Unexpected error: $e');
      return {
        'success': false,
        'message': 'Failed to fetch time logs. Please try again.',
      };
    }
  }
}