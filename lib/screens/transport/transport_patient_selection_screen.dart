import 'package:flutter/material.dart';
import 'dart:async';
import '../../utils/app_colors.dart';
import '../../models/patients/nurse_patient_models.dart';
import '../../services/patients/nurse_patient_service.dart';
import 'transport_location_selection_screen.dart';

class TransportPatientSelectionScreen extends StatefulWidget {
  const TransportPatientSelectionScreen({Key? key}) : super(key: key);

  @override
  State<TransportPatientSelectionScreen> createState() => _TransportPatientSelectionScreenState();
}

class _TransportPatientSelectionScreenState extends State<TransportPatientSelectionScreen> {
  final _searchController = TextEditingController();
  final _patientService = NursePatientService();
  
  List<Patient> _allPatients = [];
  List<Patient> _filteredPatients = [];
  Patient? _selectedPatient;
  
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadPatients() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _patientService.getNursePatients();

      if (mounted) {
        setState(() {
          _allPatients = response.data;
          _filteredPatients = response.data;
          _isLoading = false;
        });
      }
    } on NursePatientException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load patients. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  void _filterPatients(String query) {
    _debounce?.cancel();
    
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (query.isEmpty) {
        setState(() {
          _filteredPatients = _allPatients;
        });
      } else {
        setState(() {
          _filteredPatients = _allPatients
              .where((patient) {
                final name = patient.name.toLowerCase();
                final phone = patient.phone?.toLowerCase() ?? '';
                return name.contains(query.toLowerCase()) || 
                       phone.contains(query.toLowerCase());
              })
              .toList();
        });
      }
    });
  }

  void _selectPatient(Patient patient) {
    setState(() {
      _selectedPatient = patient;
    });
  }

  void _continueToTransportType() {
    if (_selectedPatient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a patient'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    _showTransportTypeSelector();
  }

  void _showTransportTypeSelector() {
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
            const Text(
              'Request Transport',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose the type of transport for ${_selectedPatient!.name}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _buildTransportOption(
              title: 'Emergency Ambulance',
              subtitle: 'Urgent medical transport',
              icon: Icons.emergency,
              color: const Color(0xFFFF4757),
              onTap: () async {
                Navigator.pop(context); // Close the modal
                
                // Navigate to location selection and wait for result
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TransportLocationSelectionScreen(
                      transportType: 'ambulance',
                      isEmergency: true,
                      patientId: _selectedPatient!.id,
                      patientName: _selectedPatient!.name,
                    ),
                  ),
                );
                
                // If transport request was created successfully, pop this screen too
                if (result == true && mounted) {
                  Navigator.pop(context, true);
                }
              },
            ),
            const SizedBox(height: 16),
            _buildTransportOption(
              title: 'Medical Transport',
              subtitle: 'Non-emergency patient transfer',
              icon: Icons.local_shipping,
              color: AppColors.primaryGreen,
              onTap: () async {
                Navigator.pop(context); // Close the modal
                
                // Navigate to location selection and wait for result
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TransportLocationSelectionScreen(
                      transportType: 'regular',
                      isEmergency: false,
                      patientId: _selectedPatient!.id,
                      patientName: _selectedPatient!.name,
                    ),
                  ),
                );
                
                // If transport request was created successfully, pop this screen too
                if (result == true && mounted) {
                  Navigator.pop(context, true);
                }
              },
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTransportOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 4),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Select Patient',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search patients...',
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
              onChanged: _filterPatients,
            ),
          ),

          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _errorMessage != null
                    ? _buildErrorState()
                    : _filteredPatients.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.all(20),
                            itemCount: _filteredPatients.length,
                            itemBuilder: (context, index) {
                              return _buildPatientCard(_filteredPatients[index]);
                            },
                          ),
          ),

          if (_selectedPatient != null)
            Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).padding.bottom + 20,
                top: 20,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: AppColors.primaryGreen,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Selected: ${_selectedPatient!.name}',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _continueToTransportType,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.arrow_forward, size: 22),
                          SizedBox(width: 12),
                          Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
          ),
          const SizedBox(height: 16),
          const Text('Loading patients...'),
        ],
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
            Text(
              _errorMessage ?? 'An error occurred',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadPatients,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
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

  Widget _buildPatientCard(Patient patient) {
    final isSelected = _selectedPatient?.id == patient.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectPatient(patient),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected 
                    ? AppColors.primaryGreen 
                    : Colors.transparent,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? AppColors.primaryGreen.withOpacity(0.15)
                      : Colors.black.withOpacity(0.04),
                  blurRadius: isSelected ? 20 : 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primaryGreen.withOpacity(0.2),
                        AppColors.primaryGreen.withOpacity(0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person,
                    color: AppColors.primaryGreen,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (patient.age != null)
                        Text(
                          '${patient.age} years old',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        patient.condition,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
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
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 24),
            Text(
              _searchController.text.isEmpty 
                  ? 'No patients assigned'
                  : 'No patients found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _searchController.text.isEmpty
                  ? 'You don\'t have any assigned patients yet'
                  : 'Try a different search term',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}