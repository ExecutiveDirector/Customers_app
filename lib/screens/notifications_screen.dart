// lib/screens/notifications_screen.dart
//
// Replaces the dead bell icon (onNotificationsTap was a no-op comment) and
// the "Notifications feature coming soon" snackbar in profile_screen.dart.
// The backend notification API already existed and was fully unused.
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:aquagas/services/notification_service.dart';
import 'package:aquagas/theme/app_colors.dart';
import 'package:aquagas/app.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _service = NotificationService();

  List<NotificationItem> _items = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final List<NotificationItem> items = await _service.getNotifications();
      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    final List<NotificationItem> previous = _items;
    setState(() {
      _items = _items
          .map((NotificationItem n) => n.isRead
              ? n
              : NotificationItem(
                  id: n.id,
                  type: n.type,
                  title: n.title,
                  message: n.message,
                  actionUrl: n.actionUrl,
                  isRead: true,
                  readAt: DateTime.now(),
                  priority: n.priority,
                  relatedEntityType: n.relatedEntityType,
                  relatedEntityId: n.relatedEntityId,
                  createdAt: n.createdAt,
                ))
          .toList();
    });
    try {
      await _service.markAllAsRead();
    } catch (e) {
      if (!mounted) return;
      setState(() => _items = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _onTapNotification(NotificationItem item) async {
    if (!item.isRead) {
      setState(() {
        final int i = _items.indexWhere((NotificationItem n) => n.id == item.id);
        if (i != -1) {
          _items[i] = NotificationItem(
            id: item.id,
            type: item.type,
            title: item.title,
            message: item.message,
            actionUrl: item.actionUrl,
            isRead: true,
            readAt: DateTime.now(),
            priority: item.priority,
            relatedEntityType: item.relatedEntityType,
            relatedEntityId: item.relatedEntityId,
            createdAt: item.createdAt,
          );
        }
      });
      unawaited(_service.markAsRead(item.id));
    }

    // Orders (order_placed, order_dispatched, order_delivered, etc.) link
    // straight to live tracking for that order.
    if (item.relatedEntityType == 'order' && item.relatedEntityId != null) {
      if (!mounted) return;
      Navigator.pushNamed(context, Routes.trackOrder,
          arguments: item.relatedEntityId);
    }
  }

  Future<void> _delete(NotificationItem item) async {
    setState(() => _items.removeWhere((NotificationItem n) => n.id == item.id));
    try {
      await _service.deleteNotification(item.id);
    } catch (_) {
      // If the delete failed server-side, a stale row reappearing on the
      // next pull-to-refresh is a reasonable enough fallback — not worth
      // a jarring "undo" flow for a notification.
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasUnread = _items.any((NotificationItem n) => !n.isRead);

    return Scaffold(
      backgroundColor: AppColors.slate100,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _buildHeader(hasUnread),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool hasUnread) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.slate800),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Expanded(
            child: Text(
              'Notifications',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.slate800,
              ),
            ),
          ),
          if (hasUnread)
            TextButton(
              onPressed: _markAllRead,
              child: const Text(
                'Mark all read',
                style: TextStyle(color: AppColors.green600, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.green500),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.slate500),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.slate500)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _load,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.green500),
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(
                  color: AppColors.green50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_none_rounded,
                    size: 44, color: AppColors.green600),
              ),
              const SizedBox(height: 16),
              const Text(
                "You're all caught up",
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.slate800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Order updates and account alerts will show up here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.slate500),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.green500,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.slate100),
        itemBuilder: (BuildContext context, int index) {
          final NotificationItem item = _items[index];
          return Dismissible(
            key: ValueKey<String>(item.id),
            direction: DismissDirection.endToStart,
            background: Container(
              color: AppColors.red500,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
            ),
            onDismissed: (_) => _delete(item),
            child: _NotificationTile(
              item: item,
              onTap: () => _onTapNotification(item),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap});

  final NotificationItem item;
  final VoidCallback onTap;

  IconData get _icon {
    switch (item.type) {
      case 'order_placed':
      case 'order_confirmed':
      case 'order_dispatched':
      case 'order_delivered':
        return Icons.local_shipping_rounded;
      case 'payment':
      case 'payment_success':
      case 'payment_failed':
        return Icons.payments_rounded;
      case 'promo':
      case 'promotion':
        return Icons.local_offer_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String get _timeAgo {
    final Duration diff = DateTime.now().difference(item.createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${item.createdAt.day}/${item.createdAt.month}/${item.createdAt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: item.isRead ? Colors.white : AppColors.green50,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: item.isRead ? AppColors.slate100 : AppColors.green100,
                shape: BoxShape.circle,
              ),
              child: Icon(_icon,
                  size: 20,
                  color: item.isRead ? AppColors.slate500 : AppColors.green600),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w700,
                            color: AppColors.slate800,
                          ),
                        ),
                      ),
                      if (!item.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 6, top: 4),
                          decoration: const BoxDecoration(
                            color: AppColors.green500,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppColors.slate500),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _timeAgo,
                    style: TextStyle(fontSize: 11.5, color: AppColors.slate500.withOpacity(0.8)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
