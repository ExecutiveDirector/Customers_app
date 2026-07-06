import 'package:flutter/material.dart';
import 'package:aquagas/features/orders/pages/orders_page.dart';
import 'package:aquagas/features/orders/pages/order_details_page.dart';

/// Named route constants and helpers for the orders feature.
/// Uses Navigator 1.0 (MaterialPageRoute) since go_router is not a dependency.
class OrdersRoutes {
  const OrdersRoutes._();

  static const String orders = '/orders';
  static const String orderDetails = '/orders/details';

  static Route<void> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case orders:
        return MaterialPageRoute<void>(
          builder: (BuildContext _) => const OrdersPage(),
        );
      case orderDetails:
        final String orderId = settings.arguments as String;
        return MaterialPageRoute<void>(
          builder: (BuildContext _) => OrderDetailsPage(orderId: orderId),
        );
      default:
        return MaterialPageRoute<void>(
          builder: (BuildContext _) => const OrdersPage(),
        );
    }
  }

  /// Push the orders list onto the navigator stack.
  static Future<void> pushOrders(BuildContext context) {
    return Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext _) => const OrdersPage(),
      ),
    );
  }

  /// Push a specific order's detail page.
  static Future<void> pushOrderDetails(BuildContext context, String orderId) {
    return Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext _) => OrderDetailsPage(orderId: orderId),
      ),
    );
  }
}
