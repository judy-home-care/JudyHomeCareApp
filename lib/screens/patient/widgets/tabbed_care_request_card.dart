import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/care_request/care_request_models.dart';
import '../../../models/payment/payment_models.dart';
import '../../../services/care_request_service.dart';
import '../../../services/contact_person/contact_person_service.dart';
import '../../../services/file_download_service.dart';
import '../../../services/payment_service.dart';
import '../../../utils/api_config.dart';
import '../../../utils/string_utils.dart';
import 'installment_section.dart';

/// A care request card with tabs for Details and Payment
class TabbedCareRequestCard extends StatefulWidget {
  final CareRequest request;
  final VoidCallback onTap;
  final VoidCallback onPaymentComplete;
  final bool isContactPerson;
  /// Patient ID for contact person paying on behalf of patient
  final int? patientId;

  const TabbedCareRequestCard({
    Key? key,
    required this.request,
    required this.onTap,
    required this.onPaymentComplete,
    this.isContactPerson = false,
    this.patientId,
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

  /// Get count of pending installments that need payment
  int _getPendingInstallmentsCount() {
    if (_installmentsData == null) return 0;

    // Count pending or overdue installments
    return _installmentsData!.installments.where((i) {
      final status = i.status.toLowerCase();
      return status == 'pending' || status == 'overdue';
    }).length;
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
                      badgeCount: (needsPayment ? 1 : 0) + _getPendingInstallmentsCount(),
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
    int badgeCount = 0,
  }) {
    final isSelected = _selectedTabIndex == index;
    final showBadge = badgeCount > 0 && !isSelected;

    Widget buttonContent = Container(
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
          // Icon with optional badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? const Color(0xFF199A8E)
                    : Colors.grey[600],
              ),
              // Badge with count
              if (showBadge)
                Positioned(
                  top: -8,
                  right: -10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    constraints: const BoxConstraints(minWidth: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4757),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFF5F5F5),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      '$badgeCount',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
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
    );

    // Wrap with tooltip if there are pending payments
    if (showBadge) {
      buttonContent = Tooltip(
        message: badgeCount == 1
            ? 'Tap to pay'
            : 'Tap to pay ($badgeCount pending)',
        preferBelow: false,
        child: buttonContent,
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTabIndex = index;
        });
      },
      child: buttonContent,
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
        ],

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

    // Show installment plan info when first payment is not completed
    if (_installmentsData != null && !_installmentsData!.firstPaymentCompleted) {
      return _buildInstallmentPlanPending();
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

    return GestureDetector(
      onTap: () => _showAllInstallmentsModal(context),
      child: Container(
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

          // View Installments button
          const SizedBox(height: 12),
          InkWell(
            onTap: () => _showAllInstallmentsModal(context),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF199A8E).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF199A8E).withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.view_list,
                    size: 16,
                    color: Color(0xFF199A8E),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'View All Installments',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF199A8E),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: Color(0xFF199A8E),
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

  Widget _buildInstallmentPlanPending() {
    // Calculate total from installments
    double total = 0;
    String currency = 'GHS';

    if (_installmentsData != null) {
      for (var i in _installmentsData!.installments) {
        total += i.amount;
        currency = i.currency;
      }
      for (var i in _installmentsData!.completedPayments) {
        total += i.amount;
      }
    }

    final formattedTotal = '$currency ${total.toStringAsFixed(2)}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF9A00).withOpacity(0.1),
            const Color(0xFFFF9A00).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFF9A00).withOpacity(0.3),
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
                  color: const Color(0xFFFF9A00).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.payments_outlined,
                  size: 16,
                  color: Color(0xFFFF9A00),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Installment Plan Available',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9A00),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Pending',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Total Amount
          if (total > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Care Payment',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  formattedTotal,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Info message
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.orange[700],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Complete initial payment to activate installment plan',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange[800],
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

  void _showAllInstallmentsModal(BuildContext context) {
    if (_installmentsData == null) return;

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
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
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
                      'All Installments',
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
              // Completed payments header
              if (_installmentsData!.completedPayments.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Color(0xFF199A8E),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Completed Payments',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              // List
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // Completed payments
                    ..._installmentsData!.completedPayments.map((installment) =>
                      _buildCompletedInstallmentItem(installment)),

                    // Pending payments
                    ...(() {
                      final actualPendingItems = _installmentsData!.installments
                          .where((installment) => !installment.isPaid)
                          .toList();

                      return [
                        if (_installmentsData!.completedPayments.isNotEmpty &&
                            actualPendingItems.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Icon(
                                Icons.pending_outlined,
                                size: 16,
                                color: Color(0xFFFF9A00),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Pending Payments',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],

                        // Pending items
                        ...actualPendingItems.map((installment) => _buildPendingInstallmentItem(installment)),
                      ];
                    })(),

                    // Refunded payments
                    if (_installmentsData!.refundedPayments.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            Icons.refresh,
                            size: 16,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Refunded',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ..._installmentsData!.refundedPayments.map((installment) =>
                        _buildRefundedInstallmentItem(installment)),
                    ],

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletedInstallmentItem(Installment installment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF199A8E).withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF199A8E).withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFF199A8E),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      installment.label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    if (installment.paidAt != null)
                      Text(
                        'Paid on ${_formatDate(installment.paidAt!)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                installment.formattedAmount,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF199A8E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const SizedBox(width: 44), // Align with text above
              Expanded(
                child: Row(
                  children: [
                    _buildReceiptButton(
                      icon: Icons.visibility_outlined,
                      label: 'Preview',
                      onTap: () {
                        Navigator.pop(context);
                        _previewReceipt(installment);
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildReceiptButton(
                      icon: Icons.download_outlined,
                      label: 'Download',
                      onTap: () {
                        Navigator.pop(context);
                        _downloadReceipt(installment);
                      },
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

  Widget _buildReceiptButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF199A8E).withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: const Color(0xFF199A8E).withOpacity(0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF199A8E)),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF199A8E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _previewReceipt(Installment installment) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Text('Loading receipt...'),
          ],
        ),
        backgroundColor: const Color(0xFF199A8E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 10),
      ),
    );

    try {
      final paymentService = PaymentService();
      final response = await paymentService.getInstallmentReceipt(
        careRequestId: widget.request.id,
        paymentId: installment.id,
        isContactPerson: widget.isContactPerson,
        patientId: widget.patientId,
      );

      scaffoldMessenger.clearSnackBars();

      if (!mounted) return;

      if (response.success && response.data != null) {
        _showReceiptPreviewModal(response.data!);
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(response.message.isNotEmpty
                ? response.message
                : 'Failed to load receipt'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      scaffoldMessenger.clearSnackBars();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error loading receipt: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showReceiptPreviewModal(PaymentReceipt receipt) {
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
                    'Payment Receipt',
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
            // Receipt content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // Receipt header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF199A8E).withOpacity(0.1),
                            const Color(0xFF199A8E).withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Color(0xFF199A8E),
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Payment Successful',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF199A8E),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${receipt.currency} ${receipt.totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Receipt details
                    _buildReceiptDetailRow('Receipt No.', receipt.receiptNumber),
                    _buildReceiptDetailRow('Reference', receipt.referenceNumber),
                    _buildReceiptDetailRow('Date', DateFormat('MMM d, yyyy • h:mm a').format(receipt.paymentDate)),
                    _buildReceiptDetailRow('Patient', receipt.patientName),
                    _buildReceiptDetailRow('Payment Type', receipt.paymentType),
                    _buildReceiptDetailRow('Payment Method', receipt.paymentMethod),
                    const Divider(height: 24),
                    _buildReceiptDetailRow('Amount', '${receipt.currency} ${receipt.amount.toStringAsFixed(2)}'),
                    if (receipt.taxAmount > 0)
                      _buildReceiptDetailRow('Tax', '${receipt.currency} ${receipt.taxAmount.toStringAsFixed(2)}'),
                    _buildReceiptDetailRow(
                      'Total',
                      '${receipt.currency} ${receipt.totalAmount.toStringAsFixed(2)}',
                      isBold: true,
                    ),
                    if (receipt.description != null && receipt.description!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildReceiptDetailRow('Description', receipt.description!),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptDetailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: const Color(0xFF1A1A1A),
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  void _downloadReceipt(Installment installment) async {
    _downloadReceiptFile(installment.id);
  }

  void _downloadReceiptFile(int paymentId) async {
    String endpoint;
    if (widget.isContactPerson && widget.patientId != null) {
      endpoint = ApiConfig.contactPersonInstallmentReceiptDownloadEndpoint(
          widget.patientId!, widget.request.id, paymentId);
    } else {
      endpoint = ApiConfig.installmentReceiptDownloadEndpoint(
          widget.request.id, paymentId);
    }

    final fileName = 'installment_receipt_${widget.request.id}_$paymentId.pdf';
    final downloader = FileDownloadService();
    await downloader.downloadAndShare(
      endpoint,
      fileName: fileName,
      context: context,
    );
  }

  Widget _buildRefundedInstallmentItem(Installment installment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.refresh,
              size: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  installment.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                Text(
                  'Refunded',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          Text(
            installment.formattedAmount,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[500],
              decoration: TextDecoration.lineThrough,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingInstallmentItem(Installment installment) {
    final isOverdue = installment.isOverdue;
    // Check if this is the next payable installment
    final canPay = _installmentsData?.nextPayableInstallment?.id == installment.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canPay
              ? () {
                  Navigator.pop(context); // Close bottom sheet
                  _showPaymentSheet(context, installment);
                }
              : null,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isOverdue
                  ? Colors.red.withOpacity(0.05)
                  : Colors.grey.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isOverdue
                    ? Colors.red.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isOverdue
                        ? Colors.red.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${installment.installmentNumber}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isOverdue ? Colors.red : Colors.grey[600],
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
                        installment.label,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      Row(
                        children: [
                          if (installment.dueDateFormatted != null) ...[
                            Text(
                              'Due: ${installment.dueDateFormatted}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isOverdue ? Colors.red : Colors.grey[600],
                              ),
                            ),
                          ],
                          if (isOverdue) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                installment.dueStatusLabel ?? 'OVERDUE',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ] else if (installment.isDueToday) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF9A00),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                installment.dueStatusLabel ?? 'Due Today',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ] else if (installment.isDueSoon) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF9A00),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                installment.dueStatusLabel ?? 'Due Soon',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      installment.formattedAmount,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isOverdue ? Colors.red : Colors.grey[800],
                      ),
                    ),
                    if (canPay)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isOverdue ? Colors.red : const Color(0xFF199A8E),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Pay Now',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
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

  void _showPaymentSheet(BuildContext context, Installment installment) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => InstallmentPaymentSheet(
        careRequestId: widget.request.id,
        installment: installment,
        isContactPerson: widget.isContactPerson,
        patientId: widget.patientId,
      ),
    );

    // If payment was successful, refresh the data
    if (result == true) {
      _loadInstallmentsSummary();
      widget.onPaymentComplete();
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
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
