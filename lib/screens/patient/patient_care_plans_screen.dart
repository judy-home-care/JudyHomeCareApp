import 'package:flutter/material.dart';
import '../../services/care_plans/care_plan_service.dart';
import '../../models/care_plans/care_plan_models.dart';
import '../../services/notification_service.dart';
import '../modern_notifications_sheet.dart';

class PatientCarePlansScreen extends StatefulWidget {
  const PatientCarePlansScreen({Key? key}) : super(key: key);

  @override
  // ✅ CHANGE 1: Made state class PUBLIC (removed underscore)
  State<PatientCarePlansScreen> createState() => PatientCarePlansScreenState();
}

// ✅ CHANGE 2: PUBLIC state class with AutomaticKeepAliveClientMixin
class PatientCarePlansScreenState extends State<PatientCarePlansScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  final CarePlanService _carePlanService = CarePlanService();
  final ScrollController _scrollController = ScrollController();

  List<CarePlan> _carePlans = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasError = false;
  String _errorMessage = '';
  
  // Pagination
  int _currentPage = 1;
  int _lastPage = 1;
  
  // Filters
  String? _selectedStatus;
  String? _selectedPriority;

  // ✅ CHANGE 3: Cache management fields
  DateTime? _lastFetchTime;
  DateTime? _lastRefreshAttempt;
  static const Duration _cacheValidityDuration = Duration(minutes: 15);
  static const Duration _minRefreshInterval = Duration(seconds: 30);
  static const Duration _backgroundReturnThreshold = Duration(minutes: 10);

  // ✅ CHANGE 4: Visibility tracking fields
  bool _isTabVisible = false;
  DateTime? _lastVisibleTime;
  bool _isScreenVisible = true;

  // Notification management
  final NotificationService _notificationService = NotificationService();
  int _unreadNotificationCount = 0;

  // Listener cleanup functions (multi-listener pattern)
  VoidCallback? _removeCountListener;
  VoidCallback? _removeReceivedListener;

  // Prevent concurrent refresh calls (race condition fix)
  bool _isRefreshing = false;

  // ✅ CHANGE 5: Keep state alive when switching tabs
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Mark as visible on first load
    _isTabVisible = true;
    _lastVisibleTime = DateTime.now();
    _loadCarePlans();
    _scrollController.addListener(_onScroll);

    // Set up FCM notification updates
    _setupFcmNotificationUpdates();
    _loadUnreadNotificationCount();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();

    // Clean up FCM listeners (multi-listener pattern)
    _removeCountListener?.call();
    _removeReceivedListener?.call();

    super.dispose();
  }

  // Detect app lifecycle changes for battery saving
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      _isScreenVisible = true;
      debugPrint('🔄 [Patient Care Plans] App resumed - checking for background notifications');

      // Check if notification was received while in background
      final hasBackgroundNotification = _notificationService.hasNotificationWhileBackground;
      if (hasBackgroundNotification) {
        debugPrint('📱 [Patient Care Plans] Notification received while away - forcing refresh');
        _notificationService.clearBackgroundNotificationFlag();
        _loadCarePlans(forceRefresh: true, silent: true);
      } else if (_isTabVisible) {
        // Only refresh if data is actually stale
        final shouldRefresh = _lastFetchTime == null ||
            DateTime.now().difference(_lastFetchTime!) >= Duration(minutes: 10);

        if (shouldRefresh) {
          debugPrint('🔄 Data stale, refreshing care plans...');
          _loadCarePlans(forceRefresh: true, silent: true);
        } else {
          debugPrint('📦 Using cached care plans');
        }
      }

      // Refresh notification count
      _notificationService.refreshBadge();
    } else if (state == AppLifecycleState.paused) {
      _isScreenVisible = false;
      debugPrint('⏸️ [Patient Care Plans] App paused');
    }
  }

  // ==================== FCM NOTIFICATION UPDATES ====================

  /// Set up FCM callback for real-time notification count updates
  /// Uses multi-listener pattern so all screens get updates!
  void _setupFcmNotificationUpdates() {
    debugPrint('⚡ [Patient Care Plans] Setting up FCM real-time notification updates (multi-listener)');

    // Update notification badge count - using multi-listener pattern
    _removeCountListener = _notificationService.addNotificationCountListener((newCount) {
      if (mounted) {
        setState(() {
          _unreadNotificationCount = newCount;
        });
        debugPrint('🔔 [Patient Care Plans] Notification count updated: $newCount');
      }
    });

    // Refresh data when notification received (foreground)
    _removeReceivedListener = _notificationService.addNotificationReceivedListener(() {
      if (mounted && _isScreenVisible) {
        debugPrint('🔄 [Patient Care Plans] Notification received - triggering silent refresh');
        _loadCarePlans(forceRefresh: true, silent: true);
      }
    });
  }

  /// Load unread notification count
  Future<void> _loadUnreadNotificationCount() async {
    try {
      await _notificationService.refreshBadge();
      debugPrint('📊 [Patient Care Plans] Badge refreshed');
    } catch (e) {
      debugPrint('❌ [Patient Care Plans] Error refreshing badge: $e');
    }
  }

  /// Open notifications sheet
  void _openNotificationsSheet() async {
    await showNotificationsSheet(context);
    await _notificationService.refreshBadge();
    debugPrint('🔔 [Patient Care Plans] Badge refreshed after closing notifications');
  }

  // ==================== END NOTIFICATION UPDATES ====================

  // ✅ CHANGE 7: PUBLIC METHODS FOR PARENT NAVIGATION
  
  /// Called by parent when tab becomes visible
  void onTabVisible() {
    _isTabVisible = true;
    final now = DateTime.now();

    debugPrint('👁️ Care Plans tab visible - checking if refresh needed');

    final timeSinceLastVisible = _lastVisibleTime != null
        ? now.difference(_lastVisibleTime!)
        : null;

    _lastVisibleTime = now;

    if (_shouldRefreshOnVisible(timeSinceLastVisible)) {
      final reason = _getRefreshReason(timeSinceLastVisible);
      debugPrint('🔄 Refreshing care plans: $reason');
      _loadCarePlans(forceRefresh: true, silent: true);
    } else {
      debugPrint('📦 Using cached data - no refresh needed');
    }
  }

  /// Called by parent when tab becomes hidden
  void onTabHidden() {
    _isTabVisible = false;
    debugPrint('👁️‍🗨️ Care Plans tab hidden');
  }

  /// Public method to trigger manual refresh (called by parent)
  void loadCarePlans({bool forceRefresh = false}) {
    _loadCarePlans(forceRefresh: forceRefresh);
  }

  // ✅ CHANGE 8: Smart refresh logic
  
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
    if (_lastFetchTime == null || _carePlans.isEmpty) return true;
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
      return const Color(0xFF199A8E);
    } else if (difference < _cacheValidityDuration) {
      return const Color(0xFFFF9A00);
    } else {
      return Colors.red;
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _currentPage < _lastPage) {
        _loadMoreCarePlans();
      }
    }
  }

  // ✅ CHANGE 9: Updated _loadCarePlans with smart caching
  Future<void> _loadCarePlans({
    bool refresh = false,
    bool forceRefresh = false,
    bool silent = false,
  }) async {
    // Prevent concurrent refresh calls (race condition fix)
    if (_isRefreshing) {
      debugPrint('⏭️ Refresh already in progress - skipping duplicate call');
      return;
    }

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
    if (!forceRefresh && !refresh && !_isCacheExpired && _carePlans.isNotEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      debugPrint('📦 Using cached care plans (${_cacheAge})');
      return;
    }

    if (refresh) {
      setState(() {
        _currentPage = 1;
        _carePlans.clear();
      });
    }

    // Show loading only if not silent refresh
    if (!silent && mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    _lastRefreshAttempt = DateTime.now();
    _isRefreshing = true;

    debugPrint('🌐 Fetching care plans from API...');

    try {
      final response = await _carePlanService.getNurseCarePlans(
        page: _currentPage,
        perPage: 15,
        status: _selectedStatus,
        priority: _selectedPriority,
      );

      if (mounted) {
        setState(() {
          _carePlans = response.data;
          _currentPage = response.currentPage ?? 1;
          _lastPage = response.lastPage ?? 1;
          _lastFetchTime = DateTime.now();
          _isLoading = false;
        });

        debugPrint('✅ Care plans loaded (${_cacheAge})');

        // Show notification if silent refresh
        if (silent && _isTabVisible) {
          _showDataUpdatedNotification();
        }
      }
    } on CarePlanException catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.message;
          _isLoading = false;
        });
        debugPrint('❌ Care plans load error: ${e.message}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'An unexpected error occurred: $e';
          _isLoading = false;
        });
        debugPrint('❌ Care plans unexpected error: $e');
      }
    } finally {
      _isRefreshing = false;
    }
  }

  /// Show notification when data updates in background
  void _showDataUpdatedNotification() {
    if (!mounted) return;

    // Clear any existing queued snackbars to prevent stacking
    ScaffoldMessenger.of(context).clearSnackBars();

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
              child: Text('Care plans updated'),
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

  Future<void> _loadMoreCarePlans() async {
    if (_isLoadingMore || _currentPage >= _lastPage) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final response = await _carePlanService.getNurseCarePlans(
        page: _currentPage + 1,
        perPage: 15,
        status: _selectedStatus,
        priority: _selectedPriority,
      );

      if (mounted) {
        setState(() {
          _carePlans.addAll(response.data);
          _currentPage = response.currentPage ?? _currentPage;
          _lastPage = response.lastPage ?? _lastPage;
          _isLoadingMore = false;
        });
      }
    } on CarePlanException catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load more: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter Care Plans',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Status',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedStatus,
                          isExpanded: true,
                          underline: const SizedBox(),
                          hint: const Text('All Statuses'),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('All Statuses'),
                            ),
                            ...['active', 'completed', 'draft', 'pending_approval', 'cancelled']
                                .map((status) => DropdownMenuItem<String>(
                                      value: status,
                                      child: Text(status.replaceAll('_', ' ').toUpperCase()),
                                    ))
                                .toList(),
                          ],
                          onChanged: (value) {
                            setModalState(() {
                              _selectedStatus = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      const Text(
                        'Priority',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedPriority,
                          isExpanded: true,
                          underline: const SizedBox(),
                          hint: const Text('All Priorities'),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('All Priorities'),
                            ),
                            ...['low', 'medium', 'high']
                                .map((priority) => DropdownMenuItem<String>(
                                      value: priority,
                                      child: Text(priority.toUpperCase()),
                                    ))
                                .toList(),
                          ],
                          onChanged: (value) {
                            setModalState(() {
                              _selectedPriority = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setModalState(() {
                              _selectedStatus = null;
                              _selectedPriority = null;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: Colors.grey[300]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _lastFetchTime = null; // Invalidate cache when filters change
                            });
                            Navigator.pop(context);
                            _loadCarePlans(refresh: true, forceRefresh: true);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF199A8E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Apply Filters',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  bool _hasActiveFilters() {
    return _selectedStatus != null || _selectedPriority != null;
  }

  @override
  Widget build(BuildContext context) {
    // ✅ CHANGE 10: Must call super.build when using AutomaticKeepAliveClientMixin
    super.build(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: false,
        titleSpacing: 16,
        // ✅ CHANGE 11: Added cache freshness indicator to app bar
        title: _lastFetchTime != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'My Care Plans',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
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
                'My Care Plans',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: -0.5,
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
          // ✅ CHANGE 12: Updated refresh button with loading state
          IconButton(
            icon: _isLoading && !_isCacheExpired
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        const Color(0xFF199A8E),
                      ),
                    ),
                  )
                : Icon(
                    Icons.refresh,
                    color: _isCacheExpired ? Colors.red : const Color(0xFF199A8E),
                  ),
            onPressed: _isLoading ? null : () => _loadCarePlans(forceRefresh: true),
            tooltip: _isCacheExpired ? 'Data expired - Tap to refresh' : 'Refresh care plans',
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.filter_list,
                  color: Color(0xFF199A8E),
                ),
                onPressed: _showFilterModal,
                tooltip: 'Filter',
              ),
              if (_hasActiveFilters())
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4757),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.grey.shade200,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadCarePlans(refresh: true, forceRefresh: true),
        color: const Color(0xFF199A8E),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _carePlans.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF199A8E),
        ),
      );
    }

    if (_hasError) {
      return _buildErrorState();
    }

    if (_carePlans.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _carePlans.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _carePlans.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(
                color: Color(0xFF199A8E),
              ),
            ),
          );
        }

        return _buildCarePlanCard(_carePlans[index]);
      },
    );
  }

  Widget _buildCarePlanCard(CarePlan carePlan) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _viewCarePlanDetail(carePlan.id),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _getPriorityColor(carePlan.priority).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.medical_services_rounded,
                        color: _getPriorityColor(carePlan.priority),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            carePlan.carePlan,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            carePlan.careType,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(carePlan.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        carePlan.status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(carePlan.status),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progress',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${(carePlan.progress * 100).toInt()}%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF199A8E),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: carePlan.progress,
                        backgroundColor: Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF199A8E)),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoChip(
                        Icons.person_outline,
                        'Nurse',
                        carePlan.primaryNurse,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildInfoChip(
                        Icons.local_hospital_outlined,
                        'Doctor',
                        carePlan.doctor,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoChip(
                        Icons.flag_outlined,
                        'Priority',
                        carePlan.priority,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildInfoChip(
                        Icons.calendar_today_outlined,
                        'Frequency',
                        carePlan.frequency,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _viewCarePlanDetail(int carePlanId) async {
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
      final carePlan = await _carePlanService.getCarePlanById(carePlanId);
      
      if (mounted) {
        Navigator.pop(context);
        _showDetailBottomSheet(carePlan);
      }
    } on CarePlanException catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDetailBottomSheet(CarePlan carePlan) {
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
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF199A8E).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.medical_services_rounded,
                          color: Color(0xFF199A8E),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          carePlan.carePlan,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
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
                    if (carePlan.description.isNotEmpty) ...[
                      _buildSectionHeader('Description', Icons.description),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Text(
                          carePlan.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[800],
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    
                    if (carePlan.careTasks.isNotEmpty) ...[
                      _buildSectionHeader('Care Tasks', Icons.task_alt),
                      const SizedBox(height: 12),
                      ...carePlan.careTasks.asMap().entries.map((entry) {
                        final index = entry.key;
                        final task = entry.value;
                        final isCompleted = carePlan.completedTasks.contains(index);
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isCompleted 
                                ? const Color(0xFF199A8E).withOpacity(0.05)
                                : const Color(0xFFF8FAFB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isCompleted
                                  ? const Color(0xFF199A8E).withOpacity(0.2)
                                  : Colors.grey[200]!,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isCompleted
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: isCompleted
                                    ? const Color(0xFF199A8E)
                                    : Colors.grey[400],
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  task,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[800],
                                    decoration: isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 20),
                    ],
                    
                    if (carePlan.specialInstructions.isNotEmpty) ...[
                      _buildSectionHeader('Special Instructions', Icons.info_outline),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFFFC107).withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: carePlan.specialInstructions.map((instruction) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '• ',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[800],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      instruction.toString(),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[800],
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border(top: BorderSide(color: Colors.grey[200]!)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Progress: ${(carePlan.progress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '${carePlan.completedTasks.length}/${carePlan.careTasks.length} tasks',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF199A8E),
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
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF999999),
            letterSpacing: 1,
          ),
        ),
      ],
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
        return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return const Color(0xFF199A8E);
      case 'completed':
        return const Color(0xFF4CAF50);
      case 'draft':
        return const Color(0xFF9E9E9E);
      case 'pending approval':
      case 'pending_approval':
        return const Color(0xFFFF9A00);
      case 'cancelled':
        return const Color(0xFFFF4757);
      default:
        return Colors.grey;
    }
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
                      const Color(0xFF199A8E).withOpacity(0.1),
                      const Color(0xFF199A8E).withOpacity(0.05),
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
                          color: const Color(0xFF199A8E).withOpacity(0.2),
                          width: 2,
                        ),
                      ),
                    ),
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: const Color(0xFF199A8E).withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.medical_services_outlined,
                        size: 50,
                        color: Color(0xFF199A8E),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  Color(0xFF199A8E),
                  Color(0xFF147D73),
                ],
              ).createShader(bounds),
              child: const Text(
                'No Care Plans Yet',
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
                'Your care plans will appear here once they are assigned by your healthcare team',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                  height: 1.6,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _loadCarePlans(refresh: true, forceRefresh: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF199A8E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
}