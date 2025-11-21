import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/app_colors.dart';

class NurseHelpCenterScreen extends StatefulWidget {
  const NurseHelpCenterScreen({Key? key}) : super(key: key);

  @override
  State<NurseHelpCenterScreen> createState() => _NurseHelpCenterScreenState();
}

class _NurseHelpCenterScreenState extends State<NurseHelpCenterScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<Map<String, dynamic>> _quickActions = [
    {
      'icon': Icons.emergency_outlined,
      'title': 'Emergency',
      'subtitle': '24/7 Hotline',
      'color': const Color(0xFFFF5722),
      'badge': '24/7',
      'route': 'emergency',
    },
    {
      'icon': Icons.phone_outlined,
      'title': 'Call Support',
      'subtitle': '+233 543-413-513',
      'color': AppColors.primaryGreen,
      'badge': null,
      'route': 'call',
    },
    {
      'icon': Icons.bug_report_outlined,
      'title': 'Report Issue',
      'subtitle': 'Technical problems',
      'color': const Color(0xFFFF9800),
      'badge': null,
      'route': 'report',
    },
  ];

  final List<Map<String, dynamic>> _helpCategories = [
    {
      'id': 'home_visit_protocol',
      'icon': Icons.home_outlined,
      'title': 'Home Care Visit Protocol',
      'description': 'Step-by-step guide for home visits',
      'color': const Color(0xFF6C63FF),
      'articlesCount': 7,
      'articles': [
        {
          'title': 'Preparation Before Visit',
          'content': 'Review client\'s care plan and previous notes.\n\nPack required supplies:\n• Vital signs kit\n• Dressing materials\n• Medications\n• Documentation forms\n\nEnsure personal protective equipment (mask, gloves, sanitizer) is available.'
        },
        {
          'title': 'Arrival at Client\'s Home',
          'content': '• Greet client/family politely\n• Introduce yourself and your role\n• Wash or sanitize hands\n• Explain the purpose of the visit\n• Ensure privacy and comfort of the client'
        },
        {
          'title': 'Initial Assessment',
          'content': '• Ask about client\'s general wellbeing since last visit\n• Check symptoms, pain, sleep, appetite, bowel/bladder function\n• Check adherence to medications\n• Observe the environment for safety/hygiene risks\n• Measure vital signs (Temp, Pulse, Resp, BP, SpO₂, Pain scale)'
        },
        {
          'title': 'Care Delivery',
          'content': 'As per care plan:\n• Medication administration\n• Wound care/dressing changes\n• Physiotherapy/exercises\n• Personal hygiene support\n• Emotional/psychosocial support\n• Family education on ongoing care'
        },
        {
          'title': 'Documentation',
          'content': '• Record vital signs, interventions, and observations\n• Update care plan if needed\n• Note family/client concerns'
        },
        {
          'title': 'Communication & Handover',
          'content': '• Discuss findings with client/family\n• Highlight warning signs\n• Notify supervisor/doctor if abnormal findings\n• Leave emergency contact information'
        },
        {
          'title': 'Departure',
          'content': '• Ensure client is comfortable\n• Dispose of waste properly\n• Wash/sanitize hands\n• Thank client and family'
        },
      ],
    },
    {
      'id': 'initial_assessment',
      'icon': Icons.assessment_outlined,
      'title': 'Initial Home Assessment',
      'description': 'Complete assessment checklist',
      'color': const Color(0xFF9C27B0),
      'articlesCount': 4,
      'articles': [
        {
          'title': 'Purpose & Preparation',
          'content': 'Ensure the client\'s home environment is safe and suitable for care delivery.\n\nPreparation:\n• Review case details\n• Gather tools (BP machine, thermometer, PPE)\n• Inform client/family of visit'
        },
        {
          'title': 'Environmental Checklist',
          'content': '✓ Safe entrance & pathways\n✓ Clean, dry, non-slippery flooring\n✓ Adequate lighting\n✓ Accessible bathroom with grab bars\n✓ Clean, safe kitchen\n✓ Comfortable bedroom\n✓ Proper ventilation\n✓ Electrical safety\n✓ Waste disposal bins\n✓ Emergency contacts visible'
        },
        {
          'title': 'Client Assessment Checklist',
          'content': '✓ Demographic data\n✓ Medical history\n✓ Current condition\n✓ Vital signs\n✓ Medication review\n✓ Nutritional status\n✓ Mobility assessment\n✓ Cognitive & emotional status\n✓ Pain assessment\n✓ Skin assessment\n✓ Activities of Daily Living\n✓ Social support\n✓ Cultural/spiritual needs'
        },
        {
          'title': 'Documentation & Follow-up',
          'content': '✓ Complete and sign assessment form\n✓ Take photos of hazards (if consented)\n✓ Submit report within 24 hours\n✓ Explain hazards to family\n✓ Provide recommendations\n✓ Plan caregiver assignment'
        },
      ],
    },
    {
      'id': 'daily_documentation',
      'icon': Icons.description_outlined,
      'title': 'Daily Documentation',
      'description': 'Progress notes & checklists',
      'color': AppColors.primaryGreen,
      'articlesCount': 4,
      'articles': [
        {
          'title': 'Daily Progress Notes',
          'content': 'Record for each visit:\n\n✅ Vital Signs\n• Temperature, Pulse, Respiration\n• Blood Pressure, SpO₂\n\n✅ Interventions Provided\n• Medication administered\n• Wound care\n• Physiotherapy\n• Nutrition support\n• Hygiene/personal care\n• Counseling/education\n\n✅ Observations\n• General condition\n• Pain level (0-10)\n• Wound status\n\n✅ Family Communication\n• Education provided\n• Concerns raised'
        },
        {
          'title': 'Vital Signs Monitoring',
          'content': 'Before Procedure:\n✓ Explain procedure to client\n✓ Wash hands\n✓ Gather equipment\n✓ Ensure client rested 5 minutes\n\nDuring Procedure:\n✓ Measure Temperature\n✓ Measure Pulse (rate, rhythm, volume)\n✓ Count Respirations\n✓ Check Blood Pressure\n✓ Measure Oxygen Saturation\n\nAfter Procedure:\n✓ Record all results\n✓ Report abnormal values\n✓ Educate client/family\n✓ Wash hands'
        },
        {
          'title': 'Wound Dressing Procedure',
          'content': 'Before:\n✓ Explain procedure\n✓ Wash hands\n✓ Gather sterile supplies\n✓ Position client comfortably\n\nDuring:\n✓ Wear sterile gloves\n✓ Remove old dressing\n✓ Inspect wound\n✓ Clean wound (clean → dirty)\n✓ Apply medication\n✓ Apply sterile dressing\n✓ Secure with tape\n\nAfter:\n✓ Dispose waste safely\n✓ Remove gloves & wash hands\n✓ Document wound condition\n✓ Report signs of infection'
        },
        {
          'title': 'Medication Administration',
          'content': 'Before:\n✓ Verify client identity\n✓ Check prescription\n✓ Check for allergies\n✓ Wash hands\n✓ Prepare correct medication\n✓ Check expiry date\n\nDuring:\n✓ Administer via correct route\n✓ Use aseptic technique\n✓ Ensure oral meds swallowed\n✓ Monitor for reactions\n\nAfter:\n✓ Record drug, dose, route, time\n✓ Document refused/missed doses\n✓ Report adverse reactions\n✓ Wash hands'
        },
      ],
    },
    {
      'id': 'incident_reporting',
      'icon': Icons.report_problem_outlined,
      'title': 'Incident Reporting',
      'description': 'Report unexpected events',
      'color': const Color(0xFFFF5722),
      'articlesCount': 5,
      'articles': [
        {
          'title': 'When to Report',
          'content': 'All incidents must be reported promptly:\n\n• Falls\n• Medication errors\n• Equipment failure\n• Injuries\n• Near-misses\n• Any unexpected event during home healthcare services'
        },
        {
          'title': 'General Information Required',
          'content': 'Document:\n• Date of report\n• Date of incident\n• Time of incident\n• Location (home/room/washroom/kitchen)\n• Type of incident\n• Patient name, age, sex\n• Client ID/Case number\n• Staff/family involved'
        },
        {
          'title': 'Description & Actions',
          'content': 'Describe what happened (facts only, no opinions)\n\nImmediate Actions:\n• First aid/medical care provided\n• Who provided care\n• Was client transferred to hospital?\n• Where and mode of transportation\n• Witness information'
        },
        {
          'title': 'Follow-up Actions',
          'content': '• Report to supervisor/manager\n• Corrective/preventive actions planned\n• Document all steps taken\n• Submit within 24 hours'
        },
        {
          'title': 'Important Notes',
          'content': '• Be factual and objective\n• Complete all sections\n• Get signatures required\n• Mark as CONFIDENTIAL\n• Submit to agency manager promptly\n• Keep a copy for records'
        },
      ],
    },
    {
      'id': 'end_of_life_care',
      'icon': Icons.favorite_border,
      'title': 'Managing Unresponsive Client',
      'description': 'Protocol for emergency situations',
      'color': const Color(0xFFE91E63),
      'articlesCount': 6,
      'articles': [
        {
          'title': 'Immediate Assessment',
          'content': 'If client becomes unresponsive:\n\n• Assess for pulse, breathing, and responsiveness\n• DO NOT declare death\n• Only state that client is unresponsive and requires urgent medical attention\n• Remain calm and professional'
        },
        {
          'title': 'Informing the Family',
          'content': '• Use neutral language: "Your relative is unresponsive. We need to get them to the hospital for further assessment and care."\n\n• Offer emotional reassurance\n• Maintain professionalism at all times\n• Do not use terms like "death" or "deceased"'
        },
        {
          'title': 'Emergency Response',
          'content': '• Immediately call ambulance service (112)\n• Stay with client and family until help arrives\n• Prepare necessary documents:\n  - Client file\n  - Care notes\n  - ID if available'
        },
        {
          'title': 'Notifications',
          'content': '• Notify agency supervisor/manager immediately\n• Keep physician on record updated\n• Document time of notifications\n• Record who was informed'
        },
        {
          'title': 'Hospital Transfer',
          'content': '• Escort client and family to hospital\n• Hand over all relevant medical information\n• Provide complete care notes to hospital team\n• Stay until handover is complete'
        },
        {
          'title': 'Documentation Required',
          'content': 'Record in Incident Report Form:\n\n• Time and circumstances of event\n• Vital signs and observations made\n• Actions taken (ambulance, notifications, transfer)\n• Names of family members informed\n• Names of receiving medical staff\n• Submit report within 24 hours'
        },
      ],
    },
    {
      'id': 'termination_care',
      'icon': Icons.check_circle_outline,
      'title': 'Termination of Care',
      'description': 'Closing care services properly',
      'color': const Color(0xFF00BCD4),
      'articlesCount': 5,
      'articles': [
        {
          'title': 'Reasons for Termination',
          'content': 'Care may be terminated due to:\n\n☐ Completed Goals/Recovery\n☐ Hospital Admission\n☐ Transfer to Another Facility\n☐ Client Request/Relocation\n☐ Financial Reasons\n☐ Death\n☐ Other reasons'
        },
        {
          'title': 'Care Completion Review',
          'content': '☐ Final nursing assessment completed\n☐ Medication reconciliation done\n☐ Wound/catheter/IV care status reviewed\n☐ Vital signs checked at termination\n☐ All agency equipment collected/returned\n☐ Final care notes documented'
        },
        {
          'title': 'Client/Family Education',
          'content': 'Ensure the following are provided:\n\n☐ Medication instructions\n☐ Diet & nutrition advice\n☐ Activity/exercise guidance\n☐ Signs & symptoms to report\n☐ Emergency contacts\n☐ Follow-up appointment arranged (if applicable)'
        },
        {
          'title': 'Documentation Requirements',
          'content': '☐ Progress notes completed & filed\n☐ Care plan closed out\n☐ Referral made (if applicable)\n☐ Client/family acknowledgement obtained\n☐ All records properly stored'
        },
        {
          'title': 'Acknowledgement',
          'content': 'Required signatures:\n\n• Client/Family signature and date\n• Attending nurse signature and date\n• Supervisor signature and date\n\nDate of termination must be clearly documented.\n\nConfirm all parties understand the termination and next steps.'
        },
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.primaryGreen,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primaryGreen,
                      AppColors.primaryGreen.withOpacity(0.8),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Help Center',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'We\'re here to help you succeed',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Search Bar
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search for help articles...',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.grey.shade400,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: Colors.grey.shade400,
                          ),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),

          // Quick Actions
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  color: Colors.grey.shade100,
                  height: 8,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),

          SliverToBoxAdapter(
            child: SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _quickActions.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  return _buildQuickActionCard(_quickActions[index]);
                },
              ),
            ),
          ),

          // Help Categories
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
              child: Text(
                'Browse by Category',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.85,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return _buildCategoryCard(_helpCategories[index]);
                },
                childCount: _helpCategories.length,
              ),
            ),
          ),

          // Bottom Spacing
          const SliverToBoxAdapter(
            child: SizedBox(height: 40),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(Map<String, dynamic> action) {
    return GestureDetector(
      onTap: () => _handleQuickAction(action['route']),
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: action['color'].withOpacity(0.2),
            width: 1.5,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: action['color'].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    action['icon'],
                    color: action['color'],
                    size: 22,
                  ),
                ),
                if (action['badge'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: action['color'],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      action['badge'],
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              action['title'],
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              action['subtitle'],
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> category) {
    return GestureDetector(
      onTap: () => _navigateToCategory(category),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.shade200,
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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: category['color'].withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: category['color'].withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      category['icon'],
                      color: category['color'],
                      size: 24,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${category['articlesCount']}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: category['color'],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, // Changed from max to min
                  children: [
                    Text(
                      category['title'],
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Flexible( // Wrap description in Flexible
                      child: Text(
                        category['description'],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 8), // Replace Spacer with fixed spacing
                    Row(
                      children: [
                        Text(
                          'View articles',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: category['color'],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 10,
                          color: category['color'],
                        ),
                      ],
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

  void _handleQuickAction(String route) {
    switch (route) {
      case 'emergency':
        _callEmergency();
        break;
      case 'call':
        _makeCall();
        break;
      case 'report':
        _showReportIssueModal();
        break;
    }
  }

  void _makeCall() async {
    final phoneNumber = '+233543413513';
    final uri = Uri.parse('tel:$phoneNumber');
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to make phone call',
              style: TextStyle(color: Colors.white), 
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  void _showReportIssueModal() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final issueController = TextEditingController();
    String selectedCategory = 'Technical Issue';
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
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
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
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
                        color: const Color(0xFFFF9800).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.bug_report,
                        color: Color(0xFFFF9800),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Report Technical Issue',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          Text(
                            'Describe the problem you\'re experiencing',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
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
              
              // Form
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name
                        const Text(
                          'Your Name *',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: nameController,
                          decoration: InputDecoration(
                            hintText: 'Enter your full name',
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        
                        // Email
                        const Text(
                          'Email Address *',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'your.email@example.com',
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!value.contains('@')) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        
                        // Phone
                        const Text(
                          'Phone Number',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            hintText: '+233 XXX XXX XXX',
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Category
                        const Text(
                          'Issue Category *',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: selectedCategory,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Technical Issue',
                              child: Text('Technical Issue'),
                            ),
                            DropdownMenuItem(
                              value: 'Login Problem',
                              child: Text('Login Problem'),
                            ),
                            DropdownMenuItem(
                              value: 'App Crash',
                              child: Text('App Crash'),
                            ),
                            DropdownMenuItem(
                              value: 'Feature Request',
                              child: Text('Feature Request'),
                            ),
                            DropdownMenuItem(
                              value: 'Other',
                              child: Text('Other'),
                            ),
                          ],
                          onChanged: (value) {
                            setModalState(() {
                              selectedCategory = value!;
                            });
                          },
                        ),
                        const SizedBox(height: 20),
                        
                        // Issue Description
                        const Text(
                          'Describe the Issue *',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: issueController,
                          maxLines: 6,
                          decoration: InputDecoration(
                            hintText: 'Please provide as much detail as possible...',
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please describe the issue';
                            }
                            if (value.length < 10) {
                              return 'Please provide more details (at least 10 characters)';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Submit Button
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        if (formKey.currentState!.validate()) {
                          _submitIssueReport(
                            name: nameController.text,
                            email: emailController.text,
                            phone: phoneController.text,
                            category: selectedCategory,
                            description: issueController.text,
                          );
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF9800),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Submit Report',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submitIssueReport({
    required String name,
    required String email,
    required String phone,
    required String category,
    required String description,
  }) async {
    final emailBody = '''
Name: $name
Email: $email
Phone: $phone
Category: $category

Issue Description:
$description
    ''';
    
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'theophilusboateng7@gmail.com',
      query: 'subject=Technical Issue Report - $category&body=${Uri.encodeComponent(emailBody)}',
    );
    
    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Opening email app...'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No email app available. Please email theophilusboateng7@gmail.com directly.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error opening email app'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _callEmergency() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.emergency, color: Colors.red.shade600),
            const SizedBox(width: 8),
            const Text('Emergency Services'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select emergency service:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 16),
            Text('🚑 Ambulance: 112 or 193'),
            SizedBox(height: 8),
            Text('🚒 Fire Service: 192'),
            SizedBox(height: 8),
            Text('👮 Police: 191 or 18555'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _dialEmergencyNumber('112');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          child: const Text(
            'Call Ambulance (112)',
            style: TextStyle(color: Colors.white),
          ),
          ),
        ],
      ),
    );
  }

  Future<void> _dialEmergencyNumber(String number) async {
    final uri = Uri.parse('tel:$number');
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to dial $number'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToCategory(Map<String, dynamic> category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryArticlesScreen(category: category),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

// Category Articles Screen
class CategoryArticlesScreen extends StatelessWidget {
  final Map<String, dynamic> category;

  const CategoryArticlesScreen({Key? key, required this.category})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final articles = category['articles'] as List<Map<String, dynamic>>;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: category['color'],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          category['title'],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: category['color'],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    category['icon'],
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  category['description'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: articles.length,
              itemBuilder: (context, index) {
                return _buildArticleCard(
                  context,
                  articles[index],
                  category['color'],
                  index,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArticleCard(
    BuildContext context,
    Map<String, dynamic> article,
    Color color,
    int index,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () => _openArticleDetail(context, article, color),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  article['title'],
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openArticleDetail(
    BuildContext context,
    Map<String, dynamic> article,
    Color color,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArticleDetailScreen(
          article: article,
          color: color,
        ),
      ),
    );
  }
}

// Article Detail Screen
class ArticleDetailScreen extends StatelessWidget {
  final Map<String, dynamic> article;
  final Color color;

  const ArticleDetailScreen({
    Key? key,
    required this.article,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: color,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Article',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Text(
                article['title'],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                article['content'],
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.6,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}