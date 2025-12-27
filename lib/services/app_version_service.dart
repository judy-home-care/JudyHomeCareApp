import 'dart:io';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Model for version requirements from the backend
class VersionRequirement {
  final String minVersion;
  final int minBuildNumber;
  final bool forceUpdate;
  final String? updateMessage;
  final String? iosStoreUrl;
  final String? androidStoreUrl;

  VersionRequirement({
    required this.minVersion,
    required this.minBuildNumber,
    required this.forceUpdate,
    this.updateMessage,
    this.iosStoreUrl,
    this.androidStoreUrl,
  });

  factory VersionRequirement.fromJson(Map<String, dynamic> json) {
    return VersionRequirement(
      minVersion: json['min_version']?.toString() ?? '1.0.0',
      minBuildNumber: _parseInt(json['min_build_number']),
      forceUpdate: json['force_update'] == true,
      updateMessage: json['update_message']?.toString(),
      iosStoreUrl: json['ios_store_url']?.toString(),
      androidStoreUrl: json['android_store_url']?.toString(),
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

/// Service to manage app version checking and force updates
class AppVersionService {
  static final AppVersionService _instance = AppVersionService._internal();
  factory AppVersionService() => _instance;
  AppVersionService._internal();

  PackageInfo? _packageInfo;
  bool _isUpdateDialogShowing = false;

  // Default store URLs - update these with your actual app store URLs
  static const String _defaultIosStoreUrl =
      'https://apps.apple.com/gh/app/judycare/id6755534041';
  static const String _defaultAndroidStoreUrl =
      'https://play.google.com/store/apps/details?id=com.judyhealthcare.mobile';

  /// Initialize the service and load package info
  Future<void> initialize() async {
    _packageInfo = await PackageInfo.fromPlatform();
    debugPrint('[AppVersionService] Initialized:');
    debugPrint('  App Name: ${_packageInfo?.appName}');
    debugPrint('  Version: ${_packageInfo?.version}');
    debugPrint('  Build Number: ${_packageInfo?.buildNumber}');
  }

  /// Get current app version (e.g., "1.0.0")
  String get currentVersion => _packageInfo?.version ?? '0.0.0';

  /// Get current build number (e.g., "10")
  int get currentBuildNumber =>
      int.tryParse(_packageInfo?.buildNumber ?? '0') ?? 0;

  /// Get package name
  String get packageName => _packageInfo?.packageName ?? '';

  /// Check if an update is required based on version requirements
  bool needsUpdate(VersionRequirement requirement) {
    debugPrint('[AppVersionService] Checking update requirement:');
    debugPrint('  Current: $currentVersion ($currentBuildNumber)');
    debugPrint('  Required: ${requirement.minVersion} (${requirement.minBuildNumber})');
    debugPrint('  Force update enabled: ${requirement.forceUpdate}');

    if (!requirement.forceUpdate) {
      debugPrint('  Result: No update needed (force_update is false)');
      return false;
    }

    final versionComparison =
        _compareVersions(currentVersion, requirement.minVersion);

    if (versionComparison < 0) {
      // Current version is lower than minimum required
      debugPrint('  Result: Update required (version is lower)');
      return true;
    } else if (versionComparison == 0) {
      // Versions are equal, check build number
      final needsBuildUpdate = currentBuildNumber < requirement.minBuildNumber;
      debugPrint('  Result: ${needsBuildUpdate ? "Update required (build is lower)" : "No update needed (build is equal or higher)"}');
      return needsBuildUpdate;
    }

    // Current version is higher than minimum required
    debugPrint('  Result: No update needed (version is higher)');
    return false;
  }

  /// Compare two version strings (e.g., "1.2.3" vs "1.2.4")
  /// Returns: -1 if v1 < v2, 0 if v1 == v2, 1 if v1 > v2
  int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final parts2 = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    // Pad to same length
    while (parts1.length < parts2.length) {
      parts1.add(0);
    }
    while (parts2.length < parts1.length) {
      parts2.add(0);
    }

    for (int i = 0; i < parts1.length; i++) {
      if (parts1[i] < parts2[i]) return -1;
      if (parts1[i] > parts2[i]) return 1;
    }

    return 0;
  }

  /// Check version from API response and show dialog if needed
  /// Call this after receiving dashboard API response
  Future<void> checkVersionFromResponse(
    BuildContext context,
    Map<String, dynamic> response,
  ) async {
    // Check if response contains version info
    final versionData = response['version_info'] ?? response['app_version'];
    if (versionData == null) return;

    final requirement = VersionRequirement.fromJson(
      versionData is Map<String, dynamic> ? versionData : {},
    );

    if (needsUpdate(requirement)) {
      await showForceUpdateDialog(
        context,
        requirement: requirement,
      );
    }
  }

  /// Show the force update dialog (blocking)
  Future<void> showForceUpdateDialog(
    BuildContext context, {
    VersionRequirement? requirement,
  }) async {
    // Prevent multiple dialogs
    if (_isUpdateDialogShowing) return;
    _isUpdateDialogShowing = true;

    final message = requirement?.updateMessage ??
        'A new version of the app is available. Please update to continue using the app.';

    final storeUrl = Platform.isIOS
        ? (requirement?.iosStoreUrl ?? _defaultIosStoreUrl)
        : (requirement?.androidStoreUrl ?? _defaultAndroidStoreUrl);

    await showDialog(
      context: context,
      barrierDismissible: false, // User cannot dismiss by tapping outside
      builder: (context) => PopScope(
        canPop: false, // Prevent back button from closing dialog
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF199A8E).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.system_update,
                  color: Color(0xFF199A8E),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Update Required',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Current version: $currentVersion ($currentBuildNumber)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _openStore(storeUrl),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF199A8E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Platform.isIOS ? Icons.apple : Icons.shop,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      Platform.isIOS
                          ? 'Update on App Store'
                          : 'Update on Play Store',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    _isUpdateDialogShowing = false;
  }

  /// Open the app store
  Future<void> _openStore(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    }
  }

  /// Get headers to send with API requests
  Map<String, String> getVersionHeaders() {
    return {
      'X-App-Version': currentVersion,
      'X-Build-Number': currentBuildNumber.toString(),
      'X-Platform': Platform.isIOS ? 'ios' : 'android',
    };
  }
}
