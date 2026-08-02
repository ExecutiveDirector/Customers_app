// lib/screens/home/widgets/featured_products.dart
//
// Curated featured product carousel for the home page.
//
// Picks the top-N products (currently: highest rated, then by stock
// breadth) from the outlets that the home page already loaded, so this
// widget requires zero new API calls and just re-uses the data the page
// has. Falls back to "nothing to feature" gracefully if the dataset is
// empty so the home page never shows a half-broken section header.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:aquagas/models/product.dart';
import 'package:aquagas/models/outlet_products.dart';
import 'package:aquagas/screens/product_detail_screen.dart';
import 'package:aquagas/theme/app_colors.dart';

class FeaturedProducts extends StatelessWidget {
  final List<OutletProducts> outlets;
  final ValueChanged<Product> onAddToCart;

  const FeaturedProducts({
    super.key,
    required this.outlets,
    required this.onAddToCart,
  });

  List<Product> _pickFeatured() {
    final List<Product> pool = <Product>[];
    for (final OutletProducts o in outlets) {
      pool.addAll(o.products);
    }
    if (pool.isEmpty) return const <Product>[];

    pool.sort((Product a, Product b) {
      // Primary: rating desc. Secondary: stock desc. Tertiary: price asc.
      final int byRating = b.rating.compareTo(a.rating);
      if (byRating != 0) return byRating;
      final int byStock = b.stock.compareTo(a.stock);
      if (byStock != 0) return byStock;
      return a.price.compareTo(b.price);
    });
    return pool.take(6).toList();
  }

  @override
  Widget build(BuildContext context) {
    final List<Product> featured = _pickFeatured();
    if (featured.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionHeader(
          title: 'Featured for you',
          subtitle: 'Top picks near you, updated daily',
        ),
        SizedBox(
          height: 248,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: featured.length,
            separatorBuilder: (BuildContext _, int __) =>
                const SizedBox(width: AppSpacing.sm),
            itemBuilder: (BuildContext context, int i) {
              return SizedBox(
                width: 156,
                child: _FeaturedCard(
                  product: featured[i],
                  onAddToCart: () => onAddToCart(featured[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.product, required this.onAddToCart});
  final Product product;
  final VoidCallback onAddToCart;

  @override
  Widget build(BuildContext context) {
    final NumberFormat currencyFormatter = NumberFormat.currency(
      locale: 'en_KE',
      symbol: 'KSh ',
      decimalDigits: 0,
    );

    final bool inStock = product.stock > 0;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (BuildContext _) => ProductDetailScreen(
                product: product,
                onAddToCart: onAddToCart,
              ),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.slate100),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Full-width image on top — gives the content column below
              // its full width instead of splitting it with the image.
              SizedBox(
                height: 100,
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: _ProductImage(
                        url: product.image,
                        fit: BoxFit.cover,
                      ),
                    ),
                    if (product.rating >= 4.5)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: _PillTag(
                          label: 'Top rated',
                          background: AppColors.warning,
                          foreground: Colors.white,
                          icon: Icons.star_rounded,
                        ),
                      ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm,
                    AppSpacing.xs,
                    AppSpacing.sm,
                    AppSpacing.xs,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        product.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.slate800,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: <Widget>[
                          const Icon(
                            Icons.star_rounded,
                            color: AppColors.warning,
                            size: 13,
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
                          if (product.brand != null &&
                              product.brand!.trim().isNotEmpty) ...<Widget>[
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '· ${product.brand!}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.slate500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const Spacer(),
                      // Price gets the card's full content width now,
                      // instead of sharing ~74px with the add button.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                currencyFormatter.format(product.price),
                                maxLines: 1,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.brandDark,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _AddButton(
                            inStock: inStock,
                            onTap: onAddToCart,
                          ),
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
          width: 30,
          height: 30,
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

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.url, required this.fit});
  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) {
      return Container(
        color: AppColors.slate100,
        child: const Icon(
          Icons.local_gas_station_rounded,
          color: AppColors.slate400,
          size: 32,
        ),
      );
    }
    return Image.network(
      url,
      fit: fit,
      errorBuilder: (BuildContext _, Object __, StackTrace? ___) => Container(
        color: AppColors.slate100,
        child: const Icon(
          Icons.local_gas_station_rounded,
          color: AppColors.slate400,
          size: 32,
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.slate900,
                    letterSpacing: -0.2,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.slate500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Public so other sections (categories, outlets) can share the same
/// header styling and feel.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => _SectionHeader(
        title: title,
        subtitle: subtitle,
      );
}
