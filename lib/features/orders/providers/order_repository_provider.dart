import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aquagas/features/orders/repositories/order_repository.dart';
import 'package:aquagas/features/orders/services/order_service.dart';

final orderRepositoryProvider = Provider<IOrderRepository>((ref) {
  return OrderRepository(
    service: OrderService(),
  );
});
