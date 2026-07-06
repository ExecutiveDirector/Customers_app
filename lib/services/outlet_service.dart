// lib/services/outlet_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:aquagas/services/auth_service.dart';

/// Service for fetching outlets and their products
class OutletService {
  static const String _baseUrl = 'https://aquagas-backend.onrender.com/api/v1';
  final AuthService _authService = AuthService();

  // =========================================================================
  // Get Nearby Outlets
  // =========================================================================

  /// Fetch outlets near user's location
  ///
  /// Returns list of outlets with distance information
  Future<List<Map<String, dynamic>>> getNearbyOutlets({
    required double latitude,
    required double longitude,
    double radiusKm = 50,
    int limit = 20,
  }) async {
    try {
      debugPrint(
          '📍 Fetching nearby outlets: lat=$latitude, lng=$longitude, radius=${radiusKm}km');

      final Map<String, String> queryParameters = {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'radius': radiusKm.toString(),
        'limit': limit.toString(),
      };

      final uri = Uri.parse('$_baseUrl/outlets/nearby').replace(
        queryParameters: queryParameters,
      );

      debugPrint('🌐 API URL: $uri');

      final response = await http.get(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Connection timeout. Please try again.');
        },
      );

      debugPrint('📥 Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic> outlets =
            (data['outlets'] ?? <dynamic>[]) as List<dynamic>;

        debugPrint('✅ Found ${outlets.length} nearby outlets');

        return outlets
            .map((dynamic outlet) => outlet as Map<String, dynamic>)
            .toList();
      } else {
        final Map<String, dynamic> error =
            jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(error['error'] ?? 'Failed to fetch nearby outlets');
      }
    } catch (e) {
      debugPrint('❌ Error fetching nearby outlets: $e');
      rethrow;
    }
  }

  // =========================================================================
  // Get Outlet with Products
  // =========================================================================

  /// Fetch outlet details including all products
  ///
  /// Returns outlet info and product list
  Future<Map<String, dynamic>> getOutletWithProducts(
    String outletId, {
    String? category,
    String? search,
    bool inStockOnly = true,
  }) async {
    try {
      debugPrint('📦 Fetching outlet $outletId with products');

      final Map<String, String> queryParams = <String, String>{
        'in_stock': inStockOnly.toString(),
      };

      if (category != null) {
        queryParams['category'] = category;
      }

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final uri = Uri.parse('$_baseUrl/outlets/$outletId/products')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Connection timeout. Please try again.');
        },
      );

      debugPrint('📥 Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('✅ Outlet loaded with ${data['product_count']} products');
        return data;
      } else if (response.statusCode == 404) {
        throw Exception('Outlet not found');
      } else {
        final Map<String, dynamic> error =
            jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(error['error'] ?? 'Failed to fetch outlet products');
      }
    } catch (e) {
      debugPrint('❌ Error fetching outlet products: $e');
      rethrow;
    }
  }

  // =========================================================================
  // Get Outlet Details
  // =========================================================================

  /// Fetch basic outlet information
  Future<Map<String, dynamic>> getOutletById(String outletId) async {
    try {
      debugPrint('📍 Fetching outlet details: $outletId');

      final response = await http.get(
        Uri.parse('$_baseUrl/outlets/$outletId'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Connection timeout. Please try again.');
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('✅ Outlet details loaded');
        return (data['outlet'] ?? data) as Map<String, dynamic>;
      } else if (response.statusCode == 404) {
        throw Exception('Outlet not found');
      } else {
        final Map<String, dynamic> error =
            jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(error['error'] ?? 'Failed to fetch outlet details');
      }
    } catch (e) {
      debugPrint('❌ Error fetching outlet details: $e');
      rethrow;
    }
  }

  // =========================================================================
  // Get All Outlets
  // =========================================================================

  /// Fetch all outlets with pagination and search
  Future<Map<String, dynamic>> getAllOutlets({
    int page = 1,
    int limit = 20,
    String? search,
    bool? isActive,
  }) async {
    try {
      debugPrint('📋 Fetching all outlets (page $page)');

      final Map<String, String> queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      if (isActive != null) {
        queryParams['is_active'] = isActive.toString();
      }

      final uri =
          Uri.parse('$_baseUrl/outlets').replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Connection timeout. Please try again.');
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('✅ Loaded ${data['outlets']?.length ?? 0} outlets');
        return data;
      } else {
        final Map<String, dynamic> error =
            jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(error['error'] ?? 'Failed to fetch outlets');
      }
    } catch (e) {
      debugPrint('❌ Error fetching outlets: $e');
      rethrow;
    }
  }

  // =========================================================================
  // Vendor-specific Methods (require authentication)
  // =========================================================================

  /// Get outlets for authenticated vendor
  Future<List<Map<String, dynamic>>> getVendorOutlets({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final String? token = await _authService.getToken();
      if (token == null) throw Exception('Not authenticated');

      debugPrint('🏪 Fetching vendor outlets');

      final Map<String, String> queryParameters = {
        'page': page.toString(),
        'limit': limit.toString(),
      };

      final uri = Uri.parse('$_baseUrl/outlets/vendor/my-outlets')
          .replace(queryParameters: queryParameters);

      final response = await http.get(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Connection timeout. Please try again.');
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic> outlets =
            (data['outlets'] ?? <dynamic>[]) as List<dynamic>;
        debugPrint('✅ Loaded ${outlets.length} vendor outlets');
        return outlets
            .map((dynamic outlet) => outlet as Map<String, dynamic>)
            .toList();
      } else {
        final Map<String, dynamic> error =
            jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(error['error'] ?? 'Failed to fetch vendor outlets');
      }
    } catch (e) {
      debugPrint('❌ Error fetching vendor outlets: $e');
      rethrow;
    }
  }

  /// Create new outlet (vendor only)
  Future<Map<String, dynamic>> createOutlet({
    required String outletName,
    required String outletCode,
    required double latitude,
    required double longitude,
    required String addressLine1,
    required String city,
    required String county,
    String? addressLine2,
    String? postalCode,
    String? phone,
    String? email,
    String? openingTime,
    String? closingTime,
  }) async {
    try {
      final String? token = await _authService.getToken();
      if (token == null) throw Exception('Not authenticated');

      debugPrint('➕ Creating new outlet: $outletName');

      final Map<String, dynamic> body = <String, dynamic>{
        'outlet_name': outletName,
        'outlet_code': outletCode,
        'latitude': latitude,
        'longitude': longitude,
        'address_line_1': addressLine1,
        'city': city,
        'county': county,
        if (addressLine2 != null) 'address_line_2': addressLine2,
        if (postalCode != null) 'postal_code': postalCode,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        if (openingTime != null) 'opening_time': openingTime,
        if (closingTime != null) 'closing_time': closingTime,
      };

      final response = await http
          .post(
        Uri.parse('$_baseUrl/outlets'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      )
          .timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Connection timeout. Please try again.');
        },
      );

      if (response.statusCode == 201) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('✅ Outlet created successfully');
        return data;
      } else {
        final Map<String, dynamic> error =
            jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(error['error'] ?? 'Failed to create outlet');
      }
    } catch (e) {
      debugPrint('❌ Error creating outlet: $e');
      rethrow;
    }
  }

  /// Update existing outlet (vendor only)
  Future<void> updateOutlet(
    String outletId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final String? token = await _authService.getToken();
      if (token == null) throw Exception('Not authenticated');

      debugPrint('✏️ Updating outlet: $outletId');

      final response = await http
          .put(
        Uri.parse('$_baseUrl/outlets/$outletId'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(updates),
      )
          .timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Connection timeout. Please try again.');
        },
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Outlet updated successfully');
      } else {
        final Map<String, dynamic> error =
            jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(error['error'] ?? 'Failed to update outlet');
      }
    } catch (e) {
      debugPrint('❌ Error updating outlet: $e');
      rethrow;
    }
  }
}
