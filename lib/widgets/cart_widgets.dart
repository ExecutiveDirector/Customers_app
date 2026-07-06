// lib/widgets/cart_widgets.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:aquagas/cart.dart';
// import 'package:aquagas/main.dart';
import 'package:aquagas/app.dart';

// =============================================================================
// Empty Cart View
// =============================================================================

/// Displays an empty cart state with call-to-action button
class EmptyCartView extends StatelessWidget {
  const EmptyCartView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 120,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 24),
            Text(
              'Your cart is empty',
              style: TextStyle(
                fontSize: 22.0,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add items to get started',
              style: TextStyle(
                fontSize: 16.0,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushReplacementNamed(context, Routes.home);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              icon: const Icon(Icons.shopping_bag, color: Colors.white),
              label: const Text(
                'Start Shopping',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Cart Content View
// =============================================================================

/// Displays the cart items list and summary
class CartContentView extends StatelessWidget {
  final Function(Map<String, dynamic>, bool) onQuantityUpdate;
  final VoidCallback onConfirmOrder;
  final bool isProcessing;

  const CartContentView({
    super.key,
    required this.onQuantityUpdate,
    required this.onConfirmOrder,
    required this.isProcessing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: cart.itemCount,
            itemBuilder: (context, index) {
              final item = cart.items[index];
              return CartItemCard(
                item: item,
                onQuantityUpdate: onQuantityUpdate,
              );
            },
          ),
        ),
        CartSummary(
          total: cart.totalAmount,
          onConfirmOrder: onConfirmOrder,
          isProcessing: isProcessing,
        ),
      ],
    );
  }
}

// =============================================================================
// Cart Item Card
// =============================================================================

/// Displays a single cart item with image, details, and quantity controls
class CartItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final Function(Map<String, dynamic>, bool) onQuantityUpdate;

  const CartItemCard({
    super.key,
    required this.item,
    required this.onQuantityUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_KE',
      symbol: 'KSh ',
      decimalDigits: 2,
    );
    final itemTotal = (item['price'] as double) * (item['quantity'] as int);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProductImage(imageUrl: item['image'] as String?),
            const SizedBox(width: 12),
            Expanded(
              child: ProductDetails(
                title: item['title'].toString(),
                price: item['price'] as double,
                itemTotal: itemTotal,
                currencyFormatter: currencyFormatter,
              ),
            ),
            QuantityControls(
              quantity: item['quantity'] as int,
              onDecrease: () => onQuantityUpdate(item, false),
              onIncrease: () => onQuantityUpdate(item, true),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Product Image
// =============================================================================

/// Displays product image with error handling
class ProductImage extends StatelessWidget {
  final String? imageUrl;

  const ProductImage({super.key, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        imageUrl ?? 'https://via.placeholder.com/80',
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.image_not_supported,
            size: 40,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Product Details
// =============================================================================

/// Displays product title, price, and subtotal
class ProductDetails extends StatelessWidget {
  final String title;
  final double price;
  final double itemTotal;
  final NumberFormat currencyFormatter;

  const ProductDetails({
    super.key,
    required this.title,
    required this.price,
    required this.itemTotal,
    required this.currencyFormatter,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          currencyFormatter.format(price),
          style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Text(
          'Subtotal: ${currencyFormatter.format(itemTotal)}',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: Colors.green,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Quantity Controls
// =============================================================================

/// Displays quantity increase/decrease buttons with current quantity
class QuantityControls extends StatelessWidget {
  final int quantity;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  const QuantityControls({
    super.key,
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            color: Colors.red,
            iconSize: 24,
            onPressed: onDecrease,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '$quantity',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle),
            color: Colors.green,
            iconSize: 24,
            onPressed: onIncrease,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Cart Summary
// =============================================================================

/// Displays cart total and checkout button
class CartSummary extends StatelessWidget {
  final double total;
  final VoidCallback onConfirmOrder;
  final bool isProcessing;

  const CartSummary({
    super.key,
    required this.total,
    required this.onConfirmOrder,
    required this.isProcessing,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_KE',
      symbol: 'KSh ',
      decimalDigits: 2,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20.0),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total:',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  currencyFormatter.format(total),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: isProcessing ? null : onConfirmOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  disabledBackgroundColor: Colors.orange.shade200,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                icon: isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.payment, color: Colors.white),
                label: Text(
                  isProcessing ? 'Processing...' : 'Proceed to Payment',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
