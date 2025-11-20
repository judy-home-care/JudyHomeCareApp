import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/care_request_service.dart';
import '../../models/care_request/care_request_models.dart';
import '../../utils/string_utils.dart';
import 'nurse_medical_assessment_screen.dart';

class NurseCareRequestsListScreen extends StatefulWidget {
  final Map<String, dynamic> nurseData;

  const NurseCareRequestsListScreen({
    Key? key,
    required this.nurseData,
  }) : super(key: key);

  @override
  State<NurseCareRequestsListScreen> createState() => _NurseCareRequestsListScreenState();
}

class _NurseCareRequestsListScreenState extends State<NurseCareRequestsListScreen> {
  final CareRequestService _careRequestService = CareRequestService();
  final ScrollController _scrollController = ScrollController();

  List<CareRequest> _careRequests = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasError = false;
  String _errorMessage = '';
  
  int _currentPage = 1;
  int _lastPage = 1;

  @override
  void initState() {
    super.initState();
    _loadCareRequests();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _currentPage < _lastPage) {
        _loadMoreCareRequests();
      }
    }
  }

  Future<void> _loadCareRequests({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _careRequests.clear();
      });
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final response = await _careRequestService.getAssignedCareRequests(
        page: _currentPage,
        perPage: 15,
      );

      if (mounted) {
        setState(() {
          _careRequests = response.data;
          _currentPage = response.pagination?.currentPage ?? 1;
          _lastPage = response.pagination?.lastPage ?? 1;
          _isLoading = false;
        });
      }
    } on CareRequestException catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.message;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreCareRequests() async {
    if (_isLoadingMore || _currentPage >= _lastPage) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final response = await _careRequestService.getAssignedCareRequests(
        page: _currentPage + 1,
        perPage: 15,
      );

      if (mounted) {
        setState(() {
          _careRequests.addAll(response.data);
          _currentPage = response.pagination?.currentPage ?? _currentPage;
          _lastPage = response.pagination?.lastPage ?? _lastPage;
          _isLoadingMore = false;
        });
      }
    } on CareRequestException catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
        _showErrorSnackbar('Failed to load more: ${e.message}');
      }
    }
  }

  Future<void> _handleRequestTap(CareRequest request) async {
    // Determine action based on status
    if (request.status == 'nurse_assigned' || request.status == 'assessment_scheduled') {
      _navigateToAssessment(request);
    } else {
      _showRequestDetails(request);
    }
  }

  Future<void> _navigateToAssessment(CareRequest request) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF199A8E),
          ),
        ),
      );

      final detailResponse = await _careRequestService.getCareRequestById(request.id);
      
      if (!mounted) return;
      
      Navigator.pop(context);
      
      if (detailResponse.success && detailResponse.data != null) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NurseMedicalAssessmentScreen(
              nurseData: widget.nurseData,
              careRequest: detailResponse.data,
            ),
          ),
        );
        
        if (result == true) {
          _loadCareRequests(refresh: true);
        }
      } else {
        _showErrorSnackbar('Failed to load care request details');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showErrorSnackbar('Error loading care request: $e');
      }
    }
  }

  void _showRequestDetails(CareRequest request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Care Request Details',
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
                    const SizedBox(height: 20),
                    _buildDetailRow('Request ID', '#${request.id}'),
                    _buildDetailRow('Patient ID', '#${request.patientId}'),
                    _buildDetailRow('Care Type', StringUtils.formatCareType(request.careType)),
                    _buildDetailRow('Status', _careRequestService.getStatusDisplayText(request.status)),
                    _buildDetailRow('Urgency', request.urgencyLevel.toUpperCase()),
                    _buildDetailRow('Location', '${request.city ?? ''}, ${request.region ?? ''}'),
                    _buildDetailRow('Created', DateFormat('MMM d, yyyy • h:mm a').format(request.createdAt)),
                    if (request.assessmentScheduledAt != null)
                      _buildDetailRow(
                        'Assessment Scheduled',
                        DateFormat('MMM d, yyyy • h:mm a').format(request.assessmentScheduledAt!),
                      ),
                    if (request.assessmentCompletedAt != null)
                      _buildDetailRow(
                        'Assessment Completed',
                        DateFormat('MMM d, yyyy • h:mm a').format(request.assessmentCompletedAt!),
                      ),
                    const SizedBox(height: 12),
                    const Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'My Care Requests',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF199A8E)),
            onPressed: () => _loadCareRequests(refresh: true),
          ),
        ],
      ),
      body: _buildBody(),
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

    return RefreshIndicator(
      onRefresh: () => _loadCareRequests(refresh: true),
      color: const Color(0xFF199A8E),
      child: ListView.builder(
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
      ),
    );
  }

  Widget _buildCareRequestCard(CareRequest request) {
    final urgencyColor = _getUrgencyColor(request.urgencyLevel);
    final statusColor = _getStatusColor(request.status);
    
    String? scheduledTimeDisplay;
    if (request.assessmentScheduledAt != null) {
      final scheduledDate = request.assessmentScheduledAt!;
      final now = DateTime.now();
      final difference = scheduledDate.difference(now);
      
      if (difference.inDays == 0) {
        scheduledTimeDisplay = 'Today at ${DateFormat('h:mm a').format(scheduledDate)}';
      } else if (difference.inDays == 1) {
        scheduledTimeDisplay = 'Tomorrow at ${DateFormat('h:mm a').format(scheduledDate)}';
      } else if (difference.inDays < 7) {
        scheduledTimeDisplay = DateFormat('EEE, MMM d • h:mm a').format(scheduledDate);
      } else {
        scheduledTimeDisplay = DateFormat('MMM d, yyyy • h:mm a').format(scheduledDate);
      }
    }

    final needsAssessment = request.status == 'nurse_assigned' || request.status == 'assessment_scheduled';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF199A8E).withOpacity(0.3),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleRequestTap(request),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFF199A8E).withOpacity(0.2),
                                      const Color(0xFF199A8E).withOpacity(0.1),
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Text(
                                    'P',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF199A8E),
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
                                      'Request #${request.id}',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1A1A1A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      StringUtils.formatCareType(request.careType),
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
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
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _careRequestService.getStatusDisplayText(request.status),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                if (scheduledTimeDisplay != null && needsAssessment) ...[
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
                                'Assessment Scheduled',
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
                
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: urgencyColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: urgencyColor.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getUrgencyIcon(request.urgencyLevel),
                            size: 14,
                            color: urgencyColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            request.urgencyLevel.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: urgencyColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Created ${DateFormat('MMM d').format(request.createdAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
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
                      Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${request.city ?? ''}, ${request.region ?? ''}',
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
                
                const SizedBox(height: 12),
                
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF199A8E).withOpacity(0.1),
                        const Color(0xFF199A8E).withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF199A8E).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        needsAssessment ? Icons.assignment_outlined : Icons.visibility_outlined,
                        size: 16,
                        color: const Color(0xFF199A8E),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          needsAssessment ? 'Tap to start assessment' : 'Tap to view details',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF199A8E),
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward,
                        size: 16,
                        color: Color(0xFF199A8E),
                      ),
                    ],
                  ),
                ),
              ],
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
                Icons.assignment_outlined,
                size: 80,
                color: Color(0xFF199A8E),
              ),
            ),
            
            const SizedBox(height: 32),
            
            const Text(
              'No Care Requests',
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
                'You don\'t have any care requests assigned to you at the moment',
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
              onPressed: () => _loadCareRequests(refresh: true),
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
      case 'nurse_assigned':
        return const Color(0xFF00BCD4);
      case 'assessment_scheduled':
        return const Color(0xFF3F51B5);
      case 'assessment_completed':
        return const Color(0xFF9C27B0);
      case 'awaiting_care_payment':
        return const Color(0xFFFF9800);
      case 'care_payment_received':
        return const Color(0xFF4CAF50);
      case 'care_plan_created':
        return const Color(0xFF2196F3);
      case 'care_active':
        return const Color(0xFF199A8E);
      case 'care_completed':
        return const Color(0xFF4CAF50);
      default:
        return Colors.grey;
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFFF4757),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}