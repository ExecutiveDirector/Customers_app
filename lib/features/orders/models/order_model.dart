import 'package:aquagas/features/orders/models/order_item.dart';
import 'package:aquagas/features/orders/models/order_tracking.dart';

class RiderModel {
  final String id;
  final String name;
  final String phone;

  const RiderModel({
    required this.id,
    required this.name,
    required this.phone,
  });

  factory RiderModel.fromJson(Map<String, dynamic> json) {
    return RiderModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
    );
  }
}

class OrderModel {
  final String id;
  final String status;
  final DateTime createdAt;
  final DateTime? deliveredAt;

  final List<OrderItem> items;

  final double subtotal;
  final double deliveryFee;
  final double grandTotal;

  final String paymentMethod;
  final String paymentStatus;

  final String? deliveryAddress;
  final String? deliveryPhone;

  final String? vendorName;

  final RiderModel? rider;

  const OrderModel({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.items,
    required this.subtotal,
    required this.deliveryFee,
    required this.grandTotal,
    required this.paymentMethod,
    required this.paymentStatus,
    this.deliveryAddress,
    this.deliveryPhone,
    this.vendorName,
    this.rider,
    this.deliveredAt,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawItems =
        (json['items'] ?? json['order_items']) as List<dynamic>? ?? <dynamic>[];

    return OrderModel(
      id: json['id']?.toString() ?? json['order_id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      deliveredAt: json['delivered_at'] != null
          ? DateTime.tryParse(
              json['delivered_at'].toString(),
            )
          : null,
      items: rawItems
          .map<OrderItem>(
            (dynamic e) => OrderItem.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
      subtotal: double.tryParse(json['subtotal']?.toString() ?? '') ??
          double.tryParse(
            json['sub_total']?.toString() ?? '',
          ) ??
          0.0,
      deliveryFee: double.tryParse(
            json['delivery_fee']?.toString() ?? '',
          ) ??
          0.0,
      grandTotal: double.tryParse(
            json['grand_total']?.toString() ?? '',
          ) ??
          double.tryParse(
            json['total_price']?.toString() ?? '',
          ) ??
          double.tryParse(
            json['total_amount']?.toString() ?? '',
          ) ??
          0.0,
      paymentMethod: json['payment_method']?.toString() ?? '',
      paymentStatus: json['payment_status']?.toString() ?? '',
      deliveryAddress: json['delivery_address']?.toString(),
      deliveryPhone: json['delivery_phone']?.toString(),
      vendorName: json['vendor_name']?.toString(),
      rider: json['rider'] != null
          ? RiderModel.fromJson(
              json['rider'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  /// Convert to an [OrderTracking] for the tracking page.
  OrderTracking toTracking() {
    return OrderTracking.fromOrderJson(<String, dynamic>{
      'id': id,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'delivered_at': deliveredAt?.toIso8601String(),
      'rider': rider != null
          ? <String, dynamic>{
              'name': rider!.name,
              'phone': rider!.phone,
            }
          : null,
    });
  }
}
