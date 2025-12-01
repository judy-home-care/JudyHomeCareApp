import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/progress_notes/progress_notes_service.dart';
import '../../models/progress_notes/progress_note_models.dart';
import '../../services/notification_service.dart';
import '../modern_notifications_sheet.dart';

class ProgressNoteScreen extends StatefulWidget {
  const ProgressNoteScreen({Key? key}) : super(key: key);

  @override
  // ✅ CHANGE 1: Made state class PUBLIC (removed underscore)
  State<ProgressNoteScreen> createState() => ProgressNoteScreenState();
}

// ✅ CHANGE 2: PUBLIC state class with AutomaticKeepAliveClientMixin
class ProgressNoteScreenState extends State<ProgressNoteScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  final ProgressNotesService _progressNotesService = ProgressNotesService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _progressNotes = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasError = false;
  String _errorMessage = '';
  
  // Pagination
  int _currentPage = 1;
  int _lastPage = 1;
  
  // Filters
  DateTime? _startDate;
  DateTime? _endDate;
  String _searchQuery = '';
  String _sortOrder = 'Newest First';

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
    _loadProgressNotes();
    _scrollController.addListener(_onScroll);

    // Set up FCM notification updates
    _setupFcmNotificationUpdates();
    _loadUnreadNotificationCount();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _searchController.dispose();

    // Clean up FCM listeners (multi-listener pattern)
    _removeCountListener?.call();
    _removeReceivedListener?.call();

    super.dispose();
  }

  //Detect app lifecycle changes for battery saving
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      _isScreenVisible = true;
      debugPrint('🔄 [Progress Notes] App resumed - checking for background notifications');

      // Check if notification was received while in background
      final hasBackgroundNotification = _notificationService.hasNotificationWhileBackground;
      if (hasBackgroundNotification) {
        debugPrint('📱 [Progress Notes] Notification received while away - forcing refresh');
        _notificationService.clearBackgroundNotificationFlag();
        _loadProgressNotes(forceRefresh: true, silent: true);
      } else if (_isTabVisible) {
        // Only refresh if data is actually stale
        final shouldRefresh = _lastFetchTime == null ||
            DateTime.now().difference(_lastFetchTime!) >= Duration(minutes: 5);

        if (shouldRefresh) {
          debugPrint('🔄 Data stale, refreshing progress notes...');
          _loadProgressNotes(forceRefresh: true, silent: true);
        } else {
          debugPrint('📦 Using cached progress notes');
        }
      }

      // Refresh notification count
      _notificationService.refreshBadge();
    } else if (state == AppLifecycleState.paused) {
      _isScreenVisible = false;
      debugPrint('⏸️ [Progress Notes] App paused');
    }
  }

  // ==================== FCM NOTIFICATION UPDATES ====================

  /// Set up FCM callback for real-time notification count updates
  /// Uses multi-listener pattern so all screens get updates!
  void _setupFcmNotificationUpdates() {
    debugPrint('⚡ [Progress Notes] Setting up FCM real-time notification updates (multi-listener)');

    // Update notification badge count - using multi-listener pattern
    _removeCountListener = _notificationService.addNotificationCountListener((newCount) {
      if (mounted) {
        setState(() {
          _unreadNotificationCount = newCount;
        });
        debugPrint('🔔 [Progress Notes] Notification count updated: $newCount');
      }
    });

    // Refresh data when notification received (foreground)
    _removeReceivedListener = _notificationService.addNotificationReceivedListener(() {
      if (mounted && _isScreenVisible) {
        debugPrint('🔄 [Progress Notes] Notification received - triggering silent refresh');
        _loadProgressNotes(forceRefresh: true, silent: true);
      }
    });
  }

  /// Load unread notification count
  Future<void> _loadUnreadNotificationCount() async {
    try {
      await _notificationService.refreshBadge();
      debugPrint('📊 [Progress Notes] Badge refreshed');
    } catch (e) {
      debugPrint('❌ [Progress Notes] Error refreshing badge: $e');
    }
  }

  /// Open notifications sheet
  void _openNotificationsSheet() async {
    await showNotificationsSheet(context);
    await _notificationService.refreshBadge();
    debugPrint('🔔 [Progress Notes] Badge refreshed after closing notifications');
  }

  // ==================== END NOTIFICATION UPDATES ====================

  // ✅ CHANGE 7: PUBLIC METHODS FOR PARENT NAVIGATION

  /// Called by parent when tab becomes visible
  void onTabVisible() {
    _isTabVisible = true;
    final now = DateTime.now();

    debugPrint('👁️ Progress Notes tab visible - checking if refresh needed');

    final timeSinceLastVisible = _lastVisibleTime != null
        ? now.difference(_lastVisibleTime!)
        : null;

    _lastVisibleTime = now;

    if (_shouldRefreshOnVisible(timeSinceLastVisible)) {
      final reason = _getRefreshReason(timeSinceLastVisible);
      debugPrint('🔄 Refreshing progress notes: $reason');
      _loadProgressNotes(forceRefresh: true, silent: true);
    } else {
      debugPrint('📦 Using cached data - no refresh needed');
    }
  }

  /// Called by parent when tab becomes hidden
  void onTabHidden() {
    _isTabVisible = false;
    debugPrint('👁️‍🗨️ Progress Notes tab hidden');
  }

  /// Public method to trigger manual refresh (called by parent)
  void loadProgressNotes({bool forceRefresh = false}) {
    _loadProgressNotes(forceRefresh: forceRefresh);
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
    if (_lastFetchTime == null || _progressNotes.isEmpty) return true;
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
        _loadMoreNotes();
      }
    }
  }

  // ✅ CHANGE 9: Updated _loadProgressNotes with smart caching
  Future<void> _loadProgressNotes({
    bool refresh = false,
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
    if (!forceRefresh && !refresh && !_isCacheExpired && _progressNotes.isNotEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      debugPrint('📦 Using cached progress notes (${_cacheAge})');
      return;
    }

    if (refresh) {
      setState(() {
        _currentPage = 1;
        _progressNotes.clear();
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
    debugPrint('🌐 Fetching progress notes from API...');

    try {
      final sortOrderParam = _sortOrder == 'Oldest First' ? 'asc' : 'desc';
      
      final response = await _progressNotesService.getProgressNotes(
        page: _currentPage,
        perPage: 15,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        startDate: _startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : null,
        endDate: _endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : null,
        sortOrder: sortOrderParam,
      );

      if (mounted) {
        setState(() {
          _progressNotes = response.data.map<Map<String, dynamic>>((note) => note.toJson()).toList();
          _currentPage = response.pagination.currentPage;
          _lastPage = response.pagination.lastPage;
          _lastFetchTime = DateTime.now();
          _isLoading = false;
        });

        debugPrint('✅ Progress notes loaded (${_cacheAge})');

        // Show notification if silent refresh
        if (silent && _isTabVisible) {
          _showDataUpdatedNotification();
        }
      }
    } on ProgressNotesException catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.message;
          _isLoading = false;
        });
        debugPrint('❌ Progress notes load error: ${e.message}');
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
              child: Text('Progress notes updated'),
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

  Future<void> _loadMoreNotes() async {
    if (_isLoadingMore || _currentPage >= _lastPage) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final sortOrderParam = _sortOrder == 'Oldest First' ? 'asc' : 'desc';
      
      final response = await _progressNotesService.getProgressNotes(
        page: _currentPage + 1,
        perPage: 15,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        startDate: _startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : null,
        endDate: _endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : null,
        sortOrder: sortOrderParam,
      );

      if (mounted) {
        final newNotes = response.data.map<Map<String, dynamic>>((note) => note.toJson()).toList();

        setState(() {
          _progressNotes.addAll(newNotes);
          _currentPage = response.pagination.currentPage;
          _lastPage = response.pagination.lastPage;
          _isLoadingMore = false;
        });
      }
    } on ProgressNotesException catch (e) {
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

  void _applyFilters() {
    _currentPage = 1;
    _progressNotes.clear();
    _lastFetchTime = null; // Invalidate cache when filters change
    _loadProgressNotes();
  }

  void _clearFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _searchQuery = '';
      _searchController.clear();
      _sortOrder = 'Newest First';
      _currentPage = 1;
      _progressNotes.clear();
      _lastFetchTime = null; // Invalidate cache
    });
    _loadProgressNotes();
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
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                // Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter Progress Notes',
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
                      // Date Range
                      const Text(
                        'Date Range',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDateField(
                              'Start Date',
                              _startDate,
                              () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _startDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  setModalState(() {
                                    _startDate = picked;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDateField(
                              'End Date',
                              _endDate,
                              () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _endDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  setModalState(() {
                                    _endDate = picked;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Sort By
                      const Text(
                        'Sort By',
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
                          value: _sortOrder,
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: ['Newest First', 'Oldest First'].map((String item) {
                            return DropdownMenuItem<String>(
                              value: item,
                              child: Text(item),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setModalState(() {
                              _sortOrder = value!;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 20), 
                    ],
                  ),
                ),
                
                // Buttons
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setModalState(() {
                              _startDate = null;
                              _endDate = null;
                              _sortOrder = 'Newest First';
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
                              // Apply the filters from modal state
                            });
                            Navigator.pop(context);
                            _applyFilters();
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

  Widget _buildDateField(String label, DateTime? date, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                date != null ? DateFormat('MMM d, yyyy').format(date) : label,
                style: TextStyle(
                  fontSize: 14,
                  color: date != null ? const Color(0xFF1A1A1A) : Colors.grey[600],
                  fontWeight: date != null ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
            Icon(
              Icons.calendar_today,
              size: 18,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
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
        // ✅ CHANGE 11: Added cache freshness indicator to app bar
        title: _lastFetchTime != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Progress Notes',
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
                'Progress Notes',
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
            onPressed: _isLoading ? null : () => _loadProgressNotes(forceRefresh: true),
            tooltip: _isCacheExpired ? 'Data expired - Tap to refresh' : 'Refresh progress notes',
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
        onRefresh: () => _loadProgressNotes(refresh: true, forceRefresh: true),
        color: const Color(0xFF199A8E),
        child: _buildBody(),
      ),
    );
  }

  bool _hasActiveFilters() {
    return _startDate != null || 
           _endDate != null || 
           _sortOrder != 'Newest First';
  }

  Widget _buildBody() {
    if (_isLoading && _progressNotes.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF199A8E),
        ),
      );
    }

    if (_hasError) {
      return _buildErrorState();
    }

    if (_progressNotes.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _progressNotes.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _progressNotes.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(
                color: Color(0xFF199A8E),
              ),
            ),
          );
        }

        return _buildCleanProgressNoteCard(_progressNotes[index], index);
      },
    );
  }

  // [REST OF THE CODE REMAINS THE SAME - all the card building methods, etc.]
  
  Widget _buildCleanProgressNoteCard(Map<String, dynamic> note, int index) {
    final visitDate = DateTime.parse(note['visit_date']);
    final nurseName = note['nurse']?['name'] ?? 'Unknown Nurse';
    final generalCondition = note['general_condition'] ?? 'N/A';
    final painLevel = note['pain_level'] ?? 0;

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
          onTap: () => _viewFullNoteDetail(note['id']),
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
                        color: const Color(0xFF199A8E).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.edit_note_rounded,
                        color: Color(0xFF199A8E),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Daily Progress Note',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 12,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${DateFormat('MMM d, yyyy').format(visitDate)} • ${note['visit_time'] ?? 'N/A'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF199A8E).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios,
                        color: Color(0xFF199A8E),
                        size: 16,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.health_and_safety,
                            size: 16,
                            color: _getConditionIconColor(generalCondition),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              generalCondition,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    Container(
                      width: 1,
                      height: 20,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      color: Colors.grey[300],
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.sentiment_satisfied_alt,
                          size: 16,
                          color: _getPainLevelIconColor(painLevel),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Pain: $painLevel/10',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                if (note['nurse'] != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFF199A8E).withOpacity(0.1),
                          child: Text(
                            nurseName.isNotEmpty ? nurseName[0].toUpperCase() : 'N',
                            style: const TextStyle(
                              color: Color(0xFF199A8E),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nurseName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A1A1A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Visiting Nurse',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF199A8E).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF199A8E).withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.visibility_outlined,
                        color: Color(0xFF199A8E),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Tap to view complete details',
                        style: TextStyle(
                          fontSize: 12,
                          color: const Color(0xFF199A8E),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                
                if (note['created_at'] != null) ...[
                  const SizedBox(height: 12),
                  Divider(height: 1, color: Colors.grey[200]),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            'Recorded',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _formatTimeAgo(DateTime.parse(note['created_at'])),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
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

  Future<void> _viewFullNoteDetail(int noteId) async {
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
      final response = await _progressNotesService.getProgressNoteById(noteId);
      
      if (mounted) {
        Navigator.pop(context);
        _showDetailedNoteBottomSheet(response.data);
      }
    } on ProgressNotesException catch (e) {
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

  // [All the remaining methods stay exactly the same - _showDetailedNoteBottomSheet, helpers, etc.]
  void _showDetailedNoteBottomSheet(ProgressNoteDetail noteDetail) {
    // Keep the same implementation
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
                          Icons.note_alt_rounded,
                          color: Color(0xFF199A8E),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Daily Progress Note',
                          style: TextStyle(
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
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2196F3).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.calendar_today,
                              color: Color(0xFF2196F3),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Visit Date & Time',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_formatDate(DateTime.parse(noteDetail.visitDate))} • ${noteDetail.visitTime}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    if (noteDetail.nurse != null) ...[
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
                              child: Center(
                                child: Text(
                                  noteDetail.nurse!.name.isNotEmpty
                                      ? noteDetail.nurse!.name[0].toUpperCase()
                                      : 'N',
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
                                    'Nurse',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    noteDetail.nurse!.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.health_and_safety,
                                      size: 16,
                                      color: Color(0xFF199A8E),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'General Condition',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  noteDetail.generalCondition,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFF1A1A1A),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.sentiment_satisfied_alt,
                                      size: 16,
                                      color: Color(0xFFFF9A00),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Pain Level',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${noteDetail.painLevel}/10',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFF1A1A1A),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    if (noteDetail.vitals != null) ...[
                      _buildDetailSectionHeader('Vital Signs', Icons.favorite),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8F5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFFF9A00).withOpacity(0.2),
                          ),
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (noteDetail.vitals!['temperature'] != null)
                              _buildDetailVitalBadge(
                                icon: Icons.thermostat,
                                label: 'Temp',
                                value: '${noteDetail.vitals!['temperature']}°C',
                                color: const Color(0xFFFF9A00),
                              ),
                            if (noteDetail.vitals!['pulse'] != null)
                              _buildDetailVitalBadge(
                                icon: Icons.monitor_heart,
                                label: 'Pulse',
                                value: '${noteDetail.vitals!['pulse']} bpm',
                                color: const Color(0xFFFF4757),
                              ),
                            if (noteDetail.vitals!['blood_pressure'] != null)
                              _buildDetailVitalBadge(
                                icon: Icons.favorite,
                                label: 'BP',
                                value: noteDetail.vitals!['blood_pressure'].toString(),
                                color: const Color(0xFFFF6B9D),
                              ),
                            if (noteDetail.vitals!['respiration'] != null)
                              _buildDetailVitalBadge(
                                icon: Icons.air,
                                label: 'Resp',
                                value: '${noteDetail.vitals!['respiration']}/min',
                                color: const Color(0xFF2196F3),
                              ),
                            if (noteDetail.vitals!['spo2'] != null)
                              _buildDetailVitalBadge(
                                icon: Icons.speed,
                                label: 'SpO₂',
                                value: '${noteDetail.vitals!['spo2']}%',
                                color: const Color(0xFF199A8E),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    
                    if (noteDetail.interventions != null && _hasAnyInterventions(noteDetail.interventions!)) ...[
                      _buildDetailSectionHeader('Interventions Provided', Icons.medical_services),
                      const SizedBox(height: 12),
                      ..._buildDetailInterventionsList(noteDetail.interventions!),
                      const SizedBox(height: 20),
                    ],
                    
                    if (noteDetail.woundStatus != null && noteDetail.woundStatus!.isNotEmpty) ...[
                      _buildDetailInfoSection(
                        icon: Icons.healing,
                        title: 'WOUND STATUS',
                        content: noteDetail.woundStatus!,
                        backgroundColor: const Color(0xFFFFF3E0),
                        borderColor: const Color(0xFFFF9800),
                      ),
                      const SizedBox(height: 20),
                    ],
                    
                    if (noteDetail.otherObservations != null && noteDetail.otherObservations!.isNotEmpty) ...[
                      _buildDetailInfoSection(
                        icon: Icons.remove_red_eye,
                        title: 'OTHER OBSERVATIONS',
                        content: noteDetail.otherObservations!,
                        backgroundColor: const Color(0xFFF5F0FF),
                        borderColor: const Color(0xFF6C63FF),
                      ),
                      const SizedBox(height: 20),
                    ],
                    
                    if (noteDetail.educationProvided != null && noteDetail.educationProvided!.isNotEmpty) ...[
                      _buildDetailInfoSection(
                        icon: Icons.school,
                        title: 'EDUCATION PROVIDED',
                        content: noteDetail.educationProvided!,
                        backgroundColor: const Color(0xFFE8F5E9),
                        borderColor: const Color(0xFF4CAF50),
                      ),
                      const SizedBox(height: 20),
                    ],
                    
                    if (noteDetail.familyConcerns != null && noteDetail.familyConcerns!.isNotEmpty) ...[
                      _buildDetailInfoSection(
                        icon: Icons.people,
                        title: 'FAMILY/CLIENT CONCERNS',
                        content: noteDetail.familyConcerns!,
                        backgroundColor: const Color(0xFFFFF8E1),
                        borderColor: const Color(0xFFFFC107),
                      ),
                      const SizedBox(height: 20),
                    ],
                    
                    if (noteDetail.nextSteps != null && noteDetail.nextSteps!.isNotEmpty) ...[
                      _buildDetailInfoSection(
                        icon: Icons.event_note,
                        title: 'PLAN / NEXT STEPS',
                        content: noteDetail.nextSteps!,
                        backgroundColor: const Color(0xFFE3F2FD),
                        borderColor: const Color(0xFF2196F3),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            if (noteDetail.createdAt != null)
              Container(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: 24,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border(top: BorderSide(color: Colors.grey[200]!)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          'Recorded',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _formatTimeAgo(DateTime.parse(noteDetail.createdAt!)),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
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

  bool _hasAnyInterventions(Map<String, dynamic> interventions) {
    return interventions['medication_administered'] == true ||
        interventions['wound_care'] == true ||
        interventions['physiotherapy'] == true ||
        interventions['nutrition_support'] == true ||
        interventions['hygiene_care'] == true ||
        interventions['counseling'] == true ||
        interventions['other_interventions'] == true;
  }

  List<Widget> _buildDetailInterventionsList(Map<String, dynamic> interventions) {
    final List<Widget> interventionWidgets = [];
    
    final interventionTypes = [
      {
        'key': 'medication_administered',
        'detailKey': 'medication_details',
        'icon': Icons.medication,
        'label': 'Medication Administered',
        'color': const Color(0xFFFF4757),
      },
      {
        'key': 'wound_care',
        'detailKey': 'wound_care_details',
        'icon': Icons.healing,
        'label': 'Wound Care',
        'color': const Color(0xFFFF9800),
      },
      {
        'key': 'physiotherapy',
        'detailKey': 'physiotherapy_details',
        'icon': Icons.fitness_center,
        'label': 'Physiotherapy/Exercise',
        'color': const Color(0xFF2196F3),
      },
      {
        'key': 'nutrition_support',
        'detailKey': 'nutrition_details',
        'icon': Icons.restaurant,
        'label': 'Nutrition/Feeding Support',
        'color': const Color(0xFFFF9A00),
      },
      {
        'key': 'hygiene_care',
        'detailKey': 'hygiene_details',
        'icon': Icons.cleaning_services,
        'label': 'Hygiene/Personal Care',
        'color': const Color(0xFF6C63FF),
      },
      {
        'key': 'counseling',
        'detailKey': 'counseling_details',
        'icon': Icons.psychology,
        'label': 'Counseling/Education',
        'color': const Color(0xFF199A8E),
      },
      {
        'key': 'other_interventions',
        'detailKey': 'other_details',
        'icon': Icons.more_horiz,
        'label': 'Other Interventions',
        'color': const Color(0xFF9C27B0),
      },
    ];
    
    for (var intervention in interventionTypes) {
      if (interventions[intervention['key']] == true) {
        final details = interventions[intervention['detailKey']] as String?;
        interventionWidgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (intervention['color'] as Color).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (intervention['color'] as Color).withOpacity(0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (intervention['color'] as Color).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      intervention['icon'] as IconData,
                      color: intervention['color'] as Color,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          intervention['label'] as String,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        if (details != null && details.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            details,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                              height: 1.4,
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
        );
      }
    }
    
    return interventionWidgets;
  }

  Widget _buildDetailSectionHeader(String title, IconData icon) {
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

  Widget _buildDetailInfoSection({
    required IconData icon,
    required String title,
    required String content,
    required Color backgroundColor,
    required Color borderColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF999999),
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor.withOpacity(0.2),
            ),
          ),
          child: Text(
            content,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[800],
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailVitalBadge({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getConditionIconColor(String condition) {
    switch (condition.toLowerCase()) {
      case 'stable':
        return const Color(0xFF199A8E);
      case 'improved':
      case 'improving':
        return Colors.green;
      case 'deteriorating':
      case 'declining':
        return Colors.orange;
      case 'critical':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getPainLevelIconColor(int painLevel) {
    if (painLevel == 0) return Colors.green;
    if (painLevel <= 3) return const Color(0xFF199A8E);
    if (painLevel <= 6) return const Color(0xFFFF9A00);
    return const Color(0xFFFF4757);
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inMinutes}m ago';
    }
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
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
                        Icons.note_alt_outlined,
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
              child: Text(
                _searchQuery.isNotEmpty
                    ? 'No Progress Notes Found'
                    : 'No Progress Notes Yet',
                style: const TextStyle(
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
                _searchQuery.isNotEmpty
                    ? 'Try adjusting your search query or filters'
                    : 'Your progress notes will appear here once they are added to your care roster',
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
              onPressed: () => _loadProgressNotes(refresh: true, forceRefresh: true),
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