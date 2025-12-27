import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/care_request/care_request_models.dart';
import '../../../services/care_request_service.dart';
import '../../../services/contact_person/contact_person_service.dart';
import '../../../utils/string_utils.dart';
import 'installment_section.dart';

/// A care request card with tabs for Details and Payment
class TabbedCareRequestCard extends StatefulWidget {
  final CareRequest request;
  final VoidCallback onTap;
  final VoidCallback onPaymentComplete;
  final bool isContactPerson;

  const TabbedCareRequestCard({
    Key? key,
    required this.request,
    required this.onTap,
    required this.onPaymentComplete,
    this.isContactPerson = false,
  }) : super(key: key);

  @override
  State<TabbedCareRequestCard> createState() => _TabbedCareRequestCardState();
}

class _TabbedCareRequestCardState extends State<TabbedCareRequestCard> {
  final CareRequestService _careRequestService = CareRequestService();
  final ContactPersonService _contactPersonService = ContactPersonService();
  int _selectedTabIndex = 0; // 0 = Details, 1 = Payment

  // Installment summary data
  bool _isLoadingInstallments = true;
  InstallmentsData? _installmentsData;

  bool get _hasInstallmentPayments {
    if (widget.isContactPerson) {
      return _contactPersonService.hasInstallmentPayments(widget.request);
    }
    return _careRequestService.hasInstallmentPayments(widget.request);
  }

  @override
  void initState() {
    super.initState();
    _loadInstallmentsSummary();
  }

  Future<void> _loadInstallmentsSummary() async {
    if (!_hasInstallmentPayments) {
      setState(() => _isLoadingInstallments = false);
      return;
    }

    try {
      InstallmentsResponse response;
      if (widget.isContactPerson) {
        response = await _contactPersonService.getInstallments(widget.request.id);
      } else {
        response = await _careRequestService.getInstallments(widget.request.id);
      }

      if (mounted) {
        setState(() {
          _isLoadingInstallments = false;
          if (response.success && response.data != null) {
            _installmentsData = response.data;
            // Debug logging for summary values
            final summary = response.data!.summary;
            if (summary != null) {
              print('📊 [TabbedCard] Summary - totalAmount: ${summary.totalAmount}');
              print('📊 [TabbedCard] Summary - paidAmount: ${summary.paidAmount}');
              print('📊 [TabbedCard] Summary - remainingAmount: ${summary.remainingAmount}');
              print('📊 [TabbedCard] Summary - totalCareCost: ${summary.totalCareCost}');
              print('📊 [TabbedCard] Summary - totalPaid: ${summary.totalPaid}');
              print('📊 [TabbedCard] Summary - totalRemaining: ${summary.totalRemaining}');
              print('📊 [TabbedCard] Summary - progressPercentage: ${summary.paymentProgressPercentage}');
            } else {
              print('📊 [TabbedCard] Summary is null');
            }
          }
        });
      }
    } catch (e) {
      print('💥 [TabbedCard] Error loading installments: $e');
      if (mounted) {
        setState(() => _isLoadingInstallments = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final createdDate = request.createdAt;
    final statusColor = _getStatusColor(request.status);
    final urgencyColor = _getUrgencyColor(request.urgencyLevel);

    final needsPayment = request.status == 'pending_payment' ||
        request.status == 'awaiting_care_payment';
    final isAwaitingCarePayment = request.status == 'awaiting_care_payment';
    final hasInstallments = _hasInstallmentPayments;

    // Show payment tab only if there's payment info to show
    final showPaymentTab = needsPayment || hasInstallments;

    // Scheduled time display
    String? scheduledTimeDisplay;
    final showScheduledInfo = request.status == 'nurse_assigned' ||
        request.status == 'assessment_scheduled' ||
        request.status == 'assessment_completed';

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header - Always visible, tappable to open details
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
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
              ),
            ),
          ),

          // Tab Bar - Only show if there's payment info
          if (showPaymentTab) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTabButton(
                      index: 0,
                      label: 'Details',
                      icon: Icons.info_outline,
                    ),
                  ),
                  Expanded(
                    child: _buildTabButton(
                      index: 1,
                      label: 'Payment',
                      icon: Icons.payment_outlined,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Tab Content
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _selectedTabIndex == 0 || !showPaymentTab
                ? _buildDetailsTab(
                    request: request,
                    scheduledTimeDisplay: scheduledTimeDisplay,
                    showScheduledInfo: showScheduledInfo,
                  )
                : _buildPaymentTab(
                    request: request,
                    needsPayment: needsPayment,
                    isAwaitingCarePayment: isAwaitingCarePayment,
                    hasInstallments: hasInstallments,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required int index,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedTabIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTabIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? const Color(0xFF199A8E)
                  : Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF199A8E)
                    : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsTab({
    required CareRequest request,
    required String? scheduledTimeDisplay,
    required bool showScheduledInfo,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Scheduled Assessment Display
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

        // Description
        Text(
          request.description,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
            height: 1.4,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),

        const SizedBox(height: 12),

        // Address
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentTab({
    required CareRequest request,
    required bool needsPayment,
    required bool isAwaitingCarePayment,
    required bool hasInstallments,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Payment Summary Card
        if (hasInstallments) ...[
          _buildPaymentSummaryCard(),
          const SizedBox(height: 12),
        ],

        // Payment action for pending payment status
        if (needsPayment) ...[
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap, // Open detail modal to make payment
              borderRadius: BorderRadius.circular(10),
              child: Container(
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
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2196F3).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.payment,
                        size: 20,
                        color: Color(0xFF2196F3),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAwaitingCarePayment
                                ? 'Care Service Payment'
                                : 'Assessment Fee',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isAwaitingCarePayment
                                ? 'Tap to pay for care services'
                                : 'Tap to complete assessment payment',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isAwaitingCarePayment && request.carePayment != null)
                      Text(
                        '${request.carePayment!.currency} ${request.carePayment!.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF199A8E),
                        ),
                      ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: Color(0xFF2196F3),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (hasInstallments) const SizedBox(height: 4),
        ],

        // Installments section
        if (hasInstallments)
          InstallmentSection(
            careRequest: request,
            isContactPerson: widget.isContactPerson,
            onPaymentComplete: () {
              // Reload this card's summary first
              _loadInstallmentsSummary();
              // Then notify parent to refresh
              widget.onPaymentComplete();
            },
          ),

        // No payment info message
        if (!needsPayment && !hasInstallments)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 20,
                  color: Colors.grey[500],
                ),
                const SizedBox(width: 12),
                Text(
                  'No pending payments',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPaymentSummaryCard() {
    if (_isLoadingInstallments) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF199A8E),
            ),
          ),
        ),
      );
    }

    final summary = _installmentsData?.summary;
    if (summary == null) {
      // Calculate from installments if no summary
      double total = 0;
      double paid = 0;
      String currency = 'GHS';

      if (_installmentsData != null) {
        for (var i in _installmentsData!.installments) {
          total += i.amount;
          currency = i.currency;
        }
        for (var i in _installmentsData!.completedPayments) {
          total += i.amount;
          paid += i.amount;
          currency = i.currency;
        }
      }

      if (total == 0) {
        return const SizedBox.shrink();
      }

      // Get next due date from next payable installment
      final nextDueDate = _installmentsData?.nextPayableInstallment?.dueDateFormatted;
      final isOverdue = _installmentsData?.nextPayableInstallment?.isOverdue ?? false;

      return _buildSummaryContent(
        total: total,
        paid: paid,
        pending: total - paid,
        currency: currency,
        progressPercentage: null,
        nextDueDate: nextDueDate,
        isOverdue: isOverdue,
      );
    }

    // Use new API fields if available (they are nullable), otherwise fall back to existing fields
    // New fields are preferred because old fields default to 0.0 when API doesn't send them
    final total = (summary.totalCareCost != null && summary.totalCareCost! > 0)
        ? summary.totalCareCost!
        : summary.totalAmount;
    final paid = (summary.totalPaid != null)
        ? summary.totalPaid!
        : summary.paidAmount;
    final pending = (summary.totalRemaining != null)
        ? summary.totalRemaining!
        : summary.remainingAmount;
    final progressPercent = summary.paymentProgressPercentage;

    // Get next due date from summary or next payable installment
    final nextDueDate = summary.nextPaymentDue ??
        _installmentsData?.nextPayableInstallment?.dueDateFormatted;
    final isOverdue = _installmentsData?.nextPayableInstallment?.isOverdue ??
        (summary.overdueCount > 0);

    return _buildSummaryContent(
      total: total,
      paid: paid,
      pending: pending,
      currency: summary.currency,
      progressPercentage: progressPercent,
      nextDueDate: nextDueDate,
      isOverdue: isOverdue,
    );
  }

  Widget _buildSummaryContent({
    required double total,
    required double paid,
    required double pending,
    required String currency,
    double? progressPercentage,
    String? nextDueDate,
    bool isOverdue = false,
  }) {
    // Use API progress percentage if available, otherwise calculate it
    final calculatedProgress = progressPercentage != null
        ? progressPercentage / 100 // API returns percentage (e.g., 25), we need fraction (e.g., 0.25)
        : (total > 0 ? (paid / total) : 0.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF199A8E).withOpacity(0.1),
            const Color(0xFF199A8E).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF199A8E).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF199A8E).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 16,
                  color: Color(0xFF199A8E),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Care Payment Summary',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Total Amount
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Amount',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                '$currency ${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: calculatedProgress,
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF199A8E)),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 10),

          // Paid and Pending
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF199A8E),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Paid',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$currency ${paid.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF199A8E),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Pending',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$currency ${pending.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: pending > 0 ? const Color(0xFFFF9A00) : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Next Payment Due Date
          if (nextDueDate != null && pending > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isOverdue
                    ? const Color(0xFFFF4757).withOpacity(0.1)
                    : const Color(0xFFFF9A00).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isOverdue
                      ? const Color(0xFFFF4757).withOpacity(0.3)
                      : const Color(0xFFFF9A00).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isOverdue ? Icons.warning_amber : Icons.schedule,
                    size: 16,
                    color: isOverdue ? const Color(0xFFFF4757) : const Color(0xFFFF9A00),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isOverdue ? 'Payment Overdue' : 'Next Payment Due',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isOverdue ? const Color(0xFFFF4757) : const Color(0xFFFF9A00),
                      ),
                    ),
                  ),
                  Text(
                    nextDueDate,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isOverdue ? const Color(0xFFFF4757) : const Color(0xFFFF9A00),
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
        return const Color(0xFF9C27B0);
      case 'assessment_scheduled':
        return const Color(0xFFFF9A00);
      case 'assessment_completed':
        return const Color(0xFF00BCD4);
      case 'awaiting_care_payment':
        return const Color(0xFF2196F3);
      case 'care_payment_received':
        return const Color(0xFF4CAF50);
      case 'care_active':
        return const Color(0xFF199A8E);
      case 'care_completed':
        return const Color(0xFF607D8B);
      case 'cancelled':
        return const Color(0xFFFF4757);
      default:
        return Colors.grey;
    }
  }
}
