// lib/services/messages/message_service.dart
// Service for handling message API calls

import 'package:flutter/foundation.dart';
import '../../utils/api_client.dart';
import '../../utils/api_config.dart';
import '../../models/messages/message_models.dart';

/// Service for handling messaging functionality
class MessageService {
  final ApiClient _apiClient = ApiClient();

  // ==================== CONVERSATION LIST ====================

  /// Get list of conversations
  Future<ConversationListResponse> getConversations() async {
    try {
      debugPrint('📡 [MessageService] Fetching conversations...');

      final response = await _apiClient.get(
        ApiConfig.conversationsEndpoint,
        requiresAuth: true,
      );

      if (response['success'] == true) {
        debugPrint('✅ [MessageService] Conversations fetched successfully');
        return ConversationListResponse.fromJson(response);
      } else {
        throw MessageException(
          message: response['message'] ?? 'Failed to fetch conversations',
        );
      }
    } catch (e) {
      debugPrint('❌ [MessageService] Error fetching conversations: $e');
      if (e is MessageException) rethrow;
      throw MessageException(
        message: 'Network error: Unable to fetch conversations',
      );
    }
  }

  // ==================== CONVERSATION ====================

  /// Get conversation with a specific user
  /// [page] - Page number for pagination (1-indexed)
  /// [perPage] - Number of messages per page
  Future<ConversationResponse> getConversation(
    int userId, {
    int page = 1,
    int perPage = 30,
  }) async {
    try {
      debugPrint('📡 [MessageService] Fetching conversation with user $userId (page: $page)...');

      final uri = Uri.parse(ApiConfig.conversationWithUserEndpoint(userId)).replace(
        queryParameters: {
          'page': page.toString(),
          'per_page': perPage.toString(),
        },
      );

      final response = await _apiClient.get(
        uri.toString(),
        requiresAuth: true,
      );

      if (response['success'] == true) {
        debugPrint('✅ [MessageService] Conversation fetched successfully (page: $page)');
        return ConversationResponse.fromJson(response);
      } else {
        throw MessageException(
          message: response['message'] ?? 'Failed to fetch conversation',
        );
      }
    } catch (e) {
      debugPrint('❌ [MessageService] Error fetching conversation: $e');
      if (e is MessageException) rethrow;
      throw MessageException(
        message: 'Network error: Unable to fetch conversation',
      );
    }
  }

  // ==================== SEND MESSAGE ====================

  /// Send a new message
  Future<SendMessageResponse> sendMessage({
    required int receiverId,
    required String message,
    String? subject,
    String messageType = 'general',
    int? careRequestId,
  }) async {
    try {
      debugPrint('📡 [MessageService] Sending message to user $receiverId...');

      final body = {
        'receiver_id': receiverId,
        'message': message,
        if (subject != null) 'subject': subject,
        'message_type': messageType,
        if (careRequestId != null) 'care_request_id': careRequestId,
      };

      final response = await _apiClient.post(
        ApiConfig.messagesEndpoint,
        body: body,
        requiresAuth: true,
      );

      if (response['success'] == true) {
        debugPrint('✅ [MessageService] Message sent successfully');
        return SendMessageResponse.fromJson(response);
      } else {
        throw MessageException(
          message: response['message'] ?? 'Failed to send message',
        );
      }
    } catch (e) {
      debugPrint('❌ [MessageService] Error sending message: $e');
      if (e is MessageException) rethrow;
      throw MessageException(
        message: 'Network error: Unable to send message',
      );
    }
  }

  // ==================== CONTACTS ====================

  /// Get available contacts for messaging
  Future<ContactsResponse> getContacts() async {
    try {
      debugPrint('📡 [MessageService] Fetching contacts...');

      final response = await _apiClient.get(
        ApiConfig.messageContactsEndpoint,
        requiresAuth: true,
      );

      if (response['success'] == true) {
        debugPrint('✅ [MessageService] Contacts fetched successfully');
        return ContactsResponse.fromJson(response);
      } else {
        throw MessageException(
          message: response['message'] ?? 'Failed to fetch contacts',
        );
      }
    } catch (e) {
      debugPrint('❌ [MessageService] Error fetching contacts: $e');
      if (e is MessageException) rethrow;
      throw MessageException(
        message: 'Network error: Unable to fetch contacts',
      );
    }
  }

  // ==================== UNREAD COUNT ====================

  /// Get unread message count
  Future<UnreadCountResponse> getUnreadCount() async {
    try {
      debugPrint('📡 [MessageService] Fetching unread count...');

      final response = await _apiClient.get(
        ApiConfig.messagesUnreadCountEndpoint,
        requiresAuth: true,
      );

      if (response['success'] == true) {
        debugPrint('✅ [MessageService] Unread count fetched');
        return UnreadCountResponse.fromJson(response);
      } else {
        throw MessageException(
          message: response['message'] ?? 'Failed to fetch unread count',
        );
      }
    } catch (e) {
      debugPrint('❌ [MessageService] Error fetching unread count: $e');
      if (e is MessageException) rethrow;
      throw MessageException(
        message: 'Network error: Unable to fetch unread count',
      );
    }
  }

  // ==================== MARK AS READ ====================

  /// Mark a message as read
  Future<void> markMessageAsRead(int messageId) async {
    try {
      debugPrint('📡 [MessageService] Marking message $messageId as read...');

      final response = await _apiClient.post(
        ApiConfig.markMessageReadEndpoint(messageId),
        requiresAuth: true,
      );

      if (response['success'] == true) {
        debugPrint('✅ [MessageService] Message marked as read');
      } else {
        throw MessageException(
          message: response['message'] ?? 'Failed to mark message as read',
        );
      }
    } catch (e) {
      debugPrint('❌ [MessageService] Error marking message as read: $e');
      if (e is MessageException) rethrow;
      throw MessageException(
        message: 'Network error: Unable to mark message as read',
      );
    }
  }

  /// Mark all messages in a conversation as read
  Future<void> markConversationAsRead(int userId) async {
    try {
      debugPrint('📡 [MessageService] Marking conversation with user $userId as read...');

      final response = await _apiClient.post(
        ApiConfig.markConversationReadEndpoint(userId),
        requiresAuth: true,
      );

      if (response['success'] == true) {
        debugPrint('✅ [MessageService] Conversation marked as read');
      } else {
        throw MessageException(
          message: response['message'] ?? 'Failed to mark conversation as read',
        );
      }
    } catch (e) {
      debugPrint('❌ [MessageService] Error marking conversation as read: $e');
      if (e is MessageException) rethrow;
      throw MessageException(
        message: 'Network error: Unable to mark conversation as read',
      );
    }
  }

  // ==================== DELETE MESSAGE ====================

  /// Delete a message
  Future<void> deleteMessage(int messageId) async {
    try {
      debugPrint('📡 [MessageService] Deleting message $messageId...');

      final response = await _apiClient.delete(
        ApiConfig.deleteMessageEndpoint(messageId),
        requiresAuth: true,
      );

      if (response['success'] == true) {
        debugPrint('✅ [MessageService] Message deleted');
      } else {
        throw MessageException(
          message: response['message'] ?? 'Failed to delete message',
        );
      }
    } catch (e) {
      debugPrint('❌ [MessageService] Error deleting message: $e');
      if (e is MessageException) rethrow;
      throw MessageException(
        message: 'Network error: Unable to delete message',
      );
    }
  }
}
