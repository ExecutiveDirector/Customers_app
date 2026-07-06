// lib/models/outlet_products.dart
import 'package:aquagas/models/product.dart';

class OutletProducts {
  final int outletId;
  final String outletName;
  final int vendorId;
  final String vendorName;
  final double? distance;
  final List<Product> products;

  OutletProducts({
    required this.outletId,
    required this.outletName,
    required this.vendorId,
    required this.vendorName,
    this.distance,
    required this.products,
  });
}
