import 'package:flutter/material.dart';
import '../../../models/care_request/care_request_models.dart';
import '../../../services/care_request_service.dart';
import '../../../services/contact_person/contact_person_service.dart';
import '../../../services/payment_service.dart';
import '../../payment/care_payment_screen.dart';

/// Widget to display installment payment information on care request cards
class InstallmentSection extends StatefulWidget {
  final CareRequest careRequest;
  final VoidCallback? onPaymentComplete;
  final bool isContactPerson;

  const InstallmentSection({
    Key? key,
    required this.careRequest,
    this.onPaymentComplete,
    this.isContactPerson = false,
  }) : super(key: key);

  @override
  State<InstallmentSection> createState() => _InstallmentSectionState();
}

class _InstallmentSectionState extends State<InstallmentSection> {
  final CareRequestService _careRequestService = CareRequestService();
  final ContactPersonService _contactPersonService = ContactPersonService();

  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  InstallmentsData? _installmentsData;
  bool _isExpanded = false;
  int? _nextPayableInstallmentId;

  @override
  void initState() {
    super.initState();
    _loadInstallments();
  }

  Future<void> _loadInstallments() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      InstallmentsResponse response;
      if (widget.isContactPerson) {
        response = await _contactPersonService.getInstallments(widget.careRequest.id);
      } else {
        response = await _careRequestService.getInstallments(widget.careRequest.id);
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (response.success && response.data != null) {
            _installmentsData = response.data;
            // Determine the next payable installment (only ONE can be paid at a time)
            _nextPayableInstallmentId = response.data!.nextPayableInstallment?.id;
          } else {
            _hasError = true;
            _errorMessage = response.message;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_hasError) {
      return _buildErrorState();
    }

    if (_installmentsData == null || !_installmentsData!.hasInstallments) {
      return const SizedBox.shrink();
    }

    if (!_installmentsData!.firstPaymentCompleted) {
      return _buildFirstPaymentPending();
    }

    return _buildInstallmentsList();
  }

  /// Build the total amount card widget (reusable)
  Widget _buildTotalAmountCard(InstallmentSummary summary) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 18,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 8),
              Text(
                'Total Care Payment',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          Text(
            summary.formattedTotalCareCost,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Loading installments...',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: Colors.red[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Unable to load installments',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red[700],
              ),
            ),
          ),
          InkWell(
            onTap: _loadInstallments,
            child: Icon(Icons.refresh, size: 16, color: Colors.red[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildFirstPaymentPending() {
    final summary = _installmentsData?.summary;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF9A00).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9A00).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.payments_outlined,
                  size: 18,
                  color: Color(0xFFFF9A00),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Payment Installments',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
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
          ),
          // Total amount if available
          if (summary != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: _buildTotalAmountCard(summary),
            ),
          // Info message
          Container(
            margin: EdgeInsets.only(
              left: 12,
              right: 12,
              bottom: 12,
              top: summary == null ? 12 : 0,
            ),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(10),
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
                    Icons.info_outline,
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
                        'Installment Plan Available',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Complete initial payment to see installment details',
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
        ],
      ),
    );
  }

  Widget _buildInstallmentsList() {
    final data = _installmentsData!;
    final summary = data.summary;
    final pendingInstallments = data.installments;
    // Use API-provided hasOverdue from summary, fallback to checking installments
    final hasOverdue = summary?.hasOverdue ?? data.overdueInstallments.isNotEmpty;

    // Calculate total from installments if summary is not available
    double calculatedTotal = 0;
    double calculatedPaid = 0;
    String currency = 'GHS';

    if (summary == null) {
      // Sum up all pending installments
      for (var installment in pendingInstallments) {
        calculatedTotal += installment.amount;
        currency = installment.currency;
      }
      // Sum up all completed payments
      for (var payment in data.completedPayments) {
        calculatedTotal += payment.amount;
        calculatedPaid += payment.amount;
      }
    }

    // Get next due installment for collapsed view (only ONE can be paid at a time)
    Installment? nextDueInstallment;
    if (pendingInstallments.isNotEmpty && _nextPayableInstallmentId != null) {
      // Get the specific installment that is next payable
      try {
        nextDueInstallment = pendingInstallments.firstWhere(
          (i) => i.id == _nextPayableInstallmentId,
        );
      } catch (e) {
        // If not found, show the first pending installment (but won't be payable)
        nextDueInstallment = pendingInstallments.first;
      }
    } else if (pendingInstallments.isNotEmpty) {
      nextDueInstallment = pendingInstallments.first;
    }

    // Determine if the next installment can be paid
    final canPayNextInstallment = nextDueInstallment != null &&
        nextDueInstallment.id == _nextPayableInstallmentId &&
        nextDueInstallment.canPay;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasOverdue
              ? Colors.red.withOpacity(0.5)
              : const Color(0xFF199A8E).withOpacity(0.3),
          width: hasOverdue ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header - Tappable to expand/collapse
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(11),
              topRight: Radius.circular(11),
            ),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hasOverdue
                    ? Colors.red.withOpacity(0.1)
                    : const Color(0xFF199A8E).withOpacity(0.1),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(11),
                  topRight: const Radius.circular(11),
                  bottomLeft: Radius.circular(_isExpanded ? 0 : 11),
                  bottomRight: Radius.circular(_isExpanded ? 0 : 11),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.payments_outlined,
                    size: 18,
                    color: hasOverdue ? Colors.red : const Color(0xFF199A8E),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Payment Installments',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: hasOverdue ? Colors.red[800] : const Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  if (summary != null || data.hasInstallments)
                    Builder(
                      builder: (context) {
                        // Calculate paid/total from data if summary fields are 0
                        final paidCount = (summary?.paidInstallments ?? 0) > 0
                            ? summary!.paidInstallments
                            : data.completedPayments.length;
                        final totalCount = (summary?.totalInstallments ?? 0) > 0
                            ? summary!.totalInstallments
                            : data.installments.length + data.completedPayments.length;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: hasOverdue
                                ? Colors.red
                                : const Color(0xFF199A8E),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$paidCount/$totalCount',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      size: 20,
                      color: hasOverdue ? Colors.red : const Color(0xFF199A8E),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Collapsed view - show summary with next payment
          if (!_isExpanded) ...[
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Total amount - compact display
                  if (summary != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          summary.formattedTotalCareCost,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: summary.progressPercentage / 100,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          hasOverdue ? Colors.red : const Color(0xFF199A8E),
                        ),
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Paid: ${summary.formattedTotalPaid}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF199A8E),
                          ),
                        ),
                        Text(
                          'Remaining: ${summary.formattedTotalRemaining}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: hasOverdue ? Colors.red : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ] else if (calculatedTotal > 0) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          '$currency ${calculatedTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ],
                    ),
                  ],
                  // Next due installment
                  if (nextDueInstallment != null) ...[
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: canPayNextInstallment
                          ? () => _showPaymentSheet(context, nextDueInstallment!)
                          : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: nextDueInstallment.isOverdue
                              ? Colors.red.withOpacity(0.05)
                              : const Color(0xFF199A8E).withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: nextDueInstallment.isOverdue
                                ? Colors.red.withOpacity(0.2)
                                : const Color(0xFF199A8E).withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: nextDueInstallment.isOverdue
                                    ? Colors.red.withOpacity(0.1)
                                    : const Color(0xFF199A8E).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${nextDueInstallment.installmentNumber}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: nextDueInstallment.isOverdue
                                        ? Colors.red
                                        : const Color(0xFF199A8E),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Next Due: ',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          nextDueInstallment.label,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1A1A1A),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (nextDueInstallment.dueDateFormatted != null)
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today_outlined,
                                          size: 10,
                                          color: nextDueInstallment.isOverdue
                                              ? Colors.red
                                              : Colors.grey[500],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          nextDueInstallment.dueDateFormatted!,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: nextDueInstallment.isOverdue
                                                ? Colors.red
                                                : Colors.grey[600],
                                          ),
                                        ),
                                        if (nextDueInstallment.isOverdue) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              borderRadius: BorderRadius.circular(3),
                                            ),
                                            child: Text(
                                              nextDueInstallment.dueStatusLabel ?? 'OVERDUE',
                                              style: const TextStyle(
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ] else if (nextDueInstallment.isDueToday) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFF9A00),
                                              borderRadius: BorderRadius.circular(3),
                                            ),
                                            child: Text(
                                              nextDueInstallment.dueStatusLabel ?? 'DUE TODAY',
                                              style: const TextStyle(
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ] else if (nextDueInstallment.isDueSoon) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFF9A00),
                                              borderRadius: BorderRadius.circular(3),
                                            ),
                                            child: Text(
                                              nextDueInstallment.dueStatusLabel ?? 'DUE SOON',
                                              style: const TextStyle(
                                                fontSize: 8,
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
                                  nextDueInstallment.formattedAmount,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: nextDueInstallment.isOverdue
                                        ? Colors.red
                                        : const Color(0xFF199A8E),
                                  ),
                                ),
                                if (canPayNextInstallment)
                                  Container(
                                    margin: const EdgeInsets.only(top: 2),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: nextDueInstallment.isOverdue
                                          ? Colors.red
                                          : const Color(0xFF199A8E),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Pay Now',
                                      style: TextStyle(
                                        fontSize: 9,
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
                  ],
                  // Tap to expand hint
                  if (pendingInstallments.length > 1) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Tap to view all ${pendingInstallments.length} installments',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Expanded view - full details
          if (_isExpanded) ...[
            // Summary - show calculated total if summary is null
            if (summary == null && calculatedTotal > 0) ...[
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    // Total amount - calculated from installments
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.account_balance_wallet_outlined,
                                size: 18,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Total Care Payment',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '$currency ${calculatedTotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (calculatedPaid > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Paid: $currency ${calculatedPaid.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF199A8E),
                            ),
                          ),
                          Text(
                            'Remaining: $currency ${(calculatedTotal - calculatedPaid).toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: hasOverdue ? Colors.red : Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1),
            ],

            // Summary with full details
            if (summary != null) ...[
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    // Total amount - prominent display
                    _buildTotalAmountCard(summary),
                    const SizedBox(height: 12),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: summary.progressPercentage / 100,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          hasOverdue ? Colors.red : const Color(0xFF199A8E),
                        ),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Amount summary - Paid and Remaining
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Paid',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              summary.formattedTotalPaid,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF199A8E),
                              ),
                            ),
                          ],
                        ),
                        Builder(
                          builder: (context) {
                            // Calculate paid/total from data if summary fields are 0
                            final paidCount = summary.paidInstallments > 0
                                ? summary.paidInstallments
                                : data.completedPayments.length;
                            final totalCount = summary.totalInstallments > 0
                                ? summary.totalInstallments
                                : data.installments.length + data.completedPayments.length;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  'of $totalCount',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  '$paidCount paid',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Remaining',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              summary.formattedTotalRemaining,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: hasOverdue ? Colors.red : Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (hasOverdue) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              size: 14,
                              color: Colors.red,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${summary.overdueCount} overdue payment${summary.overdueCount > 1 ? 's' : ''}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1),
            ],

            // Pending installments list
            if (pendingInstallments.isNotEmpty) ...[
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: pendingInstallments.length > 3
                    ? 3
                    : pendingInstallments.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final installment = pendingInstallments[index];
                  return _buildInstallmentItem(installment);
                },
              ),
              if (pendingInstallments.length > 3) ...[
                const Divider(height: 1),
                InkWell(
                  onTap: () => _showAllInstallments(context),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'View all ${pendingInstallments.length} installments',
                          style: const TextStyle(
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
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildInstallmentItem(Installment installment) {
    final isOverdue = installment.isOverdue;
    // Only allow payment for the next payable installment (by date order)
    final isNextPayable = installment.id == _nextPayableInstallmentId;
    final canPay = isNextPayable && installment.canPay;

    return InkWell(
      onTap: canPay
          ? () => _showPaymentSheet(context, installment)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Status indicator
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isOverdue
                    ? Colors.red.withOpacity(0.1)
                    : canPay
                        ? const Color(0xFF199A8E).withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${installment.installmentNumber}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isOverdue
                        ? Colors.red
                        : canPay
                            ? const Color(0xFF199A8E)
                            : Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          installment.label,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ),
                      Text(
                        installment.formattedAmount,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isOverdue
                              ? Colors.red
                              : const Color(0xFF199A8E),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (installment.dueDateFormatted != null) ...[
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 11,
                          color: isOverdue ? Colors.red : Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          installment.dueDateFormatted!,
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
            if (canPay) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isOverdue ? Colors.red : const Color(0xFF199A8E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Pay Now',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showAllInstallments(BuildContext context) {
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
              // Completed payments
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
                    // Completed
                    ..._installmentsData!.completedPayments.map((installment) =>
                      _buildCompletedInstallmentItem(installment)),

                    if (_installmentsData!.completedPayments.isNotEmpty &&
                        _installmentsData!.installments.isNotEmpty) ...[
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

                    // Pending
                    ..._installmentsData!.installments.map((installment) =>
                      _buildPendingInstallmentItem(installment)),

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
      child: Row(
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
    );
  }

  Widget _buildPendingInstallmentItem(Installment installment) {
    final isOverdue = installment.isOverdue;
    // Only allow payment for the next payable installment (by date order)
    final isNextPayable = installment.id == _nextPayableInstallmentId;
    final canPay = isNextPayable && installment.canPay;

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
        careRequestId: widget.careRequest.id,
        installment: installment,
        isContactPerson: widget.isContactPerson,
      ),
    );

    // If payment was successful (result == true), refresh the data
    if (result == true) {
      _loadInstallments();
      widget.onPaymentComplete?.call();
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

/// Bottom sheet for making installment payment
class InstallmentPaymentSheet extends StatefulWidget {
  final int careRequestId;
  final Installment installment;
  final bool isContactPerson;

  const InstallmentPaymentSheet({
    Key? key,
    required this.careRequestId,
    required this.installment,
    this.isContactPerson = false,
  }) : super(key: key);

  @override
  State<InstallmentPaymentSheet> createState() => _InstallmentPaymentSheetState();
}

class _InstallmentPaymentSheetState extends State<InstallmentPaymentSheet> {
  final CareRequestService _careRequestService = CareRequestService();
  final ContactPersonService _contactPersonService = ContactPersonService();
  final PaymentService _paymentService = PaymentService();

  bool _isProcessing = false;

  Future<void> _initiatePayment() async {
    setState(() => _isProcessing = true);

    try {
      // Use mobile_money as default channel without phone - this triggers Paystack checkout
      InstallmentPaymentResponse response;
      if (widget.isContactPerson) {
        response = await _contactPersonService.initiateInstallmentPayment(
          requestId: widget.careRequestId,
          paymentId: widget.installment.id,
          paymentMethod: 'mobile_money',
        );
      } else {
        response = await _careRequestService.payInstallment(
          requestId: widget.careRequestId,
          paymentId: widget.installment.id,
          channel: 'mobile_money',
        );
      }

      if (!mounted) return;

      if (response.success && response.data != null) {
        final paymentUrl = response.data!.paymentUrl;
        final reference = response.data!.reference;

        // Debug logging
        print('🔗 [InstallmentPayment] Payment URL: $paymentUrl');
        print('📝 [InstallmentPayment] Reference: $reference');

        if (paymentUrl.isEmpty) {
          setState(() => _isProcessing = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Payment URL is empty. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        setState(() => _isProcessing = false);

        // Navigate to webview for payment - keep bottom sheet open (like CarePaymentScreen)
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => PaystackPaymentWebView(
              authorizationUrl: paymentUrl,
              reference: reference,
            ),
            fullscreenDialog: true,
          ),
        );

        if (!mounted) return;

        if (result == true) {
          // Verify payment on backend
          setState(() => _isProcessing = true);
          print('🔄 [InstallmentPayment] Verifying payment with reference: $reference');

          final verifyResponse = await _paymentService.verifyPayment(reference);

          if (!mounted) return;
          setState(() => _isProcessing = false);

          if (verifyResponse.success) {
            print('✅ [InstallmentPayment] Payment verified successfully!');
            // Payment verified successfully - show success dialog
            _showSuccessDialog();
          } else {
            print('❌ [InstallmentPayment] Verification failed: ${verifyResponse.message}');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Payment verification failed: ${verifyResponse.message}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          // Payment was cancelled or failed - show cancel dialog like CarePaymentScreen
          _showCancelDialog();
        }
      } else {
        setState(() => _isProcessing = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Show cancellation dialog - allows retry (same as CarePaymentScreen)
  void _showCancelDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cancel_outlined,
                color: Colors.orange.shade700,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Payment Cancelled',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your payment was cancelled. You can try again or go back.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop(); // Close dialog
                      Navigator.of(context).pop(); // Close bottom sheet
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey.shade400),
                    ),
                    child: Text(
                      'Go Back',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop(); // Close dialog only
                      // Stay on bottom sheet - user can retry
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF199A8E),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Try Again',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
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
  }

  /// Show success dialog (same pattern as CarePaymentScreen)
  void _showSuccessDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF199A8E),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Payment Successful!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${widget.installment.label} has been paid successfully. Your payment has been received.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF199A8E).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.installment.formattedAmount,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF199A8E),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(); // Close dialog
                  Navigator.of(context).pop(true); // Close bottom sheet with success result
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF199A8E),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
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
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF199A8E).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.payment,
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
                        'Pay Installment',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      Text(
                        widget.installment.label,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Amount
          Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFB),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    'Amount to Pay',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.installment.formattedAmount,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF199A8E),
                    ),
                  ),
                  if (widget.installment.isOverdue) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            size: 16,
                            color: Colors.red,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'This payment is overdue',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (widget.installment.dueDateFormatted != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Due: ${widget.installment.dueDateFormatted}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Payment info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You\'ll be redirected to complete payment securely via Paystack.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Pay button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _initiatePayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.installment.isOverdue
                      ? Colors.red
                      : const Color(0xFF199A8E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock_outline, size: 20, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            'Pay ${widget.installment.formattedAmount}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
