import 'package:flutter_test/flutter_test.dart';
import 'package:aquagas/services/cod_payment_service.dart';

void main() {
  test('parses a waiting M-Pesa request', () {
    final s = CodPaymentStatus.fromJson(
        {'state': 'waiting', 'amount': '7040.00', 'seconds_left': 80, 'is_paid': false});
    expect(s.isWaiting, isTrue);
    expect(s.amount, 7040);
    expect(s.secondsLeft, 80);
  });

  test('missing fields fall back to a safe "none" state', () {
    final s = CodPaymentStatus.fromJson({});
    expect(s.state, 'none');
    expect(s.isWaiting, isFalse);
    expect(s.isPaid, isFalse);
  });
}
