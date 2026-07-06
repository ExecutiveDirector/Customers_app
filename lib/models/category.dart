// lib/models/category.dart
class Category {
  final String id;
  final String name;
  final String? description;
  final String? iconUrl;

  const Category({
    required this.id,
    required this.name,
    this.description,
    this.iconUrl,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['category_id']?.toString() ?? '',
      name: json['category_name']?.toString() ?? 'Category',
      description: json['description']?.toString(),
      iconUrl: json['icon_url']?.toString(),
    );
  }
}
