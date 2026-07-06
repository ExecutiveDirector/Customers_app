// lib/screens/category_products_screen.dart
//
// Destination for tapping a category on the redesigned home-page category
// section. Reuses ProductGridCard/ProductDetailScreen so the browsing
// experience matches the rest of the app instead of introducing a third
// product-card style.
import 'package:flutter/material.dart';

import 'package:aquagas/models/product.dart';
import 'package:aquagas/services/product_service.dart';
import 'package:aquagas/theme/app_colors.dart';
import 'package:aquagas/screens/home/widgets/vendor_products_section.dart'
    show ProductGridCard;
import 'package:aquagas/cart.dart' as cart_lib;

class CategoryProductsScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;

  const CategoryProductsScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  final ProductService _productService = ProductService();
  List<Product> _products = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final List<Product> products =
          await _productService.getProductsByCategory(widget.categoryId);
      if (!mounted) return;
      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _addToCart(Product product) {
    try {
      if (product.id.isEmpty || product.title.isEmpty || product.price <= 0) {
        throw cart_lib.CartException('This product is missing required information.');
      }

      final String outletId = product.outletId?.toString() ?? '';
      if (outletId.isEmpty) {
        throw cart_lib.CartException('Outlet information is missing for this product');
      }

      cart_lib.cart.addItem(<String, dynamic>{
        'id': product.id,
        'product_id': product.id,
        'outlet_id': outletId,
        'outletId': outletId,
        'title': product.title,
        'price': product.price,
        'image': product.image,
        'vendorName': product.vendorName,
        'outletName': product.outletName ?? 'Unknown Outlet',
        'description': product.description ?? '',
        'brand': product.brand ?? '',
        'sizeSpecification': product.sizeSpecification ?? '',
        'stock': product.stock,
        'quantity': 1,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${product.title} added to cart')),
      );
    } on cart_lib.CartException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add to cart: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate100,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 16, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2))],
              ),
              child: Row(
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: AppColors.slate800),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      widget.categoryName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.slate800),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.green500));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.slate500)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _load,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.green500),
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }
    if (_products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.slate500),
              const SizedBox(height: 12),
              Text('No products in ${widget.categoryName} yet.',
                  textAlign: TextAlign.center, style: const TextStyle(color: AppColors.slate500)),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.green500,
      onRefresh: _load,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.68,
        ),
        itemCount: _products.length,
        itemBuilder: (BuildContext context, int index) {
          final Product product = _products[index];
          return ProductGridCard(
            product: product,
            onAdd: () => _addToCart(product),
          );
        },
      ),
    );
  }
}
