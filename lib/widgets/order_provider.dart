import 'package:flutter/foundation.dart';
import 'package:aquagas/app_order.dart' as models;

class OrderProvider extends ChangeNotifier {
  List<models.AppOrder> _orders = <models.AppOrder>[];

  List<models.AppOrder> get orders =>
      List<models.AppOrder>.unmodifiable(_orders);

  void addOrder(models.AppOrder order) {
    _orders.add(order);
    notifyListeners();
    debugPrint('Added order: ${order.id}');
  }

  void clearOrders() {
    _orders.clear();
    notifyListeners();
  }
}
