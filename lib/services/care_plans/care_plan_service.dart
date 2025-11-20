import 'dart:convert';
import '../../models/care_plans/care_plan_models.dart';
import '../../utils/api_client.dart';
import '../../utils/api_config.dart';

class CarePlanService {
  static final CarePlanService _instance = CarePlanService._internal();
  factory CarePlanService() => _instance;
  CarePlanService._internal();

  final _apiClient = ApiClient();


  Future<CarePlansResponse> getNurseCarePlans({
    String? search,
    String? status,
    String? priority,
    int? page,
    int? perPage,
  }) async {
    try {
      print('🌐 [CarePlanService] Fetching care plans...');
      print('📋 [CarePlanService] Params - search: $search, status: $status, priority: $priority, page: $page, perPage: $perPage');

      // Build query parameters
      final queryParams = <String, String>{};
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }
      if (priority != null && priority.isNotEmpty) {
        queryParams['priority'] = priority;
      }
      if (page != null) {
        queryParams['page'] = page.toString();
      }
      if (perPage != null) {
        queryParams['per_page'] = perPage.toString();
      }

      // Build URL with query parameters
      String url = ApiConfig.nurseCarePlansEndpoint;
      if (queryParams.isNotEmpty) {
        final queryString = queryParams.entries
            .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
            .join('&');
        url = '$url?$queryString';
      }

      print('🔗 [CarePlanService] GET Request URL: $url');

      // Make API request
      final response = await _apiClient.get(
        url,
        requiresAuth: true,
      );

      print('✅ [CarePlanService] Response received');
      print('📦 [CarePlanService] Response keys: ${response.keys.toList()}');

      // Parse response
      final carePlansResponse = CarePlansResponse.fromJson(response);
      
      print('✅ [CarePlanService] Parsed ${carePlansResponse.data.length} care plans');
      
      return carePlansResponse;
    } on ApiError catch (e) {
      print('❌ [CarePlanService] ApiError: ${e.message}');
      print('❌ [CarePlanService] Status Code: ${e.statusCode}');
      print('❌ [CarePlanService] Errors: ${e.errors}');
      
      throw CarePlanException(
        message: e.displayMessage,
        statusCode: e.statusCode,
        errors: e.errors,
      );
    } catch (e, stackTrace) {
      print('❌ [CarePlanService] Unexpected error: $e');
      print('❌ [CarePlanService] Stack trace: $stackTrace');
      
      throw CarePlanException(
        message: 'An unexpected error occurred: $e',
        statusCode: 0,
      );
    }
  }

  /// Create a new care plan
  Future<Map<String, dynamic>> createCarePlan({
    required int patientId,
    int? doctorId,
    int? careRequestId,  // ADD THIS PARAMETER
    required String title,
    required String description,
    required String careType,
    required String priority,
    required String startDate,
    String? endDate,
    required String frequency,
    required List<String> careTasks,
  }) async {
    try {
      print('🌐 [CarePlanService] Creating care plan...');
      
      // Transform values to backend format
      final transformedCareType = _transformCareType(careType);
      final transformedPriority = _transformPriority(priority);
      final transformedFrequency = _transformFrequency(frequency);

      print('📋 [CarePlanService] Original → Transformed values:');
      print('   - Care Type: "$careType" → "$transformedCareType"');
      print('   - Priority: "$priority" → "$transformedPriority"');
      print('   - Frequency: "$frequency" → "$transformedFrequency"');
      print('   - Care Request ID: $careRequestId');

      final request = CreateCarePlanRequest(
        patientId: patientId,
        doctorId: doctorId,
        careRequestId: careRequestId,  
        title: title,
        description: description,
        careType: transformedCareType,
        priority: transformedPriority,
        startDate: startDate,
        endDate: endDate,
        frequency: transformedFrequency,
        careTasks: careTasks,
      );

      final requestBody = request.toJson();
      print('📤 [CarePlanService] POST Request URL: ${ApiConfig.createCarePlanEndpoint}');
      print('📤 [CarePlanService] Request body: ${jsonEncode(requestBody)}');

      final response = await _apiClient.post(
        ApiConfig.createCarePlanEndpoint,  
        body: requestBody,
        requiresAuth: true,
      );

      print('✅ [CarePlanService] Care plan created successfully');
      print('📦 [CarePlanService] Response: ${jsonEncode(response)}');

      return response;
    } on ApiError catch (e) {
      print('❌ [CarePlanService] ApiError during creation: ${e.message}');
      print('❌ [CarePlanService] Status Code: ${e.statusCode}');
      print('❌ [CarePlanService] Errors: ${e.errors}');
      
      throw CarePlanException(
        message: e.displayMessage,
        statusCode: e.statusCode,
        errors: e.errors,
      );
    } catch (e, stackTrace) {
      print('❌ [CarePlanService] Unexpected error during creation: $e');
      print('❌ [CarePlanService] Stack trace: $stackTrace');
      
      throw CarePlanException(
        message: 'An unexpected error occurred: $e',
        statusCode: 0,
      );
    }
  }
  /// Update an existing care plan
  Future<dynamic> updateCarePlan({
    required int carePlanId,
    required int patientId,
    int? doctorId,
    int? careRequestId,
    required String title,
    required String description,
    required String careType,
    required String priority,
    required String startDate,
    String? endDate,
    required String frequency,
    required List<String> careTasks,
  }) async {
    try {
      print('🌐 [CarePlanService] Updating care plan ID: $carePlanId');
      
      // Transform values to backend format
      final transformedCareType = _transformCareType(careType);
      final transformedPriority = _transformPriority(priority);
      final transformedFrequency = _transformFrequency(frequency);

      print('📋 [CarePlanService] Transformed values:');
      print('   - Care Type: "$careType" → "$transformedCareType"');
      print('   - Priority: "$priority" → "$transformedPriority"');
      print('   - Frequency: "$frequency" → "$transformedFrequency"');

      final url = ApiConfig.updateCarePlanEndpoint(carePlanId);
      print('📤 [CarePlanService] PUT Request URL: $url');

      final response = await _apiClient.put(
        url,
        body: {
          'patient_id': patientId,
          'doctor_id': doctorId,
          if (careRequestId != null) 'care_request_id': careRequestId,
          'title': title,
          'description': description,
          'care_type': transformedCareType,
          'priority': transformedPriority,
          'start_date': startDate,
          if (endDate != null) 'end_date': endDate,
          'frequency': transformedFrequency,
          'care_tasks': careTasks,
        },
        requiresAuth: true,
      );

      print('✅ [CarePlanService] Care plan updated successfully');
      print('📦 [CarePlanService] Response: ${jsonEncode(response)}');

      return response;
    } on ApiError catch (e) {
      print('❌ [CarePlanService] ApiError during update: ${e.message}');
      print('❌ [CarePlanService] Status Code: ${e.statusCode}');
      print('❌ [CarePlanService] Errors: ${e.errors}');
      
      throw CarePlanException(
        message: e.displayMessage,
        statusCode: e.statusCode,
        errors: e.errors,
      );
    } catch (e, stackTrace) {
      print('❌ [CarePlanService] Unexpected error during update: $e');
      print('❌ [CarePlanService] Stack trace: $stackTrace');
      
      throw CarePlanException(
        message: 'Failed to update care plan: $e',
        statusCode: 0,
      );
    }
  }

  /// Get a specific care plan by ID
  Future<CarePlan> getCarePlanById(int id) async {
    try {
      print('🌐 [CarePlanService] Fetching care plan ID: $id');

      final url = ApiConfig.carePlanDetailEndpoint(id);
      print('🔗 [CarePlanService] GET Request URL: $url');

      final response = await _apiClient.get(
        url,
        requiresAuth: true,
      );

      print('✅ [CarePlanService] Care plan fetched successfully');

      final carePlan = CarePlan.fromJson(response['data'] as Map<String, dynamic>);
      return carePlan;
    } on ApiError catch (e) {
      print('❌ [CarePlanService] ApiError: ${e.message}');
      
      throw CarePlanException(
        message: e.displayMessage,
        statusCode: e.statusCode,
        errors: e.errors,
      );
    } catch (e, stackTrace) {
      print('❌ [CarePlanService] Unexpected error: $e');
      print('❌ [CarePlanService] Stack trace: $stackTrace');
      
      throw CarePlanException(
        message: 'An unexpected error occurred: $e',
        statusCode: 0,
      );
    }
  }



  /// Get available care requests for a patient
Future<List<Map<String, dynamic>>> getPatientCareRequests(int patientId) async {
  try {
    print('🌐 [CarePlanService] Fetching care requests for patient $patientId...');
    
    final url = '${ApiConfig.carePlanCareRequestsEndpoint}?patient_id=$patientId';
    
    final response = await _apiClient.get(url, requiresAuth: true);
    
    if (response['data'] is List) {
      final careRequests = List<Map<String, dynamic>>.from(response['data']);
      print('✅ [CarePlanService] Loaded ${careRequests.length} care requests');
      return careRequests;
    }
    
    return [];
  } catch (e) {
    print('❌ [CarePlanService] Error fetching care requests: $e');
    // Don't throw error, just return empty list
    return [];
  }
}

  /// Delete a care plan
  Future<Map<String, dynamic>> deleteCarePlan(int carePlanId) async {
    try {
      print('🌐 [CarePlanService] Deleting care plan ID: $carePlanId');

      final url = ApiConfig.deleteCarePlanEndpoint(carePlanId);
      print('📤 [CarePlanService] DELETE Request URL: $url');

      final response = await _apiClient.delete(
        url,
        requiresAuth: true,
      );

      print('✅ [CarePlanService] Care plan deleted successfully');
      return response;
    } on ApiError catch (e) {
      print('❌ [CarePlanService] ApiError during deletion: ${e.message}');
      
      throw CarePlanException(
        message: e.displayMessage,
        statusCode: e.statusCode,
        errors: e.errors,
      );
    } catch (e, stackTrace) {
      print('❌ [CarePlanService] Unexpected error during deletion: $e');
      
      throw CarePlanException(
        message: 'Failed to delete care plan: $e',
        statusCode: 0,
      );
    }
  }

  /// Toggle care task completion status
  /// This method allows nurses to mark tasks as complete/incomplete
  Future<Map<String, dynamic>> toggleCareTaskCompletion({
    required int carePlanId,
    required int taskIndex,
    required bool isCompleted,
  }) async {
    try {
      print('🌐 [CarePlanService] Toggling task completion...');
      print('📋 [CarePlanService] Care Plan ID: $carePlanId');
      print('📋 [CarePlanService] Task Index: $taskIndex');
      print('📋 [CarePlanService] Is Completed: $isCompleted');

      final url = ApiConfig.toggleCareTaskEndpoint(carePlanId);
      
      final requestBody = {
        'task_index': taskIndex,
        'is_completed': isCompleted,
      };

      print('📤 [CarePlanService] POST Request URL: $url');
      print('📤 [CarePlanService] Request body: ${jsonEncode(requestBody)}');

      final response = await _apiClient.post(
        url,
        body: requestBody,
        requiresAuth: true,
      );

      print('✅ [CarePlanService] Task toggle successful');
      print('📦 [CarePlanService] Response: ${jsonEncode(response)}');

      return response;
    } on ApiError catch (e) {
      print('❌ [CarePlanService] ApiError during task toggle: ${e.message}');
      print('❌ [CarePlanService] Status Code: ${e.statusCode}');
      print('❌ [CarePlanService] Errors: ${e.errors}');
      
      throw CarePlanException(
        message: e.displayMessage,
        statusCode: e.statusCode,
        errors: e.errors,
      );
    } catch (e, stackTrace) {
      print('❌ [CarePlanService] Unexpected error during task toggle: $e');
      print('❌ [CarePlanService] Stack trace: $stackTrace');
      
      throw CarePlanException(
        message: 'Failed to update task: $e',
        statusCode: 0,
      );
    }
  }

  // ==================== TRANSFORMATION METHODS ====================
  
  /// Transform care type from UI format to backend format
  /// Examples:
  ///   "General Care" → "general_care"
  ///   "Elderly Care" → "elderly_care"
  ///   "Post-Surgery Care" → "post_surgery_care"
  ///   "Pediatric Care" → "pediatric_care"
  ///   "Chronic Disease Management" → "chronic_disease_management"
  ///   "Palliative Care" → "palliative_care"
  ///   "Rehabilitation Care" → "rehabilitation_care"
  String _transformCareType(String careType) {
    if (careType.isEmpty) return '';
    
    return careType
        .toLowerCase()           // "Elderly Care" → "elderly care"
        .trim()                  // Remove any extra spaces
        .replaceAll(RegExp(r'\s+'), '_')  // "elderly care" → "elderly_care"
        .replaceAll('-', '_');   // Handle any hyphens
  }

  /// Transform priority from UI format to backend format
  /// Examples:
  ///   "Low" → "low"
  ///   "Medium" → "medium"
  ///   "High" → "high"
  String _transformPriority(String priority) {
    if (priority.isEmpty) return '';
    
    return priority.toLowerCase().trim();
  }

  /// Transform frequency from UI format to backend format
  /// Note: Backend has inconsistent naming (uses both hyphens and underscores)
  /// Examples:
  ///   "Daily" → "daily"
  ///   "Weekly" → "weekly"
  ///   "Bi-weekly" → "bi-weekly" (special case - backend uses hyphen!)
  ///   "Monthly" → "monthly"
  ///   "As Needed" → "as_needed" (special case - backend uses underscore!)
  String _transformFrequency(String frequency) {
    if (frequency.isEmpty) return '';
    
    final normalized = frequency.toLowerCase().trim();
    
    // Handle special cases that don't follow the pattern
    switch (normalized) {
      case 'bi-weekly':
      case 'bi weekly':
      case 'biweekly':
        return 'bi-weekly';  // Backend expects hyphen for this one
        
      case 'as needed':
      case 'as-needed':
      case 'asneeded':
        return 'as_needed';  // Backend expects underscore for this one
        
      // Regular cases (daily, weekly, monthly)
      default:
        return normalized.replaceAll(RegExp(r'\s+'), '_').replaceAll('-', '_');
    }
  }

  /// Get all doctors for care plan assignment
  Future<List<Map<String, dynamic>>> getDoctors({String? search}) async {
    try {
      print('🌐 [CarePlanService] Fetching doctors...');
      
      String url = ApiConfig.carePlanDoctorsEndpoint;
      if (search != null && search.isNotEmpty) {
        url = '$url?search=${Uri.encodeComponent(search)}';
      }
      
      final response = await _apiClient.get(url, requiresAuth: true);
      
      if (response['data'] is List) {
        return List<Map<String, dynamic>>.from(response['data']);
      }
      
      return [];
    } catch (e) {
      print('❌ [CarePlanService] Error fetching doctors: $e');
      throw CarePlanException(
        message: 'Failed to fetch doctors',
        statusCode: 0,
      );
    }
  }

  /// Get all patients for care plan assignment
  Future<List<Map<String, dynamic>>> getPatients({String? search}) async {
    try {
      print('🌐 [CarePlanService] Fetching patients...');
      
      String url = ApiConfig.carePlanPatientsEndpoint;
      if (search != null && search.isNotEmpty) {
        url = '$url?search=${Uri.encodeComponent(search)}';
      }
      
      final response = await _apiClient.get(url, requiresAuth: true);
      
      if (response['data'] is List) {
        return List<Map<String, dynamic>>.from(response['data']);
      }
      
      return [];
    } catch (e) {
      print('❌ [CarePlanService] Error fetching patients: $e');
      throw CarePlanException(
        message: 'Failed to fetch patients',
        statusCode: 0,
      );
    }
  }
}