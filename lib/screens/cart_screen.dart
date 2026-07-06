// lib/screens/cart_screen.dart
import 'package:flutter/material.dart';
import 'package:aquagas/cart.dart';
import 'package:aquagas/app_order.dart' as models;
import 'package:aquagas/services/auth_service.dart';
import 'package:aquagas/controllers/cart_controller.dart';
import 'package:aquagas/widgets/cart_widgets.dart';
import 'package:intl/intl.dart';
import 'package:aquagas/utils/cart_debugger.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' show cos, sqrt, asin, pi, sin;

/// Colour tokens — keeps greens consistent with the rest of the app.
const Color _kGreen = Color(0xFF10B981);
const Color _kGreenDark = Color(0xFF065F46);
const Color _kGreenLight = Color(0xFFD1FAE5);
const Color _kOrange = Color(0xFFF97316);
const Color _kSurface = Color(0xFFF8FAFC);
const Color _kBorder = Color(0xFFE2E8F0);

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final AuthService _authService = AuthService();
  final CartController _cartController = CartController();
  bool _isProcessing = false;
  bool _isGuest = true;
  Position? _userLocation;
  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
    _getUserLocation();
  }

  // ─── Auth / Location ──────────────────────────────────────────────────────

  Future<void> _checkAuthStatus() async {
    final bool isAuth = await _authService.isAuthenticated();
    if (mounted) setState(() => _isGuest = !isAuth);
  }

  Future<void> _getUserLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() => _isLoadingLocation = false);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _isLoadingLocation = false);
        return;
      }
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      );
      if (mounted) {
        setState(() {
          _userLocation = position;
          _isLoadingLocation = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  // ─── Cart helpers ─────────────────────────────────────────────────────────

  Map<String, dynamic>? _getOutletInfo() {
    if (cart.isEmpty) return null;
    final Map<String, dynamic> f = cart.items.first;
    return <String, dynamic>{
      'outlet_id': f['outlet_id'],
      'outlet_name': f['outlet_name'] ?? f['outletName'],
      'vendor_id': f['vendor_id'],
      'vendor_name': f['vendor_name'] ?? f['vendorName'],
      'outlet_latitude': f['outlet_latitude'],
      'outlet_longitude': f['outlet_longitude'],
      'distance': f['distance'],
    };
  }

  bool _hasMultipleOutlets() {
    if (cart.items.length <= 1) return false;
    return cart.items
            .map<dynamic>((Map<String, dynamic> i) => i['outlet_id'])
            .where((dynamic id) => id != null)
            .toSet()
            .length >
        1;
  }

  String _getDisplayDistance() {
    final Map<String, dynamic>? info = _getOutletInfo();
    if (info?['distance'] != null) {
      return _formatDistance((info!['distance'] as num).toDouble());
    }
    if (_userLocation != null &&
        info?['outlet_latitude'] != null &&
        info?['outlet_longitude'] != null) {
      final double lat = (info!['outlet_latitude'] as num).toDouble();
      final double lng = (info['outlet_longitude'] as num).toDouble();
      return _formatDistance(_calculateDistance(LatLng(lat, lng)));
    }
    return 'N/A';
  }

  double _calculateDistance(LatLng outlet) {
    if (_userLocation == null) return 0.0;
    const double r = 6371.0;
    final double dLat = _toRad(outlet.latitude - _userLocation!.latitude);
    final double dLon = _toRad(outlet.longitude - _userLocation!.longitude);
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(_userLocation!.latitude)) *
            cos(_toRad(outlet.latitude)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return r * 2 * asin(sqrt(a));
  }

  double _toRad(double deg) => deg * (pi / 180);

  String _formatDistance(double km) =>
      km < 1 ? '${(km * 1000).toInt()}m' : '${km.toStringAsFixed(1)}km';

  void _updateItemQuantity(Map<String, dynamic> item, bool increase) {
    if (increase)
      cart.addItem(item);
    else
      cart.removeItem(item);
    setState(() {});
  }

  void _goToCheckout() {
    CartDebugger.diagnoseCart();
    if (_hasMultipleOutlets()) return;

    final Map<String, dynamic>? outletInfo = _getOutletInfo();

    final List<models.OrderItem> orderItems =
        cart.items.map((Map<String, dynamic> item) {
      return models.OrderItem(
        id: (item['product_id'] ?? item['id'] ?? '').toString(),
        name: (item['product_name'] ?? item['title'] ?? 'Unknown').toString(),
        price: (item['price'] as num?)?.toDouble() ?? 0.0,
        quantity: (item['quantity'] as int?) ?? 1,
      );
    }).toList();

    final models.AppOrder appOrder = models.AppOrder(
      id: '',
      userId: '',
      vendorName: outletInfo?['vendor_name']?.toString() ?? '',
      status: 'draft',
      timestamp: DateTime.now(),
      items: orderItems,
      totalPrice: cart.totalAmount,
      quantity: cart.totalQuantity,
    );

    Navigator.pushNamed(context, '/payment_options', arguments: appOrder);
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? outletInfo = _getOutletInfo();
    final int itemCount = cart.totalQuantity;

    return Scaffold(
      backgroundColor: _kSurface,
      appBar: _buildAppBar(itemCount, outletInfo),
      body: cart.isEmpty
          ? const EmptyCartView()
          : Column(
              children: <Widget>[
                if (_hasMultipleOutlets()) _buildMultiOutletBanner(),
                if (_isGuest && !_hasMultipleOutlets()) _buildGuestBanner(),
                Expanded(
                  child: CustomScrollView(
                    slivers: <Widget>[
                      if (!_hasMultipleOutlets() && outletInfo != null)
                        SliverToBoxAdapter(
                          child: _buildOutletCard(outletInfo),
                        ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (BuildContext context, int index) {
                              final Map<String, dynamic> item =
                                  cart.items[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: CartItemCard(
                                  item: item,
                                  onQuantityUpdate: _updateItemQuantity,
                                ),
                              );
                            },
                            childCount: cart.itemCount,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildCheckoutBar(),
              ],
            ),
    );
  }

  AppBar _buildAppBar(int itemCount, Map<String, dynamic>? outletInfo) {
    final String? outletName = outletInfo?['outlet_name']?.toString();
    return AppBar(
      backgroundColor: _kGreen,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'My Cart${itemCount > 0 ? ' · $itemCount ${itemCount == 1 ? 'item' : 'items'}' : ''}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
          if (outletName != null)
            Row(
              children: <Widget>[
                const Icon(Icons.store_outlined,
                    color: Colors.white60, size: 12),
                const SizedBox(width: 3),
                Text(outletName,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(width: 6),
                const Icon(Icons.circle, color: Colors.white38, size: 3),
                const SizedBox(width: 6),
                const Icon(Icons.near_me_outlined,
                    color: Colors.white60, size: 12),
                const SizedBox(width: 3),
                Text(_getDisplayDistance(),
                    style:
                        const TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
        ],
      ),
      actions: <Widget>[
        if (cart.isNotEmpty)
          TextButton.icon(
            onPressed: () => _cartController.clearCart(context),
            icon: const Icon(Icons.delete_sweep_outlined,
                color: Colors.white70, size: 18),
            label: const Text('Clear',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
          ),
      ],
    );
  }

  // ─── Banners ──────────────────────────────────────────────────────────────

  Widget _buildMultiOutletBanner() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: const Color(0xFFFFF7ED),
        child: Row(
          children: const <Widget>[
            Icon(Icons.warning_amber_rounded,
                color: Color(0xFFEA580C), size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Items from different outlets detected — please checkout each outlet separately.',
                style: TextStyle(
                    color: Color(0xFF7C2D12), fontSize: 12, height: 1.4),
              ),
            ),
          ],
        ),
      );

  Widget _buildGuestBanner() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: const Color(0xFFEFF6FF),
        child: Row(
          children: <Widget>[
            const Icon(Icons.info_outline, color: Color(0xFF3B82F6), size: 18),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Shopping as guest — sign in to track your orders.',
                style: TextStyle(color: Color(0xFF1E3A8A), fontSize: 12),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/signIn'),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Sign In',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

  // ─── Outlet card ──────────────────────────────────────────────────────────

  Widget _buildOutletCard(Map<String, dynamic> outletInfo) {
    final String outletName =
        outletInfo['outlet_name']?.toString() ?? 'Unknown Outlet';
    final String vendorName =
        outletInfo['vendor_name']?.toString() ?? 'Unknown Vendor';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _kGreenLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.store_rounded, color: _kGreen, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(outletName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(vendorName,
                    style:
                        const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _kGreenLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.near_me, color: _kGreen, size: 13),
                const SizedBox(width: 3),
                Text(
                  _isLoadingLocation ? '…' : _getDisplayDistance(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _kGreenDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Checkout bar ─────────────────────────────────────────────────────────

  Widget _buildCheckoutBar() {
    final NumberFormat fmt = NumberFormat.currency(
        locale: 'en_KE', symbol: 'KSh ', decimalDigits: 2);
    final double subtotal = cart.totalAmount;
    final bool canCheckout =
        !_isProcessing && !_hasMultipleOutlets() && cart.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _kBorder)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  '${cart.totalQuantity} ${cart.totalQuantity == 1 ? 'item' : 'items'}',
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                Row(
                  children: <Widget>[
                    const Text('Subtotal  ',
                        style:
                            TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                    Text(
                      fmt.format(subtotal),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Delivery fee & tax confirmed at checkout',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: canCheckout ? _goToCheckout : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kOrange,
                  disabledBackgroundColor: Colors.grey.shade200,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13)),
                  elevation: canCheckout ? 2 : 0,
                ),
                child: _isProcessing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            _hasMultipleOutlets()
                                ? 'Multiple outlets — checkout separately'
                                : 'Proceed to Checkout',
                            style: TextStyle(
                              color: canCheckout
                                  ? Colors.white
                                  : Colors.grey.shade400,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.1,
                            ),
                          ),
                          if (canCheckout) ...<Widget>[
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded,
                                color: Colors.white, size: 18),
                          ],
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
