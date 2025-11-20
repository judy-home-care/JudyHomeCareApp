import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../services/profile_service.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  
  const NotificationPreferencesScreen({
    Key? key,
    required this.userData,
  }) : super(key: key);

  @override
  State<NotificationPreferencesScreen> createState() => _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState extends State<NotificationPreferencesScreen> {
  final ProfileService _profileService = ProfileService();
  
  // Notification toggles
  bool _allNotifications = true;
  
  // Care & Patient notifications
  bool _newPatientAssignment = true;
  bool _careplanUpdates = true;
  bool _patientVitalsAlert = true;
  bool _medicationReminders = true;
  
  // Schedule notifications
  bool _shiftReminders = true;
  bool _shiftChanges = true;
  bool _clockInReminders = true;
  
  // Communication notifications
  bool _transportRequests = true;
  bool _incidentReports = false;
  
  // System notifications
  bool _systemUpdates = false;
  bool _securityAlerts = true;
  
  // Channel preferences (removed push notifications)
  bool _emailNotifications = true;
  bool _smsNotifications = false;
  
  // Quiet hours
  bool _quietHoursEnabled = false;
  TimeOfDay _quietHoursStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietHoursEnd = const TimeOfDay(hour: 7, minute: 0);
  
  bool _isSaving = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationPreferences();
  }

  Future<void> _loadNotificationPreferences() async {
    setState(() => _isLoading = true);
    
    try {
      final result = await _profileService.getProfile();
      
      if (result['success'] && result['data'] != null) {
        final prefs = result['data']['notificationPreferences'];
        
        if (prefs != null) {
          setState(() {
            _allNotifications = prefs['all_notifications'] ?? true;
            _newPatientAssignment = prefs['new_patient_assignment'] ?? true;
            _careplanUpdates = prefs['careplan_updates'] ?? true;
            _patientVitalsAlert = prefs['patient_vitals_alert'] ?? true;
            _medicationReminders = prefs['medication_reminders'] ?? true;
            _shiftReminders = prefs['shift_reminders'] ?? true;
            _shiftChanges = prefs['shift_changes'] ?? true;
            _clockInReminders = prefs['clock_in_reminders'] ?? true;
            _transportRequests = prefs['transport_requests'] ?? true;
            _incidentReports = prefs['incident_reports'] ?? false;
            _systemUpdates = prefs['system_updates'] ?? false;
            _securityAlerts = prefs['security_alerts'] ?? true;
            _emailNotifications = prefs['email_notifications'] ?? true;
            _smsNotifications = prefs['sms_notifications'] ?? false;
            _quietHoursEnabled = prefs['quiet_hours_enabled'] ?? false;
            
            if (prefs['quiet_hours_start'] != null) {
              final startParts = prefs['quiet_hours_start'].split(':');
              _quietHoursStart = TimeOfDay(
                hour: int.parse(startParts[0]),
                minute: int.parse(startParts[1]),
              );
            }
            
            if (prefs['quiet_hours_end'] != null) {
              final endParts = prefs['quiet_hours_end'].split(':');
              _quietHoursEnd = TimeOfDay(
                hour: int.parse(endParts[0]),
                minute: int.parse(endParts[1]),
              );
            }
            
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notification Preferences',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton.icon(
              onPressed: _isSaving ? null : _savePreferences,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: AppColors.primaryGreen,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.check,
                      size: 20,
                      color: AppColors.primaryGreen,
                    ),
              label: Text(
                _isSaving ? 'Saving...' : 'Save',
                style: const TextStyle(
                  color: AppColors.primaryGreen,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
        : RefreshIndicator(
            onRefresh: _loadNotificationPreferences,
            color: AppColors.primaryGreen,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildMasterToggle(),
                    const SizedBox(height: 24),
                    _buildChannelPreferences(),
                    const SizedBox(height: 20),
                    _buildQuietHours(),
                    const SizedBox(height: 20),
                    _buildCareNotifications(),
                    const SizedBox(height: 20),
                    _buildScheduleNotifications(),
                    const SizedBox(height: 20),
                    _buildCommunicationNotifications(),
                    const SizedBox(height: 20),
                    _buildSystemNotifications(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Widget _buildMasterToggle() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _allNotifications
              ? [AppColors.primaryGreen, const Color(0xFF25B5A8)]
              : [Colors.grey.shade400, Colors.grey.shade500],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (_allNotifications ? AppColors.primaryGreen : Colors.grey).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _allNotifications ? Icons.notifications_active : Icons.notifications_off,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'All Notifications',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _allNotifications ? 'Notifications enabled' : 'Notifications disabled',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _allNotifications,
            onChanged: (value) {
              setState(() {
                _allNotifications = value;
                if (!value) {
                  _disableAllNotifications();
                } else {
                  _enableAllNotifications();
                }
              });
            },
            activeColor: Colors.white,
            activeTrackColor: Colors.white.withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelPreferences() {
    return _buildSection(
      title: 'Notification Channels',
      icon: Icons.send_outlined,
      iconColor: const Color(0xFF6C63FF),
      iconBg: const Color(0xFFEDE9FF),
      child: Column(
        children: [
          _buildChannelToggle(
            icon: Icons.email_outlined,
            title: 'Email Notifications',
            subtitle: 'Receive notifications via email',
            value: _emailNotifications,
            onChanged: (value) => setState(() => _emailNotifications = value),
            enabled: _allNotifications,
          ),
          const SizedBox(height: 16),
          _buildChannelToggle(
            icon: Icons.sms_outlined,
            title: 'SMS Notifications',
            subtitle: 'Receive critical alerts via SMS',
            value: _smsNotifications,
            onChanged: (value) => setState(() => _smsNotifications = value),
            enabled: _allNotifications,
          ),
        ],
      ),
    );
  }

  Widget _buildQuietHours() {
    return _buildSection(
      title: 'Quiet Hours',
      icon: Icons.bedtime_outlined,
      iconColor: const Color(0xFF9C27B0),
      iconBg: const Color(0xFFF3E5F5),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF9C27B0).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.do_not_disturb_on,
                  color: Color(0xFF9C27B0),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Do Not Disturb',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Silence non-urgent notifications',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _quietHoursEnabled,
                onChanged: _allNotifications
                    ? (value) => setState(() => _quietHoursEnabled = value)
                    : null,
                activeColor: const Color(0xFF9C27B0),
              ),
            ],
          ),
          if (_quietHoursEnabled) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF9C27B0).withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF9C27B0).withOpacity(0.2),
                ),
              ),
              child: Column(
                children: [
                  _buildTimeSelector(
                    label: 'Start Time',
                    time: _quietHoursStart,
                    onTap: () => _selectTime(context, true),
                  ),
                  const SizedBox(height: 12),
                  _buildTimeSelector(
                    label: 'End Time',
                    time: _quietHoursEnd,
                    onTap: () => _selectTime(context, false),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCareNotifications() {
    return _buildSection(
      title: 'Care & Patients',
      icon: Icons.medical_services_outlined,
      iconColor: AppColors.primaryGreen,
      iconBg: const Color(0xFFE8F5F5),
      child: Column(
        children: [
          _buildNotificationToggle(
            icon: Icons.person_add_outlined,
            title: 'New Patient Assignment',
            subtitle: 'When you\'re assigned a new patient',
            value: _newPatientAssignment,
            onChanged: (value) => setState(() => _newPatientAssignment = value),
            enabled: _allNotifications,
          ),
          const SizedBox(height: 12),
          _buildNotificationToggle(
            icon: Icons.assignment_outlined,
            title: 'Care Plan Updates',
            subtitle: 'Changes to patient care plans',
            value: _careplanUpdates,
            onChanged: (value) => setState(() => _careplanUpdates = value),
            enabled: _allNotifications,
          ),
          const SizedBox(height: 12),
          _buildNotificationToggle(
            icon: Icons.monitor_heart_outlined,
            title: 'Patient Vitals Alert',
            subtitle: 'Reminder to take patient daily vitals',
            value: _patientVitalsAlert,
            onChanged: (value) => setState(() => _patientVitalsAlert = value),
            enabled: _allNotifications,
          ),
          // const SizedBox(height: 12),
          // _buildNotificationToggle(
          //   icon: Icons.medication_outlined,
          //   title: 'Medication Reminders',
          //   subtitle: 'Time to administer medications',
          //   value: _medicationReminders,
          //   onChanged: (value) => setState(() => _medicationReminders = value),
          //   enabled: _allNotifications,
          // ),
        ],
      ),
    );
  }

  Widget _buildScheduleNotifications() {
    return _buildSection(
      title: 'Schedule & Shifts',
      icon: Icons.calendar_today_outlined,
      iconColor: const Color(0xFF2196F3),
      iconBg: const Color(0xFFE3F2FD),
      child: Column(
        children: [
          _buildNotificationToggle(
            icon: Icons.alarm,
            title: 'Shift Reminders',
            subtitle: '30 minutes before shift starts',
            value: _shiftReminders,
            onChanged: (value) => setState(() => _shiftReminders = value),
            enabled: _allNotifications,
          ),
          const SizedBox(height: 12),
          _buildNotificationToggle(
            icon: Icons.event_note,
            title: 'Shift Changes',
            subtitle: 'Schedule modifications or cancellations',
            value: _shiftChanges,
            onChanged: (value) => setState(() => _shiftChanges = value),
            enabled: _allNotifications,
          ),
          const SizedBox(height: 12),
          _buildNotificationToggle(
            icon: Icons.access_time,
            title: 'Clock-In Reminders',
            subtitle: 'Reminder to clock in for your shift',
            value: _clockInReminders,
            onChanged: (value) => setState(() => _clockInReminders = value),
            enabled: _allNotifications,
          ),
        ],
      ),
    );
  }

  Widget _buildCommunicationNotifications() {
    return _buildSection(
      title: 'Communication',
      icon: Icons.chat_bubble_outline,
      iconColor: const Color(0xFFFF9800),
      iconBg: const Color(0xFFFFF3E0),
      child: Column(
        children: [
          _buildNotificationToggle(
            icon: Icons.local_shipping_outlined,
            title: 'Transport Requests',
            subtitle: 'Updates on transportation requests',
            value: _transportRequests,
            onChanged: (value) => setState(() => _transportRequests = value),
            enabled: _allNotifications,
          ),
          const SizedBox(height: 12),
          _buildNotificationToggle(
            icon: Icons.report_outlined,
            title: 'Incident Reports',
            subtitle: 'Updates on submitted incident reports',
            value: _incidentReports,
            onChanged: (value) => setState(() => _incidentReports = value),
            enabled: _allNotifications,
          ),
        ],
      ),
    );
  }

  Widget _buildSystemNotifications() {
    return _buildSection(
      title: 'System & Security',
      icon: Icons.settings_outlined,
      iconColor: const Color(0xFF607D8B),
      iconBg: const Color(0xFFECEFF1),
      child: Column(
        children: [
          _buildNotificationToggle(
            icon: Icons.system_update_outlined,
            title: 'System Updates',
            subtitle: 'App updates and maintenance notices',
            value: _systemUpdates,
            onChanged: (value) => setState(() => _systemUpdates = value),
            enabled: _allNotifications,
          ),
          const SizedBox(height: 12),
          _buildNotificationToggle(
            icon: Icons.security_outlined,
            title: 'Security Alerts',
            subtitle: 'Account security and login notifications',
            value: _securityAlerts,
            onChanged: (value) => setState(() => _securityAlerts = value),
            enabled: _allNotifications,
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildChannelToggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool enabled,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF6C63FF), size: 24),
          ),
          const SizedBox(width: 16),
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
          Switch(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeColor: const Color(0xFF6C63FF),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationToggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool enabled,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: Colors.grey.shade700,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: enabled ? onChanged : null,
              activeColor: AppColors.primaryGreen,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSelector({
    required String label,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A1A1A),
              ),
            ),
            Row(
              children: [
                Text(
                  time.format(context),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.access_time,
                  size: 18,
                  color: Colors.grey.shade600,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _quietHoursStart : _quietHoursEnd,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF9C27B0),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1A1A1A),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        if (isStart) {
          _quietHoursStart = picked;
        } else {
          _quietHoursEnd = picked;
        }
      });
    }
  }

  void _disableAllNotifications() {
    setState(() {
      _newPatientAssignment = false;
      _careplanUpdates = false;
      _patientVitalsAlert = false;
      _medicationReminders = false;
      _shiftReminders = false;
      _shiftChanges = false;
      _clockInReminders = false;
      _transportRequests = false;
      _incidentReports = false;
      _systemUpdates = false;
      _securityAlerts = false;
      _emailNotifications = false;
      _smsNotifications = false;
      _quietHoursEnabled = false;
    });
  }

  void _enableAllNotifications() {
    setState(() {
      _newPatientAssignment = true;
      _careplanUpdates = true;
      _patientVitalsAlert = true;
      _medicationReminders = true;
      _shiftReminders = true;
      _shiftChanges = true;
      _clockInReminders = true;
      _transportRequests = true;
      _incidentReports = true;
      _systemUpdates = true;
      _securityAlerts = true;
      _emailNotifications = true;
      _smsNotifications = true;
      // Don't automatically enable quiet hours
      _quietHoursEnabled = false;
    });
  }

  void _savePreferences() async {
    setState(() => _isSaving = true);
    
    try {
      final preferences = {
        'all_notifications': _allNotifications,
        'new_patient_assignment': _newPatientAssignment,
        'careplan_updates': _careplanUpdates,
        'patient_vitals_alert': _patientVitalsAlert,
        'medication_reminders': _medicationReminders,
        'shift_reminders': _shiftReminders,
        'shift_changes': _shiftChanges,
        'clock_in_reminders': _clockInReminders,
        'transport_requests': _transportRequests,
        'incident_reports': _incidentReports,
        'system_updates': _systemUpdates,
        'security_alerts': _securityAlerts,
        'email_notifications': _emailNotifications,
        'sms_notifications': _smsNotifications,
        'quiet_hours_enabled': _quietHoursEnabled,
        'quiet_hours_start': '${_quietHoursStart.hour.toString().padLeft(2, '0')}:${_quietHoursStart.minute.toString().padLeft(2, '0')}',
        'quiet_hours_end': '${_quietHoursEnd.hour.toString().padLeft(2, '0')}:${_quietHoursEnd.minute.toString().padLeft(2, '0')}',
      };
      
      final result = await _profileService.updateNotificationPreferences(preferences);
      
      setState(() => _isSaving = false);
      
      if (mounted) {
        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(result['message'] ?? 'Notification preferences saved'),
                ],
              ),
              backgroundColor: AppColors.primaryGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(20),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(result['message'] ?? 'Failed to save preferences'),
                ],
              ),
              backgroundColor: const Color(0xFFFF4757),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(20),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isSaving = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Text('An error occurred while saving preferences'),
              ],
            ),
            backgroundColor: Color(0xFFFF4757),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}