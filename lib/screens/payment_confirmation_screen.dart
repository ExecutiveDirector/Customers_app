import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:aquagas/app_order.dart' as models;
import 'package:aquagas/main.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:aquagas/app.dart';
import 'package:aquagas/services/auth_service.dart';
import 'package:aquagas/services/order_service.dart';

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

  final AuthService _authService = AuthService();
  final OrderService _orderService = OrderService();

  @override
  void initState() {
    super.initState();
    _initializeOrder();
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

  Future<void> _fetchOrderDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
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

      final Map<String, dynamic>? loc =
          orderData['deliveryLocation'] as Map<String, dynamic>?;
      LatLng? deliveryLocation =
          loc != null && loc['latitude'] is num && loc['longitude'] is num
              ? LatLng(
                  (loc['latitude'] as num).toDouble(),
                  (loc['longitude'] as num).toDouble(),
                )
              : null;

      if (mounted) {
        setState(() {
          _order = models.AppOrder(
            id: orderData['_id'] as String,
            userId: orderData['userId'] as String,
            vendorName: orderData['vendorName'] as String,
            status: orderData['status'] as String,
            timestamp: DateTime.parse(orderData['createdAt'] as String),
            items: (orderData['items'] as List<dynamic>)
                .map((dynamic item) =>
                    models.OrderItem.fromJson(item as Map<String, dynamic>))
                .toList(),
            totalPrice: (orderData['totalPrice'] as num).toDouble(),
            quantity: orderData['quantity'] as int,
            deliveryLocation: deliveryLocation,
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isGuest = true;
          _errorMessage = 'Order confirmed! Sign in to view full details.';
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
        title: const Text('Payment Confirmation',
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
              const Text(
                'Payment Successful!',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),

              // ✅ GUEST MODE: Show guest notice if applicable
              if (_isGuest && _order == null)
                _buildGuestNotice()
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
        onPressed: _order != null && _order!.id.isNotEmpty
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
