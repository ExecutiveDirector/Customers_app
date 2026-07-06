import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:aquagas/services/order_service.dart';
import 'package:aquagas/services/auth_service.dart';
import 'package:aquagas/features/orders/pages/order_details_page.dart';
import 'package:aquagas/features/orders/pages/order_tracking_page.dart';
import 'package:aquagas/features/orders/models/order_tracking.dart';

// ---------------------------------------------------------------------------
// Local Order model — maps directly to GET /orders/user response fields.
// ---------------------------------------------------------------------------
class Order {
  final int orderId;
  final String orderNumber;
  final String vendorName;
  final String orderStatus;
  final String paymentStatus;
  final double totalAmount;
  final String deliveryType;
  final String? deliveryAddress;
  final DateTime createdAt;
  final DateTime? estimatedDeliveryTime;
  final int itemCount;

  const Order({
    required this.orderId,
    required this.orderNumber,
    required this.vendorName,
    required this.orderStatus,
    required this.paymentStatus,
    required this.totalAmount,
    required this.deliveryType,
    this.deliveryAddress,
    required this.createdAt,
    this.estimatedDeliveryTime,
    this.itemCount = 0,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      orderId: int.tryParse(
            json['order_id']?.toString() ?? json['id']?.toString() ?? '',
          ) ??
          0,
      orderNumber:
          json['order_number']?.toString() ?? json['id']?.toString() ?? '',
      vendorName: json['vendor_name']?.toString() ??
          json['outlet_name']?.toString() ??
          'Unknown Vendor',
      orderStatus:
          (json['order_status'] ?? json['status'])?.toString() ?? 'pending',
      paymentStatus: json['payment_status']?.toString() ?? 'pending',
      totalAmount: double.tryParse(
            (json['total_amount'] ?? json['grand_total'] ?? json['total_price'])
                    ?.toString() ??
                '',
          ) ??
          0.0,
      deliveryType: json['delivery_type']?.toString() ?? 'home_delivery',
      deliveryAddress: json['delivery_address']?.toString(),
      createdAt: DateTime.tryParse(
            json['created_at']?.toString() ?? '',
          ) ??
          DateTime.now(),
      estimatedDeliveryTime: json['estimated_delivery_time'] != null
          ? DateTime.tryParse(
              json['estimated_delivery_time'].toString(),
            )
          : null,
      itemCount: int.tryParse(
            json['item_count']?.toString() ?? '',
          ) ??
          ((json['items'] as List?)?.length ?? 0),
    );
  }
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------
class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  String? _error;
  List<Order> _allOrders = <Order>[];
  String _selectedFilter = 'all';

  final OrderService _orderService = OrderService();
  final AuthService _authService = AuthService();

  static const List<String> _filters = <String>[
    'all',
    'active',
    'completed',
    'canceled',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchOrders() async {
    // Guard: ensure token exists before hitting the API.
    final bool authed = await _authService.isAuthenticated();
    if (!authed) {
      _redirectToLogin();
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final List<Map<String, dynamic>> raw =
          await _orderService.getUserOrders();
      if (mounted) {
        setState(() {
          _allOrders = raw.map(Order.fromJson).toList();
        });
      }
    } catch (e) {
      final String msg = e.toString();

      // 401 = expired token → clear + redirect to login
      if (msg.contains('401') ||
          msg.contains('Session expired') ||
          msg.contains('Not authenticated')) {
        await _authService.logout();
        _redirectToLogin();
        return;
      }

      // 403 = server actively refused (wrong role, banned account, secret rotation)
      // Don't auto-logout — user might need to know WHY before we wipe their session
      if (msg.contains('403') || msg.contains('Forbidden')) {
        if (mounted) {
          setState(() {
            _error =
                'Access denied (403). Your account may not have permission to '
                'view orders, or your session has expired. Please log out and '
                'log back in.\n\nServer said: ${msg.replaceFirst('Exception: ', '')}';
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _error = msg;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _redirectToLogin() {
    if (!mounted) return;
    // Pop back to the home stack and push sign-in on top.
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/sign_in',
      (Route<dynamic> route) => route.isFirst,
    );
  }

  List<Order> _getFilteredOrders() {
    const List<String> activeStatuses = <String>[
      'pending',
      'confirmed',
      'preparing',
      'ready',
      'dispatched',
      'in_transit',
      'processing',
    ];

    switch (_selectedFilter) {
      case 'active':
        return _allOrders
            .where((Order o) => activeStatuses.contains(o.orderStatus))
            .toList();
      case 'completed':
        return _allOrders
            .where((Order o) => o.orderStatus == 'delivered')
            .toList();
      case 'canceled':
        return _allOrders
            .where((Order o) =>
                o.orderStatus == 'canceled' ||
                o.orderStatus == 'cancelled' ||
                o.orderStatus == 'refunded')
            .toList();
      default:
        return _allOrders;
    }
  }

  // ---------------------------------------------------------------------------
  // Navigation helpers
  // ---------------------------------------------------------------------------

  void _navigateToOrderDetails(Order order) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext _) =>
            OrderDetailsPage(orderId: order.orderId.toString()),
      ),
    );
  }

  void _trackOrder(Order order) {
    // Build a minimal OrderTracking from what we already have so we can
    // open the tracking page immediately without a second API call.
    final OrderTracking tracking = OrderTracking(
      orderId: order.orderId.toString(),
      status: _mapStatus(order.orderStatus),
      createdAt: order.createdAt,
    );

    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext _) => OrderTrackingPage(tracking: tracking),
      ),
    );
  }

  void _reorder(Order order) {
    // Navigate to details — user can rebuild cart from there once
    // order-item API is wired up.
    _navigateToOrderDetails(order);
  }

  TrackingStatus _mapStatus(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return TrackingStatus.confirmed;
      case 'preparing':
      case 'processing':
        return TrackingStatus.processing;
      case 'ready':
      case 'dispatched':
      case 'in_transit':
        return TrackingStatus.inTransit;
      case 'delivered':
        return TrackingStatus.delivered;
      case 'canceled':
      case 'cancelled':
        return TrackingStatus.cancelled;
      default:
        return TrackingStatus.pending;
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'My Orders',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorWeight: 3,
          onTap: (int index) {
            setState(() {
              _selectedFilter = _filters[index];
            });
          },
          tabs: const <Tab>[
            Tab(text: 'All'),
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
            Tab(text: 'Canceled'),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.wifi_off, size: 56, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Could not load orders',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fetchOrders,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
              if (_error!.contains('403') || _error!.contains('Access denied'))
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: TextButton.icon(
                    onPressed: () async {
                      await _authService.logout();
                      _redirectToLogin();
                    },
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text(
                      'Log out and sign in again',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchOrders,
      child: _buildOrderList(),
    );
  }

  Widget _buildOrderList() {
    final List<Order> orders = _getFilteredOrders();

    if (orders.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (BuildContext context, int index) {
        return _buildOrderCard(orders[index]);
      },
    );
  }

  Widget _buildOrderCard(Order order) {
    const List<String> activeStatuses = <String>[
      'pending',
      'confirmed',
      'preparing',
      'ready',
      'dispatched',
      'in_transit',
      'processing',
    ];
    final bool isActive = activeStatuses.contains(order.orderStatus);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _navigateToOrderDetails(order),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          order.vendorName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          order.orderNumber.isNotEmpty
                              ? order.orderNumber
                              : '#${order.orderId}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(order.orderStatus),
                ],
              ),
              const Divider(height: 24),

              // Date + item count
              Row(
                children: <Widget>[
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatDateTime(order.createdAt),
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                  const Spacer(),
                  Text(
                    '${order.itemCount} item${order.itemCount != 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Delivery address
              if (order.deliveryAddress != null &&
                  order.deliveryAddress!.isNotEmpty) ...<Widget>[
                Row(
                  children: <Widget>[
                    Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order.deliveryAddress!,
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // ETA banner (active orders only)
              if (order.estimatedDeliveryTime != null && isActive) ...<Widget>[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.access_time,
                          size: 16, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Est. delivery: ${_formatTime(order.estimatedDeliveryTime!)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    'KSh ${order.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  if (isActive)
                    TextButton.icon(
                      onPressed: () => _trackOrder(order),
                      icon: const Icon(Icons.my_location, size: 18),
                      label: const Text('Track'),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).primaryColor,
                      ),
                    )
                  else if (order.orderStatus == 'delivered')
                    TextButton(
                      onPressed: () => _reorder(order),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).primaryColor,
                      ),
                      child: const Text('Reorder'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final (Color bg, Color fg, String label) = _statusStyle(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  (Color, Color, String) _statusStyle(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return (Colors.orange[100]!, Colors.orange[900]!, 'Pending');
      case 'confirmed':
        return (Colors.blue[100]!, Colors.blue[900]!, 'Confirmed');
      case 'preparing':
      case 'processing':
        return (Colors.purple[100]!, Colors.purple[900]!, 'Preparing');
      case 'ready':
        return (Colors.cyan[100]!, Colors.cyan[900]!, 'Ready');
      case 'dispatched':
      case 'in_transit':
        return (Colors.indigo[100]!, Colors.indigo[900]!, 'On the way');
      case 'delivered':
        return (Colors.green[100]!, Colors.green[900]!, 'Delivered');
      case 'canceled':
      case 'cancelled':
        return (Colors.red[100]!, Colors.red[900]!, 'Canceled');
      case 'refunded':
        return (Colors.grey[300]!, Colors.grey[800]!, 'Refunded');
      default:
        return (Colors.grey[200]!, Colors.grey[800]!, status);
    }
  }

  Widget _buildEmptyState() {
    return ListView(
      // Wrap in ListView so RefreshIndicator still works on empty state
      children: <Widget>[
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.shopping_bag_outlined,
                  size: 80, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No orders found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your order history will appear here',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Formatters
  // ---------------------------------------------------------------------------

  String _formatDateTime(DateTime dateTime) {
    final DateTime now = DateTime.now();
    final Duration difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours != 1 ? 's' : ''} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays != 1 ? 's' : ''} ago';
    } else {
      return DateFormat('MMM d, y').format(dateTime);
    }
  }

  String _formatTime(DateTime dateTime) {
    return DateFormat('h:mm a').format(dateTime);
  }
}
