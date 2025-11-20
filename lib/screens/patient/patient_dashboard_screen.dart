import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/app_colors.dart';
import 'patient_feedback_screen.dart';
import '../../utils/string_utils.dart';
import '../../services/dashboard/dashboard_service.dart';
import '../../models/dashboard/patient_dashboard_models.dart';
import '../transport/transport_request_screen.dart';
import 'care_request_screen.dart';
import '../../services/care_request_service.dart';
import 'care_request_lists_screen.dart';
import '../modern_notifications_sheet.dart';
import '../../services/notification_service.dart';

class PatientDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> patientData;
  final Function(int)? onTabChange;

  const PatientDashboardScreen({
    Key? key,
    required this.patientData,
    this.onTabChange,
  }) : super(key: key);

  @override
  // CRITICAL: State class must be PUBLIC (no underscore) for GlobalKey access
  PatientDashboardScreenState createState() => PatientDashboardScreenState();
}

// CRITICAL: PUBLIC state class (no underscore prefix)
class PatientDashboardScreenState extends State<PatientDashboardScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  final _dashboardService = DashboardService();

  bool _isLoading = true;
  String? _errorMessage;
  PatientDashboardData? _dashboardData;

  // Cache management
  DateTime? _lastFetchTime;
  DateTime? _lastRefreshAttempt;
  static const Duration _cacheValidityDuration = Duration(minutes: 2);
  static const Duration _minRefreshInterval = Duration(seconds: 30);
  static const Duration _backgroundReturnThreshold = Duration(minutes: 2);

  final NotificationService _notificationService = NotificationService();
  int _unreadNotificationCount = 0;
  // 🔥 REMOVED: No more polling timer!
  // Timer? _notificationPollingTimer;

  // Visibility tracking
  bool _isTabVisible = false;
  DateTime? _lastVisibleTime;

  // Screen visibility tracking for battery optimization
  bool _isScreenVisible = true;

  // CRITICAL: Keep state alive when switching tabs
  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // 🔥 REMOVED: No more polling timer to cancel!
    // _notificationPollingTimer?.cancel();
    
    // Clean up FCM callback
    _notificationService.onNotificationCountChanged = null;
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isTabVisible = true;
    _lastVisibleTime = DateTime.now();
    _loadDashboardData(forceRefresh: false);
    
    // ⚡ NEW: Set up real-time FCM notification updates
    _setupFcmNotificationUpdates();
    
    // Load initial count once (no polling!)
    _loadUnreadNotificationCount();
  }

  // OPTIMIZED: Detect app lifecycle changes for battery saving
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isScreenVisible = true;
      
      if (_isTabVisible) {
        // Smart refresh: Only if data is actually stale
        final shouldRefresh = _lastFetchTime == null || 
            DateTime.now().difference(_lastFetchTime!) >= Duration(minutes: 5);
        
        if (shouldRefresh) {
          _loadDashboardData(forceRefresh: true, silent: true);
        }
        
        // Always refresh lightweight notification count
        _loadUnreadNotificationCount();
      }
    }
  }

  // ==================== FCM REAL-TIME UPDATES ====================

  /// ⚡ Set up FCM callback for real-time notification count updates
  /// This eliminates the need for polling!
  void _setupFcmNotificationUpdates() {
    debugPrint('⚡ [Dashboard] Setting up FCM real-time notification updates');
    
    _notificationService.onNotificationCountChanged = (newCount) {
      if (mounted) {
        setState(() {
          _unreadNotificationCount = newCount;
        });
        debugPrint('🔔 [Dashboard] Notification count updated in real-time: $newCount');
      }
    };
  }

  /// Load unread notification count (only called once on init and resume)
  Future<void> _loadUnreadNotificationCount() async {
    try {
      final response = await _notificationService.getUnreadCount();
      if (mounted) {
        setState(() {
          _unreadNotificationCount = response.unreadCount;
        });
        debugPrint('📊 [Dashboard] Initial notification count loaded: ${response.unreadCount}');
      }
    } catch (e) {
      debugPrint('❌ [Dashboard] Error loading unread count: $e');
    }
  }

  // 🔥 REMOVED: No more polling timer!
  /*
  void _startNotificationPolling() {
    _notificationPollingTimer = Timer.periodic(
      const Duration(minutes: 2),
      (timer) {
        if (_isTabVisible && _isScreenVisible) {
          _loadUnreadNotificationCount();
        }
      },
    );
  }
  */

  /// Open notifications sheet (new modern bottom sheet)
  void _openNotificationsSheet() async {
    await showNotificationsSheet(context);
    
    // Refresh count after closing (in case user marked as read)
    _loadUnreadNotificationCount();
  }

  // ==================== PUBLIC METHODS FOR PARENT NAVIGATION ====================

  /// Public method to trigger manual refresh (called by parent)
  void loadDashboard({bool forceRefresh = false}) {
    _loadDashboardData(forceRefresh: forceRefresh);
  }

  // ==================== SMART REFRESH LOGIC ====================

  /// Called by parent when tab becomes visible
  void onTabVisible() {
    _isTabVisible = true;
    final now = DateTime.now();

    debugPrint('👁️ Dashboard tab visible - checking if refresh needed');

    // Calculate time since last visible
    final timeSinceLastVisible = _lastVisibleTime != null
        ? now.difference(_lastVisibleTime!)
        : null;

    _lastVisibleTime = now;

    // Determine if we should refresh
    if (_shouldRefreshOnVisible(timeSinceLastVisible)) {
      final reason = _getRefreshReason(timeSinceLastVisible);
      debugPrint('🔄 Refreshing dashboard: $reason');
      _loadDashboardData(forceRefresh: true, silent: true);
      _loadUnreadNotificationCount(); // Refresh count when tab visible
    } else {
      debugPrint('📦 Using cached data - no refresh needed');
    }
  }

  /// Called by parent when tab becomes hidden
  void onTabHidden() {
    _isTabVisible = false;
    debugPrint('👁️‍🗨️ Dashboard tab hidden');
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
    // Rate limiting check
    if (!forceRefresh && _lastRefreshAttempt != null) {
      final timeSinceLastAttempt = DateTime.now().difference(_lastRefreshAttempt!);
      if (timeSinceLastAttempt < _minRefreshInterval) {
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

    debugPrint('🌐 Fetching patient dashboard from API...');

    try {
      final data = await _dashboardService.getPatientMobileDashboard();

      if (mounted) {
        setState(() {
          _dashboardData = data;
          _lastFetchTime = DateTime.now();
          _isLoading = false;
        });

        debugPrint('✅ Dashboard loaded (${_cacheAge})');

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

  /// Show notification when data updates in background
  void _showDataUpdatedNotification() {
    if (!mounted) return;

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

  @override
  Widget build(BuildContext context) {
    // CRITICAL: Must call super.build when using AutomaticKeepAliveClientMixin
    super.build(context);
    
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
              _buildHealthMetrics(),
              const SizedBox(height: 32),
              _buildScheduledVisits(),
              const SizedBox(height: 32),
              _buildQuickActions(),
              const SizedBox(height: 32),
              _buildMyNurses(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGreeting() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, ${widget.patientData['name']?.split(' ')[0] ?? 'Patient'}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'How are you feeling today?',
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
              widget.patientData['name']?.substring(0, 1) ?? 'P',
              style: const TextStyle(
                color: Color(0xFF199A8E),
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
        ),
      ],
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
                icon: Icons.people_outline,
                label: 'Nurses Today',
                value: '${_dashboardData!.nursesToday}',
                iconColor: const Color(0xFF6C63FF),
                bgColor: const Color(0xFFEDE9FF),
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
                iconColor: const Color(0xFFFF6B6B),
                bgColor: const Color(0xFFFFE5E5),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.calendar_today_outlined,
                label: 'Weekly Visits',
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
    return Container(
      padding: const EdgeInsets.all(16),
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 20,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
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

  Widget _buildScheduledVisits() {
    final todayVisits = _dashboardData!.scheduleVisits
        .where((visit) => visit.dateDisplay == 'Today')
        .toList();

    final upcomingVisits = todayVisits
        .where((visit) =>
            visit.status.toLowerCase() != 'completed' &&
            visit.status.toLowerCase() != 'cancelled')
        .toList();

    final completedVisits = todayVisits
        .where((visit) => visit.status.toLowerCase() == 'completed')
        .toList();

    // Show upcoming visit first, otherwise show completed
    final visitToShow = upcomingVisits.isNotEmpty
        ? upcomingVisits.first
        : (completedVisits.isNotEmpty ? completedVisits.first : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
            TextButton(
              onPressed: () {
                if (widget.onTabChange != null) {
                  widget.onTabChange!(2); // Care Plans tab
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

  Widget _buildScheduleCard(ScheduleVisit visit) {
    String timeRange = visit.endTime != null
        ? '${visit.time} - ${visit.endTime}'
        : visit.time;

    bool isCompleted = visit.status.toLowerCase() == 'completed';

    return GestureDetector(
      onTap: () => _showScheduleDetailModal(visit),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2D2D2D),
          borderRadius: BorderRadius.circular(20),
          border: isCompleted
              ? Border.all(
                  color: const Color(0xFF199A8E).withOpacity(0.3),
                  width: 2,
                )
              : null,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
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
                    Text(
                      timeRange,
                      style: TextStyle(
                        fontSize: 13,
                        color: isCompleted
                            ? const Color(0xFF199A8E)
                            : Colors.white.withOpacity(0.7),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
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
                    if (visit.duration.isNotEmpty && visit.duration != '0m') ...[
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
                        visit.durationCompleted!,
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
            if (visit.nurse != null)
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
                        visit.nurse!.name.substring(0, 1),
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
                          visit.nurse!.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isCompleted ? Colors.white : Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          StringUtils.formatCareType(visit.nurse!.specialization ?? visit.careType),
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
  bool isCompleted = visit.status.toLowerCase() == 'completed';
  
  // Use completed duration if available, otherwise scheduled duration
  String durationDisplay = visit.duration;
  if (isCompleted && visit.durationCompleted != null && visit.durationCompleted!.isNotEmpty) {
    durationDisplay = visit.durationCompleted!;
  } else if (visit.duration.isEmpty || visit.duration == '0m') {
    durationDisplay = 'Not recorded';
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
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
          // HEADER
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFB),
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
                      'Visit Details',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    if (isCompleted)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
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
                      ),
                  ],
                ),
              ],
            ),
          ),
          
          // SCROLLABLE CONTENT
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
                  
                  // NURSE INFO
                  if (visit.nurse != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF199A8E).withOpacity(0.1),
                            const Color(0xFF199A8E).withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF199A8E).withOpacity(0.2),
                        ),
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
                                  visit.nurse!.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  StringUtils.formatCareType(
                                      visit.nurse!.specialization ?? 'Nurse'),
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
                  
                  // INFO GRID
                  _buildInfoGrid([
                    _buildInfoItem(
                      Icons.access_time,
                      'Scheduled Time',
                      visit.endTime != null
                          ? '${visit.time} - ${visit.endTime}'
                          : visit.time,
                    ),
                    _buildInfoItem(
                      Icons.timer_outlined,
                      'Planned Duration',
                      visit.duration,
                    ),
                    _buildInfoItem(
                      Icons.location_on_outlined,
                      'Location',
                      visit.location,
                    ),
                    _buildInfoItem(
                      Icons.medical_services_outlined,
                      'Care Type',
                      StringUtils.formatCareType(visit.careType),
                    ),
                  ]),
                ],
              ),
            ),
          ),
          
          // BOTTOM SECTION - Total Completed Duration
          if (isCompleted && visit.durationCompleted != null && 
              visit.durationCompleted!.isNotEmpty && visit.durationCompleted != '0m')
            Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF199A8E).withOpacity(0.1),
                      const Color(0xFF199A8E).withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF199A8E).withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF199A8E).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.schedule,
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
                                'Total Visit Duration',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                visit.durationCompleted!,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF199A8E),
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF199A8E),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                visit.durationCompleted!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // Show comparison if actual differs from planned
                    if (visit.duration != visit.durationCompleted) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Planned: ${visit.duration}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

  Widget _buildInfoGrid(List<Widget> items) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.5,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: items,
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 20,
            color: const Color(0xFF199A8E),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
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
                  icon: Icons.medical_services_outlined,
                  title: 'Request Care',
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF8B84FF)],
                  ),
                  onTap: () async {
                    // Check if user has existing care requests
                    await _navigateToCareRequest();
                  },
                ),
                _buildActionTile(
                icon: Icons.local_taxi_outlined,
                title: 'Transport',
                gradient: const LinearGradient(
                    colors: [Color(0xFF00D2FF), Color(0xFF3A7BD5)],
                ),
                onTap: () {
                    Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => TransportRequestScreen(
                        userData: widget.patientData,
                        ),
                    ),
                    );
                },
                ),
              _buildActionTile(
                icon: Icons.emergency_outlined,
                title: 'Emergency',
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF4757), Color(0xFFFF6B7A)],
                ),
                onTap: _callEmergencyServices,
              ),
              _buildActionTile(
                icon: Icons.feedback_outlined,
                title: 'Feedback',
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF9A00), Color(0xFFFFB347)],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PatientFeedbackScreen(),
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

  Future<void> _navigateToCareRequest() async {
  // Show loading indicator
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const Center(
      child: CircularProgressIndicator(
        color: Color(0xFF199A8E),
      ),
    ),
  );

  try {
    final careRequestService = CareRequestService();
    final response = await careRequestService.getCareRequests(page: 1, perPage: 1);
    
    if (mounted) {
      Navigator.pop(context); // Close loading dialog
      
      if (response.data.isEmpty) {
        // No requests, go directly to create screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CareRequestScreen(
              patientData: widget.patientData,
            ),
          ),
        );
      } else {
        // Has requests, show list screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CareRequestListsScreen(
              patientData: widget.patientData,
            ),
          ),
        );
      }
    }
  } catch (e) {
    if (mounted) {
      Navigator.pop(context); // Close loading dialog
      
      // On error, go to create screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CareRequestScreen(
            patientData: widget.patientData,
          ),
        ),
      );
    }
  }
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

  Widget _buildMyNurses() {
    final upcomingNurses = _dashboardData!.upcomingNurses.take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'My nurses',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        if (upcomingNurses.isEmpty)
          _buildEmptyState('No upcoming nurse visits')
        else
          ...upcomingNurses.map((nurse) => _buildNurseCard(nurse)).toList(),
      ],
    );
  }

Widget _buildNurseCard(UpcomingNurse nurseVisit) {
  Color priorityColor = _getPriorityColor(nurseVisit.priority);
  String timeDisplay = nurseVisit.scheduledTime;
  if (nurseVisit.endTime != null && nurseVisit.endTime!.isNotEmpty) {
    timeDisplay = '${nurseVisit.scheduledTime} - ${nurseVisit.endTime}';
  }

  return Container(
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
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showNurseDetailsModal(nurseVisit),
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                          ),
                          shape: BoxShape.circle,
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
                              nurseVisit.nurse.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              StringUtils.formatCareType(
                                  nurseVisit.nurse.specialization ?? 'Nurse'),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              StringUtils.formatCareType(nurseVisit.careType),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF2D2D2D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (nurseVisit.currentVitals != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFB),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.monitor_heart_outlined,
                                size: 16,
                                color: Color(0xFF199A8E),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Your Latest Vitals Picked By Nurse',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildVitalMini(
                                Icons.favorite_outline,
                                nurseVisit.currentVitals!.bloodPressure,
                                'BP',
                              ),
                              _buildVitalMini(
                                Icons.thermostat_outlined,
                                '${nurseVisit.currentVitals!.temperature}',
                                'Temp',
                              ),
                              _buildVitalMini(
                                Icons.monitor_heart_outlined,
                                '${nurseVisit.currentVitals!.pulse}',
                                'Pulse',
                              ),
                              _buildVitalMini(
                                Icons.air,
                                '${nurseVisit.currentVitals!.spo2}',
                                'SpO₂',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
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
                                timeDisplay,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                nurseVisit.timeUntil,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
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
    ),
  );
}

void _showNurseDetailsModal(UpcomingNurse nurseVisit) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Header
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
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF199A8E).withOpacity(0.2),
                            const Color(0xFF199A8E).withOpacity(0.1),
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Color(0xFF199A8E),
                        size: 36,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nurseVisit.nurse.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            StringUtils.formatCareType(
                                nurseVisit.nurse.specialization ?? 'Nurse'),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Contact Information
                  _buildSectionTitle('Contact Information'),
                  const SizedBox(height: 12),
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
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF199A8E).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.phone,
                            color: Color(0xFF199A8E),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Phone Number',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                nurseVisit.nurse.phone ?? 'Not available',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (nurseVisit.nurse.phone != null)
                          IconButton(
                            onPressed: () => _callNurse(nurseVisit.nurse.phone!),
                            icon: const Icon(Icons.phone_forwarded),
                            color: const Color(0xFF199A8E),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Next Visit
                  _buildSectionTitle('Next Visit'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF199A8E).withOpacity(0.1),
                          const Color(0xFF199A8E).withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF199A8E).withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF199A8E).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.calendar_today,
                                color: Color(0xFF199A8E),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nurseVisit.scheduledDate,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${nurseVisit.scheduledTime}${nurseVisit.endTime != null ? ' - ${nurseVisit.endTime}' : ''}',
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
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 16,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                nurseVisit.timeUntil,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF199A8E).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  nurseVisit.duration,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF199A8E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Care Type & Location
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFB),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.medical_services_outlined,
                                color: Color(0xFF199A8E),
                                size: 20,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Care Type',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                StringUtils.formatCareType(nurseVisit.careType),
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
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFB),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                color: Color(0xFF199A8E),
                                size: 20,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Location',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                nurseVisit.location,
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
                        ),
                      ),
                    ],
                  ),

                  // Latest Vitals if available
                  if (nurseVisit.currentVitals != null) ...[
                    const SizedBox(height: 24),
                    _buildSectionTitle('Your Latest Vitals Picked By Nurse'),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildVitalDetail(
                                Icons.favorite,
                                'Blood Pressure',
                                nurseVisit.currentVitals!.bloodPressure,
                              ),
                              _buildVitalDetail(
                                Icons.thermostat,
                                'Temperature',
                                '${nurseVisit.currentVitals!.temperature}°F',
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildVitalDetail(
                                Icons.monitor_heart,
                                'Pulse',
                                '${nurseVisit.currentVitals!.pulse} bpm',
                              ),
                              _buildVitalDetail(
                                Icons.air,
                                'SpO₂',
                                '${nurseVisit.currentVitals!.spo2}%',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Upcoming Schedules
                  if (nurseVisit.totalSchedules > 1) ...[
                    const SizedBox(height: 24),
                    _buildSectionTitle(
                        'Upcoming Visits (${nurseVisit.totalSchedules})'),
                    const SizedBox(height: 12),
                    ...nurseVisit.upcomingSchedules.map((schedule) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    schedule.scheduledDate,  
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                  ),
                                  Text(
                                    schedule.scheduledTime, 
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF199A8E).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                schedule.duration,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF199A8E),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildVitalDetail(IconData icon, String label, String value) {
  return Column(
    children: [
      Icon(
        icon,
        size: 24,
        color: const Color(0xFF199A8E),
      ),
      const SizedBox(height: 8),
      Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: Colors.grey.shade600,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1A1A1A),
        ),
      ),
    ],
  );
}

Widget _buildSectionTitle(String title) {
  return Row(
    children: [
      Container(
        width: 4,
        height: 20,
        decoration: BoxDecoration(
          color: const Color(0xFF199A8E),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 12),
      Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1A1A1A),
        ),
      ),
    ],
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
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade500,
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
                colors: [
                  const Color(0xFF199A8E).withOpacity(0.15),
                  const Color(0xFF199A8E).withOpacity(0.1),
                ],
              ),
              shape: BoxShape.circle,
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
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
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
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
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
      } else {
        _showErrorSnackbar('Unable to make phone calls');
      }
    } catch (e) {
      _showErrorSnackbar('Failed to make call');
    }
  }

  Future<void> _callNurse(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);

    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        _showErrorSnackbar('Unable to make phone calls');
      }
    } catch (e) {
      _showErrorSnackbar('Failed to make call');
    }
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
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFFF4757),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}