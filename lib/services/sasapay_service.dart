// lib/services/sasapay_service.dart
//
// Talks to the backend's /api/v1/payments/sasapay endpoints. Unlike
// Pesapal, there's no WebView here — SasaPay pushes a standard M-PESA
// "Enter your PIN" prompt straight to the customer's phone. The actual
// payment result arrives asynchronously at the backend (SasaPay calls our
// callback), so this service's checkStatus() just polls our own backend,
// which is updated once that callback lands.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class SasapayInitiateResult {
  final String checkoutRequestId;
  final String orderId;
  final String message;

  const SasapayInitiateResult({
    required this.checkoutRequestId,
    required this.orderId,
    required this.message,
  });

  factory SasapayInitiateResult.fromJson(Map<String, dynamic> json) {
    return SasapayInitiateResult(
      checkoutRequestId: json['checkout_request_id']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      message: json['message']?.toString() ?? 'STK push sent — enter your M-PESA PIN',
    );
  }
}

class SasapayStatusResult {
  final String paymentStatus; // pending | paid | failed | ...
  final String? transactionId;

  const SasapayStatusResult({required this.paymentStatus, this.transactionId});

  bool get isPaid => paymentStatus == 'paid';
  bool get isFailed => paymentStatus == 'failed';

  factory SasapayStatusResult.fromJson(Map<String, dynamic> json) {
    return SasapayStatusResult(
      paymentStatus: json['payment_status']?.toString() ?? 'pending',
      transactionId: json['transaction_id']?.toString(),
    );
  }
}

class SasapayService {
  static const String _baseUrl = 'https://aquagas-backend.onrender.com/api/v1/payments/sasapay';

  final AuthService _authService = AuthService();

  Future<Map<String, String>> _headers() async {
    final String? token = await _authService.getToken();
    return <String, String>{
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Exception _friendlyError(Object e) {
    if (e is TimeoutException) return Exception('Connection timed out. Please try again.');
    if (e is SocketException) return Exception('No internet connection. Please check your network.');
    if (e is Exception && e.toString().startsWith('Exception: ')) return e;
    return Exception('Something went wrong. Please try again.');
  }

  Future<SasapayInitiateResult> initiatePayment({
    required String orderId,
    required String phoneNumber,
  }) async {
    try {
      final http.Response response = await http
          .post(
            Uri.parse('$_baseUrl/initiate'),
            headers: await _headers(),
            body: jsonEncode(<String, dynamic>{
              'order_id': orderId,
              'phone_number': phoneNumber,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return SasapayInitiateResult.fromJson(data);
      }
      throw Exception(data['error']?.toString() ?? 'Failed to start M-Pesa payment.');
    } catch (e) {
      throw _friendlyError(e);
    }
  }

  Future<SasapayStatusResult> checkStatus(String orderId) async {
    try {
      final http.Response response = await http
          .get(Uri.parse('$_baseUrl/status/$orderId'), headers: await _headers())
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return SasapayStatusResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      }
      throw Exception('Failed to check payment status.');
    } catch (e) {
      throw _friendlyError(e);
    }
  }
}
