import '../../models/dashboard/nurse_dashboard_models.dart';
import '../../models/dashboard/patient_dashboard_models.dart';
import '../../utils/api_client.dart';
import '../../utils/api_config.dart';
import '../app_version_service.dart';

/// Wrapper for dashboard response that includes version info
class DashboardResponse<T> {
  final T data;
  final VersionRequirement? versionRequirement;

  DashboardResponse({
    required this.data,
    this.versionRequirement,
  });
}

class DashboardService {
  static final DashboardService _instance = DashboardService._internal();
  factory DashboardService() => _instance;
  DashboardService._internal();

  final _apiClient = ApiClient();

  /// Extract version requirement from API response
  VersionRequirement? _extractVersionInfo(Map<String, dynamic> response) {
    final versionData = response['version_info'] ?? response['app_version'];
    if (versionData != null && versionData is Map<String, dynamic>) {
      return VersionRequirement.fromJson(versionData);
    }
    return null;
  }

  /// Get nurse mobile dashboard
  Future<DashboardResponse<NurseDashboardData>> getNurseMobileDashboard() async {
    try {
      final response = await _apiClient.get(
        ApiConfig.nurseMobileDashboardEndpoint,
        requiresAuth: true,
      );

      if (response['success'] == true && response['data'] != null) {
        return DashboardResponse(
          data: NurseDashboardData.fromJson(response['data']),
          versionRequirement: _extractVersionInfo(response),
        );
      } else {
        throw Exception('Failed to load dashboard data');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get patient mobile dashboard
  Future<DashboardResponse<PatientDashboardData>> getPatientMobileDashboard() async {
    try {
      final response = await _apiClient.get(
        ApiConfig.patientMobileDashboardEndpoint,
        requiresAuth: true,
      );

      if (response['success'] == true && response['data'] != null) {
        return DashboardResponse(
          data: PatientDashboardData.fromJson(response['data']),
          versionRequirement: _extractVersionInfo(response),
        );
      } else {
        throw Exception('Failed to load patient dashboard data');
      }
    } catch (e) {
      rethrow;
    }
  }
}