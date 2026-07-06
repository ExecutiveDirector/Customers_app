// lib/utils/cart_debugger.dart
// Use this to debug cart validation issues

import 'package:flutter/foundation.dart';
import 'package:aquagas/cart.dart';

/// Helper class to debug cart validation issues
class CartDebugger {
  /// Check what's wrong with cart items
  static void diagnoseCart() {
    debugPrint('═══════════════════════════════════════');
    debugPrint('🔍 CART DIAGNOSIS');
    debugPrint('═══════════════════════════════════════');

    if (cart.isEmpty) {
      debugPrint('❌ ISSUE: Cart is empty');
      return;
    }

    debugPrint('📊 Total items: ${cart.itemCount}');
    debugPrint('📊 Total quantity: ${cart.totalQuantity}');
    debugPrint('📊 Total amount: ${cart.totalAmount}');
    debugPrint('───────────────────────────────────────');

    for (int i = 0; i < cart.items.length; i++) {
      final Map<String, dynamic> item = cart.items[i];
      debugPrint('\n🔎 Checking Item #${i + 1}:');
      debugPrint('Raw data: $item');

      // Check required fields
      _checkField(item, 'title', required: true);
      _checkField(item, 'price', required: true);
      _checkField(item, 'quantity', required: true);
      _checkField(item, 'outlet_id', required: true);
      _checkField(item, 'outletId', required: false);
      _checkField(item, 'product_id', required: false);
      _checkField(item, 'id', required: false);

      // Validate quantity
      final dynamic quantity = item['quantity'];
      if (quantity != null) {
        if (quantity is! int) {
          debugPrint(
              '❌ ISSUE: quantity is not an int, it is ${quantity.runtimeType}');
        } else if (quantity <= 0) {
          debugPrint('❌ ISSUE: quantity is <= 0 (value: $quantity)');
        } else {
          debugPrint('✅ quantity is valid: $quantity');
        }
      }

      // Validate price
      final dynamic price = item['price'];
      if (price != null) {
        if (price is! num) {
          debugPrint(
              '❌ ISSUE: price is not a number, it is ${price.runtimeType}');
        } else if (price <= 0) {
          debugPrint('❌ ISSUE: price is <= 0 (value: $price)');
        } else {
          debugPrint('✅ price is valid: $price');
        }
      }

      // Check outlet_id specifically
      final dynamic outletId = item['outlet_id'] ?? item['outletId'];
      if (outletId == null) {
        debugPrint('❌ CRITICAL: outlet_id is missing!');
        debugPrint('   This will cause "Invalid items in cart" error');
        debugPrint('   Available keys: ${item.keys.toList()}');
      } else if (outletId.toString().isEmpty) {
        debugPrint('❌ CRITICAL: outlet_id is empty string!');
      } else {
        debugPrint('✅ outlet_id found: $outletId');
      }

      debugPrint('───────────────────────────────────────');
    }

    debugPrint(
        '\n🎯 VALIDATION RESULT: ${cart.validateCart() ? "PASS ✅" : "FAIL ❌"}');
    debugPrint('═══════════════════════════════════════\n');
  }

  static void _checkField(
    Map<String, dynamic> item,
    String field, {
    bool required = false,
  }) {
    if (item.containsKey(field)) {
      final dynamic value = item[field];
      if (value == null) {
        debugPrint('⚠️  $field: exists but is null');
      } else if (value.toString().isEmpty) {
        debugPrint('⚠️  $field: exists but is empty');
      } else {
        debugPrint('✅ $field: $value (${value.runtimeType})');
      }
    } else {
      if (required) {
        debugPrint('❌ $field: MISSING (required field!)');
      } else {
        debugPrint('ℹ️  $field: not present');
      }
    }
  }

  /// Show how to properly add items to cart
  static void showCorrectUsage() {
    debugPrint('═══════════════════════════════════════');
    debugPrint('📖 CORRECT CART USAGE');
    debugPrint('═══════════════════════════════════════');
    debugPrint('''
// ✅ CORRECT WAY to add items to cart:
cart.addItem({
  'id': 'prod_123',                    // Product local ID
  'product_id': 'prod_123',            // Backend product ID
  'outlet_id': 'outlet_456',           // ← REQUIRED! Backend outlet ID
  'title': 'Gas Cylinder 13kg',        // ← REQUIRED!
  'price': 2500.0,                     // ← REQUIRED! (must be double)
  'quantity': 1,                       // Set automatically but can override
  'image': 'https://example.com/image.jpg',
  'vendorName': 'AquaGas Vendor',
  'description': 'Product description',
});

// ❌ WRONG WAY (missing outlet_id):
cart.addItem({
  'title': 'Gas Cylinder',
  'price': 2500,
  // Missing outlet_id!
});

// ❌ WRONG WAY (price is int instead of double):
cart.addItem({
  'title': 'Gas Cylinder',
  'price': 2500,  // Should be 2500.0
  'outlet_id': 'outlet_456',
});
''');
    debugPrint('═══════════════════════════════════════\n');
  }
}

// ENHANCED CART VALIDATION with detailed error messages
extension CartValidationExtension on Cart {
  /// Validate cart with detailed error reporting
  bool validateCartWithDetails() {
    final List<String> errors = <String>[];

    if (isEmpty) {
      debugPrint('❌ Cart validation failed: Cart is empty');
      return false;
    }

    for (int i = 0; i < items.length; i++) {
      final Map<String, dynamic> item = items[i];
      final String itemName = item['title']?.toString() ?? 'Item #${i + 1}';

      // Check title
      if (item['title'] == null || item['title'].toString().isEmpty) {
        errors.add('$itemName: Missing title');
      }

      // Check price
      if (item['price'] == null) {
        errors.add('$itemName: Missing price');
      } else if (item['price'] is! num) {
        errors.add(
            '$itemName: Price must be a number (found: ${item['price'].runtimeType})');
      } else if ((item['price'] as num) <= 0) {
        errors.add('$itemName: Price must be greater than 0');
      }

      // Check quantity
      final dynamic quantity = item['quantity'];
      if (quantity == null) {
        errors.add('$itemName: Missing quantity');
      } else if (quantity is! int) {
        errors.add(
            '$itemName: Quantity must be an integer (found: ${quantity.runtimeType})');
      } else if (quantity <= 0) {
        errors.add('$itemName: Quantity must be greater than 0');
      }

      // Check outlet_id (CRITICAL!)
      final dynamic outletId = item['outlet_id'] ?? item['outletId'];
      if (outletId == null) {
        errors.add(
            '$itemName: Missing outlet_id (CRITICAL - this causes checkout to fail)');
      } else if (outletId.toString().isEmpty) {
        errors.add('$itemName: outlet_id is empty');
      }
    }

    if (errors.isNotEmpty) {
      debugPrint('❌ Cart validation failed with ${errors.length} error(s):');
      for (final String error in errors) {
        debugPrint('   • $error');
      }
      return false;
    }

    debugPrint('✅ Cart validation passed!');
    return true;
  }
}
