import 'package:flutter/foundation.dart';

enum TrackingStatus {
  pending,
  confirmed,
  processing,
  inTransit,
  delivered,
  cancelled,
}

@immutable
class OrderTracking {
  final String orderId;
  final TrackingStatus status;

  final DateTime? createdAt;
  final DateTime? assignedAt;
  final DateTime? dispatchedAt;
  final DateTime? deliveredAt;

  final String? riderName;
  final String? riderPhone;

  const OrderTracking({
    required this.orderId,
    required this.status,
    this.createdAt,
    this.assignedAt,
    this.dispatchedAt,
    this.deliveredAt,
    this.riderName,
    this.riderPhone,
  });

  factory OrderTracking.fromOrderJson(
    Map<String, dynamic> json,
  ) {
    final rider = json['rider'] as Map<String, dynamic>?;

    return OrderTracking(
      orderId: json['id'].toString(),
      status: _mapStatus(
        json['status']?.toString() ?? '',
      ),
      createdAt: _parseDate(
        json['created_at'],
      ),
      assignedAt: _parseDate(
        json['assigned_at'],
      ),
      dispatchedAt: _parseDate(
        json['dispatched_at'],
      ),
      deliveredAt: _parseDate(
        json['delivered_at'],
      ),
      riderName: rider?['name']?.toString(),
      riderPhone: rider?['phone']?.toString(),
    );
  }

  static TrackingStatus _mapStatus(
    String status,
  ) {
    switch (status.toLowerCase()) {
      case 'pending':
        return TrackingStatus.pending;

      case 'confirmed':
        return TrackingStatus.confirmed;

      case 'processing':
        return TrackingStatus.processing;

      case 'in_transit':
        return TrackingStatus.inTransit;

      case 'delivered':
        return TrackingStatus.delivered;

      case 'cancelled':
        return TrackingStatus.cancelled;

      default:
        return TrackingStatus.pending;
    }
  }

  static DateTime? _parseDate(
    dynamic value,
  ) {
    if (value == null) return null;

    return DateTime.tryParse(
      value.toString(),
    );
  }

  int get currentStep {
    switch (status) {
      case TrackingStatus.pending:
        return 0;

      case TrackingStatus.confirmed:
        return 1;

      case TrackingStatus.processing:
        return 2;

      case TrackingStatus.inTransit:
        return 3;

      case TrackingStatus.delivered:
        return 4;

      case TrackingStatus.cancelled:
        return 0;
    }
  }

  bool get isCompleted => status == TrackingStatus.delivered;

  bool get isCancelled => status == TrackingStatus.cancelled;

  bool get hasRider => riderName != null && riderName!.isNotEmpty;

  List<String> get timelineSteps => const [
        'Order Placed',
        'Order Confirmed',
        'Preparing Order',
        'Out For Delivery',
        'Delivered',
      ];
}
