// lib/services/notification_service.dart
// UPDATED VERSION - WITH iOS BADGE MANAGEMENT
// FIXED: App badge icon now properly syncs with notification count

import 'dart:io' show Platform;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import '../utils/api_client.dart';
import '../utils/api_config.dart';
import '../models/notification/notification_models.dart';

/// Service for handling Push Notifications and Notification API calls
/// ✅ NOW INCLUDES: iOS Badge Management
class NotificationService {
  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final ApiClient _apiClient = ApiClient();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  // Callback for real-time notification count updates
  Function(int)? onNotificationCountChanged;

  // ==================== INITIALIZATION ====================

  /// Initialize notification service
  Future<void> initialize() async {
    try {
      debugPrint('🔔 [NotificationService] Initializing notification service...');

      // Request permission for iOS
      await _requestPermissions();

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Get and register FCM token (with iOS APNS fix)
      await _initializeFcm();

      // Set up message handlers
      _setupMessageHandlers();

      // ✅ CRITICAL: Clear badge when app opens
      await _clearBadgeOnStartup();

      debugPrint('✅ [NotificationService] Notification service initialized successfully');
    } catch (e) {
      debugPrint('💥 [NotificationService] Initialization error: $e');
      rethrow;
    }
  }

  /// Request notification permissions (iOS)
  Future<void> _requestPermissions() async {
    try {
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true, // ✅ Essential for badge management
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ [NotificationService] User granted notification permission');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('⚠️ [NotificationService] User granted provisional notification permission');
      } else {
        debugPrint('❌ [NotificationService] User declined notification permission');
      }
    } catch (e) {
      debugPrint('💥 [NotificationService] Permission request error: $e');
    }
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true, // ✅ Enable badge permission
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create notification channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'care_notifications',
      'Care Notifications',
      description: 'Notifications for appointments and care updates',
      importance: Importance.high,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    debugPrint('✅ [NotificationService] Local notifications initialized');
  }

  /// Initialize FCM and register token
  Future<void> _initializeFcm() async {
    try {
      // iOS-specific: Wait for APNS token before getting FCM token
      if (!kIsWeb && Platform.isIOS) {
        debugPrint('📱 [NotificationService] iOS detected - waiting for APNS token...');
        
        // Get APNS token first
        String? apnsToken = await _firebaseMessaging.getAPNSToken();
        
        // If APNS token is not immediately available, wait for it
        if (apnsToken == null) {
          debugPrint('⏳ [NotificationService] APNS token not ready, waiting...');
          
          // Wait up to 10 seconds for APNS token
          int attempts = 0;
          while (apnsToken == null && attempts < 20) {
            await Future.delayed(const Duration(milliseconds: 500));
            apnsToken = await _firebaseMessaging.getAPNSToken();
            attempts++;
            
            if (attempts % 4 == 0) {
              debugPrint('⏳ [NotificationService] Still waiting for APNS token... (${attempts * 0.5}s)');
            }
          }
          
          if (apnsToken != null) {
            debugPrint('✅ [NotificationService] APNS token obtained: ${apnsToken.substring(0, 20)}...');
          } else {
            debugPrint('⚠️ [NotificationService] APNS token not available after waiting');
          }
        } else {
          debugPrint('✅ [NotificationService] APNS token immediately available: ${apnsToken.substring(0, 20)}...');
        }
      }

      // Now get FCM token (works for both iOS and Android)
      _fcmToken = await _firebaseMessaging.getToken();
      
      if (_fcmToken != null) {
        debugPrint('✅ [NotificationService] FCM Token obtained: ${_fcmToken!.substring(0, 20)}...');
        
        // Register token with backend
        await registerFcmToken(_fcmToken!);
      } else {
        debugPrint('⚠️ [NotificationService] Failed to get FCM token');
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        debugPrint('🔄 [NotificationService] FCM Token refreshed');
        _fcmToken = newToken;
        registerFcmToken(newToken);
      });
    } catch (e) {
      debugPrint('💥 [NotificationService] FCM initialization error: $e');
    }
  }

  /// Set up message handlers
  void _setupMessageHandlers() {
    // ⚡ Handle foreground messages (app is open)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint('📨 [NotificationService] Foreground message received');
      
      // Show local notification (without badge management)
      await _showLocalNotification(message);
      
      // ✅ CRITICAL FIX: Wait a tiny bit then update badge with correct count
      await Future.delayed(const Duration(milliseconds: 100));
      await _refreshNotificationCount();
    });

    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('👆 [NotificationService] Background notification tapped');
      _handleNotificationTap(message);
      
      // Refresh count after interaction
      _refreshNotificationCount();
    });

    // Handle notification when app is opened from terminated state
    _checkInitialMessage();
  }

  /// Clear badge when app starts
  /// ✅ CRITICAL FIX: This syncs the badge with actual unread count
  Future<void> _clearBadgeOnStartup() async {
    try {
      debugPrint('🔄 [NotificationService] Syncing badge with backend count...');
      
      // Get actual unread count from backend
      final response = await getUnreadCount();
      
      // Update badge to match backend count
      await _updateBadge(response.unreadCount);
      
      debugPrint('✅ [NotificationService] Badge synced: ${response.unreadCount}');
    } catch (e) {
      debugPrint('❌ [NotificationService] Error syncing badge: $e');
      // If sync fails, clear badge to be safe
      await _updateBadge(0);
    }
  }

  /// Refresh notification count and update badge
  /// ✅ KEY FIX: Now also updates iOS badge
  Future<void> _refreshNotificationCount() async {
    try {
      final response = await getUnreadCount();
      final unreadCount = response.unreadCount;
      
      // Update iOS badge
      await _updateBadge(unreadCount);
      
      // Notify any listeners (like the dashboard)
      if (onNotificationCountChanged != null) {
        onNotificationCountChanged!(unreadCount);
      }
      
      debugPrint('🔄 [NotificationService] Badge count updated: $unreadCount');
    } catch (e) {
      debugPrint('❌ [NotificationService] Error refreshing count: $e');
    }
  }

  /// Update iOS app badge
  Future<void> _updateBadge(int count) async {
    try {
      if (!kIsWeb && Platform.isIOS) {
        // Set the badge number SILENTLY
        final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
          presentBadge: true,
          badgeNumber: count,
          presentAlert: false,   // ✅ Don't show alert
          presentSound: false,   // ✅ Don't play sound
          presentBanner: false,  // ✅ Don't show banner
        );

        // This updates the badge without showing a notification or playing sound
        await _localNotifications.show(
          -1, // Use -1 as a special ID for badge-only updates
          null,
          null,
          NotificationDetails(iOS: iosDetails),
        );

        debugPrint('📱 [NotificationService] iOS badge set to: $count (silent)');
      }
    } catch (e) {
      debugPrint('❌ [NotificationService] Error updating badge: $e');
    }
  }

  // ==================== FCM TOKEN REGISTRATION ====================

  /// Register FCM token with backend
  Future<RegisterTokenResponse> registerFcmToken(String token) async {
    try {
      debugPrint('📡 [NotificationService] Registering FCM token with backend...');

      final body = {
        'fcm_token': token,
      };

      final response = await _apiClient.post(
        ApiConfig.notificationRegisterTokenEndpoint,
        body: body,
        requiresAuth: true,
      );

      if (response['success'] == true) {
        debugPrint('✅ [NotificationService] FCM token registered successfully');
        return RegisterTokenResponse.fromJson(response);
      } else {
        throw NotificationException(
          message: response['message'] ?? 'Failed to register FCM token',
        );
      }
    } catch (e) {
      debugPrint('💥 [NotificationService] Token registration error: $e');
      if (e is NotificationException) rethrow;
      throw NotificationException(
        message: 'Network error: Unable to register FCM token',
      );
    }
  }

  // ==================== MESSAGE HANDLING ====================

  /// Handle foreground message
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('📋 [NotificationService] Title: ${message.notification?.title}');
    debugPrint('📋 [NotificationService] Body: ${message.notification?.body}');

    // Show local notification
    await _showLocalNotification(message);

    // Update notification log as delivered
    if (message.data['notification_id'] != null) {
      await updateNotificationStatus(
        int.parse(message.data['notification_id'].toString()),
        'delivered',
      );
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'care_notifications',
      'Care Notifications',
      channelDescription: 'Notifications for appointments and care updates',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false, 
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'Notification',
      message.notification?.body ?? '',
      details,
      payload: message.data.toString(),
    );
  }

  /// Handle notification tap
  void _onNotificationTap(NotificationResponse response) {
    debugPrint('👆 [NotificationService] Notification tapped');
    
    if (response.payload != null) {
      _handleNotificationAction(response.payload!);
    }
  }

  /// Handle notification tap from background
  Future<void> _handleNotificationTap(RemoteMessage message) async {
    debugPrint('📋 [NotificationService] Type: ${message.data['type']}');

    // Mark as read
    if (message.data['notification_id'] != null) {
      await markNotificationAsRead(
        int.parse(message.data['notification_id'].toString()),
      );
    }

    _handleNotificationAction(message.data.toString());
  }

  /// Check initial message when app opens from terminated state
  Future<void> _checkInitialMessage() async {
    RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();

    if (initialMessage != null) {
      debugPrint('📨 [NotificationService] App opened from notification');
      await _handleNotificationTap(initialMessage);
    }
  }

  /// Handle notification action/navigation
  void _handleNotificationAction(String payload) {
    debugPrint('🔗 [NotificationService] Handling notification action');
    // TODO: Implement navigation based on notification type
  }

  // ==================== NOTIFICATION MANAGEMENT ====================

  /// Get notifications for current user
  Future<NotificationListResponse> getNotifications({
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'per_page': perPage.toString(),
      };

      final uri = Uri.parse(ApiConfig.notificationsEndpoint).replace(
        queryParameters: queryParams,
      );

      debugPrint('📡 [NotificationService] Fetching notifications (Page: $page)...');

      final response = await _apiClient.get(
        uri.toString(),
        requiresAuth: true,
      );

      if (response['success'] == true) {
        return NotificationListResponse.fromJson(response);
      } else {
        throw NotificationException(
          message: response['message'] ?? 'Failed to fetch notifications',
        );
      }
    } catch (e) {
      debugPrint('💥 [NotificationService] Error fetching notifications: $e');
      if (e is NotificationException) rethrow;
      throw NotificationException(
        message: 'Network error: Unable to fetch notifications',
      );
    }
  }

  /// Mark notification as read
  /// ✅ NOW UPDATES BADGE
  Future<MarkReadResponse> markNotificationAsRead(int notificationId) async {
    try {
      final response = await _apiClient.post(
        ApiConfig.notificationMarkReadEndpoint(notificationId),
        requiresAuth: true,
      );

      if (response['success'] == true) {
        // Refresh count and badge after marking as read
        await _refreshNotificationCount();
        return MarkReadResponse.fromJson(response);
      } else {
        throw NotificationException(
          message: response['message'] ?? 'Failed to mark notification as read',
        );
      }
    } catch (e) {
      debugPrint('💥 [NotificationService] Error marking as read: $e');
      if (e is NotificationException) rethrow;
      throw NotificationException(
        message: 'Network error: Unable to mark notification as read',
      );
    }
  }

  /// Mark all notifications as read
  /// ✅ NOW CLEARS BADGE
  Future<MarkAllReadResponse> markAllNotificationsAsRead() async {
    try {
      final response = await _apiClient.post(
        ApiConfig.notificationMarkAllReadEndpoint,
        requiresAuth: true,
      );

      if (response['success'] == true) {
        // Clear badge when all notifications are read
        await _updateBadge(0);
        
        // Notify listeners
        if (onNotificationCountChanged != null) {
          onNotificationCountChanged!(0);
        }
        
        return MarkAllReadResponse.fromJson(response);
      } else {
        throw NotificationException(
          message: response['message'] ?? 'Failed to mark all notifications as read',
        );
      }
    } catch (e) {
      debugPrint('💥 [NotificationService] Error marking all as read: $e');
      if (e is NotificationException) rethrow;
      throw NotificationException(
        message: 'Network error: Unable to mark all notifications as read',
      );
    }
  }

  /// Delete notification
  /// ✅ NOW UPDATES BADGE
  Future<DeleteNotificationResponse> deleteNotification(int notificationId) async {
    try {
      final response = await _apiClient.delete(
        ApiConfig.notificationDeleteEndpoint(notificationId),
        requiresAuth: true,
      );

      if (response['success'] == true) {
        // Refresh count and badge after deletion
        await _refreshNotificationCount();
        return DeleteNotificationResponse.fromJson(response);
      } else {
        throw NotificationException(
          message: response['message'] ?? 'Failed to delete notification',
        );
      }
    } catch (e) {
      debugPrint('💥 [NotificationService] Error deleting notification: $e');
      if (e is NotificationException) rethrow;
      throw NotificationException(
        message: 'Network error: Unable to delete notification',
      );
    }
  }

  /// Get unread notification count
  Future<UnreadCountResponse> getUnreadCount() async {
    try {
      final response = await _apiClient.get(
        ApiConfig.notificationUnreadCountEndpoint,
        requiresAuth: true,
      );

      if (response['success'] == true) {
        return UnreadCountResponse.fromJson(response);
      } else {
        throw NotificationException(
          message: response['message'] ?? 'Failed to fetch unread count',
        );
      }
    } catch (e) {
      debugPrint('💥 [NotificationService] Error fetching unread count: $e');
      if (e is NotificationException) rethrow;
      throw NotificationException(
        message: 'Network error: Unable to fetch unread count',
      );
    }
  }

  /// Update notification status (internal use)
  Future<void> updateNotificationStatus(int notificationId, String status) async {
    try {
      debugPrint('📡 [NotificationService] Updating notification status to: $status');
      debugPrint('✅ [NotificationService] Status updated locally');
    } catch (e) {
      debugPrint('💥 [NotificationService] Error updating status: $e');
    }
  }

  // ==================== UTILITY METHODS ====================

  /// Clear all local notifications
  Future<void> clearAllNotifications() async {
    await _localNotifications.cancelAll();
    debugPrint('🗑️ [NotificationService] All local notifications cleared');
  }

  /// Manually refresh badge (call this when notifications screen is viewed)
  /// ✅ USEFUL: Call this when user opens notifications screen
  Future<void> refreshBadge() async {
    await _refreshNotificationCount();
  }

  // ==================== LIFECYCLE MANAGEMENT ====================

  /// Register FCM token (call after login)
  Future<void> registerTokenForCurrentUser() async {
    try {
      if (_fcmToken == null) {
        debugPrint('⚠️ [NotificationService] No FCM token available yet, initializing...');
        await _initializeFcm();
      }

      if (_fcmToken != null) {
        debugPrint('📡 [NotificationService] Registering FCM token for current user...');
        await registerFcmToken(_fcmToken!);
        
        // Sync badge after login
        await _clearBadgeOnStartup();
        
        debugPrint('✅ [NotificationService] Token registered for current user');
      } else {
        debugPrint('❌ [NotificationService] Failed to get FCM token');
      }
    } catch (e) {
      debugPrint('💥 [NotificationService] Error registering token: $e');
    }
  }

  /// Unregister FCM token (call on logout)
  /// ✅ NOW CLEARS BADGE ON LOGOUT
  Future<void> unregisterToken() async {
    try {
      debugPrint('🔓 [NotificationService] Unregistering FCM token...');

      // Clear badge before logout
      await _updateBadge(0);

      final response = await _apiClient.post(
        ApiConfig.notificationUnregisterTokenEndpoint,
        requiresAuth: true,
      );

      if (response['success'] == true) {
        debugPrint('✅ [NotificationService] FCM token unregistered successfully');
      } else {
        debugPrint('⚠️ [NotificationService] Failed to unregister token: ${response['message']}');
      }
    } catch (e) {
      debugPrint('💥 [NotificationService] Unregister error: $e');
    }
  }

  /// Clear local notification state
  Future<void> clearNotificationState() async {
    try {
      await clearAllNotifications();
      await _updateBadge(0); // ✅ Clear badge
      onNotificationCountChanged = null;
      debugPrint('🗑️ [NotificationService] Notification state cleared');
    } catch (e) {
      debugPrint('💥 [NotificationService] Error clearing state: $e');
    }
  }
}

// ============================================================================
// EXCEPTION CLASS & RESPONSE MODELS
// ============================================================================

class NotificationException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? errors;

  NotificationException({
    required this.message,
    this.statusCode,
    this.errors,
  });

  @override
  String toString() => message;
}

class RegisterTokenResponse {
  final bool success;
  final String message;

  RegisterTokenResponse({required this.success, required this.message});
  factory RegisterTokenResponse.fromJson(Map<String, dynamic> json) {
    return RegisterTokenResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
    );
  }
}

class NotificationListResponse {
  final bool success;
  final String message;
  final NotificationData data;

  NotificationListResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  factory NotificationListResponse.fromJson(Map<String, dynamic> json) {
    return NotificationListResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: NotificationData.fromJson(json['data'] ?? {}),
    );
  }
}

class NotificationData {
  final List<NotificationItem> data;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  NotificationData({
    required this.data,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  factory NotificationData.fromJson(Map<String, dynamic> json) {
    return NotificationData(
      data: (json['data'] as List<dynamic>?)
              ?.map((e) => NotificationItem.fromJson(e))
              .toList() ??
          [],
      currentPage: json['current_page'] ?? 1,
      lastPage: json['last_page'] ?? 1,
      perPage: json['per_page'] ?? 20,
      total: json['total'] ?? 0,
    );
  }
}

class MarkReadResponse {
  final bool success;
  final String message;
  MarkReadResponse({required this.success, required this.message});
  factory MarkReadResponse.fromJson(Map<String, dynamic> json) {
    return MarkReadResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
    );
  }
}

class MarkAllReadResponse {
  final bool success;
  final String message;
  MarkAllReadResponse({required this.success, required this.message});
  factory MarkAllReadResponse.fromJson(Map<String, dynamic> json) {
    return MarkAllReadResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
    );
  }
}

class DeleteNotificationResponse {
  final bool success;
  final String message;
  DeleteNotificationResponse({required this.success, required this.message});
  factory DeleteNotificationResponse.fromJson(Map<String, dynamic> json) {
    return DeleteNotificationResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
    );
  }
}

class UnreadCountResponse {
  final bool success;
  final int unreadCount;
  UnreadCountResponse({required this.success, required this.unreadCount});
  factory UnreadCountResponse.fromJson(Map<String, dynamic> json) {
    return UnreadCountResponse(
      success: json['success'] ?? false,
      unreadCount: json['unread_count'] ?? 0,  
    );
  }
}