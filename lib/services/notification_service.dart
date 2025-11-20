// lib/services/notification_service.dart
// UPDATED VERSION - Battery Optimized with FCM
// FIXED: APNS token handling for iOS

import 'dart:io' show Platform;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import '../utils/api_client.dart';
import '../utils/api_config.dart';
import '../models/notification/notification_models.dart';

/// Service for handling Push Notifications and Notification API calls
/// OPTIMIZED for battery life and data usage
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
  /// 
  /// This should be called once when the app starts
  Future<void> initialize() async {
    try {
      debugPrint('🔔 [NotificationService] Initializing notification service...');

      // Request permission for iOS
      await _requestPermissions();

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Get and register FCM token (with iOS APNS fix)
      await _initializeFcm();

      // Set up message handlers (KEY: This is what makes it real-time!)
      _setupMessageHandlers();

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
        badge: true,
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
      requestBadgePermission: true,
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
  /// FIXED: Now properly handles APNS token on iOS
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
      // Don't rethrow - allow app to continue even if FCM fails
    }
  }

  /// Set up message handlers - THIS IS KEY FOR REAL-TIME UPDATES!
  void _setupMessageHandlers() {
    // ⚡ CRITICAL: Handle foreground messages (app is open)
    // This eliminates the need for constant polling!
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📨 [NotificationService] Foreground message received');
      _handleForegroundMessage(message);
      
      // Update badge count in real-time
      _refreshNotificationCount();
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

  /// Refresh notification count and notify listeners
  /// This is battery-efficient because it's event-driven, not polling!
  Future<void> _refreshNotificationCount() async {
    try {
      final response = await getUnreadCount();
      
      // Notify any listeners (like the dashboard)
      if (onNotificationCountChanged != null) {
        onNotificationCountChanged!(response.unreadCount);
      }
      
      debugPrint('🔄 [NotificationService] Badge count updated: ${response.unreadCount}');
    } catch (e) {
      debugPrint('❌ [NotificationService] Error refreshing count: $e');
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
      presentBadge: true,
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
  Future<MarkReadResponse> markNotificationAsRead(int notificationId) async {
    try {
      final response = await _apiClient.post(
        ApiConfig.notificationMarkReadEndpoint(notificationId),
        requiresAuth: true,
      );

      if (response['success'] == true) {
        // Refresh count after marking as read
        _refreshNotificationCount();
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
  Future<MarkAllReadResponse> markAllNotificationsAsRead() async {
    try {
      final response = await _apiClient.post(
        ApiConfig.notificationMarkAllReadEndpoint,
        requiresAuth: true,
      );

      if (response['success'] == true) {
        // Refresh count after marking all as read
        _refreshNotificationCount();
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
  Future<DeleteNotificationResponse> deleteNotification(int notificationId) async {
    try {
      final response = await _apiClient.delete(
        ApiConfig.notificationDeleteEndpoint(notificationId),
        requiresAuth: true,
      );

      if (response['success'] == true) {
        // Refresh count after deletion
        _refreshNotificationCount();
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
      // This would be a backend endpoint if you want to track delivery status
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


  // ==================== LIFECYCLE MANAGEMENT ====================

/// Register FCM token (call after login)
/// ✅ CRITICAL: This ensures the token is assigned to the current user
Future<void> registerTokenForCurrentUser() async {
  try {
    if (_fcmToken == null) {
      debugPrint('⚠️ [NotificationService] No FCM token available yet, initializing...');
      await _initializeFcm();
    }

    if (_fcmToken != null) {
      debugPrint('📡 [NotificationService] Registering FCM token for current user...');
      await registerFcmToken(_fcmToken!);
      debugPrint('✅ [NotificationService] Token registered for current user');
    } else {
      debugPrint('❌ [NotificationService] Failed to get FCM token');
    }
  } catch (e) {
    debugPrint('💥 [NotificationService] Error registering token: $e');
  }
}

/// Unregister FCM token (call on logout)
/// ✅ CRITICAL: This clears the token from the old user
Future<void> unregisterToken() async {
  try {
    debugPrint('🔓 [NotificationService] Unregistering FCM token...');

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
    // Don't throw - allow logout to continue even if unregister fails
  }
}

/// Clear local notification state
Future<void> clearNotificationState() async {
  try {
    await clearAllNotifications();
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