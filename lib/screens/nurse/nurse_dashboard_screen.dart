import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../../utils/app_colors.dart';
import '../../services/dashboard/dashboard_service.dart';
import '../../services/time_tracking_service.dart';
import '../../services/location_service.dart';
import '../../models/dashboard/nurse_dashboard_models.dart';
import '../schedules/schedule_patients_screen.dart';
import 'nurse_patients_screen.dart';
import 'nurse_medical_assessment_screen.dart';
import '../incidents/incident_report_screen.dart';
import '../transport/transport_request_screen.dart';
import 'nurse_care_requests_lists_screen.dart';
import '../modern_notifications_sheet.dart';
import '../../services/notification_service.dart';

class NurseDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> nurseData;
  final Function(int)? onTabChange;
  
  const NurseDashboardScreen({
    Key? key,
    required this.nurseData,
    this.onTabChange,
  }) : super(key: key);

  @override
  State<NurseDashboardScreen> createState() => _NurseDashboardScreenState();
}

class _NurseDashboardScreenState extends State<NurseDashboardScreen>
    with WidgetsBindingObserver {

  final _dashboardService = DashboardService();
  final _timeTrackingService = TimeTrackingService();
  final _locationService = LocationService();
  
  bool _isLoading = true;
  String? _errorMessage;
  NurseDashboardData? _dashboardData;
  
  // Cache management
  DateTime? _lastFetchTime;
  DateTime? _lastRefreshAttempt;
  static const Duration _cacheValidityDuration = Duration(minutes: 2);
  static const Duration _minRefreshInterval = Duration(seconds: 30);
  static const Duration _backgroundReturnThreshold = Duration(minutes: 2);
  
  // Visibility tracking
  bool _isTabVisible = false;
  DateTime? _lastVisibleTime;
  
  // 🆕 OPTIMIZATION: Debounce timer for tab visibility
  Timer? _visibilityDebounce;

  // 🆕 Rate limiting for "Dashboard updated" notification
  DateTime? _lastNotificationShownTime;
  static const Duration _minNotificationInterval = Duration(seconds: 5);

  // Screen visibility tracking for battery optimization
  bool _isScreenVisible = true;

  // Track if notification was received while app was paused (local flag)
  bool _pendingNotificationRefresh = false;

  // Notification management
  final NotificationService _notificationService = NotificationService();
  int _unreadNotificationCount = 0;

  // Multi-listener cleanup callbacks
  VoidCallback? _removeCountListener;
  VoidCallback? _removeReceivedListener;
  
  // Timer management
  Timer? _activeTimer;
  Timer? _timerSyncTimer;
  final ValueNotifier<int> _elapsedSeconds = ValueNotifier<int>(0);
  bool _isTimerRunning = false;
  int? _activeScheduleId;
  int? _activeTimeTrackingId;
  DateTime? _timerStartTime;
  
  // Location data
  Position? _currentPosition;
  bool _isLoadingLocation = false;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _activeTimer?.cancel();
    _timerSyncTimer?.cancel();
    _visibilityDebounce?.cancel();
    _elapsedSeconds.dispose();

    // Clean up FCM listeners (multi-listener pattern)
    _removeCountListener?.call();
    _removeReceivedListener?.call();

    debugPrint('🧹 Dashboard disposed - all timers and listeners cleaned up');
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDashboardData(forceRefresh: false);
    _checkForActiveSession();
    
    // ⚡ NEW: Set up real-time FCM notification updates
    _setupFcmNotificationUpdates();
    
    // Load initial notification count once (no polling!)
    _loadUnreadNotificationCount();
  }

  // OPTIMIZED: Detect app lifecycle changes for battery saving
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      _isScreenVisible = true;
      debugPrint('🔄 [Nurse Dashboard] App resumed - checking for pending notifications');

      // Check how long we've been away
      final now = DateTime.now();
      final timeSinceLastVisible = _lastVisibleTime != null
          ? now.difference(_lastVisibleTime!)
          : null;

      _lastVisibleTime = now;

      // Check if notification was received while in background (from tapping notification)
      final hasBackgroundNotification = _notificationService.hasNotificationWhileBackground;

      // Check if notification was received while app was paused (local tracking)
      final hasPendingRefresh = _pendingNotificationRefresh;

      // Force refresh if any notification was received while away
      if (hasBackgroundNotification || hasPendingRefresh) {
        debugPrint('📱 [Nurse Dashboard] Notification received while away - forcing refresh');
        debugPrint('   - Background notification (tapped): $hasBackgroundNotification');
        debugPrint('   - Pending refresh (received while paused): $hasPendingRefresh');

        // Clear both flags
        _notificationService.clearBackgroundNotificationFlag();
        _pendingNotificationRefresh = false;

        // Force dashboard reload
        _loadDashboardData(forceRefresh: true, silent: true);
      } else if (_shouldRefreshOnResume(timeSinceLastVisible)) {
        // Only refresh if cache is expired or we've been away for a while
        debugPrint('📱 [Nurse Dashboard] Cache expired or long absence, refreshing');
        _loadDashboardData(forceRefresh: true, silent: true);
      } else {
        debugPrint('📱 [Nurse Dashboard] Using cached data (valid for ${_getRemainingCacheTime()})');
      }

      // Always sync timer if running (lightweight operation)
      if (_isTimerRunning) {
        debugPrint('⏱️ Syncing active timer with backend');
        _syncTimerWithBackend();
        _startLocalTimer();

        if (_isTabVisible) {
          _startPeriodicSync();
        }
      }

      // Refresh notification count on app resume
      _notificationService.refreshBadge();
    } else if (state == AppLifecycleState.paused) {
      _isScreenVisible = false;
      _lastVisibleTime = DateTime.now();
      debugPrint('⏸️ [Nurse Dashboard] App paused - stopping local timer to save battery');

      _activeTimer?.cancel();
      _stopPeriodicSync();
    }
  }


  // ==================== FCM REAL-TIME NOTIFICATION UPDATES ====================

  /// ⚡ Set up FCM callback for real-time notification count updates
  /// Uses multi-listener pattern so all screens get updates!
  void _setupFcmNotificationUpdates() {
    debugPrint('⚡ [Nurse Dashboard] Setting up FCM real-time notification updates (multi-listener)');

    // Update notification badge count - using multi-listener pattern
    _removeCountListener = _notificationService.addNotificationCountListener((newCount) {
      if (mounted) {
        setState(() {
          _unreadNotificationCount = newCount;
        });
        debugPrint('🔔 [Nurse Dashboard] Notification count updated: $newCount');
      }
    });

    // Refresh dashboard when notification received (foreground or background)
    _removeReceivedListener = _notificationService.addNotificationReceivedListener(() {
      if (mounted) {
        if (_isScreenVisible) {
          // App is in foreground - refresh dashboard data immediately
          debugPrint('🔄 [Nurse Dashboard] Notification received (foreground) - triggering silent refresh');
          _loadDashboardData(forceRefresh: true, silent: true);
          // NOTE: Don't call _loadUnreadNotificationCount() here!
          // The badge count is already updated via the count listener (addNotificationCountListener)
          // Calling the API here would overwrite the correct count with stale data
        } else {
          // App is in background/paused - set flag to refresh on resume
          debugPrint('🔄 [Nurse Dashboard] Notification received (background) - setting pending refresh flag');
          _pendingNotificationRefresh = true;
        }
      }
    });
  }

  /// Load unread notification count (only called once on init and resume)
  Future<void> _loadUnreadNotificationCount() async {
    try {
      // Just call refreshBadge() - it updates BOTH count AND badge
      await _notificationService.refreshBadge();
      debugPrint('📊 [Nurse Dashboard] Badge refreshed and count updated');
    } catch (e) {
      debugPrint('❌ [Nurse Dashboard] Error refreshing badge: $e');
    }
  }

  /// Open notifications sheet (new modern bottom sheet)
  void _openNotificationsSheet() async {
    await showNotificationsSheet(context);
    
    // Refresh badge after closing
    await _notificationService.refreshBadge();
    debugPrint('🔔 [Nurse Dashboard] Badge refreshed after closing notifications');
  }

  // ==================== END NOTIFICATION UPDATES ====================


  // ==================== LOCATION SERVICES ====================
  
  /// Check and request location permissions
  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showErrorSnackbar('Location services are disabled. Please enable location services.');
      return false;
    }

    // Check location permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showErrorSnackbar('Location permission denied. Cannot start timer without location.');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showErrorSnackbar('Location permissions are permanently denied. Please enable in settings.');
      _showLocationSettingsDialog();
      return false;
    }

    return true;
  }

  /// Get current location
  Future<Position?> _getCurrentLocation() async {
    try {
      setState(() {
        _isLoadingLocation = true;
      });

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF199A8E)),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Getting your location...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please wait',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
      });

      debugPrint('📍 Location obtained: ${position.latitude}, ${position.longitude}');
      return position;

    } catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      setState(() {
        _isLoadingLocation = false;
      });

      debugPrint('❌ Error getting location: $e');
      
      if (e is TimeoutException) {
        _showErrorSnackbar('Location timeout. Please check your GPS signal.');
      } else {
        _showErrorSnackbar('Failed to get location. Please try again.');
      }
      
      return null;
    }
  }

  /// Show dialog to open location settings
  void _showLocationSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE5E5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.location_off,
                color: Color(0xFFFF4757),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Location Required',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const Text(
          'Time tracking requires location permission. Please enable location permissions in your device settings.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF199A8E), Color(0xFF25B5A8)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Geolocator.openAppSettings();
              },
              child: const Text(
                'Open Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== ACTIVE SESSION MANAGEMENT ====================
  
  /// Check for existing active session on load
  Future<void> _checkForActiveSession() async {
    try {
      final activeSession = await _timeTrackingService.getActiveSession();
      
      if (activeSession != null && mounted) {
        final startTime = DateTime.parse(activeSession['start_time'] as String);
        
        setState(() {
          _activeScheduleId = activeSession['schedule_id'] as int?;
          _activeTimeTrackingId = activeSession['id'] as int;
          _isTimerRunning = true;
          _timerStartTime = startTime;
          
          // Calculate elapsed seconds from start_time
          final elapsed = DateTime.now().difference(startTime).inSeconds;
          _elapsedSeconds.value = elapsed > 0 ? elapsed : 0;
        });
        
        // Start the local timer AND periodic sync (only if screen visible)
        if (_isScreenVisible) {
          _startLocalTimer();
        }
        
        // 🆕 OPTIMIZATION: Only start periodic sync if tab is visible
        if (_isTabVisible) {
          _startPeriodicSync();
        }
        
        debugPrint('✅ Restored active timer session: ${activeSession['id']}');
        debugPrint('⏰ Start time: $startTime, Elapsed: ${_elapsedSeconds.value}s');
      }
    } catch (e) {
      debugPrint('❌ Error checking for active session: $e');
    }
  }

  /// IMPROVED: Sync timer with backend and auto-hide if session ended
  Future<void> _syncTimerWithBackend() async {
    if (!_isTimerRunning || _activeTimeTrackingId == null) return;

    try {
      final activeSession = await _timeTrackingService.getActiveSession();
      
      if (activeSession != null && mounted) {
        final startTime = DateTime.parse(activeSession['start_time'] as String);
        final currentElapsed = DateTime.now().difference(startTime).inSeconds;
        
        setState(() {
          _timerStartTime = startTime;
          _elapsedSeconds.value = currentElapsed > 0 ? currentElapsed : 0;
        });
        
        debugPrint('🔄 Timer synced - Backend time: ${_elapsedSeconds.value}s');
      } else {
        // Session no longer exists on backend - hide Active Session widget
        debugPrint('⚠️ Active session not found on backend - hiding timer widget');
        
        if (mounted) {
          _stopLocalTimer();
          
          // Show subtle notification
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: const [
                  Icon(Icons.info_outline, color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('Session completed'),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF199A8E),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error syncing timer: $e');
    }
  }

  /// 🆕 OPTIMIZED: Start periodic sync - respects tab visibility
  void _startPeriodicSync() {
    // Don't start if tab is not visible
    if (!_isTabVisible) {
      debugPrint('⏸️ Tab not visible - not starting periodic sync');
      return;
    }
    
    _timerSyncTimer?.cancel();
    
    // Changed from 5 minutes to 2 minutes for more responsive completion detection
    _timerSyncTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      // 🆕 OPTIMIZATION: Check both timer running AND tab visible
      if (_isTimerRunning && _isScreenVisible && _isTabVisible) {
        _syncTimerWithBackend();
        // Also refresh dashboard to check completion status
        _loadDashboardData(forceRefresh: true, silent: true);
        debugPrint('🔄 Periodic sync executed (tab visible)');
      } else if (!_isTimerRunning) {
        // Stop syncing if timer not running
        timer.cancel();
        debugPrint('⏹️ Periodic sync stopped - timer not running');
      } else {
        debugPrint('⏸️ Periodic sync skipped - tab not visible');
      }
    });
    debugPrint('🔄 Started periodic timer sync (every 2 minutes)');
  }

  /// Stop periodic sync
  void _stopPeriodicSync() {
    _timerSyncTimer?.cancel();
    _timerSyncTimer = null;
    debugPrint('⏹️ Stopped periodic timer sync');
  }

  // ==================== TIMER CONTROL ====================
  
  /// Start timer - Gets location first, then creates time tracking session and clocks in
  Future<void> _startTimer(int scheduleId) async {
    if (_isTimerRunning && _activeScheduleId != null) {
      _showInfoSnackbar('Timer is already running for another schedule');
      return;
    }

    // Check if the schedule is already completed
    final schedule = _dashboardData?.scheduleVisits.firstWhere(
      (s) => s.id == scheduleId,
      orElse: () => _dashboardData!.scheduleVisits.first,
    );

    if (schedule?.status?.toLowerCase() == 'completed') {
      _showErrorSnackbar('This schedule is already completed. Cannot start timer.');
      return;
    }

    // Step 1: Check location permission
    final hasPermission = await _handleLocationPermission();
    if (!hasPermission) {
      return;
    }

    // Step 2: Get current location
    final position = await _getCurrentLocation();
    if (position == null) {
      _showErrorSnackbar('Cannot start timer without location. Please try again.');
      return;
    }

    // Step 3: DON'T set timer running here - wait for API success
    // REMOVED: setState(() {
    //   _isTimerRunning = true;
    //   _activeScheduleId = scheduleId;
    // });
    
    try {
      // Show starting indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('Starting timer...'),
            ],
          ),
          backgroundColor: const Color(0xFF199A8E),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      
      // Get the resolved address first
      final resolvedLocation = await _getAddressFromCoordinates(position);
      debugPrint('📍 Resolved location to send: $resolvedLocation');

      // Call API to clock in with location
      final response = await _timeTrackingService.clockIn(
        scheduleId: scheduleId,
        latitude: position.latitude,
        longitude: position.longitude,
        location: resolvedLocation,
        deviceInfo: 'Flutter Mobile App',
      );

      debugPrint('📦 Clock-in payload: scheduleId=$scheduleId, lat=${position.latitude}, lng=${position.longitude}, location=$resolvedLocation');
      
      if (!mounted) return;
      
      if (response['success'] == true && response['data'] != null) {
        final data = response['data'] as Map<String, dynamic>;
        final startTime = DateTime.parse(data['start_time'] as String);
        
        // NOW set the timer as running after successful API call
        setState(() {
          _isTimerRunning = true;
          _activeScheduleId = scheduleId;
          _activeTimeTrackingId = data['id'] as int;
          _timerStartTime = startTime;
          _elapsedSeconds.value = 0;
        });
        
        // Start the local timer AND periodic sync (only if screen visible)
        if (_isScreenVisible) {
          _startLocalTimer();
        }
        
        // Only start periodic sync if tab is visible
        if (_isTabVisible) {
          _startPeriodicSync();
        }
        
        _showSuccessSnackbar('Timer started successfully!');
        
        debugPrint('✅ Timer started - Session ID: $_activeTimeTrackingId');
        debugPrint('⏰ Start time: $startTime');
        debugPrint('📍 Location: ${position.latitude}, ${position.longitude}');
      } else {
        // Failed to start timer - no need to rollback state since we didn't set it yet
        _showErrorSnackbar(response['message'] as String? ?? 'Failed to start timer');
      }
    } catch (e) {
      if (mounted) {
        // No need to rollback state since we didn't set it yet
        _showErrorSnackbar('Error starting timer. Please try again.');
        debugPrint('❌ Error starting timer: $e');
      }
    }
  }

  /// Get address from coordinates using Google Maps Geocoding API
  Future<String> _getAddressFromCoordinates(Position position) async {
    try {
      // Use Google Maps Geocoding API via LocationService (same as transport screen)
      final address = await _locationService.getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (address != null && address.isNotEmpty) {
        debugPrint('📍 Address resolved: $address');
        return address;
      }
    } catch (e) {
      debugPrint('⚠️ Error getting address: $e');
    }

    // Fallback to coordinates if geocoding fails
    return 'Lat: ${position.latitude.toStringAsFixed(6)}, Long: ${position.longitude.toStringAsFixed(6)}';
  }

  /// Stop timer - Clocks out from active session
  Future<void> _stopTimer() async {
    if (!_isTimerRunning || _activeTimeTrackingId == null) {
      _showInfoSnackbar('No active timer to stop');
      return;
    }

    // Get current location for clock out
    final hasPermission = await _handleLocationPermission();
    Position? position;
    
    if (hasPermission) {
      position = await _getCurrentLocation();
    }

    // Stop the local timer AND periodic sync immediately
    _activeTimer?.cancel();
    _stopPeriodicSync();
    
    try {
      // Show stopping indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('Stopping timer...'),
            ],
          ),
          backgroundColor: const Color(0xFF199A8E),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      
      final elapsedTime = _elapsedSeconds.value;

      // Get the resolved address first
      String? resolvedLocation;
      if (position != null) {
        resolvedLocation = await _getAddressFromCoordinates(position);
        debugPrint('📍 Resolved clock-out location: $resolvedLocation');
      }

      // Call API to clock out
      final response = await _timeTrackingService.clockOut(
        latitude: position?.latitude,
        longitude: position?.longitude,
        location: resolvedLocation,
      );

      debugPrint('📦 Clock-out payload: lat=${position?.latitude}, lng=${position?.longitude}, location=$resolvedLocation');
      
      if (!mounted) return;
      
      if (response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>;
        final formattedDuration = data['formatted_duration'] as String? ?? 
                                  _formatDuration(elapsedTime);
        
        _stopLocalTimer();
        
        _showSuccessSnackbar('Timer stopped - $formattedDuration logged');
        
        // Refresh dashboard to show updated data
        _loadDashboardData(forceRefresh: true, silent: true);
        
        debugPrint('✅ Timer stopped - Duration: $formattedDuration');
      } else {
        // Check if the error is "no active session"
        final errorMessage = (response['message'] as String? ?? '').toLowerCase();
        
        if (errorMessage.contains('no active session') || 
            errorMessage.contains('no active') ||
            errorMessage.contains('not found')) {
          // If there's no active session on the server, just stop the local timer
          _stopLocalTimer();
          
          _showInfoSnackbar('Timer stopped (session already ended)');
          
          // Refresh dashboard
          _loadDashboardData(forceRefresh: true, silent: true);
          
          debugPrint('⚠️ Timer stopped locally - No active session on server');
        } else {
          // Other errors - restart local timer
          if (_isScreenVisible) {
            _startLocalTimer();
          }
          _showErrorSnackbar(response['message'] as String? ?? 'Failed to stop timer');
        }
      }
    } catch (e) {
      // Network or other error - stop timer locally anyway
      if (mounted) {
        _stopLocalTimer();
        
        _showInfoSnackbar('Timer stopped locally (network error)');
        debugPrint('❌ Error stopping timer: $e - Timer stopped locally');
      }
    }
  }

  /// OPTIMIZED: Start local timer - only runs when screen is visible
  void _startLocalTimer() {
    _activeTimer?.cancel();
    
    // BATTERY OPTIMIZATION: Don't start if screen not visible
    if (!_isScreenVisible) {
      debugPrint('⏸️ Screen not visible - not starting local timer');
      return;
    }
    
    _activeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // BATTERY OPTIMIZATION: Stop if screen becomes invisible
      if (!_isScreenVisible) {
        debugPrint('⏸️ Screen not visible - pausing local timer');
        timer.cancel();
        return;
      }
      
      if (_timerStartTime != null) {
        // CRITICAL: Recalculate from backend start_time, not just increment
        final elapsed = DateTime.now().difference(_timerStartTime!).inSeconds;
        _elapsedSeconds.value = elapsed > 0 ? elapsed : 0;
      } else {
        // Fallback: just increment if start time not available
        _elapsedSeconds.value++;
      }
    });
    
    debugPrint('▶️ Local timer started');
  }

  /// Stop local timer
  void _stopLocalTimer() {
    _activeTimer?.cancel();
    _timerSyncTimer?.cancel();
    
    if (mounted) {
      setState(() {
        _isTimerRunning = false;
        _activeScheduleId = null;
        _activeTimeTrackingId = null;
        _timerStartTime = null;
        _elapsedSeconds.value = 0;
      });
    }
  }

  /// Pause timer
  Future<void> _pauseTimer(String? reason) async {
    if (!_isTimerRunning) return;
    
    try {
      final response = await _timeTrackingService.pauseSession(reason: reason);
      
      if (!mounted) return;
      
      if (response['success'] == true) {
        _activeTimer?.cancel();
        _showInfoSnackbar('Timer paused');
      } else {
        _showErrorSnackbar(response['message'] as String? ?? 'Failed to pause timer');
      }
    } catch (e) {
      debugPrint('❌ Error pausing timer: $e');
    }
  }

  /// Resume timer
  Future<void> _resumeTimer() async {
    try {
      final response = await _timeTrackingService.resumeSession();
      
      if (!mounted) return;
      
      if (response['success'] == true) {
        if (_isScreenVisible) {
          _startLocalTimer();
        }
        _showInfoSnackbar('Timer resumed');
      } else {
        _showErrorSnackbar(response['message'] as String? ?? 'Failed to resume timer');
      }
    } catch (e) {
      debugPrint('❌ Error resuming timer: $e');
    }
  }

  String _formatDuration(int seconds) {
    int hours = seconds ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    int secs = seconds % 60;
    
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  // ==================== STOP TIMER CONFIRMATION ====================
  
  /// Show confirmation before stopping timer
  void _showStopTimerConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE5E5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.stop_circle_outlined,
                color: Color(0xFFFF4757),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Stop Timer',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to stop the timer? This will end the current time tracking session.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF4757), Color(0xFFFF6B7A)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _stopTimer();
              },
              child: const Text(
                'Stop Timer',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== PUBLIC METHODS FOR PARENT NAVIGATION ====================
  
  /// Public method to trigger manual refresh (called by parent)
  void loadDashboard({bool forceRefresh = false}) {
    _loadDashboardData(forceRefresh: forceRefresh);
  }

  // ==================== SMART REFRESH LOGIC ====================
  
  /// 🆕 OPTIMIZED: Called by parent when tab becomes visible - with debouncing
  void onTabVisible() {
    _isTabVisible = true;
    
    // Cancel any existing debounce timer
    _visibilityDebounce?.cancel();
    
    // Debounce to prevent rapid refreshes
    _visibilityDebounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted || !_isTabVisible) return;
      
      debugPrint('👁️ Dashboard tab visible - checking cache validity');
      
      final now = DateTime.now();
      final timeSinceLastVisible = _lastVisibleTime != null 
          ? now.difference(_lastVisibleTime!) 
          : null;
      
      _lastVisibleTime = now;
      
      // Only refresh if cache is actually expired
      if (_shouldRefreshOnVisible(timeSinceLastVisible)) {
        debugPrint('✅ Cache expired or stale - refreshing dashboard');
        _loadDashboardData(forceRefresh: true, silent: true);
      } else {
        debugPrint('📦 Using cached data (valid for ${_getRemainingCacheTime()})');
      }
      
      _notificationService.refreshBadge(); 
      
      // Always sync timer if running
      if (_isTimerRunning) {
        _syncTimerWithBackend();
        _startPeriodicSync();
      }
    });
  }

  // ==================== CACHE VALIDATION HELPERS ====================

/// Determine if refresh is needed when app resumes
bool _shouldRefreshOnResume(Duration? timeSinceLastVisible) {
  // Never refresh if we just refreshed
  if (_lastRefreshAttempt != null) {
    final timeSinceRefresh = DateTime.now().difference(_lastRefreshAttempt!);
    if (timeSinceRefresh < _minRefreshInterval) {
      debugPrint('⏱️ Rate limit: Last refresh was ${timeSinceRefresh.inSeconds}s ago');
      return false;
    }
  }
  
  // Don't refresh if cache is still valid
  if (!_isCacheExpired) {
    debugPrint('📦 Cache still valid for ${_getRemainingCacheTime()}');
    return false;
  }
  
  // Refresh if cache is expired
  debugPrint('🔄 Cache expired - needs refresh');
  return true;
}



/// Get remaining cache validity time as a string
String _getRemainingCacheTime() {
  if (_lastFetchTime == null) return 'No cache';
  
  final elapsed = DateTime.now().difference(_lastFetchTime!);
  final remaining = _cacheValidityDuration - elapsed;
  
  if (remaining.isNegative) return 'Expired';
  
  if (remaining.inMinutes > 0) {
    return '${remaining.inMinutes}m ${remaining.inSeconds % 60}s';
  } else {
    return '${remaining.inSeconds}s';
  }
}
  
  /// 🆕 OPTIMIZED: Called by parent when tab becomes hidden - stops periodic sync
  void onTabHidden() {
    _isTabVisible = false;
    _visibilityDebounce?.cancel();
    
    // 🆕 OPTIMIZATION: Stop periodic sync to save battery/CPU
    _stopPeriodicSync();
    
    debugPrint('👁️‍🗨️ Dashboard tab hidden - periodic sync stopped');
  }

  /// Determine if refresh is needed when tab becomes visible
  bool _shouldRefreshOnVisible(Duration? timeSinceLastVisible) {
    // Never refresh if we just refreshed
    if (_lastRefreshAttempt != null) {
      final timeSinceRefresh = DateTime.now().difference(_lastRefreshAttempt!);
      if (timeSinceRefresh < _minRefreshInterval) {
        debugPrint('⏱️ Rate limit: Last refresh was ${timeSinceRefresh.inSeconds}s ago');
        return false;
      }
    }
    
    // Refresh if cache is expired
    if (_isCacheExpired) {
      return true;
    }
    
    // Refresh if returning after being away for a while
    if (timeSinceLastVisible != null && 
        timeSinceLastVisible > _backgroundReturnThreshold) {
      return true;
    }
    
    return false;
  }

  /// Get human-readable reason for refresh (for debugging)
  String _getRefreshReason(Duration? timeSinceLastVisible) {
    if (_isCacheExpired) {
      return 'cache expired';
    }
    if (timeSinceLastVisible != null && 
        timeSinceLastVisible > _backgroundReturnThreshold) {
      return 'returning after ${timeSinceLastVisible.inMinutes}m';
    }
    return 'manual';
  }

  /// Check if cached data is expired
  bool get _isCacheExpired {
    if (_lastFetchTime == null || _dashboardData == null) return true;
    final difference = DateTime.now().difference(_lastFetchTime!);
    return difference >= _cacheValidityDuration;
  }

  /// Get cache age for display
  String get _cacheAge {
    if (_lastFetchTime == null) return 'Never';
    final difference = DateTime.now().difference(_lastFetchTime!);
    
    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  /// Get cache freshness color
  Color get _cacheFreshnessColor {
    if (_lastFetchTime == null) return Colors.grey;
    final difference = DateTime.now().difference(_lastFetchTime!);
    
    if (difference < const Duration(minutes: 2)) {
      return AppColors.primaryGreen;
    } else if (difference < _cacheValidityDuration) {
      return const Color(0xFFFF9A00);
    } else {
      return Colors.red;
    }
  }

  // ==================== DATA LOADING ====================

  /// Load dashboard data with smart caching and rate limiting
  Future<void> _loadDashboardData({
    bool forceRefresh = false,
    bool silent = false,
  }) async {
    // Rate limiting check - applies to ALL refreshes (including silent ones)
    if (_lastRefreshAttempt != null) {
      final timeSinceLastAttempt = DateTime.now().difference(_lastRefreshAttempt!);
      if (timeSinceLastAttempt < _minRefreshInterval) {
        // For silent refreshes, just skip quietly
        if (silent) {
          debugPrint('⏭️ Silent refresh rate limited - last attempt ${timeSinceLastAttempt.inSeconds}s ago');
          return;
        }
        // For manual refreshes, show a message
        if (!forceRefresh) {
          debugPrint('⏱️ Rate limited - last attempt ${timeSinceLastAttempt.inSeconds}s ago');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.schedule, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Please wait ${_minRefreshInterval.inSeconds - timeSinceLastAttempt.inSeconds}s before refreshing again',
                      ),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFFFF9A00),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          }
          return;
        }
        // For explicit forceRefresh (like pull-to-refresh), allow it through
      }
    }

    // Use cache if valid and not forcing refresh
    if (!forceRefresh && !_isCacheExpired && _dashboardData != null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      debugPrint('📦 Using cached dashboard data (${_cacheAge})');
      return;
    }

    // Show loading only if not silent refresh
    if (!silent && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    _lastRefreshAttempt = DateTime.now();
    
    debugPrint('🌐 Fetching dashboard from API...');

    try {
      final data = await _dashboardService.getNurseMobileDashboard();
      
      if (mounted) {
        setState(() {
          _dashboardData = data;
          _lastFetchTime = DateTime.now();
          _isLoading = false;
        });
        
        debugPrint('✅ Dashboard loaded (${_cacheAge})');

        _checkAndStopCompletedTimer();
        
        // Show notification if silent refresh
        if (silent && _isTabVisible) {
          _showDataUpdatedNotification();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load dashboard data. Please try again.';
          _isLoading = false;
        });
        debugPrint('❌ Dashboard load error: $e');
      }
    }
  }

  /// Show notification when data updates in background (rate-limited)
  void _showDataUpdatedNotification() {
    if (!mounted) return;

    // Rate limit: Only show notification if enough time has passed since last one
    final now = DateTime.now();
    if (_lastNotificationShownTime != null) {
      final timeSinceLastNotification = now.difference(_lastNotificationShownTime!);
      if (timeSinceLastNotification < _minNotificationInterval) {
        debugPrint('⏭️ Skipping notification - shown ${timeSinceLastNotification.inSeconds}s ago');
        return;
      }
    }

    _lastNotificationShownTime = now;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.refresh,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Dashboard updated'),
            ),
          ],
        ),
        backgroundColor: AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Force refresh the dashboard (for pull-to-refresh)
  Future<void> _forceRefresh() async {
    await _loadDashboardData(forceRefresh: true);
  }

  // ==================== UI BUILD METHODS ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFB),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: _lastFetchTime != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Dashboard',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _cacheFreshnessColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Updated $_cacheAge',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : null,
actions: [
  // 🔔 NOTIFICATION BELL WITH REAL-TIME BADGE
  Stack(
    clipBehavior: Clip.none,
    children: [
      Container(
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IconButton(
          icon: Icon(
            _unreadNotificationCount > 0
                ? Icons.notifications_rounded
                : Icons.notifications_outlined,
            color: _unreadNotificationCount > 0
                ? AppColors.primaryGreen
                : const Color(0xFF1A1A1A),
          ),
          onPressed: _openNotificationsSheet,
          iconSize: 24,
        ),
      ),
      if (_unreadNotificationCount > 0)
        Positioned(
          right: 12,
          top: 8,
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFF4757),
                  const Color(0xFFFF4757).withOpacity(0.8),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFF8FAFB), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF4757).withOpacity(0.5),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
            constraints: const BoxConstraints(
              minWidth: 20,
              minHeight: 20,
            ),
            child: Center(
              child: Text(
                _unreadNotificationCount > 99 
                    ? '99+' 
                    : _unreadNotificationCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
    ],
  ),
  const SizedBox(width: 4),
  IconButton(
    icon: _isLoading && !_isCacheExpired
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.primaryGreen,
              ),
            ),
          )
        : Icon(
            Icons.refresh,
            color: _isCacheExpired ? Colors.red : AppColors.primaryGreen,
          ),
    onPressed: _isLoading ? null : () => _loadDashboardData(forceRefresh: true),
    tooltip: _isCacheExpired ? 'Data expired - Tap to refresh' : 'Refresh dashboard',
  ),
],
      ),
      body: SafeArea(
        child: _isLoading && _dashboardData == null
            ? _buildLoadingState()
            : _errorMessage != null && _dashboardData == null
                ? _buildErrorState()
                : _buildDashboardContent(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF199A8E)),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading dashboard...',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'An error occurred',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _forceRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF199A8E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardContent() {
    if (_dashboardData == null) {
      return const SizedBox();
    }

    return RefreshIndicator(
      onRefresh: _forceRefresh,
      color: const Color(0xFF199A8E),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              _buildGreeting(),
              const SizedBox(height: 24),
              
              // 🆕 OPTIMIZATION: Wrap static widgets in RepaintBoundary
              RepaintBoundary(
                child: _buildHealthMetrics(),
              ),
              
              const SizedBox(height: 32),
              _buildTodaySchedule(),
              const SizedBox(height: 32),
              
              // 🆕 OPTIMIZATION: Quick actions are static
              RepaintBoundary(
                child: _buildQuickActions(),
              ),
              
              const SizedBox(height: 32),
              _buildMyPatients(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGreeting() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, ${widget.nurseData['name']?.split(' ')[0] ?? 'Nurse'}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'How is your shift going today?',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF199A8E).withOpacity(0.1),
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  widget.nurseData['name']?.substring(0, 1) ?? 'N',
                  style: const TextStyle(
                    color: Color(0xFF199A8E),
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
        // Active Timer Widget - ONLY shows if timer is actually running
        if (_isTimerRunning) ...[
          const SizedBox(height: 16),
          _buildActiveTimerWidget(),
        ],
      ],
    );
  }

  // Active Timer Widget with only Stop button (no Clear button)
  Widget _buildActiveTimerWidget() {
    return ValueListenableBuilder<int>(
      valueListenable: _elapsedSeconds,
      builder: (context, elapsedTime, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF199A8E).withOpacity(0.1),
                const Color(0xFF199A8E).withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF199A8E).withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF199A8E).withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Pulsing indicator
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFF199A8E),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF199A8E).withOpacity(0.5),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Active Session',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF199A8E),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Time tracking in progress',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Timer display
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF199A8E),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF199A8E).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.timer,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatDuration(elapsedTime),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFeatures: [
                              FontFeature.tabularFigures(),
                            ],
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              // Only Stop button (Clear button removed)
              const SizedBox(height: 12),
              Row(
                children: [
                  // Stop button - full width
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showStopTimerConfirmation,
                      icon: const Icon(Icons.stop_circle_outlined, size: 18),
                      label: const Text(
                        'Stop Timer',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF4757),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHealthMetrics() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                icon: Icons.access_time_outlined,
                label: 'Week Hours',
                value: '${_dashboardData!.weekHours}h',
                iconColor: const Color(0xFF199A8E),
                bgColor: const Color(0xFFE8F5F5),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.favorite_outline,
                label: 'Patients Today',
                value: '${_dashboardData!.todayPatients}',
                iconColor: const Color(0xFFFF6B6B),
                bgColor: const Color(0xFFFFE5E5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                icon: Icons.assignment_outlined,
                label: 'Care Plans',
                value: '${_dashboardData!.activePlans}',
                iconColor: const Color(0xFF6C63FF),
                bgColor: const Color(0xFFEDE9FF),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.calendar_today_outlined,
                label: 'Weekly Schedule',
                value: '${_dashboardData!.scheduleVisits.length}',
                iconColor: const Color(0xFFFF9A00),
                bgColor: const Color(0xFFFFF3E0),
              ),
            ),
          ],
        ),
      ],
    );
  }

Widget _buildMetricCard({
  required IconData icon,
  required String label,
  required String value,
  required Color iconColor,
  required Color bgColor,
}) {
  // Make responsive based on screen height
  final screenHeight = MediaQuery.of(context).size.height;
  final isSmallScreen = screenHeight < 700;
  
  return Container(
    padding: EdgeInsets.all(isSmallScreen ? 12 : 16), // Reduced padding
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          padding: EdgeInsets.all(isSmallScreen ? 8 : 10), // Smaller icon container
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: isSmallScreen ? 18 : 20, // Smaller icon
            color: iconColor,
          ),
        ),
        SizedBox(width: isSmallScreen ? 10 : 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, // Important for smaller screens
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: isSmallScreen ? 11 : 12, // Smaller label
                  color: Colors.grey.shade600,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: isSmallScreen ? 1 : 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: isSmallScreen ? 16 : 18, // Smaller value
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1A1A),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildTodaySchedule() {
  final todayVisits = _dashboardData!.scheduleVisits
      .where((visit) => visit.dateDisplay == 'Today')
      .toList();

  // Separate visits into upcoming and completed
  final upcomingVisits = todayVisits
      .where((visit) => 
          visit.status?.toLowerCase() != 'completed' && 
          visit.status?.toLowerCase() != 'cancelled')
      .toList();
  
  final completedVisits = todayVisits
      .where((visit) => visit.status?.toLowerCase() == 'completed')
      .toList();

  // Smart logic: Show ONLY ONE visit at a time
  // Priority: Next upcoming visit (closest to current time) > Most recent completed visit
  ScheduleVisit? visitToShow;
  bool showingCompleted = false;

  if (upcomingVisits.isNotEmpty) {
    // Show the most recent upcoming visit (closest to current time, but still in the future)
    final now = DateTime.now();
    
    // Parse and sort by actual time (ascending order)
    upcomingVisits.sort((a, b) {
      try {
        final timeA = _parseTimeString(a.time);
        final timeB = _parseTimeString(b.time);
        return timeA.compareTo(timeB);
      } catch (e) {
        debugPrint('Error parsing time: $e');
        return 0;
      }
    });
    
    // Find the visit that's closest to now but still upcoming
    ScheduleVisit? nextUpcoming;
    
    for (var visit in upcomingVisits) {
      try {
        final visitTime = _parseTimeString(visit.time);
        final visitDateTime = DateTime(
          now.year,
          now.month,
          now.day,
          visitTime.hour,
          visitTime.minute,
        );
        
        // If visit is in the future or within 15 minutes of now, it's our candidate
        if (visitDateTime.isAfter(now.subtract(const Duration(minutes: 15)))) {
          nextUpcoming = visit;
          break; // Take the first (earliest) upcoming visit
        }
      } catch (e) {
        debugPrint('Error comparing visit time: $e');
      }
    }
    
    // If we found an upcoming visit, use it; otherwise use the first in the list
    visitToShow = nextUpcoming ?? upcomingVisits.first;
    showingCompleted = false;
    
    debugPrint('🔍 Selected upcoming visit: ${visitToShow.time} - ${visitToShow.carePlanTitle}');
  } else if (completedVisits.isNotEmpty) {
    // Show the most recent completed visit (latest time = most recently completed)
    completedVisits.sort((a, b) {
      try {
        final timeA = _parseTimeString(a.time);
        final timeB = _parseTimeString(b.time);
        return timeB.compareTo(timeA); // Descending sort - latest time first
      } catch (e) {
        return 0;
      }
    });
    
    visitToShow = completedVisits.first; // This is now the most recently completed
    showingCompleted = true;
    
    debugPrint('🔍 Selected completed visit: ${visitToShow.time} - ${visitToShow.carePlanTitle}');
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Scheduled visits',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: -0.5,
                ),
              ),
              if (showingCompleted)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 14,
                        color: Color(0xFF199A8E),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'All visits completed today',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          TextButton(
            onPressed: () {
              debugPrint('🔵 Schedule See all pressed');
              debugPrint('🔵 onTabChange callback: ${widget.onTabChange != null ? "EXISTS" : "NULL"}');
              
              if (widget.onTabChange != null) {
                debugPrint('🔵 Calling onTabChange with index 2');
                widget.onTabChange!(2); // Index 2 = Schedule tab
              } else {
                debugPrint('🔴 Fallback: Using Navigator.push');
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SchedulePatientsScreen(
                      nurseData: widget.nurseData,
                    ),
                  ),
                );
              }
            },
            child: Row(
              children: [
                Text(
                  'See all',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      if (visitToShow == null)
        _buildEmptyState('No visits scheduled for today')
      else
        _buildScheduleCard(visitToShow),
    ],
  );
}

// Helper method to parse time strings like "9:00 AM" into DateTime
DateTime _parseTimeString(String timeStr) {
  try {
    // Remove extra spaces and split
    final parts = timeStr.trim().split(' ');
    if (parts.length != 2) throw FormatException('Invalid time format');
    
    final timeParts = parts[0].split(':');
    if (timeParts.length != 2) throw FormatException('Invalid time format');
    
    int hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);
    final period = parts[1].toUpperCase();
    
    // Convert to 24-hour format
    if (period == 'PM' && hour != 12) {
      hour += 12;
    } else if (period == 'AM' && hour == 12) {
      hour = 0;
    }
    
    return DateTime(2000, 1, 1, hour, minute); // Year/month/day don't matter for time comparison
  } catch (e) {
    debugPrint('Error parsing time string "$timeStr": $e');
    return DateTime(2000, 1, 1, 0, 0); // Default to midnight if parsing fails
  }
}

Widget _buildScheduleCard(ScheduleVisit visit) {
  String formattedCareType = visit.careType
      .split('_')
      .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
      .join(' ');

  bool isCompleted = visit.status.toLowerCase() == 'completed';

  return GestureDetector(
    onTap: () => _showScheduleDetailModal(visit),
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCompleted ? const Color(0xFF2D2D2D) : const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(20),
        border: isCompleted ? Border.all(
          color: const Color(0xFF199A8E).withOpacity(0.3),
          width: 2,
        ) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isCompleted ? 0.05 : 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date range row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    if (isCompleted) ...[
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF199A8E).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          color: Color(0xFF199A8E),
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            visit.dateRangeDisplay,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isCompleted
                                  ? const Color(0xFF199A8E)
                                  : Colors.white.withOpacity(0.9),
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            visit.timeRangeDisplay,
                            style: TextStyle(
                              fontSize: 12,
                              color: isCompleted
                                  ? const Color(0xFF199A8E).withOpacity(0.7)
                                  : Colors.white.withOpacity(0.6),
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? const Color(0xFF199A8E).withOpacity(0.1)
                      : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.arrow_forward_ios,
                  color: isCompleted
                      ? const Color(0xFF199A8E)
                      : Colors.white.withOpacity(0.7),
                  size: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            visit.carePlanTitle,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: isCompleted ? Colors.white : Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          if (isCompleted) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF199A8E).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF199A8E).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: Color(0xFF199A8E),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Completed',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF199A8E),
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (visit.timeCompleted != null && visit.timeCompleted!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 1,
                      height: 12,
                      color: const Color(0xFF199A8E).withOpacity(0.3),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.timer,
                      color: Color(0xFF199A8E),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      visit.timeCompleted!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF199A8E),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (visit.patient != null)
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? const Color(0xFF199A8E).withOpacity(0.1)
                        : const Color(0xFFE8F5F5),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      visit.patient!.name.substring(0, 1),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isCompleted
                            ? const Color(0xFF199A8E)
                            : const Color(0xFF2D2D2D),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        visit.patient!.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isCompleted
                              ? Colors.white
                              : Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Age ${visit.patient!.age} • $formattedCareType',
                        style: TextStyle(
                          fontSize: 12,
                          color: isCompleted
                              ? Colors.white.withOpacity(0.7)
                              : Colors.white.withOpacity(0.6),
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    ),
  );
}

  void _showScheduleDetailModal(ScheduleVisit visit) {
    bool isCompleted = visit.status?.toLowerCase() == 'completed';
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ValueListenableBuilder<int>(
        valueListenable: _elapsedSeconds,
        builder: (context, elapsedTime, child) {
          bool isActive = _activeScheduleId == visit.id;
          
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF199A8E).withOpacity(0.1),
                        const Color(0xFF199A8E).withOpacity(0.05),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Schedule Details',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          if (isCompleted)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF199A8E).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF199A8E).withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(
                                    Icons.check_circle,
                                    color: Color(0xFF199A8E),
                                    size: 14,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'COMPLETED',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF199A8E),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _getPriorityColor(visit.priority).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                visit.priority.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _getPriorityColor(visit.priority),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          visit.carePlanTitle,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 24),

                        if (visit.patient != null) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFB),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFF199A8E).withOpacity(0.2),
                                        const Color(0xFF199A8E).withOpacity(0.1),
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      visit.patient!.name.substring(0, 1),
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF199A8E),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        visit.patient!.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1A1A1A),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Age ${visit.patient!.age}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        _buildInfoGrid([
                          _buildInfoItem(
                            Icons.calendar_today_outlined,
                            'Date',
                            visit.dateRangeDisplay,
                          ),
                          _buildInfoItem(
                            Icons.access_time,
                            'Time',
                            visit.timeRangeDisplay,
                          ),
                          _buildInfoItem(
                            Icons.timer_outlined,
                            'Daily Duration',
                            visit.dailyDuration,
                          ),
                          _buildInfoItem(
                            Icons.date_range_outlined,
                            'Assignment',
                            visit.assignmentDuration,
                          ),
                          _buildInfoItem(
                            Icons.location_on_outlined,
                            'Location',
                            visit.location,
                          ),
                          _buildInfoItem(
                            Icons.medical_services_outlined,
                            'Care Type',
                            visit.careType.split('_').map((word) =>
                              word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1)
                            ).join(' '),
                          ),
                        ]),

                        const SizedBox(height: 32),

                        if (isCompleted)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF199A8E).withOpacity(0.1),
                                  const Color(0xFF199A8E).withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF199A8E).withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(
                                      Icons.check_circle,
                                      color: Color(0xFF199A8E),
                                      size: 24,
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Session Completed',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF199A8E),
                                      ),
                                    ),
                                  ],
                                ),
                                if (visit.timeCompleted != null && visit.timeCompleted!.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.timer,
                                          color: Color(0xFF199A8E),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Time Worked:',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF666666),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          visit.timeCompleted!,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF199A8E),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF199A8E).withOpacity(0.05),
                                  const Color(0xFF199A8E).withOpacity(0.02),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF199A8E).withOpacity(0.2),
                                width: 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _isTimerRunning && isActive
                                          ? Icons.timer
                                          : Icons.timer_outlined,
                                      color: const Color(0xFF199A8E),
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      _isTimerRunning && isActive
                                          ? 'Time Tracking Active'
                                          : 'Start Time Tracking',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF199A8E),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 20,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 10,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      _formatDuration(isActive ? elapsedTime : 0),
                                      style: TextStyle(
                                        fontSize: 48,
                                        fontWeight: FontWeight.bold,
                                        color: _isTimerRunning && isActive
                                            ? const Color(0xFF199A8E)
                                            : Colors.grey.shade400,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                        letterSpacing: 2,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                
                                Row(
                                  children: [
                                    Expanded(
                                      child: _isTimerRunning && isActive
                                          ? ElevatedButton.icon(
                                              onPressed: _isLoadingLocation ? null : () {
                                                _stopTimer();
                                                Navigator.of(context).pop();
                                              },
                                              icon: const Icon(Icons.stop_circle_outlined),
                                              label: const Text('Stop Timer'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFFFF4757),
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(vertical: 16),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                elevation: 0,
                                              ),
                                            )
                                          : ElevatedButton.icon(
                                              onPressed: _isLoadingLocation ? null : () {
                                                Navigator.of(context).pop();
                                                _startTimer(visit.id);
                                              },
                                              icon: _isLoadingLocation
                                                  ? const SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                      ),
                                                    )
                                                  : const Icon(Icons.play_circle_outline),
                                              label: Text(_isLoadingLocation ? 'Getting Location...' : 'Start Timer'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF199A8E),
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(vertical: 16),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                elevation: 0,
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                                
                                if (_isTimerRunning && isActive) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    'Recording time for this visit...',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _calculateEndTime(String startTime, String duration) {
  try {
    // Parse start time (e.g., "02:00 PM")
    final timeParts = startTime.trim().split(' ');
    if (timeParts.length != 2) return startTime;
    
    final time = timeParts[0].split(':');
    if (time.length != 2) return startTime;
    
    int hour = int.parse(time[0]);
    final minute = int.parse(time[1]);
    final period = timeParts[1].toUpperCase();
    
    // Convert to 24-hour format
    if (period == 'PM' && hour != 12) {
      hour += 12;
    } else if (period == 'AM' && hour == 12) {
      hour = 0;
    }
    
    // Parse duration (e.g., "1h 30m", "45m", "2h")
    int durationHours = 0;
    int durationMinutes = 0;
    
    final durationLower = duration.toLowerCase().trim();
    
    // Extract hours
    final hourMatch = RegExp(r'(\d+)\s*h').firstMatch(durationLower);
    if (hourMatch != null) {
      durationHours = int.parse(hourMatch.group(1)!);
    }
    
    // Extract minutes
    final minMatch = RegExp(r'(\d+)\s*m').firstMatch(durationLower);
    if (minMatch != null) {
      durationMinutes = int.parse(minMatch.group(1)!);
    }
    
    // Calculate end time
    int endHour = hour + durationHours;
    int endMinute = minute + durationMinutes;
    
    // Handle minute overflow
    if (endMinute >= 60) {
      endHour += endMinute ~/ 60;
      endMinute = endMinute % 60;
    }
    
    // Handle hour overflow
    if (endHour >= 24) {
      endHour = endHour % 24;
    }
    
    // Convert back to 12-hour format
    String endPeriod = 'AM';
    int displayHour = endHour;
    
    if (endHour >= 12) {
      endPeriod = 'PM';
      if (endHour > 12) {
        displayHour = endHour - 12;
      }
    }
    if (endHour == 0) {
      displayHour = 12;
    }
    
    // Format the end time
    return '${displayHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')} $endPeriod';
    
  } catch (e) {
    debugPrint('Error calculating end time: $e');
    return startTime;
  }
}

  Widget _buildInfoGrid(List<Widget> items) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.35,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: items,
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14), 
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min, 
        children: [
          Icon(
            icon,
            size: 18, 
            color: const Color(0xFF199A8E),
          ),
          const SizedBox(height: 6), 
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3), 
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'critical':
      case 'high':
        return const Color(0xFFFF4757);
      case 'medium':
        return const Color(0xFFFF9A00);
      case 'low':
        return const Color(0xFF199A8E);
      default:
        return const Color(0xFF199A8E);
    }
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 2.2,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            padding: EdgeInsets.zero,
            children: [
              _buildActionTile(
                icon: Icons.monitor_heart_outlined,
                title: 'Assessment',
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF8B84FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                onTap: () async {
                  // Navigate to care requests list instead of direct assessment
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NurseCareRequestsListScreen(
                        nurseData: widget.nurseData,
                      ),
                    ),
                  );
                  
                  if (result == true) {
                    _loadDashboardData(forceRefresh: true, silent: true);
                  }
                },
              ),
              _buildActionTile(
                icon: Icons.report_problem_outlined,
                title: 'Incident Report',
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF9A00), Color(0xFFFFB347)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                onTap: () async {
                  // Navigate to Incident Report Screen
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NurseIncidentReportScreen(
                        nurseData: widget.nurseData,
                      ),
                    ),
                  );
                  
                  // Refresh dashboard if incident was created successfully
                  if (result == true) {
                    _loadDashboardData(forceRefresh: true, silent: true);
                  }
                },
              ),
              _buildActionTile(
                icon: Icons.emergency_outlined,
                title: 'Emergency',
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF4757), Color(0xFFFF6B7A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                onTap: _callEmergencyServices,
              ),
              _buildActionTile(
                icon: Icons.local_taxi_outlined,
                title: 'Transport',
                gradient: const LinearGradient(
                  colors: [Color(0xFF00D2FF), Color(0xFF3A7BD5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TransportRequestScreen(
                        userData: widget.nurseData,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required LinearGradient gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyPatients() {
    final upcomingPatients = _dashboardData!.upcomingPatients.take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'My patients',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
                letterSpacing: -0.5,
              ),
            ),
            TextButton(
              onPressed: () {
                if (widget.onTabChange != null) {
                  widget.onTabChange!(1); // Index 1 is Patients tab
                }
              },
              child: Row(
                children: [
                  Text(
                    'See all',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (upcomingPatients.isEmpty)
          _buildEmptyState('No upcoming patient visits')
        else
          ...upcomingPatients.map((patient) => _buildModernPatientCard(patient)).toList(),
      ],
    );
  }

Widget _buildModernPatientCard(UpcomingPatient patient) {
  if (patient.patient == null) return const SizedBox();

  Color priorityColor = _getPriorityColor(patient.priority);
  String priorityText = patient.priority.toUpperCase();

  return GestureDetector(
    onTap: () => _showPatientScheduleDetails(patient),
    child: Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF199A8E).withOpacity(0.1),
                        const Color(0xFF199A8E).withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF199A8E).withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Color(0xFF199A8E),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              patient.patient!.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A),
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: priorityColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              priorityText,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: priorityColor,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Age ${patient.patient!.age}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        patient.careType,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF2D2D2D),
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (patient.totalSchedules > 1) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF199A8E).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${patient.totalSchedules} upcoming visits',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF199A8E),
                            ),
                          ),
                        ),
                      ],
                      if (patient.patient!.lastVitals != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFB),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildVitalMini(
                                Icons.favorite_outline,
                                patient.patient!.lastVitals!.bloodPressure,
                                'BP',
                              ),
                              _buildVitalMini(
                                Icons.thermostat_outlined,
                                '${patient.patient!.lastVitals!.temperature}°C',
                                'Temp',
                              ),
                              _buildVitalMini(
                                Icons.monitor_heart_outlined,
                                '${patient.patient!.lastVitals!.pulse} bpm',
                                'Pulse',
                              ),
                              _buildVitalMini(
                                Icons.air,
                                '${patient.patient!.lastVitals!.spo2}%',
                                'SpO₂',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFB),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule_outlined,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              patient.dateRangeDisplay,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade800,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${patient.timeRangeDisplay} • ${patient.timeUntil}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF199A8E),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_forward,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  void _showPatientScheduleDetails(UpcomingPatient patient) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFB),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF199A8E).withOpacity(0.1),
                              const Color(0xFF199A8E).withOpacity(0.05),
                            ],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF199A8E).withOpacity(0.2),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Color(0xFF199A8E),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              patient.patient!.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Age ${patient.patient!.age} • ${patient.careType}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Upcoming Visits (${patient.totalSchedules})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  ...patient.upcomingSchedules.map((schedule) => 
                    _buildScheduleDetailCard(schedule)
                  ).toList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleDetailCard(ScheduleInfo schedule) {
    bool isToday = schedule.isToday;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isToday ? const Color(0xFF2D2D2D) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isToday ? Colors.transparent : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      isToday ? Icons.calendar_today : Icons.calendar_month_outlined,
                      size: 16,
                      color: isToday ? Colors.white70 : const Color(0xFF199A8E),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        schedule.dateRangeDisplay,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isToday ? Colors.white70 : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isToday)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF199A8E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'TODAY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Display time range (start - end) or just start time
          Text(
            schedule.timeRangeDisplay,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isToday ? Colors.white : const Color(0xFF1A1A1A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          
          // Display "time until" information
          Text(
            schedule.timeUntil,
            style: TextStyle(
              fontSize: 13,
              color: isToday ? Colors.white70 : Colors.grey.shade600,
            ),
          ),
          
          const SizedBox(height: 12),
          Divider(color: isToday ? Colors.white24 : Colors.grey.shade200),
          const SizedBox(height: 12),
          
          // Location
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 16,
                color: isToday ? Colors.white70 : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  schedule.location,
                  style: TextStyle(
                    fontSize: 13,
                    color: isToday ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Duration - now showing the actual duration from backend
          Row(
            children: [
              Icon(
                Icons.timer_outlined,
                size: 16,
                color: isToday ? Colors.white70 : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Duration: ${schedule.dailyDuration}${schedule.isMultiDay ? ' (${schedule.assignmentDuration})' : ''}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isToday ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVitalMini(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(
          icon,
          size: 18,
          color: const Color(0xFF199A8E),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
            letterSpacing: -0.2,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade500,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF199A8E).withOpacity(0.05),
            const Color(0xFF199A8E).withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF199A8E).withOpacity(0.15),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF199A8E).withOpacity(0.15),
                  const Color(0xFF199A8E).withOpacity(0.1),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF199A8E).withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.event_available_outlined,
              size: 22,
              color: Color(0xFF199A8E),
            ),
          ),
          
          const SizedBox(width: 16),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'All Clear',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
          
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF199A8E).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 16,
              color: Color(0xFF199A8E),
            ),
          ),
        ],
      ),
    );
  }

  void _callEmergencyServices() async {
    const emergencyNumber = '112';
    const ambulanceNumber = '193';
    const policeNumber = '191';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE5E5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.emergency,
                color: Color(0xFFFF4757),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Emergency Services',
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Select emergency service to call:',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 16),
            
            _buildEmergencyOption(
              context: context,
              icon: Icons.emergency_outlined,
              title: 'General Emergency',
              number: emergencyNumber,
              color: const Color(0xFFFF4757),
            ),
            
            const SizedBox(height: 12),
            
            _buildEmergencyOption(
              context: context,
              icon: Icons.local_hospital_outlined,
              title: 'Ambulance',
              number: ambulanceNumber,
              color: const Color(0xFFFF9A00),
            ),
            
            const SizedBox(height: 12),
            
            _buildEmergencyOption(
              context: context,
              icon: Icons.local_police_outlined,
              title: 'Police',
              number: policeNumber,
              color: const Color(0xFF199A8E),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String number,
    required Color color,
  }) {
    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        _confirmEmergencyCall(title, number);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
          color: color.withOpacity(0.05),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    number,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.phone,
              color: color,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  void _confirmEmergencyCall(String serviceName, String phoneNumber) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE5E5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.phone,
                color: Color(0xFFFF4757),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Confirm Call',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to call $serviceName ($phoneNumber)?',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF4757), Color(0xFFFF6B7A)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _makeEmergencyCall(phoneNumber);
              },
              child: const Text(
                'Call Now',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _makeEmergencyCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
        _showSuccessSnackbar('Calling $phoneNumber...');
      } else {
        _showErrorSnackbar('Unable to make phone calls on this device');
      }
    } catch (e) {
      debugPrint('❌ Error making emergency call: $e');
      _showErrorSnackbar('Failed to initiate call. Error: ${e.toString()}');
    }
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF199A8E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFFF4757),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showInfoSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF199A8E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Check if active timer's schedule is completed in dashboard data
  void _checkAndStopCompletedTimer() {
    if (!_isTimerRunning || _activeScheduleId == null || _dashboardData == null) {
      return;
    }

    // Find the schedule in dashboard data
    final activeSchedule = _dashboardData!.scheduleVisits.firstWhere(
      (visit) => visit.id == _activeScheduleId,
      orElse: () => _dashboardData!.scheduleVisits.first,
    );

    // If the schedule is completed, stop the local timer
    if (activeSchedule.status?.toLowerCase() == 'completed') {
      debugPrint('⚠️ Active schedule is completed - auto-stopping timer');
      
      _stopLocalTimer();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Session completed - Timer stopped'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF199A8E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}