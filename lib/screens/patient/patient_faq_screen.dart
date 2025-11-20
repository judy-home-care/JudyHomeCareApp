import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/app_colors.dart';

class PatientFAQScreen extends StatefulWidget {
  const PatientFAQScreen({Key? key}) : super(key: key);

  @override
  State<PatientFAQScreen> createState() => _PatientFAQScreenState();
}

class _PatientFAQScreenState extends State<PatientFAQScreen> {
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
      'id': 'care',
      'name': 'Care',
      'icon': Icons.favorite_outline,
      'color': AppColors.primaryGreen,
    },
    {
      'id': 'transport',
      'name': 'Transport',
      'icon': Icons.local_shipping_outlined,
      'color': const Color(0xFF4CAF50),
    },
    {
      'id': 'emergency',
      'name': 'Emergency',
      'icon': Icons.emergency_outlined,
      'color': const Color(0xFFFF5722),
    },
  ];

  final List<Map<String, dynamic>> _faqs = [
    {
      'id': '1',
      'category': 'care',
      'question': 'How do I schedule a home care visit?',
      'answer': 'You can schedule a visit through the app by contacting your assigned nurse or calling our support team.',
    },
    {
      'id': '2',
      'category': 'transport',
      'question': 'How do I request transportation?',
      'answer': 'Go to "My Transport Requests" in your account settings to request transportation for medical appointments.',
    },
    {
      'id': '3',
      'category': 'care',
      'question': 'Can I change my assigned nurse?',
      'answer': 'Yes, please contact our support team to discuss changing your assigned healthcare provider.',
    },
    {
      'id': '4',
      'category': 'emergency',
      'question': 'What should I do in case of emergency?',
      'answer': 'In case of emergency, call 911 immediately. For non-emergency medical concerns, contact your assigned nurse.',
    },
    {
      'id': '5',
      'category': 'general',
      'question': 'How do I update my medical information?',
      'answer': 'Go to "Personal Information" in your account settings to update your medical details and contact information.',
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

  Future<void> _makePhoneCall(String phoneNumber) async {
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

  Future<void> _openEmail(String email) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=Support Request - Judy Home HealthCare',
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
          'Frequently Asked Questions',
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
            
            _buildContactOption(
              icon: Icons.email_outlined,
              title: 'Email Support',
              subtitle: 'support@judyhealthcare.com',
              color: const Color(0xFF9C27B0),
              onTap: () {
                Navigator.pop(context);
                _openEmail('support@judyhealthcare.com');
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
                _makePhoneCall('+18001234567');
              },
            ),
            
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