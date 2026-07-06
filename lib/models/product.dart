// lib/models/product.dart
import 'dart:convert';
import 'package:equatable/equatable.dart';

/// One outlet that currently stocks a product — from getProductDetails'
/// `available_at` array. Lets the product detail screen show where it can
/// actually be picked up/delivered from, similar to the customer website's
/// product page (which shows this same data, just for a single outlet).
class AvailableOutlet {
  final String outletId;
  final String outletName;
  final String vendorName;
  final double vendorRating;
  final double price;
  final int stock;
  final double? latitude;
  final double? longitude;
  final String? contactPhone;

  const AvailableOutlet({
    required this.outletId,
    required this.outletName,
    required this.vendorName,
    required this.vendorRating,
    required this.price,
    required this.stock,
    this.latitude,
    this.longitude,
    this.contactPhone,
  });

  factory AvailableOutlet.fromJson(Map<String, dynamic> json) {
    return AvailableOutlet(
      outletId: json['outlet_id']?.toString() ?? '',
      outletName: json['outlet_name']?.toString() ?? 'Outlet',
      vendorName: json['vendor_name']?.toString() ?? '',
      vendorRating: (json['vendor_rating'] as num?)?.toDouble() ?? 0.0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      contactPhone: json['contact_phone']?.toString(),
    );
  }
}

class Product extends Equatable {
  final String id;
  final String title;
  final double price;
  final String image;
  final String vendorName;
  final double rating;
  final String availability;
  final bool isActive;
  final int stock;
  final int sales;
  final double vendorLatitude;
  final double vendorLongitude;

  // Additional fields from database
  final String? brand;
  final String? description;
  final String? sizeSpecification;
  final String? outletName;
  final int? outletId;

  // Full detail fields — populated from list endpoints where available,
  // and always populated (and more complete) from
  // ProductService.getProductDetails(). Kept optional so every existing
  // call site building a Product from a summary/list response keeps
  // working unchanged.
  final List<String> images;
  final String? unitOfMeasure;
  final double? weightKg;
  final String? specifications;
  final String? safetyCertifications;
  final String? storageRequirements;
  final String? categoryName;
  final double? minPrice;
  final double? maxPrice;
  final List<AvailableOutlet> availableAt;

  const Product({
    required this.id,
    required this.title,
    required this.price,
    required this.image,
    required this.vendorName,
    required this.rating,
    required this.availability,
    required this.isActive,
    required this.stock,
    required this.sales,
    required this.vendorLatitude,
    required this.vendorLongitude,
    this.brand,
    this.description,
    this.sizeSpecification,
    this.outletName,
    this.outletId,
    this.images = const <String>[],
    this.unitOfMeasure,
    this.weightKg,
    this.specifications,
    this.safetyCertifications,
    this.storageRequirements,
    this.categoryName,
    this.minPrice,
    this.maxPrice,
    this.availableAt = const <AvailableOutlet>[],
  });

  /// The full image list to show in a gallery. Falls back to the single
  /// `image` field when the backend response didn't include an `images`
  /// array (e.g. older cached data), so callers can always just use this
  /// instead of checking both fields.
  List<String> get galleryImages {
    final List<String> cleaned =
        images.where((String url) => url.trim().isNotEmpty).toList();
    if (cleaned.isNotEmpty) return cleaned;
    if (image.trim().isNotEmpty) return <String>[image];
    return const <String>[];
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    // `images` may arrive as a real JSON array (from getProductDetails /
    // searchProducts once updated) or not be present at all on older
    // summary shapes — handle both without throwing.
    List<String> parsedImages = <String>[];
    final dynamic rawImages = json['images'];
    if (rawImages is List) {
      parsedImages = rawImages
          .map((dynamic e) => e?.toString() ?? '')
          .where((String e) => e.isNotEmpty)
          .toList();
    }

    return Product(
      id: json['id']?.toString() ?? json['product_id']?.toString() ?? '',
      title: json['title'] as String? ?? json['product_name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ??
          (json['base_price'] as num?)?.toDouble() ??
          0.0,
      image: json['image'] as String? ?? '',
      vendorName: json['vendor_name'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      availability: json['availability'] as String? ?? 'Available',
      isActive: json['isActive'] as bool? ?? (json['is_active'] == 1) ?? true,
      stock: json['stock'] as int? ?? 0,
      sales: json['sales'] as int? ?? 0,
      vendorLatitude: (json['vendor_latitude'] as num?)?.toDouble() ?? 0.0,
      vendorLongitude: (json['vendor_longitude'] as num?)?.toDouble() ?? 0.0,
      brand: json['brand'] as String?,
      description: json['description'] as String?,
      sizeSpecification: json['size_specification'] as String?,
      outletName: json['outlet_name'] as String?,
      outletId: json['outlet_id'] as int?,
      images: parsedImages,
      unitOfMeasure: json['unit_of_measure'] as String?,
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      specifications: json['specifications']?.toString(),
      safetyCertifications: json['safety_certifications']?.toString(),
      storageRequirements: json['storage_requirements']?.toString(),
      categoryName: json['category'] is Map
          ? (json['category'] as Map)['category_name']?.toString()
          : json['category_name'] as String?,
      minPrice: (json['min_price'] as num?)?.toDouble(),
      maxPrice: (json['max_price'] as num?)?.toDouble(),
      availableAt: (json['available_at'] as List<dynamic>?)
              ?.map((dynamic e) =>
                  AvailableOutlet.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <AvailableOutlet>[],
    );
  }

  /// Merge full detail-endpoint data onto a Product we already had from a
  /// list/card (which may be missing the richer fields). Anything not
  /// present in [detail] keeps its existing value.
  Product mergedWithDetails(Product detail) {
    return Product(
      id: id.isNotEmpty ? id : detail.id,
      title: detail.title.isNotEmpty ? detail.title : title,
      price: detail.price != 0 ? detail.price : price,
      image: detail.image.isNotEmpty ? detail.image : image,
      vendorName: detail.vendorName.isNotEmpty ? detail.vendorName : vendorName,
      rating: detail.rating != 0 ? detail.rating : rating,
      availability: detail.availability,
      isActive: detail.isActive,
      stock: detail.stock != 0 ? detail.stock : stock,
      sales: sales,
      vendorLatitude: vendorLatitude,
      vendorLongitude: vendorLongitude,
      brand: detail.brand ?? brand,
      description: detail.description ?? description,
      sizeSpecification: detail.sizeSpecification ?? sizeSpecification,
      outletName: outletName ?? detail.outletName,
      outletId: outletId ?? detail.outletId,
      images: detail.galleryImages.isNotEmpty ? detail.galleryImages : images,
      unitOfMeasure: detail.unitOfMeasure ?? unitOfMeasure,
      weightKg: detail.weightKg ?? weightKg,
      specifications: detail.specifications ?? specifications,
      safetyCertifications: detail.safetyCertifications ?? safetyCertifications,
      storageRequirements: detail.storageRequirements ?? storageRequirements,
      categoryName: detail.categoryName ?? categoryName,
      minPrice: detail.minPrice ?? minPrice,
      maxPrice: detail.maxPrice ?? maxPrice,
      availableAt: detail.availableAt.isNotEmpty ? detail.availableAt : availableAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'price': price,
        'image': image,
        'vendor_name': vendorName,
        'rating': rating,
        'availability': availability,
        'is_active': isActive,
        'stock': stock,
        'sales': sales,
        'vendor_latitude': vendorLatitude,
        'vendor_longitude': vendorLongitude,
        'brand': brand,
        'description': description,
        'size_specification': sizeSpecification,
        'outlet_name': outletName,
        'outlet_id': outletId,
        'images': images,
        'unit_of_measure': unitOfMeasure,
        'weight_kg': weightKg,
        'specifications': specifications,
        'safety_certifications': safetyCertifications,
        'storage_requirements': storageRequirements,
        'category_name': categoryName,
        'min_price': minPrice,
        'max_price': maxPrice,
      };

  /// Best-effort decode of a specifications/safety-certifications TEXT
  /// column that the backend stores (and returns) as raw JSON but doesn't
  /// parse server-side. Returns null if it isn't valid JSON so callers can
  /// fall back to showing it as plain text.
  static dynamic tryDecodeJson(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  @override
  List<Object?> get props => [
        id,
        title,
        price,
        vendorName,
        rating,
        availability,
        stock,
      ];
}
