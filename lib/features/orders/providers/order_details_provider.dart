import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aquagas/features/orders/models/order_model.dart';
import 'package:aquagas/features/orders/providers/order_repository_provider.dart';

final orderDetailsProvider =
    FutureProvider.family<OrderModel, String>((ref, orderId) async {
  final repository = ref.read(orderRepositoryProvider);
  return repository.getOrderById(orderId);
});
