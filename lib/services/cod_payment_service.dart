// lib/services/cod_payment_service.dart
//
// Cash-on-delivery orders can be paid by M-Pesa at the door: the rider asks
// for payment and the customer gets a prompt on their phone. The server is the
// only source of truth ("paid" is set after a verified SasaPay callback).
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:aquagas/services/auth_service.dart';

/// none | waiting | expired | failed | paid
class CodPaymentStatus {
  final String state;
  final double amount;
  final int secondsLeft;
  final String? reason;
  final bool isPaid;

  const CodPaymentStatus({
    required this.state,
    required this.amount,
    this.secondsLeft = 0,
    this.reason,
    this.isPaid = false,
  });

  factory CodPaymentStatus.fromJson(Map<String, dynamic> j) => CodPaymentStatus(
        state: (j['state'] ?? 'none').toString(),
        amount: double.tryParse('${j['amount']}') ?? 0,
        secondsLeft: int.tryParse('${j['seconds_left']}') ?? 0,
        reason: j['reason']?.toString(),
        isPaid: j['is_paid'] == true,
      );

  bool get isWaiting => state == 'waiting';
}

class CodPaymentService {
  static const String _baseUrl = 'https://aquagas-backend.onrender.com/api/v1';
  final AuthService _auth = AuthService();

  Future<CodPaymentStatus?> fetch(String orderId) async {
    final String? token = await _auth.getToken();
    if (token == null) return null;
    final http.Response r = await http.get(
      Uri.parse('$_baseUrl/orders/$orderId/cod-payment'),
      headers: <String, String>{'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 12));
    if (r.statusCode != 200) return null;
    return CodPaymentStatus.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }
}

/// Polls the payment state and calls [onRequested] each time a NEW request
/// appears (state becomes `waiting`), so the app can open the pay screen.
class CodPaymentWatcher {
  final String orderId;
  final void Function(CodPaymentStatus) onRequested;
  final CodPaymentService _service = CodPaymentService();
  Timer? _timer;
  bool _wasWaiting = false;
  bool _busy = false;

  CodPaymentWatcher({required this.orderId, required this.onRequested});

  void start({Duration every = const Duration(seconds: 5)}) {
    _timer?.cancel();
    _timer = Timer.periodic(every, (_) => _tick());
    _tick();
  }

  /// Call after returning from the pay screen so a resend re-opens it.
  void reset() => _wasWaiting = false;

  Future<void> _tick() async {
    if (_busy || orderId.isEmpty) return;
    _busy = true;
    try {
      final CodPaymentStatus? s = await _service.fetch(orderId);
      if (s == null) return;
      if (s.isPaid) {
        stop();
        return;
      }
      if (s.isWaiting && !_wasWaiting) onRequested(s);
      _wasWaiting = s.isWaiting;
    } catch (e) {
      debugPrint('CodPaymentWatcher: $e');
    } finally {
      _busy = false;
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
