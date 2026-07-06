import 'package:flutter/foundation.dart';

@immutable
class OrderItem {
  final String productName;
  final String? outletName;
  final int quantity;
  final double price;
  final double total;

  const OrderItem({
    required this.productName,
    required this.quantity,
    required this.price,
    required this.total,
    this.outletName,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productName: json['product_name']?.toString() ?? 'Unknown Product',
      outletName: json['outlet_name']?.toString(),
      quantity: int.tryParse(json['quantity']?.toString() ?? '') ?? 0,
      price: double.tryParse(json['price']?.toString() ?? '') ?? 0.0,
      total: double.tryParse(json['total']?.toString() ?? '') ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'product_name': productName,
      'outlet_name': outletName,
      'quantity': quantity,
      'price': price,
      'total': total,
    };
  }

  OrderItem copyWith({
    String? productName,
    String? outletName,
    int? quantity,
    double? price,
    double? total,
  }) {
    return OrderItem(
      productName: productName ?? this.productName,
      outletName: outletName ?? this.outletName,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      total: total ?? this.total,
    );
  }

  @override
  String toString() {
    return 'OrderItem(productName: $productName, quantity: $quantity, price: $price, total: $total)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is OrderItem &&
            other.productName == productName &&
            other.outletName == outletName &&
            other.quantity == quantity &&
            other.price == price &&
            other.total == total;
  }

  @override
  int get hashCode {
    return Object.hash(
      productName,
      outletName,
      quantity,
      price,
      total,
    );
  }
}
