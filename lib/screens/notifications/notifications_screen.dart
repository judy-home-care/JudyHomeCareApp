import 'package:flutter/material.dart';
import '../../services/notification_service.dart';
import '../../models/notification/notification_models.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  
  List<NotificationItem> _notifications = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  int _unreadCount = 0;
  int _currentPage = 1;
  bool _hasMorePages = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _loadUnreadCount();
  }

  /// Load notifications from backend
  Future<void> _loadNotifications({bool loadMore = false}) async {
    if (!loadMore) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      final response = await _notificationService.getNotifications(
        page: loadMore ? _currentPage + 1 : 1,
        perPage: 20,
      );

      setState(() {
        if (loadMore) {
          _notifications.addAll(response.data.data);
          _currentPage++;
        } else {
          _notifications = response.data.data;
          _currentPage = 1;
        }
        _hasMorePages = response.data.currentPage < response.data.lastPage;
        _isLoading = false;
      });
    } on NotificationException catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'An unexpected error occurred';
      });
    }
  }

  /// Load unread count
  Future<void> _loadUnreadCount() async {
    try {
      final response = await _notificationService.getUnreadCount();
      setState(() {
        _unreadCount = response.unreadCount;
      });
    } catch (e) {
      // Silently fail for unread count
      print('Error loading unread count: $e');
    }
  }

  /// Mark notification as read
  Future<void> _markAsRead(NotificationItem notification) async {
    if (notification.isRead) return;

    try {
      await _notificationService.markNotificationAsRead(notification.id);
      
      setState(() {
        // Update the notification in the list
        final index = _notifications.indexWhere((n) => n.id == notification.id);
        if (index != -1) {
          _notifications[index] = notification.copyWith(
            isRead: true,
            readAt: DateTime.now(),
          );
        }
        if (_unreadCount > 0) _unreadCount--;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to mark as read: $e')),
      );
    }
  }

  /// Mark all notifications as read
  Future<void> _markAllAsRead() async {
    try {
      await _notificationService.markAllNotificationsAsRead();
      
      setState(() {
        _notifications = _notifications.map((n) => n.copyWith(
          isRead: true,
          readAt: DateTime.now(),
        )).toList();
        _unreadCount = 0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All notifications marked as read')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to mark all as read: $e')),
      );
    }
  }

  /// Delete notification
  Future<void> _deleteNotification(NotificationItem notification) async {
    try {
      await _notificationService.deleteNotification(notification.id);
      
      setState(() {
        _notifications.removeWhere((n) => n.id == notification.id);
        if (!notification.isRead && _unreadCount > 0) {
          _unreadCount--;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification deleted')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Notifications'),
            if (_unreadCount > 0)
              Text(
                '$_unreadCount unread',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        actions: [
          if (_unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'Mark all as read',
              onPressed: _markAllAsRead,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _notifications.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadNotifications(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.notifications_none, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No notifications yet'),
            const SizedBox(height: 8),
            Text(
              'You\'ll see updates about your care here',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadNotifications(),
      child: ListView.builder(
        itemCount: _notifications.length + (_hasMorePages ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _notifications.length) {
            // Load more button
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: ElevatedButton(
                  onPressed: () => _loadNotifications(loadMore: true),
                  child: const Text('Load More'),
                ),
              ),
            );
          }

          final notification = _notifications[index];
          return NotificationTile(
            notification: notification,
            onTap: () => _markAsRead(notification),
            onDelete: () => _deleteNotification(notification),
          );
        },
      ),
    );
  }
}

// ============================================================================
// NOTIFICATION TILE WIDGET
// ============================================================================

class NotificationTile extends StatelessWidget {
  final NotificationItem notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const NotificationTile({
    Key? key,
    required this.notification,
    required this.onTap,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(notification.id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: notification.isRead 
              ? Colors.grey[300] 
              : Colors.blue[100],
          child: Text(
            notification.getIcon(),
            style: const TextStyle(fontSize: 20),
          ),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.isRead 
                ? FontWeight.normal 
                : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              notification.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  notification.timeAgo,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                if (notification.priority == 'high' || 
                    notification.priority == 'urgent') ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: notification.priority == 'urgent'
                          ? Colors.red[100]
                          : Colors.orange[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      notification.priority.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: notification.priority == 'urgent'
                            ? Colors.red[900]
                            : Colors.orange[900],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: !notification.isRead
            ? Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}