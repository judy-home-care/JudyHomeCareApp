import '../../models/dashboard/nurse_dashboard_models.dart';
import '../../models/dashboard/patient_dashboard_models.dart';
import '../../utils/api_client.dart';
import '../../utils/api_config.dart';

class DashboardService {
  static final DashboardService _instance = DashboardService._internal();
  factory DashboardService() => _instance;
  DashboardService._internal();

  final _apiClient = ApiClient();

  /// Get nurse mobile dashboard
  Future<NurseDashboardData> getNurseMobileDashboard() async {
    try {
      final response = await _apiClient.get(
        ApiConfig.nurseMobileDashboardEndpoint,
        requiresAuth: true,
      );

      if (response['success'] == true && response['data'] != null) {
        return NurseDashboardData.fromJson(response['data']);
      } else {
        throw Exception('Failed to load dashboard data');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get patient mobile dashboard
  Future<PatientDashboardData> getPatientMobileDashboard() async {
    try {
      final response = await _apiClient.get(
        ApiConfig.patientMobileDashboardEndpoint,
        requiresAuth: true,
      );

      if (response['success'] == true && response['data'] != null) {
        return PatientDashboardData.fromJson(response['data']);
      } else {
        throw Exception('Failed to load patient dashboard data');
      }
    } catch (e) {
      rethrow;
    }
  }
}