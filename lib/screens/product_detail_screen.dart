// lib/screens/product_detail_screen.dart
//
// Didn't exist before — every product card only had an "Add to Cart"
// button with nothing behind a tap on the card itself. Built to mirror
// what the customer website shows on a product page (full description,
// every image, specs, where it's available) and to match the tracking
// screen's green/slate theme.
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:aquagas/models/product.dart';
import 'package:aquagas/services/product_service.dart';
import 'package:aquagas/theme/app_colors.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  /// Reuses whatever cart-add logic the screen that navigated here already
  /// has (outlet resolution, validation, etc. — see home_page.dart's
  /// _handleAddToCart) instead of duplicating it here.
  final VoidCallback? onAddToCart;

  const ProductDetailScreen({
    super.key,
    required this.product,
    this.onAddToCart,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final ProductService _productService = ProductService();
  final PageController _pageController = PageController();

  late Product _product;
  int _currentImage = 0;
  bool _loadingDetails = true;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
    _fetchFullDetails();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchFullDetails() async {
    if (_product.id.isEmpty) {
      setState(() => _loadingDetails = false);
      return;
    }
    try {
      final Product detail = await _productService.getProductDetails(_product.id);
      if (!mounted) return;
      setState(() {
        _product = _product.mergedWithDetails(detail);
        _loadingDetails = false;
      });
    } catch (_) {
      // Not fatal — we already have the summary data from the card that
      // opened this screen, so just keep showing that.
      if (mounted) setState(() => _loadingDetails = false);
    }
  }

  void _openFullScreenGallery(int startIndex) {
    final List<String> images = _product.galleryImages;
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => _FullScreenGallery(
          images: images,
          initialIndex: startIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<String> images = _product.galleryImages;

    return Scaffold(
      backgroundColor: AppColors.slate100,
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            expandedHeight: 340,
            pinned: true,
            backgroundColor: Colors.white,
            leading: _circleButton(
              icon: Icons.arrow_back_rounded,
              onTap: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: _buildGallery(images),
            ),
          ),
          SliverToBoxAdapter(child: _buildInfo()),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _circleButton({required IconData icon, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: AppColors.slate800, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildGallery(List<String> images) {
    if (images.isEmpty) {
      return Container(
        color: AppColors.slate100,
        child: const Center(
          child: Icon(Icons.propane_tank_rounded, size: 72, color: AppColors.slate500),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        PageView.builder(
          controller: _pageController,
          itemCount: images.length,
          onPageChanged: (int i) => setState(() => _currentImage = i),
          itemBuilder: (BuildContext context, int index) {
            return GestureDetector(
              onTap: () => _openFullScreenGallery(index),
              child: Hero(
                tag: 'product-image-${_product.id}-$index',
                child: Image.network(
                  images[index],
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.slate100,
                    child: const Icon(Icons.broken_image_rounded,
                        size: 56, color: AppColors.slate500),
                  ),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: AppColors.slate100,
                      child: const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.green500, strokeWidth: 2),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
        if (images.length > 1)
          Positioned(
            bottom: 14,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(images.length, (int i) {
                final bool active = i == _currentImage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active ? Colors.white : Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
        if (images.length > 1)
          Positioned(
            top: 8,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_currentImage + 1}/${images.length}',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInfo() {
    final Product p = _product;
    final bool hasRange = p.minPrice != null && p.maxPrice != null && p.minPrice != p.maxPrice;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      transform: Matrix4.translationValues(0, -20, 0),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (p.categoryName != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.green50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                p.categoryName!,
                style: const TextStyle(
                    color: AppColors.green600, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          const SizedBox(height: 10),
          Text(
            p.title,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: AppColors.slate800),
          ),
          if (p.brand != null && p.brand!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(p.brand!, style: const TextStyle(color: AppColors.slate500, fontSize: 13.5)),
          ],
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                hasRange
                    ? 'KSh ${p.minPrice!.toStringAsFixed(0)} – ${p.maxPrice!.toStringAsFixed(0)}'
                    : 'KSh ${p.price.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.green600),
              ),
              if (p.rating > 0) ...<Widget>[
                const SizedBox(width: 12),
                const Icon(Icons.star_rounded, color: AppColors.amber500, size: 18),
                const SizedBox(width: 2),
                Text(p.rating.toStringAsFixed(1),
                    style: const TextStyle(color: AppColors.slate800, fontWeight: FontWeight.w600)),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _buildSpecChips(),
          if (p.description != null && p.description!.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 20),
            _sectionTitle('Description'),
            const SizedBox(height: 8),
            Text(p.description!, style: const TextStyle(color: AppColors.slate800, height: 1.5)),
          ],
          if (p.availableAt.isNotEmpty) ...<Widget>[
            const SizedBox(height: 20),
            _sectionTitle('Available at'),
            const SizedBox(height: 10),
            ...p.availableAt.map(_buildOutletRow),
          ],
          if (_hasSpecsContent) ...<Widget>[
            const SizedBox(height: 20),
            _sectionTitle('Specifications'),
            const SizedBox(height: 8),
            _buildSpecificationsBlock(),
          ],
          if (p.safetyCertifications != null && p.safetyCertifications!.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 20),
            _sectionTitle('Safety & certification'),
            const SizedBox(height: 8),
            _buildTextOrList(p.safetyCertifications!, icon: Icons.verified_rounded),
          ],
          if (p.storageRequirements != null && p.storageRequirements!.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 20),
            _sectionTitle('Storage requirements'),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(Icons.warehouse_rounded, size: 18, color: AppColors.slate500),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(p.storageRequirements!,
                      style: const TextStyle(color: AppColors.slate800, height: 1.4)),
                ),
              ],
            ),
          ],
          if (_loadingDetails) ...<Widget>[
            const SizedBox(height: 20),
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.green500),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool get _hasSpecsContent {
    final dynamic decoded = Product.tryDecodeJson(_product.specifications);
    if (decoded is Map && decoded.isNotEmpty) return true;
    if (decoded is List && decoded.isNotEmpty) return true;
    return _product.specifications != null && _product.specifications!.trim().isNotEmpty;
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.slate800),
      );

  Widget _buildOutletRow(AvailableOutlet outlet) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.slate100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(outlet.outletName,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.slate800, fontSize: 13.5)),
                const SizedBox(height: 2),
                Text(outlet.vendorName,
                    style: const TextStyle(color: AppColors.slate500, fontSize: 12)),
                const SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    Text('KSh ${outlet.price.toStringAsFixed(0)}',
                        style: const TextStyle(color: AppColors.green600, fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(width: 8),
                    Text(
                      outlet.stock > 0 ? '${outlet.stock} in stock' : 'Out of stock',
                      style: TextStyle(
                        color: outlet.stock > 0 ? AppColors.slate500 : AppColors.red500,
                        fontSize: 11.5,
                      ),
                    ),
                    if (outlet.vendorRating > 0) ...<Widget>[
                      const SizedBox(width: 8),
                      const Icon(Icons.star_rounded, size: 13, color: AppColors.amber500),
                      const SizedBox(width: 2),
                      Text(outlet.vendorRating.toStringAsFixed(1),
                          style: const TextStyle(color: AppColors.slate500, fontSize: 11.5)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (outlet.contactPhone != null && outlet.contactPhone!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.call_rounded, color: AppColors.green600),
              onPressed: () async {
                final Uri uri = Uri(scheme: 'tel', path: outlet.contactPhone);
                if (await canLaunchUrl(uri)) await launchUrl(uri);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSpecChips() {
    final List<Widget> chips = <Widget>[];

    if (_product.sizeSpecification != null && _product.sizeSpecification!.isNotEmpty) {
      chips.add(_chip(Icons.straighten_rounded, _product.sizeSpecification!));
    }
    if (_product.weightKg != null) {
      chips.add(_chip(Icons.scale_rounded, '${_product.weightKg!.toStringAsFixed(1)} kg'));
    }
    if (_product.unitOfMeasure != null && _product.unitOfMeasure!.isNotEmpty) {
      chips.add(_chip(Icons.inventory_2_rounded, _product.unitOfMeasure!));
    }
    chips.add(_chip(
      _product.stock > 0 ? Icons.check_circle_rounded : Icons.remove_circle_rounded,
      _product.stock > 0 ? 'In stock' : 'Out of stock',
      color: _product.stock > 0 ? AppColors.green600 : AppColors.red500,
    ));

    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  Widget _chip(IconData icon, String label, {Color? color}) {
    final Color c = color ?? AppColors.slate800;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.slate100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  /// Specifications are stored server-side as raw (unparsed) JSON text, or
  /// sometimes plain notes. Best-effort render whichever it turns out to
  /// be rather than assuming one shape.
  Widget _buildSpecificationsBlock() {
    final dynamic decoded = Product.tryDecodeJson(_product.specifications);

    if (decoded is Map) {
      return Column(
        children: decoded.entries.map((MapEntry<dynamic, dynamic> e) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  flex: 2,
                  child: Text('${e.key}',
                      style: const TextStyle(color: AppColors.slate500, fontSize: 13)),
                ),
                Expanded(
                  flex: 3,
                  child: Text('${e.value}',
                      style: const TextStyle(
                          color: AppColors.slate800, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }

    if (decoded is List) {
      return _buildTextOrList(decoded.join('\n'), icon: Icons.circle, bullet: true);
    }

    return Text(_product.specifications ?? '', style: const TextStyle(color: AppColors.slate800, height: 1.4));
  }

  Widget _buildTextOrList(String raw, {required IconData icon, bool bullet = false}) {
    final List<String> lines =
        raw.split(RegExp(r'[\n,]')).map((String s) => s.trim()).where((String s) => s.isNotEmpty).toList();

    if (lines.length <= 1) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: AppColors.green600),
          const SizedBox(width: 8),
          Expanded(child: Text(raw, style: const TextStyle(color: AppColors.slate800, height: 1.4))),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines
          .map((String line) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(bullet ? Icons.circle : icon, size: bullet ? 6 : 18, color: AppColors.green600),
                    const SizedBox(width: 8),
                    Expanded(child: Text(line, style: const TextStyle(color: AppColors.slate800, height: 1.4))),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget? _buildBottomBar() {
    if (widget.onAddToCart == null) return null;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x1A000000), blurRadius: 12, offset: Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _product.stock > 0 ? widget.onAddToCart : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green500,
              disabledBackgroundColor: AppColors.slate100,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.shopping_cart_rounded, color: Colors.white),
            label: Text(
              _product.stock > 0 ? 'Add to Cart' : 'Out of stock',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ),
      ),
    );
  }
}

class _FullScreenGallery extends StatefulWidget {
  const _FullScreenGallery({required this.images, required this.initialIndex});
  final List<String> images;
  final int initialIndex;

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late final PageController _controller = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: <Widget>[
            PageView.builder(
              controller: _controller,
              itemCount: widget.images.length,
              onPageChanged: (int i) => setState(() => _index = i),
              itemBuilder: (BuildContext context, int index) {
                return InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: Hero(
                      tag: 'product-image-fullscreen-$index',
                      child: Image.network(widget.images[index], fit: BoxFit.contain),
                    ),
                  ),
                );
              },
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    if (widget.images.length > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('${_index + 1}/${widget.images.length}',
                            style: const TextStyle(color: Colors.white)),
                      ),
                    const SizedBox(width: 48),
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
