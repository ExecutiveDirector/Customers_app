// lib/controllers/cart_controller.dart  –  DRAFT-FIRST VERSION
import 'package:flutter/material.dart';
import 'package:aquagas/cart.dart';
import 'package:aquagas/app.dart';
import 'package:aquagas/app_order.dart' as models;
import 'package:aquagas/services/auth_service.dart';
import 'package:aquagas/services/order_service.dart';

/// Controller that handles cart operations and order-confirmation / payment flow
class CartController {
  final OrderService _orderService = OrderService();

  /* =======================================================================
   *  PUBLIC API
   * ======================================================================= */

  /// Draft-first confirm order (Pesapal integration)
  Future<void> confirmOrder({
    required BuildContext context,
    required AuthService authService,
    Map<String, dynamic>? deliverySchedule,
    required Function(models.AppOrder) onSuccess,
  }) async {
    /* ---------------- 1.  Cart validation ---------------- */
    if (cart.items.isEmpty) {
      _showSnackBar(context, 'Your cart is empty', Colors.red);
      return;
    }
    if (!cart.validateCart()) {
      _showSnackBar(
        context,
        'Invalid items in cart. Please check your cart.',
        Colors.red,
      );
      return;
    }

    /* ---------------- 2.  Auth check ---------------- */
    final bool isAuthenticated = await authService.isAuthenticated();

    /* ---------------- 3.  Loading UI ---------------- */
    _showLoadingDialog(context);

    String? draftOrderId; // kept in outer scope for cancellation

    try {
      /* ---------------- 4.  Build payload (re-use existing helper) ---- */
      final orderPayload = await _prepareOrderPayload(
        isAuthenticated: isAuthenticated,
        authService: authService,
        deliverySchedule: deliverySchedule,
      );

      /* ---------------- 5.  Extract fields for draft call ------------- */
      final String userId = isAuthenticated
          ? orderPayload['user_id'].toString()
          : orderPayload['guest_identifier'] as String;

      final String outletId = orderPayload['outlet_id'].toString();
      final double totalPrice = (orderPayload['total'] as num).toDouble();
      final List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(
        orderPayload['items'] as List<dynamic>,
      );

      // Use real user email/phone; fall back to guest stubs only when truly unknown
      final String customerEmail = orderPayload['customer_email']?.toString() ??
          orderPayload['guest_email']?.toString() ??
          'guest@example.com';
      final String customerPhone = orderPayload['customer_phone']?.toString() ??
          orderPayload['guest_phone']?.toString() ??
          '+254700000000';

      /* ---------------- 6.  Create DRAFT order ------------------------ */
      draftOrderId = await _orderService.createDraftOrder(
        userId: userId,
        items: items,
        outletId: outletId,
        totalPrice: totalPrice,
        customerEmail: customerEmail,
        customerPhone: customerPhone,
        deliveryAddress: orderPayload['delivery_address'] as String?,
        deliveryLatitude: orderPayload['delivery_latitude'] as double?,
        deliveryLongitude: orderPayload['delivery_longitude'] as double?,
        deliveryNotes: orderPayload['delivery_notes'] as String?,
        isGuest: !isAuthenticated,
      );

      debugPrint('✅ Draft order created: $draftOrderId');

      /* ---------------- 7.  Initiate Pesapal payment ------------------ */
      final paymentResult = await _orderService.initiatePayment(
        orderId: draftOrderId,
        customerEmail: customerEmail,
        customerPhone: customerPhone,
      );

      final String redirectUrl = paymentResult['redirect_url'] as String;

      /* ---------------- 8.  Close loading before redirect ------------- */
      if (!context.mounted) return;
      Navigator.of(context).pop(); // close loading

      // TODO: launch redirectUrl in WebView / external browser
      debugPrint('🌍 Redirect customer to: $redirectUrl');

      /* ---------------- 9.  Fetch now-PENDING order ------------------- */
      final Map<String, dynamic> orderData =
          await _orderService.getOrderById(draftOrderId);
      final order = models.AppOrder.fromJson(orderData);

      /* ---------------- 10. Clear cart & callback --------------------- */
      cart.clear();
      onSuccess(order);

      /* ---------------- 11. Success snack-bar ------------------------- */
      final String msg =
          (deliverySchedule != null && deliverySchedule['type'] == 'scheduled')
              ? (isAuthenticated
                  ? '✓ Order scheduled! Complete payment.'
                  : '✓ Order scheduled! Proceed to payment.')
              : (isAuthenticated
                  ? '✓ Order created! Complete payment.'
                  : '✓ Order created! Proceed to payment.');
      _showSnackBar(context, msg, Colors.green.shade700);

      /* ---------------- 12. Navigate to confirmation ------------------ */
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!context.mounted) return;
      Navigator.pushReplacementNamed(
        context,
        '/orderConfirmation',
        arguments: order,
      );
    } catch (e) {
      /* -------------------------------------------------------------- */
      /*  Failure path – cancel draft if created                        */
      /* -------------------------------------------------------------- */
      if (draftOrderId != null) {
        try {
          await _orderService.cancelDraftOrder(
            orderId: draftOrderId,
            cancellationReason: 'Payment initiation failed: ${e.toString()}',
          );
        } catch (cancelError) {
          debugPrint('❌ Could not cancel draft order: $cancelError');
        }
      }

      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(); // close loading
      }
      if (!context.mounted) return;

      if (e is AuthException) {
        _handleAuthException(context, e, authService);
      } else {
        _handleGeneralError(context, e);
      }
    }
  }

  /// Proceed directly to payment (used only if order already exists)
  Future<void> proceedToPayment({
    required BuildContext context,
    required models.AppOrder order,
  }) async {
    try {
      Navigator.pushNamed(
        context,
        Routes.paymentOptions,
        arguments: order,
      );
    } catch (e) {
      _showSnackBar(context, 'Failed to proceed to payment', Colors.red);
    }
  }

  /// Show guest-checkout info dialog
  Future<bool> showGuestCheckoutDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Continue as Guest?'),
        content: const _GuestBenefitsList(),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue as Guest'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, false);
              Navigator.pushNamed(context, Routes.signIn);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Clear cart with confirmation
  Future<void> clearCart(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear Cart?'),
        content: const Text(
            'Are you sure you want to remove all items from your cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear Cart'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      cart.clear();
      if (context.mounted) {
        _showSnackBar(context, 'Cart cleared', Colors.grey);
      }
    }
  }

  /* =======================================================================
   *  PRIVATE HELPERS – PAYLOAD & GUEST ID
   * ======================================================================= */

  /// Build order payload (unchanged except for minor tidy-up)
  Future<Map<String, dynamic>> _prepareOrderPayload({
    required bool isAuthenticated,
    required AuthService authService,
    Map<String, dynamic>? deliverySchedule,
  }) async {
    final firstItem = cart.items.first;
    final dynamic outletId = firstItem['outlet_id'];
    final dynamic vendorId = firstItem['vendor_id'];

    final List<Map<String, dynamic>> items = cart.items.map((item) {
      return <String, dynamic>{
        'product_id': item['product_id'],
        'product_name': item['product_name'] ?? item['title'],
        'quantity': item['quantity'],
        'price': item['price'],
        'subtotal': (item['price'] as num) * (item['quantity'] as int),
      };
    }).toList();

    final double subtotal = cart.totalAmount;
    final double tax = cart.calculateTax();
    final double total = subtotal + tax;

    final Map<String, dynamic> payload = <String, dynamic>{
      'outlet_id': outletId,
      'vendor_id': vendorId,
      'items': items,
      'subtotal': subtotal,
      'tax': tax,
      'total': total,
      'currency': 'KES',
      'item_count': cart.totalQuantity,
    };

    // delivery schedule
    if (deliverySchedule != null) {
      payload['delivery_schedule'] = deliverySchedule;
      if (deliverySchedule['type'] == 'scheduled') {
        payload['delivery_type'] = 'scheduled';
        payload['scheduled_delivery_datetime'] =
            deliverySchedule['scheduled_datetime'];
        if (deliverySchedule['scheduled_date'] != null) {
          payload['scheduled_date'] = deliverySchedule['scheduled_date'];
        }
        if (deliverySchedule['scheduled_time'] != null) {
          payload['scheduled_time'] = deliverySchedule['scheduled_time'];
        }
        debugPrint(
            '📅 Scheduled delivery: ${deliverySchedule['scheduled_datetime']}');
      } else {
        payload['delivery_type'] = 'immediate';
        debugPrint('🚀 Immediate delivery requested');
      }
    } else {
      payload['delivery_type'] = 'immediate';
    }

    // auth / guest block (identical to your fixed version)
    if (isAuthenticated) {
      payload['order_source'] = 'authenticated';
      final Map<String, dynamic>? userData = await authService.getCurrentUser();
      debugPrint('🔍 Retrieved user data: $userData');

      if (userData == null) throw AuthException('No user data available');

      dynamic userId;
      if (userData.containsKey('user_id') && userData['user_id'] != null) {
        userId = userData['user_id'];
      } else if (userData.containsKey('account_id') &&
          userData['account_id'] != null) {
        userId = userData['account_id'];
      } else if (userData.containsKey('id') && userData['id'] != null) {
        userId = userData['id'];
      } else if (userData.containsKey('profile') &&
          userData['profile'] is Map<String, dynamic>) {
        final profile = userData['profile'] as Map<String, dynamic>;
        if (profile.containsKey('user_id')) {
          userId = profile['user_id'];
        } else if (profile.containsKey('account_id')) {
          userId = profile['account_id'];
        }
      } else if (userData.containsKey('account') &&
          userData['account'] is Map<String, dynamic>) {
        final account = userData['account'] as Map<String, dynamic>;
        if (account.containsKey('account_id')) {
          userId = account['account_id'];
        }
      }

      if (userId != null) {
        payload['user_id'] = userId;
        debugPrint('✅ Using user_id for order: $userId');

        // Store real email & phone so confirmOrder can pass them to Pesapal
        final String? email = userData['email']?.toString();
        final String? phone =
            (userData['phone_number'] ?? userData['phone'])?.toString();
        if (email != null && email.isNotEmpty)
          payload['customer_email'] = email;
        if (phone != null && phone.isNotEmpty)
          payload['customer_phone'] = phone;
      } else {
        debugPrint('❌ Available user data keys: ${userData.keys.toList()}');
        throw AuthException('User ID not found in user data');
      }
    } else {
      payload['order_source'] = 'guest';
      payload['guest_identifier'] = _generateGuestId();
      debugPrint('👤 Guest order: ${payload['guest_identifier']}');
    }

    return payload;
  }

  String _generateGuestId() => 'guest_${DateTime.now().millisecondsSinceEpoch}';

  /* =======================================================================
   *  PRIVATE HELPERS – UI FEEDBACK
   * ======================================================================= */

  void _showLoadingDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.green),
                  SizedBox(height: 16),
                  Text('Creating your order...', style: TextStyle(fontSize: 16))
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /* =======================================================================
   *  PRIVATE HELPERS – ERROR HANDLING
   * ======================================================================= */

  void _handleAuthException(
    BuildContext context,
    AuthException e,
    AuthService authService,
  ) {
    final String msg = authService.getAuthErrorMessage(e);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Sign In',
          textColor: Colors.white,
          onPressed: () => Navigator.pushNamed(context, Routes.signIn),
        ),
      ),
    );
  }

  void _handleGeneralError(BuildContext context, Object error) {
    final String errStr = error.toString();
    String msg;
    if (errStr.contains('Network') || errStr.contains('SocketException')) {
      msg = 'Network error. Please check your connection.';
    } else if (errStr.contains('timeout')) {
      msg = 'Request timed out. Please try again.';
    } else if (errStr.contains('Outlet information missing')) {
      msg = 'Product information incomplete. Please try adding items again.';
    } else {
      msg = errStr.replaceAll('Exception: ', '');
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: () => confirmOrder(
            context: context,
            authService: AuthService(),
            deliverySchedule: null,
            onSuccess: (_) {},
          ),
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------
 *  Tiny local widget reused in dialog
 * ------------------------------------------------------------------------- */
class _GuestBenefitsList extends StatelessWidget {
  const _GuestBenefitsList();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('You can complete your order as a guest or sign in for:'),
        const SizedBox(height: 12),
        _benefitRow('Order tracking'),
        _benefitRow('Order history'),
        _benefitRow('Faster checkout'),
      ],
    );
  }

  Widget _benefitRow(String txt) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(txt)),
        ],
      ),
    );
  }
}
