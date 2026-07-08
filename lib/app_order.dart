import 'package:equatable/equatable.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class OrderItem extends Equatable {
  final String id;
  final String name;
  final double price;
  final int quantity;

  const OrderItem({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      quantity: json['quantity'] as int,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'price': price,
        'quantity': quantity,
      };

  /// ✅ Added `copyWith()` for immutability and updates
  OrderItem copyWith({
    String? id,
    String? name,
    double? price,
    int? quantity,
  }) {
    return OrderItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
    );
  }

  @override
  List<Object> get props => [id, name, price, quantity];
}

class AppOrder extends Equatable {
  final String id;
  final String userId;
  final String vendorName;
  final String status;
  final DateTime timestamp;
  final List<OrderItem> items;
  final double totalPrice;
  final int quantity;
  final LatLng? deliveryLocation;
  // The outlet this order was placed with. Needed to look up pickup
  // location correctly: vendor_outlets has latitude/longitude, the
  // vendors table does not — looking up "the vendor" by name for pickup
  // location can never work (see payment_options_screen.dart).
  final String? outletId;

  const AppOrder({
    required this.id,
    required this.userId,
    required this.vendorName,
    required this.status,
    required this.timestamp,
    required this.items,
    required this.totalPrice,
    required this.quantity,
    this.deliveryLocation,
    this.outletId,
  });

  /// ✅ Added `copyWith()` for easier updates and navigation arguments
  AppOrder copyWith({
    String? id,
    String? userId,
    String? vendorName,
    String? status,
    DateTime? timestamp,
    List<OrderItem>? items,
    double? totalPrice,
    int? quantity,
    LatLng? deliveryLocation,
    String? outletId,
  }) {
    return AppOrder(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      vendorName: vendorName ?? this.vendorName,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      items: items ?? this.items,
      totalPrice: totalPrice ?? this.totalPrice,
      quantity: quantity ?? this.quantity,
      deliveryLocation: deliveryLocation ?? this.deliveryLocation,
      outletId: outletId ?? this.outletId,
    );
  }

  factory AppOrder.fromJson(Map<String, dynamic> json) {
    final List<dynamic> itemsJson = json['items'] as List<dynamic>;
    final List<OrderItem> orderItems = <OrderItem>[
      for (final dynamic item in itemsJson)
        OrderItem.fromJson(item as Map<String, dynamic>)
    ];

    final Map<String, dynamic>? deliveryJson =
        json['delivery_location'] as Map<String, dynamic>?;

    return AppOrder(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      vendorName: json['vendor_name'] as String,
      status: json['status'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      items: orderItems,
      totalPrice: (json['total_price'] as num).toDouble(),
      quantity: json['quantity'] as int,
      deliveryLocation: deliveryJson != null
          ? LatLng(
              (deliveryJson['lat'] as num).toDouble(),
              (deliveryJson['lng'] as num).toDouble(),
            )
          : null,
      outletId: json['outlet_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'user_id': userId,
        'vendor_name': vendorName,
        'status': status,
        'timestamp': timestamp.toIso8601String(),
        'items': <Map<String, dynamic>>[
          for (final OrderItem item in items) item.toJson()
        ],
        'total_price': totalPrice,
        'quantity': quantity,
        'delivery_location': deliveryLocation != null
            ? <String, double>{
                'lat': deliveryLocation!.latitude,
                'lng': deliveryLocation!.longitude,
              }
            : null,
        'outlet_id': outletId,
      };

  @override
  List<Object?> get props => [
        id,
        userId,
        vendorName,
        status,
        timestamp,
        items,
        totalPrice,
        quantity,
        deliveryLocation,
        outletId,
      ];
}