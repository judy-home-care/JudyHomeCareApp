import 'package:flutter/material.dart';
import '../../services/notification_service.dart';
import '../../models/notification/notification_models.dart';
import '../../utils/app_colors.dart';

class NotificationsDrawer extends StatefulWidget {
  const NotificationsDrawer({Key? key}) : super(key: key);

  @override
  State<NotificationsDrawer> createState() => _NotificationsDrawerState();
}

class _NotificationsDrawerState extends State<NotificationsDrawer> {
  final NotificationService _notificationService = NotificationService();
  
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  
  List<NotificationItem> _notifications = [];
  int _currentPage = 1;
  int _lastPage = 1;
  bool _hasMore = false;
  
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('All notifications marked as read'),
              ],
            ),
            backgroundColor: AppColors.primaryGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark all as read'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.delete_outline, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Notification deleted'),
              ],
            ),
            backgroundColor: AppColors.primaryGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete notification'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFB),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(-5, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),
            
            // Content
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
  }

  Widget _buildHeader() {
    final unreadCount = _notifications.where((n) => !n.isRead).length;
    
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                  padding: EdgeInsets.zero,
                  color: AppColors.primaryGreen,
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
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (unreadCount > 0)
                      Text(
                        '$unreadCount unread',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              if (unreadCount > 0)
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primaryGreen,
                        AppColors.primaryGreen.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryGreen.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextButton.icon(
                    onPressed: _markAllAsRead,
                    icon: const Icon(Icons.done_all, size: 16, color: Colors.white),
                    label: const Text(
                      'Mark all read',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading notifications...',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'An error occurred',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadNotifications,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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
              width: 120,
              height: 120,
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
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.notifications_none_rounded,
                    size: 32,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'All Clear!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You don\'t have any notifications',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'We\'ll notify you when something new arrives',
              style: TextStyle(
                fontSize: 13,
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
        padding: const EdgeInsets.only(top: 16, bottom: 16),
        itemCount: _notifications.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _notifications.length) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
                ),
              ),
            );
          }

          final notification = _notifications[index];
          return _buildNotificationItem(notification);
        },
      ),
    );
  }

  Widget _buildNotificationItem(NotificationItem notification) {
    final isUnread = !notification.isRead;
    
    return Dismissible(
      key: Key('notification_${notification.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF4757), Color(0xFFFF6B7A)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.delete_outline, color: Colors.white, size: 24),
            SizedBox(height: 4),
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4757).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.delete_outline,
                    color: Color(0xFFFF4757),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Delete Notification',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            content: const Text(
              'Are you sure you want to delete this notification?',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF4757), Color(0xFFFF6B7A)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    'Delete',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        _deleteNotification(notification);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnread
                ? AppColors.primaryGreen.withOpacity(0.2)
                : Colors.grey.shade200,
            width: isUnread ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              _markAsRead(notification);
              // TODO: Handle notification tap navigation
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _getNotificationColor(notification.notificationType),
                          _getNotificationColor(notification.notificationType).withOpacity(0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: _getNotificationColor(notification.notificationType).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _getNotificationIcon(notification.notificationType),
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                notification.title,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                                  color: const Color(0xFF1A1A1A),
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (isUnread)
                              Container(
                                width: 10,
                                height: 10,
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
                                      color: AppColors.primaryGreen.withOpacity(0.4),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          notification.body,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            height: 1.5,
                            letterSpacing: -0.1,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
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
                                size: 12,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                notification.timeAgo,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getNotificationIcon(String type) {
    // Using the model's built-in getIcon method would be better,
    // but since it's an instance method, we'll keep the static mapping
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
    };
    return colors[type] ?? AppColors.primaryGreen;
  }
}