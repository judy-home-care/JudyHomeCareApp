import 'package:flutter/material.dart';
import 'dart:async';
import '../../utils/app_colors.dart';
import '../../services/transport/transport_service.dart';
import '../../models/transport/transport_models.dart';
import 'package:geolocator/geolocator.dart';
import 'transport_patient_selection_screen.dart';
import 'package:intl/intl.dart';

class TransportRequestScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  
  const TransportRequestScreen({
    Key? key,
    required this.userData,
  }) : super(key: key);

  @override
  State<TransportRequestScreen> createState() => _TransportRequestScreenState();
}

class _TransportRequestScreenState extends State<TransportRequestScreen> 
    with SingleTickerProviderStateMixin {
  
  final _transportService = TransportService();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  late TabController _tabController;
  Timer? _debounce;
  Timer? _scrollDebounce;
  
  List<TransportRequest> _requests = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  Position? _currentPosition;
  String _selectedFilter = 'all';
  String _searchQuery = '';
  
  // Pagination
  static const int _perPage = 15;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalRequests = 0;
  bool _hasMorePages = false;
  bool _canLoadMore = true;
  
  // Status counts
  Map<String, int> _statusCounts = {
    'requested': 0,
    'in_progress': 0,
    'completed': 0,
    'total': 0,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);
    _loadTransportRequests();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _scrollController.dispose();
    _scrollDebounce?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      final previousFilter = _selectedFilter;
      setState(() {
        switch (_tabController.index) {
          case 0:
            _selectedFilter = 'all';
            break;
          case 1:
            _selectedFilter = 'requested';
            break;
          case 2:
            _selectedFilter = 'in_progress';
            break;
          case 3:
            _selectedFilter = 'completed';
            break;
        }
        _currentPage = 1;
        _totalPages = 1;
        _requests.clear();
        _hasMorePages = false;
      });
      
      debugPrint('🔄 Tab changed: $previousFilter → $_selectedFilter');
      _loadTransportRequests();
    }
  }

  void _onScroll() {
    _scrollDebounce?.cancel();
    
    final currentPosition = _scrollController.position.pixels;
    final maxScroll = _scrollController.position.maxScrollExtent;
    
    if (currentPosition >= maxScroll - 100) {
      _scrollDebounce = Timer(const Duration(milliseconds: 200), () {
        if (_canLoadMore && !_isLoadingMore && _hasMorePages && mounted) {
          _loadMoreRequests();
        }
      });
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query != _searchQuery && mounted) {
        setState(() {
          _searchQuery = query;
          _currentPage = 1;
          _requests.clear();
        });
        _loadTransportRequests();
      }
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  Future<void> _loadTransportRequests({bool refresh = false}) async {
    if (refresh) {
      debugPrint('🔄 Refreshing transport requests...');
      setState(() {
        _currentPage = 1;
        _requests.clear();
        _isLoading = true;
        _errorMessage = null;
        _canLoadMore = true;
        _hasMorePages = false;
      });
    } else if (!_isLoading && !refresh) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    debugPrint('📡 Loading requests: page=$_currentPage, filter=$_selectedFilter, search=$_searchQuery');

    try {
      final response = await _transportService.getTransportRequests(
        page: _currentPage,
        perPage: _perPage,
        status: _selectedFilter == 'all' ? null : _selectedFilter,
        search: _searchQuery.isEmpty ? null : _searchQuery,
      );

      if (mounted) {
        setState(() {
          _requests = response.data;
          _totalPages = response.lastPage;
          _totalRequests = response.total;
          _hasMorePages = _currentPage < _totalPages;
          _statusCounts = response.counts ?? _statusCounts;
          _isLoading = false;
          _canLoadMore = true;
        });
        
        debugPrint('📊 Loaded page $_currentPage of $_totalPages');
        debugPrint('📊 Showing ${_requests.length} of $_totalRequests requests');
        debugPrint('📊 Has more pages: $_hasMorePages');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load transport requests';
          _isLoading = false;
          _canLoadMore = true;
        });
        debugPrint('❌ Error loading requests: $e');
      }
    }
  }

  Future<void> _loadMoreRequests() async {
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
      final response = await _transportService.getTransportRequests(
        page: nextPage,
        perPage: _perPage,
        status: _selectedFilter == 'all' ? null : _selectedFilter,
        search: _searchQuery.isEmpty ? null : _searchQuery,
      );

      if (mounted) {
        setState(() {
          _currentPage = nextPage;
          _requests.addAll(response.data);
          _totalPages = response.lastPage;
          _hasMorePages = _currentPage < _totalPages;
          _isLoadingMore = false;
        });
        
        debugPrint('✅ Loaded ${response.data.length} more requests');
        debugPrint('📊 Now showing ${_requests.length} of $_totalRequests');
        
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
            content: Text('Failed to load more requests: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  int get _pendingCount => _statusCounts['requested'] ?? 0;
  int get _inProgressCount => _statusCounts['in_progress'] ?? 0;
  int get _completedCount => _statusCounts['completed'] ?? 0;

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
          'Transport Requests',
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
            onPressed: () => _loadTransportRequests(refresh: true),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildTabs(),
          Expanded(
            child: _isLoading && _requests.isEmpty
              ? _buildLoadingState()
              : _errorMessage != null && _requests.isEmpty
                ? _buildErrorState()
                : _requests.isEmpty
                  ? _buildEmptyState()
                  : _buildRequestsList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Navigate to patient selection screen first (for nurses)
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TransportPatientSelectionScreen(),
            ),
          );
          
          // Refresh list if transport request was created successfully
          if (result == true) {
            _loadTransportRequests(refresh: true);
          }
        },
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add, size: 22, color: Colors.white),
        label: const Text(
          'New Request',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: Colors.white,
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
                ? AppColors.primaryGreen.withOpacity(0.3)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search requests, patients, locations...',
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: _searchQuery.isNotEmpty 
                  ? AppColors.primaryGreen
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
              _buildTab('Active', _inProgressCount, 2),
              _buildTab('Done', _completedCount, 3),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading transport requests...',
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
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _loadTransportRequests(refresh: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
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

  Widget _buildRequestsList() {
    return RefreshIndicator(
      onRefresh: () => _loadTransportRequests(refresh: true),
      color: AppColors.primaryGreen,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _requests.length + (_hasMorePages ? 1 : 0),
        addAutomaticKeepAlives: true,
        cacheExtent: 500,
        itemBuilder: (context, index) {
          if (index == _requests.length) {
            return _buildLoadMoreIndicator();
          }
          final request = _requests[index];
          return _buildRequestCard(request, key: ValueKey(request.id));
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
                  'Loading more requests...',
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
                onPressed: _canLoadMore ? _loadMoreRequests : null,
                icon: const Icon(Icons.expand_more_rounded, size: 20),
                label: Text(
                  'Load More (${_totalRequests - _requests.length} remaining)',
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
                      _searchQuery.isNotEmpty
                        ? Icons.search_off_rounded
                        : _selectedFilter == 'all'
                          ? Icons.local_shipping_outlined
                          : _selectedFilter == 'requested'
                            ? Icons.schedule_rounded
                            : _selectedFilter == 'in_progress'
                              ? Icons.local_shipping
                              : Icons.check_circle_outline_rounded,
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
            child: Text(
              _searchQuery.isNotEmpty
                ? 'No Results Found'
                : _selectedFilter == 'all'
                  ? 'No Transport Requests Yet'
                  : 'No ${_selectedFilter.toUpperCase().replaceAll('_', ' ')} Requests',
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
                  ? 'Start by creating your first transport request to track and manage patient transport'
                  : 'Try switching to another tab or create a new request',
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

  Widget _buildRequestCard(TransportRequest request, {Key? key}) {
    final isEmergency = request.priority == 'emergency';
    
    Color statusColor;
    Color statusBgColor;
    
    switch (request.status) {
      case 'completed':
        statusColor = const Color(0xFF00C896);
        statusBgColor = const Color(0xFFD4F8F0);
        break;
      case 'in_progress':
        statusColor = const Color(0xFF2196F3);
        statusBgColor = const Color(0xFFE3F2FD);
        break;
      case 'requested':
        statusColor = const Color(0xFFFFB648);
        statusBgColor = const Color(0xFFFFF3E0);
        break;
      default:
        statusColor = Colors.grey;
        statusBgColor = Colors.grey.shade100;
    }

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isEmergency 
          ? Border.all(color: const Color(0xFFFF4757), width: 2)
          : null,
        boxShadow: [
          BoxShadow(
            color: isEmergency
              ? const Color(0xFFFF4757).withOpacity(0.15)
              : Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showRequestDetails(request),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: statusBgColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        isEmergency ? Icons.emergency : Icons.local_shipping,
                        color: isEmergency ? const Color(0xFFFF4757) : statusColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request.patientName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            request.typeLabel,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusBgColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        request.statusLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildLocationRow(
                  Icons.location_on_rounded,
                  'Pickup',
                  request.pickupLocation,
                  const Color(0xFF00C896),
                ),
                const SizedBox(height: 8),
                _buildLocationRow(
                  Icons.location_on_rounded,
                  'Drop-off',
                  request.destinationLocation,
                  const Color(0xFFFF4757),
                ),
                if (request.driver != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person,
                            color: AppColors.primaryGreen,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                request.driver!.name ?? 'Driver',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${request.driver!.vehicleModel ?? 'Vehicle'} - ${request.driver!.vehicleNumber ?? 'N/A'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (request.driver!.averageRating != null)
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                color: Color(0xFFFFB648),
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                request.driver!.averageRating!.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
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
        ),
      ),
    );
  }

  Widget _buildLocationRow(IconData icon, String label, String location, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
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
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                location,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== TRANSPORT REQUEST DETAILS MODAL ====================
  
  void _showRequestDetails(TransportRequest request) {
    Color statusColor = _getStatusColor(request.status);
    Color priorityColor = _getPriorityColor(request.priority);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
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
                    statusColor.withOpacity(0.1),
                    statusColor.withOpacity(0.05),
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
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          request.priority == 'emergency' 
                            ? Icons.emergency 
                            : Icons.local_shipping,
                          color: statusColor,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              request.patientName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Transport Request #${request.id}',
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
            
            // Content - Scrollable
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status and Priority Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildDetailCard(
                            icon: Icons.info_outline,
                            title: 'Status',
                            value: request.statusLabel,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDetailCard(
                            icon: Icons.priority_high,
                            title: 'Priority',
                            value: request.priorityLabel,
                            color: priorityColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Transport Type and Schedule
                    Row(
                      children: [
                        Expanded(
                          child: _buildDetailCard(
                            icon: Icons.category_outlined,
                            title: 'Type',
                            value: request.typeLabel,
                            color: const Color(0xFF6C63FF),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDetailCard(
                            icon: Icons.schedule,
                            title: 'Scheduled',
                            value: request.scheduledTime != null
                              ? DateFormat('MMM dd, hh:mm a').format(request.scheduledTime!)
                              : 'Not set',
                            color: const Color(0xFF2196F3),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Pickup Location Section
                    _buildSectionTitle('Pickup Location'),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF00C896).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00C896).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.location_on,
                              color: Color(0xFF00C896),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  request.pickupLocation,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                                if (request.pickupAddress != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    request.pickupAddress!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade700,
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
                    const SizedBox(height: 16),
                    
                    // Destination Location Section
                    _buildSectionTitle('Destination'),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFFF4757).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF4757).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.location_on,
                              color: Color(0xFFFF4757),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  request.destinationLocation,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                                if (request.destinationAddress != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    request.destinationAddress!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade700,
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
                    const SizedBox(height: 24),
                    
                    // Trip Details
                    _buildSectionTitle('Trip Details'),
                    const SizedBox(height: 12),
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
                                  Icons.social_distance,
                                  color: Colors.grey.shade600,
                                  size: 24,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  request.distanceKm != null 
                                    ? '${request.distanceKm!.toStringAsFixed(1)} km'
                                    : 'N/A',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Distance',
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
                                  Icons.access_time,
                                  color: Colors.grey.shade600,
                                  size: 24,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  request.estimatedDurationMinutes != null
                                    ? '${request.estimatedDurationMinutes} min'
                                    : 'N/A',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Duration',
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
                                  Icons.attach_money,
                                  color: Colors.grey.shade600,
                                  size: 24,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  request.estimatedCost != null
                                    ? '\$${request.estimatedCost!.toStringAsFixed(2)}'
                                    : 'N/A',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Est. Cost',
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
                    
                    // Driver Information
                    if (request.driver != null) ...[
                      const SizedBox(height: 24),
                      _buildSectionTitle('Driver Information'),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primaryGreen.withOpacity(0.1),
                              AppColors.primaryGreen.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.primaryGreen.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryGreen.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.person,
                                    color: AppColors.primaryGreen,
                                    size: 30,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        request.driver!.name ?? 'Driver',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1A1A1A),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (request.driver!.phone != null)
                                        Text(
                                          request.driver!.phone!,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (request.driver!.averageRating != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFB648).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.star,
                                          color: Color(0xFFFFB648),
                                          size: 18,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          request.driver!.averageRating!.toStringAsFixed(1),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            if (request.driver!.vehicleModel != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryGreen.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.directions_car,
                                        color: AppColors.primaryGreen,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            request.driver!.vehicleModel!,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (request.driver!.vehicleNumber != null)
                                            Text(
                                              request.driver!.vehicleNumber!,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (request.driver!.vehicleColor != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          request.driver!.vehicleColor!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    
                    // Reason
                    if (request.reason != null && request.reason!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildSectionTitle('Reason for Transport'),
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
                          request.reason!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                    
                    // Special Requirements
                    if (request.specialRequirements != null && 
                        request.specialRequirements!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildSectionTitle('Special Requirements'),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFFFB648).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: Color(0xFFFFB648),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                request.specialRequirements!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade800,
                                  height: 1.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    // Contact Person
                    if (request.contactPerson != null && 
                        request.contactPerson!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildSectionTitle('Contact Person'),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFB),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.contact_phone,
                              color: Colors.grey.shade600,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              request.contactPerson!,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    // Rating and Feedback (for completed requests)
                    if (request.status == 'completed') ...[
                      const SizedBox(height: 24),
                      _buildSectionTitle('Your Feedback'),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFB),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (request.rating != null) ...[
                              Row(
                                children: [
                                  Text(
                                    'Rating: ',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  ...List.generate(5, (index) {
                                    return Icon(
                                      index < request.rating!
                                        ? Icons.star
                                        : Icons.star_border,
                                      color: const Color(0xFFFFB648),
                                      size: 20,
                                    );
                                  }),
                                ],
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (request.feedback != null && 
                                request.feedback!.isNotEmpty) ...[
                              Text(
                                request.feedback!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                  height: 1.6,
                                ),
                              ),
                            ] else ...[
                              Text(
                                'No feedback provided yet',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
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
              fontSize: 14,
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return const Color(0xFF00C896);
      case 'in_progress':
        return const Color(0xFF2196F3);
      case 'requested':
        return const Color(0xFFFFB648);
      case 'cancelled':
        return const Color(0xFFFF4757);
      default:
        return Colors.grey;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'emergency':
        return const Color(0xFFFF4757);
      case 'high':
        return const Color(0xFFFF9A00);
      case 'medium':
        return const Color(0xFF2196F3);
      case 'low':
        return AppColors.primaryGreen;
      default:
        return Colors.grey;
    }
  }
}