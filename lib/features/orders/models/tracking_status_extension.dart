import 'package:aquagas/features/orders/models/order_tracking.dart';

extension TrackingStatusExtension on TrackingStatus {
  String get label {
    switch (this) {
      case TrackingStatus.pending:
        return 'Pending';
      case TrackingStatus.confirmed:
        return 'Confirmed';
      case TrackingStatus.processing:
        return 'Preparing';
      case TrackingStatus.inTransit:
        return 'In Transit';
      case TrackingStatus.delivered:
        return 'Delivered';
      case TrackingStatus.cancelled:
        return 'Cancelled';
    }
  }
}
