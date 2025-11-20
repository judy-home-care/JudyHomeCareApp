import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/incidents/incident_report_models.dart';
import '../../services/incidents/incident_service.dart';

class AddIncidentReportScreen extends StatefulWidget {
  final Map<String, dynamic> nurseData;

  const AddIncidentReportScreen({
    Key? key,
    required this.nurseData,
  }) : super(key: key);

  @override
  State<AddIncidentReportScreen> createState() => _AddIncidentReportScreenState();
}

class _AddIncidentReportScreenState extends State<AddIncidentReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _incidentService = IncidentService();
  
  final _incidentLocationController = TextEditingController();
  final _incidentDescriptionController = TextEditingController();
  final _incidentTypeOtherController = TextEditingController();
  final _firstAidDescriptionController = TextEditingController();
  final _careProviderNameController = TextEditingController();
  final _hospitalTransferDetailsController = TextEditingController();
  final _witnessNamesController = TextEditingController();
  final _witnessContactsController = TextEditingController();
  final _reportedToSupervisorController = TextEditingController();
  final _correctiveActionsController = TextEditingController();
  final _clientIdCaseNoController = TextEditingController();
  final _staffFamilyInvolvedController = TextEditingController();
  final _staffFamilyRoleOtherController = TextEditingController();
  
  DateTime _reportDate = DateTime.now();
  DateTime _incidentDate = DateTime.now();
  TimeOfDay _incidentTime = TimeOfDay.now();
  String _incidentType = 'fall';
  String? _selectedPatientId;
  List<PatientOption> _patients = [];
  bool _firstAidProvided = false;
  bool _transferredToHospital = false;
  String _severity = 'medium';
  bool _followUpRequired = false;
  DateTime? _followUpDate;
  String? _staffFamilyRole;
  bool _patientSelectionError = false;
  
  bool _isLoading = false;
  bool _isLoadingPatients = true;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  @override
  void dispose() {
    _incidentLocationController.dispose();
    _incidentDescriptionController.dispose();
    _incidentTypeOtherController.dispose();
    _firstAidDescriptionController.dispose();
    _careProviderNameController.dispose();
    _hospitalTransferDetailsController.dispose();
    _witnessNamesController.dispose();
    _witnessContactsController.dispose();
    _reportedToSupervisorController.dispose();
    _correctiveActionsController.dispose();
    _clientIdCaseNoController.dispose();
    _staffFamilyInvolvedController.dispose();
    _staffFamilyRoleOtherController.dispose();
    super.dispose();
  }

  Future<void> _loadPatients() async {
    try {
      final patients = await _incidentService.getPatientsForIncident();
      if (mounted) {
        setState(() {
          _patients = patients;
          _isLoadingPatients = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPatients = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFB),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF1A1A1A)),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'New Incident Report',
            style: TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: _isLoadingPatients
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF199A8E)),
                ),
              )
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSection(
                        '1. General Information',
                        Icons.info_outline,
                        [
                          _buildDateField(
                            'Report Date',
                            _reportDate,
                            (date) => setState(() => _reportDate = date),
                          ),
                          const SizedBox(height: 12),
                          _buildDateField(
                            'Incident Date',
                            _incidentDate,
                            (date) => setState(() => _incidentDate = date),
                          ),
                          const SizedBox(height: 12),
                          _buildTimeField(),
                          const SizedBox(height: 12),
                          _buildTextField(
                            'Incident Location',
                            _incidentLocationController,
                            'e.g., Patient\'s home, bedroom',
                            required: false,
                          ),
                          const SizedBox(height: 12),
                          _buildDropdown(
                            'Incident Type',
                            _incidentType,
                            IncidentTypes.types,
                            (value) => setState(() => _incidentType = value!),
                          ),
                          if (_incidentType == 'other') ...[
                            const SizedBox(height: 12),
                            _buildTextField(
                              'Specify Other Type',
                              _incidentTypeOtherController,
                              'Please specify',
                              required: true,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      _buildSection(
                        '2. Patient Information',
                        Icons.person_outline,
                        [
                          _buildPatientDropdown(),
                          const SizedBox(height: 12),
                          _buildTextField(
                            'Client ID / Case No',
                            _clientIdCaseNoController,
                            'Optional',
                            required: false,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      _buildSection(
                        '3. Staff/Family Involved',
                        Icons.people_outline,
                        [
                          _buildTextField(
                            'Name',
                            _staffFamilyInvolvedController,
                            'Name of person involved',
                            required: false,
                          ),
                          const SizedBox(height: 12),
                          _buildDropdown(
                            'Role',
                            _staffFamilyRole,
                            StaffFamilyRoles.roles,
                            (value) => setState(() => _staffFamilyRole = value),
                            required: false,
                          ),
                          if (_staffFamilyRole == 'other') ...[
                            const SizedBox(height: 12),
                            _buildTextField(
                              'Specify Other Role',
                              _staffFamilyRoleOtherController,
                              'Please specify',
                              required: true,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      _buildSection(
                        '4. Incident Description',
                        Icons.description_outlined,
                        [
                          _buildTextArea(
                            'Describe what happened',
                            _incidentDescriptionController,
                            'Provide detailed description of the incident',
                            required: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      _buildSection(
                        '5. Immediate Actions',
                        Icons.medical_services_outlined,
                        [
                          _buildSwitchTile(
                            'First Aid Provided',
                            _firstAidProvided,
                            (value) => setState(() => _firstAidProvided = value),
                          ),
                          if (_firstAidProvided) ...[
                            const SizedBox(height: 12),
                            _buildTextArea(
                              'First Aid Description',
                              _firstAidDescriptionController,
                              'Describe first aid provided',
                              required: true,
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              'Care Provider Name',
                              _careProviderNameController,
                              'Name of person who provided care',
                              required: false,
                            ),
                          ],
                          const SizedBox(height: 12),
                          _buildSwitchTile(
                            'Transferred to Hospital',
                            _transferredToHospital,
                            (value) => setState(() => _transferredToHospital = value),
                          ),
                          if (_transferredToHospital) ...[
                            const SizedBox(height: 12),
                            _buildTextArea(
                              'Transfer Details',
                              _hospitalTransferDetailsController,
                              'Hospital name, reason for transfer, etc.',
                              required: true,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      _buildSection(
                        '6. Witnesses',
                        Icons.visibility_outlined,
                        [
                          _buildTextField(
                            'Witness Names',
                            _witnessNamesController,
                            'Names of witnesses (if any)',
                            required: false,
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            'Witness Contacts',
                            _witnessContactsController,
                            'Contact information',
                            required: false,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      _buildSection(
                        '7. Follow-Up',
                        Icons.follow_the_signs_outlined,
                        [
                          _buildTextField(
                            'Reported to Supervisor',
                            _reportedToSupervisorController,
                            'Name of supervisor',
                            required: false,
                          ),
                          const SizedBox(height: 12),
                          _buildTextArea(
                            'Corrective/Preventive Actions',
                            _correctiveActionsController,
                            'Actions taken or recommended',
                            required: false,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      _buildSection(
                        '8. Severity & Follow-Up',
                        Icons.priority_high_outlined,
                        [
                          _buildDropdown(
                            'Severity Level',
                            _severity,
                            SeverityLevels.levels,
                            (value) => setState(() => _severity = value!),
                          ),
                          const SizedBox(height: 12),
                          _buildSwitchTile(
                            'Requires Follow-Up',
                            _followUpRequired,
                            (value) => setState(() => _followUpRequired = value),
                          ),
                          if (_followUpRequired) ...[
                            const SizedBox(height: 12),
                            _buildDateField(
                              'Follow-Up Date',
                              _followUpDate ?? DateTime.now().add(const Duration(days: 7)),
                              (date) => setState(() => _followUpDate = date),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      _buildSubmitButton(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF199A8E).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF199A8E),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildPatientDropdown() {
    final selectedPatient = _patients.firstWhere(
      (p) => p.id.toString() == _selectedPatientId,
      orElse: () => PatientOption(id: 0, name: '', age: 0),
    );
    
    return InkWell(
      onTap: () => _showPatientSearchModal(),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Select Patient *',
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 1),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          suffixIcon: const Icon(Icons.arrow_drop_down),
          errorText: _patientSelectionError && _selectedPatientId == null
              ? 'Please select a patient'
              : null,
        ),
        child: Text(
          _selectedPatientId != null && selectedPatient.id != 0
              ? '${selectedPatient.name} (Age ${selectedPatient.age})'
              : 'Tap to search and select patient',
          style: TextStyle(
            fontSize: 16,
            color: _selectedPatientId != null && selectedPatient.id != 0
                ? Colors.black
                : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  void _showPatientSearchModal() {
    setState(() {
      _patientSelectionError = false;
    });
    
    FocusScope.of(context).unfocus();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PatientSearchModal(
        patients: _patients,
        selectedPatientId: _selectedPatientId,
        onPatientSelected: (patientId) {
          Navigator.pop(context);
          
          Future.microtask(() {
            if (mounted) {
              setState(() {
                _selectedPatientId = patientId;
                _patientSelectionError = false;
              });
            }
          });
        },
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    String hint, {
    bool required = false,
  }) {
    return TextFormField(
      controller: controller,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        hintText: hint,
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: required
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return 'This field is required';
              }
              return null;
            }
          : null,
    );
  }

  Widget _buildTextArea(
    String label,
    TextEditingController controller,
    String hint, {
    bool required = false,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: 4,
      textInputAction: TextInputAction.newline,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        hintText: hint,
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: required
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return 'This field is required';
              }
              return null;
            }
          : null,
    );
  }

  Widget _buildDropdown(
    String label,
    String? value,
    List<Map<String, String>> items,
    void Function(String?) onChanged, {
    bool required = true,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      items: items.map((item) {
        return DropdownMenuItem(
          value: item['value'],
          child: Text(
            item['label']!,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: onChanged,
      validator: required
          ? (value) {
              if (value == null || value.isEmpty) {
                return 'Please select an option';
              }
              return null;
            }
          : null,
    );
  }

  Widget _buildDateField(
    String label,
    DateTime date,
    void Function(DateTime) onChanged,
  ) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          suffixIcon: const Icon(Icons.calendar_today),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        child: Text(
          DateFormat('MMM dd, yyyy').format(date),
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildTimeField() {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: _incidentTime,
        );
        if (picked != null) {
          setState(() {
            _incidentTime = picked;
          });
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Incident Time *',
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          suffixIcon: const Icon(Icons.access_time),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        child: Text(
          _incidentTime.format(context),
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    bool value,
    void Function(bool) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF199A8E),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitIncidentReport,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF199A8E),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Submit Report',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Future<void> _submitIncidentReport() async {
    if (_selectedPatientId == null || _selectedPatientId!.isEmpty) {
      setState(() {
        _patientSelectionError = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a patient'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final request = CreateIncidentRequest(
        reportDate: DateFormat('yyyy-MM-dd').format(_reportDate),
        incidentDate: DateFormat('yyyy-MM-dd').format(_incidentDate),
        incidentTime: '${_incidentTime.hour.toString().padLeft(2, '0')}:${_incidentTime.minute.toString().padLeft(2, '0')}',
        incidentLocation: _incidentLocationController.text.trim().isEmpty
            ? null
            : _incidentLocationController.text.trim(),
        incidentType: _incidentType,
        incidentTypeOther: _incidentType == 'other'
            ? _incidentTypeOtherController.text.trim()
            : null,
        patientId: int.parse(_selectedPatientId!),
        clientIdCaseNo: _clientIdCaseNoController.text.trim().isEmpty
            ? null
            : _clientIdCaseNoController.text.trim(),
        staffFamilyInvolved: _staffFamilyInvolvedController.text.trim().isEmpty
            ? null
            : _staffFamilyInvolvedController.text.trim(),
        staffFamilyRole: _staffFamilyRole,
        staffFamilyRoleOther: _staffFamilyRole == 'other'
            ? _staffFamilyRoleOtherController.text.trim()
            : null,
        incidentDescription: _incidentDescriptionController.text.trim(),
        firstAidProvided: _firstAidProvided,
        firstAidDescription: _firstAidProvided
            ? _firstAidDescriptionController.text.trim()
            : null,
        careProviderName: _careProviderNameController.text.trim().isEmpty
            ? null
            : _careProviderNameController.text.trim(),
        transferredToHospital: _transferredToHospital,
        hospitalTransferDetails: _transferredToHospital
            ? _hospitalTransferDetailsController.text.trim()
            : null,
        witnessNames: _witnessNamesController.text.trim().isEmpty
            ? null
            : _witnessNamesController.text.trim(),
        witnessContacts: _witnessContactsController.text.trim().isEmpty
            ? null
            : _witnessContactsController.text.trim(),
        reportedToSupervisor: _reportedToSupervisorController.text.trim().isEmpty
            ? null
            : _reportedToSupervisorController.text.trim(),
        correctivePreventiveActions: _correctiveActionsController.text.trim().isEmpty
            ? null
            : _correctiveActionsController.text.trim(),
        severity: _severity,
        followUpRequired: _followUpRequired,
        followUpDate: _followUpRequired && _followUpDate != null
            ? DateFormat('yyyy-MM-dd').format(_followUpDate!)
            : null,
      );

      final response = await _incidentService.createIncident(request);

      if (!mounted) return;

      if (response.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incident report submitted successfully'),
            backgroundColor: Color(0xFF199A8E),
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit incident report'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

class _PatientSearchModal extends StatefulWidget {
  final List<PatientOption> patients;
  final String? selectedPatientId;
  final Function(String) onPatientSelected;

  const _PatientSearchModal({
    Key? key,
    required this.patients,
    required this.selectedPatientId,
    required this.onPatientSelected,
  }) : super(key: key);

  @override
  State<_PatientSearchModal> createState() => _PatientSearchModalState();
}

class _PatientSearchModalState extends State<_PatientSearchModal> {
  final _searchController = TextEditingController();
  List<PatientOption> _filteredPatients = [];

  @override
  void initState() {
    super.initState();
    _filteredPatients = widget.patients;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterPatients(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredPatients = widget.patients;
      } else {
        _filteredPatients = widget.patients.where((patient) {
          final nameLower = patient.name.toLowerCase();
          final queryLower = query.toLowerCase();
          final ageString = patient.age.toString();
          return nameLower.contains(queryLower) || ageString.contains(queryLower);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Select Patient',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey.shade100,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _filterPatients,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search by name or age...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterPatients('');
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
          
          Expanded(
            child: _filteredPatients.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No patients found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your search',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredPatients.length,
                    itemBuilder: (context, index) {
                      final patient = _filteredPatients[index];
                      final isSelected = patient.id.toString() == widget.selectedPatientId;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? const Color(0xFF199A8E).withOpacity(0.1)
                              : Colors.white,
                          border: Border.all(
                            color: isSelected 
                                ? const Color(0xFF199A8E)
                                : Colors.grey.shade200,
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          onTap: () => widget.onPatientSelected(patient.id.toString()),
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF199A8E)
                                  : Colors.grey.shade200,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                patient.name.split(' ').map((n) => n[0]).take(2).join(),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            patient.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isSelected 
                                  ? const Color(0xFF199A8E)
                                  : const Color(0xFF1A1A1A),
                            ),
                          ),
                          subtitle: Text(
                            'Age: ${patient.age}${patient.gender != null ? ' • ${patient.gender}' : ''}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          trailing: isSelected
                              ? Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF199A8E),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                )
                              : Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey.shade400,
                                ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}