import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/app_colors.dart';
import '../../services/patients/nurse_patient_service.dart';
import '../../models/patients/nurse_patient_models.dart';
import '../../services/patients_assessments/progress_note_service.dart';
import '../../models/patients_assessments/progress_note_models.dart';
import 'widgets/edit_progress_note_form.dart';

/// Optimized Smart Refresh Nurse Patients Screen with:
/// - Performance optimizations for low-end devices
/// - Debounced search to prevent excessive API calls
/// - Cached filtering to reduce CPU usage
/// - Image caching for better performance
/// - RepaintBoundary for complex widgets
/// - Intelligent cache management
/// - Tab visibility awareness for optimal refresh timing
/// - App lifecycle detection for background/foreground transitions
/// - Rate limiting to prevent excessive API calls
/// - Visual feedback for data freshness
/// - Manual refresh always available
/// - Pagination support like incident reports
class NursePatientsScreen extends StatefulWidget {
  final Map<String, dynamic> nurseData;
  
  const NursePatientsScreen({
    Key? key,
    required this.nurseData,
  }) : super(key: key);

  @override
  State<NursePatientsScreen> createState() => _NursePatientsScreenState();
}

class _NursePatientsScreenState extends State<NursePatientsScreen>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  
  @override
  bool get wantKeepAlive => true;

  final Set<int> _expandedNotes = {};
  final _nursePatientService = NursePatientService();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  late TabController _tabController;
  
  // UI State
  String _searchQuery = '';
  String _selectedFilter = 'All';
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  List<Patient> _patients = [];
  
  // OPTIMIZED: Search debouncing
  Timer? _searchDebounce;
  Timer? _scrollDebounce;
  
  // Pagination - NEW
  static const int _perPage = 15;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalPatients = 0;
  bool _hasMorePages = false;
  
  // Scroll optimization
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
  
  // Status counts for tabs
  Map<String, int> _priorityCounts = {
    'all': 0,
    'critical': 0,
    'high': 0,
    'medium': 0,
    'low': 0,
  };
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);
    _loadPatients(forceRefresh: false);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      setState(() {
        switch (_tabController.index) {
          case 0:
            _selectedFilter = 'All';
            break;
          case 1:
            _selectedFilter = 'Critical Priority'; // Add this
            break;
          case 2:
            _selectedFilter = 'High Priority';
            break;
          case 3:
            _selectedFilter = 'Medium Priority';
            break;
          case 4:
            _selectedFilter = 'Low Priority';
            break;
        }
        _currentPage = 1;
        _patients.clear();
      });
      _loadPatients(forceRefresh: true);
    }
  }

  bool _isNotEmpty(String? value) {
  return value != null && value.trim().isNotEmpty;
}

/// Helper to check if note has any interventions
bool _hasInterventions(ProgressNote note) {
  // Check if interventions map exists and has data
  if (note.interventions != null && note.interventions is Map) {
    final interventions = note.interventions as Map;
    return interventions.isNotEmpty;
  }
  
  // Check if interventionsProvided string exists and has data
  if (note.interventionsProvided != null && note.interventionsProvided!.trim().isNotEmpty) {
    return true;
  }
  
  return false;
}

  // OPTIMIZED: Debounced scroll listener to reduce CPU usage
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
          _loadMorePatients();
        }
      });
    }
    
    _lastScrollPosition = currentPosition;
  }

  /// Make a phone call to the given phone number
Future<void> _makePhoneCall(String? phoneNumber) async {
  if (phoneNumber == null || phoneNumber.isEmpty) {
    _showErrorSnackBar('Phone number not available');
    return;
  }

  // Clean the phone number (remove spaces, dashes, etc.)
  final cleanedNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
  
  final Uri phoneUri = Uri(
    scheme: 'tel',
    path: cleanedNumber,
  );

  try {
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      if (mounted) {
        _showErrorSnackBar('Unable to make phone call');
      }
    }
  } catch (e) {
    if (mounted) {
      _showErrorSnackBar('Error making phone call: $e');
    }
    debugPrint('Error launching phone dialer: $e');
  }
}

/// Show confirmation dialog before calling
Future<void> _confirmAndCall(String? phoneNumber, String contactName) async {
  if (phoneNumber == null || phoneNumber.isEmpty) {
    _showErrorSnackBar('Phone number not available');
    return;
  }

  final bool? shouldCall = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.phone,
              color: AppColors.primaryGreen,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Make Call',
              style: TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Call $contactName?',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.phone_outlined,
                  size: 20,
                  color: AppColors.primaryGreen,
                ),
                const SizedBox(width: 8),
                Text(
                  phoneNumber,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Cancel',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.phone, size: 18),
          label: const Text('Call Now'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    ),
  );

  if (shouldCall == true) {
    await _makePhoneCall(phoneNumber);
  }
}

/// Show error snackbar
void _showErrorSnackBar(String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      duration: const Duration(seconds: 3),
    ),
  );
}

  // ==================== PUBLIC METHODS FOR PARENT NAVIGATION ====================
  
  /// Public method to trigger manual refresh (called by parent)
  void loadPatients({bool forceRefresh = false}) {
    _loadPatients(forceRefresh: forceRefresh);
  }
  
  // ==================== SMART REFRESH LOGIC ====================
  
  /// Called by parent when tab becomes visible
  void onTabVisible() {
    _isTabVisible = true;
    final now = DateTime.now();
    
    debugPrint('👁️ Patients tab visible - checking if refresh needed');
    
    // Calculate time since last visible
    final timeSinceLastVisible = _lastVisibleTime != null 
        ? now.difference(_lastVisibleTime!) 
        : null;
    
    _lastVisibleTime = now;
    
    // Smart refresh decision
    if (_shouldRefreshOnVisible(timeSinceLastVisible)) {
      debugPrint('🔄 Auto-refreshing patients (reason: ${_getRefreshReason(timeSinceLastVisible)})');
      _loadPatients(forceRefresh: true, silent: true);
    } else {
      debugPrint('✅ Using cached data - still fresh');
    }
  }
  
  /// Called by parent when tab becomes hidden
  void onTabHidden() {
    _isTabVisible = false;
    debugPrint('👁️‍🗨️ Patients tab hidden');
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
    if (_lastFetchTime == null || _patients.isEmpty) return true;
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
  
  /// Load patients with smart caching and rate limiting
  Future<void> _loadPatients({
    bool forceRefresh = false, 
    bool silent = false
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
    if (!forceRefresh && !_isCacheExpired && _patients.isNotEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      debugPrint('📦 Using cached patients data (${_cacheAge})');
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
    
    debugPrint('🌐 Fetching patients from API (page $_currentPage)...');

    try {
      final response = await _nursePatientService.getNursePatients(
        search: _searchQuery.isEmpty ? null : _searchQuery,
        priority: _selectedFilter == 'All' ? null : _selectedFilter,
        page: _currentPage,
        perPage: _perPage,
      );

      if (mounted) {
        final hadPatients = _patients.isNotEmpty;
        final newPatientCount = response.data.length;
        
        // Update priority counts from response
        if (response.counts != null) {
          _priorityCounts = response.counts!;
        } else {
          // Calculate priority counts manually if not provided
          _priorityCounts = {
            'all': newPatientCount,
            'critical': response.data.where((p) => p.priority == 'Critical').length,
            'high': response.data.where((p) => p.priority == 'High').length,
            'medium': response.data.where((p) => p.priority == 'Medium').length,
            'low': response.data.where((p) => p.priority == 'Low').length,
          };
        }
        
        setState(() {
          _patients = response.data;
          _totalPatients = response.total;
          _currentPage = response.currentPage;
          _totalPages = response.lastPage;
          _hasMorePages = _currentPage < _totalPages;
          _lastFetchTime = DateTime.now();
          _isLoading = false;
          _canLoadMore = true;
        });
        
        debugPrint('✅ Patients loaded: $newPatientCount patients (${_cacheAge})');
        debugPrint('📊 Page $_currentPage of $_totalPages');
        
        // Show notification if new patients appeared during silent refresh
        if (silent && _isTabVisible && newPatientCount > 0 && 
            (!hadPatients || newPatientCount != hadPatients)) {
          _showDataUpdatedNotification(newPatientCount);
        }
      }
    } on NursePatientException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isLoading = false;
        });
        debugPrint('❌ Error loading patients: ${e.message}');
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
  
  /// Load more patients (pagination)
  Future<void> _loadMorePatients() async {
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
      final response = await _nursePatientService.getNursePatients(
        search: _searchQuery.isEmpty ? null : _searchQuery,
        priority: _selectedFilter == 'All' ? null : _selectedFilter,
        page: nextPage,
        perPage: _perPage,
      );

      if (mounted) {
        setState(() {
          _currentPage = nextPage;
          _patients.addAll(response.data);
          _totalPatients = response.total;
          _totalPages = response.lastPage;
          _hasMorePages = _currentPage < _totalPages;
          _isLoadingMore = false;
        });
        
        debugPrint('✅ Loaded ${response.data.length} more patients');
        debugPrint('📊 Now showing ${_patients.length} of $_totalPatients');
        
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
            content: Text('Failed to load more patients: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
  
  /// Show notification when data updates in background
  void _showDataUpdatedNotification(int patientCount) {
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
            Expanded(
              child: Text(
                'Patient list updated • $patientCount ${patientCount == 1 ? 'patient' : 'patients'}',
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  // ==================== UI HELPERS ====================
  
  /// OPTIMIZED: Debounced search handler
  void _handleSearchChanged(String value) {
    // Cancel previous debounce timer
    if (_searchDebounce?.isActive ?? false) {
      _searchDebounce!.cancel();
    }
    
    // Update search query immediately for UI
    setState(() {
      _searchQuery = value;
    });
    
    // Debounce API call
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (value.length >= 2 || value.isEmpty) {
        setState(() {
          _currentPage = 1;
          _patients.clear();
        });
        _loadPatients(forceRefresh: true);
      }
    });
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'Critical':
        return const Color(0xFFDC143C); 
      case 'High':
        return const Color(0xFFFF4757);
      case 'Medium':
        return const Color(0xFFFF9A00);
      case 'Low':
        return const Color(0xFF199A8E);
      default:
        return Colors.grey;
    }
  }


String _formatTimeAgo(DateTime? dateTime) {
  if (dateTime == null) return 'N/A';
  final now = DateTime.now();
  
  // Normalize both dates to midnight (start of day) for consistent day counting
  // This ensures "3 days ago" means 3 calendar days, not 72 hours
  final normalizedNow = DateTime(now.year, now.month, now.day);
  final normalizedDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
  
  final difference = normalizedNow.difference(normalizedDate);
  
  if (difference.inDays > 0) {
    return '${difference.inDays}d ago';
  } else {
    // For today's dates, calculate hours/minutes from actual time
    final actualDifference = now.difference(dateTime);
    if (actualDifference.inHours > 0) {
      return '${actualDifference.inHours}h ago';
    } else {
      return '${actualDifference.inMinutes}m ago';
    }
  }
}

  String _formatTimeUntil(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    final now = DateTime.now();
    final difference = dateTime.difference(now);
    
    if (difference.inDays > 0) {
      return 'in ${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return 'in ${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return 'in ${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatDateTime(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return DateFormat('MMM dd, yyyy • hh:mm a').format(dateTime);
    } catch (e) {
      return dateTimeStr;
    }
  }

  // ==================== BUILD METHOD ====================
  
  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'My Patients',
              style: TextStyle(
                color: Color(0xFF1A1A1A),
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            // Data freshness indicator
            if (_lastFetchTime != null)
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
        ),
        actions: [
          // Manual refresh button with loading indicator
          IconButton(
            icon: _isLoading && !_isCacheExpired
                ? const SizedBox(
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
            onPressed: _isLoading ? null : () => _loadPatients(forceRefresh: true),
            tooltip: _isCacheExpired ? 'Data expired - Tap to refresh' : 'Refresh patients',
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
          // Search Bar (styled like incident report)
          _buildSearchBar(),
          
          // Tabs (styled like incident report)
          _buildTabs(),
          
          // Patient List
          Expanded(
            child: _buildBody(),
          ),
        ],
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
          onChanged: _handleSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search patients, conditions, care types...',
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
                      _handleSearchChanged('');
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
              _buildTab('All', _priorityCounts['all'] ?? 0, 0),
              _buildTab('Critical', _priorityCounts['critical'] ?? 0, 1), // Add this
              _buildTab('High', _priorityCounts['high'] ?? 0, 2),
              _buildTab('Medium', _priorityCounts['medium'] ?? 0, 3),
              _buildTab('Low', _priorityCounts['low'] ?? 0, 4),
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

  Widget _buildBody() {
    if (_isLoading && _patients.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
        ),
      );
    }

    if (_errorMessage != null && _patients.isEmpty) {
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
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _loadPatients(forceRefresh: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
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

    if (_patients.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () => _loadPatients(forceRefresh: true),
      color: AppColors.primaryGreen,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _patients.length + (_hasMorePages ? 1 : 0),
        addAutomaticKeepAlives: true,
        cacheExtent: 500,
        itemBuilder: (context, index) {
          if (index == _patients.length) {
            return _buildLoadMoreIndicator();
          }
          return _buildPatientCard(_patients[index]);
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
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading more patients...',
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
                onPressed: _canLoadMore ? _loadMorePatients : null,
                icon: const Icon(Icons.expand_more_rounded, size: 20),
                label: Text(
                  'Load More (${_totalPatients - _patients.length} remaining)',
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
                        _selectedFilter == 'All'
                          ? Icons.group_outlined
                          : Icons.person_search_outlined,
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
                  ? 'No Patients Found'
                  : _selectedFilter == 'All'
                    ? 'No Patients Yet'
                    : 'No $_selectedFilter Patients',
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
                  : _selectedFilter == 'All'
                    ? 'Your assigned patients will appear here once they are added to your care roster'
                    : 'Try switching to another filter or adjust your search',
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

  /// OPTIMIZED: Wrapped in RepaintBoundary to prevent unnecessary repaints
  Widget _buildPatientCard(Patient patient) {
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showPatientDetails(patient),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Patient Avatar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: patient.avatar,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 50,
                        height: 50,
                        color: Colors.grey[200],
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primaryGreen,
                              ),
                            ),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) {
                        return Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              patient.name.isNotEmpty ? patient.name.substring(0, 1) : '?',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                          ),
                        );
                      },
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
                                patient.name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A1A1A),
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _getPriorityColor(patient.priority).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                patient.priority,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: _getPriorityColor(patient.priority),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${patient.age ?? 'N/A'} yrs • ${patient.careType}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF666666),
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          patient.condition,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF999999),
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _buildVitalChip(
                              Icons.favorite,
                              patient.vitals.bloodPressure,
                              const Color(0xFFFF4757),
                            ),
                            _buildVitalChip(
                              Icons.thermostat,
                              '${patient.vitals.temperature}°C',
                              const Color(0xFFFF9A00),
                            ),
                            _buildVitalChip(
                              Icons.air,
                              '${patient.vitals.spo2}%',
                              const Color(0xFF199A8E),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFB),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 12,
                                    color: Colors.grey[500],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Last: ${_formatTimeAgo(patient.lastVisitDateTime)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Icon(
                                    Icons.schedule,
                                    size: 12,
                                    color: Colors.grey[500],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Next: ${_formatTimeUntil(patient.nextVisitDateTime)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
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
        ),
      ),
    );
  }

  Widget _buildVitalChip(IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 10,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showPatientDetails(Patient patient) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
        ),
      ),
    );

    _nursePatientService.getPatientDetail(patient.id).then((response) {
      Navigator.pop(context);
      _showPatientDetailsModal(response.data);
    }).catchError((error) {
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    });
  }

void _showPatientDetailsModal(PatientDetail patientDetail) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => StatefulBuilder(
      builder: (BuildContext context, StateSetter setModalState) {
        return DefaultTabController(
          length: 4,
          child: Container(
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
                    color: AppColors.primaryGreen.withOpacity(0.05),
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
                          // Patient Avatar in Details Modal
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: CachedNetworkImage(
                              imageUrl: patientDetail.avatar,
                              width: 70,
                              height: 70,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                width: 70,
                                height: 70,
                                color: Colors.grey[200],
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.primaryGreen,
                                    ),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) {
                                return Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryGreen.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Center(
                                    child: Text(
                                      patientDetail.name.isNotEmpty 
                                          ? patientDetail.name.substring(0, 1) 
                                          : '?',
                                      style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryGreen,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  patientDetail.name,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${patientDetail.age ?? 'N/A'} years old • ${patientDetail.gender ?? 'N/A'}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF666666),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getPriorityColor(patientDetail.carePlan.priority),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${patientDetail.carePlan.priority} Priority',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
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
                
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[200]!, width: 1),
                    ),
                  ),
                  child: const TabBar(
                    indicatorColor: AppColors.primaryGreen,
                    indicatorWeight: 3,
                    labelColor: AppColors.primaryGreen,
                    unselectedLabelColor: Colors.grey,
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                    unselectedLabelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    tabs: [
                      Tab(
                        icon: Icon(Icons.info_outline, size: 20),
                        text: 'Details',
                      ),
                      Tab(
                        icon: Icon(Icons.note_add_outlined, size: 20),
                        text: 'Daily Note',
                      ),
                      Tab(
                        icon: Icon(Icons.assignment_outlined, size: 20),
                        text: 'Care Plan',
                      ),
                      Tab(
                        icon: Icon(Icons.history, size: 20),
                        text: 'History',
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildDetailsTab(patientDetail),
                      DailyProgressNoteForm(patientDetail: patientDetail),
                      _buildCarePlanTab(patientDetail, setModalState),
                      _buildHistoryTab(patientDetail),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}



void _editProgressNote(ProgressNote note, PatientDetail patientDetail) async {
  // Close the patient details modal first
  Navigator.pop(context);
  
  // Small delay to ensure modal is closed
  await Future.delayed(const Duration(milliseconds: 300));
  
  // Show edit form
  final result = await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => EditProgressNoteForm(
      patientDetail: patientDetail,
      progressNote: note,
    ),
  );
  
  if (result == true && mounted) {
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Progress note updated successfully'),
            ),
          ],
        ),
        backgroundColor: AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
    
    // ✅ Directly refresh the patient list
   // _refreshPatientList();
  }
}

/// Refresh the patient list after update
Future<void> _refreshPatientList() async {
  try {
    setState(() {
      _isLoading = true;
    });

    // ✅ Directly call the service to get fresh patient data
    final response = await _nursePatientService.getNursePatients(
      page: 1, // Reset to first page
      perPage: _perPage,
      search: _searchQuery.isNotEmpty ? _searchQuery : null,
      priority: null, // Don't filter by priority on refresh
    );

    if (mounted) {
      setState(() {
        _patients = response.data; // Replace with fresh data
        _currentPage = 1; // Reset to first page
        _totalPages = response.lastPage;
        _totalPatients = response.total;
        _isLoading = false;
      });
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      
      // Optionally show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to refresh patients: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

  Widget _buildDetailsTab(PatientDetail patientDetail) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (patientDetail.schedules.isNotEmpty) ...[
            _buildProminentVisitSchedule(patientDetail.schedules),
            const SizedBox(height: 20),
          ],
          
          if (patientDetail.vitals != null) ...[
            _buildProminentVitals(patientDetail.vitals!),
            const SizedBox(height: 20),
          ],
          
          _buildDetailSection(
            'Medical Information',
            [
              if (patientDetail.medicalInfo.conditions.isNotEmpty)
                _buildDetailRow('Conditions', patientDetail.medicalInfo.conditions.join(', ')),
              if (patientDetail.medicalInfo.allergies.isNotEmpty)
                _buildDetailRow('Allergies', patientDetail.medicalInfo.allergies.join(', ')),
              if (patientDetail.medicalInfo.currentMedications.isNotEmpty)
                _buildDetailRow('Current Medications', patientDetail.medicalInfo.currentMedications.join(', ')),
            ],
          ),
          const SizedBox(height: 20),
          
          _buildDetailSection(
            'Care Information',
            [
              _buildDetailRow('Care Type', patientDetail.carePlan.careType),
              _buildDetailRow('Care Plan', patientDetail.carePlan.title),
              if (patientDetail.carePlan.description != null)
                _buildDetailRow('Description', patientDetail.carePlan.description!),
            ],
          ),
          const SizedBox(height: 20),
          
          _buildDetailSection(
            'Contact Information',
            [
              if (patientDetail.phone != null)
                _buildDetailRow('Phone', patientDetail.phone!),
              if (patientDetail.email != null)
                _buildDetailRow('Email', patientDetail.email!),
              _buildDetailRow('Address', patientDetail.address),
            ],
          ),
          const SizedBox(height: 20),
          
          _buildDetailSection(
            'Emergency Contact',
            [
              _buildDetailRow('Name', patientDetail.emergencyContact.name),
              _buildDetailRow('Phone', patientDetail.emergencyContact.phone),
            ],
          ),
          const SizedBox(height: 20),
          
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _confirmAndCall(
                    patientDetail.phone,
                    patientDetail.name,
                  ),
                  icon: const Icon(Icons.phone, size: 18),
                  label: const Text('Call Patient'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryGreen,
                    side: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _confirmAndCall(
                    patientDetail.emergencyContact.phone,
                    patientDetail.emergencyContact.name,
                  ),
                  icon: const Icon(Icons.contact_phone, size: 18),
                  label: const Text('Call Emergency'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF4757),
                    side: const BorderSide(color: Color(0xFFFF4757), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
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
  }

  Widget _buildProminentVisitSchedule(List<Schedule> schedules) {
    final visitTimes = _getVisitTimes(schedules);
    final lastVisit = visitTimes['lastVisit'];
    final nextVisit = visitTimes['nextVisit'];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2196F3).withOpacity(0.1),
            const Color(0xFF2196F3).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2196F3).withOpacity(0.3),
          width: 2,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.calendar_today_rounded,
                  color: Color(0xFF2196F3),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Visit Schedule',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Last Visit',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      lastVisit != null ? _formatTimeAgo(lastVisit) : 'No visits yet',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    if (lastVisit != null)
                      Text(
                        _formatDate(lastVisit),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
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
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Next Visit',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      nextVisit != null ? _formatTimeUntil(nextVisit) : 'Not scheduled',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: nextVisit != null ? const Color(0xFF2196F3) : Colors.grey[600],
                      ),
                    ),
                    if (nextVisit != null)
                      Text(
                        _formatDate(nextVisit),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

Map<String, DateTime?> _getVisitTimes(List<Schedule> schedules) {
  DateTime? lastVisit;
  DateTime? nextVisit;
  final now = DateTime.now();

  try {
    // Get completed visits
    final completedVisits = schedules
        .where((s) => s.status.toLowerCase() == 'completed')
        .map((s) {
          try {
            return DateTime.parse(s.date);
          } catch (e) {
            return null;
          }
        })
        .where((d) => d != null)
        .cast<DateTime>()
        .toList();

    if (completedVisits.isNotEmpty) {
      completedVisits.sort((a, b) => b.compareTo(a));
      lastVisit = completedVisits.first;
    }

    // Get all scheduled/pending visits (regardless of date)
    final scheduledVisits = schedules
        .where((s) => ['scheduled', 'pending', 'in_progress'].contains(s.status.toLowerCase()))
        .map((s) {
          try {
            return DateTime.parse(s.date);
          } catch (e) {
            return null;
          }
        })
        .where((d) => d != null)
        .cast<DateTime>()
        .toList();

    if (scheduledVisits.isNotEmpty) {
      // Separate future and past visits
      final futureVisits = scheduledVisits.where((d) => d.isAfter(now)).toList();
      
      if (futureVisits.isNotEmpty) {
        // If there are future visits, show the earliest one
        futureVisits.sort((a, b) => a.compareTo(b));
        nextVisit = futureVisits.first;
      } else {
        // If no future visits, show the most recent scheduled visit
        scheduledVisits.sort((a, b) => b.compareTo(a));
        nextVisit = scheduledVisits.first;
      }
    }
  } catch (e) {
    debugPrint('Error parsing visit times: $e');
  }

  return {'lastVisit': lastVisit, 'nextVisit': nextVisit};
}

  Widget _buildProminentVitals(PatientVitals vitals) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryGreen.withOpacity(0.1),
            AppColors.primaryGreen.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryGreen.withOpacity(0.3),
          width: 2,
        ),
      ),
      padding: const EdgeInsets.all(14), 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, 
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: AppColors.primaryGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Latest Vitals',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const Spacer(),
              if (vitals.recordedAt != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _formatTimeAgo(DateTime.parse(vitals.recordedAt!)),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14), 
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 10, 
            children: [
              _buildVitalCard(
                icon: Icons.favorite,
                label: 'Blood Pressure',
                value: vitals.bloodPressure,
                color: const Color(0xFFFF4757),
              ),
              _buildVitalCard(
                icon: Icons.monitor_heart,
                label: 'Pulse',
                value: '${vitals.pulse} bpm',
                color: const Color(0xFFFF6B9D),
              ),
              _buildVitalCard(
                icon: Icons.thermostat,
                label: 'Temperature',
                value: '${vitals.temperature}°C',
                color: const Color(0xFFFF9A00),
              ),
              _buildVitalCard(
                icon: Icons.air,
                label: 'SpO₂',
                value: '${vitals.spo2}%',
                color: AppColors.primaryGreen,
              ),
              _buildVitalCard(
                icon: Icons.air_rounded,
                label: 'Respiration',
                value: '${vitals.respiration}/min',
                color: const Color(0xFF2196F3),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVitalCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), 
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min, 
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color), 
              const SizedBox(width: 4), 
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10, 
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                    height: 1.0, 
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2), 
          Text(
            value,
            style: TextStyle(
              fontSize: 13, 
              fontWeight: FontWeight.bold,
              color: color,
              height: 1.0,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    if (children.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF999999),
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF666666),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
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

Widget _buildCarePlanTab(PatientDetail patientDetail, StateSetter setModalState) {
  final carePlans = patientDetail.carePlans;
  
  // If only one care plan, show it directly without swipe functionality
  if (carePlans.length == 1) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: CarePlanCard(
        carePlan: carePlans[0],
        patientDetail: patientDetail,
        modalSetState: setModalState,
        onToggleTask: _toggleTaskCompletion,
        showNumber: false,
        planNumber: 1,
      ),
    );
  }
  
  // Multiple care plans - use the SwipeableCarePlans widget
  return SwipeableCarePlans(
    carePlans: carePlans,
    patientDetail: patientDetail,
    modalSetState: setModalState,
    onToggleTask: _toggleTaskCompletion,
  );
}


Widget _buildCheckableCareTask({
  required int index,
  required String task,
  required bool isCompleted,
  required IconData icon,
  required Color color,
  required PatientDetail patientDetail,
  required StateSetter setModalState,
  required int carePlanId, // Add this parameter
}) {
  return Container(
    decoration: BoxDecoration(
      color: isCompleted ? color.withOpacity(0.05) : color.withOpacity(0.05),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isCompleted ? color : color.withOpacity(0.2),
        width: isCompleted ? 2 : 1,
      ),
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _toggleTaskCompletion(
          carePlanId, // Use the passed carePlanId instead of patientDetail.carePlan.id
          index,
          !isCompleted,
          patientDetail,
          setModalState,
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Checkbox
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isCompleted ? color : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: color,
                    width: 2,
                  ),
                ),
                child: isCompleted
                    ? const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              // Icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              // Task text
              Expanded(
                child: Text(
                  task,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1A1A),
                    decoration: isCompleted 
                        ? TextDecoration.lineThrough 
                        : TextDecoration.none,
                    decorationColor: color,
                    decorationThickness: 2,
                  ),
                ),
              ),
              // Completion badge
              if (isCompleted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

// Add this method to handle task completion toggle
Future<void> _toggleTaskCompletion(
  int carePlanId,
  int taskIndex,
  bool isCompleted,
  PatientDetail patientDetail,
  StateSetter setModalState,
) async {
  try {
    // Call API immediately
    final response = await _nursePatientService.toggleCareTaskCompletion(
      carePlanId: carePlanId,
      taskIndex: taskIndex,
      isCompleted: isCompleted,
    );

    if (response['success'] == true) {
      // Update local state immediately using setModalState
      setModalState(() {
        // ✅ Find the SPECIFIC care plan that was clicked
        final targetCarePlan = patientDetail.carePlans.firstWhere(
          (cp) => cp.id == carePlanId,
          orElse: () => patientDetail.carePlan, // fallback to primary
        );
        
        if (isCompleted) {
          if (!targetCarePlan.completedTasks.contains(taskIndex)) {
            targetCarePlan.completedTasks.add(taskIndex);
          }
        } else {
          targetCarePlan.completedTasks.remove(taskIndex);
        }
        
        // Update completion percentage from response
        final data = response['data'] as Map<String, dynamic>;
        targetCarePlan.completionPercentage = 
            data['completion_percentage'] as int;
            
        // ✅ Also update primary care plan if it matches (for consistency)
        if (patientDetail.carePlan.id == carePlanId) {
          if (isCompleted) {
            if (!patientDetail.carePlan.completedTasks.contains(taskIndex)) {
              patientDetail.carePlan.completedTasks.add(taskIndex);
            }
          } else {
            patientDetail.carePlan.completedTasks.remove(taskIndex);
          }
          patientDetail.carePlan.completionPercentage = 
              data['completion_percentage'] as int;
        }
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  isCompleted ? Icons.check_circle : Icons.cancel,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    response['message'] ?? 
                        (isCompleted ? 'Task completed!' : 'Task marked incomplete'),
                  ),
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
    }
  } on NursePatientException catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(e.message)),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text('Failed to update task. Please try again.'),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

  IconData _getTaskIcon(int index) {
    const icons = [
      Icons.medication,
      Icons.fitness_center,
      Icons.monitor_heart,
      Icons.restaurant,
      Icons.cleaning_services,
      Icons.medical_services,
    ];
    return icons[index % icons.length];
  }

  Color _getTaskColor(int index) {
    const colors = [
      Color(0xFFFF4757),
      Color(0xFF2196F3),
      AppColors.primaryGreen,
      Color(0xFFFF9A00),
      Color(0xFF6C63FF),
      Color(0xFFE91E63),
    ];
    return colors[index % colors.length];
  }

  Widget _buildCareInstruction({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

Widget _buildHistoryTab(PatientDetail patientDetail) {
  return StatefulBuilder(
    builder: (BuildContext context, StateSetter setModalState) {
      // Local state for expanded notes within this modal
      final Set<int> localExpandedNotes = _expandedNotes;
      
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Care History & Progress Notes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 16),
            
            if (patientDetail.recentNotes.isNotEmpty)
              ...patientDetail.recentNotes.asMap().entries.map((entry) {
                final index = entry.key;
                final note = entry.value;
                return _buildComprehensiveHistoryNote(
                  note, 
                  index,
                  localExpandedNotes,
                  setModalState, 
                  patientDetail,
                );
              }).toList()
            else
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.note_outlined,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No progress notes yet',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Daily progress notes will appear here',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
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
  );
}

Widget _buildComprehensiveHistoryNote(
  ProgressNote note, 
  int index,
  Set<int> expandedNotes,
  StateSetter setModalState,
  PatientDetail patientDetail,
) {
  final isExpanded = expandedNotes.contains(index);
  final isAuthor = true;
  
  // Check if within 24 hours
  final createdAt = note.createdAt != null ? DateTime.parse(note.createdAt!) : null;
  final hoursSinceCreation = createdAt != null 
      ? DateTime.now().difference(createdAt).inHours 
      : 999;
  final isEditable = isAuthor && hoursSinceCreation < 24;
  
  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey[200]!),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Clickable Header
        InkWell(
          onTap: () {
            setModalState(() {
              if (isExpanded) {
                expandedNotes.remove(index);
              } else {
                expandedNotes.add(index);
              }
            });
          },
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isExpanded ? Radius.zero : const Radius.circular(16),
            bottomRight: isExpanded ? Radius.zero : const Radius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryGreen.withOpacity(0.08),
                  AppColors.primaryGreen.withOpacity(0.03),
                ],
              ),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: isExpanded ? Radius.zero : const Radius.circular(16),
                bottomRight: isExpanded ? Radius.zero : const Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.note_alt_outlined,
                    color: AppColors.primaryGreen,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Daily Progress Note',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                          ),
                          // Edit button - only show if editable
                          if (isEditable && isExpanded) ...[
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _editProgressNote(note, patientDetail), 
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryGreen,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(
                                      Icons.edit,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Edit',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 12, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _formatDateTime(note.createdAt ?? ''),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Show editable time remaining
                          if (isAuthor && hoursSinceCreation < 24) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreen.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${24 - hoursSinceCreation}h to edit',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.keyboard_arrow_down,
                    color: AppColors.primaryGreen,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Preview when collapsed
        if (!isExpanded)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (note.generalCondition != null) ...[
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(
                              Icons.health_and_safety,
                              size: 14,
                              color: AppColors.primaryGreen,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              note.generalCondition!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF1A1A1A),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (note.painLevel != null) ...[
                      if (note.generalCondition != null)
                        Container(
                          width: 1,
                          height: 20,
                          color: Colors.grey[300],
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      Row(
                        children: [
                          const Icon(
                            Icons.sentiment_satisfied_alt,
                            size: 14,
                            color: Color(0xFFFF9A00),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Pain: ${note.painLevel}/10',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF1A1A1A),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Tap to view full details',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        
        // Full content when expanded
// Full content when expanded
if (isExpanded) ...[
  Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // General Condition & Pain Level
        if (note.generalCondition != null || note.painLevel != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                if (note.generalCondition != null)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.health_and_safety,
                              size: 16,
                              color: AppColors.primaryGreen,
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
                          note.generalCondition!,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF1A1A1A),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (note.generalCondition != null && note.painLevel != null)
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.grey[300],
                  ),
                if (note.generalCondition != null && note.painLevel != null)
                  const SizedBox(width: 12),
                if (note.painLevel != null)
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
                          '${note.painLevel}/10',
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
        if (note.generalCondition != null || note.painLevel != null)
          const SizedBox(height: 16),
        
        // Vital Signs - UPDATED CHECK
        if (note.vitals != null && note.vitals is Map && (note.vitals as Map).isNotEmpty) ...[
          Row(
            children: [
              Icon(Icons.favorite, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 6),
              const Text(
                'VITAL SIGNS',
                style: TextStyle(
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
                if (note.vitals!['temperature'] != null)
                  _buildVitalBadge(
                    icon: Icons.thermostat,
                    label: 'Temp',
                    value: '${note.vitals!['temperature']}°C',
                    color: const Color(0xFFFF9A00),
                  ),
                if (note.vitals!['pulse'] != null)
                  _buildVitalBadge(
                    icon: Icons.monitor_heart,
                    label: 'Pulse',
                    value: '${note.vitals!['pulse']} bpm',
                    color: const Color(0xFFFF4757),
                  ),
                if (note.vitals!['blood_pressure'] != null)
                  _buildVitalBadge(
                    icon: Icons.favorite,
                    label: 'BP',
                    value: note.vitals!['blood_pressure'].toString(),
                    color: const Color(0xFFFF6B9D),
                  ),
                if (note.vitals!['respiration'] != null)
                  _buildVitalBadge(
                    icon: Icons.air,
                    label: 'Resp',
                    value: '${note.vitals!['respiration']}/min',
                    color: const Color(0xFF2196F3),
                  ),
                if (note.vitals!['spo2'] != null)
                  _buildVitalBadge(
                    icon: Icons.speed,
                    label: 'SpO₂',
                    value: '${note.vitals!['spo2']}%',
                    color: AppColors.primaryGreen,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        
        // Interventions - UPDATED CHECK
        if (_hasInterventions(note)) ...[
          Row(
            children: [
              Icon(Icons.medical_services, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 6),
              const Text(
                'INTERVENTIONS PROVIDED',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF999999),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (note.interventions != null && note.interventions is Map)
            ..._buildInterventionsList(note.interventions!)
          else if (_isNotEmpty(note.interventionsProvided))
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF2196F3).withOpacity(0.2),
                ),
              ),
              child: Text(
                note.interventionsProvided!,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[800],
                  height: 1.5,
                ),
              ),
            ),
          const SizedBox(height: 16),
        ],
        
        // Wound Status - UPDATED CHECK
        if (_isNotEmpty(note.woundStatus)) ...[
          _buildInfoSection(
            icon: Icons.healing,
            title: 'WOUND STATUS',
            content: note.woundStatus!,
            backgroundColor: const Color(0xFFFFF3E0),
            borderColor: const Color(0xFFFF9800),
          ),
          const SizedBox(height: 16),
        ],
        
        // Observations - UPDATED CHECK
        if (_isNotEmpty(note.otherObservations)) ...[
          _buildInfoSection(
            icon: Icons.remove_red_eye,
            title: 'OTHER OBSERVATIONS',
            content: note.otherObservations!,
            backgroundColor: const Color(0xFFF5F0FF),
            borderColor: const Color(0xFF6C63FF),
          ),
          const SizedBox(height: 16),
        ] else if (_isNotEmpty(note.observations)) ...[
          _buildInfoSection(
            icon: Icons.remove_red_eye,
            title: 'OBSERVATIONS',
            content: note.observations!,
            backgroundColor: const Color(0xFFF5F0FF),
            borderColor: const Color(0xFF6C63FF),
          ),
          const SizedBox(height: 16),
        ],
        
        // Education Provided - UPDATED CHECK
        if (_isNotEmpty(note.educationProvided)) ...[
          _buildInfoSection(
            icon: Icons.school,
            title: 'EDUCATION PROVIDED',
            content: note.educationProvided!,
            backgroundColor: const Color(0xFFE8F5E9),
            borderColor: const Color(0xFF4CAF50),
          ),
          const SizedBox(height: 16),
        ],
        
        // Family Concerns - UPDATED CHECK
        if (_isNotEmpty(note.familyConcerns)) ...[
          _buildInfoSection(
            icon: Icons.people,
            title: 'FAMILY/CLIENT CONCERNS',
            content: note.familyConcerns!,
            backgroundColor: const Color(0xFFFFF8E1),
            borderColor: const Color(0xFFFFC107),
          ),
          const SizedBox(height: 16),
        ],
        
        // Next Steps - UPDATED CHECK
        if (_isNotEmpty(note.nextSteps)) ...[
          _buildInfoSection(
            icon: Icons.event_note,
            title: 'PLAN / NEXT STEPS',
            content: note.nextSteps!,
            backgroundColor: const Color(0xFFE3F2FD),
            borderColor: const Color(0xFF2196F3),
          ),
        ],
      ],
    ),
  ),
  
  // Footer - Timestamp
  if (note.createdAt != null)
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
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
            _formatTimeAgo(DateTime.parse(note.createdAt!)),
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
      ],
    ),
  );
}

  // Helper method to build individual intervention items
  List<Widget> _buildInterventionsList(Map<String, dynamic> interventions) {
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
        'color': AppColors.primaryGreen,
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

  // Helper method to build info sections
  Widget _buildInfoSection({
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
            Icon(
              icon,
              size: 16,
              color: Colors.grey[600],
            ),
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

  Widget _buildVitalBadge({
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
}

// ==================== SWIPEABLE CARE PLANS WIDGET ====================
class SwipeableCarePlans extends StatefulWidget {
  final List<CarePlan> carePlans;
  final PatientDetail patientDetail;
  final StateSetter modalSetState;
  final Future<void> Function(int carePlanId, int taskIndex, bool isCompleted, PatientDetail patientDetail, StateSetter modalSetState) onToggleTask;

  const SwipeableCarePlans({
    Key? key,
    required this.carePlans,
    required this.patientDetail,
    required this.modalSetState,
    required this.onToggleTask,
  }) : super(key: key);

  @override
  State<SwipeableCarePlans> createState() => _SwipeableCarePlansState();
}

class _SwipeableCarePlansState extends State<SwipeableCarePlans> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header with swipe indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Colors.grey[200]!),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Active Care Plans',
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
                        Icons.swipe_rounded,
                        size: 16,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Swipe to view all plans',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryGreen,
                      AppColors.primaryGreen.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryGreen.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '${widget.carePlans.length} Plans',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Swipeable care plans
        Expanded(
          child: Column(
            children: [
              // Page indicator with plan counter
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    // Page dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        widget.carePlans.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == index ? 32 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? AppColors.primaryGreen
                                : Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Plan counter
                    Text(
                      'Plan ${_currentPage + 1} of ${widget.carePlans.length}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
              
              // PageView with care plans
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (page) {
                    setState(() {
                      _currentPage = page;
                    });
                  },
                  itemCount: widget.carePlans.length,
                  itemBuilder: (context, index) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: CarePlanCard(
                        carePlan: widget.carePlans[index],
                        patientDetail: widget.patientDetail,
                        modalSetState: widget.modalSetState,
                        onToggleTask: widget.onToggleTask,
                        showNumber: true,
                        planNumber: index + 1,
                      ),
                    );
                  },
                ),
              ),
              
              // Navigation arrows
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Previous button
                    ElevatedButton.icon(
                      onPressed: _currentPage > 0
                          ? () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          : null,
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Previous'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primaryGreen,
                        disabledBackgroundColor: Colors.grey[100],
                        disabledForegroundColor: Colors.grey[400],
                        elevation: 0,
                        side: BorderSide(
                          color: _currentPage > 0
                              ? AppColors.primaryGreen
                              : Colors.grey[300]!,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    
                    // Next button
                    ElevatedButton.icon(
                      onPressed: _currentPage < widget.carePlans.length - 1
                          ? () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          : null,
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: const Text('Next'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _currentPage < widget.carePlans.length - 1
                            ? AppColors.primaryGreen
                            : Colors.grey[100],
                        foregroundColor: _currentPage < widget.carePlans.length - 1
                            ? Colors.white
                            : Colors.grey[400],
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ==================== CARE PLAN CARD WIDGET ====================
class CarePlanCard extends StatelessWidget {
  final CarePlan carePlan;
  final PatientDetail patientDetail;
  final StateSetter modalSetState;
  final bool showNumber;
  final int planNumber;
  final Future<void> Function(int carePlanId, int taskIndex, bool isCompleted, PatientDetail patientDetail, StateSetter modalSetState) onToggleTask;

  const CarePlanCard({
    Key? key,
    required this.carePlan,
    required this.patientDetail,
    required this.modalSetState,
    required this.onToggleTask,
    this.showNumber = false,
    this.planNumber = 1,
  }) : super(key: key);

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'High':
        return const Color(0xFFFF4757);
      case 'Medium':
        return const Color(0xFFFF9A00);
      case 'Low':
        return const Color(0xFF199A8E);
      default:
        return Colors.grey;
    }
  }

  Color _getCompletionColor(int percentage) {
    if (percentage >= 80) {
      return AppColors.primaryGreen;
    } else if (percentage >= 50) {
      return const Color(0xFFFF9A00);
    } else if (percentage >= 25) {
      return const Color(0xFFFF9A00);
    } else {
      return const Color(0xFFFF4757);
    }
  }

  IconData _getTaskIcon(int index) {
    const icons = [
      Icons.medication,
      Icons.fitness_center,
      Icons.monitor_heart,
      Icons.restaurant,
      Icons.cleaning_services,
      Icons.medical_services,
    ];
    return icons[index % icons.length];
  }

  Color _getTaskColor(int index) {
    const colors = [
      Color(0xFFFF4757),
      Color(0xFF2196F3),
      AppColors.primaryGreen,
      Color(0xFFFF9A00),
      Color(0xFF6C63FF),
      Color(0xFFE91E63),
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Care Plan Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF6C63FF).withOpacity(0.1),
                  const Color(0xFF6C63FF).withOpacity(0.05),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
              border: Border(
                bottom: BorderSide(
                  color: const Color(0xFF6C63FF).withOpacity(0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                // Plan number badge (if multiple plans)
                if (showNumber) ...[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '$planNumber',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                
                // Plan icon (if single plan)
                if (!showNumber) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.assignment_rounded,
                      color: Color(0xFF6C63FF),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        carePlan.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _getPriorityColor(carePlan.priority).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              carePlan.priority,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _getPriorityColor(carePlan.priority),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              carePlan.careType,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Completion percentage
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getCompletionColor(carePlan.completionPercentage).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getCompletionColor(carePlan.completionPercentage).withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        carePlan.completionPercentage == 100
                            ? Icons.check_circle
                            : Icons.pie_chart_rounded,
                        size: 16,
                        color: _getCompletionColor(carePlan.completionPercentage),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${carePlan.completionPercentage}%',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _getCompletionColor(carePlan.completionPercentage),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Care Plan Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description
                if (carePlan.description != null && carePlan.description!.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.description_outlined,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'DESCRIPTION',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey[600],
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          carePlan.description!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Progress bar
                if (carePlan.careTasks.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primaryGreen.withOpacity(0.1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Task Progress',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                            Text(
                              '${carePlan.completedTasks.length}/${carePlan.careTasks.length} completed',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: carePlan.completionPercentage / 100,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _getCompletionColor(carePlan.completionPercentage),
                            ),
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Care Tasks Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Care Tasks',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    if (carePlan.careTasks.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${carePlan.careTasks.length} tasks',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                
                if (carePlan.careTasks.isNotEmpty)
                  ...carePlan.careTasks.asMap().entries.map((entry) {
                    final index = entry.key;
                    final task = entry.value;
                    final isCompleted = carePlan.completedTasks.contains(index);
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _CheckableCareTask(
                        index: index,
                        task: task,
                        isCompleted: isCompleted,
                        icon: _getTaskIcon(index),
                        color: _getTaskColor(index),
                        patientDetail: patientDetail,
                        modalSetState: modalSetState,
                        carePlanId: carePlan.id,
                        onToggleTask: onToggleTask,
                      ),
                    );
                  }).toList()
                else
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.task_outlined,
                            size: 40,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No care tasks specified',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Checkable Care Task Widget
// Checkable Care Task Widget
class _CheckableCareTask extends StatelessWidget {
  final int index;
  final String task;
  final bool isCompleted;
  final IconData icon;
  final Color color;
  final PatientDetail patientDetail;
  final StateSetter modalSetState;
  final int carePlanId;
  final Future<void> Function(int carePlanId, int taskIndex, bool isCompleted, PatientDetail patientDetail, StateSetter modalSetState) onToggleTask;

  const _CheckableCareTask({
    required this.index,
    required this.task,
    required this.isCompleted,
    required this.icon,
    required this.color,
    required this.patientDetail,
    required this.modalSetState,
    required this.carePlanId,
    required this.onToggleTask,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isCompleted ? color.withOpacity(0.05) : color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted ? color : color.withOpacity(0.2),
          width: isCompleted ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onToggleTask(
            carePlanId,
            index,
            !isCompleted,
            patientDetail,
            modalSetState,
          ),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Checkbox
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isCompleted ? color : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: color,
                      width: 2,
                    ),
                  ),
                  child: isCompleted
                      ? const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                // Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                // Task text
                Expanded(
                  child: Text(
                    task,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1A1A),
                      decoration: isCompleted 
                          ? TextDecoration.lineThrough 
                          : TextDecoration.none,
                      decorationColor: color,
                      decorationThickness: 2,
                    ),
                  ),
                ),
                // Completion badge
                if (isCompleted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}




// ==================== DAILY PROGRESS NOTE FORM ====================
class DailyProgressNoteForm extends StatefulWidget {
  final PatientDetail patientDetail;

  const DailyProgressNoteForm({
    Key? key,
    required this.patientDetail,
  }) : super(key: key);

  @override
  State<DailyProgressNoteForm> createState() => _DailyProgressNoteFormState();
}

class _DailyProgressNoteFormState extends State<DailyProgressNoteForm> {
  final _formKey = GlobalKey<FormState>();
  final _progressNoteService = ProgressNoteService();
  bool _isSaving = false;
  
  DateTime _visitDate = DateTime.now();
  TimeOfDay _visitTime = TimeOfDay.now();
  
  // Required Vital Signs Controllers
  final _temperatureController = TextEditingController();
  final _pulseController = TextEditingController();
  final _respirationController = TextEditingController();
  final _bloodPressureController = TextEditingController();
  final _spo2Controller = TextEditingController();
  
  bool _medicationAdministered = false;
  final _medicationDetailsController = TextEditingController();
  bool _woundCare = false;
  final _woundCareDetailsController = TextEditingController();
  bool _physiotherapy = false;
  final _physiotherapyDetailsController = TextEditingController();
  bool _nutritionSupport = false;
  final _nutritionDetailsController = TextEditingController();
  bool _hygieneCare = false;
  final _hygieneDetailsController = TextEditingController();
  bool _counseling = false;
  final _counselingDetailsController = TextEditingController();
  bool _otherInterventions = false;
  final _otherInterventionsController = TextEditingController();
  
  String? _expandedIntervention;
  
  // Required Observations Fields
  String _generalCondition = 'Stable';
  int _painLevel = 0;
  final _woundStatusController = TextEditingController();
  final _observationsController = TextEditingController();
  
  final _educationProvidedController = TextEditingController();
  final _familyConcernsController = TextEditingController();
  
  final _nextVisitPlanController = TextEditingController();

  @override
  void dispose() {
    _temperatureController.dispose();
    _pulseController.dispose();
    _respirationController.dispose();
    _bloodPressureController.dispose();
    _spo2Controller.dispose();
    _medicationDetailsController.dispose();
    _woundCareDetailsController.dispose();
    _physiotherapyDetailsController.dispose();
    _nutritionDetailsController.dispose();
    _hygieneDetailsController.dispose();
    _counselingDetailsController.dispose();
    _otherInterventionsController.dispose();
    _woundStatusController.dispose();
    _observationsController.dispose();
    _educationProvidedController.dispose();
    _familyConcernsController.dispose();
    _nextVisitPlanController.dispose();
    super.dispose();
  }

  void _toggleInterventionExpansion(String intervention, bool isChecked) {
    setState(() {
      if (isChecked) {
        _expandedIntervention = intervention;
      } else {
        if (_expandedIntervention == intervention) {
          _expandedIntervention = null;
        }
      }
    });
  }

  void _toggleExpansionOnly(String intervention) {
    setState(() {
      if (_expandedIntervention == intervention) {
        _expandedIntervention = null;
      } else {
        _expandedIntervention = intervention;
      }
    });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _visitDate,
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
    if (picked != null && picked != _visitDate) {
      setState(() {
        _visitDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _visitTime,
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
    if (picked != null && picked != _visitTime) {
      setState(() {
        _visitTime = picked;
      });
    }
  }

  Future<void> _saveNote() async {
    if (_formKey.currentState!.validate()) {
      if (_temperatureController.text.isEmpty ||
          _pulseController.text.isEmpty ||
          _respirationController.text.isEmpty ||
          _bloodPressureController.text.isEmpty ||
          _spo2Controller.text.isEmpty) {
        _showErrorSnackBar('All vital signs fields are required');
        return;
      }

      final vitals = _buildVitalsObject();
      if (vitals != null) {
        final vitalsError = _progressNoteService.validateVitals(vitals);
        if (vitalsError != null) {
          _showErrorSnackBar(vitalsError);
          return;
        }
      }

      final painError = _progressNoteService.validatePainLevel(_painLevel);
      if (painError != null) {
        _showErrorSnackBar(painError);
        return;
      }

      setState(() {
        _isSaving = true;
      });

      try {
        final request = CreateProgressNoteRequest(
          visitDate: _progressNoteService.formatDateForApi(_visitDate),
          visitTime: _progressNoteService.formatTimeForApi(
            _visitTime.hour,
            _visitTime.minute,
          ),
          vitals: vitals,
          interventions: _buildInterventionsObject(),
          generalCondition: _generalCondition,
          painLevel: _painLevel,
          woundStatus: _woundStatusController.text.trim().isEmpty
              ? null
              : _woundStatusController.text.trim(),
          otherObservations: _observationsController.text.trim().isEmpty
              ? null
              : _observationsController.text.trim(),
          educationProvided: _educationProvidedController.text.trim().isEmpty
              ? null
              : _educationProvidedController.text.trim(),
          familyConcerns: _familyConcernsController.text.trim().isEmpty
              ? null
              : _familyConcernsController.text.trim(),
          nextSteps: _nextVisitPlanController.text.trim().isEmpty
              ? null
              : _nextVisitPlanController.text.trim(),
        );

        final response = await _progressNoteService.createProgressNote(
          widget.patientDetail.id,
          request,
        );

        if (mounted) {
          setState(() {
            _isSaving = false;
          });

          _showSuccessSnackBar(response.message);
          Navigator.pop(context, true);
        }
      } on ProgressNoteException catch (e) {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });

          if (e.errors != null && e.errors!.isNotEmpty) {
            final errorMessages = <String>[];
            e.errors!.forEach((key, value) {
              if (value is List) {
                errorMessages.addAll(value.map((e) => e.toString()));
              } else {
                errorMessages.add(value.toString());
              }
            });
            _showErrorSnackBar(errorMessages.join('\n'));
          } else {
            _showErrorSnackBar(e.message);
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
          _showErrorSnackBar('An unexpected error occurred. Please try again.');
        }
      }
    }
  }

  ProgressNoteVitals? _buildVitalsObject() {
    return ProgressNoteVitals(
      temperature: _temperatureController.text.isEmpty
          ? null
          : double.tryParse(_temperatureController.text),
      pulse: _pulseController.text.isEmpty
          ? null
          : int.tryParse(_pulseController.text),
      respiration: _respirationController.text.isEmpty
          ? null
          : int.tryParse(_respirationController.text),
      bloodPressure: _bloodPressureController.text.isEmpty
          ? null
          : _bloodPressureController.text.trim(),
      spo2: _spo2Controller.text.isEmpty
          ? null
          : int.tryParse(_spo2Controller.text),
    );
  }

  ProgressNoteInterventions? _buildInterventionsObject() {
    final hasAnyIntervention = _medicationAdministered ||
        _woundCare ||
        _physiotherapy ||
        _nutritionSupport ||
        _hygieneCare ||
        _counseling ||
        _otherInterventions;

    if (!hasAnyIntervention) return null;

    return ProgressNoteInterventions(
      medicationAdministered: _medicationAdministered,
      medicationDetails: _medicationAdministered && _medicationDetailsController.text.isNotEmpty
          ? _medicationDetailsController.text.trim()
          : null,
      woundCare: _woundCare,
      woundCareDetails: _woundCare && _woundCareDetailsController.text.isNotEmpty
          ? _woundCareDetailsController.text.trim()
          : null,
      physiotherapy: _physiotherapy,
      physiotherapyDetails: _physiotherapy && _physiotherapyDetailsController.text.isNotEmpty
          ? _physiotherapyDetailsController.text.trim()
          : null,
      nutritionSupport: _nutritionSupport,
      nutritionDetails: _nutritionSupport && _nutritionDetailsController.text.isNotEmpty
          ? _nutritionDetailsController.text.trim()
          : null,
      hygieneCare: _hygieneCare,
      hygieneDetails: _hygieneCare && _hygieneDetailsController.text.isNotEmpty
          ? _hygieneDetailsController.text.trim()
          : null,
      counseling: _counseling,
      counselingDetails: _counseling && _counselingDetailsController.text.isNotEmpty
          ? _counselingDetailsController.text.trim()
          : null,
      otherInterventions: _otherInterventions,
      otherDetails: _otherInterventions && _otherInterventionsController.text.isNotEmpty
          ? _otherInterventionsController.text.trim()
          : null,
    );
  }



  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }


@override
Widget build(BuildContext context) {
  return GestureDetector(
    onTap: () {
      FocusScope.of(context).unfocus();
    },
    child: Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20, // Changed this line
        ),
        physics: const ClampingScrollPhysics(), // Added this line
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Visit Date and Time
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Visit Date *',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _selectDate,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 20, color: AppColors.primaryGreen),
                        const SizedBox(width: 12),
                        Text(
                          DateFormat('MM/dd/yyyy').format(_visitDate),
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF1A1A1A),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Visit Time *',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _selectTime,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time, size: 20, color: AppColors.primaryGreen),
                        const SizedBox(width: 12),
                        Text(
                          _visitTime.format(context),
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF1A1A1A),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Vital Signs
            Row(
              children: [
                const Icon(Icons.favorite, color: AppColors.primaryGreen, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Vital Signs (All Required)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            
            Row(
              children: [
                Expanded(
                  child: _buildRequiredNumberField(
                    label: 'Temperature (°C) *',
                    controller: _temperatureController,
                    hint: '36.5',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildRequiredNumberField(
                    label: 'Pulse (bpm) *',
                    controller: _pulseController,
                    hint: '72',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: _buildRequiredNumberField(
                    label: 'Respiration (/min) *',
                    controller: _respirationController,
                    hint: '16',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildRequiredTextField(
                    label: 'Blood Pressure *',
                    controller: _bloodPressureController,
                    hint: '120/80',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            _buildRequiredNumberField(
              label: 'SpO₂ (%) *',
              controller: _spo2Controller,
              hint: '98',
            ),
            const SizedBox(height: 24),
            
            // Interventions
            Row(
              children: [
                const Icon(Icons.medical_services, color: Color(0xFFFF9A00), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Interventions Provided',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            
            _buildExpandableCheckbox(
              label: 'Medication Administered',
              value: _medicationAdministered,
              interventionKey: 'medication',
              controller: _medicationDetailsController,
              hint: 'List medications administered...',
              onChanged: (value) {
                setState(() {
                  _medicationAdministered = value!;
                });
                _toggleInterventionExpansion('medication', value!);
              },
            ),
            
            _buildExpandableCheckbox(
              label: 'Wound Care',
              value: _woundCare,
              interventionKey: 'wound',
              controller: _woundCareDetailsController,
              hint: 'Describe wound care provided...',
              onChanged: (value) {
                setState(() {
                  _woundCare = value!;
                });
                _toggleInterventionExpansion('wound', value!);
              },
            ),
            
            _buildExpandableCheckbox(
              label: 'Physiotherapy/Exercise',
              value: _physiotherapy,
              interventionKey: 'physio',
              controller: _physiotherapyDetailsController,
              hint: 'Describe exercises or therapy provided...',
              onChanged: (value) {
                setState(() {
                  _physiotherapy = value!;
                });
                _toggleInterventionExpansion('physio', value!);
              },
            ),
            
            _buildExpandableCheckbox(
              label: 'Nutrition/Feeding Support',
              value: _nutritionSupport,
              interventionKey: 'nutrition',
              controller: _nutritionDetailsController,
              hint: 'Describe nutritional support provided...',
              onChanged: (value) {
                setState(() {
                  _nutritionSupport = value!;
                });
                _toggleInterventionExpansion('nutrition', value!);
              },
            ),
            
            _buildExpandableCheckbox(
              label: 'Hygiene/Personal Care',
              value: _hygieneCare,
              interventionKey: 'hygiene',
              controller: _hygieneDetailsController,
              hint: 'Describe hygiene care provided...',
              onChanged: (value) {
                setState(() {
                  _hygieneCare = value!;
                });
                _toggleInterventionExpansion('hygiene', value!);
              },
            ),
            
            _buildExpandableCheckbox(
              label: 'Counseling/Education',
              value: _counseling,
              interventionKey: 'counseling',
              controller: _counselingDetailsController,
              hint: 'Describe counseling or education provided...',
              onChanged: (value) {
                setState(() {
                  _counseling = value!;
                });
                _toggleInterventionExpansion('counseling', value!);
              },
            ),
            
            _buildExpandableCheckbox(
              label: 'Other Interventions',
              value: _otherInterventions,
              interventionKey: 'other',
              controller: _otherInterventionsController,
              hint: 'Describe other interventions...',
              onChanged: (value) {
                setState(() {
                  _otherInterventions = value!;
                });
                _toggleInterventionExpansion('other', value!);
              },
            ),
            const SizedBox(height: 24),
            
            // Observations
            Row(
              children: [
                const Icon(Icons.remove_red_eye, color: Color(0xFF2196F3), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Observations/Findings (Required)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    label: 'General Condition *',
                    value: _generalCondition,
                    items: ['Stable', 'Improving', 'Declining', 'Critical'],
                    onChanged: (value) {
                      setState(() {
                        _generalCondition = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pain Level (0-10) *',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _painLevel.toString(),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            Column(
                              children: [
                                InkWell(
                                  onTap: () {
                                    if (_painLevel < 10) {
                                      setState(() {
                                        _painLevel++;
                                      });
                                    }
                                  },
                                  child: const Icon(
                                    Icons.arrow_drop_up,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    if (_painLevel > 0) {
                                      setState(() {
                                        _painLevel--;
                                      });
                                    }
                                  },
                                  child: const Icon(
                                    Icons.arrow_drop_down,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            _buildTextField(
              label: 'Wound Status (if any)',
              controller: _woundStatusController,
              hint: 'Describe wound status, healing progress, etc...',
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            
            _buildTextField(
              label: 'Other Significant Observations',
              controller: _observationsController,
              hint: 'Note any other significant observations...',
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            
            // Communication
            Row(
              children: [
                const Icon(Icons.people, color: Color(0xFF6C63FF), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Family/Client Communication',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            
            _buildTextField(
              label: 'Education Provided',
              controller: _educationProvidedController,
              hint: 'Describe education provided to patient/family...',
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            
            _buildTextField(
              label: 'Concerns Raised by Family/Client',
              controller: _familyConcernsController,
              hint: 'Note any concerns raised by family or client...',
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            
            // Plan
            Row(
              children: [
                const Icon(Icons.event_note, color: AppColors.primaryGreen, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Plan / Next Steps',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            
            _buildTextField(
              label: 'Plan for Next Visit',
              controller: _nextVisitPlanController,
              hint: 'Outline plans for the next visit, follow-up care, adjustments needed...',
              maxLines: 4,
            ),
            const SizedBox(height: 32),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF666666),
                      side: BorderSide(color: Colors.grey[300]!, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveNote,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                      disabledBackgroundColor: AppColors.primaryGreen.withOpacity(0.5),
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
                            'Save Note',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

  // Helper Widgets
  Widget _buildExpandableCheckbox({
    required String label,
    required bool value,
    required String interventionKey,
    required TextEditingController controller,
    required String hint,
    required void Function(bool?) onChanged,
  }) {
    final isExpanded = _expandedIntervention == interventionKey;
    
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: value ? AppColors.primaryGreen.withOpacity(0.05) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  title: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      color: const Color(0xFF1A1A1A),
                      fontWeight: value ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  value: value,
                  onChanged: onChanged,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: AppColors.primaryGreen,
                  contentPadding: const EdgeInsets.only(left: 0, right: 8),
                ),
              ),
              if (value)
                IconButton(
                  icon: Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.primaryGreen,
                  ),
                  onPressed: () => _toggleExpansionOnly(interventionKey),
                ),
            ],
          ),
        ),
        if (value && isExpanded) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 40, right: 16, bottom: 12),
            child: TextField(
              controller: controller,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 13,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primaryGreen.withOpacity(0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primaryGreen.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primaryGreen,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: 13,
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.primaryGreen,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
      ],
    );
  }

  Widget _buildRequiredNumberField({
    required String label,
    required TextEditingController controller,
    required String hint,
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
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'This field is required';
            }
            return null;
          },
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: 13,
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.primaryGreen,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
      ],
    );
  }

  Widget _buildRequiredTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
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
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'This field is required';
            }
            return null;
          },
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: 13,
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.primaryGreen,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
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
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: const SizedBox(),
            items: items.map((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(item),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}