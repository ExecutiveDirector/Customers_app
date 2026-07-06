// lib/screens/track_order_screen.dart
//
// Unified live-tracking screen for the AquaGas delivery app.
// • Fetches order via OrderService.getOrderById() with user auth token
// • Polls status every 5 s via OrderService.trackOrderStatus() stream
// • Google Maps with destination marker
// • Shows rider name, phone + tap-to-call button when rider is assigned
// • Pure AquaGas green palette (0xFF10B981 / 0xFF064E3B)
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:aquagas/app.dart';
import 'package:aquagas/services/auth_service.dart';
import 'package:aquagas/services/order_service.dart';
import 'package:aquagas/widgets/drawer.dart';

// ─── Palette ─────────────────────────────────────────────────────────────────
const Color _kGreen500 = Color(0xFF10B981);
const Color _kGreen900 = Color(0xFF064E3B);
const Color _kGreen100 = Color(0xFFD1FAE5);
const Color _kSlate800 = Color(0xFF1E293B);
const Color _kSlate500 = Color(0xFF64748B);
const Color _kSlate100 = Color(0xFFF1F5F9);

// ─────────────────────────────────────────────────────────────────────────────
//  TrackOrderScreen
// ─────────────────────────────────────────────────────────────────────────────
class TrackOrderScreen extends StatefulWidget {
  final String orderId;
  const TrackOrderScreen({super.key, required this.orderId});

  @override
  State<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends State<TrackOrderScreen> {
  final OrderService _orderService = OrderService();
  final AuthService _authService = AuthService();

  // Map
  final Completer<GoogleMapController> _mapCompleter =
      Completer<GoogleMapController>();
  GoogleMapController? _mapController;

  // State
  Map<String, dynamic>? _rawOrder;
  bool _isLoading = true;
  String? _errorMessage;

  // Only true once we've actually confirmed the OS granted location
  // permission. GoogleMap's myLocationEnabled throws a PlatformException
  // ("...requires location permission...") if set to true without a
  // granted permission — which is what was blocking this screen from
  // opening at all. Defaulting to false and flipping it on only after a
  // real grant means the map (and the destination pin, which is the part
  // that actually matters here) always renders regardless of whether the
  // customer has granted location access.
  bool _myLocationEnabled = false;

  // Polling stream
  StreamSubscription<Map<String, dynamic>>? _pollSub;

  // Default centre: Nairobi CBD
  static const LatLng _kNairobi = LatLng(-1.2921, 36.8219);

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _pollSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<void> _boot() async {
    final String? token = await _authService.getToken();
    if (token == null && mounted) {
      Navigator.pushNamedAndRemoveUntil(
          context, Routes.signIn, (Route<dynamic> r) => false);
      return;
    }

    // Deliberately not awaited: the destination pin doesn't need this, so
    // permission (or the lack of it) should never delay/block the order
    // fetch or the map from showing.
    _ensureLocationPermission();

    await _fetchOrder();
    _startPolling();
  }

  Future<void> _ensureLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      final bool granted = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      if (mounted) setState(() => _myLocationEnabled = granted);
    } catch (_) {
      // If the platform call itself fails for any reason, just keep
      // myLocationEnabled off rather than risk the exception this was
      // written to avoid in the first place.
    }
  }

  Future<void> _fetchOrder() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final Map<String, dynamic> order =
          await _orderService.getOrderById(widget.orderId);
      if (mounted)
        setState(() {
          _rawOrder = order;
          _isLoading = false;
        });
      _animateToDelivery(order);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _startPolling() {
    _pollSub =
        _orderService.trackOrderStatus(widget.orderId, interval: 5).listen(
      (Map<String, dynamic> order) {
        if (mounted) setState(() => _rawOrder = order);
      },
      onError: (Object error) {
        // Silent — we already have the first fetch.
      },
    );
  }

  void _animateToDelivery(Map<String, dynamic> order) {
    // Backend normalizeOrder now sends delivery_lat / delivery_lng.
    // Fall back to delivery_latitude / delivery_longitude for raw shapes.
    final double? lat =
        _parseDouble(order['delivery_lat'] ?? order['delivery_latitude']);
    final double? lng =
        _parseDouble(order['delivery_lng'] ?? order['delivery_longitude']);
    if (lat != null && lng != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(LatLng(lat, lng)),
      );
    }
  }

  // ── Computed helpers ──────────────────────────────────────────────────────

  LatLng get _mapTarget {
    if (_rawOrder != null) {
      final double? lat = _parseDouble(
          _rawOrder!['delivery_lat'] ?? _rawOrder!['delivery_latitude']);
      final double? lng = _parseDouble(
          _rawOrder!['delivery_lng'] ?? _rawOrder!['delivery_longitude']);
      if (lat != null && lng != null) return LatLng(lat, lng);
    }
    return _kNairobi;
  }

  Set<Marker> get _markers {
    final Set<Marker> m = <Marker>{};
    if (_rawOrder == null) return m;

    final double? lat = _parseDouble(
        _rawOrder!['delivery_lat'] ?? _rawOrder!['delivery_latitude']);
    final double? lng = _parseDouble(
        _rawOrder!['delivery_lng'] ?? _rawOrder!['delivery_longitude']);

    if (lat != null && lng != null) {
      m.add(Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(lat, lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: _rawOrder!['delivery_address']?.toString() ?? 'Delivery point',
        ),
      ));
    }
    return m;
  }

  String get _statusLabel {
    final String raw =
        (_rawOrder?['order_status'] ?? _rawOrder?['status'] ?? 'pending')
            .toString();
    return raw[0].toUpperCase() + raw.substring(1).replaceAll('_', ' ');
  }

  Color get _statusColor {
    final String s = (_rawOrder?['order_status'] ?? _rawOrder?['status'] ?? '')
        .toString()
        .toLowerCase();
    switch (s) {
      case 'delivered':
        return const Color(0xFF059669);
      case 'dispatched':
      case 'out_for_delivery':
      case 'in_transit':
        return _kGreen500;
      case 'preparing':
      case 'confirmed':
      case 'processing':
        return const Color(0xFF0EA5E9);
      case 'canceled':
      case 'cancelled':
        return const Color(0xFFEF4444);
      default:
        return _kSlate500;
    }
  }

  /// Extract rider info from order response.
  /// Backend normalizeOrder wraps it under `rider: { name, phone, vehicle_type }`.
  Map<String, String?>? get _rider {
    final dynamic r = _rawOrder?['rider'];
    if (r == null || r is! Map) return null;
    final String? name = r['name']?.toString();
    final String? phone = r['phone']?.toString();
    if (name == null && phone == null) return null;
    return {
      'name': name,
      'phone': phone,
      'vehicle_type': r['vehicle_type']?.toString(),
    };
  }

  static double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString());
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      drawer: const AppDrawer(),
      appBar: _buildAppBar(context),
      body: _isLoading
          ? _buildLoader()
          : _errorMessage != null
              ? _buildError()
              : _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10), blurRadius: 8),
            ],
          ),
          child: const Icon(Icons.arrow_back, color: _kSlate800),
        ),
      ),
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: <BoxShadow>[
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.10), blurRadius: 8),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                  color: _kGreen500, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            const Text(
              'Live Tracking',
              style: TextStyle(
                color: _kSlate800,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildLoader() {
    return const Center(
      child: CircularProgressIndicator(color: _kGreen500),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, color: _kGreen500, size: 56),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _kSlate800, fontSize: 15),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGreen500,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Stack(
      children: <Widget>[
        // ── Google Map ────────────────────────────────────────────────────
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _mapTarget,
            zoom: 15,
          ),
          onMapCreated: (GoogleMapController c) {
            if (!_mapCompleter.isCompleted) _mapCompleter.complete(c);
            _mapController = c;
            if (_rawOrder != null) _animateToDelivery(_rawOrder!);
          },
          markers: _markers,
          myLocationEnabled: _myLocationEnabled,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
        ),

        // ── Bottom info panel ─────────────────────────────────────────────
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _InfoPanel(
            order: _rawOrder!,
            statusLabel: _statusLabel,
            statusColor: _statusColor,
            rider: _rider,
            onHome: () => Navigator.pushNamedAndRemoveUntil(
                context, Routes.home, (Route<dynamic> r) => false),
          ),
        ),

        // ── Recenter FAB ──────────────────────────────────────────────────
        Positioned(
          right: 16,
          bottom: 320,
          child: FloatingActionButton.small(
            onPressed: () => _mapController
                ?.animateCamera(CameraUpdate.newLatLng(_mapTarget)),
            backgroundColor: Colors.white,
            child: const Icon(Icons.my_location, color: _kGreen500),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Info panel
// ─────────────────────────────────────────────────────────────────────────────
class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.order,
    required this.statusLabel,
    required this.statusColor,
    required this.rider,
    required this.onHome,
  });

  final Map<String, dynamic> order;
  final String statusLabel;
  final Color statusColor;
  final Map<String, String?>? rider;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final NumberFormat currencyFmt = NumberFormat.currency(
        locale: 'en_KE', symbol: 'KES ', decimalDigits: 0);
    final DateFormat dateFmt = DateFormat('MMM dd, yyyy • HH:mm');

    final String orderNumber =
        order['order_number']?.toString() ?? order['id']?.toString() ?? '—';
    final String vendorName = order['vendor_name']?.toString() ?? '—';
    final String address = order['delivery_address']?.toString() ?? '—';
    final double total = _parseDouble(order['total_amount'] ??
            order['grand_total'] ??
            order['total_price']) ??
        0;
    final String dateRaw =
        order['created_at']?.toString() ?? order['timestamp']?.toString() ?? '';
    final String dateLabel = dateRaw.isNotEmpty
        ? dateFmt.format(DateTime.tryParse(dateRaw) ?? DateTime.now())
        : '—';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: <BoxShadow>[
          BoxShadow(
              color: Colors.black12, blurRadius: 20, offset: Offset(0, -4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Order header ─────────────────────────────────────────────────
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _kGreen100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.local_fire_department_outlined,
                    color: _kGreen900, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      vendorName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: _kSlate800,
                      ),
                    ),
                    Text(
                      address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _kSlate500, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Text(
                currencyFmt.format(total),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: _kGreen900,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          // ── Detail rows ──────────────────────────────────────────────────
          _Row(
              icon: Icons.receipt_long_rounded,
              label: 'Order',
              value: '#$orderNumber'),
          _Row(
              icon: Icons.calendar_today_rounded,
              label: 'Date',
              value: dateLabel),
          _Row(
              icon: Icons.circle_rounded,
              label: 'Status',
              value: statusLabel,
              valueColor: statusColor),

          // ── Rider card (shown only when rider is assigned) ───────────────
          if (rider != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 12),
            _RiderCard(rider: rider!),
          ],

          const SizedBox(height: 16),

          // ── Back to home ─────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onHome,
              icon: const Icon(Icons.home_rounded, size: 18),
              label: const Text('Back to Home',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGreen500,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString());
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Rider contact card
// ─────────────────────────────────────────────────────────────────────────────
class _RiderCard extends StatelessWidget {
  const _RiderCard({required this.rider});

  final Map<String, String?> rider;

  Future<void> _callRider(String phone) async {
    final Uri uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String name = rider['name'] ?? 'Your Rider';
    final String? phone = rider['phone'];
    final String? vehicleType = rider['vehicle_type'];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kGreen100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          // Avatar
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: _kGreen500,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.delivery_dining_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),

          // Name + vehicle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Your Rider',
                  style: TextStyle(
                      fontSize: 11,
                      color: _kSlate500,
                      fontWeight: FontWeight.w500),
                ),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _kSlate800,
                  ),
                ),
                if (vehicleType != null)
                  Text(
                    vehicleType,
                    style: const TextStyle(fontSize: 12, color: _kSlate500),
                  ),
              ],
            ),
          ),

          // Call button — only shown if phone number is available
          if (phone != null && phone.isNotEmpty)
            GestureDetector(
              onTap: () => _callRider(phone),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: _kGreen500,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.phone_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Generic detail row
// ─────────────────────────────────────────────────────────────────────────────
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor = _kSlate800,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 15, color: _kSlate500),
          const SizedBox(width: 8),
          Text('$label: ',
              style: const TextStyle(fontSize: 13, color: _kSlate500)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
