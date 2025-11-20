import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/app_colors.dart';

class NurseFAQScreen extends StatefulWidget {
  const NurseFAQScreen({Key? key}) : super(key: key);

  @override
  State<NurseFAQScreen> createState() => _NurseFAQScreenState();
}

class _NurseFAQScreenState extends State<NurseFAQScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'all';
  Set<String> _expandedFAQs = {};
  
  final List<Map<String, dynamic>> _faqCategories = [
    {
      'id': 'all',
      'name': 'All',
      'icon': Icons.grid_view_rounded,
      'color': Colors.grey.shade700,
    },
    {
      'id': 'general',
      'name': 'General',
      'icon': Icons.info_outline,
      'color': const Color(0xFF2196F3),
    },
    {
      'id': 'scheduling',
      'name': 'Scheduling',
      'icon': Icons.calendar_today_outlined,
      'color': const Color(0xFF9C27B0),
    },
    {
      'id': 'payments',
      'name': 'Payments',
      'icon': Icons.payments_outlined,
      'color': const Color(0xFFFF9800),
    },
    {
      'id': 'careplans',
      'name': 'Care Plans',
      'icon': Icons.medical_services_outlined,
      'color': AppColors.primaryGreen,
    },
    {
      'id': 'safety',
      'name': 'Safety',
      'icon': Icons.shield_outlined,
      'color': const Color(0xFFE91E63),
    },
  ];

  final List<Map<String, dynamic>> _faqs = [
    // General FAQs
    {
      'id': '1',
      'category': 'general',
      'question': 'How do I update my profile information?',
      'answer': 'To update your profile:\n\n1. Tap the menu icon in the top left\n2. Select "Profile Settings"\n3. Edit your information (name, phone, email, etc.)\n4. Tap "Save Changes"\n\nNote: Some information like license number may require admin verification.',
    },
    {
      'id': '2',
      'category': 'general',
      'question': 'What should I do if I forgot my password?',
      'answer': 'If you forgot your password:\n\n1. On the login screen, tap "Forgot Password?"\n2. Enter your registered email address\n3. Check your email for a reset link\n4. Follow the link to create a new password\n5. Use your new password to log in\n\nIf you don\'t receive the email within 5 minutes, check your spam folder or contact support.',
    },
    {
      'id': '3',
      'category': 'general',
      'question': 'How do I contact support?',
      'answer': 'You can contact our support team through:\n\n• In-app Chat: Tap the help icon and select "Live Chat"\n• Email: support@judyhomecare.com\n• Phone: +233 (0) 123 456 789 (Mon-Fri, 8AM-6PM)\n• Emergency Hotline: +233 (0) 987 654 321 (24/7)\n\nResponse times: Chat (5-10 mins), Email (24 hours), Phone (immediate)',
    },
    {
      'id': '4',
      'category': 'general',
      'question': 'Can I use the app offline?',
      'answer': 'Limited offline functionality is available:\n\n✓ View previously loaded patient information\n✓ Review care plans downloaded earlier\n✓ Access your schedule (if synced)\n\n✗ Cannot clock in/out\n✗ Cannot update vitals or notes\n✗ Cannot view new assignments\n\nAll actions taken offline will sync automatically when you reconnect to the internet.',
    },
    
    // Scheduling FAQs
    {
      'id': '5',
      'category': 'scheduling',
      'question': 'How do I view my shift schedule?',
      'answer': 'To view your schedule:\n\n1. Open the app and go to "Schedule" from the main menu\n2. You\'ll see your shifts in calendar and list view\n3. Tap on any shift to see details (patient, location, time)\n4. Use the filter to view by day, week, or month\n\nYou\'ll receive notifications 24 hours and 1 hour before each shift.',
    },
    {
      'id': '6',
      'category': 'scheduling',
      'question': 'Can I request time off through the app?',
      'answer': 'Yes! To request time off:\n\n1. Go to "Schedule" → "Time Off Request"\n2. Select the dates you need off\n3. Choose the reason (vacation, sick leave, personal, etc.)\n4. Add any notes if needed\n5. Submit the request\n\nYour manager will review and approve/deny within 48 hours. You\'ll receive a notification with their decision.',
    },
    {
      'id': '7',
      'category': 'scheduling',
      'question': 'What if I need to swap shifts with another nurse?',
      'answer': 'To swap shifts:\n\n1. Go to "Schedule" → "Shift Swap"\n2. Select the shift you want to swap\n3. Browse available nurses or request a specific nurse\n4. The other nurse must accept the swap\n5. Your manager must approve the final swap\n\nBoth parties will be notified of approvals. Shift swaps must be requested at least 48 hours in advance.',
    },
    {
      'id': '8',
      'category': 'scheduling',
      'question': 'How do I clock in and out of my shifts?',
      'answer': 'Clocking in/out is simple:\n\n1. Arrive at the patient\'s location\n2. Open the app and tap "Clock In"\n3. The app will verify your location\n4. Confirm the patient and start your shift\n\nWhen finished:\n1. Tap "Clock Out"\n2. Add any final notes\n3. Submit your time\n\nImportant: You must be within 100 meters of the patient\'s address to clock in/out.',
    },
    
    // Payments FAQs
    {
      'id': '9',
      'category': 'payments',
      'question': 'When and how will I get paid?',
      'answer': 'Payment schedule:\n\n• Frequency: Bi-weekly (every 2 weeks)\n• Payment Day: Every other Friday\n• Method: Direct deposit to your registered bank account\n• Timesheet Period: Monday to Sunday\n\nPayment includes:\n- Regular hours\n- Overtime (1.5x after 40 hours/week)\n- Weekend differential (+15%)\n- Night shift differential (+20%)',
    },
    {
      'id': '10',
      'category': 'payments',
      'question': 'How can I view my payment history and payslips?',
      'answer': 'To access payment information:\n\n1. Go to "Menu" → "Payments & Earnings"\n2. View your current pay period earnings\n3. Tap "Payment History" to see past payments\n4. Tap any payment to download the payslip PDF\n\nYou can also:\n• View hours worked breakdown\n• Track overtime hours\n• See deductions and taxes\n• Export reports for tax purposes',
    },
    {
      'id': '11',
      'category': 'payments',
      'question': 'What happens if there\'s an error in my payment?',
      'answer': 'If you notice a payment error:\n\n1. Document the issue (screenshots of your hours vs payment)\n2. Go to "Payments" → "Report Issue"\n3. Select the affected pay period\n4. Describe the discrepancy\n5. Attach supporting documents\n6. Submit the report\n\nOur payroll team will:\n• Review within 24-48 hours\n• Contact you for clarification if needed\n• Process corrections in the next pay cycle\n• Issue immediate payment for significant errors',
    },
    
    // Care Plans FAQs
    {
      'id': '12',
      'category': 'careplans',
      'question': 'How do I access patient care plans?',
      'answer': 'To view care plans:\n\n1. Go to "My Patients" from the main menu\n2. Select the patient\n3. Tap "Care Plan" tab\n4. Review all prescribed care activities, medications, and special instructions\n\nCare plans include:\n• Medical history and diagnoses\n• Prescribed medications and schedules\n• Daily care activities and routines\n• Emergency contacts and procedures\n• Dietary restrictions and preferences',
    },
    {
      'id': '13',
      'category': 'careplans',
      'question': 'How do I record patient vitals?',
      'answer': 'Recording vitals:\n\n1. Select your patient\n2. Tap "Record Vitals"\n3. Enter readings for:\n   - Blood Pressure\n   - Heart Rate\n   - Temperature\n   - Oxygen Saturation (SpO2)\n   - Blood Glucose (if diabetic)\n   - Pain Level (1-10 scale)\n4. Add notes if readings are abnormal\n5. Submit\n\nThe system will alert you if any reading is outside normal range. Critical readings trigger immediate doctor notification.',
    },
    {
      'id': '14',
      'category': 'careplans',
      'question': 'What should I do if a patient refuses care?',
      'answer': 'If a patient refuses care:\n\n1. Remain calm and respectful\n2. Try to understand their concerns\n3. Explain the importance of the care activity\n4. Document the refusal in the app:\n   • Go to "Daily Notes"\n   • Select "Care Refusal"\n   • Note what was refused and why\n   • Document your attempts to encourage compliance\n5. Notify the care coordinator immediately\n6. Follow up according to care plan protocols\n\nNever force care on an unwilling patient. Patient autonomy must be respected.',
    },
    {
      'id': '15',
      'category': 'careplans',
      'question': 'How do I report medication administration?',
      'answer': 'To document medication administration:\n\n1. Go to patient profile → "Medications"\n2. Find the scheduled medication\n3. Tap "Administer"\n4. Scan medication barcode (if available)\n5. Confirm:\n   - Correct medication\n   - Correct dosage\n   - Correct time\n   - Correct route\n6. Add notes if patient had any reaction\n7. Submit\n\nIf patient refuses medication or you notice any issues, document and report immediately.',
    },
    
    // Safety FAQs
    {
      'id': '16',
      'category': 'safety',
      'question': 'What are the infection control protocols?',
      'answer': 'Standard infection control measures:\n\n1. Hand Hygiene:\n   • Wash hands before and after patient contact\n   • Use hand sanitizer (60%+ alcohol)\n   • Wash for at least 20 seconds\n\n2. PPE Requirements:\n   • Gloves for body fluid contact\n   • Mask for respiratory symptoms\n   • Gown for splash risk\n   • Eye protection when needed\n\n3. Equipment:\n   • Clean and disinfect between patients\n   • Use single-use items when possible\n   • Properly dispose of sharps\n\nReport any exposure incidents immediately through the app.',
    },
    {
      'id': '17',
      'category': 'safety',
      'question': 'How do I report a safety incident or emergency?',
      'answer': 'For emergencies:\n\n1. Life-threatening: Call 911 immediately\n2. After calling 911, use in-app "Emergency Alert":\n   • Tap the red emergency button\n   • Select incident type\n   • Your location is automatically shared\n   • Management is notified instantly\n\nFor non-emergency incidents:\n1. Go to "Reports" → "Incident Report"\n2. Select incident type (fall, medication error, injury, etc.)\n3. Provide details and circumstances\n4. Attach photos if safe and appropriate\n5. Submit within 24 hours of incident\n\nAll incidents are reviewed by quality assurance within 48 hours.',
    },
    {
      'id': '18',
      'category': 'safety',
      'question': 'What if I feel unsafe at a patient\'s home?',
      'answer': 'Your safety is our priority. If you feel unsafe:\n\nImmediate danger:\n1. Leave the premises immediately\n2. Call emergency services if needed\n3. Contact your supervisor\n4. Use the app\'s "Safety Alert" feature\n\nConcerns about safety:\n1. Document specific concerns in the app\n2. Request a safety assessment\n3. Ask for another nurse to accompany you\n4. Request reassignment if needed\n\nWe support:\n• Pair visits for high-risk situations\n• Safety training and de-escalation techniques\n• 24/7 support hotline\n• Zero-tolerance policy for violence or harassment',
    },
    {
      'id': '19',
      'category': 'safety',
      'question': 'What PPE should I use and when?',
      'answer': 'PPE requirements by situation:\n\nStandard Precautions (all patients):\n• Gloves for contact with body fluids\n• Hand hygiene before and after\n\nContact Precautions:\n• Gloves + Gown for MRSA, C.diff, wounds\n\nDroplet Precautions:\n• Mask + Gloves for flu, COVID-19\n\nAirborne Precautions:\n• N95 mask + Gloves + Gown for TB\n\nPPE is provided by the agency. Request supplies through "Inventory" → "Request PPE". Emergency supplies available 24/7.',
    },
    {
      'id': '20',
      'category': 'safety',
      'question': 'How do I handle patient falls?',
      'answer': 'If a patient falls:\n\n1. Stay calm and assess the situation\n2. Do NOT move the patient immediately\n3. Check for:\n   • Responsiveness\n   • Injuries (bleeding, deformity, pain)\n   • Vital signs\n4. If serious injury suspected, call 911\n5. If no serious injury:\n   • Help patient to sitting position slowly\n   • Monitor for 15 minutes\n   • Assist to standing only if stable\n6. Document in app:\n   • Circumstances of fall\n   • Patient condition\n   • Interventions taken\n7. Complete incident report\n8. Notify doctor and family\n\nPrevent falls by following care plan fall prevention strategies.',
    },
  ];

  List<Map<String, dynamic>> get filteredFAQs {
    return _faqs.where((faq) {
      final matchesCategory = _selectedCategory == 'all' || faq['category'] == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          faq['question'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
          faq['answer'].toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  /// Make a phone call to the given phone number
  Future<void> _makePhoneCall(String phoneNumber) async {
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

  /// Open email client
  Future<void> _openEmail(String email) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=Support Request - Judy Home Care',
    );

    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        if (mounted) {
          _showErrorSnackBar('Unable to open email client');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error opening email: $e');
      }
      debugPrint('Error launching email client: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Help & FAQs',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.grey.shade200,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
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
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search for answers...',
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
                            setState(() {
                              _searchQuery = '';
                            });
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
          ),

          // Category Filters
          Container(
            color: Colors.white,
            height: 60,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              itemCount: _faqCategories.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = _faqCategories[index];
                final isSelected = _selectedCategory == category['id'];
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory = category['id'];
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? category['color'].withOpacity(0.1)
                          : Colors.transparent,
                      border: Border.all(
                        color: isSelected 
                            ? category['color']
                            : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          category['icon'],
                          size: 18,
                          color: isSelected 
                              ? category['color']
                              : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          category['name'],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSelected 
                                ? category['color']
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Divider
          Container(
            height: 8,
            color: Colors.grey.shade100,
          ),

          // FAQ List
          Expanded(
            child: filteredFAQs.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                    itemCount: filteredFAQs.length,
                    itemBuilder: (context, index) {
                      return _buildFAQCard(filteredFAQs[index], index);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showContactSupport(),
        backgroundColor: AppColors.primaryGreen,
        elevation: 4,
        icon: const Icon(Icons.support_agent, color: Colors.white),
        label: const Text(
          'Contact Support',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off,
                size: 60,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No results found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or filter',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQCard(Map<String, dynamic> faq, int index) {
    final isExpanded = _expandedFAQs.contains(faq['id']);
    final category = _faqCategories.firstWhere(
      (cat) => cat['id'] == faq['category'],
      orElse: () => _faqCategories[1],
    );

    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 300 + (index * 50)),
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
              _expandedFAQs.remove(faq['id']);
            } else {
              _expandedFAQs.add(faq['id']);
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isExpanded 
                  ? category['color'].withOpacity(0.3)
                  : Colors.grey.shade200,
              width: isExpanded ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: category['color'].withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        category['icon'],
                        size: 20,
                        color: category['color'],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        faq['question'],
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      duration: const Duration(milliseconds: 300),
                      turns: isExpanded ? 0.5 : 0,
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.grey.shade600,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
              
              if (isExpanded) ...[
                Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.grey.shade200,
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    faq['answer'],
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showContactSupport() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
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
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.support_agent,
                size: 40,
                color: AppColors.primaryGreen,
              ),
            ),
            
            const SizedBox(height: 16),
            
            const Text(
              'Contact Support',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              'Choose how you\'d like to reach us',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // COMMENTED OUT: Live Chat
            // _buildContactOption(
            //   icon: Icons.chat_bubble_outline,
            //   title: 'Live Chat',
            //   subtitle: 'Response in 5-10 minutes',
            //   color: const Color(0xFF2196F3),
            //   onTap: () {
            //     Navigator.pop(context);
            //     ScaffoldMessenger.of(context).showSnackBar(
            //       const SnackBar(
            //         content: Text('Opening live chat...'),
            //         backgroundColor: AppColors.primaryGreen,
            //       ),
            //     );
            //   },
            // ),
            // const SizedBox(height: 12),
            
            _buildContactOption(
              icon: Icons.email_outlined,
              title: 'Email Support',
              subtitle: 'support@judyhomecare.com',
              color: const Color(0xFF9C27B0),
              onTap: () {
                Navigator.pop(context);
                _openEmail('support@judyhomecare.com');
              },
            ),
            
            const SizedBox(height: 12),
            
            _buildContactOption(
              icon: Icons.phone_outlined,
              title: 'Call Support',
              subtitle: '+233 543-413-513',
              color: AppColors.primaryGreen,
              onTap: () {
                Navigator.pop(context);
                _makePhoneCall('+233123456789');
              },
            ),
            
            // COMMENTED OUT: Emergency Hotline
            // const SizedBox(height: 12),
            // _buildContactOption(
            //   icon: Icons.emergency_outlined,
            //   title: 'Emergency Hotline',
            //   subtitle: '+233 (0) 987 654 321 (24/7)',
            //   color: const Color(0xFFFF5722),
            //   onTap: () {
            //     Navigator.pop(context);
            //     _makePhoneCall('+233987654321');
            //   },
            // ),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildContactOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}