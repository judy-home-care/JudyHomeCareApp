import 'dart:async';
import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../services/care_plans/care_plan_service.dart';
import '../../models/care_plans/care_plan_models.dart';
import 'edit_care_plan_modal.dart';
import '../../widgets/searchable_dropdown.dart';


/// Complete Optimized Care Plans Screen with Task Toggle Feature & Pagination
class CarePlansScreen extends StatefulWidget {
  final Map<String, dynamic> nurseData;
  
  const CarePlansScreen({
    Key? key,
    required this.nurseData,
  }) : super(key: key);

  @override
  State<CarePlansScreen> createState() => _CarePlansScreenState();
}

class _CarePlansScreenState extends State<CarePlansScreen>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  
  @override
  bool get wantKeepAlive => true;

  final _carePlanService = CarePlanService();
  late AnimationController _animationController;
  final _scrollController = ScrollController();
  
  // UI State
  String _searchQuery = '';
  String _selectedFilter = 'all';
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  List<CarePlan> _carePlans = [];
  
  // OPTIMIZATION: Cached filtered data to avoid repeated computations
  List<CarePlan> _cachedFilteredPlans = [];
  int _cachedActiveCount = 0;
  int _cachedCompletedCount = 0;
  int _cachedDraftCount = 0;
  int _cachedTotalCount = 0;
  
  // Pagination - NEW
  static const int _perPage = 15;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalCarePlans = 0;
  bool _hasMorePages = false;
  
  // Scroll optimization - NEW
  Timer? _scrollDebounce;
  double _lastScrollPosition = 0;
  bool _canLoadMore = true;
  
  // Cache Management
  DateTime? _lastFetchTime;
  DateTime? _lastRefreshAttempt;
  static const Duration _cacheValidityDuration = Duration(minutes: 2);
  static const Duration _minRefreshInterval = Duration(seconds: 30);
  static const Duration _backgroundReturnThreshold = Duration(minutes: 2);
  
  // Visibility Tracking
  bool _isTabVisible = false;
  DateTime? _lastVisibleTime;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scrollController.addListener(_onScroll);
    _loadCarePlans(forceRefresh: false);
  }

  @override
  void dispose() {
    _scrollDebounce?.cancel();
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // ==================== SCROLL HANDLING ====================
  
  void _onScroll() {
    // Cancel previous debounce timer
    _scrollDebounce?.cancel();
    
    final currentPosition = _scrollController.position.pixels;
    final maxScroll = _scrollController.position.maxScrollExtent;
    
    // Lower threshold (100px) and trigger on any scroll near bottom
    if (currentPosition >= maxScroll - 100) {
      // Debounce the load more call
      _scrollDebounce = Timer(const Duration(milliseconds: 200), () {
        if (_canLoadMore && !_isLoadingMore && _hasMorePages && mounted) {
          _loadMoreCarePlans();
        }
      });
    }
    
    _lastScrollPosition = currentPosition;
  }

  // ==================== PUBLIC METHODS FOR PARENT NAVIGATION ====================
  
  void loadCarePlans({bool forceRefresh = false}) {
    _loadCarePlans(forceRefresh: forceRefresh);
  }
  
  // ==================== SMART REFRESH LOGIC ====================
  
  void onTabVisible() {
    _isTabVisible = true;
    final now = DateTime.now();
    
    debugPrint('👁️ Care Plans tab visible - checking if refresh needed');
    
    final timeSinceLastVisible = _lastVisibleTime != null 
        ? now.difference(_lastVisibleTime!) 
        : null;
    
    _lastVisibleTime = now;
    
    if (_shouldRefreshOnVisible(timeSinceLastVisible)) {
      debugPrint('🔄 Auto-refreshing care plans (reason: ${_getRefreshReason(timeSinceLastVisible)})');
      _loadCarePlans(forceRefresh: true, silent: true);
    } else {
      debugPrint('✅ Using cached data - still fresh');
    }
  }
  
  void onTabHidden() {
    _isTabVisible = false;
    debugPrint('👁️‍🗨️ Care Plans tab hidden');
  }
  
  bool _shouldRefreshOnVisible(Duration? timeSinceLastVisible) {
    if (_lastRefreshAttempt != null) {
      final timeSinceRefresh = DateTime.now().difference(_lastRefreshAttempt!);
      if (timeSinceRefresh < _minRefreshInterval) {
        debugPrint('⏱️ Rate limit: Last refresh was ${timeSinceRefresh.inSeconds}s ago');
        return false;
      }
    }
    
    if (_isCacheExpired) return true;
    
    if (timeSinceLastVisible != null && 
        timeSinceLastVisible > _backgroundReturnThreshold) {
      return true;
    }
    
    return false;
  }
  
  String _getRefreshReason(Duration? timeSinceLastVisible) {
    if (_isCacheExpired) return 'cache expired';
    if (timeSinceLastVisible != null && 
        timeSinceLastVisible > _backgroundReturnThreshold) {
      return 'returning after ${timeSinceLastVisible.inMinutes}m';
    }
    return 'manual';
  }
  
  bool get _isCacheExpired {
    if (_lastFetchTime == null || _carePlans.isEmpty) return true;
    final difference = DateTime.now().difference(_lastFetchTime!);
    return difference >= _cacheValidityDuration;
  }
  
  String get _cacheAge {
    if (_lastFetchTime == null) return 'Never';
    final difference = DateTime.now().difference(_lastFetchTime!);
    
    if (difference.inSeconds < 60) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }
  
  Color get _cacheFreshnessColor {
    if (_lastFetchTime == null) return Colors.grey;
    final difference = DateTime.now().difference(_lastFetchTime!);
    
    if (difference < const Duration(minutes: 2)) return AppColors.primaryGreen;
    if (difference < _cacheValidityDuration) return const Color(0xFFFF9A00);
    return Colors.red;
  }

  // ==================== OPTIMIZATION: Update cached data ====================
  
  void _updateCachedData() {
    // Cache filtered plans
    _cachedFilteredPlans = _carePlans.where((plan) {
      final matchesSearch = _searchQuery.isEmpty ||
          plan.patient.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          plan.carePlan.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          plan.doctor.toLowerCase().contains(_searchQuery.toLowerCase());
      
      final matchesFilter = _selectedFilter == 'all' ||
          plan.status.toLowerCase() == _selectedFilter.toLowerCase();
      
      return matchesSearch && matchesFilter;
    }).toList();
    
    // FIXED: Only update status counts when we have all the data (viewing "all" filter)
    // This prevents counts from being recalculated based on filtered data
    if (_selectedFilter == 'all') {
      _cachedActiveCount = _carePlans.where((p) => p.status.toLowerCase() == 'active').length;
      _cachedCompletedCount = _carePlans.where((p) => p.status.toLowerCase() == 'completed').length;
      _cachedDraftCount = _carePlans.where((p) => p.status.toLowerCase() == 'draft').length;
      _cachedTotalCount = _totalCarePlans;
    }
    // When viewing a specific filter, keep the existing cached counts intact
  }

  // ==================== DATA LOADING ====================
  
  Future<void> _loadCarePlans({
    bool forceRefresh = false, 
    bool silent = false
  }) async {
    if (!forceRefresh && _lastRefreshAttempt != null) {
      final timeSinceLastAttempt = DateTime.now().difference(_lastRefreshAttempt!);
      if (timeSinceLastAttempt < _minRefreshInterval) {
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }
    }
    
    if (!forceRefresh && !_isCacheExpired && _carePlans.isNotEmpty) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('📦 Using cached care plans data ($_cacheAge)');
      return;
    }

    if (!silent && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    
    _lastRefreshAttempt = DateTime.now();
    debugPrint('🌐 Fetching care plans from API (page $_currentPage)...');

    try {
      final response = await _carePlanService.getNurseCarePlans(
        search: _searchQuery.isEmpty ? null : _searchQuery,
        status: _selectedFilter == 'all' ? null : _selectedFilter,
        page: _currentPage,
        perPage: _perPage,
      );

      if (mounted) {
        final hadPlans = _carePlans.isNotEmpty;
        final newPlanCount = response.data.length;
        
        setState(() {
          _carePlans = response.data;
          // FIXED: Check if properties exist before accessing them
          _totalCarePlans = response.total ?? newPlanCount;
          _currentPage = response.currentPage ?? 1;
          _totalPages = response.lastPage ?? 1;
          _hasMorePages = _currentPage < _totalPages;
          _lastFetchTime = DateTime.now();
          _isLoading = false;
          _canLoadMore = true;
          _updateCachedData();
        });
        
        debugPrint('✅ Care plans loaded: $newPlanCount plans ($_cacheAge)');
        debugPrint('📊 Page $_currentPage of $_totalPages');
        
        if (silent && _isTabVisible && newPlanCount > 0 && 
            (!hadPlans || newPlanCount != hadPlans)) {
          _showDataUpdatedNotification(newPlanCount);
        }
      }
    } on CarePlanException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isLoading = false;
        });
        debugPrint('❌ Error loading care plans: ${e.message}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An unexpected error occurred. Please try again.';
          _isLoading = false;
        });
        debugPrint('❌ Unexpected error: $e');
      }
    }
  }
  
  /// Load more care plans (pagination) - NEW
  Future<void> _loadMoreCarePlans() async {
    if (_isLoadingMore || !_hasMorePages || !_canLoadMore) {
      debugPrint('⚠️ Load more blocked: isLoading=$_isLoadingMore, hasMore=$_hasMorePages, canLoad=$_canLoadMore');
      return;
    }

    debugPrint('🔄 Loading page ${_currentPage + 1}...');

    setState(() {
      _isLoadingMore = true;
      _canLoadMore = false;
    });

    try {
      final nextPage = _currentPage + 1;
      final response = await _carePlanService.getNurseCarePlans(
        search: _searchQuery.isEmpty ? null : _searchQuery,
        status: _selectedFilter == 'all' ? null : _selectedFilter,
        page: nextPage,
        perPage: _perPage,
      );

      if (mounted) {
        setState(() {
          _currentPage = nextPage;
          _carePlans.addAll(response.data);
          // FIXED: Check if properties exist before accessing them
          _totalCarePlans = response.total ?? _carePlans.length;
          _totalPages = response.lastPage ?? _totalPages;
          _hasMorePages = _currentPage < _totalPages;
          _isLoadingMore = false;
          _updateCachedData();
        });
        
        debugPrint('✅ Loaded ${response.data.length} more care plans');
        debugPrint('📊 Now showing ${_carePlans.length} of $_totalCarePlans');
        
        // Re-enable loading after a short delay
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _canLoadMore = true;
            });
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading more: $e');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          _canLoadMore = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load more care plans: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
  
  void _showDataUpdatedNotification(int planCount) {
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
              child: const Icon(Icons.refresh, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Care plans updated • $planCount ${planCount == 1 ? 'plan' : 'plans'}'),
            ),
          ],
        ),
        backgroundColor: AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  Future<void> _refreshData() async {
    setState(() {
      _currentPage = 1;
      _carePlans.clear();
    });
    await _loadCarePlans(forceRefresh: true);
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
        return AppColors.primaryGreen;
      case 'draft':
        return const Color(0xFFFF9A00);
      case 'completed':
        return const Color(0xFF6C63FF);
      default:
        return Colors.grey;
    }
  }

  // ==================== TASK TOGGLE FUNCTIONALITY ====================
  
  Future<void> _toggleTaskCompletion(CarePlan carePlan, int taskIndex, bool currentStatus) async {
    try {
      debugPrint('🔄 Toggling task $taskIndex for care plan ${carePlan.id}');
      
      // Optimistically update UI
      setState(() {
        if (currentStatus) {
          // Remove from completed tasks
          carePlan.completedTasks.remove(taskIndex);
        } else {
          // Add to completed tasks
          if (!carePlan.completedTasks.contains(taskIndex)) {
            carePlan.completedTasks.add(taskIndex);
          }
        }
        
        // Update progress
        final totalTasks = carePlan.careTasks.length;
        final completedCount = carePlan.completedTasks.length;
        carePlan.progress = totalTasks > 0 ? completedCount / totalTasks : 0.0;
      });

      // Call API
      await _carePlanService.toggleCareTaskCompletion(
        carePlanId: carePlan.id,
        taskIndex: taskIndex,
        isCompleted: !currentStatus,
      );

      debugPrint('✅ Task toggle successful');
      
      // Show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  !currentStatus ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    !currentStatus ? 'Task marked as completed' : 'Task marked as incomplete',
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.primaryGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
    } catch (e) {
      debugPrint('❌ Error toggling task: $e');
      
      // Revert optimistic update on error
      setState(() {
        if (!currentStatus) {
          carePlan.completedTasks.remove(taskIndex);
        } else {
          if (!carePlan.completedTasks.contains(taskIndex)) {
            carePlan.completedTasks.add(taskIndex);
          }
        }
        
        // Recalculate progress
        final totalTasks = carePlan.careTasks.length;
        final completedCount = carePlan.completedTasks.length;
        carePlan.progress = totalTasks > 0 ? completedCount / totalTasks : 0.0;
      });
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Failed to update task: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFFF4757),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // ==================== BUILD METHOD ====================
  
  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Care Plans',
              style: TextStyle(
                color: Color(0xFF1A1F36),
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            if (_lastFetchTime != null)
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _cacheFreshnessColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _cacheFreshnessColor.withOpacity(0.3),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
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
        ),
        actions: [
          IconButton(
            icon: _isLoading && !_isCacheExpired
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
                    ),
                  )
                : Icon(
                    Icons.refresh_rounded,
                    color: _isCacheExpired ? Colors.red : AppColors.primaryGreen,
                  ),
            onPressed: _isLoading ? null : () => _refreshData(),
            tooltip: _isCacheExpired ? 'Data expired - Tap to refresh' : 'Refresh care plans',
          ),
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.black),
            onPressed: _showFilterOptions,
            tooltip: 'Filter Care Plans',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.grey.shade200,
                  Colors.grey.shade100,
                  Colors.grey.shade200,
                ],
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: AppColors.primaryGreen,
        child: Column(
          children: [
            _buildModernSearchAndFilter(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _carePlans.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
        ),
      );
    }

    if (_errorMessage != null && _carePlans.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                'Error',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _loadCarePlans(forceRefresh: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_cachedFilteredPlans.isEmpty) {
      return _buildEmptyState();
    }

    return _buildCarePlansList();
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.folder_outlined,
                size: 60,
                color: AppColors.primaryGreen.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No care plans found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty || _selectedFilter != 'all'
                  ? 'Try adjusting your filters'
                  : 'No care plans assigned yet',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: () => _showCreateCarePlanModal(),
      backgroundColor: AppColors.primaryGreen,
      elevation: 4,
      heroTag: 'create_care_plan_fab',
      icon: const Icon(Icons.add, size: 24, color: Colors.white),
      label: const Text(
        'New Care Plan',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: Colors.white,
        ),
      ),
    );
  }

  // ==================== MODERN SEARCH AND FILTER ====================
  
  Widget _buildModernSearchAndFilter() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _searchQuery.isNotEmpty 
                      ? AppColors.primaryGreen.withOpacity(0.3)
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                    _currentPage = 1;
                    _carePlans.clear();
                  });
                  // Trigger search with debounce would be ideal here
                  _loadCarePlans(forceRefresh: true);
                },
                decoration: InputDecoration(
                  hintText: 'Search care plans, patients, doctors...',
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                  prefixIcon: Container(
                    padding: const EdgeInsets.all(14),
                    child: Icon(
                      Icons.search_rounded,
                      color: _searchQuery.isNotEmpty 
                          ? AppColors.primaryGreen 
                          : Colors.grey[400],
                      size: 22,
                    ),
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: Colors.grey[400],
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                              _currentPage = 1;
                              _carePlans.clear();
                            });
                            _loadCarePlans(forceRefresh: true);
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
              ),
            ),
          ),
          
          // Tab buttons
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: _buildTabButton('All', 'all', _cachedTotalCount),  // FIXED
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTabButton('Active', 'active', _cachedActiveCount),  // Already correct
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTabButton('Draft', 'draft', _cachedDraftCount),  // Already correct
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTabButton('Done', 'completed', _cachedCompletedCount),  // Already correct
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, String value, int count) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () {
        if (_selectedFilter != value) {
          setState(() {
            _selectedFilter = value;
            _currentPage = 1;
            _carePlans.clear();
          });
          _animationController.forward(from: 0);
          _loadCarePlans(forceRefresh: true);
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

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => Container(
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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filter Care Plans',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3436),
                    ),
                  ),
                  if (_selectedFilter != 'all')
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedFilter = 'all';
                          _currentPage = 1;
                          _carePlans.clear();
                        });
                        Navigator.pop(context);
                        _loadCarePlans(forceRefresh: true);
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
            const Text(
              'Status',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D3436),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildModalFilterOption('All Status', 'all'),
                _buildModalFilterOption('Active', 'active'),
                _buildModalFilterOption('Draft', 'draft'),
                _buildModalFilterOption('Completed', 'completed'),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildModalFilterOption(String label, String value) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = value;
          _currentPage = 1;
          _carePlans.clear();
        });
        Navigator.pop(context);
        _loadCarePlans(forceRefresh: true);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreen : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaryGreen : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.check_circle, color: Colors.white, size: 18),
              ),
            Text(
              label,
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
  }

  Widget _buildCarePlansList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _cachedFilteredPlans.length + (_hasMorePages ? 1 : 0),
      addAutomaticKeepAlives: true,
      cacheExtent: 500,
      itemBuilder: (context, index) {
        if (index == _cachedFilteredPlans.length) {
          return _buildLoadMoreIndicator();
        }
        return _buildCarePlanCard(_cachedFilteredPlans[index]);
      },
    );
  }

  Widget _buildLoadMoreIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      alignment: Alignment.center,
      child: _isLoadingMore
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading more care plans...',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            )
          : Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              child: ElevatedButton.icon(
                onPressed: _canLoadMore ? _loadMoreCarePlans : null,
                icon: const Icon(Icons.expand_more_rounded, size: 20),
                label: Text(
                  'Load More (${_totalCarePlans - _carePlans.length} remaining)',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildCarePlanCard(CarePlan plan) {
    final priorityColor = _getPriorityColor(plan.priority);
    final statusColor = _getStatusColor(plan.status);

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
          onTap: () => _showCarePlanDetails(plan),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          plan.patientInitials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan.patient,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1F36),
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: statusColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        plan.status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  plan.carePlan,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1F36),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  plan.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildInfoChip(
                      Icons.medical_services_outlined,
                      plan.doctor,
                      const Color(0xFF6C63FF),
                    ),
                    const SizedBox(width: 10),
                    _buildInfoChip(
                      Icons.access_time_outlined,
                      '${plan.estimatedHours}h/day',
                      const Color(0xFF2196F3),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: priorityColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: priorityColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            plan.priority,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: priorityColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: plan.progress,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${(plan.progress * 100).toInt()}% Complete',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== CARE PLAN DETAILS MODAL WITH TASK TOGGLE ====================
  
  void _showCarePlanDetails(CarePlan plan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
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
                      AppColors.primaryGreen.withOpacity(0.1),
                      AppColors.primaryGreen.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
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
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primaryGreen, Color(0xFF25B5A8)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              plan.patientInitials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
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
                                plan.patient,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                plan.carePlan,
                                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
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
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _showEditCarePlanModal(plan);
                          },
                          icon: const Icon(Icons.edit_outlined, color: AppColors.primaryGreen),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen.withOpacity(0.1),
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
              
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailCard(
                              icon: Icons.category_outlined,
                              title: 'Care Type',
                              value: plan.careType,
                              color: const Color(0xFF2196F3),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDetailCard(
                              icon: Icons.info_outline,
                              title: 'Status',
                              value: plan.status,
                              color: _getStatusColor(plan.status),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      _buildSectionTitle('Schedule'),
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
                                color: AppColors.primaryGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.calendar_today,
                                size: 20,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Start Date',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    plan.startDate ?? 'Not set',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (plan.endDate != null) ...[
                              Container(
                                width: 1,
                                height: 40,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'End Date',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      plan.endDate!,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1A1A1A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      if (plan.description.isNotEmpty) ...[
                        _buildSectionTitle('Description'),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFB),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Text(
                            plan.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              height: 1.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      
                      // ==================== TASK LIST WITH TOGGLE ====================
                      if (plan.careTasks.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildSectionTitle('Care Tasks'),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${plan.completedTaskCount}/${plan.totalTaskCount} completed',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F9FF),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF2196F3).withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            children: plan.careTasks.asMap().entries.map((entry) {
                              final index = entry.key;
                              final task = entry.value;
                              final isLast = index == plan.careTasks.length - 1;
                              final isCompleted = plan.isTaskCompleted(index);
                              
                              return Column(
                                children: [
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        // Toggle task and update both states
                                        _toggleTaskCompletion(plan, index, isCompleted);
                                        setModalState(() {}); // Update modal
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        child: Row(
                                          children: [
                                            // Custom Checkbox
                                            Container(
                                              width: 24,
                                              height: 24,
                                              decoration: BoxDecoration(
                                                color: isCompleted 
                                                    ? AppColors.primaryGreen 
                                                    : Colors.white,
                                                border: Border.all(
                                                  color: isCompleted 
                                                      ? AppColors.primaryGreen 
                                                      : Colors.grey.shade400,
                                                  width: 2,
                                                ),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: isCompleted
                                                  ? const Icon(
                                                      Icons.check,
                                                      size: 16,
                                                      color: Colors.white,
                                                    )
                                                  : null,
                                            ),
                                            const SizedBox(width: 12),
                                            // Task number
                                            Container(
                                              width: 28,
                                              height: 28,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: isCompleted
                                                      ? [Colors.grey.shade400, Colors.grey.shade500]
                                                      : [const Color(0xFF2196F3), const Color(0xFF42A5F5)],
                                                ),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  '${index + 1}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            // Task text
                                            Expanded(
                                              child: Text(
                                                task,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: isCompleted 
                                                      ? Colors.grey.shade500 
                                                      : const Color(0xFF1A1A1A),
                                                  fontWeight: FontWeight.w500,
                                                  decoration: isCompleted 
                                                      ? TextDecoration.lineThrough 
                                                      : null,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (!isLast) ...[
                                    const SizedBox(height: 12),
                                    Divider(color: Colors.grey.shade200, height: 1),
                                    const SizedBox(height: 12),
                                  ],
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFB),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    color: Colors.grey.shade600,
                                    size: 24,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${plan.estimatedHours}h',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'per day',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
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
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.repeat,
                                    color: Colors.grey.shade600,
                                    size: 24,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    plan.frequency,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'frequency',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primaryGreen, Color(0xFF25B5A8)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ],
    );
  }

  // ==================== CREATE CARE PLAN MODAL ====================
  
  void _showCreateCarePlanModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => WillPopScope(
        onWillPop: () async {
          final shouldPop = await _showDiscardDialog(context);
          return shouldPop ?? false;
        },
        child: CreateCarePlanModal(
          existingCarePlans: _carePlans,
          onSuccess: () {
            _refreshData();
          },
        ),
      ),
    );
  }

  // ==================== EDIT CARE PLAN MODAL ====================
  
  void _showEditCarePlanModal(CarePlan carePlan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => WillPopScope(
        onWillPop: () async {
          final shouldPop = await _showDiscardDialog(context);
          return shouldPop ?? false;
        },
        child: EditCarePlanModal(
          carePlan: carePlan,
          existingCarePlans: _carePlans,
          onSuccess: () {
            _refreshData();
          },
        ),
      ),
    );
  }

  Future<bool?> _showDiscardDialog(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFFF9A00)),
            SizedBox(width: 12),
            Text('Discard Changes?'),
          ],
        ),
        content: Text(
          'Are you sure you want to go back? Any unsaved changes will be lost.',
          style: TextStyle(
            color: Colors.grey.shade700,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continue Editing'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, true);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4757),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }
}

// ==================== CREATE CARE PLAN MODAL ====================
class CreateCarePlanModal extends StatefulWidget {
  final VoidCallback onSuccess;
  final List<CarePlan> existingCarePlans;

  const CreateCarePlanModal({
    Key? key,
    required this.onSuccess,
    required this.existingCarePlans,
  }) : super(key: key);

  @override
  State<CreateCarePlanModal> createState() => _CreateCarePlanModalState();
}

class _CreateCarePlanModalState extends State<CreateCarePlanModal> {
  final _formKey = GlobalKey<FormState>();
  final _carePlanService = CarePlanService();
  bool _isSaving = false;
  
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<TextEditingController> _taskControllers = [TextEditingController()];
  
  String? _selectedPatientId;
  String? _selectedDoctorId;
  String? _selectedCareRequestId;
  String? _selectedCareType;
  String? _selectedPriority;
  String? _selectedFrequency;
  
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  
  List<Map<String, dynamic>> _patients = [];
  List<Map<String, dynamic>> _doctors = [];
  List<Map<String, dynamic>> _careRequests = [];
  bool _loadingCareRequests = false;
  final List<String> _careTypes = [
    'General Care',
    'Elderly Care',
    'Post-Surgery Care',
    'Pediatric Care',
    'Chronic Disease Management',
    'Palliative Care',
    'Rehabilitation Care',
  ];
  final List<String> _priorities = ['Low', 'Medium', 'High'];
  final List<String> _frequencies = ['Daily', 'Weekly', 'Bi-weekly', 'Monthly', 'As Needed'];

  String _transformCareTypeToBackend(String uiValue) {
  if (uiValue.isEmpty) return '';
  return uiValue.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_');
}

/// Transform priority from UI format to backend format
String _transformPriorityToBackend(String uiValue) {
  if (uiValue.isEmpty) return '';
  return uiValue.toLowerCase();
}

/// Transform frequency from UI format to backend format
String _transformFrequencyToBackend(String uiValue) {
  if (uiValue.isEmpty) return '';
  
  final normalized = uiValue.toLowerCase().trim();
  
  switch (normalized) {
    case 'daily':
      return 'once_daily';
    case 'bi-weekly':
    case 'bi weekly':
    case 'biweekly':
      return 'twice_weekly';
    case 'as needed':
      return 'as_needed';
    case 'weekly':
      return 'weekly';
    case 'monthly':
      return 'monthly';
    default:
      return normalized.replaceAll(' ', '_').replaceAll('-', '_');
  }
}

  @override
  void initState() {
    super.initState();
    _loadDropdownData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    for (var controller in _taskControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCareRequestsForPatient(String patientId) async {
    if (patientId.isEmpty) {
      setState(() {
        _careRequests = [];
        _selectedCareRequestId = null;
      });
      return;
    }

    setState(() {
      _loadingCareRequests = true;
    });

    try {
      final careRequests = await _carePlanService.getPatientCareRequests(int.parse(patientId));
      
      if (mounted) {
        setState(() {
          _careRequests = careRequests;
          _loadingCareRequests = false;
          
          // Clear selected care request if it's no longer in the list
          if (_selectedCareRequestId != null && 
              !_careRequests.any((cr) => cr['id'].toString() == _selectedCareRequestId)) {
            _selectedCareRequestId = null;
          }
        });
        
        debugPrint('✅ Loaded ${_careRequests.length} care requests for patient $patientId');
      }
    } catch (e) {
      debugPrint('❌ Error loading care requests: $e');
      if (mounted) {
        setState(() {
          _careRequests = [];
          _loadingCareRequests = false;
        });
      }
    }
  }

  Future<void> _loadDropdownData() async {
    try {
      // Fetch doctors and patients from dedicated endpoints
      final doctors = await _carePlanService.getDoctors();
      final patients = await _carePlanService.getPatients();

      if (mounted) {
        setState(() {
          _doctors = doctors;
          _patients = patients;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading dropdown data: $e');
      // Optionally show error to user
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : (_endDate ?? DateTime.now()),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryGreen,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  String _formatDateForApi(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _saveCarePlan() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedPatientId == null) {
        _showErrorSnackBar('Please select a patient');
        return;
      }
      if (_selectedCareType == null) {
        _showErrorSnackBar('Please select a care type');
        return;
      }
      if (_selectedPriority == null) {
        _showErrorSnackBar('Please select a priority');
        return;
      }
      if (_selectedFrequency == null) {
        _showErrorSnackBar('Please select a frequency');
        return;
      }

      final tasks = _taskControllers
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      
      if (tasks.isEmpty) {
        _showErrorSnackBar('Please add at least one care task');
        return;
      }

      setState(() => _isSaving = true);

      try {
        final startDateFormatted = _formatDateForApi(_startDate);
        final endDateFormatted = _endDate != null ? _formatDateForApi(_endDate!) : null;

        final careTypeBackend = _transformCareTypeToBackend(_selectedCareType!);
        final priorityBackend = _transformPriorityToBackend(_selectedPriority!);
        final frequencyBackend = _transformFrequencyToBackend(_selectedFrequency!);

        debugPrint('📤 Creating care plan - Transforming values:');
        debugPrint('   Care Type: "$_selectedCareType" → "$careTypeBackend"');
        debugPrint('   Priority: "$_selectedPriority" → "$priorityBackend"');
        debugPrint('   Frequency: "$_selectedFrequency" → "$frequencyBackend"');
        debugPrint('   Care Request ID: $_selectedCareRequestId');

        final response = await _carePlanService.createCarePlan(
          patientId: int.parse(_selectedPatientId!),
          doctorId: _selectedDoctorId != null ? int.parse(_selectedDoctorId!) : null,
          careRequestId: _selectedCareRequestId != null ? int.parse(_selectedCareRequestId!) : null,  // ADD THIS
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          careType: careTypeBackend,
          priority: priorityBackend,
          startDate: startDateFormatted,
          endDate: endDateFormatted,
          frequency: frequencyBackend,
          careTasks: tasks,
        );

        if (mounted) {
          setState(() => _isSaving = false);
          _showSuccessSnackBar('Care plan created successfully!');
          Navigator.pop(context);
          widget.onSuccess();
        }
      } on CarePlanException catch (e) {
        if (mounted) {
          setState(() => _isSaving = false);
          
          String errorMessage = e.message;
          if (e.errors != null && e.errors!.isNotEmpty) {
            final firstError = e.errors!.values.first;
            if (firstError is List && firstError.isNotEmpty) {
              errorMessage = firstError.first.toString();
            } else {
              errorMessage = firstError.toString();
            }
          }
          
          _showErrorSnackBar(errorMessage);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSaving = false);
          _showErrorSnackBar('An unexpected error occurred. Please try again.');
        }
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
          ],
        ),
        backgroundColor: AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height * 0.1,
          left: 16,
          right: 16,
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
          ],
        ),
        backgroundColor: const Color(0xFFFF4757),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height * 0.1,
          left: 16,
          right: 16,
        ),
        action: SnackBarAction(
          label: 'DISMISS',
          textColor: Colors.white,
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        height: MediaQuery.of(context).size.height * 0.95,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Basic Information'),
                      const SizedBox(height: 16),
                      _buildBasicInformation(),
                      const SizedBox(height: 24),
                      
                      _buildSectionTitle('Care Details'),
                      const SizedBox(height: 16),
                      _buildCareDetails(),
                      const SizedBox(height: 24),
                      
                      _buildSectionTitle('Care Tasks'),
                      const SizedBox(height: 16),
                      _buildCareTasks(),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),
            _buildFooterButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
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
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryGreen, Color(0xFF25B5A8)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.assignment_outlined, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Create New Care Plan',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              IconButton(
                onPressed: _isSaving ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey[100],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1A1A1A),
      ),
    );
  }

  Widget _buildBasicInformation() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SearchableDropdown(
                label: 'Patient *',
                value: _selectedPatientId,
                items: _patients.map((p) {
                  final id = p['id'];
                  final name = p['name'];
                  return {
                    'value': id?.toString() ?? '',
                    'label': name?.toString() ?? 'Unknown',
                  };
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPatientId = value;
                    _selectedCareRequestId = null;  // Reset care request when patient changes
                    _careRequests = [];
                  });
                  if (value != null && value.isNotEmpty) {
                    _loadCareRequestsForPatient(value);
                  }
                },
                enabled: !_isSaving,
                hintText: 'Search patients...',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SearchableDropdown(
                label: 'Doctor',
                value: _selectedDoctorId,
                items: _doctors.map((d) {
                  final id = d['id'];
                  final name = d['name'];
                  return {
                    'value': id?.toString() ?? '',
                    'label': name?.toString() ?? 'Unknown',
                  };
                }).toList(),
                onChanged: (value) => setState(() => _selectedDoctorId = value),
                enabled: !_isSaving,
                hintText: 'Search doctors...',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // ADD CARE REQUEST DROPDOWN
        _buildDropdownField(
          label: 'Care Request (Optional)',
          value: _selectedCareRequestId,
          items: _careRequests.map((cr) {
            final id = cr['id'];
            final displayText = cr['display_text'];
            return {
              'value': id?.toString() ?? '',
              'label': displayText?.toString() ?? 'Request #$id',
            };
          }).toList(),
          onChanged: (value) => setState(() => _selectedCareRequestId = value),
          isLoading: _loadingCareRequests,
          disabled: _selectedPatientId == null || _isSaving,
          helperText: _selectedPatientId == null 
              ? 'Select a patient first' 
              : _careRequests.isEmpty && !_loadingCareRequests
                  ? 'No available care requests for this patient'
                  : null,
        ),
        
        const SizedBox(height: 16),
        _buildTextField(
          label: 'Care Plan Title *',
          controller: _titleController,
          hint: 'Enter care plan title',
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a care plan title';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(
          label: 'Description *',
          controller: _descriptionController,
          hint: 'Describe the care plan objectives and overview',
          maxLines: 4,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a description';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildCareDetails() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildDropdownField(
                label: 'Care Type *',
                value: _selectedCareType,
                items: _careTypes.map((type) => {
                  'value': type,
                  'label': type,
                }).toList(),
                onChanged: (value) => setState(() => _selectedCareType = value),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDropdownField(
                label: 'Priority *',
                value: _selectedPriority,
                items: _priorities.map((priority) => {
                  'value': priority,
                  'label': priority,
                }).toList(),
                onChanged: (value) => setState(() => _selectedPriority = value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildDateField(
                label: 'Start Date *',
                date: _startDate,
                onTap: () => _selectDate(context, true),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDateField(
                label: 'End Date',
                date: _endDate,
                onTap: () => _selectDate(context, false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildDropdownField(
          label: 'Frequency *',
          value: _selectedFrequency,
          items: _frequencies.map((freq) => {
            'value': freq,
            'label': freq,
          }).toList(),
          onChanged: (value) => setState(() => _selectedFrequency = value),
        ),
      ],
    );
  }

  Widget _buildCareTasks() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          ..._taskControllers.asMap().entries.map((entry) {
            int index = entry.key;
            TextEditingController controller = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF2196F3), Color(0xFF42A5F5)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: 'Enter care task description...',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_taskControllers.length > 1)
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _taskControllers.removeAt(index);
                        });
                      },
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Color(0xFFFF4757),
                        size: 22,
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
          GestureDetector(
            onTap: () {
              setState(() {
                _taskControllers.add(TextEditingController());
              });
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.primaryGreen,
                  width: 2,
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, color: AppColors.primaryGreen, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Add Another Task',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          enabled: !_isSaving,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            filled: true,
            fillColor: const Color(0xFFF8FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<Map<String, String>> items,
    required Function(String?) onChanged,
    bool isLoading = false,
    bool disabled = false,
    String? helperText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: (disabled || _isSaving) ? Colors.grey.shade200 : const Color(0xFFF8FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: isLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Loading...',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: value,
                    isExpanded: true,
                    hint: Text(
                      helperText ?? 'Select ${label.replaceAll(' *', '').replaceAll(' (Optional)', '')}',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                      ),
                    ),
                    icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600),
                    items: items.isEmpty
                        ? null
                        : items.map((item) {
                            return DropdownMenuItem<String>(
                              value: item['value'],
                              child: Text(
                                item['label'] ?? '',
                                style: const TextStyle(fontSize: 14),
                              ),
                            );
                          }).toList(),
                    onChanged: (disabled || _isSaving) ? null : onChanged,
                  ),
                ),
        ),
        if (helperText != null && !isLoading) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              helperText,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _isSaving ? null : onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isSaving ? Colors.grey.shade200 : const Color(0xFFF8FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  date != null 
                      ? '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}'
                      : 'Select Date',
                  style: TextStyle(
                    fontSize: 14,
                    color: date != null ? const Color(0xFF1A1A1A) : Colors.grey.shade400,
                    fontWeight: date != null ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
                Icon(Icons.calendar_today_outlined, size: 18, color: Colors.grey.shade600),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooterButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isSaving ? null : () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                disabledForegroundColor: Colors.grey.shade400,
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _isSaving ? Colors.grey.shade400 : Colors.grey.shade700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isSaving 
                      ? [Colors.grey.shade400, Colors.grey.shade400]
                      : [AppColors.primaryGreen, const Color(0xFF25B5A8)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: _isSaving ? [] : [
                  BoxShadow(
                    color: AppColors.primaryGreen.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveCarePlan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  disabledBackgroundColor: Colors.transparent,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Create Care Plan',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}