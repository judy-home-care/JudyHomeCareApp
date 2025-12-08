import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/contact_person/contact_person_service.dart';
import '../../models/care_request/care_request_models.dart';
import '../../models/contact_person/contact_person_models.dart';
import '../../utils/string_utils.dart';
import 'contact_person_care_request_screen.dart';

class ContactPersonCareRequestListsScreen extends StatefulWidget {
  final ContactPersonUser contactPerson;
  final LinkedPatient selectedPatient;

  const ContactPersonCareRequestListsScreen({
    Key? key,
    required this.contactPerson,
    required this.selectedPatient,
  }) : super(key: key);

  @override
  State<ContactPersonCareRequestListsScreen> createState() =>
      _ContactPersonCareRequestListsScreenState();
}

class _ContactPersonCareRequestListsScreenState
    extends State<ContactPersonCareRequestListsScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  final ContactPersonService _contactPersonService = ContactPersonService();
  final ScrollController _scrollController = ScrollController();

  List<CareRequest> _careRequests = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasError = false;
  String _errorMessage = '';

  // Pagination
  int _currentPage = 1;
  int _lastPage = 1;

  // Filters
  String? _selectedStatus;

  // Cache management
  DateTime? _lastFetchTime;
  DateTime? _lastRefreshAttempt;
  static const Duration _cacheValidityDuration = Duration(minutes: 2);
  static const Duration _minRefreshInterval = Duration(seconds: 30);

  // Visibility tracking
  bool _isScreenVisible = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCareRequests();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      _isScreenVisible = true;
      debugPrint('App resumed - checking if care requests refresh needed');
      _loadCareRequests(forceRefresh: true, silent: true);
    } else if (state == AppLifecycleState.paused) {
      _isScreenVisible = false;
      debugPrint('App paused');
    }
  }

  bool get _isCacheExpired {
    if (_lastFetchTime == null || _careRequests.isEmpty) return true;
    final difference = DateTime.now().difference(_lastFetchTime!);
    return difference >= _cacheValidityDuration;
  }

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
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _currentPage < _lastPage) {
        _loadMoreCareRequests();
      }
    }
  }

  Future<void> _loadCareRequests({
    bool refresh = false,
    bool forceRefresh = false,
    bool silent = false,
  }) async {
    // Rate limiting check
    if (!forceRefresh && _lastRefreshAttempt != null) {
      final timeSinceLastAttempt =
          DateTime.now().difference(_lastRefreshAttempt!);
      if (timeSinceLastAttempt < _minRefreshInterval) {
        debugPrint(
            'Rate limited - last attempt ${timeSinceLastAttempt.inSeconds}s ago');
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
    if (!forceRefresh &&
        !refresh &&
        !_isCacheExpired &&
        _careRequests.isNotEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      debugPrint('Using cached care requests ($_cacheAge)');
      return;
    }

    if (refresh) {
      setState(() {
        _currentPage = 1;
        _careRequests.clear();
      });
    }

    if (!silent && mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    _lastRefreshAttempt = DateTime.now();
    debugPrint('Fetching care requests from API...');

    try {
      final data = await _contactPersonService.getCareRequests(
        status: _selectedStatus,
      );

      if (mounted) {
        setState(() {
          _careRequests = data;
          _lastFetchTime = DateTime.now();
          _isLoading = false;
        });

        debugPrint('Care requests loaded ($_cacheAge)');

        if (silent) {
          _showDataUpdatedNotification();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _isLoading = false;
        });
        debugPrint('Care requests load error: $e');
      }
    }
  }

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
              child: Text('Care requests updated'),
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

  Future<void> _loadMoreCareRequests() async {
    if (_isLoadingMore || _currentPage >= _lastPage) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final data = await _contactPersonService.getCareRequests(
        status: _selectedStatus,
      );

      if (mounted) {
        setState(() {
          _careRequests.addAll(data);
          _currentPage++;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load more: $e'),
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
                        'Filter Care Requests',
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
                            ...[
                              'pending_payment',
                              'payment_received',
                              'nurse_assigned',
                              'assessment_scheduled',
                              'assessment_completed',
                              'care_active',
                              'completed',
                              'cancelled'
                            ]
                                .map((status) => DropdownMenuItem<String>(
                                      value: status,
                                      child: Text(_getStatusDisplayText(status)),
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
                              _lastFetchTime = null;
                            });
                            Navigator.pop(context);
                            _loadCareRequests(refresh: true, forceRefresh: true);
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
    return _selectedStatus != null;
  }

  String _getStatusDisplayText(String status) {
    switch (status.toLowerCase()) {
      case 'pending_payment':
        return 'Payment Pending';
      case 'payment_received':
        return 'Payment Received';
      case 'nurse_assigned':
        return 'Nurse Assigned';
      case 'assessment_scheduled':
        return 'Assessment Scheduled';
      case 'assessment_completed':
        return 'Assessment Completed';
      case 'under_review':
        return 'Under Review';
      case 'care_plan_created':
        return 'Care Plan Created';
      case 'awaiting_care_payment':
        return 'Awaiting Care Payment';
      case 'care_payment_received':
        return 'Care Payment Received';
      case 'care_active':
        return 'Care Active';
      case 'completed':
      case 'care_completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'rejected':
        return 'Rejected';
      default:
        return status.replaceAll('_', ' ').split(' ').map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        }).join(' ');
    }
  }

  void _showRequestDetailModal(CareRequest request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
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
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailHeader(request),
                      const SizedBox(height: 24),
                      _buildDetailInfo(request),
                      const SizedBox(height: 24),
                      _buildProgressTracker(request),
                      const SizedBox(height: 24),
                      _buildActionSection(request),
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

  Widget _buildDetailHeader(CareRequest request) {
    final urgencyColor = _getUrgencyColor(request.urgencyLevel);
    final statusColor = _getStatusColor(request.status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: urgencyColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                _getUrgencyIcon(request.urgencyLevel),
                color: urgencyColor,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    StringUtils.formatCareType(request.careType),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getStatusDisplayText(request.status),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
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
            color: const Color(0xFFF8FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                'Created: ${DateFormat('MMM d, yyyy - hh:mm a').format(request.createdAt)}',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailInfo(CareRequest request) {
    String? formattedStartDate;
    if (request.preferredStartDate != null) {
      try {
        final date = DateTime.parse(request.preferredStartDate!);
        formattedStartDate = DateFormat('MMM d, yyyy').format(date);
      } catch (e) {
        formattedStartDate = request.preferredStartDate;
      }
    }

    String? formattedTime;
    if (request.preferredTime != null) {
      formattedTime = request.preferredTime!
          .split('_')
          .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
          .join(' ');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Request Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  _buildCompactInfoRow(Icons.medical_services, 'Care Type',
                      StringUtils.formatCareType(request.careType)),
                  const SizedBox(height: 12),
                  _buildCompactInfoRow(
                      Icons.location_on, 'Service Address', request.serviceAddress),
                  if (request.preferredTime != null) ...[
                    const SizedBox(height: 12),
                    _buildCompactInfoRow(
                        Icons.access_time, 'Preferred Time', formattedTime ?? ''),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                children: [
                  _buildCompactInfoRow(
                      Icons.priority_high,
                      'Urgency',
                      request.urgencyLevel[0].toUpperCase() +
                          request.urgencyLevel.substring(1).toLowerCase()),
                  const SizedBox(height: 12),
                  if (request.preferredStartDate != null)
                    _buildCompactInfoRow(
                        Icons.event, 'Preferred Start', formattedStartDate ?? ''),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
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
                  Icon(Icons.description, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                request.description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        if (request.specialRequirements != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: const Color(0xFFFF9A00).withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 16, color: Color(0xFFFF9A00)),
                    const SizedBox(width: 8),
                    Text(
                      'Special Requirements',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  request.specialRequirements!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCompactInfoRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF199A8E)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressTracker(CareRequest request) {
    final steps = _getProgressSteps(request.status);
    final currentStepIndex = _getCurrentStepIndex(request.status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Request Progress',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 16),
        ...steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          final isCompleted = index < currentStepIndex;
          final isCurrent = index == currentStepIndex;
          final isLast = index == steps.length - 1;

          return _buildProgressStep(
            step['step'],
            step['title'],
            step['description'],
            isCompleted,
            isCurrent,
            isLast,
          );
        }).toList(),
      ],
    );
  }

  List<Map<String, dynamic>> _getProgressSteps(String currentStatus) {
    String step7Title;
    String step7Description;

    if (currentStatus == 'awaiting_care_payment') {
      step7Title = 'Awaiting Care Payment';
      step7Description = 'Payment required for care services';
    } else if (currentStatus == 'care_payment_received' ||
        currentStatus == 'care_active' ||
        currentStatus == 'completed' ||
        currentStatus == 'care_completed') {
      step7Title = 'Care Payment Received';
      step7Description = 'Care service payment completed';
    } else {
      step7Title = 'Awaiting Care Payment';
      step7Description = 'Payment required for care services';
    }

    String step8Title;
    String step8Description;

    if (currentStatus == 'care_active') {
      step8Title = 'Care Active';
      step8Description = 'Receiving home healthcare services';
    } else {
      step8Title = 'Care To Start';
      step8Description = 'Care services will begin soon';
    }

    return [
      {
        'step': 1,
        'title': 'Payment Pending',
        'description': 'Awaiting assessment fee payment',
      },
      {
        'step': 2,
        'title': 'Payment Received',
        'description': 'Payment confirmed, processing request',
      },
      {
        'step': 3,
        'title': 'Nurse Assigned',
        'description': 'Qualified nurse assigned to your case',
      },
      {
        'step': 4,
        'title': 'Assessment Scheduled',
        'description': 'Home assessment appointment scheduled',
      },
      {
        'step': 5,
        'title': 'Assessment Completed',
        'description': 'Nurse completed home assessment',
      },
      {
        'step': 6,
        'title': 'Care Plan Created',
        'description': 'Personalized care plan prepared',
      },
      {
        'step': 7,
        'title': step7Title,
        'description': step7Description,
      },
      {
        'step': 8,
        'title': step8Title,
        'description': step8Description,
      },
      {
        'step': 9,
        'title': 'Care Completed',
        'description': 'Care services successfully completed',
      },
    ];
  }

  int _getCurrentStepIndex(String status) {
    switch (status.toLowerCase()) {
      case 'pending_payment':
        return 0;
      case 'payment_received':
        return 1;
      case 'nurse_assigned':
        return 2;
      case 'assessment_scheduled':
        return 3;
      case 'assessment_completed':
        return 4;
      case 'under_review':
        return 7;
      case 'care_plan_created':
        return 5;
      case 'awaiting_care_payment':
        return 6;
      case 'care_payment_received':
        return 7;
      case 'care_active':
        return 7;
      case 'completed':
      case 'care_completed':
        return 8;
      default:
        return 0;
    }
  }

  Widget _buildProgressStep(
    int step,
    String title,
    String description,
    bool isCompleted,
    bool isCurrent,
    bool isLast,
  ) {
    final stepColor =
        isCompleted || isCurrent ? const Color(0xFF199A8E) : Colors.grey.shade300;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isCompleted || isCurrent
                    ? const Color(0xFF199A8E)
                    : Colors.white,
                border: Border.all(
                  color: stepColor,
                  width: 2,
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 20,
                      )
                    : Text(
                        '$step',
                        style: TextStyle(
                          color: isCurrent ? Colors.white : Colors.grey.shade400,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 50,
                color: isCompleted ? const Color(0xFF199A8E) : Colors.grey.shade300,
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isCompleted || isCurrent
                        ? const Color(0xFF1A1A1A)
                        : Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: isCompleted || isCurrent
                        ? Colors.grey.shade600
                        : Colors.grey.shade400,
                  ),
                ),
                if (isCurrent) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF199A8E).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Current Step',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF199A8E),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionSection(CareRequest request) {
    return Column(
      children: [
        const Divider(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
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
              'Close',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: _lastFetchTime != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${widget.selectedPatient.name}\'s Care Requests',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
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
            : Text(
                '${widget.selectedPatient.name}\'s Care Requests',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
        actions: [
          IconButton(
            icon: _isLoading && !_isCacheExpired
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF199A8E),
                      ),
                    ),
                  )
                : Icon(
                    Icons.refresh,
                    color: _isCacheExpired ? Colors.red : const Color(0xFF199A8E),
                  ),
            onPressed:
                _isLoading ? null : () => _loadCareRequests(forceRefresh: true),
            tooltip: _isCacheExpired ? 'Data expired - Tap to refresh' : 'Refresh',
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
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadCareRequests(refresh: true, forceRefresh: true),
        color: const Color(0xFF199A8E),
        child: _buildBody(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ContactPersonCareRequestScreen(
                contactPerson: widget.contactPerson,
                selectedPatient: widget.selectedPatient,
              ),
            ),
          );

          if (result == true) {
            _loadCareRequests(refresh: true, forceRefresh: true);
          }
        },
        backgroundColor: const Color(0xFF199A8E),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'New Request',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _careRequests.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF199A8E),
        ),
      );
    }

    if (_hasError) {
      return _buildErrorState();
    }

    if (_careRequests.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _careRequests.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _careRequests.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(
                color: Color(0xFF199A8E),
              ),
            ),
          );
        }

        return _buildCareRequestCard(_careRequests[index]);
      },
    );
  }

  Widget _buildCareRequestCard(CareRequest request) {
    final createdDate = request.createdAt;
    final urgencyColor = _getUrgencyColor(request.urgencyLevel);
    final statusColor = _getStatusColor(request.status);
    final isPendingPayment = request.status == 'pending_payment';
    final isAwaitingCarePayment = request.status == 'awaiting_care_payment';
    final needsPayment = isPendingPayment || isAwaitingCarePayment;

    String? scheduledTimeDisplay;
    if (request.assessmentScheduledAt != null) {
      final scheduledDate = request.assessmentScheduledAt!;
      final now = DateTime.now();
      final difference = scheduledDate.difference(now);

      if (difference.inDays == 0) {
        scheduledTimeDisplay =
            'Today at ${DateFormat('h:mm a').format(scheduledDate)}';
      } else if (difference.inDays == 1) {
        scheduledTimeDisplay =
            'Tomorrow at ${DateFormat('h:mm a').format(scheduledDate)}';
      } else if (difference.inDays < 7) {
        scheduledTimeDisplay =
            DateFormat('EEE, MMM d • h:mm a').format(scheduledDate);
      } else {
        scheduledTimeDisplay =
            DateFormat('MMM d, yyyy • h:mm a').format(scheduledDate);
      }
    }

    final showScheduledInfo = request.status == 'nurse_assigned' ||
        request.status == 'assessment_scheduled' ||
        request.status == 'assessment_completed';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: needsPayment
              ? const Color(0xFF2196F3).withOpacity(0.5)
              : Colors.grey[200]!,
          width: needsPayment ? 2 : 1,
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
          onTap: () => _showRequestDetailModal(request),
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
                        color: urgencyColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getUrgencyIcon(request.urgencyLevel),
                        color: urgencyColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            StringUtils.formatCareType(request.careType),
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
                            DateFormat('MMM d, yyyy').format(createdDate),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getStatusDisplayText(request.status),
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
                if (scheduledTimeDisplay != null && showScheduledInfo) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFFF9A00).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9A00).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.schedule,
                            size: 16,
                            color: Color(0xFFFF9A00),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                request.status == 'assessment_completed'
                                    ? 'Assessment Completed'
                                    : 'Assessment Scheduled',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                scheduledTimeDisplay,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFF9A00),
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
                Text(
                  request.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          request.serviceAddress,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (needsPayment) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF2196F3).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Color(0xFF2196F3),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isAwaitingCarePayment
                                ? 'Tap to view care payment details'
                                : 'Tap to view assessment payment details',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (isAwaitingCarePayment && request.carePayment != null)
                          Text(
                            '${request.carePayment!.currency} ${request.carePayment!.totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF199A8E),
                            ),
                          ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward,
                          size: 16,
                          color: Color(0xFF2196F3),
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

  Color _getUrgencyColor(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'routine':
        return const Color(0xFF199A8E);
      case 'urgent':
        return const Color(0xFFFF9A00);
      case 'emergency':
        return const Color(0xFFFF4757);
      default:
        return Colors.grey;
    }
  }

  IconData _getUrgencyIcon(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'routine':
        return Icons.schedule;
      case 'urgent':
        return Icons.warning_amber;
      case 'emergency':
        return Icons.emergency;
      default:
        return Icons.help;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending_payment':
        return const Color(0xFF2196F3);
      case 'payment_received':
        return const Color(0xFF4CAF50);
      case 'nurse_assigned':
        return const Color(0xFF00BCD4);
      case 'assessment_scheduled':
        return const Color(0xFF3F51B5);
      case 'assessment_completed':
      case 'under_review':
        return const Color(0xFF6C63FF);
      case 'awaiting_care_payment':
        return const Color(0xFFFF9A00);
      case 'care_plan_created':
        return const Color(0xFF009688);
      case 'care_active':
        return const Color(0xFF199A8E);
      case 'completed':
      case 'care_completed':
        return const Color(0xFF4CAF50);
      case 'cancelled':
      case 'rejected':
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
            Container(
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
              child: const Icon(
                Icons.medical_services_outlined,
                size: 80,
                color: Color(0xFF199A8E),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'No Care Requests Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Tap the button below to create your first care request for ${widget.selectedPatient.name}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                  height: 1.6,
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
              onPressed: () => _loadCareRequests(refresh: true, forceRefresh: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF199A8E),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
