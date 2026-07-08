// lib/cart.dart - COMPLETE FIXED VERSION
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:aquagas/app_order.dart' as models;
import 'package:aquagas/services/auth_service.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// ✅ Custom Exceptions
class CartException implements Exception {
  final String message;
  CartException(this.message);

  @override
  String toString() => 'CartException: $message';
}

class CartEmptyException extends CartException {
  CartEmptyException() : super('Your cart is empty');
}

class InvalidCartItemException extends CartException {
  InvalidCartItemException(String item) : super('Invalid cart item: $item');
}

class Cart extends ChangeNotifier {
  static const String _baseUrl = 'https://aquagas-backend.onrender.com/api';
  final AuthService _authService = AuthService();

  final List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];

  // Getters
  List<Map<String, dynamic>> get items => List.unmodifiable(_items);
  int get itemCount => _items.length;
  int get totalQuantity => _items.fold<int>(
        0,
        (int sum, Map<String, dynamic> item) => sum + (item['quantity'] as int),
      );

  double get totalAmount {
    return _items.fold(
      0.0,
      (double sum, Map<String, dynamic> item) {
        final double price = (item['price'] as num).toDouble();
        final int qty = item['quantity'] as int;
        return sum + price * qty;
      },
    );
  }

  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;
  Map<String, dynamic> get first => _items.first;

  /// ✅ FIXED: Add item with complete vendor/outlet data
  void addItem(Map<String, dynamic> rawItem) {
    try {
      final item = _normalizeCartItem(rawItem);
      final String productId = item['product_id'] as String;

      final int index = _items.indexWhere(
        (element) => element['product_id'] == productId,
      );

      if (index != -1) {
        _items[index]['quantity'] = (_items[index]['quantity'] as int) + 1;
      } else {
        _items.add(item);
      }

      debugPrint(
          '✅ Added to cart: ${item['title']} from ${item['outletName']} (Vendor ID: ${item['vendor_id']})');
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding item to cart: $e');
      rethrow;
    }
  }

  /// ✅ FIXED: Normalize cart item with proper vendor_id extraction
  Map<String, dynamic> _normalizeCartItem(Map<String, dynamic> item) {
    final String productId = item['product_id']?.toString() ??
        item['id']?.toString() ??
        const Uuid().v4();

    final dynamic outletIdValue = item['outlet_id'];
    final int outletId = outletIdValue is int
        ? outletIdValue
        : int.tryParse(outletIdValue?.toString() ?? '') ?? 0;

    // ✅ FIX: Better vendor_id extraction with fallback chain
    final dynamic vendorIdValue = item['vendor_id'] ?? item['vendorId'];
    int vendorId = 0;

    if (vendorIdValue != null) {
      if (vendorIdValue is int) {
        vendorId = vendorIdValue;
      } else if (vendorIdValue is String) {
        vendorId = int.tryParse(vendorIdValue) ?? 0;
      }
    }

    // ✅ If still 0, try to extract from outlet object
    if (vendorId == 0 && item['outlet'] != null) {
      final dynamic outletVendorId =
          item['outlet']['vendor_id'] ?? item['outlet']['vendorId'];
      if (outletVendorId != null) {
        if (outletVendorId is int) {
          vendorId = outletVendorId;
        } else if (outletVendorId is String) {
          vendorId = int.tryParse(outletVendorId) ?? 0;
        }
      }
    }

    final String outletName = item['outlet_name']?.toString() ??
        item['outletName']?.toString() ??
        item['outlet']?['name']?.toString() ??
        'Unknown Outlet';

    final String vendorName = item['vendor_name']?.toString() ??
        item['vendorName']?.toString() ??
        item['outlet']?['vendor_name']?.toString() ??
        item['outlet']?['vendorName']?.toString() ??
        'Unknown Vendor';

    final double? outletLat = item['outlet_latitude'] != null
        ? (item['outlet_latitude'] as num).toDouble()
        : null;

    final double? outletLng = item['outlet_longitude'] != null
        ? (item['outlet_longitude'] as num).toDouble()
        : null;

    final double? distance =
        item['distance'] != null ? (item['distance'] as num).toDouble() : null;

    debugPrint('🔍 Normalizing item: ${item['title']}');
    debugPrint('   Outlet ID: $outletId');
    debugPrint('   Vendor ID: $vendorId');
    debugPrint('   Vendor Name: $vendorName');

    return <String, dynamic>{
      'id': productId,
      'product_id': productId,
      'product_code': item['product_code']?.toString() ?? '',
      'outlet_id': outletId,
      'outletId': outletId,
      'outlet_name': outletName,
      'outletName': outletName,
      'vendor_id': vendorId,
      'vendorId': vendorId,
      'vendor_name': vendorName,
      'vendorName': vendorName,
      'outlet_latitude': outletLat,
      'outlet_longitude': outletLng,
      'distance': distance,
      'title':
          item['title']?.toString() ?? item['product_name']?.toString() ?? '',
      'price': (item['price'] is num)
          ? (item['price'] as num).toDouble()
          : double.tryParse(item['price']?.toString() ?? '') ?? 0.0,
      'quantity': (item['quantity'] is int)
          ? item['quantity']
          : int.tryParse(item['quantity']?.toString() ?? '') ?? 1,
      'image':
          item['image']?.toString() ?? item['product_images']?.toString() ?? '',
      'description': item['description']?.toString() ?? '',
      'brand': item['brand']?.toString() ?? '',
      'size_specification': item['size_specification']?.toString() ??
          item['sizeSpecification']?.toString() ??
          '',
      'stock': item['stock'] ?? 0,
      'category_id': item['category_id'] ?? 0,
    };
  }

  void removeItem(Map<String, dynamic> item) {
    try {
      final String productId = item['product_id']?.toString() ?? '';
      if (productId.isEmpty) {
        throw Exception('Item must have product_id');
      }

      final int index = _items.indexWhere(
        (element) => element['product_id'] == productId,
      );

      if (index != -1) {
        final int currentQuantity = _items[index]['quantity'] as int;
        if (currentQuantity > 1) {
          _items[index]['quantity'] = currentQuantity - 1;
        } else {
          _items.removeAt(index);
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error removing item from cart: $e');
      rethrow;
    }
  }

  void deleteItem(String productId) {
    try {
      _items.removeWhere((element) => element['product_id'] == productId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting item from cart: $e');
      rethrow;
    }
  }

  bool containsItem(String productId) {
    return _items.any((element) => element['product_id'] == productId);
  }

  int getItemQuantity(String productId) {
    final int index = _items.indexWhere(
      (element) => element['product_id'] == productId,
    );
    return index != -1 ? _items[index]['quantity'] as int : 0;
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  bool validateCart() {
    if (_items.isEmpty) {
      debugPrint('Cart validation failed: Empty cart');
      return false;
    }

    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];

      final String? productId = item['product_id']?.toString();
      if (productId == null || productId.isEmpty) {
        debugPrint('Cart validation failed: Item #${i + 1} missing product_id');
        return false;
      }

      if (item['title'] == null || item['title'].toString().isEmpty) {
        debugPrint('Cart validation failed: Item #${i + 1} missing title');
        return false;
      }

      final dynamic price = item['price'];
      if (price == null || (price is num && price <= 0)) {
        debugPrint(
            'Cart validation failed: Invalid price for "${item['title']}"');
        return false;
      }

      final dynamic quantity = item['quantity'];
      if (quantity == null || (quantity is int && quantity <= 0)) {
        debugPrint(
            'Cart validation failed: Invalid quantity for "${item['title']}"');
        return false;
      }

      final dynamic outletId = item['outlet_id'];
      if (outletId == null || (outletId is int && outletId <= 0)) {
        debugPrint(
            'Cart validation failed: Missing outlet_id for "${item['title']}"');
        return false;
      }

      final dynamic vendorId = item['vendor_id'];
      if (vendorId == null || (vendorId is int && vendorId <= 0)) {
        debugPrint(
            '⚠️ Warning: Missing vendor_id for "${item['title']}" - attempting to continue');
      }
    }

    final int firstOutletId = _items[0]['outlet_id'] as int;
    final bool sameOutlet =
        _items.every((item) => item['outlet_id'] == firstOutletId);

    if (!sameOutlet) {
      debugPrint('Cart validation failed: Items from multiple outlets');
      return false;
    }

    debugPrint('✅ Cart validation passed');
    return true;
  }

  Future<models.AppOrder> createOrder({
    LatLng? deliveryLocation,
    String? deliveryAddress,
    String? phoneNumber,
    String? notes,
  }) async {
    try {
      if (_items.isEmpty) {
        throw CartEmptyException();
      }

      if (!validateCart()) {
        throw InvalidCartItemException('Cart contains invalid items');
      }

      final firstItem = _items[0];
      final int outletId = firstItem['outlet_id'] as int;
      final int vendorId = firstItem['vendor_id'] as int;
      final String vendorName = firstItem['vendor_name'] as String;

      final String orderId = const Uuid().v4();
      final DateTime now = DateTime.now();

      final bool isAuth = await _authService.isAuthenticated();

      if (isAuth) {
        final String? token = await _authService.getToken();
        if (token == null) {
          throw AuthException('Authentication token not found');
        }

        final Map<String, dynamic>? userData =
            await _authService.getCurrentUser();
        if (userData == null) {
          throw AuthException('User data not found');
        }

        final dynamic idValue = userData['id'];
        final int customerId = (idValue is int)
            ? idValue
            : int.tryParse(idValue?.toString() ?? '') ?? 0;

        if (customerId <= 0) {
          throw AuthException('Invalid customer ID');
        }

        return await _createAuthenticatedOrder(
          customerId: customerId,
          outletId: outletId,
          vendorId: vendorId,
          vendorName: vendorName,
          orderId: orderId,
          now: now,
          deliveryLocation: deliveryLocation,
          deliveryAddress: deliveryAddress,
          phoneNumber: phoneNumber,
          notes: notes,
          token: token,
        );
      } else {
        return _createGuestOrder(
          outletId: outletId,
          vendorId: vendorId,
          vendorName: vendorName,
          orderId: orderId,
          now: now,
          deliveryLocation: deliveryLocation,
          deliveryAddress: deliveryAddress,
          phoneNumber: phoneNumber,
          notes: notes,
        );
      }
    } catch (e) {
      debugPrint('Error creating order: $e');
      rethrow;
    }
  }

  Future<models.AppOrder> _createAuthenticatedOrder({
    required int customerId,
    required int outletId,
    required int vendorId,
    required String vendorName,
    required String orderId,
    required DateTime now,
    required String token,
    LatLng? deliveryLocation,
    String? deliveryAddress,
    String? phoneNumber,
    String? notes,
  }) async {
    try {
      final double subtotal = totalAmount;
      final double taxAmount = calculateTax();
      final double deliveryFee = 0.0;
      final double discountAmount = 0.0;
      final double totalAmountWithTax =
          subtotal + taxAmount + deliveryFee - discountAmount;

      final List<Map<String, dynamic>> formattedItems = _items.map((item) {
        final double unitPrice = (item['price'] as num).toDouble();
        final int quantity = item['quantity'] as int;
        final double itemTotalPrice = unitPrice * quantity;

        return <String, dynamic>{
          'product_id': item['product_id'],
          'product_name': item['title'],
          'quantity': quantity,
          'unit_price': unitPrice,
          'total_price': itemTotalPrice,
        };
      }).toList();

      final Map<String, dynamic> orderPayload = <String, dynamic>{
        'customer_id': customerId,
        'outlet_id': outletId,
        'vendor_id': vendorId,
        'vendor_name': vendorName,
        'subtotal': subtotal,
        'tax_amount': taxAmount,
        'delivery_fee': deliveryFee,
        'discount_amount': discountAmount,
        'total_amount': totalAmountWithTax,
        'total_price': totalAmountWithTax,
        'order_status': 'pending',
        'payment_status': 'pending',
        'delivery_type': 'home_delivery',
        'items': formattedItems,
      };

      if (deliveryLocation != null) {
        orderPayload['delivery_latitude'] = deliveryLocation.latitude;
        orderPayload['delivery_longitude'] = deliveryLocation.longitude;
      }

      if (deliveryAddress != null && deliveryAddress.isNotEmpty) {
        orderPayload['delivery_address'] = deliveryAddress;
      }
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        orderPayload['delivery_contact'] = phoneNumber;
      }
      if (notes != null && notes.isNotEmpty) {
        orderPayload['customer_note'] = notes;
      }

      debugPrint('📤 Creating order: ${jsonEncode(orderPayload)}');

      final http.Response response = await http
          .post(
            Uri.parse('$_baseUrl/orders'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(orderPayload),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw CartException('Request timed out'),
          );

      debugPrint('📥 Response status: ${response.statusCode}');
      debugPrint('📥 Response body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final Map<String, dynamic> responseData =
            jsonDecode(response.body) as Map<String, dynamic>;

        final Map<String, dynamic>? orderData =
            responseData['order'] as Map<String, dynamic>?;

        final String backendOrderId = orderData?['order_id']?.toString() ??
            orderData?['order_number']?.toString() ??
            responseData['order_id']?.toString() ??
            orderId;

        final String orderStatus =
            orderData?['order_status']?.toString() ?? 'pending';

        debugPrint('✅ Order created: $backendOrderId (Status: $orderStatus)');

        final List<models.OrderItem> orderItems = _items
            .map((item) => models.OrderItem(
                  id: item['product_id']?.toString() ?? '',
                  name: item['title'] as String,
                  price: (item['price'] as num).toDouble(),
                  quantity: item['quantity'] as int,
                ))
            .toList();

        final models.AppOrder order = models.AppOrder(
          id: backendOrderId,
          userId: customerId.toString(),
          vendorName: vendorName,
          status: orderStatus,
          timestamp: now,
          items: orderItems,
          totalPrice: totalAmountWithTax,
          quantity: totalQuantity,
          deliveryLocation: deliveryLocation,
          outletId: outletId.toString(),
        );

        clear();
        return order;
      } else {
        String errorMessage = 'Failed to create order';

        try {
          final Map<String, dynamic> error =
              jsonDecode(response.body) as Map<String, dynamic>;
          errorMessage = error['error']?.toString() ??
              error['message']?.toString() ??
              errorMessage;
        } catch (e) {
          debugPrint('Failed to parse error response: $e');
        }

        debugPrint('❌ Order failed: $errorMessage (${response.statusCode})');
        throw CartException(errorMessage);
      }
    } on SocketException {
      throw CartException('No internet connection');
    } on FormatException catch (e) {
      debugPrint('❌ Invalid response format: $e');
      throw CartException('Invalid server response');
    } catch (e) {
      debugPrint('❌ Error in _createAuthenticatedOrder: $e');
      rethrow;
    }
  }

  models.AppOrder _createGuestOrder({
    required int outletId,
    required int vendorId,
    required String vendorName,
    required String orderId,
    required DateTime now,
    LatLng? deliveryLocation,
    String? deliveryAddress,
    String? phoneNumber,
    String? notes,
  }) {
    debugPrint('🛒 Creating guest order: $orderId');

    final double totalWithTax = totalAmount + calculateTax();

    final List<models.OrderItem> orderItems = _items
        .map((item) => models.OrderItem(
              id: item['product_id']?.toString() ?? '',
              name: item['title'] as String,
              price: (item['price'] as num).toDouble(),
              quantity: item['quantity'] as int,
            ))
        .toList();

    final models.AppOrder guestOrder = models.AppOrder(
      id: 'GUEST-$orderId',
      userId: 'guest',
      vendorName: vendorName,
      status: 'pending',
      timestamp: now,
      items: orderItems,
      totalPrice: totalWithTax,
      quantity: totalQuantity,
      deliveryLocation: deliveryLocation,
      outletId: outletId.toString(),
    );

    debugPrint('⚠️ Guest order created (cart not cleared)');
    return guestOrder;
  }

  double calculateTax() {
    return totalAmount * 0.16;
  }

  double getFinalTotal({double discount = 0.0}) {
    final double tax = calculateTax();
    return totalAmount - discount + tax;
  }

  Map<String, dynamic> getSummary() {
    return <String, dynamic>{
      'itemCount': itemCount,
      'totalQuantity': totalQuantity,
      'totalAmount': totalAmount,
      'totalWithTax': getFinalTotal(),
      'tax': calculateTax(),
      'items': _items,
    };
  }

  @override
  String toString() {
    return 'Cart(items: ${_items.length}, total: $totalAmount, quantity: $totalQuantity)';
  }
}

final Cart cart = Cart();