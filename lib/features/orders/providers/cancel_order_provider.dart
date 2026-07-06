import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aquagas/features/orders/providers/order_repository_provider.dart';

final cancelOrderProvider =
    FutureProvider.family<void, ({String orderId, String reason})>(
  (ref, params) async {
    final repository = ref.read(orderRepositoryProvider);
    await repository.cancelOrder(
      orderId: params.orderId,
      reason: params.reason,
    );
  },
);
