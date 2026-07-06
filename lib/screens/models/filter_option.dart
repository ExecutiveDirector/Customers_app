// ============================================================================
// lib/screens/models/filter_option.dart
// ============================================================================
enum FilterOption {
  nearest,
  priceAsc,
  priceDesc,
  rating,
  availability,
}

extension FilterOptionExtension on FilterOption {
  String get label {
    switch (this) {
      case FilterOption.nearest:
        return 'Nearest';
      case FilterOption.priceAsc:
        return 'Price: Low to High';
      case FilterOption.priceDesc:
        return 'Price: High to Low';
      case FilterOption.rating:
        return 'Top Rated';
      case FilterOption.availability:
        return 'In Stock';
    }
  }
}
