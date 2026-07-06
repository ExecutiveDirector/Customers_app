import 'package:aquagas/features/orders/models/order_model.dart';
import 'package:aquagas/services/order_service.dart' as base_service;

/// Thin wrapper around the existing OrderService that returns typed models
/// used by the features/orders layer.
class OrderService {
  final base_service.OrderService _base = base_service.OrderService();

  /// Fetch a paginated list of orders for the current user.
  Future<List<OrderModel>> getOrders({
    int page = 1,
    int limit = 10,
    String status = 'all',
  }) async {
    final List<Map<String, dynamic>> raw = await _base.getUserOrders();

    // Filter by status if not 'all'
    final filtered = status == 'all'
        ? raw
        : raw
            .where((o) =>
                (o['status']?.toString().toLowerCase() ?? '') ==
                status.toLowerCase())
            .toList();

    return filtered.map(OrderModel.fromJson).toList();
  }

  /// Fetch a single order by ID.
  Future<OrderModel> getOrder(String orderId) async {
    final Map<String, dynamic> raw = await _base.getOrderById(orderId);
    return OrderModel.fromJson(raw);
  }

  /// Cancel an order.
  Future<void> cancelOrder(String orderId, String reason) async {
    await _base.cancelOrder(orderId, reason: reason);
  }

  /// Submit a review / rating for a delivered order.
  /// NOTE: The base OrderService does not yet expose this endpoint.
  /// This is a placeholder that can be wired once the backend supports it.
  Future<void> submitReview({
    required String orderId,
    required int rating,
    required String review,
  }) async {
    // TODO: implement once backend exposes POST /orders/:id/review
    throw UnimplementedError(
        'submitReview is not yet supported by the backend');
  }
}
