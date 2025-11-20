import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

class NurseCertificationsScreen extends StatefulWidget {
  final Map<String, dynamic> nurseData;
  
  const NurseCertificationsScreen({
    Key? key,
    required this.nurseData,
  }) : super(key: key);

  @override
  State<NurseCertificationsScreen> createState() => _NurseCertificationsScreenState();
}

class _NurseCertificationsScreenState extends State<NurseCertificationsScreen> {
  Set<String> _expandedCards = {};
  
  // Filter state
  String _selectedStatusFilter = 'all';
  String _selectedTypeFilter = 'all';

  final List<Map<String, dynamic>> certifications = [
    {
      'id': 'CERT-001',
      'name': 'Registered Nurse (RN) License',
      'type': 'License',
      'issuingBody': 'Ghana Nursing and Midwifery Council',
      'licenseNumber': 'RN-45892-GH',
      'issueDate': '2020-03-15',
      'expiryDate': '2026-03-15',
      'status': 'Active',
      'daysToExpiry': 145,
      'document': 'rn_license.pdf',
      'verificationStatus': 'Verified',
    },
    {
      'id': 'CERT-002',
      'name': 'Basic Life Support (BLS)',
      'type': 'Certification',
      'issuingBody': 'American Heart Association',
      'licenseNumber': 'BLS-2024-789456',
      'issueDate': '2024-01-10',
      'expiryDate': '2026-01-10',
      'status': 'Active',
      'daysToExpiry': 462,
      'document': 'bls_cert.pdf',
      'verificationStatus': 'Verified',
    },
    {
      'id': 'CERT-003',
      'name': 'Advanced Cardiac Life Support (ACLS)',
      'type': 'Certification',
      'issuingBody': 'American Heart Association',
      'licenseNumber': 'ACLS-2023-456123',
      'issueDate': '2023-06-20',
      'expiryDate': '2025-06-20',
      'status': 'Expiring Soon',
      'daysToExpiry': 258,
      'document': 'acls_cert.pdf',
      'verificationStatus': 'Verified',
    },
    {
      'id': 'CERT-004',
      'name': 'Pediatric Advanced Life Support (PALS)',
      'type': 'Certification',
      'issuingBody': 'American Heart Association',
      'licenseNumber': 'PALS-2022-789321',
      'issueDate': '2022-09-05',
      'expiryDate': '2024-09-05',
      'status': 'Expired',
      'daysToExpiry': -30,
      'document': 'pals_cert.pdf',
      'verificationStatus': 'Expired',
    },
  ];

  List<Map<String, dynamic>> get filteredCertifications {
    List<Map<String, dynamic>> certs = List.from(certifications);
    
    // Apply status filter
    if (_selectedStatusFilter != 'all') {
      certs = certs.where((cert) {
        return cert['status'].toLowerCase().replaceAll(' ', '_') == _selectedStatusFilter;
      }).toList();
    }
    
    // Apply type filter
    if (_selectedTypeFilter != 'all') {
      certs = certs.where((cert) {
        return cert['type'].toLowerCase() == _selectedTypeFilter;
      }).toList();
    }
    
    return certs;
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
          'Certifications & Licenses',
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
              if (_selectedStatusFilter != 'all' || _selectedTypeFilter != 'all')
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
      body: _buildCertificationsList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCertificationDialog(),
        backgroundColor: AppColors.primaryGreen,
        elevation: 4,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add New',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildCertificationsList() {
    if (filteredCertifications.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
      itemCount: filteredCertifications.length,
      itemBuilder: (context, index) => _buildCertificationCard(filteredCertifications[index], index),
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
                        Icons.card_membership_outlined,
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
                'No Certifications Found',
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
                'Add your professional certifications and licenses to keep track of renewals and stay compliant.',
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

  Widget _buildCertificationCard(Map<String, dynamic> cert, int index) {
    final isExpanded = _expandedCards.contains(cert['id']);
    final statusColor = _getStatusColor(cert['status']);
    final isExpired = cert['status'] == 'Expired';
    final isExpiringSoon = cert['status'] == 'Expiring Soon';
    
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
              _expandedCards.remove(cert['id']);
            } else {
              _expandedCards.add(cert['id']);
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
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            cert['type'] == 'License' 
                              ? Icons.badge_outlined 
                              : Icons.card_membership_outlined,
                            color: statusColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cert['name'],
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A1A1A),
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                cert['licenseNumber'],
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
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
                            cert['status'],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Issuing body
                    Row(
                      children: [
                        Icon(
                          Icons.business_outlined,
                          size: 16,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            cert['issuingBody'],
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Expiry warning
                    if (isExpired || isExpiringSoon)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: statusColor.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isExpired ? Icons.error : Icons.warning,
                              size: 18,
                              color: statusColor,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                isExpired 
                                  ? 'Expired ${cert['daysToExpiry'].abs()} days ago - Renewal required'
                                  : 'Expires in ${cert['daysToExpiry']} days - Renewal recommended',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    if (isExpanded) ...[
                      const SizedBox(height: 16),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: Colors.grey.shade200,
                      ),
                      const SizedBox(height: 16),
                      
                      // Dates
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoItem(
                              'Issue Date',
                              cert['issueDate'],
                              Icons.calendar_today_outlined,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildInfoItem(
                              'Expiry Date',
                              cert['expiryDate'],
                              Icons.event_outlined,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Document & Verification
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoItem(
                              'Document',
                              cert['document'],
                              Icons.description_outlined,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildInfoItem(
                              'Status',
                              cert['verificationStatus'],
                              Icons.verified_outlined,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.download, size: 18),
                              label: const Text('Download'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                side: BorderSide(color: Colors.grey.shade300),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('Renew'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryGreen,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    
                    const SizedBox(height: 12),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.category_outlined,
                                    size: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    cert['type'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: Colors.grey.shade500,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
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
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return AppColors.primaryGreen;
      case 'expiring soon':
        return const Color(0xFFFF9A00);
      case 'expired':
        return const Color(0xFFFF5722);
      default:
        return Colors.grey;
    }
  }

  void _showFilterOptions() {
    String tempStatusFilter = _selectedStatusFilter;
    String tempTypeFilter = _selectedTypeFilter;
    
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
                  'Filter Certifications',
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
                      label: 'Expiring Soon',
                      isSelected: tempStatusFilter == 'expiring_soon',
                      color: const Color(0xFFFF9A00),
                      onTap: () => setModalState(() => tempStatusFilter = 'expiring_soon'),
                    ),
                    _buildFilterChip(
                      label: 'Expired',
                      isSelected: tempStatusFilter == 'expired',
                      color: const Color(0xFFFF5722),
                      onTap: () => setModalState(() => tempStatusFilter = 'expired'),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Type Filter
                Text(
                  'Type',
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
                      isSelected: tempTypeFilter == 'all',
                      color: Colors.grey.shade600,
                      onTap: () => setModalState(() => tempTypeFilter = 'all'),
                    ),
                    _buildFilterChip(
                      label: 'License',
                      isSelected: tempTypeFilter == 'license',
                      color: const Color(0xFF2196F3),
                      onTap: () => setModalState(() => tempTypeFilter = 'license'),
                    ),
                    _buildFilterChip(
                      label: 'Certification',
                      isSelected: tempTypeFilter == 'certification',
                      color: const Color(0xFF9C27B0),
                      onTap: () => setModalState(() => tempTypeFilter = 'certification'),
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
                            tempTypeFilter = 'all';
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
                            _selectedTypeFilter = tempTypeFilter;
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

  void _showAddCertificationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Add Certification/License',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'This feature would allow you to add new certifications and licenses with document upload capabilities.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}