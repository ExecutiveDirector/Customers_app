// ============================================================================
// lib/screens/home/widgets/vendor_products_section.dart - HORIZONTAL LAYOUT
// ============================================================================
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:aquagas/models/product.dart';
import 'package:aquagas/services/outlet_service.dart';
import 'package:aquagas/screens/product_detail_screen.dart';

class VendorProductsSection extends StatelessWidget {
  final String vendorName;
  final String outletName;
  final int outletId;
  final double? distance;
  final List<Product> products;
  final Function(Product) onProductAdded;

  const VendorProductsSection({
    super.key,
    required this.vendorName,
    required this.outletName,
    required this.outletId,
    this.distance,
    required this.products,
    required this.onProductAdded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Outlet header
          _buildOutletHeader(context),
          const Divider(height: 1),

          // Horizontal scrollable product list
          SizedBox(
            height: 240, // Fixed height for horizontal scroll
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              itemCount: products.length,
              itemBuilder: (BuildContext context, int index) {
                return ProductCard(
                  product: products[index],
                  onAdd: () => onProductAdded(products[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutletHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Outlet icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.green.shade200,
                width: 1.5,
              ),
            ),
            child: Icon(
              Icons.store_outlined,
              size: 28,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(width: 14),

          // Outlet info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  outletName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.business_outlined,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        vendorName,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Distance badge and View All button
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (distance != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: distance! <= 5
                          ? [Colors.green.shade400, Colors.green.shade600]
                          : distance! <= 10
                              ? [Colors.blue.shade400, Colors.blue.shade600]
                              : [
                                  Colors.orange.shade400,
                                  Colors.orange.shade600
                                ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${distance!.toStringAsFixed(1)} km',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  _showAllProducts(context);
                },
                icon: const Icon(Icons.grid_view, size: 16),
                label: const Text('View All'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.green.shade700,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAllProducts(BuildContext context) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext context) => OutletProductsPage(
          vendorName: vendorName,
          outletName: outletName,
          outletId: outletId,
          distance: distance,
          products: products,
          onProductAdded: onProductAdded,
        ),
      ),
    );
  }
}

// ============================================================================
// Product Card - Compact horizontal card
// ============================================================================
class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onAdd;

  const ProductCard({
    super.key,
    required this.product,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final NumberFormat currencyFormatter = NumberFormat.currency(
      locale: 'en_KE',
      symbol: 'KSh ',
      decimalDigits: 0,
    );

    final bool isAvailable =
        product.availability.toLowerCase() != 'out of stock' &&
            product.stock > 0;

    return GestureDetector(
      onTap: () {
        Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (BuildContext context) => ProductDetailScreen(
              product: product,
              onAddToCart: onAdd,
            ),
          ),
        );
      },
      child: Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Image.network(
              product.image,
              width: 160,
              height: 110,
              fit: BoxFit.cover,
              errorBuilder: (BuildContext context, Object error,
                      StackTrace? stackTrace) =>
                  Container(
                width: 160,
                height: 110,
                color: Colors.grey.shade200,
                child: Icon(
                  Icons.image_not_supported,
                  color: Colors.grey.shade400,
                  size: 40,
                ),
              ),
            ),
          ),

          // Product details
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    product.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Brand/Size
                  if (product.brand != null ||
                      product.sizeSpecification != null)
                    Text(
                      [
                        if (product.brand != null) product.brand!,
                        if (product.sizeSpecification != null)
                          product.sizeSpecification!,
                      ].join(' • '),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                  const Spacer(),

                  // Price
                  Text(
                    currencyFormatter.format(product.price),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Add button
                  SizedBox(
                    width: double.infinity,
                    height: 32,
                    child: ElevatedButton(
                      onPressed: isAvailable ? onAdd : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        disabledBackgroundColor: Colors.grey.shade300,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_shopping_cart,
                            size: 14,
                            color: isAvailable
                                ? Colors.white
                                : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Add',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isAvailable
                                  ? Colors.white
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class OutletProductsScreen extends StatefulWidget {
  const OutletProductsScreen({super.key});

  @override
  State<OutletProductsScreen> createState() => _OutletProductsScreenState();
}

class _OutletProductsScreenState extends State<OutletProductsScreen> {
  final OutletService _outletService = OutletService();

  List<Product> _products = <Product>[];

  bool _isLoading = true;
  String? _error;

  late String _outletName;
  late String _vendorName;
  late int _outletId;
  double? _distance;

  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_initialized) return;
    _initialized = true;

    final Map<String, dynamic> args =
        (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?) ??
            <String, dynamic>{};

    _outletName = args['outlet_name']?.toString() ?? 'Outlet';

    _vendorName = args['vendor_name']?.toString() ?? '';

    // getNearbyOutlets() (see outlet_service.dart) returns the outlet's
    // identifier under the key 'outlet_id', formatted as a STRING (the
    // backend does outlet.outlet_id.toString()) — not 'id', and not a
    // number. Reading args['id'] here always missed, so _outletId silently
    // fell back to 0 and every tap on a nearby outlet fetched outlet 0
    // (never exists) instead of the real one, landing on a 404 error.
    _outletId = int.tryParse(
          (args['outlet_id'] ?? args['id'])?.toString() ?? '',
        ) ??
        0;

    _distance = (args['distance_km'] as num?)?.toDouble();

    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    if (_outletId <= 0) {
      setState(() {
        _isLoading = false;
        _error = 'This outlet could not be identified. Please go back and '
            'try again.';
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final Map<String, dynamic> data =
          await _outletService.getOutletWithProducts(
        _outletId.toString(),
      );

      final List<dynamic> rawProducts =
          data['products'] as List<dynamic>? ?? <dynamic>[];

      if (!mounted) return;

      setState(() {
        _products = rawProducts
            .map(
              (dynamic product) => Product.fromJson(
                product as Map<String, dynamic>,
              ),
            )
            .toList();

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_outletName),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_outletName),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                ),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchProducts,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return OutletProductsPage(
      vendorName: _vendorName,
      outletName: _outletName,
      outletId: _outletId,
      distance: _distance,
      products: _products,
      onProductAdded: (Product product) {
        debugPrint(
          'Added product: ${product.title}',
        );
      },
    );
  }
}

// ============================================================================
// Full Outlet Products Page - Grid View (2 columns)
// ============================================================================
class OutletProductsPage extends StatelessWidget {
  final String vendorName;
  final String outletName;
  final int outletId;
  final double? distance;
  final List<Product> products;
  final Function(Product) onProductAdded;

  const OutletProductsPage({
    super.key,
    required this.vendorName,
    required this.outletName,
    required this.outletId,
    this.distance,
    required this.products,
    required this.onProductAdded,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              outletName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              vendorName,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.70,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: products.length,
        itemBuilder: (BuildContext context, int index) {
          return ProductGridCard(
            product: products[index],
            onAdd: () => onProductAdded(products[index]),
          );
        },
      ),
    );
  }
}

// ============================================================================
// Product Grid Card - For 2-column grid view
// ============================================================================
class ProductGridCard extends StatelessWidget {
  final Product product;
  final VoidCallback onAdd;

  const ProductGridCard({
    super.key,
    required this.product,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final NumberFormat currencyFormatter = NumberFormat.currency(
      locale: 'en_KE',
      symbol: 'KSh ',
      decimalDigits: 0,
    );

    final bool isAvailable =
        product.availability.toLowerCase() != 'out of stock' &&
            product.stock > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (BuildContext _) =>
                ProductDetailScreen(product: product, onAddToCart: onAdd),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product image with stock badge
              Stack(
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(12)),
                    child: Image.network(
                      product.image,
                      width: double.infinity,
                      height: 140,
                      fit: BoxFit.cover,
                      errorBuilder: (BuildContext context, Object error,
                              StackTrace? stackTrace) =>
                          Container(
                        width: double.infinity,
                        height: 140,
                        color: Colors.grey.shade200,
                        child: Icon(
                          Icons.image_not_supported,
                          color: Colors.grey.shade400,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                  // Stock status badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isAvailable ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isAvailable
                            ? (product.stock < 5
                                ? '${product.stock} left'
                                : 'In Stock')
                            : 'Out',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Product details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        product.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // Brand/Size
                      if (product.brand != null ||
                          product.sizeSpecification != null)
                        Text(
                          [
                            if (product.brand != null) product.brand!,
                            if (product.sizeSpecification != null)
                              product.sizeSpecification!,
                          ].join(' • '),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                      const Spacer(),

                      // Rating
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            product.rating.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Price
                      Text(
                        currencyFormatter.format(product.price),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Add button
                      SizedBox(
                        width: double.infinity,
                        height: 36,
                        child: ElevatedButton(
                          onPressed: isAvailable ? onAdd : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            disabledBackgroundColor: Colors.grey.shade300,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_shopping_cart,
                                size: 16,
                                color: isAvailable
                                    ? Colors.white
                                    : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Add to Cart',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isAvailable
                                      ? Colors.white
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}