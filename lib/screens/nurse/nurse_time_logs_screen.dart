import 'dart:async';
import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../services/time_tracking_service.dart';

class NurseTimeLogsScreen extends StatefulWidget {
  final Map<String, dynamic> nurseData;
  
  const NurseTimeLogsScreen({
    Key? key,
    required this.nurseData,
  }) : super(key: key);

  @override
  State<NurseTimeLogsScreen> createState() => _NurseTimeLogsScreenState();
}

class _NurseTimeLogsScreenState extends State<NurseTimeLogsScreen> with SingleTickerProviderStateMixin {
  final _timeTrackingService = TimeTrackingService();
  final _scrollController = ScrollController();
  
  String _selectedFilter = 'all';
  late TabController _tabController;
  Set<String> _expandedCards = {};
  
  // Filter state variables
  String _selectedStatusFilter = 'all';
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedSort = 'Newest First';

  List<Map<String, dynamic>> timeLogs = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;
  
  // Pagination - NEW
  static const int _perPage = 10;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalTimeLogs = 0;
  bool _hasMorePages = false;
  
  // Scroll optimization - NEW
  Timer? _scrollDebounce;
  bool _canLoadMore = true;
  
  // Summary data
  String totalHoursToday = '0h 0m';
  int sessionsToday = 0;
  String totalHoursWeek = '0h 0m';
  int sessionsWeek = 0;
  int completedSessions = 0;
  
  // Additional summary data for different periods
  String totalHoursMonth = '0h 0m';
  int sessionsMonth = 0;
  String totalHoursAll = '0h 0m';
  int sessionsAll = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          switch (_tabController.index) {
            case 0:
              _selectedFilter = 'all';
              break;
            case 1:
              _selectedFilter = 'today';
              break;
            case 2:
              _selectedFilter = 'week';
              break;
            case 3:
              _selectedFilter = 'month';
              break;
          }
        });
        _resetAndFetchTimeLogs();
      }
    });
    
    _scrollController.addListener(_onScroll);
    _fetchTimeLogs();
  }

  @override
  void dispose() {
    _scrollDebounce?.cancel();
    _scrollController.dispose();
    _tabController.dispose();
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
          _loadMoreTimeLogs();
        }
      });
    }
  }
  
  // ==================== PAGINATION HELPERS ====================
  
  /// Reset pagination and fetch from page 1
  void _resetAndFetchTimeLogs() {
    setState(() {
      _currentPage = 1;
      timeLogs.clear();
    });
    _fetchTimeLogs();
  }

  Future<void> _fetchTimeLogs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Map sort options
      String? sortParam;
      switch (_selectedSort) {
        case 'Oldest First':
          sortParam = 'oldest';
          break;
        case 'Longest Duration':
          sortParam = 'longest';
          break;
        case 'Shortest Duration':
          sortParam = 'shortest';
          break;
        default:
          sortParam = 'newest';
      }

      final response = await _timeTrackingService.getTimeLogs(
        status: _selectedStatusFilter != 'all' ? _selectedStatusFilter : null,
        startDate: _startDate?.toIso8601String().split('T')[0],
        endDate: _endDate?.toIso8601String().split('T')[0],
        period: _selectedFilter,
        sort: sortParam,
        page: _currentPage,
      );

      if (response['success'] == true) {
        setState(() {
          timeLogs = List<Map<String, dynamic>>.from(response['data'] ?? []);
          
          // Handle pagination data
          final pagination = response['pagination'] as Map<String, dynamic>?;
          if (pagination != null) {
            _currentPage = pagination['current_page'] ?? 1;
            _totalPages = pagination['last_page'] ?? 1;
            _totalTimeLogs = pagination['total'] ?? timeLogs.length;
            _hasMorePages = _currentPage < _totalPages;
          } else {
            _totalTimeLogs = timeLogs.length;
            _hasMorePages = false;
          }
          
          // Update ALL summary fields
          final summary = response['summary'] as Map<String, dynamic>?;
          if (summary != null) {
            totalHoursToday = summary['total_hours_today'] ?? '0h 0m';
            sessionsToday = summary['sessions_today'] ?? 0;
            totalHoursWeek = summary['total_hours_week'] ?? '0h 0m';
            sessionsWeek = summary['sessions_week'] ?? 0;
            completedSessions = summary['completed_sessions'] ?? 0;
            
            // Additional summary data
            totalHoursMonth = summary['total_hours_month'] ?? '0h 0m';
            sessionsMonth = summary['sessions_month'] ?? 0;
            totalHoursAll = summary['total_hours_all'] ?? '0h 0m';
            sessionsAll = summary['sessions_all'] ?? 0;
          }
          
          _isLoading = false;
          _canLoadMore = true;
        });
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Failed to fetch time logs';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred. Please try again.';
        _isLoading = false;
      });
    }
  }
  
  /// Load more time logs (pagination)
  Future<void> _loadMoreTimeLogs() async {
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
      
      // Map sort options
      String? sortParam;
      switch (_selectedSort) {
        case 'Oldest First':
          sortParam = 'oldest';
          break;
        case 'Longest Duration':
          sortParam = 'longest';
          break;
        case 'Shortest Duration':
          sortParam = 'shortest';
          break;
        default:
          sortParam = 'newest';
      }
      
      final response = await _timeTrackingService.getTimeLogs(
        status: _selectedStatusFilter != 'all' ? _selectedStatusFilter : null,
        startDate: _startDate?.toIso8601String().split('T')[0],
        endDate: _endDate?.toIso8601String().split('T')[0],
        period: _selectedFilter,
        sort: sortParam,
        page: nextPage,
      );

      if (mounted && response['success'] == true) {
        final newLogs = List<Map<String, dynamic>>.from(response['data'] ?? []);
        
        setState(() {
          _currentPage = nextPage;
          timeLogs.addAll(newLogs);
          
          // Update pagination data
          final pagination = response['pagination'] as Map<String, dynamic>?;
          if (pagination != null) {
            _totalPages = pagination['last_page'] ?? _totalPages;
            _totalTimeLogs = pagination['total'] ?? _totalTimeLogs;
            _hasMorePages = _currentPage < _totalPages;
          }
          
          _isLoadingMore = false;
        });
        
        debugPrint('✅ Loaded ${newLogs.length} more time logs');
        debugPrint('📊 Now showing ${timeLogs.length} of $_totalTimeLogs');
        
        // Re-enable loading after a short delay
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _canLoadMore = true;
            });
          }
        });
      } else {
        if (mounted) {
          setState(() {
            _isLoadingMore = false;
            _canLoadMore = true;
          });
        }
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
            content: Text('Failed to load more time logs: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Get dynamic summary based on selected tab
  Map<String, dynamic> get _dynamicSummary {
    switch (_selectedFilter) {
      case 'today':
        return {
          'leftTitle': 'Today\'s Hours',
          'leftValue': totalHoursToday,
          'rightTitle': 'Sessions',
          'rightValue': '$sessionsToday',
        };
      case 'week':
        return {
          'leftTitle': 'This Week',
          'leftValue': totalHoursWeek,
          'rightTitle': 'Sessions',
          'rightValue': '$sessionsWeek',
        };
      case 'month':
        return {
          'leftTitle': 'This Month',
          'leftValue': totalHoursMonth,
          'rightTitle': 'Sessions',
          'rightValue': '$sessionsMonth',
        };
      case 'all':
      default:
        return {
          'leftTitle': 'Total Hours',
          'leftValue': totalHoursAll,
          'rightTitle': 'All Sessions',
          'rightValue': '$sessionsAll',
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Time Logs',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list, color: Color(0xFF1A1A1A)),
                onPressed: () => _showFilterOptions(),
              ),
              if (_selectedStatusFilter != 'all' || _startDate != null || _endDate != null || _selectedSort != 'Newest First')
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _resetAndFetchTimeLogs();
        },
        color: AppColors.primaryGreen,
        child: Column(
          children: [
            _buildSummaryCards(),
            _buildModernTabs(),
            Expanded(child: _buildTimeLogsList()),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final summary = _dynamicSummary;
    
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              title: summary['leftTitle'],
              value: summary['leftValue'],
              icon: Icons.access_time_rounded,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard(
              title: summary['rightTitle'],
              value: summary['rightValue'],
              icon: Icons.calendar_today_rounded,
              color: const Color(0xFF2196F3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTabs() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FD),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              _buildModernTab('All', 0),
              _buildModernTab('Today', 1),
              _buildModernTab('Week', 2),
              _buildModernTab('Month', 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernTab(String label, int index) {
    final isSelected = _tabController.index == index;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _tabController.animateTo(index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected ? [
              BoxShadow(
                color: AppColors.primaryGreen.withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ] : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF8F92A1),
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeLogsList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _resetAndFetchTimeLogs,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (timeLogs.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      itemCount: timeLogs.length + (_hasMorePages ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == timeLogs.length) {
          return _buildLoadMoreIndicator();
        }
        return _buildTimeLogCard(timeLogs[index], index);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated illustration
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
                width: 140,
                height: 140,
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
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primaryGreen.withOpacity(0.2),
                          width: 2,
                        ),
                      ),
                    ),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.access_time_rounded,
                        size: 40,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Title with gradient
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [
                  AppColors.primaryGreen,
                  AppColors.primaryGreen.withOpacity(0.7),
                ],
              ).createShader(bounds),
              child: const Text(
                'No Time Logs Yet',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            const SizedBox(height: 8),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Your clock-in and clock-out sessions will appear here once you start working',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
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
                  'Loading more time logs...',
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
                onPressed: _canLoadMore ? _loadMoreTimeLogs : null,
                icon: const Icon(Icons.expand_more_rounded, size: 20),
                label: Text(
                  'Load More (${_totalTimeLogs - timeLogs.length} remaining)',
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

Widget _buildTimeLogCard(Map<String, dynamic> log, int index) {
  // Add null safety for all fields
  final logId = log['id']?.toString() ?? 'N/A';
  final status = log['status']?.toString() ?? 'Unknown';
  final date = log['date']?.toString() ?? 'N/A';
  final clockIn = log['clockIn']?.toString() ?? '--:--';
  final clockOut = log['clockOut']?.toString() ?? '--:--';
  final duration = log['duration']?.toString() ?? '0h 0m';
  final patient = log['patient']?.toString() ?? 'N/A';
  final location = log['location']?.toString() ?? 'N/A';
  final notes = log['notes']?.toString() ?? '';
  final tasks = log['tasks'] as List<dynamic>? ?? [];
  
  final isExpanded = _expandedCards.contains(logId);
  final isCompleted = status == 'Completed';
  
  return TweenAnimationBuilder(
    duration: Duration(milliseconds: 300 + (index * 100)),
    tween: Tween<double>(begin: 0, end: 1),
    curve: Curves.easeOutCubic,
    builder: (context, double value, child) {
      return Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: child,
        ),
      );
    },
    child: GestureDetector(
      onTap: () {
        setState(() {
          if (isExpanded) {
            _expandedCards.remove(logId);
          } else {
            _expandedCards.add(logId);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isCompleted 
              ? AppColors.primaryGreen.withOpacity(0.3)
              : Colors.grey.shade200,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isCompleted
                            ? AppColors.primaryGreen.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          isCompleted ? Icons.check_circle_rounded : Icons.schedule_rounded,
                          color: isCompleted ? AppColors.primaryGreen : Colors.orange,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    logId,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1A1A1A),
                                      letterSpacing: 0.2,
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
                                    color: isCompleted
                                      ? AppColors.primaryGreen.withOpacity(0.1)
                                      : Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isCompleted ? AppColors.primaryGreen : Colors.orange,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 14,
                                  color: Colors.grey.shade500,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  date,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        duration: const Duration(milliseconds: 300),
                        turns: isExpanded ? 0.5 : 0,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.grey.shade600,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildTimeInfo(
                          'Clock In',
                          clockIn,
                          Icons.login_rounded,
                          AppColors.primaryGreen,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTimeInfo(
                          'Clock Out',
                          clockOut,
                          Icons.logout_rounded,
                          const Color(0xFFFF9A00),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTimeInfo(
                          'Duration',
                          duration,
                          Icons.timer_rounded,
                          const Color(0xFF2196F3),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 300),
              crossFadeState: isExpanded 
                ? CrossFadeState.showSecond 
                : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                children: [
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: Colors.grey.shade200,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow(
                          Icons.person_rounded,
                          'Patient',
                          patient,
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          Icons.location_on_rounded,
                          'Location',
                          location,
                        ),
                        if (notes.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            Icons.note_rounded,
                            'Notes',
                            notes,
                          ),
                        ],
                        if (tasks.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Tasks Completed',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...List.generate(
                            tasks.length,
                            (index) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    size: 16,
                                    color: AppColors.primaryGreen,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      tasks[index]?.toString() ?? '',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF1A1A1A),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
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

  Widget _buildTimeInfo(String label, String time, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(
            time,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showFilterOptions() {
    // Create local state for the modal
    String tempStatusFilter = _selectedStatusFilter;
    DateTime? tempStartDate = _startDate;
    DateTime? tempEndDate = _endDate;
    String tempSort = _selectedSort;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
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
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Title
                  const Text(
                    'Filter Time Logs',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Status Filter
                  Text(
                    'Status',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildFilterChip(
                          label: 'All',
                          isSelected: tempStatusFilter == 'all',
                          color: Colors.grey.shade600,
                          onTap: () {
                            setModalState(() {
                              tempStatusFilter = 'all';
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildFilterChip(
                          label: 'Completed',
                          isSelected: tempStatusFilter == 'completed',
                          color: AppColors.primaryGreen,
                          onTap: () {
                            setModalState(() {
                              tempStatusFilter = 'completed';
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildFilterChip(
                          label: 'In Progress',
                          isSelected: tempStatusFilter == 'in_progress',
                          color: Colors.orange,
                          onTap: () {
                            setModalState(() {
                              tempStatusFilter = 'in_progress';
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Date Range
                  Text(
                    'Date Range',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: tempStartDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
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
                            if (date != null) {
                              setModalState(() {
                                tempStartDate = date;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: tempStartDate != null 
                                  ? AppColors.primaryGreen 
                                  : Colors.grey.shade300,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              color: tempStartDate != null 
                                ? AppColors.primaryGreen.withOpacity(0.05)
                                : Colors.transparent,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  tempStartDate != null
                                    ? '${tempStartDate!.day}/${tempStartDate!.month}/${tempStartDate!.year}'
                                    : 'Start Date',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: tempStartDate != null
                                      ? AppColors.primaryGreen
                                      : Colors.grey.shade600,
                                    fontWeight: tempStartDate != null
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  ),
                                ),
                                Icon(
                                  Icons.calendar_today,
                                  size: 18,
                                  color: tempStartDate != null
                                    ? AppColors.primaryGreen
                                    : Colors.grey.shade600,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: tempEndDate ?? DateTime.now(),
                              firstDate: tempStartDate ?? DateTime(2020),
                              lastDate: DateTime.now(),
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
                            if (date != null) {
                              setModalState(() {
                                tempEndDate = date;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: tempEndDate != null 
                                  ? AppColors.primaryGreen 
                                  : Colors.grey.shade300,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              color: tempEndDate != null 
                                ? AppColors.primaryGreen.withOpacity(0.05)
                                : Colors.transparent,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  tempEndDate != null
                                    ? '${tempEndDate!.day}/${tempEndDate!.month}/${tempEndDate!.year}'
                                    : 'End Date',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: tempEndDate != null
                                      ? AppColors.primaryGreen
                                      : Colors.grey.shade600,
                                    fontWeight: tempEndDate != null
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  ),
                                ),
                                Icon(
                                  Icons.calendar_today,
                                  size: 18,
                                  color: tempEndDate != null
                                    ? AppColors.primaryGreen
                                    : Colors.grey.shade600,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Sort By
                  Text(
                    'Sort By',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        builder: (context) => Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(24),
                              topRight: Radius.circular(24),
                            ),
                          ),
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Center(
                                child: Container(
                                  width: 40,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'Sort By',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                              const SizedBox(height: 24),
                              ...[
                                'Newest First',
                                'Oldest First',
                                'Longest Duration',
                                'Shortest Duration',
                              ].map((option) => ListTile(
                                onTap: () {
                                  setModalState(() {
                                    tempSort = option;
                                  });
                                  Navigator.pop(context);
                                },
                                title: Text(
                                  option,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: tempSort == option 
                                      ? FontWeight.w600 
                                      : FontWeight.normal,
                                    color: tempSort == option 
                                      ? AppColors.primaryGreen 
                                      : Colors.grey.shade800,
                                  ),
                                ),
                                trailing: tempSort == option
                                  ? const Icon(
                                      Icons.check_circle,
                                      color: AppColors.primaryGreen,
                                    )
                                  : null,
                              )),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            tempSort,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Icon(
                            Icons.arrow_drop_down,
                            color: Colors.grey.shade600,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setModalState(() {
                              tempStatusFilter = 'all';
                              tempStartDate = null;
                              tempEndDate = null;
                              tempSort = 'Newest First';
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Reset',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedStatusFilter = tempStatusFilter;
                              _startDate = tempStartDate;
                              _endDate = tempEndDate;
                              _selectedSort = tempSort;
                            });
                            Navigator.pop(context);
                            
                            // Reset pagination and fetch with new filters
                            _resetAndFetchTimeLogs();
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Filters applied successfully'),
                                backgroundColor: AppColors.primaryGreen,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                margin: const EdgeInsets.all(16),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? color : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}