// lib/services/support_service.dart
//
// The backend already has a full support-ticket system (support_tickets,
// support_messages, FAQ, help topics — see controllers/supportController.js)
// that the app never called. "Help & Support" in the drawer was just a
// static AlertDialog with a placeholder phone number.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class SupportTicket {
  final String id;
  final String ticketNumber;
  final String subject;
  final String description;
  final String category;
  final String status;
  final DateTime createdAt;
  final List<SupportMessage> messages;

  const SupportTicket({
    required this.id,
    required this.ticketNumber,
    required this.subject,
    required this.description,
    required this.category,
    required this.status,
    required this.createdAt,
    this.messages = const <SupportMessage>[],
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawMessages =
        json['support_messages'] as List<dynamic>? ?? <dynamic>[];
    return SupportTicket(
      id: json['ticket_id']?.toString() ?? json['id']?.toString() ?? '',
      ticketNumber: json['ticket_number']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? 'other',
      status: json['status']?.toString() ?? 'open',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      messages: rawMessages
          .map((dynamic e) => SupportMessage.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SupportMessage {
  final String id;
  final String senderType;
  final String senderName;
  final String text;
  final DateTime sentAt;

  const SupportMessage({
    required this.id,
    required this.senderType,
    required this.senderName,
    required this.text,
    required this.sentAt,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    return SupportMessage(
      id: json['message_id']?.toString() ?? '',
      senderType: json['sender_type']?.toString() ?? 'user',
      senderName: json['sender_name']?.toString() ?? '',
      text: json['message_text']?.toString() ?? '',
      sentAt: DateTime.tryParse(json['sent_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  bool get isFromCustomer => senderType == 'user';
}

class SupportService {
  static const String _baseUrl =
      'https://aquagas-backend.onrender.com/api/v1/support';

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

  Future<List<String>> getHelpTopics() async {
    try {
      final http.Response response = await http
          .get(Uri.parse('$_baseUrl/help-topics'), headers: await _headers())
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return (jsonDecode(response.body) as List<dynamic>)
            .map((dynamic e) => e.toString())
            .toList();
      }
      return const <String>[
        'order_issue',
        'delivery_problem',
        'payment_issue',
        'product_quality',
        'account_issue',
        'technical_support',
        'billing_inquiry',
        'other',
      ];
    } catch (_) {
      return const <String>[
        'order_issue',
        'delivery_problem',
        'payment_issue',
        'product_quality',
        'account_issue',
        'technical_support',
        'billing_inquiry',
        'other',
      ];
    }
  }

  Future<List<SupportTicket>> getMyTickets() async {
    try {
      final http.Response response = await http
          .get(Uri.parse('$_baseUrl/tickets'), headers: await _headers())
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return (jsonDecode(response.body) as List<dynamic>)
            .map((dynamic e) =>
                SupportTicket.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw Exception('Failed to load your tickets (${response.statusCode}).');
    } catch (e) {
      throw _friendlyError(e);
    }
  }

  Future<SupportTicket> getTicketDetails(String ticketId) async {
    try {
      final http.Response response = await http
          .get(Uri.parse('$_baseUrl/tickets/$ticketId'),
              headers: await _headers())
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return SupportTicket.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>);
      }
      throw Exception('Failed to load ticket (${response.statusCode}).');
    } catch (e) {
      throw _friendlyError(e);
    }
  }

  Future<SupportTicket> createTicket({
    required String subject,
    required String description,
    required String category,
  }) async {
    try {
      final http.Response response = await http
          .post(
            Uri.parse('$_baseUrl/tickets'),
            headers: await _headers(),
            body: jsonEncode(<String, String>{
              'subject': subject,
              'description': description,
              'category': category,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 201) {
        final Map<String, dynamic> body =
            jsonDecode(response.body) as Map<String, dynamic>;
        return SupportTicket.fromJson(body['data'] as Map<String, dynamic>);
      }
      throw Exception('Failed to submit your request (${response.statusCode}).');
    } catch (e) {
      throw _friendlyError(e);
    }
  }

  Future<SupportMessage> replyToTicket(String ticketId, String message) async {
    try {
      final http.Response response = await http
          .post(
            Uri.parse('$_baseUrl/tickets/$ticketId/messages'),
            headers: await _headers(),
            body: jsonEncode(<String, String>{'message': message}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 201) {
        final Map<String, dynamic> body =
            jsonDecode(response.body) as Map<String, dynamic>;
        return SupportMessage.fromJson(body['data'] as Map<String, dynamic>);
      }
      throw Exception('Failed to send your message (${response.statusCode}).');
    } catch (e) {
      throw _friendlyError(e);
    }
  }
}
