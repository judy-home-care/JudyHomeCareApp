// lib/screens/messages/chat_screen.dart
// Chat screen for individual conversations with pagination

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/app_colors.dart';
import '../../utils/api_config.dart';
import '../../models/messages/message_models.dart';
import '../../services/messages/message_service.dart';
import '../../services/auth/auth_service.dart';
import '../../services/notification_service.dart';

class ChatScreen extends StatefulWidget {
  final int userId;
  final String userName;
  final String? userAvatar;
  final String? userRole;

  const ChatScreen({
    Key? key,
    required this.userId,
    required this.userName,
    this.userAvatar,
    this.userRole,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final MessageService _messageService = MessageService();
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isSending = false;
  String? _errorMessage;
  int? _currentUserId;
  bool _messageSent = false;

  // Pagination state
  int _currentPage = 1;
  bool _hasMorePages = false;
  static const int _messagesPerPage = 30;

  // Screen visibility for battery optimization
  bool _isScreenVisible = true;

  // Notification listener cleanup
  VoidCallback? _removeNotificationListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    _loadCurrentUser();
    _loadMessages();
    _setupNotificationListener();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onScroll);
    _removeNotificationListener?.call();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isScreenVisible = true;
      // Refresh messages when app returns to foreground
      _loadNewMessages();
    } else if (state == AppLifecycleState.paused) {
      _isScreenVisible = false;
    }
  }

  /// Set up listener for incoming message notifications (battery-efficient, push-based)
  void _setupNotificationListener() {
    _removeNotificationListener = _notificationService.addNotificationReceivedListener(() {
      if (mounted && _isScreenVisible) {
        // Only refresh if we're on screen - battery optimization
        debugPrint('📬 [ChatScreen] Notification received - checking for new messages');
        _loadNewMessages();
      }
    });
  }

  /// Load only new messages (for real-time updates)
  /// This fetches page 1 and merges any new messages at the bottom
  Future<void> _loadNewMessages() async {
    if (!mounted || _isLoading) return;

    try {
      final response = await _messageService.getConversation(
        widget.userId,
        page: 1,
        perPage: _messagesPerPage,
      );

      if (mounted && response.messages.isNotEmpty) {
        final newMessages = response.messages.toList();

        // Find messages we don't have yet (compare by ID)
        final existingIds = _messages.map((m) => m.id).toSet();
        final trulyNewMessages = newMessages.where((m) => !existingIds.contains(m.id)).toList();

        if (trulyNewMessages.isNotEmpty) {
          setState(() {
            // Append new messages at the end (they're the most recent)
            _messages.addAll(trulyNewMessages);
          });

          // Scroll to bottom to show new message
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
          });

          // Mark as read
          _markConversationAsRead();

          debugPrint('✅ [ChatScreen] Added ${trulyNewMessages.length} new messages');
        }
      }
    } catch (e) {
      debugPrint('❌ [ChatScreen] Error loading new messages: $e');
    }
  }

  /// Detect scroll position to load more messages when scrolling up
  void _onScroll() {
    // Load more when user scrolls near the top (older messages)
    if (_scrollController.position.pixels <= 100 &&
        !_isLoadingMore &&
        _hasMorePages) {
      _loadMoreMessages();
    }
  }

  Future<void> _loadCurrentUser() async {
    final user = await _authService.getCurrentUser();
    if (mounted && user != null) {
      setState(() {
        _currentUserId = user.id;
      });
    }
  }

  /// Load initial messages (most recent)
  Future<void> _loadMessages({bool silent = false}) async {
    if (!mounted) return;

    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final response = await _messageService.getConversation(
        widget.userId,
        page: 1,
        perPage: _messagesPerPage,
      );

      if (mounted) {
        setState(() {
          // API returns oldest first within each page, newest page first
          // Page 1 has most recent messages, but within page they're oldest->newest
          // So we use them as-is: [oldest...newest]
          _messages = response.messages.toList();
          _currentPage = response.currentPage;
          _hasMorePages = response.hasMorePages;
          _isLoading = false;
        });

        // Scroll to bottom after loading messages (to show most recent)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom(animated: false);
        });

        // Mark conversation as read
        _markConversationAsRead();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Load more older messages when scrolling up
  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMorePages || !mounted) return;

    setState(() => _isLoadingMore = true);

    // Store current scroll metrics to maintain position
    final scrollPosition = _scrollController.position.pixels;
    final maxScrollBefore = _scrollController.position.maxScrollExtent;

    try {
      final nextPage = _currentPage + 1;
      final response = await _messageService.getConversation(
        widget.userId,
        page: nextPage,
        perPage: _messagesPerPage,
      );

      if (mounted) {
        setState(() {
          // Older messages from next page - prepend to existing messages
          final olderMessages = response.messages.toList();
          _messages = [...olderMessages, ..._messages];
          _currentPage = response.currentPage;
          _hasMorePages = response.hasMorePages;
          _isLoadingMore = false;
        });

        // Maintain scroll position after adding messages at top
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            final maxScrollAfter = _scrollController.position.maxScrollExtent;
            final scrollDiff = maxScrollAfter - maxScrollBefore;
            _scrollController.jumpTo(scrollPosition + scrollDiff);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
        debugPrint('Error loading more messages: $e');
      }
    }
  }

  Future<void> _markConversationAsRead() async {
    try {
      await _messageService.markConversationAsRead(widget.userId);
    } catch (e) {
      debugPrint('Failed to mark conversation as read: $e');
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    // Optimistically add message to UI
    final optimisticMessage = Message(
      id: -1,
      senderId: _currentUserId ?? 0,
      receiverId: widget.userId,
      message: text,
      messageType: 'general',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    setState(() {
      _messages.add(optimisticMessage);
      _messageController.clear();
    });

    _scrollToBottom();

    try {
      final response = await _messageService.sendMessage(
        receiverId: widget.userId,
        message: text,
      );

      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m.id == -1);
          if (index != -1 && response.data != null) {
            _messages[index] = response.data!;
          }
          _isSending = false;
          _messageSent = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m.id == -1);
          _isSending = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  void _scrollToBottom({bool animated = true}) {
    if (_scrollController.hasClients) {
      if (animated) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildMessagesList()),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final avatarUrl = ApiConfig.getAvatarUrl(widget.userAvatar);

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      shadowColor: Colors.black.withOpacity(0.1),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF1A1A1A)),
        onPressed: () => Navigator.pop(context, _messageSent),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primaryGreen.withOpacity(0.1),
            backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
            child: avatarUrl.isEmpty
                ? Text(
                    _getInitials(widget.userName),
                    style: const TextStyle(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.userName,
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.userRole != null)
                  Text(
                    _getRoleDisplayName(widget.userRole),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert, color: Color(0xFF1A1A1A)),
          onPressed: () => _showOptionsMenu(),
        ),
      ],
    );
  }

  Widget _buildMessagesList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
              const SizedBox(height: 16),
              Text(
                'Failed to load messages',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadMessages,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline,
                size: 48,
                color: AppColors.primaryGreen.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No messages yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Send a message to start the conversation',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      // +1 for loading indicator at top if has more pages
      itemCount: _messages.length + (_hasMorePages ? 1 : 0),
      itemBuilder: (context, index) {
        // Show loading indicator at the top when there are more pages
        if (_hasMorePages && index == 0) {
          return _buildLoadMoreIndicator();
        }

        // Adjust index if we have loading indicator
        final messageIndex = _hasMorePages ? index - 1 : index;
        final message = _messages[messageIndex];
        final isMe = message.senderId == _currentUserId;
        final showDate = _shouldShowDate(messageIndex);

        return Column(
          children: [
            if (showDate) _buildDateDivider(_messages[messageIndex].createdAt),
            _buildMessageBubble(message, isMe),
          ],
        );
      },
    );
  }

  Widget _buildLoadMoreIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: _isLoadingMore
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Loading older messages...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              )
            : GestureDetector(
                onTap: _loadMoreMessages,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(
                        'Load older messages',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  bool _shouldShowDate(int index) {
    if (index == 0) return true;

    final currentDate = _messages[index].createdAt;
    final previousDate = _messages[index - 1].createdAt;

    return currentDate.day != previousDate.day ||
        currentDate.month != previousDate.month ||
        currentDate.year != previousDate.year;
  }

  Widget _buildDateDivider(DateTime date) {
    final now = DateTime.now();
    String dateText;

    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      dateText = 'Today';
    } else if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
      dateText = 'Yesterday';
    } else {
      dateText = '${date.day}/${date.month}/${date.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            dateText,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Message message, bool isMe) {
    final time = _formatTime(message.createdAt);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 4,
          bottom: 4,
          left: isMe ? 48 : 0,
          right: isMe ? 0 : 48,
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMe ? AppColors.primaryGreen : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isMe ? 20 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.message,
                style: TextStyle(
                  color: isMe ? Colors.white : const Color(0xFF1A1A1A),
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  time,
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.id == -1
                        ? Icons.access_time
                        : message.isRead
                            ? Icons.done_all
                            : Icons.done,
                    size: 14,
                    color: message.isRead ? AppColors.primaryGreen : Colors.grey[400],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewPadding.bottom > 0 ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 4,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryGreen,
                    AppColors.primaryGreen.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryGreen.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _isSending
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Refresh'),
                onTap: () {
                  Navigator.pop(context);
                  _loadMessages();
                },
              ),
              ListTile(
                leading: const Icon(Icons.keyboard_double_arrow_down),
                title: const Text('Go to latest'),
                onTap: () {
                  Navigator.pop(context);
                  _scrollToBottom();
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy last message'),
                onTap: () {
                  Navigator.pop(context);
                  if (_messages.isNotEmpty) {
                    Clipboard.setData(ClipboardData(text: _messages.last.message));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Message copied to clipboard'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  String _getRoleDisplayName(String? role) {
    switch (role?.toLowerCase()) {
      case 'admin':
        return 'Administrator';
      case 'superadmin':
        return 'Super Admin';
      case 'manager':
        return 'Manager';
      case 'nurse':
        return 'Nurse';
      default:
        return role ?? 'Staff';
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }
}
