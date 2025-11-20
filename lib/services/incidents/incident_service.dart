import '../../models/incidents/incident_report_models.dart';
import '../../utils/api_client.dart';
import '../../utils/api_config.dart';

class IncidentService {
  static final IncidentService _instance = IncidentService._internal();
  factory IncidentService() => _instance;
  IncidentService._internal();

  final _apiClient = ApiClient();

  /// Get all incident reports (with optional filters)
  /// 
  /// [page] - The page number to fetch (starts from 1)
  /// [perPage] - Number of items per page (sent to backend)
  /// [status] - Filter by status: 'pending', 'under_review', 'resolved', or null for all
  /// [patientId] - Filter by specific patient ID
  /// [search] - Search query for incident description, location, or patient name
  Future<IncidentListResponse> getIncidents({
    int page = 1,
    int perPage = 15, // Changed default to match screen
    String? status,
    int? patientId,
    String? search,
  }) async {
    try {
      // Build query parameters
      final queryParams = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(), // Always send per_page to backend
      };

      // Add optional filters
      if (status != null && status != 'all') {
        queryParams['status'] = status;
      }
      
      if (patientId != null) {
        queryParams['patient_id'] = patientId.toString();
      }
      
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      // Build query string with proper URL encoding
      final queryString = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');

      // Make API request
      final response = await _apiClient.get(
        '${ApiConfig.incidentsEndpoint}?$queryString',
        requiresAuth: true,
      );

      // DEBUG: Log the raw response to verify pagination data
      print('🔍 Raw API Response:');
      print('  - success: ${response['success']}');
      print('  - total: ${response['total']}');
      print('  - current_page: ${response['current_page']}');
      print('  - last_page: ${response['last_page']}');
      print('  - data length: ${(response['data'] as List?)?.length ?? 0}');

      return IncidentListResponse.fromJson(response);
      
    } on ApiError catch (e) {
      // Return error response with proper structure
      return IncidentListResponse(
        success: false,
        message: e.displayMessage,
        data: [],
        total: 0,
        currentPage: page,
        lastPage: 1,
        counts: null,
      );
    } catch (e) {
      // Handle unexpected errors
      return IncidentListResponse(
        success: false,
        message: 'Failed to fetch incident reports',
        data: [],
        total: 0,
        currentPage: page,
        lastPage: 1,
        counts: null,
      );
    }
  }

  /// Create a new incident report
  Future<IncidentResponse> createIncident(CreateIncidentRequest request) async {
    try {
      final response = await _apiClient.post(
        ApiConfig.incidentsEndpoint,
        body: request.toJson(),
        requiresAuth: true,
      );

      return IncidentResponse.fromJson(response);
      
    } on ApiError catch (e) {
      return IncidentResponse(
        success: false,
        message: e.displayMessage,
        errors: e.errors,
      );
    } catch (e) {
      return IncidentResponse(
        success: false,
        message: 'Failed to create incident report',
      );
    }
  }


  /// Get patients for incident reporting (dropdown)
  Future<List<PatientOption>> getPatientsForIncident() async {
    try {
      final response = await _apiClient.get(
        '${ApiConfig.incidentsPatientEndpoint}',
        requiresAuth: true,
      );

      if (response['success'] == true && response['data'] != null) {
              print('🔍 Raw API Response For Incident list:');
      print('  - success: ${response['success']}');
        final patients = response['data'] as List<dynamic>;
        return patients
            .map((p) => PatientOption.fromJson(p as Map<String, dynamic>))
            .toList();
      }

      return [];
    } catch (e) {
      return [];
    }
  }
}