import 'package:aquagas/features/orders/models/order_model.dart';
import 'package:aquagas/features/orders/services/order_service.dart';

abstract class IOrderRepository {
  Future<List<OrderModel>> getOrders({
    int page,
    int limit,
    String status,
  });

  Future<OrderModel> getOrderById(String orderId);

  Future<void> cancelOrder({
    required String orderId,
    required String reason,
  });

  Future<void> submitReview({
    required String orderId,
    required int rating,
    required String review,
  });
}

class OrderRepository implements IOrderRepository {
  final OrderService _service;

  OrderRepository({required OrderService service}) : _service = service;

  @override
  Future<List<OrderModel>> getOrders({
    int page = 1,
    int limit = 10,
    String status = 'all',
  }) async {
    return _service.getOrders(
      page: page,
      limit: limit,
      status: status,
    );
  }

  @override
  Future<OrderModel> getOrderById(String orderId) async {
    return _service.getOrder(orderId);
  }

  @override
  Future<void> cancelOrder({
    required String orderId,
    required String reason,
  }) async {
    await _service.cancelOrder(orderId, reason);
  }

  @override
  Future<void> submitReview({
    required String orderId,
    required int rating,
    required String review,
  }) async {
    await _service.submitReview(
      orderId: orderId,
      rating: rating,
      review: review,
    );
  }
}
