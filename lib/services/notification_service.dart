// lib/services/notification_service.dart
//
// Talks to the notification endpoints that already exist on the backend
// (routes/notifications.js, controllers/notificationController.js) but
// were never called from this app — the bell icon was wired to nothing,
// and there was no screen to view notifications in at all.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class NotificationItem {
  final String id;
  final String type;
  final String title;
  final String message;
  final String? actionUrl;
  final bool isRead;
  final DateTime? readAt;
  final String priority;
  final String? relatedEntityType;
  final String? relatedEntityId;
  final DateTime createdAt;

  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    required this.priority,
    required this.createdAt,
    this.actionUrl,
    this.readAt,
    this.relatedEntityType,
    this.relatedEntityId,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      return DateTime.tryParse(v.toString()) ?? DateTime.now();
    }

    return NotificationItem(
      id: json['notification_id']?.toString() ?? json['id']?.toString() ?? '',
      type: json['notification_type']?.toString() ?? 'general',
      title: json['title']?.toString() ?? 'Notification',
      message: json['message']?.toString() ?? '',
      actionUrl: json['action_url']?.toString(),
      isRead: json['is_read'] == true || json['is_read'] == 1,
      readAt: json['read_at'] != null ? parseDate(json['read_at']) : null,
      priority: json['priority']?.toString() ?? 'normal',
      relatedEntityType: json['related_entity_type']?.toString(),
      relatedEntityId: json['related_entity_id']?.toString(),
      createdAt: parseDate(json['created_at']),
    );
  }
}

class NotificationService {
  static const String _baseUrl =
      'https://aquagas-backend.onrender.com/api/v1/notifications';

  final AuthService _authService = AuthService();

  Future<Map<String, String>> _headers() async {
    final String? token = await _authService.getToken();
    return <String, String>{
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Exception _friendlyError(Object e) {
    if (e is TimeoutException) {
      return Exception('Connection timed out. Please try again.');
    }
    if (e is SocketException) {
      return Exception('No internet connection. Please check your network.');
    }
    if (e is Exception && e.toString().startsWith('Exception: ')) return e;
    return Exception('Something went wrong: $e');
  }

  Future<List<NotificationItem>> getNotifications() async {
    try {
      final http.Response response = await http
          .get(Uri.parse(_baseUrl), headers: await _headers())
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        return data
            .map((dynamic e) =>
                NotificationItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw Exception('Failed to load notifications (${response.statusCode}).');
    } catch (e) {
      throw _friendlyError(e);
    }
  }

  Future<int> getUnreadCount() async {
    try {
      final http.Response response = await http
          .get(Uri.parse('$_baseUrl/unread-count'), headers: await _headers())
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;
        return (data['unreadCount'] as num?)?.toInt() ?? 0;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      final http.Response response = await http
          .put(Uri.parse('$_baseUrl/$notificationId/read'),
              headers: await _headers())
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw Exception('Failed to update notification.');
      }
    } catch (e) {
      throw _friendlyError(e);
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final http.Response response = await http
          .put(Uri.parse('$_baseUrl/mark-all-read'), headers: await _headers())
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw Exception('Failed to update notifications.');
      }
    } catch (e) {
      throw _friendlyError(e);
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      final http.Response response = await http
          .delete(Uri.parse('$_baseUrl/$notificationId'),
              headers: await _headers())
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw Exception('Failed to delete notification.');
      }
    } catch (e) {
      throw _friendlyError(e);
    }
  }

  Future<Map<String, dynamic>> getPreferences() async {
    try {
      final http.Response response = await http
          .get(Uri.parse('$_baseUrl/preferences'), headers: await _headers())
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return <String, dynamic>{
        'email_enabled': true,
        'sms_enabled': true,
        'push_enabled': true,
      };
    } catch (_) {
      return <String, dynamic>{
        'email_enabled': true,
        'sms_enabled': true,
        'push_enabled': true,
      };
    }
  }

  Future<void> updatePreferences(Map<String, dynamic> updates) async {
    try {
      final http.Response response = await http
          .put(
            Uri.parse('$_baseUrl/preferences'),
            headers: await _headers(),
            body: jsonEncode(updates),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw Exception('Failed to update preferences.');
      }
    } catch (e) {
      throw _friendlyError(e);
    }
  }

  /// Registers this device's FCM token with the backend so it can receive
  /// pushes. Safe to call repeatedly (e.g. every app start / login) —
  /// re-registering the same token is a no-op server-side.
  Future<void> registerPushToken(String token, {String platform = 'android'}) async {
    try {
      final http.Response response = await http
          .post(
            Uri.parse('$_baseUrl/token'),
            headers: await _headers(),
            body: jsonEncode(<String, String>{
              'token': token,
              'platform': platform,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw Exception('Failed to register push token.');
      }
    } catch (e) {
      throw _friendlyError(e);
    }
  }

  Future<void> unregisterPushToken(String token) async {
    try {
      await http
          .delete(
            Uri.parse('$_baseUrl/token'),
            headers: await _headers(),
            body: jsonEncode(<String, String>{'token': token}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Best-effort on logout — not worth surfacing an error for.
    }
  }
}
