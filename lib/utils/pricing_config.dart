// lib/utils/pricing_config.dart
//
// Single source of truth for the *client-side preview* of pricing.
//
// Mirrors:
//   - backend/utils/pricing.js        (calculateOrderPricing — authoritative)
//   - smartgaske web/src/lib/utils/pricing.ts (calculateCartPricing)
//
// The backend always re-derives tax/delivery/total server-side when an
// order is created and ignores whatever the client sends, so this file is
// only used to show an accurate *preview* before checkout. Values are
// fetched live from GET /api/v1/config/pricing so this never drifts from
// the backend the way a hardcoded copy would.
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class PricingConfig {
  final double taxRate;
  final double deliveryFee;
  final double freeDeliveryThreshold;
  final double pickupFeeGeneral;

  const PricingConfig({
    required this.taxRate,
    required this.deliveryFee,
    required this.freeDeliveryThreshold,
    required this.pickupFeeGeneral,
  });

  factory PricingConfig.fromJson(Map<String, dynamic> json) {
    double asDouble(dynamic v, double fallback) =>
        (v is num) ? v.toDouble() : fallback;
    return PricingConfig(
      taxRate: asDouble(json['tax_rate'], fallback.taxRate),
      deliveryFee: asDouble(json['delivery_fee'], fallback.deliveryFee),
      freeDeliveryThreshold: asDouble(
          json['free_delivery_threshold'], fallback.freeDeliveryThreshold),
      pickupFeeGeneral:
          asDouble(json['pickup_fee_general'], fallback.pickupFeeGeneral),
    );
  }

  // Last-resort fallback ONLY if /config/pricing can't be reached (e.g. the
  // device is offline). Kept in sync with the backend's current defaults,
  // but the live fetch is always authoritative — never trust this as the
  // final charged amount.
  static const PricingConfig fallback = PricingConfig(
    taxRate: 0.06,
    deliveryFee: 150,
    freeDeliveryThreshold: 7000,
    pickupFeeGeneral: 70,
  );
}

class CartPricing {
  final double subtotal;
  final double tax;
  final double deliveryFee;
  final double total;
  final bool isEstimate;

  const CartPricing({
    required this.subtotal,
    required this.tax,
    required this.deliveryFee,
    required this.total,
    required this.isEstimate,
  });
}

class PricingService {
  PricingService._();
  static const String baseUrl = 'https://aquagas-backend.onrender.com/api/v1';

  static PricingConfig? _cached;
  static Future<PricingConfig>? _inFlight;

  /// Fetches (and caches for the app session) the live pricing constants
  /// from the backend. Call this once near the top of the cart/checkout
  /// screens and pass the result into [calculateCartPricing] — don't
  /// hardcode these values locally.
  static Future<PricingConfig> fetchConfig() {
    if (_cached != null) return Future.value(_cached);
    if (_inFlight != null) return _inFlight!;

    final Future<PricingConfig> pending = http
        .get(Uri.parse('$baseUrl/config/pricing'))
        .timeout(const Duration(seconds: 10))
        .then((http.Response res) {
      if (res.statusCode == 200) {
        final PricingConfig cfg = PricingConfig.fromJson(
            jsonDecode(res.body) as Map<String, dynamic>);
        _cached = cfg;
        return cfg;
      }
      return PricingConfig.fallback;
    }).catchError((Object err) {
      debugPrint('Failed to fetch live pricing config, using fallback: $err');
      return PricingConfig.fallback;
    }).whenComplete(() {
      _inFlight = null;
    });

    _inFlight = pending;
    return pending;
  }
}

/// Mirrors the backend's calculateOrderPricing() (utils/pricing.js) exactly:
/// - Gas vendor pickup: free
/// - General vendor pickup: flat pickup_fee_general
/// - Home delivery: free above free_delivery_threshold, else delivery_fee
///
/// The backend recomputes this independently at order-creation time and is
/// always authoritative — this is only for showing an accurate preview.
CartPricing calculateCartPricing(
  double subtotal, {
  PricingConfig config = PricingConfig.fallback,
  bool isPickup = false,
  // 'gas' | 'general' — vendor.vendor_type of the vendor this order is
  // being placed with. Defaults to 'gas' (free pickup) which matches the
  // backend's own default when vendor_type can't be resolved.
  String vendorType = 'gas',
  bool isEstimate = false,
}) {
  final double tax = (subtotal * config.taxRate).roundToDouble();

  double deliveryFee;
  if (isPickup) {
    deliveryFee = vendorType == 'general' ? config.pickupFeeGeneral : 0.0;
  } else {
    deliveryFee =
        subtotal >= config.freeDeliveryThreshold ? 0.0 : config.deliveryFee;
  }

  final double total = subtotal + tax + deliveryFee;

  return CartPricing(
    subtotal: subtotal,
    tax: tax,
    deliveryFee: deliveryFee,
    total: total,
    isEstimate: isEstimate,
  );
}