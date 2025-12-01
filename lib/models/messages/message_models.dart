// lib/models/messages/message_models.dart
// Message and conversation models for chat feature

/// User info in messages
class MessageUser {
  final int id;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;
  final String? role;
  final String? avatar;

  MessageUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.email,
    this.phone,
    this.role,
    this.avatar,
  });

  String get fullName => '$firstName $lastName';

  String get initials {
    final first = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final last = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return '$first$last';
  }

  factory MessageUser.fromJson(Map<String, dynamic> json) {
    return MessageUser(
      id: json['id'] ?? 0,
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'],
      phone: json['phone'],
      role: json['role'],
      avatar: json['avatar'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone': phone,
      'role': role,
      'avatar': avatar,
    };
  }
}

/// Individual message
class Message {
  final int id;
  final int senderId;
  final int receiverId;
  final String message;
  final String? subject;
  final String messageType;
  final int? careRequestId;
  final DateTime? readAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final MessageUser? sender;
  final MessageUser? receiver;

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.message,
    this.subject,
    required this.messageType,
    this.careRequestId,
    this.readAt,
    required this.createdAt,
    required this.updatedAt,
    this.sender,
    this.receiver,
  });

  bool get isRead => readAt != null;

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] ?? 0,
      senderId: json['sender_id'] ?? 0,
      receiverId: json['receiver_id'] ?? 0,
      message: json['message'] ?? '',
      subject: json['subject'],
      messageType: json['message_type'] ?? 'general',
      careRequestId: json['care_request_id'],
      readAt: json['read_at'] != null ? DateTime.tryParse(json['read_at']) : null,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      sender: json['sender'] != null ? MessageUser.fromJson(json['sender']) : null,
      receiver: json['receiver'] != null ? MessageUser.fromJson(json['receiver']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'message': message,
      'subject': subject,
      'message_type': messageType,
      'care_request_id': careRequestId,
      'read_at': readAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// Conversation (for conversation list)
class Conversation {
  final int id;
  final int senderId;
  final int receiverId;
  final String message;
  final String? subject;
  final String messageType;
  final DateTime? readAt;
  final DateTime createdAt;
  final int userId;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;
  final String? role;
  final String? avatar;
  final int unreadCount;

  Conversation({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.message,
    this.subject,
    required this.messageType,
    this.readAt,
    required this.createdAt,
    required this.userId,
    required this.firstName,
    required this.lastName,
    this.email,
    this.phone,
    this.role,
    this.avatar,
    required this.unreadCount,
  });

  String get fullName => '$firstName $lastName';

  String get initials {
    final first = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final last = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return '$first$last';
  }

  bool get hasUnread => unreadCount > 0;

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] ?? 0,
      senderId: json['sender_id'] ?? 0,
      receiverId: json['receiver_id'] ?? 0,
      message: json['message'] ?? '',
      subject: json['subject'],
      messageType: json['message_type'] ?? 'general',
      readAt: json['read_at'] != null ? DateTime.tryParse(json['read_at']) : null,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      userId: json['user_id'] ?? 0,
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'],
      phone: json['phone'],
      role: json['role'],
      avatar: json['avatar'],
      unreadCount: json['unread_count'] ?? 0,
    );
  }
}

/// Contact (for new message)
class Contact {
  final int id;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;
  final String? role;
  final String? avatar;

  Contact({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.email,
    this.phone,
    this.role,
    this.avatar,
  });

  String get fullName => '$firstName $lastName';

  String get initials {
    final first = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final last = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return '$first$last';
  }

  String get roleDisplayName {
    switch (role?.toLowerCase()) {
      case 'admin':
        return 'Administrator';
      case 'superadmin':
        return 'Super Admin';
      case 'manager':
        return 'Manager';
      case 'nurse':
        return 'Nurse';
      case 'patient':
        return 'Patient';
      default:
        return role ?? 'Staff';
    }
  }

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'] ?? 0,
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'],
      phone: json['phone'],
      role: json['role'],
      avatar: json['avatar'],
    );
  }
}

/// API Response models
class ConversationListResponse {
  final bool success;
  final List<Conversation> data;

  ConversationListResponse({
    required this.success,
    required this.data,
  });

  factory ConversationListResponse.fromJson(Map<String, dynamic> json) {
    return ConversationListResponse(
      success: json['success'] ?? false,
      data: (json['data'] as List<dynamic>?)
              ?.map((e) => Conversation.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class ConversationResponse {
  final bool success;
  final List<Message> messages;
  final MessageUser? user;
  final int currentPage;
  final int lastPage;
  final int total;
  final bool hasMorePages;

  ConversationResponse({
    required this.success,
    required this.messages,
    this.user,
    this.currentPage = 1,
    this.lastPage = 1,
    this.total = 0,
    this.hasMorePages = false,
  });

  factory ConversationResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    final pagination = data?['pagination'] as Map<String, dynamic>?;

    // Handle both paginated and non-paginated responses
    final currentPage = pagination?['current_page'] ?? data?['current_page'] ?? 1;
    final lastPage = pagination?['last_page'] ?? data?['last_page'] ?? 1;
    final total = pagination?['total'] ?? data?['total'] ?? 0;

    return ConversationResponse(
      success: json['success'] ?? false,
      messages: (data?['messages'] as List<dynamic>?)
              ?.map((e) => Message.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      user: data?['user'] != null
          ? MessageUser.fromJson(data!['user'] as Map<String, dynamic>)
          : null,
      currentPage: currentPage is int ? currentPage : int.tryParse(currentPage.toString()) ?? 1,
      lastPage: lastPage is int ? lastPage : int.tryParse(lastPage.toString()) ?? 1,
      total: total is int ? total : int.tryParse(total.toString()) ?? 0,
      hasMorePages: currentPage < lastPage,
    );
  }
}

class ContactsResponse {
  final bool success;
  final List<Contact> data;

  ContactsResponse({
    required this.success,
    required this.data,
  });

  factory ContactsResponse.fromJson(Map<String, dynamic> json) {
    return ContactsResponse(
      success: json['success'] ?? false,
      data: (json['data'] as List<dynamic>?)
              ?.map((e) => Contact.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class UnreadCountResponse {
  final bool success;
  final int unreadCount;

  UnreadCountResponse({
    required this.success,
    required this.unreadCount,
  });

  factory UnreadCountResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    return UnreadCountResponse(
      success: json['success'] ?? false,
      unreadCount: data?['unread_count'] ?? 0,
    );
  }
}

class SendMessageResponse {
  final bool success;
  final String message;
  final Message? data;

  SendMessageResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory SendMessageResponse.fromJson(Map<String, dynamic> json) {
    return SendMessageResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null
          ? Message.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Exception for message operations
class MessageException implements Exception {
  final String message;
  final int? statusCode;

  MessageException({required this.message, this.statusCode});

  @override
  String toString() => message;
}
