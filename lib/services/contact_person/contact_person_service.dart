import 'package:flutter/foundation.dart';
import '../../models/contact_person/contact_person_models.dart';
import '../../models/dashboard/patient_dashboard_models.dart';
import '../../models/care_plans/care_plan_models.dart';
import '../../models/schedules/schedule_models.dart';
import '../../models/care_request/care_request_models.dart';
import '../../models/progress_notes/progress_note_models.dart';
import '../../utils/api_client.dart';
import '../../utils/api_config.dart';
import '../../utils/secure_storage.dart';

class ContactPersonService {
  final ApiClient _apiClient = ApiClient();
  final SecureStorage _secureStorage = SecureStorage();

  /// Get current selected patient ID
  Future<int> _getPatientId() async {
    final patientId = await _secureStorage.getSelectedPatientId();
    if (patientId == null) {
      throw Exception('No patient selected');
    }
    return patientId;
  }

  // ==================== PATIENT ACCESS ====================

  /// Get list of linked patients
  Future<List<LinkedPatient>> getLinkedPatients() async {
    try {
      debugPrint('[ContactPersonService] Fetching linked patients...');

      final response = await _apiClient.get(
        ApiConfig.contactPersonPatientsEndpoint,
      );

      final data = response['data'] ?? response['patients'] ?? [];
      final patients = (data as List)
          .map((p) => LinkedPatient.fromJson(p))
          .toList();

      debugPrint('[ContactPersonService] Found ${patients.length} linked patients');
      return patients;
    } catch (e) {
      debugPrint('[ContactPersonService] Error fetching patients: $e');
      rethrow;
    }
  }

  /// Get specific patient details
  Future<PatientDetail> getPatientDetail(int patientId) async {
    try {
      debugPrint('[ContactPersonService] Fetching patient $patientId details...');

      final response = await _apiClient.get(
        ApiConfig.contactPersonPatientDetailEndpoint(patientId),
      );

      return PatientDetail.fromJson(response['data'] ?? response);
    } catch (e) {
      debugPrint('[ContactPersonService] Error fetching patient detail: $e');
      rethrow;
    }
  }

  /// Get patient dashboard
  Future<PatientDashboardData> getPatientDashboard(int patientId) async {
    try {
      debugPrint('[ContactPersonService] Fetching dashboard for patient $patientId...');

      final response = await _apiClient.get(
        ApiConfig.contactPersonPatientDashboardEndpoint(patientId),
      );

      return PatientDashboardData.fromJson(response['data'] ?? response);
    } catch (e) {
      debugPrint('[ContactPersonService] Error fetching dashboard: $e');
      rethrow;
    }
  }

  // ==================== CARE PLANS ====================

  /// Get care plans for patient
  Future<List<CarePlan>> getCarePlans({int? page, int? perPage}) async {
    try {
      final patientId = await _getPatientId();
      debugPrint('[ContactPersonService] Fetching care plans for patient $patientId...');

      String endpoint = ApiConfig.contactPersonCarePlansEndpoint(patientId);
      if (page != null || perPage != null) {
        final queryParams = <String>[];
        if (page != null) queryParams.add('page=$page');
        if (perPage != null) queryParams.add('per_page=$perPage');
        endpoint += '?${queryParams.join('&')}';
      }

      final response = await _apiClient.get(endpoint);

      final data = response['data'] ?? response['carePlans'] ?? [];
      return (data as List).map((p) => CarePlan.fromJson(p)).toList();
    } catch (e) {
      debugPrint('[ContactPersonService] Error fetching care plans: $e');
      rethrow;
    }
  }

  /// Get care plan detail
  Future<CarePlan> getCarePlanDetail(int carePlanId) async {
    try {
      final patientId = await _getPatientId();
      debugPrint('[ContactPersonService] Fetching care plan $carePlanId...');

      final response = await _apiClient.get(
        ApiConfig.contactPersonCarePlanDetailEndpoint(patientId, carePlanId),
      );

      return CarePlan.fromJson(response['data'] ?? response);
    } catch (e) {
      debugPrint('[ContactPersonService] Error fetching care plan: $e');
      rethrow;
    }
  }

  /// Get care plan entries
  Future<List<CarePlanEntry>> getCarePlanEntries(int carePlanId) async {
    try {
      final patientId = await _getPatientId();
      debugPrint('[ContactPersonService] Fetching entries for care plan $carePlanId...');

      final response = await _apiClient.get(
        ApiConfig.contactPersonCarePlanEntriesEndpoint(patientId, carePlanId),
      );

      final data = response['data'] ?? response['entries'] ?? [];
      return (data as List).map((e) => CarePlanEntry.fromJson(e)).toList();
    } catch (e) {
      debugPrint('[ContactPersonService] Error fetching care plan entries: $e');
      rethrow;
    }
  }

  // ==================== SCHEDULES ====================

  /// Get schedules
  Future<List<ScheduleItem>> getSchedules({String? date, String? status}) async {
    try {
      final patientId = await _getPatientId();
      debugPrint('[ContactPersonService] Fetching schedules for patient $patientId...');

      String endpoint = ApiConfig.contactPersonSchedulesEndpoint(patientId);
      final queryParams = <String>[];
      if (date != null) queryParams.add('date=$date');
      if (status != null) queryParams.add('status=$status');
      if (queryParams.isNotEmpty) {
        endpoint += '?${queryParams.join('&')}';
      }

      final response = await _apiClient.get(endpoint);

      final data = response['data'] ?? response['schedules'] ?? [];
      return (data as List).map((s) => ScheduleItem.fromJson(s)).toList();
    } catch (e) {
      debugPrint('[ContactPersonService] Error fetching schedules: $e');
      rethrow;
    }
  }

  /// Request reschedule
  ///
  /// API Body format:
  /// - Single period: {"reason": "...", "preferred_date": "2025-12-15", "preferred_time": "Morning", "additional_notes": "..."}
  /// - Multi-period: adds "preferred_end_date": "2025-12-20" (must be >= preferred_date)
  Future<Map<String, dynamic>> requestReschedule({
    required int scheduleId,
    required String reason,
    String? preferredDate,
    String? preferredEndDate,
    String? preferredTime,
    String? additionalNotes,
  }) async {
    try {
      final patientId = await _getPatientId();
      debugPrint('[ContactPersonService] Requesting reschedule for schedule $scheduleId...');

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
        ApiConfig.contactPersonRequestRescheduleEndpoint(patientId, scheduleId),
        body: body,
        requiresAuth: true,
      );

      return response;
    } catch (e) {
      debugPrint('[ContactPersonService] Error requesting reschedule: $e');
      rethrow;
    }
  }

  // ==================== CARE REQUESTS ====================

  /// Get care request info
  Future<CareRequestInfo> getCareRequestInfo() async {
    try {
      final patientId = await _getPatientId();
      debugPrint('[ContactPersonService] Fetching care request info...');

      final response = await _apiClient.get(
        ApiConfig.contactPersonCareRequestInfoEndpoint(patientId),
      );

      return CareRequestInfo.fromJson(response['data'] ?? response);
    } catch (e) {
      debugPrint('[ContactPersonService] Error fetching care request info: $e');
      rethrow;
    }
  }

  /// Get care requests
  Future<List<CareRequest>> getCareRequests({String? status}) async {
    try {
      final patientId = await _getPatientId();
      debugPrint('[ContactPersonService] Fetching care requests...');

      String endpoint = ApiConfig.contactPersonCareRequestsEndpoint(patientId);
      if (status != null) {
        endpoint += '?status=$status';
      }

      final response = await _apiClient.get(endpoint);

      final data = response['data'] ?? response['careRequests'] ?? [];
      return (data as List).map((r) => CareRequest.fromJson(r)).toList();
    } catch (e) {
      debugPrint('[ContactPersonService] Error fetching care requests: $e');
      rethrow;
    }
  }

  /// Create care request
  Future<CareRequest> createCareRequest(Map<String, dynamic> data) async {
    try {
      final patientId = await _getPatientId();
      debugPrint('[ContactPersonService] Creating care request...');

      final response = await _apiClient.post(
        ApiConfig.contactPersonCareRequestsEndpoint(patientId),
        body: data,
        requiresAuth: true,
      );

      return CareRequest.fromJson(response['data'] ?? response);
    } catch (e) {
      debugPrint('[ContactPersonService] Error creating care request: $e');
      rethrow;
    }
  }

  /// Cancel care request
  Future<Map<String, dynamic>> cancelCareRequest(int requestId, String reason) async {
    try {
      final patientId = await _getPatientId();
      debugPrint('[ContactPersonService] Cancelling care request $requestId...');

      final response = await _apiClient.post(
        ApiConfig.contactPersonCancelCareRequestEndpoint(patientId, requestId),
        body: {'reason': reason},
        requiresAuth: true,
      );

      return response;
    } catch (e) {
      debugPrint('[ContactPersonService] Error cancelling care request: $e');
      rethrow;
    }
  }

  /// Initiate payment
  Future<Map<String, dynamic>> initiatePayment(int requestId) async {
    try {
      final patientId = await _getPatientId();
      debugPrint('[ContactPersonService] Initiating payment for request $requestId...');

      final response = await _apiClient.post(
        ApiConfig.contactPersonInitiatePaymentEndpoint(patientId, requestId),
        requiresAuth: true,
      );

      return response;
    } catch (e) {
      debugPrint('[ContactPersonService] Error initiating payment: $e');
      rethrow;
    }
  }

  /// Verify payment
  Future<Map<String, dynamic>> verifyPayment(String reference) async {
    try {
      final patientId = await _getPatientId();
      debugPrint('[ContactPersonService] Verifying payment $reference...');

      final response = await _apiClient.post(
        ApiConfig.contactPersonVerifyPaymentEndpoint(patientId),
        body: {'reference': reference},
        requiresAuth: true,
      );

      return response;
    } catch (e) {
      debugPrint('[ContactPersonService] Error verifying payment: $e');
      rethrow;
    }
  }

  // ==================== TRANSPORT REQUESTS ====================

  /// Get transport requests
  Future<List<dynamic>> getTransportRequests() async {
    try {
      final patientId = await _getPatientId();
      debugPrint('[ContactPersonService] Fetching transport requests...');

      final response = await _apiClient.get(
        ApiConfig.contactPersonTransportRequestsEndpoint(patientId),
      );

      return response['data'] ?? response['transportRequests'] ?? [];
    } catch (e) {
      debugPrint('[ContactPersonService] Error fetching transport requests: $e');
      rethrow;
    }
  }

  /// Create transport request
  Future<Map<String, dynamic>> createTransportRequest(Map<String, dynamic> data) async {
    try {
      final patientId = await _getPatientId();
      debugPrint('[ContactPersonService] Creating transport request...');

      final response = await _apiClient.post(
        ApiConfig.contactPersonTransportRequestsEndpoint(patientId),
        body: data,
        requiresAuth: true,
      );

      return response;
    } catch (e) {
      debugPrint('[ContactPersonService] Error creating transport request: $e');
      rethrow;
    }
  }

  /// Get available drivers
  Future<List<dynamic>> getAvailableDrivers() async {
    try {
      final patientId = await _getPatientId();
      debugPrint('[ContactPersonService] Fetching available drivers...');

      final response = await _apiClient.get(
        ApiConfig.contactPersonAvailableDriversEndpoint(patientId),
      );

      return response['data'] ?? response['drivers'] ?? [];
    } catch (e) {
      debugPrint('[ContactPersonService] Error fetching drivers: $e');
      rethrow;
    }
  }

  // ==================== FEEDBACK ====================

  /// Get feedback list
  Future<List<dynamic>> getFeedbackList() async {
    try {
      final patientId = await _getPatientId();
      debugPrint('[ContactPersonService] Fetching feedback...');

      final response = await _apiClient.get(
        ApiConfig.contactPersonFeedbackEndpoint(patientId),
      );

      return response['data'] ?? response['feedback'] ?? [];
    } catch (e) {
      debugPrint('[ContactPersonService] Error fetching feedback: $e');
      rethrow;
    }
  }

  /// Submit feedback
  Future<Map<String, dynamic>> submitFeedback(Map<String, dynamic> data) async {
    try {
      final patientId = await _getPatientId();
      debugPrint('[ContactPersonService] Submitting feedback...');

      final response = await _apiClient.post(
        ApiConfig.contactPersonFeedbackEndpoint(patientId),
        body: data,
        requiresAuth: true,
      );

      return response;
    } catch (e) {
      debugPrint('[ContactPersonService] Error submitting feedback: $e');
      rethrow;
    }
  }

  /// Get nurses for feedback
  Future<List<dynamic>> getNursesForFeedback() async {
    try {
      final patientId = await _getPatientId();
      debugPrint('[ContactPersonService] Fetching nurses for feedback...');

      final response = await _apiClient.get(
        ApiConfig.contactPersonFeedbackNursesEndpoint(patientId),
      );

      return response['data'] ?? response['nurses'] ?? [];
    } catch (e) {
      debugPrint('[ContactPersonService] Error fetching nurses: $e');
      rethrow;
    }
  }

  /// Get feedback statistics
  Future<Map<String, dynamic>> getFeedbackStatistics() async {
    try {
      final patientId = await _getPatientId();
      debugPrint('[ContactPersonService] Fetching feedback statistics...');

      final response = await _apiClient.get(
        ApiConfig.contactPersonFeedbackStatisticsEndpoint(patientId),
      );

      return response['data'] ?? response;
    } catch (e) {
      debugPrint('[ContactPersonService] Error fetching statistics: $e');
      rethrow;
    }
  }

  // ==================== PROGRESS NOTES ====================

  /// Get progress notes
  Future<List<dynamic>> getProgressNotes() async {
    try {
      final patientId = await _getPatientId();
      debugPrint('[ContactPersonService] Fetching progress notes...');

      final response = await _apiClient.get(
        ApiConfig.contactPersonProgressNotesEndpoint(patientId),
      );

      return response['data'] ?? response['progressNotes'] ?? [];
    } catch (e) {
      debugPrint('[ContactPersonService] Error fetching progress notes: $e');
      rethrow;
    }
  }

  /// Get progress note by ID
  Future<ProgressNoteDetailResponse> getProgressNoteById(int noteId) async {
    try {
      final patientId = await _getPatientId();
      debugPrint('[ContactPersonService] Fetching progress note $noteId...');
      debugPrint('[ContactPersonService] Endpoint: ${ApiConfig.contactPersonProgressNoteDetailEndpoint(patientId, noteId)}');

      final response = await _apiClient.get(
        ApiConfig.contactPersonProgressNoteDetailEndpoint(patientId, noteId),
      );

      debugPrint('[ContactPersonService] Response received: ${response.runtimeType}');
      debugPrint('[ContactPersonService] Success: ${response['success']}');

      if (response['success'] == true) {
        debugPrint('[ContactPersonService] Parsing progress note detail...');
        return ProgressNoteDetailResponse.fromJson(response);
      } else {
        debugPrint('[ContactPersonService] API returned success=false: ${response['message']}');
        throw Exception(response['message'] ?? 'Failed to fetch progress note');
      }
    } catch (e) {
      debugPrint('[ContactPersonService] Error fetching progress note: $e');
      rethrow;
    }
  }
}
