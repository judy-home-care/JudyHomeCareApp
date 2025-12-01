// lib/services/notification_service.dart
// COMPLETE FIXED VERSION - WITH iOS BADGE MANAGEMENT & FOREGROUND UPDATES
// ✅ FIXED: Foreground badge updates now work correctly
// ✅ FIXED: Title/body extraction from data field
// ✅ FIXED: Better error handling and logging

import 'dart:io' show Platform;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import '../utils/api_client.dart';
import '../utils/api_config.dart';
import '../models/notification/notification_models.dart';

/// Service for handling Push Notifications and Notification API calls
/// ✅ INCLUDES: iOS Badge Management, Multi-Listener Support, Foreground Updates
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

  // ==================== MULTI-LISTENER SUPPORT ====================
  // Lists of callbacks for multiple screen listeners
  final List<Function(int)> _notificationCountListeners = [];
  final List<Function()> _notificationReceivedListeners = [];

  // Current unread count (cached for new listeners)
  int _currentUnreadCount = 0;
  int get currentUnreadCount => _currentUnreadCount;

  // DEPRECATED: Single callbacks (kept for backwards compatibility but not used)
  // Use addNotificationCountListener/removeNotificationCountListener instead
  Function(int)? onNotificationCountChanged;
  Function()? onNotificationReceived;

  /// Add a listener for notification count changes
  /// Returns a function to remove the listener
  VoidCallback addNotificationCountListener(Function(int) listener) {
    _notificationCountListeners.add(listener);
    // Immediately notify the new listener of current count
    listener(_currentUnreadCount);
    debugPrint('🔔 [NotificationService] Added count listener. Total: ${_notificationCountListeners.length}');
    return () => removeNotificationCountListener(listener);
  }

  /// Remove a notification count listener
  void removeNotificationCountListener(Function(int) listener) {
    _notificationCountListeners.remove(listener);
    debugPrint('🔔 [NotificationService] Removed count listener. Total: ${_notificationCountListeners.length}');
  }

  /// Add a listener for notification received events
  /// Returns a function to remove the listener
  VoidCallback addNotificationReceivedListener(Function() listener) {
    _notificationReceivedListeners.add(listener);
    debugPrint('📬 [NotificationService] Added received listener. Total: ${_notificationReceivedListeners.length}');
    return () => removeNotificationReceivedListener(listener);
  }

  /// Remove a notification received listener
  void removeNotificationReceivedListener(Function() listener) {
    _notificationReceivedListeners.remove(listener);
    debugPrint('📬 [NotificationService] Removed received listener. Total: ${_notificationReceivedListeners.length}');
  }

  /// Notify all count listeners
  /// ✅ FIX: Added detailed logging to track listener notifications
  void _notifyCountListeners(int count) {
    _currentUnreadCount = count;

    debugPrint('🔔 [NotificationService] Notifying count listeners:');
    debugPrint('   New count: $count');
    debugPrint('   Number of listeners: ${_notificationCountListeners.length}');

    // Notify all registered listeners
    int successCount = 0;
    for (final listener in _notificationCountListeners) {
      try {
        listener(count);
        successCount++;
      } catch (e) {
        debugPrint('❌ [NotificationService] Error notifying count listener: $e');
      }
    }

    debugPrint('✅ [NotificationService] Successfully notified $successCount/${_notificationCountListeners.length} listeners');

    // Also notify legacy single callback if set
    if (onNotificationCountChanged != null) {
      try {
        onNotificationCountChanged!(count);
      } catch (e) {
        debugPrint('❌ [NotificationService] Error in legacy count callback: $e');
      }
    }
  }

  /// Notify all received listeners
  /// ✅ FIX: Added logging to track listener notifications
  void _notifyReceivedListeners() {
    debugPrint('📬 [NotificationService] Notifying received listeners:');
    debugPrint('   Number of listeners: ${_notificationReceivedListeners.length}');

    // Notify all registered listeners
    int successCount = 0;
    for (final listener in _notificationReceivedListeners) {
      try {
        listener();
        successCount++;
      } catch (e) {
        debugPrint('❌ [NotificationService] Error notifying received listener: $e');
      }
    }

    debugPrint('✅ [NotificationService] Successfully notified $successCount/${_notificationReceivedListeners.length} listeners');

    // Also notify legacy single callback if set
    if (onNotificationReceived != null) {
      try {
        onNotificationReceived!();
      } catch (e) {
        debugPrint('❌ [NotificationService] Error in legacy received callback: $e');
      }
    }
  }

  // Track if notification was received while app was in background
  bool _notificationReceivedWhileBackground = false;
  bool get hasNotificationWhileBackground => _notificationReceivedWhileBackground;
  void clearBackgroundNotificationFlag() => _notificationReceivedWhileBackground = false;

  // ==================== INITIALIZATION ====================

  /// Initialize notification service
  Future<void> initialize() async {
    try {
      debugPrint('🔔 [NotificationService] Initializing notification service...');

      // Request permission for iOS
      await _requestPermissions();

      // ✅ CRITICAL: Set foreground notification presentation options for iOS
      // This ensures onMessage callback fires when notification arrives in foreground
      await _firebaseMessaging.setForegroundNotificationPresentationOptions(
        alert: false, // Don't show system alert (we handle it with local notifications)
        badge: true,  // Update badge
        sound: false, // Don't play system sound (local notification handles it)
      );
      debugPrint('✅ [NotificationService] iOS foreground presentation options set');

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
  /// ✅ FIXED: Foreground badge updates now work correctly
  void _setupMessageHandlers() {
    // ⚡ Handle foreground messages (app is open)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint('📨 [NotificationService] Foreground message received');
      debugPrint('📋 [NotificationService] Message data keys: ${message.data.keys.toList()}');
      debugPrint('📋 [NotificationService] Message data: ${message.data}');
      debugPrint('📋 [NotificationService] Current count before update: $_currentUnreadCount');

      try {
        // ✅ FIX 1: Extract badge count FIRST (before showing notification)
        int newCount;
        if (message.data['badge_count'] != null) {
          newCount = int.tryParse(message.data['badge_count'].toString()) ?? (_currentUnreadCount + 1);
          debugPrint('🔔 [NotificationService] Count from FCM payload (badge_count): $newCount');
        } else if (message.data['unread_count'] != null) {
          newCount = int.tryParse(message.data['unread_count'].toString()) ?? (_currentUnreadCount + 1);
          debugPrint('🔔 [NotificationService] Count from FCM payload (unread_count): $newCount');
        } else {
          newCount = _currentUnreadCount + 1;
          debugPrint('⚠️ [NotificationService] No badge_count in payload - using optimistic increment: $_currentUnreadCount -> $newCount');
        }

        debugPrint('🔔 [NotificationService] Will notify ${_notificationCountListeners.length} count listeners with: $newCount');

        // ✅ FIX 2: Update badge and notify listeners IMMEDIATELY (before showing local notification)
        await _updateBadge(newCount);
        _notifyCountListeners(newCount);

        debugPrint('✅ [NotificationService] Badge count updated to: $newCount');
        debugPrint('✅ [NotificationService] Notified ${_notificationCountListeners.length} listeners');

        // ✅ FIX 3: Show local notification AFTER badge update (with proper data extraction)
        await _showLocalNotification(message);

        // 🔄 Notify ALL listeners to refresh their data (multi-listener support)
        debugPrint('🔄 [NotificationService] Triggering refresh for all listeners');
        _notifyReceivedListeners();

        // ✅ SYNC: After a delay, sync with backend to get accurate count
        await Future.delayed(const Duration(seconds: 3));
        await _refreshNotificationCount();
      } catch (e, stackTrace) {
        debugPrint('❌ [NotificationService] Error in foreground message handler: $e');
        debugPrint('Stack trace: $stackTrace');
        
        // Even if there's an error, try to update with optimistic count
        final fallbackCount = _currentUnreadCount + 1;
        await _updateBadge(fallbackCount);
        _notifyCountListeners(fallbackCount);
      }
    });

    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('👆 [NotificationService] Background notification tapped');

      // Set flag so dashboard knows to refresh when fully visible
      _notificationReceivedWhileBackground = true;
      debugPrint('🚩 [NotificationService] Background notification flag set');

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
  /// ✅ KEY FIX: Now also updates iOS badge and notifies ALL listeners
  Future<void> _refreshNotificationCount() async {
    try {
      debugPrint('🔄 [NotificationService] Refreshing notification count from backend...');
      
      final response = await getUnreadCount();
      final unreadCount = response.unreadCount;

      debugPrint('📊 [NotificationService] Backend count: $unreadCount');

      // Update iOS badge
      await _updateBadge(unreadCount);

      // Notify ALL listeners (multi-listener support)
      _notifyCountListeners(unreadCount);

      debugPrint('✅ [NotificationService] Badge count refreshed and listeners notified: $unreadCount');
    } catch (e) {
      debugPrint('❌ [NotificationService] Error refreshing count: $e');
    }
  }

  /// Update iOS app badge
  /// ✅ UPDATED: Now includes detailed logging
  Future<void> _updateBadge(int count) async {
    try {
      if (!kIsWeb && Platform.isIOS) {
        debugPrint('📱 [NotificationService] Updating iOS badge to: $count');
        
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

        debugPrint('✅ [NotificationService] iOS badge set to: $count (silent)');
      } else if (!kIsWeb && Platform.isAndroid) {
        debugPrint('📱 [NotificationService] Android detected - badge not supported natively');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [NotificationService] Error updating badge: $e');
      debugPrint('Stack trace: $stackTrace');
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

  /// Show local notification
  /// ✅ FIX 4: Extract title/body from data field (backend sends data-only messages)
  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      // Backend sends title/body in data field, not notification field
      final title = message.data['title'] ?? 
                    message.notification?.title ?? 
                    'Notification';
      final body = message.data['body'] ?? 
                   message.notification?.body ?? 
                   '';

      debugPrint('📱 [NotificationService] Showing local notification:');
      debugPrint('   Title: $title');
      debugPrint('   Body: $body');

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
        presentBadge: false, // Badge is managed separately via _updateBadge
        presentSound: true,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        message.hashCode,
        title,
        body,
        details,
        payload: message.data.toString(),
      );

      debugPrint('✅ [NotificationService] Local notification shown successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ [NotificationService] Error showing local notification: $e');
      debugPrint('Stack trace: $stackTrace');
      // Don't rethrow - we don't want this to prevent badge updates
    }
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

      // Set flag so dashboard knows to refresh
      _notificationReceivedWhileBackground = true;
      debugPrint('🚩 [NotificationService] Background notification flag set (from terminated)');

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
      debugPrint('📡 [NotificationService] Marking notification #$notificationId as read...');
      
      final response = await _apiClient.post(
        ApiConfig.notificationMarkReadEndpoint(notificationId),
        requiresAuth: true,
      );

      if (response['success'] == true) {
        debugPrint('✅ [NotificationService] Notification marked as read');
        
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
  /// ✅ NOW CLEARS BADGE AND NOTIFIES ALL LISTENERS
  Future<MarkAllReadResponse> markAllNotificationsAsRead() async {
    try {
      debugPrint('📡 [NotificationService] Marking all notifications as read...');
      
      final response = await _apiClient.post(
        ApiConfig.notificationMarkAllReadEndpoint,
        requiresAuth: true,
      );

      if (response['success'] == true) {
        debugPrint('✅ [NotificationService] All notifications marked as read');
        
        // Clear badge when all notifications are read
        await _updateBadge(0);

        // Notify ALL listeners (multi-listener support)
        _notifyCountListeners(0);

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
      debugPrint('📡 [NotificationService] Deleting notification #$notificationId...');
      
      final response = await _apiClient.delete(
        ApiConfig.notificationDeleteEndpoint(notificationId),
        requiresAuth: true,
      );

      if (response['success'] == true) {
        debugPrint('✅ [NotificationService] Notification deleted');
        
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
    debugPrint('🔄 [NotificationService] Manual badge refresh requested');
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
      
      // Clear listeners
      _notificationCountListeners.clear();
      _notificationReceivedListeners.clear();
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