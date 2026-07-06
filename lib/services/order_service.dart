// lib/services/order_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:aquagas/services/auth_service.dart';
import 'dart:async' show Future, TimeoutException, unawaited;

/// Service for managing orders with backend API
/// Supports both authenticated and guest users
class OrderService {
  static const String _baseUrl = 'https://aquagas-backend.onrender.com/api/v1';
  final AuthService _authService = AuthService();

  // =========================================================================
  // Helper: Error logging
  // =========================================================================
  /// Logs an error locally and (best-effort, fire-and-forget) reports it to
  /// the backend's client-error endpoint so it shows up in system_events
  /// alongside server-side events, instead of only living in the device's
  /// debug console.
  ///
  /// This intentionally never throws: a failure to log must never break the
  /// calling code path.
  void logError(String context, dynamic error, {String? orderId}) {
    debugPrint('[$context] Error: $error');

    // Fire-and-forget — do not await, do not let this affect the caller.
    unawaited(_reportErrorToBackend(
      context: context,
      error: error,
      orderId: orderId,
    ));
  }

  Future<void> _reportErrorToBackend({
    required String context,
    required dynamic error,
    String? orderId,
  }) async {
    try {
      final String? token = await _authService.getToken();

      await http
          .post(
            Uri.parse('$_baseUrl/logs/client-error'),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode(<String, dynamic>{
              'context': context,
              'message': error.toString(),
              'severity': 'error',
              'platform': 'flutter',
              if (orderId != null) 'orderId': orderId,
            }),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Swallow silently — logging the failure of logging would recurse.
    }
  }

  // =========================================================================
  // Order Creation Methods
  // =========================================================================

  /// Create a DRAFT order (no payment yet)
  Future<String> createDraftOrder({
    required String userId,
    required List<Map<String, dynamic>> items,
    required String outletId,
    required double totalPrice,
    String? customerEmail,
    String? customerPhone,
    double? deliveryLatitude,
    double? deliveryLongitude,
    String? deliveryAddress,
    String? deliveryNotes,
    bool isGuest = false,
  }) async {
    try {
      debugPrint('Creating DRAFT order for user: $userId (guest: $isGuest)');

      final String? token = isGuest ? null : await _authService.getToken();
      if (!isGuest && token == null) throw Exception('Not authenticated');

      if (outletId.isEmpty) throw Exception('Outlet ID is required');
      if (items.isEmpty)
        throw Exception('Order must contain at least one item');

      // Format items
      final List<Map<String, dynamic>> formattedItems =
          items.map<Map<String, dynamic>>((dynamic item) {
        return <String, dynamic>{
          'product_id':
              (item['product_id']?.toString() ?? item['id'].toString()),
          'quantity': (item['quantity'] ?? 1),
          'unit_price':
              ((item['unit_price'] ?? item['price'] ?? 0) as num).toDouble(),
        };
      }).toList();

      final Map<String, dynamic> payload = <String, dynamic>{
        'user_id': userId,
        'outlet_id': outletId,
        'items': formattedItems,
        'total_price': totalPrice,
        'status': 'DRAFT',
        'is_guest': isGuest,
      };

      if (customerEmail?.isNotEmpty == true)
        payload['customer_email'] = customerEmail;
      if (customerPhone?.isNotEmpty == true)
        payload['customer_phone'] = customerPhone;
      if (deliveryLatitude != null)
        payload['delivery_latitude'] = deliveryLatitude;
      if (deliveryLongitude != null)
        payload['delivery_longitude'] = deliveryLongitude;
      if (deliveryAddress?.isNotEmpty == true)
        payload['delivery_address'] = deliveryAddress;
      if (deliveryNotes?.isNotEmpty == true)
        payload['delivery_notes'] = deliveryNotes;

      debugPrint('Draft payload: ${jsonEncode(payload)}');

      final http.Response response = await http
          .post(
            Uri.parse('$_baseUrl/orders/draft'),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () =>
                throw Exception('Connection timeout. Please try again.'),
          );

      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.body.trim().startsWith('<!DOCTYPE') ||
          response.body.trim().startsWith('<html')) {
        throw Exception('Invalid response from server (received HTML)');
      }

      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('JSON Parse Error: $e');
        throw Exception('Invalid JSON response from server');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final String orderId = data['order']?['id']?.toString() ??
            data['order_id']?.toString() ??
            data['id']?.toString() ??
            '';

        if (orderId.isEmpty) {
          throw Exception('Draft order created but no ID returned.');
        }

        debugPrint('Draft order created: $orderId');
        return orderId;
      } else {
        final String errorMsg = (data['message'] ??
            data['error'] ??
            'Draft creation failed') as String;
        throw Exception(errorMsg);
      }
    } catch (e) {
      debugPrint('Draft order creation failed: $e');
      logError('createDraftOrder', e);
      rethrow;
    }
  }

  /// Create a standard order - Returns the created order ID
  Future<String> createOrder({
    required String userId,
    required List<Map<String, dynamic>> items,
    required String outletId,
    required double totalPrice,
    double? deliveryLatitude,
    double? deliveryLongitude,
    String? deliveryAddress,
    String? phoneNumber,
    String? notes,
    String? deliveryNotes,
    String? paymentMethod,
    String? scheduledDate,
    String? scheduledTime,
    String? couponCode,
    bool isGuest = false,
  }) async {
    try {
      debugPrint('Creating order for user: $userId (guest: $isGuest)');

      final String? token = await _authService.getToken();
      if (!isGuest && token == null) throw Exception('Not authenticated');

      if (outletId.isEmpty) throw Exception('Outlet ID is required');
      if (items.isEmpty)
        throw Exception('Order must contain at least one item');

      // Format items
      final List<Map<String, dynamic>> formattedItems =
          items.map<Map<String, dynamic>>((dynamic item) {
        return <String, dynamic>{
          'product_id':
              (item['product_id']?.toString() ?? item['id'].toString()),
          'quantity': (item['quantity'] ?? 1),
          'unit_price':
              ((item['unit_price'] ?? item['price'] ?? 0) as num).toDouble(),
        };
      }).toList();

      // Base order payload
      final Map<String, dynamic> orderData = <String, dynamic>{
        'user_id': userId,
        'outlet_id': outletId,
        'items': formattedItems,
        'total_price': totalPrice,
      };

      // Scheduling support
      if (scheduledDate != null && scheduledTime != null) {
        orderData['scheduled_date'] = scheduledDate;
        orderData['scheduled_time'] = scheduledTime;
      }

      // Optional fields
      if (phoneNumber?.isNotEmpty == true)
        orderData['phone_number'] = phoneNumber;
      if (notes?.isNotEmpty == true) orderData['notes'] = notes;
      if (deliveryNotes?.isNotEmpty == true)
        orderData['delivery_notes'] = deliveryNotes;
      if (paymentMethod?.isNotEmpty == true)
        orderData['payment_method'] = paymentMethod;
      if (couponCode?.isNotEmpty == true) orderData['coupon_code'] = couponCode;
      if (isGuest) orderData['is_guest'] = true;

      debugPrint('API Endpoint: $_baseUrl/orders');
      debugPrint('Payload: ${jsonEncode(orderData)}');

      final http.Response response = await http
          .post(
            Uri.parse('$_baseUrl/orders'),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode(orderData),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () =>
                throw Exception('Connection timeout. Please try again.'),
          );

      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      // Check if response is HTML
      if (response.body.trim().startsWith('<!DOCTYPE') ||
          response.body.trim().startsWith('<html')) {
        debugPrint('Received HTML instead of JSON');

        if (response.statusCode == 404) {
          throw Exception(
              'Order API endpoint not found. Please check backend configuration.');
        } else if (response.statusCode >= 500) {
          throw Exception('Server error. Please try again later.');
        } else {
          throw Exception(
              'Invalid response from server (received HTML instead of JSON)');
        }
      }

      // Parse JSON response
      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('JSON Parse Error: $e');
        throw Exception('Invalid JSON response from server');
      }

      // Handle success responses
      if (response.statusCode == 200 || response.statusCode == 201) {
        final String orderId = data['order']?['id']?.toString() ??
            data['order_id']?.toString() ??
            data['id']?.toString() ??
            '';

        if (orderId.isEmpty) {
          debugPrint('No order ID in response: $data');
          throw Exception('Order created but no ID returned.');
        }

        debugPrint('Order created successfully: $orderId');
        return orderId;
      } else {
        final String errorMsg = (data['message'] ??
            data['error'] ??
            data['details'] ??
            'Failed to create order') as String;
        debugPrint('Server error: $errorMsg');
        throw Exception(errorMsg);
      }
    } on http.ClientException catch (e) {
      debugPrint('HTTP Client error: $e');
      logError('createOrder', e);
      throw Exception('Network error: Unable to connect to server');
    } on FormatException catch (e) {
      debugPrint('Format error: $e');
      logError('createOrder', e);
      throw Exception('Invalid response format from server');
    } on TimeoutException catch (e) {
      debugPrint('Timeout error: $e');
      logError('createOrder', e);
      throw Exception(
          'Connection timeout. Please check your internet connection.');
    } catch (e) {
      debugPrint('Order creation failed: $e');
      logError('createOrder', e);
      rethrow;
    }
  }

  /// Create guest order with delivery notes support
  Future<String> createGuestOrder({
    required List<Map<String, dynamic>> items,
    required String outletId,
    required double totalPrice,
    double? deliveryLatitude,
    double? deliveryLongitude,
    String? deliveryAddress,
    String? phoneNumber,
    String? deliveryNotes,
  }) async {
    return createOrder(
      userId: 'guest',
      items: items,
      outletId: outletId,
      totalPrice: totalPrice,
      deliveryLatitude: deliveryLatitude,
      deliveryLongitude: deliveryLongitude,
      deliveryAddress: deliveryAddress,
      phoneNumber: phoneNumber,
      deliveryNotes: deliveryNotes,
      isGuest: true,
    );
  }

  // =========================================================================
  // Payment Methods
  // =========================================================================

  /// Initiate Pesapal payment (backend returns redirect URL)
  Future<Map<String, dynamic>> initiatePayment({
    required String orderId,
    required String customerEmail,
    required String customerPhone,
  }) async {
    try {
      debugPrint('Initiating payment for order: $orderId');

      final String? token = await _authService.getToken();
      if (token == null) throw Exception('Not authenticated');

      final Map<String, dynamic> payload = <String, dynamic>{
        'order_id': orderId,
        'customer_email': customerEmail,
        'customer_phone': customerPhone,
      };

      debugPrint('Payment initiation payload: ${jsonEncode(payload)}');

      final http.Response response = await http
          .post(
            Uri.parse('$_baseUrl/payments/initiate'),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () =>
                throw Exception('Connection timeout. Please try again.'),
          );

      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.body.trim().startsWith('<!DOCTYPE') ||
          response.body.trim().startsWith('<html')) {
        throw Exception('Invalid response from server (received HTML)');
      }

      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('JSON Parse Error: $e');
        throw Exception('Invalid JSON response from server');
      }

      if (response.statusCode == 200) {
        final String? redirectUrl = data['redirect_url'] as String?;

        if (redirectUrl == null || redirectUrl.isEmpty) {
          throw Exception('No redirect URL returned from payment gateway');
        }

        debugPrint('Payment initiated, redirect: $redirectUrl');
        return <String, dynamic>{'redirect_url': redirectUrl};
      } else {
        final String errorMsg = (data['message'] ??
            data['error'] ??
            'Payment initiation failed') as String;
        throw Exception(errorMsg);
      }
    } catch (e) {
      debugPrint('Payment initiation error: $e');
      logError('initiatePayment', e);
      rethrow;
    }
  }

  /// Confirm order after payment initiation (moves from draft to pending)
  /// Automatically notifies user after successful confirmation
  Future<void> confirmOrderPayment({
    required String orderId,
    required String paymentTrackingId,
    required String paymentMethod,
    String? phoneNumber,
    String? email,
  }) async {
    try {
      debugPrint('Confirming order payment: $orderId');

      final String? token = await _authService.getToken();
      if (token == null) throw Exception('Not authenticated');

      final Map<String, dynamic> payload = <String, dynamic>{
        'payment_tracking_id': paymentTrackingId,
        'payment_method': paymentMethod,
      };

      if (phoneNumber != null) payload['phone_number'] = phoneNumber;
      if (email != null) payload['email'] = email;

      debugPrint('Confirmation payload: ${jsonEncode(payload)}');

      final http.Response response = await http
          .post(
            Uri.parse('$_baseUrl/orders/$orderId/confirm'),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () =>
                throw Exception('Request timed out. Please try again.'),
          );

      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.body.trim().startsWith('<!DOCTYPE') ||
          response.body.trim().startsWith('<html')) {
        throw Exception('Invalid response from server (received HTML)');
      }

      if (response.statusCode == 200) {
        debugPrint('Order payment confirmed');

        // Automatically notify user after successful payment confirmation
        try {
          await notifyUser(
            orderId: orderId,
            message:
                'Your payment has been confirmed successfully. Order #$orderId is now being processed.',
            phoneNumber: phoneNumber,
            email: email,
          );
        } catch (notifyError) {
          debugPrint(
              'Failed to send payment confirmation notification: $notifyError');
          // Notification failure should not break the payment flow
        }
      } else {
        final Map<String, dynamic> error =
            jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(error['error'] ?? 'Failed to confirm order payment');
      }
    } catch (e) {
      debugPrint('Error confirming order payment: $e');
      logError('confirmOrderPayment', e);
      rethrow;
    }
  }

  /// Update payment status for an order
  Future<void> updatePaymentStatus({
    required String orderId,
    required String paymentStatus,
    String? transactionId,
    String? paymentReference,
  }) async {
    try {
      debugPrint('Updating payment status for order: $orderId');

      final String? token = await _authService.getToken();
      if (token == null) throw Exception('Not authenticated');

      final Map<String, dynamic> payload = <String, dynamic>{
        'payment_status': paymentStatus,
      };

      if (transactionId != null) payload['transaction_id'] = transactionId;
      if (paymentReference != null)
        payload['payment_reference'] = paymentReference;

      final http.Response response = await http
          .put(
            Uri.parse('$_baseUrl/orders/$orderId/payment-status'),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () =>
                throw Exception('Request timed out. Please try again.'),
          );

      debugPrint('Response Status: ${response.statusCode}');

      if (response.body.trim().startsWith('<!DOCTYPE') ||
          response.body.trim().startsWith('<html')) {
        throw Exception('Invalid response from server (received HTML)');
      }

      if (response.statusCode == 200) {
        debugPrint('Payment status updated');
      } else {
        final Map<String, dynamic> error =
            jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(error['error'] ?? 'Failed to update payment status');
      }
    } catch (e) {
      debugPrint('Error updating payment status: $e');
      logError('updatePaymentStatus', e);
      rethrow;
    }
  }

  /// Cancel draft order if payment fails or is cancelled
  /// Automatically notifies user after successful cancellation
  Future<void> cancelDraftOrder({
    required String orderId,
    String? cancellationReason,
    String? phoneNumber,
    String? email,
  }) async {
    try {
      debugPrint('Cancelling draft order: $orderId');

      final String? token = await _authService.getToken();
      if (token == null) throw Exception('Not authenticated');

      final Map<String, dynamic> payload = <String, dynamic>{};
      if (cancellationReason != null) {
        payload['cancellation_reason'] = cancellationReason;
      }

      final http.Response response = await http
          .post(
            Uri.parse('$_baseUrl/orders/$orderId/cancel-draft'),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: payload.isNotEmpty ? jsonEncode(payload) : null,
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () =>
                throw Exception('Request timed out. Please try again.'),
          );

      debugPrint('Response Status: ${response.statusCode}');

      if (response.body.trim().startsWith('<!DOCTYPE') ||
          response.body.trim().startsWith('<html')) {
        throw Exception('Invalid response from server (received HTML)');
      }

      if (response.statusCode == 200) {
        debugPrint('Draft order cancelled');

        // Automatically notify user after successful draft cancellation
        try {
          final String reason =
              cancellationReason ?? 'Draft order was cancelled';
          await notifyUser(
            orderId: orderId,
            message:
                'Draft order #$orderId has been cancelled. Reason: $reason',
            phoneNumber: phoneNumber,
            email: email,
          );
        } catch (notifyError) {
          debugPrint(
              'Failed to send draft cancellation notification: $notifyError');
        }
      } else {
        final Map<String, dynamic> error =
            jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(error['error'] ?? 'Failed to cancel draft order');
      }
    } catch (e) {
      debugPrint('Error cancelling draft order: $e');
      logError('cancelDraftOrder', e);
      rethrow;
    }
  }

  // =========================================================================
  // Order Retrieval Methods
  // =========================================================================

  /// Get order details by order ID
  Future<Map<String, dynamic>> getOrderById(String orderId) async {
    try {
      debugPrint('Fetching order: $orderId');

      final String? token = await _authService.getToken();

      if (token == null && orderId.startsWith('GUEST-')) {
        throw Exception('Please sign in to view order details');
      }

      if (token == null) throw Exception('Not authenticated');

      final http.Response response = await http.get(
        Uri.parse('$_baseUrl/orders/$orderId'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () =>
            throw Exception('Request timed out. Please try again.'),
      );

      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.body.trim().startsWith('<!DOCTYPE') ||
          response.body.trim().startsWith('<html')) {
        throw Exception('Invalid response from server (received HTML)');
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;

        // Log the full top-level keys so we can see the exact response shape
        debugPrint('📦 [getOrderById] Top-level keys: ${data.keys.toList()}');

        // Backend may wrap under data.order, data.data, or return it directly
        final Map<String, dynamic> order =
            data['order'] as Map<String, dynamic>? ??
                data['data'] as Map<String, dynamic>? ??
                data;

        debugPrint('📦 [getOrderById] Order keys: ${order.keys.toList()}');
        debugPrint('📦 [getOrderById] order_number=${order['order_number']}  '
            'order_status=${order['order_status']}  status=${order['status']}  '
            'total_amount=${order['total_amount']}  subtotal=${order['subtotal']}  '
            'grand_total=${order['grand_total']}  delivery_fee=${order['delivery_fee']}  '
            'payment_method=${order['payment_method']}  payment_status=${order['payment_status']}  '
            'delivery_address=${order['delivery_address']}');

        debugPrint('Order fetched successfully');
        return order;
      } else if (response.statusCode == 404) {
        throw Exception('Order not found');
      } else {
        final Map<String, dynamic> error =
            jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(error['error'] ?? 'Failed to fetch order details');
      }
    } catch (e) {
      debugPrint('Error fetching order: $e');
      logError('getOrderById', e);
      rethrow;
    }
  }

  /// Get user's order history
  Future<List<Map<String, dynamic>>> getUserOrders() async {
    try {
      debugPrint('📦 [getUserOrders] Fetching user orders...');

      final String? token = await _authService.getToken();

      // ── Debug: show whether a token exists (never print the full token in prod)
      if (token == null) {
        debugPrint(
            '❌ [getUserOrders] No token in secure storage — user must log in');
        throw Exception('Not authenticated');
      }
      debugPrint(
          '🔑 [getUserOrders] Token found (${token.length} chars), sending request...');

      final http.Response response = await http.get(
        Uri.parse('$_baseUrl/orders/user'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () =>
            throw Exception('Request timed out. Please try again.'),
      );

      debugPrint('📡 [getUserOrders] Status: ${response.statusCode}');
      debugPrint(
          '📡 [getUserOrders] Body (first 300 chars): ${response.body.length > 300 ? response.body.substring(0, 300) : response.body}');

      if (response.body.trim().startsWith('<!DOCTYPE') ||
          response.body.trim().startsWith('<html')) {
        throw Exception('Invalid response from server (received HTML)');
      }

      if (response.statusCode == 200) {
        final dynamic responseBody = jsonDecode(response.body);

        final List<Map<String, dynamic>> orders = <Map<String, dynamic>>[];

        if (responseBody is List) {
          orders.addAll(responseBody.map<Map<String, dynamic>>(
              (dynamic order) => order as Map<String, dynamic>));
        } else if (responseBody is Map<String, dynamic>) {
          final List<dynamic> ordersList =
              responseBody['orders'] as List<dynamic>? ?? <dynamic>[];
          orders.addAll(ordersList.map<Map<String, dynamic>>(
              (dynamic order) => order as Map<String, dynamic>));
        }

        debugPrint('✅ [getUserOrders] Fetched ${orders.length} orders');
        return orders;
      } else if (response.statusCode == 403) {
        // 403 = token is valid JWT but server is rejecting it.
        // Common causes:
        //   1. Account role mismatch (e.g. logged in as vendor/rider, not customer)
        //   2. Account deactivated / banned
        //   3. Token issued before a server secret rotation
        //   4. Render cold-start replayed an old token (restart and log in fresh)
        debugPrint('🚫 [getUserOrders] 403 Forbidden — body: ${response.body}');
        Map<String, dynamic> errBody = <String, dynamic>{};
        try {
          errBody = jsonDecode(response.body) as Map<String, dynamic>;
        } catch (_) {}
        final String serverMsg = errBody['error']?.toString() ??
            errBody['message']?.toString() ??
            'Access forbidden';
        throw Exception('403: $serverMsg');
      } else if (response.statusCode == 401) {
        debugPrint(
            '🔐 [getUserOrders] 401 Unauthorized — token expired or invalid');
        throw Exception('Session expired. Please log in again.');
      } else {
        Map<String, dynamic> error = <String, dynamic>{};
        try {
          error = jsonDecode(response.body) as Map<String, dynamic>;
        } catch (_) {}
        throw Exception(error['error'] ??
            'Failed to fetch orders (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('❌ [getUserOrders] Error: $e');
      logError('getUserOrders', e);
      rethrow;
    }
  }

  // =========================================================================
  // Order Update Methods
  // =========================================================================

  /// Update order with payment and delivery details
  Future<void> updateOrder({
    required String orderId,
    String? paymentMethod,
    double? deliveryFee,
    String? deliveryType,
    double? deliveryLatitude,
    double? deliveryLongitude,
    String? deliveryAddress,
    String? phoneNumber,
    String? status,
    String? notes,
  }) async {
    try {
      debugPrint('Updating order: $orderId');

      final String? token = await _authService.getToken();
      if (token == null) throw Exception('Not authenticated');

      final Map<String, dynamic> updateData = <String, dynamic>{};

      if (paymentMethod != null) updateData['payment_method'] = paymentMethod;
      if (deliveryFee != null) updateData['delivery_fee'] = deliveryFee;
      if (deliveryType != null) updateData['delivery_type'] = deliveryType;
      if (deliveryLatitude != null)
        updateData['delivery_latitude'] = deliveryLatitude;
      if (deliveryLongitude != null)
        updateData['delivery_longitude'] = deliveryLongitude;
      if (deliveryAddress != null)
        updateData['delivery_address'] = deliveryAddress;
      if (phoneNumber != null) updateData['phone_number'] = phoneNumber;
      if (status != null) updateData['status'] = status;
      if (notes != null) updateData['notes'] = notes;

      debugPrint('Update payload: ${jsonEncode(updateData)}');

      final http.Response response = await http
          .put(
            Uri.parse('$_baseUrl/orders/$orderId'),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(updateData),
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () =>
                throw Exception('Request timed out. Please try again.'),
          );

      debugPrint('Response Status: ${response.statusCode}');

      if (response.body.trim().startsWith('<!DOCTYPE') ||
          response.body.trim().startsWith('<html')) {
        throw Exception('Invalid response from server (received HTML)');
      }

      if (response.statusCode == 200) {
        debugPrint('Order updated successfully');
      } else {
        final Map<String, dynamic> error =
            jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(error['error'] ?? 'Failed to update order');
      }
    } catch (e) {
      debugPrint('Error updating order: $e');
      logError('updateOrder', e);
      rethrow;
    }
  }

  /// Cancel an order
  /// Automatically notifies user after successful cancellation
  Future<void> cancelOrder(
    String orderId, {
    String? reason,
    String? phoneNumber,
    String? email,
  }) async {
    try {
      debugPrint('Cancelling order: $orderId');

      final String? token = await _authService.getToken();
      if (token == null) throw Exception('Not authenticated');

      final Map<String, dynamic> body = <String, dynamic>{};
      if (reason != null) body['cancellation_reason'] = reason;

      final http.Response response = await http
          .put(
            Uri.parse('$_baseUrl/orders/$orderId/cancel'),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: body.isNotEmpty ? jsonEncode(body) : null,
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () =>
                throw Exception('Request timed out. Please try again.'),
          );

      debugPrint('Response Status: ${response.statusCode}');

      if (response.body.trim().startsWith('<!DOCTYPE') ||
          response.body.trim().startsWith('<html')) {
        throw Exception('Invalid response from server (received HTML)');
      }

      if (response.statusCode == 200) {
        debugPrint('Order cancelled successfully');

        // Automatically notify user after successful cancellation
        try {
          final String cancellationReason = reason ?? 'Order was cancelled';
          await notifyUser(
            orderId: orderId,
            message:
                'Order #$orderId has been cancelled. Reason: $cancellationReason',
            phoneNumber: phoneNumber,
            email: email,
          );
        } catch (notifyError) {
          debugPrint(
              'Failed to send order cancellation notification: $notifyError');
        }
      } else {
        final Map<String, dynamic> error =
            jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(error['error'] ?? 'Failed to cancel order');
      }
    } catch (e) {
      debugPrint('Error cancelling order: $e');
      logError('cancelOrder', e);
      rethrow;
    }
  }

  // =========================================================================
  // New Feature: Real-time Order Tracking / Polling
  // =========================================================================

  /// Poll order status every [interval] seconds until order is delivered or cancelled
  Stream<Map<String, dynamic>> trackOrderStatus(
    String orderId, {
    int interval = 5,
  }) async* {
    try {
      while (true) {
        final order = await getOrderById(orderId);
        yield order;

        final String status = order['status']?.toString().toUpperCase() ?? '';
        if (status == 'DELIVERED' || status == 'CANCELLED') break;

        await Future<void>.delayed(Duration(seconds: interval));
      }
    } catch (e) {
      logError('trackOrderStatus', e);
      rethrow;
    }
  }

  // =========================================================================
  // New Feature: Notifications
  // =========================================================================

  /// Send notification to user about order updates.
  ///
  /// This calls the backend's POST /notifications/send endpoint, which is
  /// multi-channel (email/SMS/push) and delivers email via the backend's
  /// own emailService (nodemailer) and SMS via its smsService — it looks
  /// the user up by ID and pulls their stored email/phone from the users
  /// table, so a `userId` is required. Since callers of this method only
  /// have an `orderId` on hand, we resolve the order's `customer_id` first.
  ///
  /// Guests (no auth token, no backend user row) have nowhere to be
  /// notified through the backend, so this is a no-op for them.
  Future<void> notifyUser({
    required String orderId,
    required String message,
    String? phoneNumber,
    String? email,
    String? subject,
  }) async {
    try {
      debugPrint(
          'Notifying user for order $orderId: $message (Phone: ${phoneNumber ?? "N/A"}, Email: ${email ?? "N/A"})');

      final String? token = await _authService.getToken();
      if (token == null) {
        debugPrint(
            'notifyUser: no auth token (guest) — skipping backend notification');
        return;
      }

      // Resolve the customer's user ID from the order, since the backend
      // notification endpoint identifies recipients by user ID rather than
      // raw email/phone.
      String? userId;
      try {
        final Map<String, dynamic> order = await getOrderById(orderId);
        userId = order['customer_id']?.toString() ??
            (order['customer'] as Map<String, dynamic>?)?['user_id']
                ?.toString();
      } catch (e) {
        debugPrint(
            'notifyUser: could not resolve customer for order $orderId: $e');
      }

      if (userId == null || userId.isEmpty) {
        debugPrint(
            'notifyUser: no customer id for order $orderId, skipping backend notification');
        return;
      }

      final List<String> channels = <String>['email'];
      if (phoneNumber?.isNotEmpty == true) channels.add('sms');

      final http.Response response = await http
          .post(
            Uri.parse('$_baseUrl/notifications/send'),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(<String, dynamic>{
              'userId': userId,
              'message': message,
              'channels': channels,
              'subject': subject ?? 'AquaGas Order Update',
              'relatedEntityType': 'order',
              'relatedEntityId': orderId,
            }),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Notification request timed out.'),
          );

      debugPrint(
          'notifyUser response (${response.statusCode}): ${response.body}');

      if (response.statusCode != 200 && response.statusCode != 201) {
        debugPrint(
            'notifyUser: backend returned ${response.statusCode}, notification may not have been delivered');
      }
    } catch (e) {
      debugPrint('notifyUser failed: $e');
      logError('notifyUser', e, orderId: orderId);
      rethrow;
    }
  }

  // =========================================================================
  // New Feature: Cancellation History
  // =========================================================================

  /// Get cancellation history for a specific order
  Future<List<Map<String, dynamic>>> getOrderCancellations(
      String orderId) async {
    try {
      debugPrint('Fetching cancellation history for order: $orderId');

      final String? token = await _authService.getToken();
      if (token == null) throw Exception('Not authenticated');

      final response = await http.get(
        Uri.parse('$_baseUrl/orders/$orderId/cancellations'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Request timed out.'),
      );

      debugPrint('Response Status: ${response.statusCode}');

      if (response.body.trim().startsWith('<!DOCTYPE') ||
          response.body.trim().startsWith('<html')) {
        throw Exception('Invalid response from server');
      }

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        final List<Map<String, dynamic>> cancellations =
            data.map((dynamic e) => e as Map<String, dynamic>).toList();

        debugPrint('Fetched ${cancellations.length} cancellation records');
        return cancellations;
      } else {
        final Map<String, dynamic> error =
            jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(
            error['error'] ?? 'Failed to fetch cancellation history');
      }
    } catch (e) {
      debugPrint('Error fetching cancellation history: $e');
      logError('getOrderCancellations', e);
      rethrow;
    }
  }

  // =========================================================================
  // New Feature: Refund Handling
  // =========================================================================

  /// Initiate a refund for an order
  Future<void> initiateRefund({
    required String orderId,
    required double amount,
    String? reason,
  }) async {
    try {
      debugPrint('Initiating refund for order $orderId, amount: $amount');

      final String? token = await _authService.getToken();
      if (token == null) throw Exception('Not authenticated');

      final payload = {
        'amount': amount,
        if (reason != null) 'reason': reason,
      };

      debugPrint('Refund payload: ${jsonEncode(payload)}');

      final response = await http
          .post(
            Uri.parse('$_baseUrl/orders/$orderId/refund'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception('Request timed out.'),
          );

      debugPrint('Response Status: ${response.statusCode}');

      if (response.body.trim().startsWith('<!DOCTYPE') ||
          response.body.trim().startsWith('<html')) {
        throw Exception('Invalid response from server');
      }

      if (response.statusCode == 200) {
        debugPrint('Refund initiated successfully');
      } else {
        final Map<String, dynamic> error =
            jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(error['error'] ?? 'Refund failed');
      }
    } catch (e) {
      debugPrint('Error initiating refund: $e');
      logError('initiateRefund', e);
      rethrow;
    }
  }

  // =========================================================================
  // New Feature: Promo Code Validation
  // =========================================================================

  /// Validate a promo code for a specific outlet
  Future<Map<String, dynamic>> validatePromoCode(
    String code, {
    required String outletId,
  }) async {
    try {
      debugPrint('Validating promo code: $code for outlet: $outletId');

      final String? token = await _authService.getToken();

      final response = await http
          .post(
            Uri.parse('$_baseUrl/promotions/validate'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'code': code,
              'outlet_id': outletId,
            }),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Request timed out.'),
          );

      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.body.trim().startsWith('<!DOCTYPE') ||
          response.body.trim().startsWith('<html')) {
        throw Exception('Invalid response from server');
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('Promo code validated successfully');
        return data;
      } else {
        final Map<String, dynamic> error =
            jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(error['error'] ?? 'Invalid promo code');
      }
    } catch (e) {
      debugPrint('Error validating promo code: $e');
      logError('validatePromoCode', e);
      rethrow;
    }
  }

  // =========================================================================
  // New Feature: Batch Order Retrieval
  // =========================================================================

  /// Fetch multiple orders by their IDs in a single request
  Future<List<Map<String, dynamic>>> getOrdersByIds(
      List<String> orderIds) async {
    try {
      debugPrint('Fetching batch orders: ${orderIds.length} orders');

      final String? token = await _authService.getToken();
      if (token == null) throw Exception('Not authenticated');

      final response = await http
          .post(
            Uri.parse('$_baseUrl/orders/batch'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'order_ids': orderIds}),
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception('Request timed out.'),
          );

      debugPrint('Response Status: ${response.statusCode}');

      if (response.body.trim().startsWith('<!DOCTYPE') ||
          response.body.trim().startsWith('<html')) {
        throw Exception('Invalid response from server');
      }

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        final List<Map<String, dynamic>> orders =
            data.map((dynamic e) => e as Map<String, dynamic>).toList();

        debugPrint('Fetched ${orders.length} orders in batch');
        return orders;
      } else {
        final Map<String, dynamic> error =
            jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(error['error'] ?? 'Failed to fetch batch orders');
      }
    } catch (e) {
      debugPrint('Error fetching batch orders: $e');
      logError('getOrdersByIds', e);
      rethrow;
    }
  }

  // =========================================================================
  // Vendor Methods
  // =========================================================================

  /// Get vendor location by vendor name
  Future<Map<String, dynamic>> getVendorLocation(String vendorName) async {
    try {
      debugPrint('Fetching vendor location: $vendorName');

      final String? token = await _authService.getToken();

      final http.Response response = await http.get(
        Uri.parse('$_baseUrl/vendors?name=${Uri.encodeComponent(vendorName)}'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () =>
            throw Exception('Request timed out. Please try again.'),
      );

      debugPrint('Response Status: ${response.statusCode}');

      if (response.body.trim().startsWith('<!DOCTYPE') ||
          response.body.trim().startsWith('<html')) {
        throw Exception('Invalid response from server (received HTML)');
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;

        final dynamic vendorData = data['vendor'] ?? data['vendors'];

        if (vendorData is Map<String, dynamic>) {
          debugPrint('Vendor location fetched');
          return vendorData;
        } else if (vendorData is List && vendorData.isNotEmpty) {
          debugPrint('Vendor location fetched');
          return vendorData.first as Map<String, dynamic>;
        }

        throw Exception('Vendor not found');
      } else {
        throw Exception('Failed to fetch vendor location');
      }
    } catch (e) {
      debugPrint('Error fetching vendor location: $e');
      logError('getVendorLocation', e);
      rethrow;
    }
  }

  /// Get vendor by outlet ID
  Future<Map<String, dynamic>> getVendorByOutletId(String outletId) async {
    try {
      debugPrint('Fetching vendor by outlet: $outletId');

      final String? token = await _authService.getToken();

      final http.Response response = await http.get(
        Uri.parse('$_baseUrl/outlets/$outletId'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () =>
            throw Exception('Request timed out. Please try again.'),
      );

      debugPrint('Response Status: ${response.statusCode}');

      if (response.body.trim().startsWith('<!DOCTYPE') ||
          response.body.trim().startsWith('<html')) {
        throw Exception('Invalid response from server (received HTML)');
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;

        debugPrint('Outlet data fetched');
        return data['outlet'] as Map<String, dynamic>? ?? data;
      } else {
        throw Exception('Failed to fetch outlet information');
      }
    } catch (e) {
      debugPrint('Error fetching outlet: $e');
      logError('getVendorByOutletId', e);
      rethrow;
    }
  }
}
