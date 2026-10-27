import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:aquagas/app_order.dart' as models;
import 'package:aquagas/main.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:aquagas/app.dart';
import 'package:aquagas/services/auth_service.dart';
import 'package:aquagas/services/order_service.dart';
import 'package:aquagas/services/cod_payment_service.dart';
import 'package:aquagas/screens/cod_payment_screen.dart';

class PaymentConfirmationScreen extends StatefulWidget {
  final String paymentOption;
  final String orderId;
  final String? address;

  // ✅ NEW: Optional order data for guest users
  final models.AppOrder? guestOrderData;

  const PaymentConfirmationScreen({
    super.key,
    required this.paymentOption,
    required this.orderId,
    this.address,
    this.guestOrderData,
  });

  @override
  State<PaymentConfirmationScreen> createState() =>
      _PaymentConfirmationScreenState();
}

class _PaymentConfirmationScreenState extends State<PaymentConfirmationScreen> {
  bool _isLoading = true;
  models.AppOrder? _order;
  String? _errorMessage;
  bool _isGuest = false;
  bool _loadFailed = false; // signed in, but the details could not be loaded
  CodPaymentWatcher? _codWatcher;

  bool get _isCash {
    final String o = widget.paymentOption.toLowerCase();
    return o.contains('cash') || o.contains('cod');
  }

  final AuthService _authService = AuthService();
  final OrderService _orderService = OrderService();

  @override
  void initState() {
    super.initState();
    _initializeOrder();
    if (_isCash) {
      // If the rider asks for M-Pesa at the door, open the pay screen for the customer.
      _codWatcher = CodPaymentWatcher(orderId: widget.orderId, onRequested: _openCodPayment)..start();
    }
  }

  @override
  void dispose() {
    _codWatcher?.stop();
    super.dispose();
  }

  Future<void> _openCodPayment(CodPaymentStatus s) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(builder: (_) => CodPaymentScreen(orderId: widget.orderId, initial: s)),
    );
    _codWatcher?.reset();
  }

  Future<void> _initializeOrder() async {
    // ✅ GUEST MODE: Check if guest order data was provided
    if (widget.guestOrderData != null) {
      setState(() {
        _order = widget.guestOrderData;
        _isGuest = true;
        _isLoading = false;
      });
      return;
    }

    // Otherwise, fetch from backend
    await _fetchOrderDetails();
  }

  /// The API returns order_id / vendor_name / total_amount / items[product_name...];
  /// read those (and the older camelCase names) without ever throwing on a missing field.
  models.AppOrder _orderFromApi(Map<String, dynamic> o) {
    double d(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    int i(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 1;
    final List<models.OrderItem> items = (o['items'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map>()
        .map((Map m) => models.OrderItem(
              id: '${m['id'] ?? m['product_name'] ?? ''}',
              name: '${m['name'] ?? m['product_name'] ?? 'Item'}',
              price: d(m['price']),
              quantity: i(m['quantity']),
            ))
        .toList();
    final Object? loc = o['deliveryLocation'];
    final double? lat = o['delivery_lat'] != null
        ? d(o['delivery_lat'])
        : (loc is Map && loc['latitude'] is num ? (loc['latitude'] as num).toDouble() : null);
    final double? lng = o['delivery_lng'] != null
        ? d(o['delivery_lng'])
        : (loc is Map && loc['longitude'] is num ? (loc['longitude'] as num).toDouble() : null);
    return models.AppOrder(
      id: '${o['_id'] ?? o['order_id'] ?? o['id'] ?? widget.orderId}',
      userId: '${o['userId'] ?? o['customer_id'] ?? ''}',
      vendorName: '${o['vendorName'] ?? o['vendor_name'] ?? ''}',
      status: '${o['status'] ?? o['order_status'] ?? 'pending'}',
      timestamp: DateTime.tryParse('${o['createdAt'] ?? o['created_at'] ?? ''}') ?? DateTime.now(),
      items: items,
      totalPrice: d(o['totalPrice'] ?? o['grand_total'] ?? o['total_amount']),
      quantity: items.fold<int>(0, (int s, models.OrderItem e) => s + e.quantity),
      deliveryLocation: lat != null && lng != null ? LatLng(lat, lng) : null,
    );
  }

  Future<void> _fetchOrderDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _loadFailed = false;
    });

    try {
      final token = await _authService.getToken();

      // ✅ GUEST MODE: Handle missing token gracefully
      if (token == null) {
        setState(() {
          _isGuest = true;
          _isLoading = false;
          _errorMessage = 'Order confirmed! Sign in to track your order.';
        });
        return;
      }

      // Fetch order details from backend
      final orderData = await _orderService.getOrderById(widget.orderId);

      final models.AppOrder parsed = _orderFromApi(orderData);

      if (mounted) {
        setState(() {
          _order = parsed;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadFailed = true; // signed in: never ask them to sign in again
          _errorMessage = null;
        });

        debugPrint('Error fetching order details: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final NumberFormat currencyFormatter = NumberFormat.currency(
        locale: 'en_KE', symbol: 'KSh ', decimalDigits: 2);
    final DateFormat dateFormatter = DateFormat('MMM dd, yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: Text(_isCash ? 'Order Confirmed' : 'Payment Confirmation',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (mounted) {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : _buildContent(currencyFormatter, dateFormatter),
    );
  }

  Widget _buildContent(
      NumberFormat currencyFormatter, DateFormat dateFormatter) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              const Icon(Icons.verified_rounded,
                  color: Colors.green, size: 100),
              const SizedBox(height: 16),
              Text(
                _isCash ? 'Order placed!' : 'Payment Successful!',
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              if (_isCash) ...<Widget>[
                const SizedBox(height: 16),
                _buildPayOnDeliveryCard(),
              ],
              const SizedBox(height: 24),

              // ✅ GUEST MODE: Show guest notice if applicable
              if (_isGuest && _order == null)
                _buildGuestNotice()
              else if (_loadFailed && _order == null)
                _buildLoadFailedCard()
              else if (_order != null)
                _buildOrderDetails(currencyFormatter, dateFormatter),

              const SizedBox(height: 25),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPayOnDeliveryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFD1FAE5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const <Widget>[
          Row(children: <Widget>[
            Icon(Icons.payments_outlined, color: Color(0xFF064E3B)),
            SizedBox(width: 10),
            Expanded(
              child: Text('Pay when your gas arrives',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF064E3B))),
            ),
          ]),
          SizedBox(height: 8),
          Text(
            'Hand the rider cash, or pay by M-Pesa — your rider can send a payment '
            'prompt to your phone and you just enter your PIN. Keep your phone nearby.',
            style: TextStyle(fontSize: 14, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadFailedCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: <Widget>[
            const Icon(Icons.cloud_off_rounded, size: 40, color: Colors.grey),
            const SizedBox(height: 10),
            const Text('Your order is placed. We could not load the details just now.',
                textAlign: TextAlign.center),
            const SizedBox(height: 10),
            _detailRow(Icons.receipt_long, 'Order ID', widget.orderId),
            TextButton.icon(
              onPressed: _fetchOrderDetails,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestNotice() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 6,
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.info_outline, color: Colors.orange.shade700, size: 48),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Order Confirmed!',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.orange.shade900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            _detailRow(Icons.receipt_long, 'Order ID', widget.orderId),
            _detailRow(Icons.payment, 'Payment Method', widget.paymentOption),
            if (widget.address != null)
              _detailRow(
                  Icons.location_on, 'Delivery Address', widget.address!),
            const SizedBox(height: 16),
            Text(
              'Sign in to track your order and view full details',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderDetails(
      NumberFormat currencyFormatter, DateFormat dateFormatter) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _detailRow(Icons.receipt_long, 'Order ID', _order!.id),
            _detailRow(Icons.storefront, 'Vendor', _order!.vendorName),
            _detailRow(Icons.payment, 'Payment Method', widget.paymentOption),
            _detailRow(Icons.check_circle, 'Status', _order!.status),
            _detailRow(Icons.shopping_cart, 'Quantity', '${_order!.quantity}'),
            _detailRow(Icons.date_range, 'Date',
                dateFormatter.format(_order!.timestamp)),
            if (_order!.deliveryLocation != null)
              _detailRow(
                Icons.location_on,
                'Delivery Address',
                widget.address ??
                    'Lat: ${_order!.deliveryLocation!.latitude}, Lon: ${_order!.deliveryLocation!.longitude}',
              ),
            _detailRow(Icons.attach_money, 'Total',
                currencyFormatter.format(_order!.totalPrice),
                isBold: true),
            const Divider(height: 30),
            const Text('Items Ordered:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            for (models.OrderItem item in _order!.items)
              Text(
                '• ${item.name} (x${item.quantity}) - ${currencyFormatter.format(item.price)}',
                style: const TextStyle(fontSize: 15),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Back to Home Button
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[Colors.green.shade500, Colors.green.shade700],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              if (mounted) {
                Navigator.pushReplacementNamed(context, Routes.home);
              }
            },
            icon: const Icon(Icons.home_rounded, size: 22, color: Colors.white),
            label: const Text(
              'Back to Home',
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ✅ GUEST MODE: Conditional Track Order / Sign In button
        if (_isGuest) _buildSignInButton() else _buildTrackOrderButton(),
      ],
    );
  }

  Widget _buildTrackOrderButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[Colors.orange.shade500, Colors.orange.shade800],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: widget.orderId.isNotEmpty
            ? () {
                if (mounted) {
                  Navigator.pushNamed(context, Routes.trackOrder,
                      arguments: widget.orderId);
                }
              }
            : null,
        icon: const Icon(Icons.local_shipping_rounded,
            size: 22, color: Colors.white),
        label: const Text(
          'Track Order',
          style: TextStyle(fontSize: 16, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildSignInButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[Colors.blue.shade500, Colors.blue.shade700],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () {
          if (mounted) {
            Navigator.pushNamed(
              context,
              Routes.signIn,
              arguments: {
                'orderId': widget.orderId,
                'returnToTracking': true,
              },
            );
          }
        },
        icon: const Icon(Icons.login, size: 22, color: Colors.white),
        label: const Text(
          'Sign In to Track Order',
          style: TextStyle(fontSize: 16, color: Colors.white),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value,
      {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          Icon(icon, color: Colors.grey[600], size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$label: $value',
              style: TextStyle(
                fontSize: 15,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
