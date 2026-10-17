import 'package:flutter/material.dart';
import 'package:aquagas/features/orders/models/order_model.dart';
import 'package:aquagas/features/orders/services/order_service.dart';
import 'package:aquagas/features/orders/pages/order_tracking_page.dart';
import 'package:aquagas/features/orders/pages/rate_order_page.dart';
import 'package:aquagas/features/chat/order_chat_page.dart';

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

  bool _cancelling = false;

  /// Customers can cancel until the vendor starts preparing (server enforces this too).
  static bool _canCancel(String status) =>
      status == 'pending' || status == 'confirmed' || status == 'draft';

  Future<void> _cancelOrder(OrderModel order) async {
    const List<String> reasons = <String>[
      'Ordered by mistake',
      'Found a better price',
      'Delivery takes too long',
      'Changed my mind',
    ];
    final TextEditingController other = TextEditingController();
    String? picked;
    final String? reason = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setLocal) => AlertDialog(
          title: const Text('Cancel this order?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (order.paymentStatus.toLowerCase() == 'paid')
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('You have already paid. Our team will refund you.'),
                  ),
                for (final String r in reasons)
                  RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: r,
                    groupValue: picked,
                    title: Text(r),
                    onChanged: (String? v) => setLocal(() => picked = v),
                  ),
                TextField(
                  controller: other,
                  decoration: const InputDecoration(labelText: 'Other reason (optional)'),
                  onChanged: (_) => setLocal(() {}),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Keep order')),
            FilledButton(
              onPressed: (picked != null || other.text.trim().length >= 3)
                  ? () => Navigator.pop(
                      ctx, other.text.trim().length >= 3 ? other.text.trim() : picked)
                  : null,
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Cancel order'),
            ),
          ],
        ),
      ),
    );
    other.dispose();
    if (reason == null) return;

    setState(() => _cancelling = true);
    try {
      await OrderService().cancelOrder(widget.orderId, reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(order.paymentStatus.toLowerCase() == 'paid'
            ? 'Order cancelled. Our team will process your refund.'
            : 'Order cancelled'),
      ));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _cancelling = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: Colors.red,
      ));
    }
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
                if (<String>['confirmed', 'preparing', 'ready', 'dispatched', 'delivered']
                    .contains(order.status.toLowerCase()))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text('Chat with rider'),
                        onPressed: () => Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (BuildContext _) =>
                                OrderChatPage(orderId: order.id),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (order.status == 'delivered')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.star_rounded),
                      label: const Text('Rate Your Order'),
                      onPressed: () {
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (BuildContext _) => RateOrderPage(orderId: order.id),
                          ),
                        );
                      },
                    ),
                  ),
                if (_canCancel(order.status.toLowerCase()))
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _cancelling ? null : () => _cancelOrder(order),
                      child: Text(_cancelling ? 'Cancelling…' : 'Cancel Order'),
                    ),
                  )
                else if (!<String>['delivered', 'cancelled', 'canceled', 'refunded']
                    .contains(order.status.toLowerCase()))
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Your order is already being prepared or delivered. Contact support if you need to cancel.',
                      style: TextStyle(color: Colors.grey),
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
