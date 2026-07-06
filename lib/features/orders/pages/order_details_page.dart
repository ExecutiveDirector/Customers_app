import 'package:flutter/material.dart';
import 'package:aquagas/features/orders/models/order_model.dart';
import 'package:aquagas/features/orders/services/order_service.dart';
import 'package:aquagas/features/orders/pages/order_tracking_page.dart';

class OrderDetailsPage extends StatefulWidget {
  final String orderId;

  const OrderDetailsPage({
    super.key,
    required this.orderId,
  });

  @override
  State<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  late Future<OrderModel> future;

  @override
  void initState() {
    super.initState();
    future = OrderService().getOrder(widget.orderId);
  }

  Future<void> _cancelOrder() async {
    await OrderService().cancelOrder(widget.orderId, 'Customer Request');

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Order cancelled')),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
      ),
      body: FutureBuilder<OrderModel>(
        future: future,
        builder: (BuildContext _, AsyncSnapshot<OrderModel> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }

          if (!snapshot.hasData) {
            return const SizedBox.shrink();
          }

          final OrderModel order = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Order #${order.id}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(order.status),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Items',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...order.items.map(
                  (item) => ListTile(
                    title: Text(item.productName),
                    subtitle: Text('Qty ${item.quantity}'),
                    trailing: Text('KES ${item.total.toStringAsFixed(2)}'),
                  ),
                ),
                const Divider(),
                ListTile(
                  title: const Text('Subtotal'),
                  trailing: Text('KES ${order.subtotal.toStringAsFixed(2)}'),
                ),
                ListTile(
                  title: const Text('Delivery Fee'),
                  trailing: Text('KES ${order.deliveryFee.toStringAsFixed(2)}'),
                ),
                ListTile(
                  title: const Text('Total'),
                  trailing: Text(
                    'KES ${order.grandTotal.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    title: const Text('Payment'),
                    subtitle:
                        Text('${order.paymentMethod}\n${order.paymentStatus}'),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    title: const Text('Delivery Address'),
                    subtitle: Text(order.deliveryAddress ?? 'N/A'),
                  ),
                ),
                if (order.rider != null)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.delivery_dining),
                      title: Text(order.rider!.name),
                      subtitle: Text(order.rider!.phone),
                    ),
                  ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.local_shipping),
                    label: const Text('Track Order'),
                    onPressed: () {
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (BuildContext _) => OrderTrackingPage(
                            tracking: order.toTracking(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                if (order.status != 'delivered' && order.status != 'cancelled')
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _cancelOrder,
                      child: const Text('Cancel Order'),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
