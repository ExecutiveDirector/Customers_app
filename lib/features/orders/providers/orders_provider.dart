import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aquagas/features/orders/models/order_model.dart';
import 'package:aquagas/features/orders/repositories/order_repository.dart';
import 'package:aquagas/features/orders/providers/order_repository_provider.dart';

class OrdersNotifier extends StateNotifier<AsyncValue<List<OrderModel>>> {
  OrdersNotifier(this._repository) : super(const AsyncLoading());

  final IOrderRepository _repository;

  Future<void> loadOrders({String status = 'all'}) async {
    try {
      state = const AsyncLoading();
      final List<OrderModel> orders =
          await _repository.getOrders(status: status);
      state = AsyncData<List<OrderModel>>(orders);
    } catch (e, stack) {
      state = AsyncError(e, stack);
    }
  }

  Future<void> refresh({String status = 'all'}) async {
    await loadOrders(status: status);
  }
}

final ordersNotifierProvider =
    StateNotifierProvider<OrdersNotifier, AsyncValue<List<OrderModel>>>(
  (ref) => OrdersNotifier(ref.read(orderRepositoryProvider)),
);
