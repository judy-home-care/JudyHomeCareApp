import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

class CarePlanHistoryScreen extends StatefulWidget {
  final Map<String, dynamic> nurseData;
  
  const CarePlanHistoryScreen({
    Key? key,
    required this.nurseData,
  }) : super(key: key);

  @override
  State<CarePlanHistoryScreen> createState() => _CarePlanHistoryScreenState();
}

class _CarePlanHistoryScreenState extends State<CarePlanHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Set<String> _expandedCards = {};
  
  // Filter state
  String _selectedStatusFilter = 'all';
  String _selectedCareTypeFilter = 'all';
  String _selectedPriorityFilter = 'all';

  final List<Map<String, dynamic>> carePlans = [
    {
      'id': 'CP-001',
      'patientName': 'Robert Ben Brown',
      'patientId': '#5',
      'patientAvatar': 'RB',
      'title': 'Post-Appendectomy Recovery Care Plan',
      'description': 'A structured plan for post-surgical recovery including wound care, pain management, and mobility exercises',
      'doctor': 'John Manager',
      'doctorSpecialty': 'General',
      'careType': 'Elderly Care',
      'status': 'Active',
      'priority': 'Medium',
      'progress': 45,
      'startDate': '2025-09-15',
      'endDate': '2025-10-15',
      'tasks': [
        {'name': 'Wound care inspection', 'completed': true},
        {'name': 'Pain medication administration', 'completed': true},
        {'name': 'Mobility exercises', 'completed': false},
        {'name': 'Vital signs monitoring', 'completed': true},
      ],
      'notes': 'Patient showing good progress. Wound healing well with no signs of infection.',
    },
    {
      'id': 'CP-002',
      'patientName': 'Robert Ben Brown',
      'patientId': '#5',
      'patientAvatar': 'RB',
      'title': 'Type 2 Diabetes Long-Term Management',
      'description': 'A structured plan to support diabetes management through diet, medication, and monitoring',
      'doctor': 'Dr. Sarah Wilson',
      'doctorSpecialty': 'Internal Medicine',
      'careType': 'Pediatric Care',
      'status': 'Active',
      'priority': 'High',
      'progress': 30,
      'startDate': '2025-08-01',
      'endDate': '2025-11-01',
      'tasks': [
        {'name': 'Blood glucose monitoring', 'completed': true},
        {'name': 'Insulin administration', 'completed': true},
        {'name': 'Diet consultation', 'completed': false},
        {'name': 'Exercise tracking', 'completed': false},
      ],
      'notes': 'Blood sugar levels stable. Continue current medication regimen.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get filteredCarePlans {
    List<Map<String, dynamic>> plans = List.from(carePlans);
    
    // Apply status filter
    if (_selectedStatusFilter != 'all') {
      plans = plans.where((plan) {
        return plan['status'].toLowerCase() == _selectedStatusFilter;
      }).toList();
    }
    
    // Apply care type filter
    if (_selectedCareTypeFilter != 'all') {
      plans = plans.where((plan) {
        return plan['careType'].toLowerCase().replaceAll(' ', '_') == _selectedCareTypeFilter;
      }).toList();
    }
    
    // Apply priority filter
    if (_selectedPriorityFilter != 'all') {
      plans = plans.where((plan) {
        return plan['priority'].toLowerCase() == _selectedPriorityFilter;
      }).toList();
    }
    
    return plans;
  }

  int get totalPlans => carePlans.length;
  int get activePlans => carePlans.where((p) => p['status'] == 'Active').length;
  int get completedPlans => carePlans.where((p) => p['status'] == 'Completed').length;
  String get avgProgress {
    if (carePlans.isEmpty) return '0%';
    final avg = carePlans.map((p) => p['progress'] as int).reduce((a, b) => a + b) / carePlans.length;
    return '${avg.round()}%';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Care Plans',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list, color: Color(0xFF1A1A1A)),
                onPressed: () => _showFilterOptions(),
              ),
              if (_selectedStatusFilter != 'all' || _selectedCareTypeFilter != 'all' || _selectedPriorityFilter != 'all')
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSummaryCards(),
          _buildModernTabs(),
          Expanded(child: _buildCarePlansList()),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              title: 'Active Plans',
              value: activePlans.toString(),
              icon: Icons.assignment_outlined,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard(
              title: 'Completed',
              value: completedPlans.toString(),
              icon: Icons.check_circle_outline,
              color: const Color(0xFF2196F3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard(
              title: 'Avg. Progress',
              value: avgProgress,
              icon: Icons.trending_up,
              color: const Color(0xFFFF9A00),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTabs() {
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
              _buildModernTab('All', 0),
              _buildModernTab('Active', 1),
              _buildModernTab('Completed', 2),
              _buildModernTab('On Hold', 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernTab(String label, int index) {
    final isSelected = _tabController.index == index;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _tabController.animateTo(index);
            switch (index) {
              case 0:
                _selectedStatusFilter = 'all';
                break;
              case 1:
                _selectedStatusFilter = 'active';
                break;
              case 2:
                _selectedStatusFilter = 'completed';
                break;
              case 3:
                _selectedStatusFilter = 'on_hold';
                break;
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
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
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF8F92A1),
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCarePlansList() {
    if (filteredCarePlans.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      itemCount: filteredCarePlans.length,
      itemBuilder: (context, index) => _buildCarePlanCard(filteredCarePlans[index], index),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                width: 140,
                height: 140,
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
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primaryGreen.withOpacity(0.2),
                          width: 2,
                        ),
                      ),
                    ),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.assignment_outlined,
                        size: 40,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [
                  AppColors.primaryGreen,
                  AppColors.primaryGreen.withOpacity(0.7),
                ],
              ).createShader(bounds),
              child: const Text(
                'No Care Plans Found',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            const SizedBox(height: 8),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Your assigned care plans will appear here. Check back later or adjust your filters.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarePlanCard(Map<String, dynamic> plan, int index) {
    final isExpanded = _expandedCards.contains(plan['id']);
    final priorityColor = _getPriorityColor(plan['priority']);
    final statusColor = _getStatusColor(plan['status']);
    
    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 300 + (index * 100)),
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
              _expandedCards.remove(plan['id']);
            } else {
              _expandedCards.add(plan['id']);
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: statusColor.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Patient Avatar
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.primaryGreen.withOpacity(0.8),
                                AppColors.primaryGreen,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              plan['patientAvatar'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      plan['patientName'],
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1A1A1A),
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      plan['status'],
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: statusColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                plan['patientId'],
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Care Plan Title
                    Text(
                      plan['title'],
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                        height: 1.3,
                      ),
                    ),
                    
                    const SizedBox(height: 6),
                    
                    Text(
                      plan['description'],
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                      maxLines: isExpanded ? null : 2,
                      overflow: isExpanded ? null : TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Badges Row
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildBadge(
                          plan['careType'],
                          const Color(0xFF2196F3),
                          Icons.medical_services_outlined,
                        ),
                        _buildBadge(
                          plan['priority'],
                          priorityColor,
                          Icons.flag_outlined,
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Progress Bar
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Progress',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            Text(
                              '${plan['progress']}%',
                              style: TextStyle(
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
                            value: plan['progress'] / 100,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.primaryGreen,
                            ),
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 14,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${plan['startDate']} - ${plan['endDate']}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        AnimatedRotation(
                          duration: const Duration(milliseconds: 300),
                          turns: isExpanded ? 0.5 : 0,
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.grey.shade600,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 300),
                crossFadeState: isExpanded 
                  ? CrossFadeState.showSecond 
                  : CrossFadeState.showFirst,
                firstChild: const SizedBox.shrink(),
                secondChild: Column(
                  children: [
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: Colors.grey.shade200,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow(
                            Icons.person_outlined,
                            'Assigned Doctor',
                            '${plan['doctor']} - ${plan['doctorSpecialty']}',
                          ),
                          
                          if (plan['notes'] != null) ...[
                            const SizedBox(height: 16),
                            _buildDetailRow(
                              Icons.note_outlined,
                              'Latest Notes',
                              plan['notes'],
                            ),
                          ],
                          
                          const SizedBox(height: 16),
                          Text(
                            'Tasks (${(plan['tasks'] as List).where((t) => t['completed'] == true).length}/${plan['tasks'].length})',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...List.generate(
                            plan['tasks'].length,
                            (index) {
                              final task = plan['tasks'][index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Icon(
                                      task['completed']
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                      size: 18,
                                      color: task['completed']
                                        ? AppColors.primaryGreen
                                        : Colors.grey.shade400,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        task['name'],
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: task['completed']
                                            ? Colors.grey.shade600
                                            : const Color(0xFF1A1A1A),
                                          decoration: task['completed']
                                            ? TextDecoration.lineThrough
                                            : null,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
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
    );
  }

  Widget _buildBadge(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return const Color(0xFFFF5722);
      case 'medium':
        return const Color(0xFFFF9A00);
      case 'low':
        return const Color(0xFF2196F3);
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return AppColors.primaryGreen;
      case 'completed':
        return const Color(0xFF2196F3);
      case 'on hold':
        return const Color(0xFFFF9A00);
      default:
        return Colors.grey;
    }
  }

  void _showFilterOptions() {
    String tempStatusFilter = _selectedStatusFilter;
    String tempCareTypeFilter = _selectedCareTypeFilter;
    String tempPriorityFilter = _selectedPriorityFilter;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
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
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                const Text(
                  'Filter Care Plans',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Status Filter
                Text(
                  'Status',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildFilterChip(
                      label: 'All',
                      isSelected: tempStatusFilter == 'all',
                      color: Colors.grey.shade600,
                      onTap: () => setModalState(() => tempStatusFilter = 'all'),
                    ),
                    _buildFilterChip(
                      label: 'Active',
                      isSelected: tempStatusFilter == 'active',
                      color: AppColors.primaryGreen,
                      onTap: () => setModalState(() => tempStatusFilter = 'active'),
                    ),
                    _buildFilterChip(
                      label: 'Completed',
                      isSelected: tempStatusFilter == 'completed',
                      color: const Color(0xFF2196F3),
                      onTap: () => setModalState(() => tempStatusFilter = 'completed'),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Care Type Filter
                Text(
                  'Care Type',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildFilterChip(
                      label: 'All Types',
                      isSelected: tempCareTypeFilter == 'all',
                      color: Colors.grey.shade600,
                      onTap: () => setModalState(() => tempCareTypeFilter = 'all'),
                    ),
                    _buildFilterChip(
                      label: 'Elderly Care',
                      isSelected: tempCareTypeFilter == 'elderly_care',
                      color: const Color(0xFF2196F3),
                      onTap: () => setModalState(() => tempCareTypeFilter = 'elderly_care'),
                    ),
                    _buildFilterChip(
                      label: 'Pediatric Care',
                      isSelected: tempCareTypeFilter == 'pediatric_care',
                      color: const Color(0xFFFF9A00),
                      onTap: () => setModalState(() => tempCareTypeFilter = 'pediatric_care'),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Priority Filter
                Text(
                  'Priority',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildFilterChip(
                      label: 'All',
                      isSelected: tempPriorityFilter == 'all',
                      color: Colors.grey.shade600,
                      onTap: () => setModalState(() => tempPriorityFilter = 'all'),
                    ),
                    _buildFilterChip(
                      label: 'High',
                      isSelected: tempPriorityFilter == 'high',
                      color: const Color(0xFFFF5722),
                      onTap: () => setModalState(() => tempPriorityFilter = 'high'),
                    ),
                    _buildFilterChip(
                      label: 'Medium',
                      isSelected: tempPriorityFilter == 'medium',
                      color: const Color(0xFFFF9A00),
                      onTap: () => setModalState(() => tempPriorityFilter = 'medium'),
                    ),
                    _buildFilterChip(
                      label: 'Low',
                      isSelected: tempPriorityFilter == 'low',
                      color: const Color(0xFF2196F3),
                      onTap: () => setModalState(() => tempPriorityFilter = 'low'),
                    ),
                  ],
                ),
                
                const SizedBox(height: 32),
                
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setModalState(() {
                            tempStatusFilter = 'all';
                            tempCareTypeFilter = 'all';
                            tempPriorityFilter = 'all';
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Reset',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedStatusFilter = tempStatusFilter;
                            _selectedCareTypeFilter = tempCareTypeFilter;
                            _selectedPriorityFilter = tempPriorityFilter;
                          });
                          Navigator.pop(context);
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Filters applied successfully'),
                              backgroundColor: AppColors.primaryGreen,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              margin: const EdgeInsets.all(16),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Apply Filters',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? color : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}