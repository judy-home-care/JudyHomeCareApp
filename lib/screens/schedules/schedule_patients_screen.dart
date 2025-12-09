import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/app_colors.dart';
import '../../services/schedules/schedule_service.dart';
import '../../models/schedules/schedule_models.dart';
import '../../services/notification_service.dart';
import '../modern_notifications_sheet.dart';
import 'dart:async';

class SchedulePatientsScreen extends StatefulWidget {
  final Map<String, dynamic> nurseData;
  
  const SchedulePatientsScreen({
    Key? key,
    required this.nurseData,
  }) : super(key: key);

  @override
  State<SchedulePatientsScreen> createState() => _SchedulePatientsScreenState();
}

class _SchedulePatientsScreenState extends State<SchedulePatientsScreen>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin, WidgetsBindingObserver {

  // Shimmer animation controller
  late AnimationController _shimmerController;
  bool _isControllerInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _isControllerInitialized = true;
    _loadSchedules();

    // Set up FCM notification updates
    _setupFcmNotificationUpdates();
    _loadUnreadNotificationCount();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shimmerController.dispose();
    _debounceTimer?.cancel();

    // Clean up FCM listeners (multi-listener pattern)
    _removeCountListener?.call();
    _removeReceivedListener?.call();

    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  // ==================== APP LIFECYCLE ====================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      _isScreenVisible = true;
      debugPrint('🔄 [Schedules] App resumed - checking for pending notifications');

      // Check if notification was received while in background (from tapping notification)
      final hasBackgroundNotification = _notificationService.hasNotificationWhileBackground;

      // Check if notification was received while app was paused (local tracking)
      final hasPendingRefresh = _pendingNotificationRefresh;

      // Force refresh if any notification was received while away
      if (hasBackgroundNotification || hasPendingRefresh) {
        debugPrint('📱 [Schedules] Notification received while away - forcing refresh');
        debugPrint('   - Background notification (tapped): $hasBackgroundNotification');
        debugPrint('   - Pending refresh (received while paused): $hasPendingRefresh');

        // Clear both flags
        _notificationService.clearBackgroundNotificationFlag();
        _pendingNotificationRefresh = false;

        // Force data reload
        _loadSchedules(forceRefresh: true, silent: true);
      }

      // Refresh notification count
      _notificationService.refreshBadge();
    } else if (state == AppLifecycleState.paused) {
      _isScreenVisible = false;
      debugPrint('⏸️ [Schedules] App paused');
    }
  }

  // ==================== FCM NOTIFICATION UPDATES ====================

  /// Set up FCM callback for real-time notification count updates
  /// Uses multi-listener pattern so all screens get updates!
  void _setupFcmNotificationUpdates() {
    debugPrint('⚡ [Schedules] Setting up FCM real-time notification updates (multi-listener)');

    // Update notification badge count - using multi-listener pattern
    _removeCountListener = _notificationService.addNotificationCountListener((newCount) {
      if (mounted) {
        setState(() {
          _unreadNotificationCount = newCount;
        });
        debugPrint('🔔 [Schedules] Notification count updated: $newCount');
      }
    });

    // Refresh data when notification received (foreground or background)
    _removeReceivedListener = _notificationService.addNotificationReceivedListener(() {
      if (mounted) {
        if (_isScreenVisible) {
          // App is in foreground - refresh data immediately
          debugPrint('🔄 [Schedules] Notification received (foreground) - triggering silent refresh');
          _loadSchedules(forceRefresh: true, silent: true);
          // NOTE: Don't call _loadUnreadNotificationCount() here!
          // The badge count is already updated via the count listener
        } else {
          // App is in background/paused - set flag to refresh on resume
          debugPrint('🔄 [Schedules] Notification received (background) - setting pending refresh flag');
          _pendingNotificationRefresh = true;
        }
      }
    });
  }

  /// Load unread notification count
  Future<void> _loadUnreadNotificationCount() async {
    try {
      await _notificationService.refreshBadge();
      debugPrint('📊 [Schedules] Badge refreshed');
    } catch (e) {
      debugPrint('❌ [Schedules] Error refreshing badge: $e');
    }
  }

  /// Open notifications sheet
  void _openNotificationsSheet() async {
    await showNotificationsSheet(context);
    await _notificationService.refreshBadge();
    debugPrint('🔔 [Schedules] Badge refreshed after closing notifications');
  }

  // ==================== END NOTIFICATION UPDATES ====================

  final _ScheduleService = ScheduleService();
  
  // Smart cache management (like dashboard)
  final Map<String, List<ScheduleItem>> _scheduleCache = {};
  final Map<String, Map<String, int>> _countsCache = {};
  DateTime? _lastFetchTime;
  DateTime? _lastRefreshAttempt;
  String? _lastCacheKeyFetched; // Track which data was last fetched
  static const Duration _cacheValidityDuration = Duration(minutes: 2);
  static const Duration _minRefreshInterval = Duration(seconds: 30);
  static const Duration _backgroundReturnThreshold = Duration(minutes: 2);
  
  // Visibility tracking
  bool _isTabVisible = false;
  DateTime? _lastVisibleTime;
  
  Timer? _debounceTimer;
  
  DateTime _selectedDate = DateTime.now();
  DateTime _currentWeekStart = DateTime.now().subtract(
    Duration(days: DateTime.now().weekday % 7),
  );
  
  String _selectedTab = 'upcoming';
  String _selectedFilter = 'All Shifts';
  String _selectedStatusFilter = 'All Status';
  
  bool _isLoading = true;
  String? _errorMessage;
  List<ScheduleItem> _schedules = [];
  Map<String, int>? _counts;

  final List<String> _shiftTypeFilters = [
    'All Shifts',
    'Morning Shifts',
    'Afternoon Shifts',
    'Night Shifts',
  ];
  
  final List<String> _statusFilters = [
    'All Status',
    'In Progress Only',
    'Pending Only',
  ];

  // Notification management
  final NotificationService _notificationService = NotificationService();
  int _unreadNotificationCount = 0;
  bool _isScreenVisible = true;

  // Track if notification was received while app was paused (local flag)
  bool _pendingNotificationRefresh = false;

  // Multi-listener cleanup callbacks
  VoidCallback? _removeCountListener;
  VoidCallback? _removeReceivedListener;

  // ==================== SMART CACHE METHODS ====================

  /// Check if cached data is expired
  bool get _isCacheExpired {
    if (_lastFetchTime == null) return true;
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

  /// Called when tab becomes visible
  void onTabVisible() {
    _isTabVisible = true;
    final now = DateTime.now();
    
    debugPrint('👁️ Schedule tab visible - checking if refresh needed');
    
    // Calculate time since last visible
    final timeSinceLastVisible = _lastVisibleTime != null 
        ? now.difference(_lastVisibleTime!) 
        : null;
    
    _lastVisibleTime = now;
    
    // Smart refresh decision
    if (_shouldRefreshOnVisible(timeSinceLastVisible)) {
      debugPrint('🔄 Auto-refreshing schedule (reason: ${_getRefreshReason(timeSinceLastVisible)})');
      _loadSchedules(forceRefresh: true, silent: true);
    } else {
      debugPrint('✅ Using cached schedule data');
    }
  }
  
  /// Called when tab becomes hidden
  void onTabHidden() {
    _isTabVisible = false;
    debugPrint('👁️‍🗨️ Schedule tab hidden');
  }

  /// Determine if refresh is needed when tab becomes visible
  bool _shouldRefreshOnVisible(Duration? timeSinceLastVisible) {
    // Never refresh if we just refreshed (for the SAME data)
    final currentCacheKey = _getCacheKey();
    if (_lastRefreshAttempt != null && _lastCacheKeyFetched == currentCacheKey) {
      final timeSinceRefresh = DateTime.now().difference(_lastRefreshAttempt!);
      if (timeSinceRefresh < _minRefreshInterval) {
        debugPrint('⏱️ Rate limit: Last refresh was ${timeSinceRefresh.inSeconds}s ago for same data');
        return false;
      }
    }
    
    // Refresh if cache is expired OR if we don't have cached data for current view
    if (_isCacheExpired || !_scheduleCache.containsKey(currentCacheKey)) {
      debugPrint('🔄 Cache expired or missing for current view');
      return true;
    }
    
    // Refresh if returning after being away for a while
    if (timeSinceLastVisible != null && 
        timeSinceLastVisible > _backgroundReturnThreshold) {
      debugPrint('🔄 Returning after ${timeSinceLastVisible.inMinutes}m absence');
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

  // ==================== SHIMMER ANIMATION ====================

  void _startShimmer() {
    if (_isControllerInitialized && !_shimmerController.isAnimating) {
      _shimmerController.repeat();
    }
  }

  void _stopShimmer() {
    if (_isControllerInitialized && _shimmerController.isAnimating) {
      _shimmerController.stop();
      _shimmerController.reset();
    }
  }

  // ==================== DATA LOADING ====================

  Future<void> _loadSchedules({bool forceRefresh = false, bool silent = false}) async {
    final cacheKey = _getCacheKey();
    
    // Rate limiting check - ONLY for the SAME data
    // Allow free browsing between different dates/filters
    if (!forceRefresh && _lastRefreshAttempt != null && _lastCacheKeyFetched == cacheKey) {
      final timeSinceLastAttempt = DateTime.now().difference(_lastRefreshAttempt!);
      if (timeSinceLastAttempt < _minRefreshInterval) {
        debugPrint('⏱️ Rate limited - last attempt ${timeSinceLastAttempt.inSeconds}s ago (same data)');
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

    // Check cache first (unless force refresh or cache expired)
    if (!forceRefresh && _scheduleCache.containsKey(cacheKey) && !_isCacheExpired) {
      debugPrint('📦 Using cached schedule data (${_cacheAge})');
      if (mounted) {
        setState(() {
          _schedules = _scheduleCache[cacheKey]!;
          _counts = _countsCache[cacheKey];
          _isLoading = false;
          _errorMessage = null;
        });
      }
      return;
    }

    // Show loading and start shimmer only if not silent refresh
    if (!silent && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      _startShimmer();
    }

    _lastRefreshAttempt = DateTime.now();
    _lastCacheKeyFetched = cacheKey; // Track which data we're fetching
    
    debugPrint('🌐 Fetching schedules from API for: $cacheKey (forceRefresh: $forceRefresh, silent: $silent)');

    try {
      final selectedDateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      
      // IMPORTANT: Always fetch ALL schedules for the date, do filtering locally
      final response = await _ScheduleService.getNurseSchedules(
        status: null, // Don't filter by status on API - do it locally!
        shiftType: _selectedFilter == 'All Shifts' ? null : _selectedFilter,
        startDate: selectedDateStr,
        endDate: selectedDateStr,
      );

      if (mounted) {
        // Check if data has changed (for cache invalidation detection)
        final oldData = _scheduleCache[cacheKey];
        final dataChanged = oldData == null || 
                           oldData.length != response.data.length ||
                           _hasScheduleDataChanged(oldData, response.data);
        
        if (dataChanged && oldData != null) {
          debugPrint('🔄 Data changed detected! Old: ${oldData.length}, New: ${response.data.length}');
          // Clear ALL cache since schedules might have moved between dates
          _scheduleCache.clear();
          _countsCache.clear();
          debugPrint('🗑️ Cleared entire cache due to data change');
        }
        
        // Update cache with fresh data
        _scheduleCache[cacheKey] = response.data;
        _countsCache[cacheKey] = response.counts ?? {};
        
        debugPrint('✅ Schedules loaded - Total: ${response.data.length}');
        debugPrint('📊 Cache updated for key: $cacheKey');
        
        // Force setState to ensure UI updates with new data
        setState(() {
          _schedules = response.data;
          _counts = response.counts;
          _lastFetchTime = DateTime.now();
          _isLoading = false;
          _errorMessage = null;
        });
        
        _stopShimmer();
        
        debugPrint('📊 After setState - Displaying: ${_filteredSchedules.length} schedules');
        debugPrint('📊 Upcoming: $_upcomingCount, Completed: $_completedCount, All: $_allCount');
        
        // Show notification if silent refresh and data actually changed
        if (silent && _isTabVisible && dataChanged) {
          _showDataUpdatedNotification();
        }
      }
    } on ScheduleException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isLoading = false;
        });
        _stopShimmer();
        debugPrint('❌ Schedule load error: ${e.message}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An unexpected error occurred. Please try again.';
          _isLoading = false;
        });
        _stopShimmer();
        debugPrint('❌ Schedule load error: $e');
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
              child: Text('Schedules updated'),
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

  /// Manually clear all cache (useful for debugging or force refresh)
  void _clearCache() {
    setState(() {
      _scheduleCache.clear();
      _countsCache.clear();
      _lastFetchTime = null;
      _lastRefreshAttempt = null;
      _lastCacheKeyFetched = null;
    });
    debugPrint('🗑️ All cache cleared manually');
  }

  // Generate cache key based on date and shift filter only (NOT tab!)
  String _getCacheKey() {
    return '${DateFormat('yyyy-MM-dd').format(_selectedDate)}_${_selectedFilter}';
  }

  // Helper method to detect if schedule data has changed
  bool _hasScheduleDataChanged(List<ScheduleItem> oldData, List<ScheduleItem> newData) {
    if (oldData.length != newData.length) return true;
    
    // Create a unique identifier for each schedule (using multiple fields)
    String getScheduleIdentifier(ScheduleItem s) {
      return '${s.patientName}_${DateFormat('yyyy-MM-dd').format(s.date)}_${s.startTime}_${s.endTime}';
    }
    
    // Create sets of schedule identifiers for comparison
    final oldIdentifiers = oldData.map((s) => getScheduleIdentifier(s)).toSet();
    final newIdentifiers = newData.map((s) => getScheduleIdentifier(s)).toSet();
    
    // If the identifiers don't match, data has changed
    if (oldIdentifiers.length != newIdentifiers.length) return true;
    
    // Check if any identifiers are different
    for (final id in newIdentifiers) {
      if (!oldIdentifiers.contains(id)) return true;
    }
    
    return false;
  }

  // ==================== FILTERING LOGIC ====================

  // Local filtering for both tab selection AND status filter
  List<ScheduleItem> get _filteredSchedules {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final filtered = _schedules.where((schedule) {
      // First, filter by selected tab (upcoming/completed/all)
      bool matchesTab = true;
      if (_selectedTab == 'upcoming') {
        // Upcoming: not completed AND schedule is still active (today or future)
        matchesTab = !schedule.isCompleted && _isScheduleActiveOrFuture(schedule, today);
      } else if (_selectedTab == 'completed') {
        // Completed: only completed schedules
        matchesTab = schedule.isCompleted;
      }
      // 'all' tab shows everything, so no filter needed

      // Then, filter by confirmation status
      bool matchesStatus = true;
      if (_selectedStatusFilter == 'In Progress Only') {
        matchesStatus = schedule.status == 'in_progress';
      } else if (_selectedStatusFilter == 'Pending Only') {
        matchesStatus = schedule.status == 'scheduled';
      }

      return matchesTab && matchesStatus;
    }).toList();

    debugPrint('🔍 Filtering: ${_schedules.length} total → ${filtered.length} after filters (tab: $_selectedTab, status: $_selectedStatusFilter)');

    return filtered;
  }

  /// Check if a schedule is still active (today or future)
  /// For multi-day schedules, checks if endDate >= today
  /// For single-day schedules, checks if date >= today
  bool _isScheduleActiveOrFuture(ScheduleItem schedule, DateTime today) {
    if (schedule.isMultiDay && schedule.endDate != null) {
      // For multi-day schedules, check if endDate is today or future
      final endDate = DateTime(schedule.endDate!.year, schedule.endDate!.month, schedule.endDate!.day);
      return endDate.isAfter(today) || endDate.isAtSameMomentAs(today);
    } else {
      // For single-day schedules, check if date is today or future
      final scheduleDate = DateTime(schedule.date.year, schedule.date.month, schedule.date.day);
      return scheduleDate.isAfter(today) || scheduleDate.isAtSameMomentAs(today);
    }
  }

  int get _upcomingCount {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _schedules.where((s) {
      return !s.isCompleted && _isScheduleActiveOrFuture(s, today);
    }).length;
  }
  
  int get _completedCount {
    return _schedules.where((s) => s.isCompleted).length;
  }
  
  int get _allCount {
    return _schedules.length;
  }

  // ==================== DATE SELECTION ====================

  // Debounced date selection (prevents rapid API calls)
  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
      _currentWeekStart = date.subtract(Duration(days: date.weekday % 7));
    });
    
    // Cancel previous timer
    _debounceTimer?.cancel();
    
    // Wait 300ms before making API call (in case user is browsing dates)
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _loadSchedules(forceRefresh: false);
    });
  }

  Future<void> _showDatePicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryGreen,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1A1A1A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      _selectDate(picked);
    }
  }

  // ==================== FILTER OPTIONS ====================

void _showFilterOptions() {
  String tempShiftFilter = _selectedFilter;
  String tempStatusFilter = _selectedStatusFilter;
  
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setModalState) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            
            // Header with title and Clear All button
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filter Schedules',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  if (tempShiftFilter != 'All Shifts' || tempStatusFilter != 'All Status')
                    TextButton(
                      onPressed: () {
                        setModalState(() {
                          tempShiftFilter = 'All Shifts';
                          tempStatusFilter = 'All Status';
                        });
                      },
                      child: const Text(
                        'Clear All',
                        style: TextStyle(
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Shift Type section
            const Text(
              'Shift Type',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 16),
            
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _shiftTypeFilters.map((filter) {
                final isSelected = tempShiftFilter == filter;
                return GestureDetector(
                  onTap: () {
                    setModalState(() {
                      tempShiftFilter = filter;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryGreen
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primaryGreen
                            : Colors.grey[300]!,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSelected)
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Icon(
                              Icons.check_circle,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        Text(
                          filter,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : const Color(0xFF636E72),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 24),
            const Divider(height: 1),
            const SizedBox(height: 24),
            
            // Status section
            const Text(
              'Status',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 16),
            
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _statusFilters.map((filter) {
                final isSelected = tempStatusFilter == filter;
                return GestureDetector(
                  onTap: () {
                    setModalState(() {
                      tempStatusFilter = filter;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryGreen
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primaryGreen
                            : Colors.grey[300]!,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSelected)
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Icon(
                              Icons.check_circle,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        Text(
                          filter,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : const Color(0xFF636E72),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 32),
            
            // Apply Filters button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  final needsApiCall = _selectedFilter != tempShiftFilter;
                  
                  setState(() {
                    _selectedFilter = tempShiftFilter;
                    _selectedStatusFilter = tempStatusFilter;
                  });
                  
                  // Only call API if shift type changed (status is filtered locally)
                  if (needsApiCall) {
                    _loadSchedules(forceRefresh: true);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Apply Filters',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    ),
  );
}

  // ==================== TAB BUTTON ====================

  Widget _buildTabButton(String label, String value, int count) {
    final isSelected = _selectedTab == value;
    return GestureDetector(
      onTap: () {
        if (_selectedTab != value) {
          setState(() {
            _selectedTab = value;
          });
          // No API call needed - just local filtering!
          debugPrint('🔄 Switched to $value tab - filtering locally');
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreen : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryGreen.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.3)
                    : AppColors.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.primaryGreen,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== BUILD METHODS ====================

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        title: _lastFetchTime != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'My Schedules',
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
            : const Text(
                'My Schedule',
                style: TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
        actions: [
          // Notification bell with badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: Color(0xFF1A1A1A),
                ),
                onPressed: _openNotificationsSheet,
                tooltip: 'Notifications',
              ),
              if (_unreadNotificationCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _unreadNotificationCount > 99 ? '99+' : '$_unreadNotificationCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Color(0xFF1A1A1A)),
            onPressed: _showDatePicker,
            tooltip: 'Select Date',
          ),
          IconButton(
            icon: const Icon(Icons.filter_list, color: Color(0xFF1A1A1A)),
            onPressed: _showFilterOptions,
            tooltip: 'Filter Schedules',
          ),
          GestureDetector(
            onLongPress: () {
              _clearCache();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.delete_sweep, color: Colors.white, size: 20),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('Cache cleared! Pull to refresh.'),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.orange,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: IconButton(
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
              onPressed: _isLoading ? null : () => _loadSchedules(forceRefresh: true),
              tooltip: _isCacheExpired ? 'Data expired - Tap to refresh' : 'Refresh schedules (Long press to clear cache)',
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.grey[200],
          ),
        ),
      ),
      body: Column(
        children: [
          // Week calendar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () {
                          setState(() {
                            _currentWeekStart = _currentWeekStart.subtract(
                              const Duration(days: 7),
                            );
                          });
                        },
                      ),
                      Text(
                        '${DateFormat('MMM d').format(_currentWeekStart)} - ${DateFormat('MMM d, yyyy').format(_currentWeekStart.add(const Duration(days: 6)))}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () {
                          setState(() {
                            _currentWeekStart = _currentWeekStart.add(
                              const Duration(days: 7),
                            );
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: 7,
                    itemBuilder: (context, index) {
                      final date = _currentWeekStart.add(Duration(days: index));
                      final isSelected = date.day == _selectedDate.day &&
                          date.month == _selectedDate.month &&
                          date.year == _selectedDate.year;
                      final isToday = date.day == DateTime.now().day &&
                          date.month == DateTime.now().month &&
                          date.year == DateTime.now().year;

                      return GestureDetector(
                        onTap: () => _selectDate(date),
                        child: Container(
                          width: 60,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primaryGreen
                                : isToday
                                    ? AppColors.primaryGreen.withOpacity(0.1)
                                    : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isToday && !isSelected
                                  ? AppColors.primaryGreen
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                DateFormat('EEE').format(date),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF636E72),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('d').format(date),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF1A1A1A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Tab buttons
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: _buildTabButton('Scheduled', 'upcoming', _upcomingCount),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTabButton('Completed', 'completed', _completedCount),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTabButton('All', 'all', _allCount),
                ),
              ],
            ),
          ),

          // Active filters display
          if (_selectedFilter != 'All Shifts' || _selectedStatusFilter != 'All Status')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: Row(
                children: [
                  const Text(
                    'Active Filters: ',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF636E72),
                    ),
                  ),
                  if (_selectedFilter != 'All Shifts')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _selectedFilter,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF1A1A1A),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedFilter = 'All Shifts';
                              });
                              _loadSchedules(forceRefresh: true);
                            },
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_selectedStatusFilter != 'All Status')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _selectedStatusFilter,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF1A1A1A),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedStatusFilter = 'All Status';
                              });
                              // No API call needed - just local filter
                            },
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

          // Selected date indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.1),
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: AppColors.primaryGreen,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Showing schedules for ${DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
                if (_scheduleCache.containsKey(_getCacheKey()) && !_isCacheExpired)
                  Tooltip(
                    message: 'Loaded from cache',
                    child: Icon(
                      Icons.offline_bolt,
                      size: 16,
                      color: AppColors.primaryGreen.withOpacity(0.6),
                    ),
                  ),
              ],
            ),
          ),

          // Schedule list
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _schedules.isEmpty) {
      return _buildSkeletonLoader();
    }

    if (_errorMessage != null && _schedules.isEmpty) {
      return _buildErrorState();
    }

    if (_filteredSchedules.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () => _loadSchedules(forceRefresh: true),
      color: AppColors.primaryGreen,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredSchedules.length,
        itemBuilder: (context, index) {
          return _buildScheduleCard(_filteredSchedules[index]);
        },
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildSkeletonCard(),
        );
      },
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildShimmerBox(
                  width: 4,
                  height: 50,
                  borderRadius: 2,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildShimmerBox(
                              height: 18,
                              borderRadius: 8,
                            ),
                          ),
                          const SizedBox(width: 12),
                          _buildShimmerBox(
                            width: 80,
                            height: 24,
                            borderRadius: 12,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildShimmerBox(
                        width: 150,
                        height: 14,
                        borderRadius: 6,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildShimmerBox(height: 16, borderRadius: 6),
                  const SizedBox(height: 8),
                  _buildShimmerBox(height: 16, borderRadius: 6),
                  const SizedBox(height: 8),
                  _buildShimmerBox(height: 16, borderRadius: 6),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerBox({
    double? width,
    required double height,
    required double borderRadius,
  }) {
    if (!_isControllerInitialized) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.grey.shade300,
                Colors.grey.shade100,
                Colors.grey.shade300,
              ],
              stops: [
                _shimmerController.value - 0.3,
                _shimmerController.value,
                _shimmerController.value + 0.3,
              ].map((stop) => stop.clamp(0.0, 1.0)).toList(),
            ),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: SingleChildScrollView(  
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder(
              duration: const Duration(milliseconds: 800),
              tween: Tween<double>(begin: 0, end: 1),
              curve: Curves.elasticOut,
              builder: (context, double value, child) {
                return Transform.scale(
                  scale: value,
                  child: child,
                );
              },
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.red.shade50,
                      Colors.red.shade50.withOpacity(0.5),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.red.shade200,
                          width: 2,
                        ),
                      ),
                    ),
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.error_outline_rounded,
                        size: 50,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [
                  Colors.red.shade700,
                  Colors.red.shade500,
                ],
              ).createShader(bounds),
              child: const Text(
                'Oops! Something Went Wrong',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                  height: 1.6,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Please check your connection and try again',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryGreen,
                    AppColors.primaryGreen.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryGreen.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () => _loadSchedules(forceRefresh: true),
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder(
              duration: const Duration(milliseconds: 800),
              tween: Tween<double>(begin: 0, end: 1),
              curve: Curves.elasticOut,
              builder: (context, double value, child) {
                return Transform.scale(
                  scale: value,
                  child: child,
                );
              },
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primaryGreen.withOpacity(0.1),
                      AppColors.primaryGreen.withOpacity(0.05),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primaryGreen.withOpacity(0.2),
                          width: 2,
                        ),
                      ),
                    ),
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _selectedFilter == 'All Shifts'
                          ? Icons.event_busy_outlined
                          : Icons.search_off_outlined,
                        size: 50,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [
                  AppColors.primaryGreen,
                  AppColors.primaryGreen.withOpacity(0.7),
                ],
              ).createShader(bounds),
              child: const Text(
                'No Schedules Found',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            const SizedBox(height: 12),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'No ${_selectedTab} schedules for ${DateFormat('MMMM d, yyyy').format(_selectedDate)}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                  height: 1.6,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            
            const SizedBox(height: 8),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _selectedFilter != 'All Shifts' || _selectedStatusFilter != 'All Status'
                  ? 'Try selecting a different date or removing filters'
                  : 'Try selecting a different date or check your schedule assignments',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                  height: 1.5,
                ),
              ),
            ),
            
            if (_selectedFilter != 'All Shifts' || _selectedStatusFilter != 'All Status') ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedFilter = 'All Shifts';
                    _selectedStatusFilter = 'All Status';
                  });
                  _loadSchedules(forceRefresh: true);
                },
                icon: const Icon(Icons.clear_all, size: 20),
                label: const Text('Clear All Filters'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryGreen,
                  side: BorderSide(color: AppColors.primaryGreen.withOpacity(0.5), width: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleCard(ScheduleItem schedule) {
    final isConfirmed = schedule.status == 'in_progress';
    final isCompleted = schedule.isCompleted;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showScheduleDetails(schedule),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 50,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? Colors.grey[400]
                            : isConfirmed
                                ? const Color(0xFF03DAC6)
                                : const Color(0xFFFF9A00),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  schedule.patientName,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isCompleted 
                                        ? Colors.grey[600]
                                        : const Color(0xFF1A1A1A),
                                    decoration: isCompleted 
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ),
                              if (isCompleted)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        size: 12,
                                        color: Colors.green,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Completed',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isConfirmed
                                        ? const Color(0xFF03DAC6).withOpacity(0.1)
                                        : const Color(0xFFFF9A00).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    isConfirmed ? 'In Progress' : 'Pending',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isConfirmed
                                          ? const Color(0xFF03DAC6)
                                          : const Color(0xFFFF9A00),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${schedule.patientAge != null ? '${schedule.patientAge} years old • ' : ''}${schedule.careType}',
                            style: TextStyle(
                              fontSize: 13,
                              color: isCompleted ? Colors.grey[500] : const Color(0xFF636E72),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        Icons.calendar_today,
                        schedule.isMultiDay
                            ? schedule.dateRangeDisplay
                            : DateFormat('EEEE, MMM d').format(schedule.date),
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        Icons.access_time,
                        '${schedule.startTime} - ${schedule.endTime}',
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        Icons.location_on,
                        schedule.location,
                      ),
                    ],
                  ),
                ),
                if (schedule.notes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Color(0xFF1A1A1A),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          schedule.notes,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF636E72),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: const Color(0xFF1A1A1A),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ),
      ],
    );
  }

  void _showScheduleDetails(ScheduleItem schedule) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A).withOpacity(0.05),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Schedule Details',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    schedule.patientName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: schedule.status == 'in_progress'
                              ? const Color(0xFF03DAC6)
                              : const Color(0xFFFF9A00),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          schedule.status == 'in_progress' ? 'In Progress' : 'Pending',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          schedule.shiftType,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
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
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailSection(
                      'Patient Information',
                      [
                        if (schedule.patientAge != null)
                          _buildDetailItem('Age', '${schedule.patientAge} years old'),
                        _buildDetailItem('Care Type', schedule.careType),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildDetailSection(
                      'Schedule Information',
                      [
                        _buildDetailItem(
                          'Date',
                          schedule.isMultiDay
                              ? schedule.dateRangeDisplay
                              : DateFormat('EEEE, MMMM d, yyyy').format(schedule.date),
                        ),
                        if (schedule.isMultiDay && schedule.totalDays != null)
                          _buildDetailItem(
                            'Duration',
                            '${schedule.totalDays} days',
                          ),
                        _buildDetailItem(
                          'Time',
                          '${schedule.startTime} - ${schedule.endTime}',
                        ),
                        _buildDetailItem('Shift Type', schedule.shiftType),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildDetailSection(
                      'Location',
                      [
                        _buildDetailItem('Address', schedule.location),
                      ],
                    ),
                    if (schedule.notes.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildDetailSection(
                        'Special Notes',
                        [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF9C4),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFFFF176),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Color(0xFFF57C00),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    schedule.notes,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 32),
                    // Row(
                    //   children: [
                    //     Expanded(
                    //       child: OutlinedButton.icon(
                    //         onPressed: () {
                    //           Navigator.pop(context);
                    //         },
                    //         icon: const Icon(Icons.person_outline),
                    //         label: const Text('Patient Profile'),
                    //         style: OutlinedButton.styleFrom(
                    //           foregroundColor: AppColors.primaryGreen,
                    //           side: const BorderSide(color: AppColors.primaryGreen),
                    //           padding: const EdgeInsets.symmetric(vertical: 16),
                    //           shape: RoundedRectangleBorder(
                    //             borderRadius: BorderRadius.circular(12),
                    //           ),
                    //         ),
                    //       ),
                    //     ),
                    //     const SizedBox(width: 12),
                    //     Expanded(
                    //       child: ElevatedButton.icon(
                    //         onPressed: () {
                    //           Navigator.pop(context);
                    //           ScaffoldMessenger.of(context).showSnackBar(
                    //             const SnackBar(
                    //               content: Text('Clock-in feature coming soon!'),
                    //               backgroundColor: AppColors.primaryGreen,
                    //             ),
                    //           );
                    //         },
                    //         icon: const Icon(Icons.access_time),
                    //         label: const Text('Clock In'),
                    //         style: ElevatedButton.styleFrom(
                    //           backgroundColor: AppColors.primaryGreen,
                    //           foregroundColor: Colors.white,
                    //           padding: const EdgeInsets.symmetric(vertical: 16),
                    //           shape: RoundedRectangleBorder(
                    //             borderRadius: BorderRadius.circular(12),
                    //           ),
                    //         ),
                    //       ),
                    //     ),
                    //   ],
                    // ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF636E72),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF636E72),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF1A1A1A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}