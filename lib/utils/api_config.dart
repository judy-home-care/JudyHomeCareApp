import 'package:flutter/foundation.dart';

class ApiConfig {
  // Base URL - can be changed based on environment
  static const String _localBaseUrl = 'http://localhost:8000';
  static const String _productionBaseUrl = 'https://portal.judyscareagency.com'; // Replace with your production URL

  // Get base URL based on environment
  static String get baseUrl {
    if (kDebugMode) {
      // For Android emulator, use 10.0.2.2 instead of localhost
      if (defaultTargetPlatform == TargetPlatform.android) {
        return 'http://10.0.2.2:8000';
      }
      return _localBaseUrl;
    }
    return _productionBaseUrl;
  }

  static String get storageUrl => '$baseUrl/storage';
 
  // API endpoints
  static const String authPrefix = '/api/auth';
  static const String loginEndpoint = '$authPrefix/login';
  static const String registerEndpoint = '$authPrefix/register';
  static const String logoutEndpoint = '$authPrefix/logout';
  static const String meEndpoint = '$authPrefix/me';

  // Password reset endpoints
  static const String forgotPasswordEndpoint = '$authPrefix/forgot-password';
  static const String verifyResetOtpEndpoint = '$authPrefix/verify-reset-otp';
  static const String resendResetOtpEndpoint = '$authPrefix/resend-reset-otp';
  static const String resetPasswordEndpoint = '$authPrefix/reset-password';
  static const String requestCallbackEndpoint = '$authPrefix/request-callback';

  static const String verifyLoginTwoFactorEndpoint = '$authPrefix/verify-login-2fa';
  static const String resendLoginTwoFactorEndpoint = '$authPrefix/resend-login-2fa';

  static const String mobilePrefix = '/api/mobile';

  // Dashboard endpoints
  static const String nurseMobileDashboardEndpoint = '/api/mobile/nurse/dashboard';

  // Patient Dashboard endpoint
  static const String patientMobileDashboardEndpoint = '/api/mobile/patient/dashboard';

  // Nurse - Patient endpoints
  static const String nursePrefix = '/api/mobile/nurse';
  static const String nursePatientsEndpoint = '$nursePrefix/patients';

  // Get patient detail endpoint - dynamic patient ID
  static String nursePatientDetailEndpoint(int patientId) =>
      '$nursePrefix/patients/$patientId';

  // Create progress note endpoint
  static const String progressNotesEndpoint = '$mobilePrefix/progress-notes';

  // For getting a specific progress note by ID
  static String progressNoteDetailEndpoint(int noteId) =>
      '$mobilePrefix/progress-notes/$noteId';

  // Update progress note endpoint (ADD THIS)
  static String updateProgressNoteEndpoint(int noteId) =>
    '$mobilePrefix/progress-notes/$noteId';

  // Check if progress note is editable (ADD THIS)
  static String checkProgressNoteEditableEndpoint(int noteId) =>
      '$mobilePrefix/progress-notes/$noteId/editable';

  // Get nurse schedules
  static const String nurseSchedulesEndpoint = '/api/mobile/schedules';

  // Request reschedule (for patients)
  static String scheduleRescheduleRequestEndpoint(int scheduleId) =>
      '$mobilePrefix/schedules/$scheduleId/request-reschedule';

  // ==================== CARE PLAN ENDPOINTS ====================
  
  // Get all care plans (supports pagination)
  static const String nurseCarePlansEndpoint = '$mobilePrefix/care-plans';

  // Create care plan
  static const String createCarePlanEndpoint = '$nursePrefix/care-plans';

  static String get carePlanDoctorsEndpoint => '$nursePrefix/care-plans/doctors';

  static String get carePlanPatientsEndpoint => '$nursePrefix/care-plans/patients';

  // Get care requests for a patient (for care plan assignment)
  static String get carePlanCareRequestsEndpoint => '$nursePrefix/care-plans/care-requests';


  // Get specific care plan by ID
  static String carePlanDetailEndpoint(int carePlanId) =>
      '$mobilePrefix/care-plans/$carePlanId';

  // Update care plan
  static String updateCarePlanEndpoint(int carePlanId) =>
      '$nursePrefix/care-plans/$carePlanId';

  // Delete care plan
  static String deleteCarePlanEndpoint(int carePlanId) =>
      '$nursePrefix/care-plans/$carePlanId';

  // Toggle care task completion
  static String toggleCareTaskEndpoint(int carePlanId) =>
      '$nursePrefix/care-plans/$carePlanId/tasks/toggle';

  // Care Plan Entries
  static String carePlanEntriesEndpoint(int carePlanId) =>
      '$mobilePrefix/care-plans/$carePlanId/entries';

  static String createCarePlanEntryEndpoint(int carePlanId) =>
      '$nursePrefix/care-plans/$carePlanId/entries';

  static String carePlanEntryDetailEndpoint(int carePlanId, int entryId) =>
      '$mobilePrefix/care-plans/$carePlanId/entries/$entryId';

  static String updateCarePlanEntryEndpoint(int carePlanId, int entryId) =>
      '$nursePrefix/care-plans/$carePlanId/entries/$entryId';

  static String deleteCarePlanEntryEndpoint(int carePlanId, int entryId) =>
      '$nursePrefix/care-plans/$carePlanId/entries/$entryId';

  // Get all care plan entries for a patient
  static String patientCarePlanEntriesEndpoint(int patientId) =>
      '$mobilePrefix/care-plans/patient/$patientId/entries';

  // ==================== END CARE PLAN ENDPOINTS ====================


  // ==================== CARE REQUEST ENDPOINTS ====================

/// Get care request information and assessment fee
static String get careRequestInfoEndpoint => '$mobilePrefix/care-requests/info';

/// Get all care requests or create new care request
static String get careRequestsEndpoint => '$mobilePrefix/care-requests';

static const String nurseAssignedCareRequestsEndpoint = '$mobilePrefix/care-requests/nurse/assigned-care-requests';

/// Get specific care request details
static String careRequestDetailEndpoint(int requestId) =>
    '$mobilePrefix/care-requests/$requestId';

/// Cancel a care request
static String cancelCareRequestEndpoint(int requestId) =>
    '$mobilePrefix/care-requests/$requestId/cancel';

/// Initiate payment for a care request
static String initiatePaymentEndpoint(int requestId) =>
    '$mobilePrefix/care-requests/$requestId/payment/initiate';

/// Verify payment
static String get verifyPaymentEndpoint => '$mobilePrefix/payments/verify';

// ==================== END CARE REQUEST ENDPOINTS ====================

  // Incident Report endpoints
  static const String incidentsEndpoint = '/api/mobile/nurse/incidents';
  static const String incidentsPatientEndpoint = '/api/mobile/nurse/incidents/patients/list';

  // Transport Request endpoints
  static const String transportRequestsEndpoint = '$mobilePrefix/transport-requests';
  static const String createTransportRequestEndpoint = '$mobilePrefix/transport-requests';
  static const String availableDriversEndpoint = '$mobilePrefix/transport-requests/drivers/available';

  // Get specific transport request
  static String transportRequestDetailEndpoint(int requestId) =>
      '$transportRequestsEndpoint/$requestId';

  // Profile endpoints
  static const String profilePrefix = '/api/mobile/profile';
  
  // Get current user profile (alternative to /api/auth/me)
  static const String getProfileEndpoint = '$profilePrefix';
  
  // Update nurse profile
  static const String updateProfileEndpoint = '$profilePrefix/update';
  
  // Upload profile avatar
  static const String uploadAvatarEndpoint = '$profilePrefix/avatar';
  
  // Change password
  static const String changePasswordEndpoint = '$profilePrefix/change-password';
  
  // Two-factor authentication
  static const String enableTwoFactorEndpoint = '$profilePrefix/enable-2fa';
  static const String disableTwoFactorEndpoint = '$profilePrefix/disable-2fa';
  static const String verifyTwoFactorEndpoint = '$profilePrefix/verify-2fa';
  static const String resendTwoFactorEndpoint = '$profilePrefix/resend-2fa-code';
  
  // Notification settings (Security - for Password & Security screen)
  static const String notificationSettingsEndpoint = '$profilePrefix/notification-settings';
  
  // Notification preferences (Comprehensive - for Notification Preferences screen)
  static const String notificationPreferencesEndpoint = '$profilePrefix/notification-preferences';


  // ==================== PATIENT FEEDBACK ENDPOINTS ====================

static const String feedbackPrefix = '/api/mobile/patient/feedback';

// Get all feedback submitted by the patient
static const String getFeedbackListEndpoint = '$feedbackPrefix';

// Get nurses that can be rated
static const String getNursesForFeedbackEndpoint = '$feedbackPrefix/nurses';

// Submit or update feedback for a nurse
static const String submitFeedbackEndpoint = '$feedbackPrefix';

// Get feedback statistics
static const String getFeedbackStatisticsEndpoint = '$feedbackPrefix/statistics';

// ==================== END PATIENT FEEDBACK ENDPOINTS ====================

// ==================== PAYMENT ENDPOINTS ====================

/// Get Paystack configuration (public key and channels)
static String get paymentConfigEndpoint => '$mobilePrefix/care-requests/payment-config';

/// Initialize payment with Paystack for a care request
static String paystackInitializeEndpoint(int requestId) =>
    '$mobilePrefix/care-requests/$requestId/payment/initiate';

/// Verify Paystack payment
static String get paystackVerifyEndpoint => '$mobilePrefix/care-requests/payment/verify';

/// Get payment history
static String get paymentHistoryEndpoint => '$mobilePrefix/payments/history';

/// Get payment receipt
static String paymentReceiptEndpoint(int paymentId) =>
    '$mobilePrefix/payments/$paymentId/receipt';

/// Get payment details
static String paymentDetailEndpoint(int paymentId) =>
    '$mobilePrefix/payments/$paymentId';

/// Refund payment (admin only)
static String refundPaymentEndpoint(int paymentId) =>
    '$mobilePrefix/payments/$paymentId/refund';

// ==================== END PAYMENT ENDPOINTS ====================

  // ==================== NOTIFICATION ENDPOINTS ====================
  
  /// Register FCM token
  static String get notificationRegisterTokenEndpoint => 
      '$mobilePrefix/notifications/register-token';

  static String get notificationUnregisterTokenEndpoint => 
    '$mobilePrefix/notifications/unregister-token';
  
  /// Get user notifications (paginated)
  static String get notificationsEndpoint => 
      '$mobilePrefix/notifications';
  
  /// Mark notification as read
  static String notificationMarkReadEndpoint(int notificationId) => 
      '$mobilePrefix/notifications/$notificationId/read';
  
  /// Mark all notifications as read
  static String get notificationMarkAllReadEndpoint => 
      '$mobilePrefix/notifications/read-all';
  
  /// Delete notification
  static String notificationDeleteEndpoint(int notificationId) => 
      '$mobilePrefix/notifications/$notificationId';
  
  /// Get unread notification count
  static String get notificationUnreadCountEndpoint => 
      '$mobilePrefix/notifications/unread-count';

  // ====================END NOTIFICATION ENDPOINTS ====================

  // ==================== MESSAGE ENDPOINTS ====================

  /// Messages prefix
  static const String messagesPrefix = '$mobilePrefix/messages';

  /// Get all messages
  static String get messagesEndpoint => messagesPrefix;

  /// Get unread message count
  static String get messagesUnreadCountEndpoint => '$messagesPrefix/unread-count';

  /// Get conversation list
  static String get conversationsEndpoint => '$messagesPrefix/conversations';

  /// Get available contacts for messaging
  static String get messageContactsEndpoint => '$messagesPrefix/contacts';

  /// Get conversation with specific user
  static String conversationWithUserEndpoint(int userId) =>
      '$messagesPrefix/conversation/$userId';

  /// Get specific message
  static String messageDetailEndpoint(int messageId) =>
      '$messagesPrefix/$messageId';

  /// Mark message as read
  static String markMessageReadEndpoint(int messageId) =>
      '$messagesPrefix/$messageId/read';

  /// Mark conversation as read
  static String markConversationReadEndpoint(int userId) =>
      '$messagesPrefix/conversation/$userId/read';

  /// Delete message
  static String deleteMessageEndpoint(int messageId) =>
      '$messagesPrefix/$messageId';

  // ==================== END MESSAGE ENDPOINTS ====================

  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);

  // Helper method to get full avatar URL
  static String getAvatarUrl(String? avatarPath) {
    if (avatarPath == null || avatarPath.isEmpty) {
      return '';
    }
    
    // If it's already a full URL (like ui-avatars.com), return as-is
    if (avatarPath.startsWith('http://') || avatarPath.startsWith('https://')) {
      return avatarPath;
    }
    
    // Otherwise, prepend storage URL
    return '$storageUrl/$avatarPath';
  }

  // Headers
  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'X-Client-Type': 'mobile',
  };

  // Get auth headers with token
  static Map<String, String> authHeaders(String token) => {
    ...headers,
    'Authorization': 'Bearer $token',
  };
}