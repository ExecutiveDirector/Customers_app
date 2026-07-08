// lib/screens/payment_options_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:aquagas/app_order.dart' as models;
import 'package:aquagas/services/auth_service.dart';
import 'package:aquagas/screens/pesapal_webview.dart';
import 'package:aquagas/cart.dart';

// ─── Colour tokens ────────────────────────────────────────────────────────────
const Color _kGreen = Color(0xFF10B981);
const Color _kGreenDark = Color(0xFF065F46);
const Color _kGreenLight = Color(0xFFD1FAE5);
const Color _kBlue = Color(0xFF3B82F6);
const Color _kSurface = Color(0xFFF8FAFC);
const Color _kBorder = Color(0xFFE2E8F0);

class PaymentOptionsScreen extends StatefulWidget {
  final models.AppOrder order;
  const PaymentOptionsScreen({Key? key, required this.order}) : super(key: key);

  @override
  State<PaymentOptionsScreen> createState() => _PaymentOptionsScreenState();
}

class _PaymentOptionsScreenState extends State<PaymentOptionsScreen> {
  // ─── Constants ────────────────────────────────────────────────────────────
  static const String _baseUrl = 'https://aquagas-backend.onrender.com/api/v1';
  static const String _geoapifyKey = '46d6b25bcfb743a290349dbe55f79528';

  // ─── Services ─────────────────────────────────────────────────────────────
  final AuthService _auth = AuthService();
  final NumberFormat _currency =
      NumberFormat.currency(locale: 'en_KE', symbol: 'KSh ');

  // ─── Controllers ──────────────────────────────────────────────────────────
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();

  // ─── Delivery method ──────────────────────────────────────────────────────
  String _deliveryType = 'home';
  double _deliveryFee = 150.0;

  // Live pricing constants from the backend (utils/pricing.js /
  // GET /api/v1/config/pricing). Previously this screen hardcoded
  // `_deliveryFee = 150.0` and `0.0` for pickup directly, with no
  // free-delivery-threshold check at all (backend waives the delivery fee
  // above KES 7000) and no awareness that pickup from a "general"
  // (non-gas) vendor carries a flat pickup fee rather than being free.
  // Fallback values here match the backend's current defaults but the
  // live fetch is authoritative — see _fetchPricingConfig / _updatePickupFee.
  Map<String, dynamic> _pricingConfig = <String, dynamic>{
    'tax_rate': 0.06,
    'delivery_fee': 150,
    'free_delivery_threshold': 7000,
    'pickup_fee_general': 70,
  };
  String _vendorType = 'gas'; // 'gas' | 'general' — from the order's vendor

  // ─── Delivery schedule (home delivery only) ───────────────────────────────
  String _deliverySchedule = 'asap'; // 'asap' | 'scheduled'
  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;

  // ─── Location ─────────────────────────────────────────────────────────────
  LatLng? _location;
  String? _address;
  bool _isLoading = false;
  bool _isPaying = false;
  bool _isGuest = true;
  String _locationError = '';

  // ─── Payment ──────────────────────────────────────────────────────────────
  String _paymentMethod = 'pesapal';

  // ─── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _checkAuth();
    _fetchPricingConfig();
    _initLocation();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  // ─── Auth ─────────────────────────────────────────────────────────────────
  Future<void> _checkAuth() async {
    _isGuest = !await _auth.isAuthenticated();
  }

  // ─── Location helpers ─────────────────────────────────────────────────────
  Future<void> _initLocation() async {
    setState(() {
      _isLoading = true;
      _locationError = '';
    });

    if (_deliveryType == 'pickup') {
      await _fetchVendorLocation();
    } else {
      _vendorType = 'gas'; // home delivery ignores vendor_type
      await _fetchCustomerLocation();
    }
    _updatePickupFee();

    if (_location != null) await _resolveAddress();
    setState(() => _isLoading = false);
  }

  // ─── Pricing config ───────────────────────────────────────────────────────
  Future<void> _fetchPricingConfig() async {
    try {
      final http.Response res = await http.get(
        Uri.parse('$_baseUrl/config/pricing'),
        headers: await _headers(),
      );
      if (res.statusCode == 200) {
        final Map<String, dynamic> data =
            json.decode(res.body) as Map<String, dynamic>;
        setState(() => _pricingConfig = data);
        _updatePickupFee();
      }
      // On failure, silently keep the fallback values already in
      // _pricingConfig — never block checkout on this call.
    } catch (_) {
      // Fallback values already set; nothing further to do.
    }
  }

  /// Mirrors the backend's calculateOrderPricing() (utils/pricing.js)
  /// exactly: gas-vendor pickup is free, general-vendor pickup carries a
  /// flat service fee, and home delivery is free above the free-delivery
  /// threshold. The backend recomputes this independently and is always
  /// authoritative — this only drives the on-screen preview.
  void _updatePickupFee() {
    final double deliveryFeeBase =
        (_pricingConfig['delivery_fee'] as num?)?.toDouble() ?? 150.0;
    final double freeThreshold =
        (_pricingConfig['free_delivery_threshold'] as num?)?.toDouble() ??
            7000.0;
    final double pickupFeeGeneral =
        (_pricingConfig['pickup_fee_general'] as num?)?.toDouble() ?? 70.0;

    double fee;
    if (_deliveryType == 'pickup') {
      fee = _vendorType == 'general' ? pickupFeeGeneral : 0.0;
    } else {
      fee = widget.order.totalPrice >= freeThreshold ? 0.0 : deliveryFeeBase;
    }

    if (mounted) {
      setState(() => _deliveryFee = fee);
    } else {
      _deliveryFee = fee;
    }
  }

  Future<void> _fetchVendorLocation() async {
    // FIX: pickup location must come from vendor_outlets (via
    // GET /outlets/:outletId), not the vendors table — vendors has no
    // latitude/longitude columns at all, so looking it up by vendor name
    // could never resolve a location no matter how the response was parsed.
    // widget.order.outletId is the actual outlet this order was placed
    // with (see AppOrder / cart.dart _createAuthenticatedOrder).
    final String? outletId = widget.order.outletId;
    if (outletId == null || outletId.isEmpty) {
      setState(() => _locationError =
          'Could not determine which outlet this order belongs to. '
              'Please choose Home Delivery or contact support.');
      return;
    }

    try {
      final http.Response res = await http.get(
        Uri.parse('$_baseUrl/outlets/$outletId'),
        headers: await _headers(),
      );
      if (res.statusCode == 200) {
        // Shape: { outlet: { outlet_id, vendor_type, location: {lat, lng},
        // address: {line_1, line_2, city, county, postal_code}, ... } }
        // (outletController.getOutletById)
        final Map<String, dynamic> body =
            json.decode(res.body) as Map<String, dynamic>;
        final Map<String, dynamic>? outlet =
            body['outlet'] as Map<String, dynamic>?;

        if (outlet != null) {
          // vendor_type drives the pickup-fee preview below: gas vendor
          // pickup is free, general vendor pickup carries a flat fee.
          _vendorType = (outlet['vendor_type'] as String?) ?? 'gas';

          final Map<String, dynamic>? loc =
              outlet['location'] as Map<String, dynamic>?;
          final double? lat = (loc?['lat'] as num?)?.toDouble();
          final double? lng = (loc?['lng'] as num?)?.toDouble();

          if (lat != null && lng != null) {
            final Map<String, dynamic>? addr =
                outlet['address'] as Map<String, dynamic>?;
            final String? formattedAddress = addr != null
                ? <String?>[
                    addr['line_1'] as String?,
                    addr['line_2'] as String?,
                    addr['city'] as String?,
                    addr['county'] as String?,
                  ].where((String? part) => part != null && part.isNotEmpty).join(', ')
                : null;

            _location = LatLng(lat, lng);
            _address = formattedAddress;
            _addressCtrl.text = _address ?? '';
            _updatePickupFee();
            return;
          }
        }
        setState(() =>
            _locationError = 'This outlet has not set a pickup location yet. '
                'Please contact the vendor or choose Home Delivery.');
      } else {
        setState(() => _locationError =
            'Could not load outlet location (server error ${res.statusCode}). '
                'Please try again.');
      }
    } catch (_) {
      setState(() => _locationError =
          'Could not load outlet location. Check your connection and try again.');
    }
  }

  Future<void> _fetchCustomerLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() => _locationError =
            'Location services are off. Enable them in device settings.');
        return;
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        setState(() => _locationError =
            'Location permission is permanently denied. Enable it in app settings, '
                'or type your address manually.');
        return;
      }
      if (perm == LocationPermission.denied) {
        setState(() => _locationError =
            'Location permission denied. Tap refresh to try again, '
                'or type your address manually.');
        return;
      }
      final Position pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      setState(() => _location = LatLng(pos.latitude, pos.longitude));
    } catch (_) {
      setState(() => _locationError =
          'Failed to detect your location. Tap refresh or enter address manually.');
    }
  }

  Future<void> _resolveAddress() async {
    if (_location == null) return;
    try {
      final http.Response res =
          await http.get(Uri.parse('https://api.geoapify.com/v1/geocode/reverse'
              '?lat=${_location!.latitude}&lon=${_location!.longitude}'
              '&apiKey=$_geoapifyKey'));
      if (res.statusCode == 200) {
        final Map<String, dynamic> data =
            json.decode(res.body) as Map<String, dynamic>;
        final List<dynamic>? features = data['features'] as List<dynamic>?;
        if (features != null && features.isNotEmpty) {
          final Map<String, dynamic> props = Map<String, dynamic>.from(
              features.first['properties'] as Map<dynamic, dynamic>);
          final List<String> parts = <String>[];
          if (props['street'] != null) parts.add(props['street'] as String);
          if (props['city'] != null) {
            parts.add(props['city'] as String);
          } else if (props['locality'] != null) {
            parts.add(props['locality'] as String);
          }
          if (props['country'] != null) parts.add(props['country'] as String);
          _address = parts.isNotEmpty
              ? parts.join(', ')
              : (props['formatted'] as String?) ??
                  '${_location!.latitude}, ${_location!.longitude}';
          _addressCtrl.text = _address!;
        }
      }
    } catch (_) {
      _addressCtrl.text = '${_location!.latitude.toStringAsFixed(5)}, '
          '${_location!.longitude.toStringAsFixed(5)}';
    }
  }

  Future<void> _openDirections() async {
    if (_location == null) return;
    final Uri url = Uri.parse('https://www.google.com/maps/dir/?api=1'
        '&destination=${_location!.latitude},${_location!.longitude}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _showSnack('Could not open maps', Colors.red.shade700);
    }
  }

  // ─── Schedule helpers ─────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _scheduledDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (BuildContext ctx, Widget? child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _kGreen,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Colors.black,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _scheduledDate = picked);
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTime ?? TimeOfDay.now(),
      builder: (BuildContext ctx, Widget? child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _kGreen,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Colors.black,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _scheduledTime = picked);
  }

  bool get _isScheduleComplete =>
      _deliverySchedule == 'asap' ||
      (_scheduledDate != null && _scheduledTime != null);

  // ─── Payment flow ─────────────────────────────────────────────────────────
  Future<void> _startPayment() async {
    if (_phoneCtrl.text.trim().isEmpty) {
      _showSnack('Enter your phone number', Colors.red.shade700);
      return;
    }
    if (_deliveryType == 'home' &&
        _deliverySchedule == 'scheduled' &&
        (_scheduledDate == null || _scheduledTime == null)) {
      _showSnack(
          'Please select a delivery date and time', Colors.orange.shade700);
      return;
    }
    if (_location == null) {
      _showSnack(
        _deliveryType == 'pickup'
            ? 'Outlet pickup location is not available'
            : 'Please set a delivery location',
        Colors.red.shade700,
      );
      return;
    }
    if (_paymentMethod == 'mpesa') {
      _showSnack('M-Pesa integration coming soon!', Colors.orange.shade700);
      return;
    }

    setState(() => _isPaying = true);
    try {
      final String orderId = await _createDraftOrder();
      final Map<String, dynamic> payData = await _initiatePesapal(orderId);
      final String? redirectUrl = payData['redirect_url'] as String?;

      if (redirectUrl == null || redirectUrl.isEmpty) {
        throw Exception('No redirect URL returned from payment gateway');
      }

      if (!mounted) return;
      setState(() => _isPaying = false);

      final bool? paid = await Navigator.push<bool>(
        context,
        MaterialPageRoute<bool>(
          builder: (_) => PesapalWebView(url: redirectUrl, orderId: orderId),
        ),
      );

      if (paid == true) {
        await _confirmOrder(orderId);
      } else {
        await _cancelDraft(orderId);
        _showSnack('Payment cancelled', Colors.orange.shade700);
      }
    } catch (e) {
      if (mounted) _showSnack('Payment failed: $e', Colors.red.shade700);
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }

  Future<String> _createDraftOrder() async {
    final dynamic user = _isGuest ? null : await _auth.getCurrentUser();

    Map<String, dynamic>? deliveryScheduleData;
    if (_deliveryType == 'home') {
      if (_deliverySchedule == 'scheduled' &&
          _scheduledDate != null &&
          _scheduledTime != null) {
        final DateTime dt = DateTime(
          _scheduledDate!.year,
          _scheduledDate!.month,
          _scheduledDate!.day,
          _scheduledTime!.hour,
          _scheduledTime!.minute,
        );
        deliveryScheduleData = <String, dynamic>{
          'type': 'scheduled',
          'scheduled_datetime': dt.toIso8601String(),
          'scheduled_date': DateFormat('yyyy-MM-dd').format(_scheduledDate!),
          'scheduled_time': _scheduledTime!.format(context),
        };
      } else {
        deliveryScheduleData = <String, dynamic>{
          'type': 'immediate',
          'requested_datetime': DateTime.now().toIso8601String(),
        };
      }
    }

    final Map<String, dynamic> body = <String, dynamic>{
      'user_id': _isGuest
          ? 'guest_${DateTime.now().millisecondsSinceEpoch}'
          : (user! as Map<String, dynamic>)['user_id'].toString(),
      'outlet_id': cart.items.isNotEmpty
          ? cart.items.first['outlet_id']?.toString() ?? widget.order.vendorName
          : widget.order.vendorName,
      'items': widget.order.items
          .map((models.OrderItem i) => <String, dynamic>{
                'product_id': i.id,
                'quantity': i.quantity,
                'unit_price': i.price,
              })
          .toList(),
      'total_price': widget.order.totalPrice + _deliveryFee,
      'delivery_address': _addressCtrl.text,
      'delivery_latitude': _location?.latitude,
      'delivery_longitude': _location?.longitude,
      'customer_email': _isGuest
          ? '${_phoneCtrl.text}@guest.com'
          : (user! as Map<String, dynamic>)['email'],
      'customer_phone': _phoneCtrl.text,
      'is_guest': _isGuest,
      'delivery_type': _deliveryType,
      if (deliveryScheduleData != null)
        'delivery_schedule': deliveryScheduleData,
    };

    final http.Response res = await http
        .post(
          Uri.parse('$_baseUrl/orders/draft'),
          headers: await _headers(),
          body: json.encode(body),
        )
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () =>
              throw Exception('Request timed out — server may be waking up'),
        );

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Draft creation failed (${res.statusCode})');
    }
    final Map<String, dynamic> parsed =
        json.decode(res.body) as Map<String, dynamic>;
    final dynamic id = parsed['order_id'] ??
        (parsed['order'] as Map<String, dynamic>?)?['order_id'] ??
        (parsed['order'] as Map<String, dynamic>?)?['id'] ??
        parsed['id'];
    return id.toString();
  }

  Future<Map<String, dynamic>> _initiatePesapal(String orderId) async {
    final dynamic user = _isGuest ? null : await _auth.getCurrentUser();
    final http.Response res = await http
        .post(
          Uri.parse('$_baseUrl/payments/initiate'),
          headers: await _headers(),
          body: json.encode(<String, dynamic>{
            'order_id': orderId,
            'customer_email': _isGuest
                ? '${_phoneCtrl.text}@guest.com'
                : (user! as Map<String, dynamic>)['email'],
            'customer_phone': _phoneCtrl.text,
          }),
        )
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () =>
              throw Exception('Payment initiation timed out — try again'),
        );

    if (res.statusCode != 200) {
      final Map<String, dynamic> err =
          json.decode(res.body) as Map<String, dynamic>;
      throw Exception(err['error']?.toString() ??
          'Payment initiation failed (${res.statusCode})');
    }
    return json.decode(res.body) as Map<String, dynamic>;
  }

  Future<void> _confirmOrder(String orderId) async {
    await http.post(
      Uri.parse('$_baseUrl/orders/$orderId/confirm'),
      headers: await _headers(),
      body: json.encode(<String, dynamic>{}),
    );
    if (!mounted) return;
    _showSnack('Payment confirmed! 🎉', Colors.green.shade700);
    Navigator.pushReplacementNamed(
      context,
      '/orderConfirmation',
      arguments: widget.order.copyWith(id: orderId),
    );
  }

  Future<void> _cancelDraft(String orderId) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/orders/$orderId/cancel-draft'),
        headers: await _headers(),
        body: json.encode(<String, dynamic>{}),
      );
    } catch (_) {}
  }

  Future<Map<String, String>> _headers() async {
    final String? token = await _auth.getToken();
    return <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
    ));
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final double total = widget.order.totalPrice + _deliveryFee;
    return Scaffold(
      backgroundColor: _kSurface,
      appBar: AppBar(
        title: Text(
          _isGuest ? 'Guest Checkout' : 'Checkout',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 17,
            letterSpacing: -0.3,
          ),
        ),
        backgroundColor: _kGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: <Widget>[
          if (_isGuest) ...<Widget>[_guestBanner(), const SizedBox(height: 16)],

          // ── 1. Delivery Method ──────────────────────────────────
          _sectionHeader('Delivery Method', Icons.local_shipping_outlined),
          const SizedBox(height: 10),
          _deliveryToggle(),
          const SizedBox(height: 10),

          if (_isLoading)
            _locationLoadingCard()
          else if (_locationError.isNotEmpty)
            _locationErrorCard()
          else
            _locationInfoStrip(),

          if (!_isLoading && _location != null) ...<Widget>[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(height: 180, child: _buildMap()),
            ),
          ],

          if (!_isLoading && _location != null) ...<Widget>[
            const SizedBox(height: 10),
            _addressField(),
          ],

          // ── 2. Delivery Schedule (home only) ────────────────────
          if (_deliveryType == 'home') ...<Widget>[
            const SizedBox(height: 20),
            _sectionHeader('Delivery Schedule', Icons.schedule_outlined),
            const SizedBox(height: 10),
            _deliveryScheduleSection(),
          ],

          const SizedBox(height: 20),

          // ── 3. Contact ──────────────────────────────────────────
          _sectionHeader('Contact', Icons.phone_outlined),
          const SizedBox(height: 10),
          _phoneField(),
          const SizedBox(height: 20),

          // ── 4. Order Summary ────────────────────────────────────
          _sectionHeader('Order Summary', Icons.receipt_long_outlined),
          const SizedBox(height: 10),
          _orderSummaryCard(total),
          const SizedBox(height: 20),

          // ── 5. Payment Method ───────────────────────────────────
          _sectionHeader('Payment Method', Icons.payment_outlined),
          const SizedBox(height: 10),
          _paymentMethodRow(),
          const SizedBox(height: 6),
          _mpesaComingSoonNote(),
          const SizedBox(height: 20),

          // ── CTA ─────────────────────────────────────────────────
          _proceedButton(total),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  // ─── Section header ───────────────────────────────────────────────────────
  Widget _sectionHeader(String title, IconData icon) => Row(
        children: <Widget>[
          Icon(icon, size: 18, color: _kGreen),
          const SizedBox(width: 7),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Color(0xFF0F172A),
              letterSpacing: -0.2,
            ),
          ),
        ],
      );

  // ─── Guest banner ─────────────────────────────────────────────────────────
  Widget _guestBanner() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: Row(
          children: const <Widget>[
            Icon(Icons.info_outline, color: Color(0xFF3B82F6), size: 16),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Checking out as guest. Sign in after for full order tracking.',
                style: TextStyle(color: Color(0xFF1E40AF), fontSize: 12),
              ),
            ),
          ],
        ),
      );

  // ─── Delivery toggle ──────────────────────────────────────────────────────
  Widget _deliveryToggle() {
    final double deliveryFeeBase =
        (_pricingConfig['delivery_fee'] as num?)?.toDouble() ?? 150.0;
    final double pickupFeeGeneral =
        (_pricingConfig['pickup_fee_general'] as num?)?.toDouble() ?? 70.0;
    final String pickupSubtitle = _vendorType == 'general'
        ? 'KSh ${pickupFeeGeneral.toStringAsFixed(0)}'
        : 'Free';

    return Row(
      children: <Widget>[
        Expanded(
          child: _deliveryChip(
            label: 'Pickup',
            subtitle: pickupSubtitle,
            icon: Icons.store_outlined,
            type: 'pickup',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _deliveryChip(
            label: 'Home Delivery',
            subtitle: 'KSh ${deliveryFeeBase.toStringAsFixed(0)}',
            icon: Icons.delivery_dining_outlined,
            type: 'home',
          ),
        ),
      ],
    );
  }

  Widget _deliveryChip({
    required String label,
    required String subtitle,
    required IconData icon,
    required String type,
  }) {
    final bool selected = _deliveryType == type;
    return InkWell(
      onTap: () async {
        setState(() {
          _deliveryType = type;
          if (type == 'pickup') {
            _deliverySchedule = 'asap';
            _scheduledDate = null;
            _scheduledTime = null;
          }
        });
        await _initLocation();
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? _kGreenLight : Colors.white,
          border: Border.all(
            color: selected ? _kGreen : _kBorder,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon,
                size: 20, color: selected ? _kGreen : const Color(0xFF94A3B8)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: selected ? _kGreenDark : const Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: selected ? _kGreen : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, size: 15, color: _kGreen),
          ],
        ),
      ),
    );
  }

  // ─── Location cards ───────────────────────────────────────────────────────
  Widget _locationLoadingCard() => _infoCard(
        color: _kGreenLight,
        borderColor: const Color(0xFF6EE7B7),
        child: Row(
          children: <Widget>[
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: _kGreen),
            ),
            const SizedBox(width: 10),
            Text(
              _deliveryType == 'pickup'
                  ? 'Fetching outlet location…'
                  : 'Detecting your location…',
              style: const TextStyle(fontSize: 13, color: _kGreenDark),
            ),
          ],
        ),
      );

  Widget _locationErrorCard() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFCA5A5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.location_off,
                    color: Color(0xFFDC2626), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _locationError,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF7F1D1D), height: 1.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: _initLocation,
                  icon: const Icon(Icons.refresh, size: 13),
                  label: const Text('Retry', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    side: const BorderSide(color: Color(0xFFDC2626)),
                    foregroundColor: const Color(0xFFDC2626),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                if (_deliveryType == 'home') ...<Widget>[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Or type your address below.',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ),
                ],
              ],
            ),
            if (_deliveryType == 'home') ...<Widget>[
              const SizedBox(height: 8),
              _addressField(),
            ],
          ],
        ),
      );

  Widget _locationInfoStrip() => _infoCard(
        color: _kGreenLight,
        borderColor: const Color(0xFF6EE7B7),
        child: Row(
          children: <Widget>[
            const Icon(Icons.place, size: 15, color: _kGreen),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _address ?? 'Location set',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _kGreenDark),
              ),
            ),
            InkWell(
              onTap: _initLocation,
              child: const Icon(Icons.refresh, size: 15, color: _kGreen),
            ),
            if (_deliveryType == 'pickup') ...<Widget>[
              const SizedBox(width: 6),
              InkWell(
                onTap: _openDirections,
                child: const Icon(Icons.directions, size: 15, color: _kGreen),
              ),
            ],
          ],
        ),
      );

  Widget _infoCard({
    required Color color,
    required Color borderColor,
    required Widget child,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: child,
      );

  // ─── Map ──────────────────────────────────────────────────────────────────
  Widget _buildMap() => GoogleMap(
        initialCameraPosition: CameraPosition(target: _location!, zoom: 14.5),
        onTap: _deliveryType == 'home'
            ? (LatLng p) async {
                setState(() => _location = p);
                await _resolveAddress();
                if (mounted) {
                  _showSnack('Location updated ✓', Colors.green.shade700);
                }
              }
            : null,
        markers: <Marker>{
          Marker(
            markerId: const MarkerId('loc'),
            position: _location!,
            infoWindow: InfoWindow(
              title: _deliveryType == 'pickup'
                  ? 'Pickup Location'
                  : 'Delivery Location',
            ),
          ),
        },
        zoomControlsEnabled: false,
        myLocationButtonEnabled: _deliveryType == 'home',
        myLocationEnabled: _deliveryType == 'home',
      );

  // ─── Address field ────────────────────────────────────────────────────────
  Widget _addressField() => TextField(
        controller: _addressCtrl,
        decoration: InputDecoration(
          labelText:
              _deliveryType == 'pickup' ? 'Pickup Address' : 'Delivery Address',
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kGreen, width: 1.5),
          ),
          prefixIcon:
              const Icon(Icons.place_outlined, color: _kGreen, size: 18),
        ),
        onChanged: (String v) => _address = v,
      );

  // ─── Delivery schedule section (home only) ────────────────────────────────
  Widget _deliveryScheduleSection() {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _scheduleChip(
                value: 'asap',
                label: 'Deliver ASAP',
                subtitle: 'Est. 30–60 min',
                icon: Icons.bolt_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _scheduleChip(
                value: 'scheduled',
                label: 'Schedule',
                subtitle: 'Pick date & time',
                icon: Icons.calendar_today_outlined,
              ),
            ),
          ],
        ),
        if (_deliverySchedule == 'scheduled') ...<Widget>[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kBorder),
            ),
            child: Column(
              children: <Widget>[
                // Date picker row
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 11),
                    decoration: BoxDecoration(
                      color: _kSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _scheduledDate != null ? _kGreen : _kBorder,
                        width: _scheduledDate != null ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.calendar_month_outlined,
                          color: _scheduledDate != null
                              ? _kGreen
                              : const Color(0xFF94A3B8),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _scheduledDate == null
                                ? 'Select date'
                                : DateFormat('EEEE, d MMMM yyyy')
                                    .format(_scheduledDate!),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _scheduledDate != null
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: _scheduledDate != null
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: _scheduledDate != null
                              ? _kGreen
                              : const Color(0xFFCBD5E1),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Time picker row
                InkWell(
                  onTap: _pickTime,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 11),
                    decoration: BoxDecoration(
                      color: _kSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _scheduledTime != null ? _kGreen : _kBorder,
                        width: _scheduledTime != null ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.access_time_rounded,
                          color: _scheduledTime != null
                              ? _kGreen
                              : const Color(0xFF94A3B8),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _scheduledTime == null
                                ? 'Select time'
                                : _scheduledTime!.format(context),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _scheduledTime != null
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: _scheduledTime != null
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: _scheduledTime != null
                              ? _kGreen
                              : const Color(0xFFCBD5E1),
                        ),
                      ],
                    ),
                  ),
                ),
                // Confirmation pill once both are chosen
                if (_scheduledDate != null &&
                    _scheduledTime != null) ...<Widget>[
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _kGreenLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.check_circle,
                            color: _kGreen, size: 15),
                        const SizedBox(width: 6),
                        Text(
                          'Scheduled for '
                          '${DateFormat('d MMM').format(_scheduledDate!)} '
                          'at ${_scheduledTime!.format(context)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _kGreenDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _scheduleChip({
    required String value,
    required String label,
    required String subtitle,
    required IconData icon,
  }) {
    final bool selected = _deliverySchedule == value;
    return InkWell(
      onTap: () => setState(() {
        _deliverySchedule = value;
        if (value == 'asap') {
          _scheduledDate = null;
          _scheduledTime = null;
        }
      }),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? _kGreenLight : Colors.white,
          border: Border.all(
            color: selected ? _kGreen : _kBorder,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon,
                size: 20, color: selected ? _kGreen : const Color(0xFF94A3B8)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: selected ? _kGreenDark : const Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: selected ? _kGreen : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, size: 15, color: _kGreen),
          ],
        ),
      ),
    );
  }

  // ─── Phone field ──────────────────────────────────────────────────────────
  Widget _phoneField() => TextField(
        controller: _phoneCtrl,
        keyboardType: TextInputType.phone,
        decoration: InputDecoration(
          labelText: 'Phone Number *',
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kGreen, width: 1.5),
          ),
          prefixIcon:
              const Icon(Icons.phone_outlined, color: _kGreen, size: 18),
          hintText: '+2547XXXXXXXX or 07XXXXXXXX',
          hintStyle: const TextStyle(fontSize: 12),
        ),
      );

  // ─── Order summary card ───────────────────────────────────────────────────
  Widget _orderSummaryCard(double total) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorder),
        ),
        child: Column(
          children: <Widget>[
            ...widget.order.items.map((models.OrderItem item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '${item.name} × ${item.quantity}',
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _currency.format(item.price * item.quantity),
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                )),
            const Divider(height: 16),
            _summaryRow('Subtotal', _currency.format(widget.order.totalPrice)),
            const SizedBox(height: 4),
            _summaryRow(
              _deliveryType == 'pickup' ? 'Pickup' : 'Delivery',
              _deliveryFee == 0 ? 'FREE' : _currency.format(_deliveryFee),
              valueColor: _deliveryFee == 0 ? Colors.green.shade700 : null,
            ),
            if (_deliveryType == 'home' &&
                _deliverySchedule == 'scheduled' &&
                _scheduledDate != null &&
                _scheduledTime != null) ...<Widget>[
              const SizedBox(height: 4),
              _summaryRow(
                'Scheduled',
                '${DateFormat('d MMM').format(_scheduledDate!)} · ${_scheduledTime!.format(context)}',
                valueColor: _kGreenDark,
              ),
            ],
            const Divider(height: 16),
            _summaryRow('Total', _currency.format(total),
                bold: true, valueColor: _kGreen),
          ],
        ),
      );

  Widget _summaryRow(
    String label,
    String value, {
    bool bold = false,
    Color? valueColor,
  }) =>
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
              color: const Color(0xFF64748B),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              fontSize: bold ? 15 : 13,
              color: valueColor ?? const Color(0xFF0F172A),
            ),
          ),
        ],
      );

  // ─── Payment method row ───────────────────────────────────────────────────
  Widget _paymentMethodRow() => Row(
        children: <Widget>[
          Expanded(
            child: _paymentChip(
              method: 'mpesa',
              label: 'M-Pesa',
              icon: Icons.phone_android,
              iconColor: const Color(0xFF00A651),
              badge: 'Soon',
              enabled: false,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _paymentChip(
              method: 'pesapal',
              label: 'Pesapal',
              sublabel: 'Card · M-Pesa · more',
              icon: Icons.credit_card_outlined,
              iconColor: _kBlue,
              enabled: true,
            ),
          ),
        ],
      );

  Widget _paymentChip({
    required String method,
    required String label,
    required IconData icon,
    required Color iconColor,
    String? sublabel,
    String? badge,
    required bool enabled,
  }) {
    final bool selected = _paymentMethod == method;
    return InkWell(
      onTap: enabled
          ? () => setState(() => _paymentMethod = method)
          : () => _showSnack('$label coming soon!', Colors.orange.shade700),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: !enabled
              ? const Color(0xFFF8FAFC)
              : selected
                  ? const Color(0xFFEFF6FF)
                  : Colors.white,
          border: Border.all(
            color: !enabled
                ? _kBorder
                : selected
                    ? _kBlue
                    : _kBorder,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              icon,
              size: 20,
              color: !enabled
                  ? const Color(0xFFCBD5E1)
                  : selected
                      ? iconColor
                      : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: !enabled
                              ? const Color(0xFFCBD5E1)
                              : selected
                                  ? const Color(0xFF1D4ED8)
                                  : const Color(0xFF64748B),
                        ),
                      ),
                      if (badge != null) ...<Widget>[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade600,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (sublabel != null)
                    Text(
                      sublabel,
                      style: TextStyle(
                        fontSize: 10,
                        color: selected ? _kBlue : const Color(0xFF94A3B8),
                      ),
                    ),
                ],
              ),
            ),
            if (selected && enabled)
              const Icon(Icons.check_circle, size: 15, color: _kBlue),
          ],
        ),
      ),
    );
  }

  Widget _mpesaComingSoonNote() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: Row(
          children: const <Widget>[
            Icon(Icons.info_outline, size: 13, color: Color(0xFF3B82F6)),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'M-Pesa direct integration coming soon. '
                'Pay via M-Pesa through Pesapal for now.',
                style: TextStyle(fontSize: 11, color: Color(0xFF1E40AF)),
              ),
            ),
          ],
        ),
      );

  // ─── Proceed button ───────────────────────────────────────────────────────
  Widget _proceedButton(double total) {
    final bool ready = _paymentMethod == 'pesapal' && _isScheduleComplete;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: ready ? _kBlue : const Color(0xFFE2E8F0),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          elevation: ready ? 3 : 0,
        ),
        onPressed: _isPaying ? null : _startPayment,
        child: _isPaying
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Icon(Icons.lock_outline, size: 15, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    ready
                        ? 'Pay ${_currency.format(total)} via Pesapal'
                        : _paymentMethod != 'pesapal'
                            ? 'Select a payment method'
                            : 'Select delivery date & time',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: ready ? Colors.white : const Color(0xFF94A3B8),
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}