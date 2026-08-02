// ============================================================================
// lib/screens/home/widgets/vendor_products_section.dart - HORIZONTAL LAYOUT
// ============================================================================
//
// Section + card redesign for the home page's "outlets near you" feed.
//
// What changed:
//   • Outlet header is slimmer and quieter — small icon, clear
//     outlet name + vendor, distance pill on the right, and a single
//     "View all" text button. No more competing boxes and gradients.
//   • Product cards (horizontal scroll) now use a real card surface
//     (white + soft border + 1 subtle shadow) instead of the 1px grey
//     outline of the previous version. Add-to-cart CTA uses the brand
//     teal (not orange) so it matches the rest of the app's identity.
//   • Stock + rating communicate more honestly: "Out" pill replaces
//     "Out of Stock" on the compact card, low-stock shows a counter
//     badge, rating uses a single inline row instead of competing with
//     a "stock count" number in parentheses.
//   • ProductDetailScreen is still the same destination, OutletProductsPage
//     is still the "View all" destination — no API or routing changes.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:aquagas/models/product.dart';
import 'package:aquagas/services/outlet_service.dart';
import 'package:aquagas/screens/product_detail_screen.dart';
import 'package:aquagas/theme/app_colors.dart';

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
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _OutletHeader(
            outletName: outletName,
            vendorName: vendorName,
            distance: distance,
            onViewAll: () => _showAllProducts(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              itemCount: products.length,
              separatorBuilder: (BuildContext _, int __) =>
                  const SizedBox(width: AppSpacing.xs),
              itemBuilder: (BuildContext context, int index) {
                return SizedBox(
                  width: 162,
                  child: ProductCard(
                    product: products[index],
                    onAdd: () => onProductAdded(products[index]),
                  ),
                );
              },
            ),
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

class _OutletHeader extends StatelessWidget {
  const _OutletHeader({
    required this.outletName,
    required this.vendorName,
    required this.distance,
    required this.onViewAll,
  });

  final String outletName;
  final String vendorName;
  final double? distance;
  final VoidCallback onViewAll;

  Color _distanceColor(double km) {
    if (km <= 5) return AppColors.success;
    if (km <= 10) return AppColors.info;
    return AppColors.warning;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.brandLight,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: AppColors.brandDark,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  outletName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.slate900,
                    letterSpacing: -0.2,
                  ),
                ),
                if (vendorName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      vendorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.slate500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          if (distance != null)
            Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: _distanceColor(distance!).withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.near_me_rounded,
                    size: 11,
                    color: _distanceColor(distance!),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${distance!.toStringAsFixed(1)} km',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _distanceColor(distance!),
                    ),
                  ),
                ],
              ),
            ),
          TextButton(
            onPressed: onViewAll,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.brandDark,
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('View all'),
          ),
        ],
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

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
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
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.slate100),
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Product image
              AspectRatio(
                aspectRatio: 16 / 11,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    _ProductImage(url: product.image),
                    if (product.rating >= 4.5)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: _PillTag(
                          label: 'Top',
                          icon: Icons.star_rounded,
                          background: AppColors.warning,
                          foreground: Colors.white,
                        ),
                      ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _StockPill(
                        inStock: isAvailable,
                        stock: product.stock,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xs,
                    AppSpacing.xs,
                    AppSpacing.xs,
                    AppSpacing.xs,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // Title
                      Text(
                        product.title,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.slate800,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      // Rating row
                      Row(
                        children: <Widget>[
                          const Icon(
                            Icons.star_rounded,
                            color: AppColors.warning,
                            size: 12,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            product.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.slate700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Price + Add
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              currencyFormatter.format(product.price),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.brandDark,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          _AddButton(inStock: isAvailable, onTap: onAdd),
                        ],
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

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) {
      return Container(
        color: AppColors.slate100,
        child: const Icon(
          Icons.local_gas_station_rounded,
          color: AppColors.slate400,
          size: 36,
        ),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (BuildContext _, Object __, StackTrace? ___) => Container(
        color: AppColors.slate100,
        child: const Icon(
          Icons.local_gas_station_rounded,
          color: AppColors.slate400,
          size: 36,
        ),
      ),
      loadingBuilder: (BuildContext _, Widget child, ImageChunkEvent? p) {
        if (p == null) return child;
        return Container(color: AppColors.slate100);
      },
    );
  }
}

class _PillTag extends StatelessWidget {
  const _PillTag({
    required this.label,
    required this.background,
    required this.foreground,
    this.icon,
  });

  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: background.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, color: foreground, size: 10),
            const SizedBox(width: 2),
          ],
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _StockPill extends StatelessWidget {
  const _StockPill({required this.inStock, required this.stock});
  final bool inStock;
  final int stock;

  @override
  Widget build(BuildContext context) {
    if (!inStock) {
      return _PillTag(
        label: 'Out',
        background: AppColors.danger,
        foreground: Colors.white,
      );
    }
    if (stock > 0 && stock < 5) {
      return _PillTag(
        label: '$stock left',
        background: AppColors.warning,
        foreground: Colors.white,
      );
    }
    return const SizedBox.shrink();
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.inStock, required this.onTap});
  final bool inStock;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: inStock ? AppColors.brand : AppColors.slate200,
      borderRadius: BorderRadius.circular(AppRadius.xs),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.xs),
        onTap: inStock ? onTap : null,
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(
            Icons.add_rounded,
            color: inStock ? Colors.white : AppColors.slate500,
            size: 18,
          ),
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              outletName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (vendorName.isNotEmpty)
              Text(
                vendorName,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.66,
          crossAxisSpacing: AppSpacing.xs,
          mainAxisSpacing: AppSpacing.xs,
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
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
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
            border: Border.all(color: AppColors.slate100),
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    _ProductImage(url: product.image),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _StockPill(inStock: isAvailable, stock: product.stock),
                    ),
                    if (product.rating >= 4.5)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: _PillTag(
                          label: 'Top',
                          background: AppColors.warning,
                          foreground: Colors.white,
                          icon: Icons.star_rounded,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // Title
                      Text(
                        product.title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.slate800,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      // Rating
                      Row(
                        children: <Widget>[
                          const Icon(
                            Icons.star_rounded,
                            color: AppColors.warning,
                            size: 12,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            product.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.slate700,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Price + Add row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              currencyFormatter.format(product.price),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.brandDark,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          _AddButton(inStock: isAvailable, onTap: onAdd),
                        ],
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
