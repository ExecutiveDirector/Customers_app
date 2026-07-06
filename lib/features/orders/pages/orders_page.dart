import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aquagas/features/orders/models/order_model.dart';
import 'package:aquagas/features/orders/services/order_service.dart';
import 'package:aquagas/features/orders/pages/order_details_page.dart';

final ordersProvider =
    FutureProvider.family<List<OrderModel>, String>((ref, status) async {
  return OrderService().getOrders(status: status);
});

class OrdersPage extends ConsumerStatefulWidget {
  const OrdersPage({super.key});

  @override
  ConsumerState<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends ConsumerState<OrdersPage> {
  String selectedStatus = 'all';

  final List<String> statuses = const <String>[
    'all',
    'pending',
    'confirmed',
    'processing',
    'in_transit',
    'delivered',
    'cancelled',
  ];

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<OrderModel>> ordersAsync =
        ref.watch(ordersProvider(selectedStatus));

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
      ),
      body: Column(
        children: <Widget>[
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: statuses.length,
              itemBuilder: (BuildContext _, int index) {
                final String status = statuses[index];
                return Padding(
                  padding: const EdgeInsets.all(8),
                  child: ChoiceChip(
                    label: Text(status.replaceAll('_', ' ')),
                    selected: selectedStatus == status,
                    onSelected: (bool _) {
                      setState(() {
                        selectedStatus = status;
                      });
                    },
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: ordersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object e, StackTrace _) =>
                  Center(child: Text(e.toString())),
              data: (List<OrderModel> orders) {
                if (orders.isEmpty) {
                  return const Center(child: Text('No Orders Found'));
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(ordersProvider(selectedStatus));
                  },
                  child: ListView.builder(
                    itemCount: orders.length,
                    itemBuilder: (BuildContext _, int index) {
                      final OrderModel order = orders[index];
                      return Card(
                        margin: const EdgeInsets.all(12),
                        child: ListTile(
                          title: Text('Order #${order.id}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(order.status),
                              Text(
                                  'KES ${order.grandTotal.toStringAsFixed(2)}'),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push<void>(
                              context,
                              MaterialPageRoute<void>(
                                builder: (BuildContext _) => OrderDetailsPage(
                                  orderId: order.id,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
