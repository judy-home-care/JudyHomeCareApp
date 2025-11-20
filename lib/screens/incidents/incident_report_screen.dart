import 'package:flutter/material.dart';
import 'dart:async';
import '../../models/incidents/incident_report_models.dart';
import '../../services/incidents/incident_service.dart';
import '../../utils/app_colors.dart';
import 'add_incident_report_screen.dart';

class NurseIncidentReportScreen extends StatefulWidget {
  final Map<String, dynamic> nurseData;

  const NurseIncidentReportScreen({
    Key? key,
    required this.nurseData,
  }) : super(key: key);

  @override
  State<NurseIncidentReportScreen> createState() => _NurseIncidentReportScreenState();
}

class _NurseIncidentReportScreenState extends State<NurseIncidentReportScreen>
    with SingleTickerProviderStateMixin {
  final _incidentService = IncidentService();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  late TabController _tabController;
  Timer? _debounce;
  Timer? _scrollDebounce;
  
  bool _isLoading = true;
  bool _isLoadingMore = false;
  List<IncidentReport> _incidents = [];
  String? _errorMessage;
  String _selectedFilter = 'all';
  String _searchQuery = '';
  
  // Pagination - OPTIMIZED
  static const int _perPage = 15; // Increased from 5 for better UX
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalIncidents = 0;
  bool _hasMorePages = false;
  
  // Scroll optimization
  double _lastScrollPosition = 0;
  bool _canLoadMore = true;

  // Status counts
  Map<String, int> _statusCounts = {
    'pending': 0,
    'under_review': 0,
    'resolved': 0,
    'total': 0,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadIncidents();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    _debounce?.cancel();
    _scrollDebounce?.cancel();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      setState(() {
        switch (_tabController.index) {
          case 0:
            _selectedFilter = 'all';
            break;
          case 1:
            _selectedFilter = 'pending';
            break;
          case 2:
            _selectedFilter = 'under_review';
            break;
          case 3:
            _selectedFilter = 'resolved';
            break;
        }
        _currentPage = 1;
        _incidents.clear();
      });
      _loadIncidents();
    }
  }

  // OPTIMIZED: Debounced scroll listener to reduce CPU usage
  void _onScroll() {
    // Cancel previous debounce timer
    _scrollDebounce?.cancel();
    
    final currentPosition = _scrollController.position.pixels;
    final maxScroll = _scrollController.position.maxScrollExtent;
    
    // FIXED: Lower threshold (100px instead of 300px) and trigger on any scroll near bottom
    if (currentPosition >= maxScroll - 100) {
      
      // Debounce the load more call
      _scrollDebounce = Timer(const Duration(milliseconds: 200), () {
        if (_canLoadMore && !_isLoadingMore && _hasMorePages && mounted) {
          _loadMoreIncidents();
        }
      });
    }
    
    _lastScrollPosition = currentPosition;
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query != _searchQuery && mounted) {
        setState(() {
          _searchQuery = query;
          _currentPage = 1;
          _incidents.clear();
        });
        _loadIncidents();
      }
    });
  }

  Future<void> _loadIncidents({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _incidents.clear();
        _isLoading = true;
        _errorMessage = null;
        _canLoadMore = true;
      });
    } else if (!_isLoading && !refresh) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final response = await _incidentService.getIncidents(
        page: _currentPage,
        perPage: _perPage, // Send per_page to backend
        status: _selectedFilter == 'all' ? null : _selectedFilter,
        search: _searchQuery.isEmpty ? null : _searchQuery,
      );

      if (mounted) {
        setState(() {
          _incidents = response.data;
          _totalPages = response.lastPage;
          _totalIncidents = response.total;
          _hasMorePages = _currentPage < _totalPages;
          _statusCounts = response.counts ?? _statusCounts;
          _isLoading = false;
          _canLoadMore = true;
        });
        
        // Debug info
        debugPrint('📊 Loaded page $_currentPage of $_totalPages');
        debugPrint('📊 Showing ${_incidents.length} of $_totalIncidents incidents');
        debugPrint('📊 Has more pages: $_hasMorePages');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load incident reports. Please try again.';
          _isLoading = false;
          _canLoadMore = true;
        });
        debugPrint('Error loading incidents: $e');
      }
    }
  }

  // OPTIMIZED: Load more with proper state management
  Future<void> _loadMoreIncidents() async {
    if (_isLoadingMore || !_hasMorePages || !_canLoadMore) {
      debugPrint('⚠️ Load more blocked: isLoading=$_isLoadingMore, hasMore=$_hasMorePages, canLoad=$_canLoadMore');
      return;
    }

    debugPrint('🔄 Loading page ${_currentPage + 1}...');

    setState(() {
      _isLoadingMore = true;
      _canLoadMore = false; // Prevent multiple simultaneous loads
    });

    try {
      final nextPage = _currentPage + 1;
      final response = await _incidentService.getIncidents(
        page: nextPage,
        perPage: _perPage, // Send per_page to backend
        status: _selectedFilter == 'all' ? null : _selectedFilter,
        search: _searchQuery.isEmpty ? null : _searchQuery,
      );

      if (mounted) {
        setState(() {
          _currentPage = nextPage;
          _incidents.addAll(response.data);
          _totalPages = response.lastPage;
          _hasMorePages = _currentPage < _totalPages;
          _isLoadingMore = false;
        });
        
        debugPrint('✅ Loaded ${response.data.length} more incidents');
        debugPrint('📊 Now showing ${_incidents.length} of $_totalIncidents');
        
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
            content: Text('Failed to load more incidents: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  int get _pendingCount => _statusCounts['pending'] ?? 0;
  int get _underReviewCount => _statusCounts['under_review'] ?? 0;
  int get _resolvedCount => _statusCounts['resolved'] ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Incident Reports',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.refresh,
              color: Color(0xFF199A8E),
            ),
            onPressed: () => _loadIncidents(refresh: true),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildTabs(),
          Expanded(
            child: _isLoading && _incidents.isEmpty
                ? _buildLoadingState()
                : _errorMessage != null && _incidents.isEmpty
                    ? _buildErrorState()
                    : _incidents.isEmpty
                        ? _buildEmptyState()
                        : _buildIncidentList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddIncidentReportScreen(
                nurseData: widget.nurseData,
              ),
            ),
          );

          if (result == true) {
            _loadIncidents(refresh: true);
          }
        },
        backgroundColor: const Color(0xFF199A8E),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'New Report',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _searchQuery.isNotEmpty 
                ? const Color(0xFF199A8E).withOpacity(0.3)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search incidents, patients, locations...',
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: _searchQuery.isNotEmpty 
                  ? const Color(0xFF199A8E) 
                  : Colors.grey.shade400,
              size: 22,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: Colors.grey.shade400,
                      size: 20,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabs() {
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
              _buildTab('All', _statusCounts['total'] ?? 0, 0),
              _buildTab('Pending', _pendingCount, 1),
              _buildTab('Review', _underReviewCount, 2),
              _buildTab('Resolved', _resolvedCount, 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab(String label, int count, int index) {
    final isSelected = _tabController.index == index;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _tabController.animateTo(index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF199A8E) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected ? [
              BoxShadow(
                color: const Color(0xFF199A8E).withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ] : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : const Color(0xFF1A1A1A),
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF8F92A1),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF199A8E)),
      ),
    );
  }

  Widget _buildErrorState() {
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
              _errorMessage ?? 'An error occurred',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _loadIncidents(refresh: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF199A8E),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
              child: const Text('Retry'),
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
                      child: Icon(
                        _searchQuery.isNotEmpty
                          ? Icons.search_off_rounded
                          : _selectedFilter == 'all' 
                            ? Icons.report_outlined
                            : _selectedFilter == 'pending'
                              ? Icons.schedule_rounded
                              : _selectedFilter == 'under_review'
                                ? Icons.find_in_page_rounded
                                : Icons.check_circle_outline_rounded,
                        size: 50,
                        color: const Color(0xFF199A8E),
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
                  const Color(0xFF199A8E),
                  const Color(0xFF199A8E).withOpacity(0.7),
                ],
              ).createShader(bounds),
              child: Text(
                _searchQuery.isNotEmpty
                  ? 'No Results Found'
                  : _selectedFilter == 'all'
                    ? 'No Incident Reports Yet'
                    : 'No ${_selectedFilter.toUpperCase().replaceAll('_', ' ')} Reports',
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
                  ? 'Try adjusting your search terms or filters'
                  : _selectedFilter == 'all'
                    ? 'Start by creating your first incident report to track and manage safety events'
                    : 'Try switching to another tab or create a new report',
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

  // OPTIMIZED: ListView with better performance
  Widget _buildIncidentList() {
    return RefreshIndicator(
      onRefresh: () => _loadIncidents(refresh: true),
      color: const Color(0xFF199A8E),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _incidents.length + (_hasMorePages ? 1 : 0),
        // OPTIMIZATION: Use addAutomaticKeepAlives to cache items
        addAutomaticKeepAlives: true,
        cacheExtent: 500, // Cache items 500px off-screen
        itemBuilder: (context, index) {
          if (index == _incidents.length) {
            return _buildLoadMoreIndicator();
          }
          final incident = _incidents[index];
          // Use unique key for better performance
          return _buildIncidentCard(incident, key: ValueKey(incident.id));
        },
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
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF199A8E)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading more incidents...',
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
                onPressed: _canLoadMore ? _loadMoreIncidents : null,
                icon: const Icon(Icons.expand_more_rounded, size: 20),
                label: Text(
                  'Load More (${_totalIncidents - _incidents.length} remaining)',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF199A8E),
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

  Widget _buildIncidentCard(IncidentReport incident, {Key? key}) {
    final severityColor = Color(int.parse('FF${incident.severityColor}', radix: 16));
    final statusColor = Color(int.parse('FF${incident.statusColor}', radix: 16));

    return GestureDetector(
      key: key,
      onTap: () => _showIncidentDetails(incident),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: incident.requiresAttention
              ? Border.all(color: Colors.red.shade300, width: 2)
              : null,
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: severityColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 14,
                          color: severityColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          incident.formattedSeverity,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: severityColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      incident.formattedStatus,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              Text(
                incident.formattedIncidentType,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              
              const SizedBox(height: 6),
              
              Text(
                incident.incidentDescription,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 12),
              
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      incident.patientName,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 12,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    incident.incidentDate,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              
              if (incident.requiresAttention) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.priority_high,
                        color: Colors.red.shade700,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Requires immediate attention',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 10),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Reported ${incident.daysOld} days ago',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward,
                    size: 14,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showIncidentDetails(IncidentReport incident) {
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
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Incident Details',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Color(int.parse('FF${incident.severityColor}', radix: 16))
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          incident.formattedSeverity,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(int.parse('FF${incident.severityColor}', radix: 16)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailSection(
                      'Incident Information',
                      [
                        _buildDetailRow('Type', incident.formattedIncidentType),
                        _buildDetailRow('Date', incident.incidentDate),
                        _buildDetailRow('Time', incident.incidentTime),
                        if (incident.incidentLocation != null)
                          _buildDetailRow('Location', incident.incidentLocation!),
                        _buildDetailRow('Status', incident.formattedStatus),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildDetailSection(
                      'Patient Information',
                      [
                        _buildDetailRow('Name', incident.patientName),
                        if (incident.patientAge != null)
                          _buildDetailRow('Age', '${incident.patientAge} years'),
                        if (incident.patientSex != null)
                          _buildDetailRow('Gender', incident.patientSex!),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildDescriptionSection(
                      'Description',
                      incident.incidentDescription,
                    ),
                    if (incident.staffFamilyInvolved != null) ...[
                      const SizedBox(height: 20),
                      _buildDetailSection(
                        'Staff/Family Involved',
                        [
                          _buildDetailRow('Name', incident.staffFamilyInvolved!),
                          if (incident.staffFamilyRole != null)
                            _buildDetailRow('Role', incident.staffFamilyRole!),
                        ],
                      ),
                    ],
                    if (incident.firstAidProvided) ...[
                      const SizedBox(height: 20),
                      _buildDetailSection(
                        'Immediate Actions',
                        [
                          _buildDetailRow('First Aid', 'Yes'),
                          if (incident.firstAidDescription != null)
                            _buildDetailRow('Details', incident.firstAidDescription!),
                          if (incident.careProviderName != null)
                            _buildDetailRow('Care Provider', incident.careProviderName!),
                        ],
                      ),
                    ],
                    if (incident.transferredToHospital) ...[
                      const SizedBox(height: 20),
                      _buildDetailSection(
                        'Hospital Transfer',
                        [
                          _buildDetailRow('Transferred', 'Yes'),
                          if (incident.hospitalTransferDetails != null)
                            _buildDetailRow('Details', incident.hospitalTransferDetails!),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    _buildDetailSection(
                      'Reporting',
                      [
                        _buildDetailRow('Reported By', incident.reporterName),
                        _buildDetailRow('Reported At', incident.reportedAt),
                        if (incident.reviewerName != null)
                          _buildDetailRow('Reviewed By', incident.reviewerName!),
                      ],
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

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF1A1A1A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF1A1A1A),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}