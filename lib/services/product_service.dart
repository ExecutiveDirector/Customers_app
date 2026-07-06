// // lib/services/product_service.dart

// import 'dart:convert';
// import 'dart:math' show pi, cos, sin, sqrt, asin;
// import 'dart:async';
// import 'package:http/http.dart' as http;
// import 'package:hive_flutter/hive_flutter.dart';
// import 'package:aquagas/models/product.dart';
// import 'package:aquagas/models/outlet_products.dart';
// import 'package:aquagas/models/cache_entry.dart';
// import 'package:aquagas/services/auth_service.dart';
// import 'package:aquagas/screens/models/filter_option.dart';

// class ProductService {
//   static const String _baseUrl =
//       'https://aquagas-backend.onrender.com/api/v1/products';
//   static const Duration cacheDuration = Duration(minutes: 30);
//   static const String _cacheBoxName = 'cacheBox';

//   final AuthService _authService = AuthService();

//   // ========================================================================
//   // Fetch nearby products grouped by vendor outlets + caching & expiry
//   // ========================================================================
//   Future<Map<String, Map<String, OutletProducts>>> fetchProductsByRadius({
//     required double userLat,
//     required double userLng,
//     required double radius,
//   }) async {
//     final String cacheKey = 'products_radius_${radius.toString()}';
//     final Box<CacheEntry> cacheBox = Hive.box<CacheEntry>(_cacheBoxName);

//     // 1️⃣ Try using valid cached data first
//     final CacheEntry? cached = cacheBox.get(cacheKey);
//     if (cached != null &&
//         DateTime.now().difference(cached.timestamp) < cacheDuration) {
//       try {
//         final result = _parseVendorOutletProductsFromBody(
//             cached.json, userLat, userLng, radius);
//         if (result.isNotEmpty) {
//           return result;
//         }
//       } catch (_) {}
//     }

//     // 2️⃣ Attempt live fetch from server
//     try {
//       final String? token = await _authService.getToken();
//       final Uri url = Uri.parse(
//           '$_baseUrl/nearby?lat=$userLat&lng=$userLng&radius=$radius');

//       final http.Response response = await http.get(
//         url,
//         headers: <String, String>{
//           'Content-Type': 'application/json',
//           if (token != null) 'Authorization': 'Bearer $token',
//         },
//       ).timeout(const Duration(seconds: 10));

//       if (response.statusCode == 200) {
//         // ✅ Save/refresh cache
//         await _saveToCache(cacheBox, cacheKey, response.body);
//         return _parseVendorOutletProductsFromBody(
//             response.body, userLat, userLng, radius);
//       } else {
//         // 3️⃣ Fallback to expired cache if available
//         if (cached != null) {
//           return _parseVendorOutletProductsFromBody(
//               cached.json, userLat, userLng, radius);
//         }
//         throw Exception('Failed with status ${response.statusCode}');
//       }
//     } on TimeoutException catch (_) {
//       // Fallback to cache
//       if (cached != null) {
//         return _parseVendorOutletProductsFromBody(
//             cached.json, userLat, userLng, radius);
//       }
//       rethrow;
//     } catch (e) {
//       // Network failure fallback
//       if (cached != null) {
//         return _parseVendorOutletProductsFromBody(
//             cached.json, userLat, userLng, radius);
//       }
//       throw Exception('Error fetching products: $e');
//     }
//   }

//   // ========================================================================
//   // Cache helpers
//   // ========================================================================
//   Future<void> _saveToCache(
//       Box<CacheEntry> box, String key, String json) async {
//     final entry = CacheEntry(key: key, json: json, timestamp: DateTime.now());
//     await box.put(key, entry);
//   }

//   Map<String, Map<String, OutletProducts>> _parseVendorOutletProductsFromBody(
//     String body,
//     double userLat,
//     double userLng,
//     double radius,
//   ) {
//     final Map<String, Map<String, OutletProducts>> vendorOutletProducts =
//         <String, Map<String, OutletProducts>>{};

//     final Map<String, dynamic> data =
//         jsonDecode(body) as Map<String, dynamic>? ?? <String, dynamic>{};
//     final List<dynamic> vendors =
//         data['vendors'] as List<dynamic>? ?? <dynamic>[];

//     for (final dynamic vendorRaw in vendors) {
//       final Map<String, dynamic> vendorData = vendorRaw as Map<String, dynamic>;
//       final String vendorName =
//           vendorData['name'] as String? ?? 'Unknown Vendor';
//       final int vendorId = vendorData['vendor_id'] as int? ?? 0;

//       final List<dynamic> outlets =
//           vendorData['outlets'] as List<dynamic>? ?? <dynamic>[];

//       vendorOutletProducts[vendorName] = <String, OutletProducts>{};

//       for (final dynamic outletRaw in outlets) {
//         final Map<String, dynamic> outlet = outletRaw as Map<String, dynamic>;

//         final int outletId = outlet['outlet_id'] as int? ?? 0;
//         final String outletName =
//             outlet['outlet_name'] as String? ?? 'Unknown Outlet';

//         final Map<String, dynamic> location =
//             outlet['location'] as Map<String, dynamic>? ?? <String, dynamic>{};
//         final double outletLat =
//             (location['latitude'] as num?)?.toDouble() ?? 0.0;
//         final double outletLng =
//             (location['longitude'] as num?)?.toDouble() ?? 0.0;

//         final double distance =
//             calculateHaversineDistance(userLat, userLng, outletLat, outletLng);
//         if (radius > 0 && distance > radius) continue;

//         final List<dynamic> products =
//             outlet['products'] as List<dynamic>? ?? <dynamic>[];
//         final List<Product> validProducts = <Product>[];

//         for (final dynamic productJson in products) {
//           final Map<String, dynamic> productData = <String, dynamic>{
//             ...productJson as Map<String, dynamic>,
//             'vendor_id': vendorId,
//             'vendor_name': vendorName,
//             'outlet_id': outletId,
//             'outlet_name': outletName,
//             'outlet_latitude': outletLat,
//             'outlet_longitude': outletLng,
//             'distance': distance,
//           };

//           final Product product = Product.fromJson(productData);
//           if (product.isActive && product.stock > 0) validProducts.add(product);
//         }

//         if (validProducts.isNotEmpty) {
//           vendorOutletProducts[vendorName]![outletId.toString()] =
//               OutletProducts(
//             outletId: outletId,
//             outletName: outletName,
//             vendorId: vendorId,
//             vendorName: vendorName,
//             distance: distance,
//             products: validProducts,
//           );
//         }
//       }

//       if (vendorOutletProducts[vendorName]!.isEmpty) {
//         vendorOutletProducts.remove(vendorName);
//       }
//     }

//     return vendorOutletProducts;
//   }

//   // ========================================================================
//   // Haversine formula
//   // ========================================================================
//   double calculateHaversineDistance(
//     double lat1,
//     double lon1,
//     double lat2,
//     double lon2,
//   ) {
//     const double earthRadiusKm = 6371.0;
//     final double lat1Rad = _toRadians(lat1);
//     final double lat2Rad = _toRadians(lat2);
//     final double dLat = _toRadians(lat2 - lat1);
//     final double dLon = _toRadians(lon2 - lon1);
//     final double a = sin(dLat / 2) * sin(dLat / 2) +
//         cos(lat1Rad) * cos(lat2Rad) * sin(dLon / 2) * sin(dLon / 2);
//     final double c = 2 * asin(sqrt(a));
//     return earthRadiusKm * c;
//   }

//   double _toRadians(double degrees) => degrees * pi / 180.0;

//   // ========================================================================
//   // Filtering & sorting (unchanged)
//   // ========================================================================
//   Map<String, Map<String, OutletProducts>> applyFilter(
//     Map<String, Map<String, OutletProducts>> vendorOutletProducts,
//     FilterOption filter,
//     double userLat,
//     double userLng,
//   ) {
//     final Map<String, Map<String, OutletProducts>> sortedVendorOutletProducts =
//         <String, Map<String, OutletProducts>>{};

//     for (final vendorEntry in vendorOutletProducts.entries) {
//       final Map<String, OutletProducts> outletMap = <String, OutletProducts>{};
//       final List<OutletProducts> sortedOutlets =
//           vendorEntry.value.values.toList();

//       if (filter == FilterOption.nearest) {
//         sortedOutlets.sort(
//             (a, b) => (a.distance ?? 99999).compareTo(b.distance ?? 99999));
//       }

//       for (final outlet in sortedOutlets) {
//         final List<Product> sortedProducts =
//             List<Product>.from(outlet.products);

//         switch (filter) {
//           case FilterOption.priceAsc:
//             sortedProducts.sort((a, b) => a.price.compareTo(b.price));
//             break;
//           case FilterOption.priceDesc:
//             sortedProducts.sort((a, b) => b.price.compareTo(a.price));
//             break;
//           case FilterOption.rating:
//             sortedProducts.sort((a, b) => b.rating.compareTo(a.rating));
//             break;
//           case FilterOption.availability:
//             sortedProducts.sort((a, b) {
//               final int aAvail = a.stock > 0 ? 1 : 0;
//               final int bAvail = b.stock > 0 ? 1 : 0;
//               return bAvail.compareTo(aAvail);
//             });
//             break;
//           default:
//             break;
//         }

//         outletMap[outlet.outletId.toString()] = OutletProducts(
//           outletId: outlet.outletId,
//           outletName: outlet.outletName,
//           vendorId: outlet.vendorId,
//           vendorName: outlet.vendorName,
//           distance: outlet.distance,
//           products: sortedProducts,
//         );
//       }

//       sortedVendorOutletProducts[vendorEntry.key] = outletMap;
//     }
//     return sortedVendorOutletProducts;
//   }
// }
// lib/services/product_service.dart

// ============================================================================
// Handles all product-related API calls and filtering logic
// ============================================================================

import 'dart:convert';
import 'dart:math' show pi, cos, sin, sqrt, asin;
import 'dart:io'; // for SocketException
import 'dart:async'; // For TimeoutException
import 'package:http/http.dart' as http;
import 'package:aquagas/models/product.dart';
import 'package:aquagas/models/outlet_products.dart';
import 'package:aquagas/models/category.dart';
import 'package:aquagas/services/auth_service.dart';
import 'package:aquagas/screens/models/filter_option.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class ProductService {
  static const String _baseUrl =
      'https://aquagas-backend.onrender.com/api/v1/products';

  final AuthService _authService = AuthService();

  // ==========================================================================
  // Fetch nearby products grouped by vendor outlets
  // ==========================================================================
  Future<Map<String, Map<String, OutletProducts>>> fetchProductsByRadius({
    required double userLat,
    required double userLng,
    required double radius,
  }) async {
    try {
      final String? token = await _authService.getToken();
      final Uri url = Uri.parse(
          '$_baseUrl/nearby?lat=$userLat&lng=$userLng&radius=$radius');

      debugPrint('🌍 Fetching from: $url');
      debugPrint(
          '⏱️ Waiting for server (may take up to 60s on first request)...');

      final http.Response response = await http.get(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 60), // Increased for Render cold start
        onTimeout: () {
          throw TimeoutException('Server is taking longer than expected. '
              'If this is the first request, the server may be starting up. '
              'Please try again in a moment.');
        },
      );

      debugPrint('📡 Response Status: ${response.statusCode}');

      if (response.statusCode != 200) {
        debugPrint('❌ Server error: ${response.body}');
        throw Exception(
            'Server returned status ${response.statusCode}: ${response.body}');
      }

      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic> vendors =
          data['vendors'] as List<dynamic>? ?? <dynamic>[];

      debugPrint('📦 Received ${vendors.length} vendors');

      final Map<String, Map<String, OutletProducts>> vendorOutletProducts =
          <String, Map<String, OutletProducts>>{};

      for (final dynamic vendorRaw in vendors) {
        final Map<String, dynamic> vendorData =
            vendorRaw as Map<String, dynamic>;
        final String vendorName =
            vendorData['name'] as String? ?? 'Unknown Vendor';
        final int vendorId = vendorData['vendor_id'] as int? ?? 0;

        final List<dynamic> outlets =
            vendorData['outlets'] as List<dynamic>? ?? <dynamic>[];

        // Initialize vendor map
        vendorOutletProducts[vendorName] = <String, OutletProducts>{};

        for (final dynamic outletRaw in outlets) {
          final Map<String, dynamic> outlet = outletRaw as Map<String, dynamic>;

          final int outletId = outlet['outlet_id'] as int? ?? 0;
          final String outletName =
              outlet['outlet_name'] as String? ?? 'Unknown Outlet';

          final Map<String, dynamic> location =
              outlet['location'] as Map<String, dynamic>? ??
                  <String, dynamic>{};
          final double outletLat =
              (location['latitude'] as num?)?.toDouble() ?? 0.0;
          final double outletLng =
              (location['longitude'] as num?)?.toDouble() ?? 0.0;

          // ✅ Calculate distance using correct Haversine
          final double distance = (outlet['distance_km'] as num?)?.toDouble() ??
              calculateHaversineDistance(
                  userLat, userLng, outletLat, outletLng);

          // ✅ Only add outlet if within selected radius
          if (distance > radius) {
            continue;
          }

          final List<dynamic> products =
              outlet['products'] as List<dynamic>? ?? <dynamic>[];
          final List<Product> validProducts = <Product>[];

          for (final dynamic productJson in products) {
            final Map<String, dynamic> productData = <String, dynamic>{
              ...productJson as Map<String, dynamic>,
              'vendor_id': vendorId,
              'vendor_name': vendorName,
              'outlet_id': outletId,
              'outlet_name': outletName,
              'outlet_latitude': outletLat,
              'outlet_longitude': outletLng,
              'distance': distance,
            };

            final Product product = Product.fromJson(productData);
            if (product.isActive && product.stock > 0) {
              validProducts.add(product);
            }
          }

          // ✅ Add outlet only if at least one product is valid
          if (validProducts.isNotEmpty) {
            vendorOutletProducts[vendorName]![outletId.toString()] =
                OutletProducts(
              outletId: outletId,
              outletName: outletName,
              vendorId: vendorId,
              vendorName: vendorName,
              distance: distance,
              products: validProducts,
            );
          }
        }

        // Remove vendor if no valid outlets
        if (vendorOutletProducts[vendorName]!.isEmpty) {
          vendorOutletProducts.remove(vendorName);
        }
      }

      debugPrint(
          '✅ Successfully loaded ${vendorOutletProducts.length} vendors');
      return vendorOutletProducts;
    } on TimeoutException catch (e) {
      debugPrint('⏱️ Timeout error: $e');
      throw Exception(
          'Connection timeout. The server might be starting up (can take 30-60 seconds). '
          'Please wait a moment and try again.');
    } on SocketException catch (e) {
      debugPrint('🌐 Network error: $e');
      throw Exception(
          'No internet connection. Please check your network and try again.');
    } on http.ClientException catch (e) {
      debugPrint('🔌 Client error: $e');
      throw Exception(
          'Cannot connect to server. The server might be starting up. '
          'Please wait a moment and try again.');
    } on FormatException catch (e) {
      debugPrint('📝 JSON parsing error: $e');
      throw Exception('Invalid response from server. Please try again.');
    } catch (e, stackTrace) {
      debugPrint('❌ Unexpected error: $e');
      debugPrint('Stack trace: $stackTrace');
      throw Exception('Error loading products: ${e.toString()}');
    }
  }

  // ==========================================================================
  // Correct Haversine formula for accurate distance calculation
  // ==========================================================================
  double calculateHaversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusKm = 6371.0;

    // Convert degrees to radians
    final double lat1Rad = _toRadians(lat1);
    final double lat2Rad = _toRadians(lat2);
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    // Haversine formula
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(dLon / 2) * sin(dLon / 2);

    final double c = 2 * asin(sqrt(a));

    return earthRadiusKm * c;
  }

  double _toRadians(double degrees) {
    return degrees * pi / 180.0;
  }

  // ==========================================================================
  // Apply sorting & filtering to outlet products
  // ==========================================================================
  Map<String, Map<String, OutletProducts>> applyFilter(
    Map<String, Map<String, OutletProducts>> vendorOutletProducts,
    FilterOption filter,
    double userLat,
    double userLng,
  ) {
    final Map<String, Map<String, OutletProducts>> sortedVendorOutletProducts =
        <String, Map<String, OutletProducts>>{};

    for (final MapEntry<String, Map<String, OutletProducts>> vendorEntry
        in vendorOutletProducts.entries) {
      final Map<String, OutletProducts> outletMap = <String, OutletProducts>{};

      // Sort outlets by distance first (for nearest filter)
      final List<OutletProducts> sortedOutlets =
          vendorEntry.value.values.toList();

      if (filter == FilterOption.nearest) {
        sortedOutlets.sort((OutletProducts a, OutletProducts b) {
          final double distA = a.distance ?? double.infinity;
          final double distB = b.distance ?? double.infinity;
          return distA.compareTo(distB);
        });
      }

      // Then sort products within each outlet
      for (final OutletProducts outlet in sortedOutlets) {
        final List<Product> sortedProducts =
            List<Product>.from(outlet.products);

        switch (filter) {
          case FilterOption.nearest:
            // Already sorted by outlet distance, keep product order
            break;

          case FilterOption.priceAsc:
            sortedProducts
                .sort((Product a, Product b) => a.price.compareTo(b.price));
            break;

          case FilterOption.priceDesc:
            sortedProducts
                .sort((Product a, Product b) => b.price.compareTo(a.price));
            break;

          case FilterOption.rating:
            sortedProducts
                .sort((Product a, Product b) => b.rating.compareTo(a.rating));
            break;

          case FilterOption.availability:
            sortedProducts.sort((Product a, Product b) {
              final int aAvailable = a.stock > 0 ? 1 : 0;
              final int bAvailable = b.stock > 0 ? 1 : 0;
              return bAvailable.compareTo(aAvailable);
            });
            break;
        }

        // Create new OutletProducts with sorted products
        outletMap[outlet.outletId.toString()] = OutletProducts(
          outletId: outlet.outletId,
          outletName: outlet.outletName,
          vendorId: outlet.vendorId,
          vendorName: outlet.vendorName,
          distance: outlet.distance,
          products: sortedProducts,
        );
      }

      sortedVendorOutletProducts[vendorEntry.key] = outletMap;
    }

    return sortedVendorOutletProducts;
  }

  // ==========================================================================
  // Fetch all available products (legacy support)
  // ==========================================================================
  Future<List<Product>> fetchAllProducts() async {
    try {
      final String? token = await _authService.getToken();
      final Uri url = Uri.parse(_baseUrl);

      debugPrint('🌍 Fetching all products: $url');

      final http.Response response = await http.get(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 60));

      debugPrint('📡 Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic> productsJson =
            data['products'] as List<dynamic>? ?? <dynamic>[];

        return productsJson
            .map((dynamic json) =>
                Product.fromJson(json as Map<String, dynamic>))
            .where((Product product) => product.isActive && product.stock > 0)
            .toList();
      } else {
        throw Exception('Failed to fetch products: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching all products: $e');
      throw Exception('Error fetching all products: $e');
    }
  }

  // ==========================================================================
  // Alias for easier product fetching
  // ==========================================================================
  Future<Map<String, Map<String, OutletProducts>>> fetchProducts(
    double userLat,
    double userLng,
    double radius,
  ) async {
    return await fetchProductsByRadius(
      userLat: userLat,
      userLng: userLng,
      radius: radius,
    );
  }

  // ==========================================================================
  // Full product detail (multi-image gallery, specs, availability by outlet)
  // GET /api/v1/products/:productId — see productController.getProductDetails
  // ==========================================================================
  Future<Product> getProductDetails(String productId) async {
    try {
      final String? token = await _authService.getToken();
      final Uri url = Uri.parse('$_baseUrl/$productId');

      final http.Response response = await http.get(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;
        return Product.fromJson(data);
      } else if (response.statusCode == 404) {
        throw Exception('This product is no longer available.');
      } else {
        throw Exception('Failed to load product (${response.statusCode}).');
      }
    } on TimeoutException {
      throw Exception('Connection timed out. Please try again.');
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } catch (e) {
      if (e is Exception && e.toString().startsWith('Exception: ')) rethrow;
      throw Exception('Error loading product details: ${e.toString()}');
    }
  }

  // ==========================================================================
  // Fetch/search products, optionally filtered by category (and/or a text
  // query). Backs the redesigned home-page category section — tapping a
  // category shows every product in it via GET /products/search?category=..
  // ==========================================================================
  Future<List<Product>> getProductsByCategory(String categoryId,
      {String query = ''}) async {
    try {
      final String? token = await _authService.getToken();
      final Uri url = Uri.parse('$_baseUrl/search').replace(
        queryParameters: <String, String>{
          'category': categoryId,
          if (query.isNotEmpty) 'q': query,
        },
      );

      final http.Response response = await http.get(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        return data
            .map((dynamic e) => Product.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw Exception('Failed to load products (${response.statusCode}).');
    } on TimeoutException {
      throw Exception('Connection timed out. Please try again.');
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } catch (e) {
      if (e is Exception && e.toString().startsWith('Exception: ')) rethrow;
      throw Exception('Error loading category products: ${e.toString()}');
    }
  }

  // ==========================================================================
  // Categories for the home-page category section.
  // GET /api/v1/products/categories — see productController.getCategories
  // ==========================================================================
  Future<List<Category>> getCategories() async {
    try {
      final String? token = await _authService.getToken();
      final Uri url = Uri.parse('$_baseUrl/categories');

      final http.Response response = await http.get(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        return data
            .map((dynamic e) => Category.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw Exception('Failed to load categories (${response.statusCode}).');
    } on TimeoutException {
      throw Exception('Connection timed out. Please try again.');
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } catch (e) {
      if (e is Exception && e.toString().startsWith('Exception: ')) rethrow;
      throw Exception('Error loading categories: ${e.toString()}');
    }
  }
}
