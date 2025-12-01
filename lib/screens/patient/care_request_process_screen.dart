import 'package:flutter/material.dart';
import '../../services/care_request_service.dart';
import '../../utils/app_colors.dart';
import '../../models/care_request/care_request_models.dart';
import '../payment/care_payment_screen.dart';  // Import the actual payment screen

class CareRequestProcessScreen extends StatefulWidget {
  final Map<String, dynamic> patientData;
  final Map<String, dynamic> requestData;

  const CareRequestProcessScreen({
    Key? key,
    required this.patientData,
    required this.requestData,
  }) : super(key: key);

  @override
  State<CareRequestProcessScreen> createState() => _CareRequestProcessScreenState();
}

class _CareRequestProcessScreenState extends State<CareRequestProcessScreen> {
  final _careRequestService = CareRequestService();
  
  bool _isLoading = true;
  Map<String, dynamic>? _processInfo;
  String? _errorMessage;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadProcessInfo();
  }

  Future<void> _loadProcessInfo() async {
    try {
      final response = await _careRequestService.getRequestInfo(
        id: widget.requestData['id'],
        careType: widget.requestData['care_type'],
        region: widget.requestData['region'],
      );

      if (response.success && response.data != null) {
        final feeData = response.data!.assessmentFee;
        
        setState(() {
          _processInfo = {
            'assessment_fee': {
              'amount': feeData.amount,
              'currency': feeData.currency,
              'tax': feeData.tax,
              'total': feeData.total,
              'description': response.data!.description ?? 'Initial home assessment fee',
            },
            'process_steps': [
              {
                'step': 1,
                'title': 'Pay Assessment Fee',
                'description': 'Complete payment to begin the process',
                'icon': 'payment',
              },
              {
                'step': 2,
                'title': 'Nurse Assignment',
                'description': 'We\'ll assign a qualified nurse to your case',
                'icon': 'assignment',
              },
              {
                'step': 3,
                'title': 'Home Assessment',
                'description': 'Nurse visits for comprehensive evaluation',
                'icon': 'assessment',
              },
              {
                'step': 4,
                'title': 'Care Plan & Quote',
                'description': 'Receive personalized care plan and pricing',
                'icon': 'plan',
              },
              {
                'step': 5,
                'title': 'Begin Care',
                'description': 'Start receiving home healthcare services',
                'icon': 'care',
              },
            ],
          };
          _isLoading = false;
        });
      } else {
        throw Exception(response.message);
      }
    } catch (e) {
      print('💥 [CareRequestProcessScreen] Error in _loadProcessInfo: $e');
      setState(() {
        _errorMessage = 'Failed to load process information: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _submitRequest() async {
    setState(() => _isSubmitting = true);

    try {
      final response = await _careRequestService.createCareRequest(
        CreateCareRequestRequest(
          careType: widget.requestData['care_type'],
          urgencyLevel: widget.requestData['urgency_level'],
          description: widget.requestData['description'],
          specialRequirements: widget.requestData['special_requirements'],
          serviceAddress: widget.requestData['service_address'],
          city: widget.requestData['city'],
          region: widget.requestData['region'],
          preferredStartDate: widget.requestData['preferred_start_date'],
          preferredTime: widget.requestData['preferred_time'],
        ),
      );

      if (mounted && response.success && response.data != null) {
        setState(() => _isSubmitting = false);

        final careRequest = response.data!;
        final assessmentFee = _processInfo?['assessment_fee']?['total'] ?? 0.0;

        print('✅ [ProcessScreen] Care request created: ${careRequest.id}');
        print('💰 [ProcessScreen] Assessment fee: GHS $assessmentFee');

        // Navigate to payment screen and wait for result
        final paymentResult = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CarePaymentScreen(
              careRequest: careRequest,
              assessmentFee: assessmentFee,
            ),
          ),
        );

        // If payment was successful, navigate back to list screen
        if (mounted && paymentResult == true) {
          // Pop the process screen with true result
          Navigator.of(context).pop(true);
          // This returns to CareRequestScreen, which will then pop with true
          // triggering refresh in CareRequestListsScreen
        }
      } else {
        setState(() => _isSubmitting = false);
        _showError(response.message);
      }
    } catch (e) {
      print('💥 [ProcessScreen] Error submitting request: $e');
      setState(() => _isSubmitting = false);
      _showError('Failed to submit request: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Request Process',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF199A8E)))
          : _errorMessage != null
              ? _buildErrorState()
              : _buildContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadProcessInfo,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF199A8E),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final assessmentFee = _processInfo!['assessment_fee'];
    final processSteps = _processInfo!['process_steps'] as List;

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildAssessmentFeeCard(assessmentFee),
          const SizedBox(height: 24),
          _buildProcessSteps(processSteps),
          const SizedBox(height: 24),
          _buildImportantNotes(),
          const SizedBox(height: 24),
          _buildActionButtons(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildAssessmentFeeCard(Map<String, dynamic> fee) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF199A8E),
            const Color(0xFF199A8E).withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF199A8E).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assessment Fee',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'One-time payment to begin',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Base Fee',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${fee['currency']} ${fee['amount'].toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (fee['tax'] > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tax',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${fee['currency']} ${fee['tax'].toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Amount',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    Text(
                      '${fee['currency']} ${fee['total'].toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF199A8E),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fee['description'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
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

  Widget _buildProcessSteps(List steps) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What Happens Next',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 16),
          ...steps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            final isLast = index == steps.length - 1;

            return _buildStepItem(
              step['step'],
              step['title'],
              step['description'],
              step['icon'],
              isLast,
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildStepItem(int step, String title, String description, String icon, bool isLast) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: step == 1 ? const Color(0xFF199A8E) : Colors.white,
                border: Border.all(
                  color: const Color(0xFF199A8E),
                  width: 2,
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$step',
                  style: TextStyle(
                    color: step == 1 ? Colors.white : const Color(0xFF199A8E),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 60,
                color: Colors.grey.shade300,
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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImportantNotes() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF9A00).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9A00).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.lightbulb_outline,
                  color: Color(0xFFFF9A00),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Important Notes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildNoteItem('The assessment fee is non-refundable once a nurse has been assigned'),
          _buildNoteItem('Care costs will be determined after the home assessment'),
          _buildNoteItem('You\'ll be notified at each stage of the process'),
          _buildNoteItem('Payment for care services must be completed before care begins'),
        ],
      ),
    );
  }

  Widget _buildNoteItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle,
            size: 16,
            color: Color(0xFFFF9A00),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF199A8E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Proceed to Payment',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Go Back',
              style: TextStyle(
                color: Color(0xFF199A8E),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}