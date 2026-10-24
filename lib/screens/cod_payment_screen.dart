// lib/screens/cod_payment_screen.dart
//
// Customer view of the rider's M-Pesa request (cash-on-delivery orders).
// States follow the approved template: waiting for PIN -> success / failed,
// with a countdown and an always-available "Pay cash instead" exit.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:aquagas/services/cod_payment_service.dart';

const Color _green = Color(0xFF10B981);
const Color _dark = Color(0xFF064E3B);

class CodPaymentScreen extends StatefulWidget {
  final String orderId;
  final CodPaymentStatus initial;
  const CodPaymentScreen({super.key, required this.orderId, required this.initial});

  @override
  State<CodPaymentScreen> createState() => _CodPaymentScreenState();
}

class _CodPaymentScreenState extends State<CodPaymentScreen> {
  final CodPaymentService _service = CodPaymentService();
  late CodPaymentStatus _status = widget.initial;
  Timer? _poll;
  Timer? _tick;
  int _left = 0;

  @override
  void initState() {
    super.initState();
    _left = _status.secondsLeft;
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _status.isWaiting && _left > 0) setState(() => _left--);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final CodPaymentStatus? s = await _service.fetch(widget.orderId);
      if (s == null || !mounted) return;
      setState(() {
        _status = s;
        _left = s.secondsLeft;
      });
      if (s.isPaid) _poll?.cancel();
    } catch (_) {/* keep last known state; next tick retries */}
  }

  String get _amount =>
      NumberFormat.currency(locale: 'en_KE', symbol: 'KSh ', decimalDigits: 0).format(_status.amount);

  @override
  Widget build(BuildContext context) {
    final String st = _status.isPaid ? 'paid' : _status.state;
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('M-Pesa payment', style: TextStyle(color: Colors.white)),
          backgroundColor: _green,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _hero(st),
                const SizedBox(height: 24),
                Text(_title(st),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _dark)),
                const SizedBox(height: 10),
                Text(_body(st),
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Colors.grey.shade700)),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(14)),
                  child: Text(_amount,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: _dark)),
                ),
                if (st == 'waiting') ...<Widget>[
                  const SizedBox(height: 14),
                  Text('Prompt expires in ${_left ~/ 60}:${(_left % 60).toString().padLeft(2, '0')}',
                      style: TextStyle(color: Colors.grey.shade600)),
                ],
                const Spacer(),
                ..._actions(st),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _hero(String st) {
    switch (st) {
      case 'paid':
        return const Icon(Icons.check_circle_rounded, color: _green, size: 96);
      case 'failed':
      case 'expired':
        return Icon(Icons.error_outline_rounded, color: Colors.orange.shade700, size: 96);
      default:
        return const SizedBox(width: 84, height: 84, child: CircularProgressIndicator(strokeWidth: 6, color: _green));
    }
  }

  String _title(String st) {
    switch (st) {
      case 'paid':
        return 'Payment received';
      case 'failed':
        return 'Payment not completed';
      case 'expired':
        return 'Request timed out';
      default:
        return 'Check your phone';
    }
  }

  String _body(String st) {
    switch (st) {
      case 'paid':
        return 'Thank you! Your rider has been notified. No cash needed.';
      case 'failed':
        return '${_status.reason ?? 'The payment did not go through.'}\nYou can pay the rider in cash, or ask them to send the request again.';
      case 'expired':
        return 'We did not get a response. Pay the rider in cash, or ask them to resend the request.';
      default:
        return 'Enter your M-Pesa PIN on the prompt to pay your rider.\nThis is the only payment prompt AquaGas will send you.';
    }
  }

  List<Widget> _actions(String st) {
    if (st == 'paid') {
      return <Widget>[_primary('Done', () => Navigator.of(context).pop(true))];
    }
    return <Widget>[
      OutlinedButton(
        style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('Pay cash instead'),
      ),
      const SizedBox(height: 8),
      Text('Never share your M-Pesa PIN with anyone, including the rider.',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
    ];
  }

  Widget _primary(String label, VoidCallback onTap) => SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: onTap,
          child: Text(label, style: const TextStyle(fontSize: 16)),
        ),
      );
}
