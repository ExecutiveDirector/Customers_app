// lib/screens/home/widgets/category_section.dart
//
// Previously: four hardcoded categories that didn't match the real
// product categories, every tap (including "See All") was a no-op, and
// there was no way to actually browse by category. Now pulls real
// categories from GET /products/categories and every tile opens a
// filtered product grid.
import 'package:flutter/material.dart';

import 'package:aquagas/models/category.dart';
import 'package:aquagas/services/product_service.dart';
import 'package:aquagas/theme/app_colors.dart';
import 'package:aquagas/screens/category_products_screen.dart';

// A small, deliberate rotation of tints (not the app's primary green for
// every tile — that would make them indistinguishable from each other and
// from every CTA in the app) used only as soft backgrounds behind each
// category's icon, so the row stays scannable even before real photography
// exists for every category.
const List<Color> _tileTints = <Color>[
  AppColors.green50,
  Color(0xFFFFF7ED), // warm amber tint
  Color(0xFFEFF6FF), // soft blue tint
  Color(0xFFF5F3FF), // soft violet tint
];

const List<Color> _tileAccents = <Color>[
  AppColors.green600,
  Color(0xFFD97706),
  Color(0xFF2563EB),
  Color(0xFF7C3AED),
];

IconData _iconForCategory(String name) {
  final String n = name.toLowerCase();
  if (n.contains('accessor') || n.contains('regulator') || n.contains('hose')) {
    return Icons.settings_suggest_rounded;
  }
  if (n.contains('refill') || n.contains('exchange')) {
    return Icons.autorenew_rounded;
  }
  if (n.contains('deliver')) return Icons.local_shipping_rounded;
  if (n.contains('cylinder') || n.contains('gas') || n.contains('lpg')) {
    return Icons.propane_tank_rounded;
  }
  if (n.contains('stove') || n.contains('cooker') || n.contains('burner')) {
    return Icons.outdoor_grill_rounded;
  }
  return Icons.category_rounded;
}

class CategorySection extends StatefulWidget {
  const CategorySection({super.key});

  @override
  State<CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends State<CategorySection> {
  final ProductService _productService = ProductService();
  List<Category>? _categories;
  bool _errored = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final List<Category> categories = await _productService.getCategories();
      if (mounted) setState(() => _categories = categories);
    } catch (_) {
      if (mounted) setState(() => _errored = true);
    }
  }

  void _openCategory(Category category) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext _) => CategoryProductsScreen(
          categoryId: category.id,
          categoryName: category.name,
        ),
      ),
    );
  }

  void _openAllCategories() {
    if (_categories == null || _categories!.isEmpty) return;
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext _) => _AllCategoriesScreen(
          categories: _categories!,
          onSelect: _openCategory,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Loading: keep the row's height reserved with skeleton tiles instead
    // of the section jumping in once data arrives.
    if (_categories == null && !_errored) {
      return _buildRow(
        itemCount: 4,
        itemBuilder: (int i) => const _CategorySkeletonTile(),
      );
    }

    if (_errored || _categories!.isEmpty) {
      return const SizedBox.shrink();
    }

    return _buildRow(
      itemCount: _categories!.length + 1,
      itemBuilder: (int i) {
        if (i == _categories!.length) {
          return _SeeAllTile(onTap: _openAllCategories);
        }
        final Category category = _categories![i];
        return _CategoryTile(
          category: category,
          tint: _tileTints[i % _tileTints.length],
          accent: _tileAccents[i % _tileAccents.length],
          icon: _iconForCategory(category.name),
          onTap: () => _openCategory(category),
        );
      },
    );
  }

  Widget _buildRow({
    required int itemCount,
    required Widget Function(int) itemBuilder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Text(
            'Shop by category',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.slate800),
          ),
        ),
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: itemCount,
            separatorBuilder: (BuildContext _, int __) =>
                const SizedBox(width: 12),
            itemBuilder: (BuildContext context, int i) => itemBuilder(i),
          ),
        ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.tint,
    required this.accent,
    required this.icon,
    required this.onTap,
  });

  final Category category;
  final Color tint;
  final Color accent;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: SizedBox(
        width: 84,
        child: Column(
          children: <Widget>[
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(18),
              ),
              child: (category.iconUrl != null && category.iconUrl!.isNotEmpty)
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.network(
                        category.iconUrl!,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (BuildContext _, Object __, StackTrace? ___) =>
                                Icon(icon, color: accent, size: 30),
                      ),
                    )
                  : Icon(icon, color: accent, size: 30),
            ),
            const SizedBox(height: 6),
            Text(
              category.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate800),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeeAllTile extends StatelessWidget {
  const _SeeAllTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: SizedBox(
        width: 84,
        child: Column(
          children: <Widget>[
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.slate100,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: AppColors.slate500.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.grid_view_rounded,
                  color: AppColors.slate500, size: 26),
            ),
            const SizedBox(height: 6),
            const Text(
              'See all',
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slate500),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategorySkeletonTile extends StatelessWidget {
  const _CategorySkeletonTile();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 84,
      child: Column(
        children: <Widget>[
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
                color: AppColors.slate100,
                borderRadius: BorderRadius.circular(18)),
          ),
          const SizedBox(height: 6),
          Container(width: 50, height: 10, color: AppColors.slate100),
        ],
      ),
    );
  }
}

class _AllCategoriesScreen extends StatelessWidget {
  const _AllCategoriesScreen(
      {required this.categories, required this.onSelect});
  final List<Category> categories;
  final ValueChanged<Category> onSelect;

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
                boxShadow: [
                  BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 8,
                      offset: Offset(0, 2))
                ],
              ),
              child: Row(
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: AppColors.slate800),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Text(
                    'All categories',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate800),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.85,
                ),
                itemCount: categories.length,
                itemBuilder: (BuildContext context, int i) {
                  final Category category = categories[i];
                  return _CategoryTile(
                    category: category,
                    tint: _tileTints[i % _tileTints.length],
                    accent: _tileAccents[i % _tileAccents.length],
                    icon: _iconForCategory(category.name),
                    onTap: () {
                      Navigator.of(context).pop();
                      onSelect(category);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
