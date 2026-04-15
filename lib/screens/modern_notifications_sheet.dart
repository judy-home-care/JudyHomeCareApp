import 'package:flutter/material.dart';
import 'dart:ui';
import '../../services/notification_service.dart';
import '../../models/notification/notification_models.dart';
import '../../utils/app_colors.dart';
import '../../utils/secure_storage.dart';
// Patient screens
import 'patient/care_request_lists_screen.dart';
import 'patient/patient_schedules_screen.dart';
import 'patient/patient_feedback_screen.dart';
import 'patient/progress_note_screen.dart';
import 'wallet/wallet_screen.dart';
// Contact person screens
import 'contact_person/contact_person_care_request_lists_screen.dart';
import 'contact_person/contact_person_schedules_screen.dart';
import 'contact_person/contact_person_feedback_screen.dart';
import 'contact_person/contact_person_progress_notes_screen.dart';
// Nurse screens
import 'nurse/nurse_care_requests_lists_screen.dart';
import 'schedules/schedule_patients_screen.dart';
// Models for contact person
import '../models/contact_person/contact_person_models.dart';

class ModernNotificationsSheet extends StatefulWidget {
  const ModernNotificationsSheet({Key? key}) : super(key: key);

  @override
  State<ModernNotificationsSheet> createState() => _ModernNotificationsSheetState();
}

class _ModernNotificationsSheetState extends State<ModernNotificationsSheet>
    with SingleTickerProviderStateMixin {
  final NotificationService _notificationService = NotificationService();
  final SecureStorage _storage = SecureStorage();

  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  
  List<NotificationItem> _notifications = [];
  int _currentPage = 1;
  int _lastPage = 1;
  bool _hasMore = false;
  
  final ScrollController _scrollController = ScrollController();
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _scrollController.addListener(_onScroll);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent * 0.8) {
      if (!_isLoadingMore && _hasMore) {
        _loadMoreNotifications();
      }
    }
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _notificationService.getNotifications(
        page: 1,
        perPage: 20,
      );

      if (mounted) {
        setState(() {
          _notifications = response.data.data;
          _currentPage = response.data.currentPage;
          _lastPage = response.data.lastPage;
          _hasMore = _currentPage < _lastPage;
          _isLoading = false;
        });

        // Auto-mark all as read immediately when user opens the sheet
        final unreadCount = _notifications.where((n) => !n.isRead).length;
        if (unreadCount > 0) {
          debugPrint('🔔 [NotificationsSheet] Auto-marking $unreadCount notifications as read');
          _markAllAsRead();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load notifications';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreNotifications() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final response = await _notificationService.getNotifications(
        page: _currentPage + 1,
        perPage: 20,
      );

      if (mounted) {
        setState(() {
          _notifications.addAll(response.data.data);
          _currentPage = response.data.currentPage;
          _lastPage = response.data.lastPage;
          _hasMore = _currentPage < _lastPage;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _markAsRead(NotificationItem notification) async {
    if (notification.isRead) return;

    try {
      await _notificationService.markNotificationAsRead(notification.id);
      
      if (mounted) {
        setState(() {
          final index = _notifications.indexWhere((n) => n.id == notification.id);
          if (index != -1) {
            _notifications[index] = notification.copyWith(
              readAt: DateTime.now(),
              isRead: true,
              status: 'read',
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await _notificationService.markAllNotificationsAsRead();
      
      if (mounted) {
        setState(() {
          _notifications = _notifications.map((n) {
            return n.copyWith(
              readAt: DateTime.now(),
              isRead: true,
              status: 'read',
            );
          }).toList();
        });

        _showSuccessMessage('All notifications marked as read');
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage('Failed to mark all as read');
      }
    }
  }

  Future<void> _deleteNotification(NotificationItem notification) async {
    try {
      await _notificationService.deleteNotification(notification.id);
      
      if (mounted) {
        setState(() {
          _notifications.removeWhere((n) => n.id == notification.id);
        });

        _showSuccessMessage('Notification deleted');
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage('Failed to delete notification');
      }
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFFF4757),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// Navigate to the appropriate screen based on notification's notifiableType and userType
  /// [fromDetailSheet] indicates if this is called from the detail sheet (2 sheets open) vs card (1 sheet open)
  Future<void> _navigateToRelatedScreen(NotificationItem notification, {bool fromDetailSheet = false}) async {
    final notifiableType = notification.notifiableType;
    // Route based on the currently-authenticated user's role, not the
    // notification's user_type field (which may reflect the progress note's
    // owning patient rather than the actual recipient).
    final currentUserType = (await _storage.getUserType())?.toLowerCase();
    final userType = currentUserType ?? notification.userType.toLowerCase();

    if (notifiableType == null) {
      _showErrorMessage('Unable to navigate - no related item');
      return;
    }

    // Capture the navigator BEFORE popping to avoid stale context issues
    final navigator = Navigator.of(context, rootNavigator: true);

    // Close sheets based on where we're navigating from
    if (fromDetailSheet) {
      // Close the notification detail sheet first
      navigator.pop();
    }
    // Close the main notifications sheet
    navigator.pop();

    // Get user data for screens that need it
    final userData = await _storage.getUserData();

    if (userData == null) {
      _showErrorMessage('Unable to load user data');
      return;
    }

    // Navigate based on notifiable type and user type
    Widget? targetScreen;

    switch (notifiableType) {
      case 'App\\Models\\CareRequest':
        if (userType == 'patient') {
          targetScreen = CareRequestListsScreen(patientData: userData);
        } else if (userType == 'contact_person') {
          // For contact person, we need contactPerson and selectedPatient
          final cpData = _getContactPersonData(userData);
          if (cpData != null) {
            targetScreen = ContactPersonCareRequestListsScreen(
              contactPerson: cpData['contactPerson'],
              selectedPatient: cpData['selectedPatient'],
            );
          }
        } else if (userType == 'nurse') {
          targetScreen = NurseCareRequestsListScreen(nurseData: userData);
        }
        break;

      case 'App\\Models\\WalletTransaction':
      case 'App\\Models\\Expense':
        if (userType == 'patient' || userType == 'contact_person') {
          targetScreen = WalletScreen(patientData: userData);
        }
        break;

      case 'App\\Models\\Schedule':
        if (userType == 'patient') {
          targetScreen = const PatientSchedulesScreen();
        } else if (userType == 'contact_person') {
          // Get patient ID from notification data or stored data
          final patientId = _getPatientIdFromData(notification, userData);
          if (patientId != null) {
            targetScreen = ContactPersonSchedulesScreen(patientId: patientId);
          }
        } else if (userType == 'nurse') {
          targetScreen = SchedulePatientsScreen(nurseData: userData);
        }
        break;

      case 'App\\Models\\SurveyResponse':
        if (userType == 'patient') {
          targetScreen = const PatientFeedbackScreen();
        } else if (userType == 'contact_person') {
          // For contact person, we need contactPerson and selectedPatient
          final cpData = _getContactPersonData(userData);
          if (cpData != null) {
            targetScreen = ContactPersonFeedbackScreen(
              contactPerson: cpData['contactPerson'],
              selectedPatient: cpData['selectedPatient'],
            );
          }
        }
        break;

      case 'App\\Models\\ProgressNote':
        if (userType == 'patient') {
          targetScreen = const ProgressNoteScreen();
        } else if (userType == 'contact_person') {
          // notifiableId here is the ProgressNote id, not a patient id, so
          // resolve the patient from notification.data or the contact
          // person's currently selected patient.
          int? patientId;
          if (notification.data != null) {
            final raw = notification.data!['patient_id'] ?? notification.data!['patientId'];
            if (raw is int) {
              patientId = raw;
            } else if (raw != null) {
              patientId = int.tryParse(raw.toString());
            }
          }
          final cpData = _getContactPersonData(userData);
          patientId ??= cpData?['selectedPatient']?.id as int?;
          if (patientId != null) {
            targetScreen = ContactPersonProgressNotesScreen(patientId: patientId);
          } else {
            debugPrint('[Notifications] ProgressNote tap: no patientId resolved');
          }
        }
        break;

      case 'App\\Models\\PatientFeedback':
        if (userType == 'patient') {
          // Navigate to Nurse Visit & Feedbacks tab (index 1) with My Feedback toggle active
          targetScreen = const PatientFeedbackScreen(
            initialTabIndex: 1,
            showMyFeedback: true,
          );
        } else if (userType == 'contact_person') {
          // For contact person, we need contactPerson and selectedPatient
          final cpData = _getContactPersonData(userData);
          if (cpData != null) {
            targetScreen = ContactPersonFeedbackScreen(
              contactPerson: cpData['contactPerson'],
              selectedPatient: cpData['selectedPatient'],
              initialTabIndex: 1,
              showMyFeedback: true,
            );
          }
        }
        break;

      default:
        debugPrint('Unknown notifiable type: $notifiableType');
        break;
    }

    if (targetScreen != null) {
      navigator.push(
        MaterialPageRoute(builder: (context) => targetScreen!),
      );
    }
  }

  /// Extract contact person data from user data
  Map<String, dynamic>? _getContactPersonData(Map<String, dynamic> userData) {
    try {
      // Check if we have contact person data in the stored user data
      if (userData['contact_person'] != null) {
        final contactPerson = ContactPersonUser.fromJson(userData['contact_person']);
        // Try to get selected patient from stored data
        if (userData['selected_patient'] != null) {
          final selectedPatient = LinkedPatient.fromJson(userData['selected_patient']);
          return {
            'contactPerson': contactPerson,
            'selectedPatient': selectedPatient,
          };
        }
        // If no selected patient but there are linked patients, use the first one
        if (contactPerson.linkedPatients.isNotEmpty) {
          return {
            'contactPerson': contactPerson,
            'selectedPatient': contactPerson.linkedPatients.first,
          };
        }
      }
      // Alternative: the user data might be the contact person object directly
      if (userData['linked_patients'] != null || userData['linkedPatients'] != null) {
        final contactPerson = ContactPersonUser.fromJson(userData);
        if (contactPerson.linkedPatients.isNotEmpty) {
          return {
            'contactPerson': contactPerson,
            'selectedPatient': contactPerson.linkedPatients.first,
          };
        }
      }
    } catch (e) {
      debugPrint('Error parsing contact person data: $e');
    }
    return null;
  }

  /// Get patient ID from notification data or user data
  int? _getPatientIdFromData(NotificationItem notification, Map<String, dynamic> userData) {
    // First try to get from notification data
    if (notification.data != null) {
      if (notification.data!['patient_id'] != null) {
        return notification.data!['patient_id'] as int;
      }
      if (notification.data!['patientId'] != null) {
        return notification.data!['patientId'] as int;
      }
    }
    // Try to get from notifiableId if it's a patient-related notification
    if (notification.notifiableId != null) {
      return notification.notifiableId;
    }
    // Try to get from stored selected patient
    if (userData['selected_patient'] != null && userData['selected_patient']['id'] != null) {
      return userData['selected_patient']['id'] as int;
    }
    // Try to get from linked patients
    final cpData = _getContactPersonData(userData);
    if (cpData != null) {
      return cpData['selectedPatient'].id;
    }
    return null;
  }

  /// Check if the notification has a navigable screen
  bool _hasNavigableScreen(NotificationItem notification) {
    final notifiableType = notification.notifiableType;
    if (notifiableType == null) return false;

    const navigableTypes = [
      'App\\Models\\CareRequest',
      'App\\Models\\WalletTransaction',
      'App\\Models\\Expense',
      'App\\Models\\Schedule',
      'App\\Models\\SurveyResponse',
      'App\\Models\\ProgressNote',
      'App\\Models\\PatientFeedback',
    ];

    return navigableTypes.contains(notifiableType);
  }

  /// Get the label for the navigation button based on notifiable type
  String _getNavigationLabel(String? notifiableType) {
    switch (notifiableType) {
      case 'App\\Models\\CareRequest':
        return 'View Care Requests';
      case 'App\\Models\\WalletTransaction':
      case 'App\\Models\\Expense':
        return 'View Wallet';
      case 'App\\Models\\Schedule':
        return 'View Schedules';
      case 'App\\Models\\SurveyResponse':
        return 'View Feedback';
      case 'App\\Models\\ProgressNote':
        return 'View Progress Notes';
      case 'App\\Models\\PatientFeedback':
        return 'View My Feedback';
      default:
        return 'View Details';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 30,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _isLoading
                      ? _buildLoadingState()
                      : _errorMessage != null
                          ? _buildErrorState()
                          : _notifications.isEmpty
                              ? _buildEmptyState()
                              : _buildNotificationsList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    final unreadCount = _notifications.where((n) => !n.isRead).length;
    
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryGreen.withOpacity(0.05),
            Colors.white,
          ],
        ),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          // Drag Handle
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
          const SizedBox(height: 20),
          
          // Title Row
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryGreen,
                      AppColors.primaryGreen.withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryGreen.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.notifications_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (unreadCount > 0)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primaryGreen,
                              AppColors.primaryGreen.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$unreadCount new',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (unreadCount > 0)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primaryGreen.withOpacity(0.1),
                        AppColors.primaryGreen.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primaryGreen.withOpacity(0.2),
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _markAllAsRead,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.done_all_rounded,
                              size: 18,
                              color: AppColors.primaryGreen,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Mark all',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
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
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryGreen.withOpacity(0.1),
                  AppColors.primaryGreen.withOpacity(0.05),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.primaryGreen,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading notifications...',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF4757).withOpacity(0.1),
                    const Color(0xFFFF4757).withOpacity(0.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 56,
                color: Color(0xFFFF4757),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _errorMessage ?? 'An error occurred',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryGreen,
                    AppColors.primaryGreen.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryGreen.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _loadNotifications,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
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
              child: Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.notifications_off_rounded,
                    size: 40,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'All Clear!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You\'re all caught up',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'We\'ll notify you when something new arrives',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsList() {
    return RefreshIndicator(
      onRefresh: _loadNotifications,
      color: AppColors.primaryGreen,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _notifications.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _notifications.length) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primaryGreen,
                    ),
                  ),
                ),
              ),
            );
          }

          final notification = _notifications[index];
          return _buildNotificationCard(notification, index);
        },
      ),
    );
  }

  Widget _buildNotificationCard(NotificationItem notification, int index) {
    final isUnread = !notification.isRead;
    
    return Dismissible(
      key: Key('notification_${notification.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF4757), Color(0xFFFF6B7A)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.delete_rounded, color: Colors.white, size: 28),
            SizedBox(height: 4),
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) => _showDeleteConfirmation(notification),
      onDismissed: (direction) => _deleteNotification(notification),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: Duration(milliseconds: 300 + (index * 50)),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: Opacity(
              opacity: value,
              child: child,
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isUnread
                  ? AppColors.primaryGreen.withOpacity(0.3)
                  : Colors.grey.shade200,
              width: isUnread ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isUnread
                    ? AppColors.primaryGreen.withOpacity(0.08)
                    : Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Material(
                color: isUnread
                    ? AppColors.primaryGreen.withOpacity(0.02)
                    : Colors.transparent,
                child: InkWell(
                  onTap: () => _showNotificationDetail(notification),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildNotificationIcon(notification),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildNotificationContent(notification, isUnread),
                        ),
                        if (_hasNavigableScreen(notification))
                          _buildNavigationButton(notification),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationIcon(NotificationItem notification) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getNotificationColor(notification.notificationType),
            _getNotificationColor(notification.notificationType).withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _getNotificationColor(notification.notificationType).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          _getNotificationIcon(notification.notificationType),
          style: const TextStyle(fontSize: 28),
        ),
      ),
    );
  }

  Widget _buildNavigationButton(NotificationItem notification) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToRelatedScreen(notification),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primaryGreen.withOpacity(0.2),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.open_in_new_rounded,
                  color: AppColors.primaryGreen,
                  size: 20,
                ),
                const SizedBox(height: 2),
                Text(
                  'View',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationContent(NotificationItem notification, bool isUnread) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                notification.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                  color: const Color(0xFF1A1A1A),
                  letterSpacing: -0.3,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (isUnread)
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryGreen,
                      AppColors.primaryGreen.withOpacity(0.8),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryGreen.withOpacity(0.5),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          notification.body,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
            height: 1.5,
            letterSpacing: -0.1,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.grey.shade100,
                Colors.grey.shade50,
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.grey.shade200,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.access_time_rounded,
                size: 14,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Text(
                notification.timeAgo,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showNotificationDetail(NotificationItem notification) {
    // Mark as read when viewing detail
    _markAsRead(notification);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              decoration: BoxDecoration(
                color: _getNotificationColor(notification.notificationType).withOpacity(0.05),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              _getNotificationColor(notification.notificationType),
                              _getNotificationColor(notification.notificationType).withOpacity(0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: _getNotificationColor(notification.notificationType).withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            _getNotificationIcon(notification.notificationType),
                            style: const TextStyle(fontSize: 28),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notification.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A1A),
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    notification.timeAgo,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.close,
                          color: Colors.grey.shade600,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Body Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.body,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade800,
                        height: 1.6,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Navigation Button (if applicable)
                    if (_hasNavigableScreen(notification)) ...[
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primaryGreen,
                              AppColors.primaryGreen.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryGreen.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () => _navigateToRelatedScreen(notification, fromDetailSheet: true),
                          icon: const Icon(Icons.open_in_new, size: 20),
                          label: Text(_getNavigationLabel(notification.notifiableType)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Delete Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteNotification(notification);
                        },
                        icon: const Icon(Icons.delete_outline, size: 20),
                        label: const Text('Delete Notification'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFF4757),
                          side: const BorderSide(
                            color: Color(0xFFFF4757),
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
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

  Future<bool?> _showDeleteConfirmation(NotificationItem notification) {
    return showDialog<bool>(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFF4757).withOpacity(0.2),
                      const Color(0xFFFF4757).withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.delete_rounded,
                  color: Color(0xFFFF4757),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Delete Notification',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'Are you sure you want to delete this notification?',
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF4757), Color(0xFFFF6B7A)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF4757).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getNotificationIcon(String type) {
    const icons = {
      'appointment_reminder': '📅',
      'medication_reminder': '💊',
      'vitals_reminder': '❤️',
      'care_plan_update': '📋',
      'payment_reminder': '💳',
      'nurse_assigned': '👩‍⚕️',
      'assessment_scheduled': '🏥',
      'care_started': '✅',
      'care_completed': '🎉',
      'care_request_created': '📝',
      'payment_received': '✅',
      'feedback_response': '💬',
      'feedback_received': '⭐',
    };
    return icons[type] ?? '🔔';
  }

  Color _getNotificationColor(String type) {
    const colors = {
      'appointment_reminder': Color(0xFF6C63FF),
      'medication_reminder': Color(0xFFFF9A00),
      'vitals_reminder': Color(0xFFFF4757),
      'care_plan_update': AppColors.primaryGreen,
      'payment_reminder': Color(0xFFFF9A00),
      'nurse_assigned': AppColors.primaryGreen,
      'assessment_scheduled': Color(0xFF6C63FF),
      'care_started': AppColors.primaryGreen,
      'care_completed': AppColors.primaryGreen,
      'care_request_created': Color(0xFF6C63FF),
      'payment_received': AppColors.primaryGreen,
      'feedback_response': Color(0xFF6C63FF),
      'feedback_received': Color(0xFFFFB648),
    };
    return colors[type] ?? AppColors.primaryGreen;
  }
}

// Helper function to show the bottom sheet
Future<void> showNotificationsSheet(BuildContext context) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const ModernNotificationsSheet(),
  );
}