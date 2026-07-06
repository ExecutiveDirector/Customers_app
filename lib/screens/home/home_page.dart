// ============================================================================
// lib/screens/home/home_page.dart - OUTLET-BASED VERSION (FIXED)
// ============================================================================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:aquagas/cart.dart';
import 'package:aquagas/models/product.dart';
import 'package:aquagas/models/outlet_products.dart';
import 'package:aquagas/app.dart';
import 'package:aquagas/screens/home/widgets/home_header.dart';
import 'package:aquagas/screens/home/widgets/promo_banner.dart';
import 'package:aquagas/screens/home/widgets/filter_bar.dart';
import 'package:aquagas/screens/home/widgets/category_section.dart';
import 'package:aquagas/screens/home/widgets/vendor_products_section.dart';
import 'package:aquagas/services/product_service.dart';
import 'package:aquagas/services/auth_service.dart';
import 'package:aquagas/services/notification_service.dart';
import 'package:aquagas/services/push_notification_manager.dart';
import 'package:aquagas/screens/models/filter_option.dart';
import 'package:aquagas/widgets/drawer.dart';

class HomePage extends StatefulWidget {
  final double userLat;
  final double userLng;

  const HomePage({super.key, required this.userLat, required this.userLng});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _authService = AuthService();
  final ProductService _productService = ProductService();
  final NotificationService _notificationService = NotificationService();

  String? _userName;
  String? _avatarUrl;
  int _unreadNotifications = 0;

  // Store outlets directly, not grouped by vendor
  List<OutletProducts> _nearbyOutlets = [];

  String? _errorMessage;
  bool _isLoading = true;
  FilterOption _selectedFilter = FilterOption.nearest;
  double _radius = 20.0;
  StreamSubscription<Position>? _positionStream;
  double _currentLat = 0.0;
  double _currentLng = 0.0;

  bool _isGuest = false;

  @override
  void initState() {
    super.initState();
    _currentLat = widget.userLat;
    _currentLng = widget.userLng;
    _initialize();
  }

  Future<void> _initialize() async {
    await _checkAuthentication();
    await _fetchProducts(_currentLat, _currentLng);
    _startLocationUpdates();
  }

  Future<void> _checkAuthentication() async {
    try {
      final bool isAuth = await _authService.isAuthenticated();

      if (!isAuth) {
        setState(() {
          _isGuest = true;
          _userName = 'Guest';
        });
        debugPrint('🟡 Guest mode enabled - browsing without authentication');
      } else {
        setState(() {
          _isGuest = false;
        });
        await _fetchUserProfile();
        _fetchUnreadCount();
        PushNotificationManager.instance.initialize();
      }
    } catch (e) {
      debugPrint('❌ Authentication error: $e');
      setState(() {
        _isGuest = true;
        _userName = 'Guest';
      });
    }
  }

  Future<void> _fetchUserProfile() async {
    try {
      final Map<String, dynamic>? userData =
          await _authService.getCurrentUser();

      if (userData != null && mounted) {
        // getCurrentUser() can return either a flat map or one nested as
        // { account: {...}, profile: {...} } (that's the shape
        // AuthService.uploadAvatar() writes avatar_url into) — flatten
        // before reading either field so both shapes work.
        final Map<String, dynamic> flat = <String, dynamic>{...userData};
        for (final String key in <String>['account', 'profile', 'user']) {
          final Object? nested = userData[key];
          if (nested is Map) flat.addAll(nested.cast<String, dynamic>());
        }

        setState(() {
          _userName = flat['first_name'] as String? ??
              flat['fullName'] as String? ??
              flat['name'] as String? ??
              'User';
          // The backend returns avatar_url as a relative path
          // (/uploads/avatars/xyz.jpg) — resolveMediaUrl turns that into
          // an absolute URL Image.network can actually load. Without this
          // the header just silently fails to load the picture.
          _avatarUrl =
              AuthService.resolveMediaUrl(flat['avatar_url'] as String?);
        });
        debugPrint('✅ User profile loaded: $_userName');
      }
    } catch (e) {
      debugPrint('❌ Error fetching user profile: $e');
      setState(() {
        _userName = 'Guest';
        _isGuest = true;
      });
    }
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final int count = await _notificationService.getUnreadCount();
      if (mounted) setState(() => _unreadNotifications = count);
    } catch (_) {
      // Non-critical — the bell icon just won't show a badge this load.
    }
  }

  // ============================================================================
  //  Fetch and flatten outlets from all vendors
  // ============================================================================
  Future<void> _fetchProducts(double userLat, double userLng) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Step 1: Try fetch within radius
      Map<String, Map<String, OutletProducts>> vendorProducts =
          await _productService.fetchProducts(userLat, userLng, _radius);

      // ✅ Step 2: If no products found, fallback to fetch ALL without radius filter
      if (vendorProducts.isEmpty) {
        debugPrint('⚠ No outlets within $_radius km. Fetching all products...');
        vendorProducts = await _productService.fetchProducts(
            userLat, userLng, 0); // 0 = no radius

        if (vendorProducts.isEmpty) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'No products available at the moment.';
          });
          return;
        }
      }

      // ✅ Flatten outlets
      final List<OutletProducts> allOutlets = [];
      for (final vendorEntry in vendorProducts.entries) {
        for (final outletEntry in vendorEntry.value.entries) {
          allOutlets.add(outletEntry.value);
        }
      }

      setState(() {
        _nearbyOutlets = allOutlets;
        _applyFilter();
        _isLoading = false;
      });

      debugPrint('✅ Loaded ${allOutlets.length} outlets.');
    } catch (e) {
      debugPrint('❌ Error fetching products: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading products. Please try again.';
      });

      if (mounted) {
        _showSnack('Unable to load products');
      }
    }
  }

  void _startLocationUpdates() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 100,
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        if (mounted) {
          _currentLat = position.latitude;
          _currentLng = position.longitude;
          _fetchProducts(_currentLat, _currentLng);
        }
      },
      onError: (Object error) {
        debugPrint('❌ Location update error: $error');
        if (mounted) {
          _showSnack('Location update failed');
        }
      },
    );
  }

  // ============================================================================
  // ✅  Apply filter directly to outlets list
  // ============================================================================
  void _applyFilter() {
    final List<OutletProducts> sortedOutlets = List.from(_nearbyOutlets);

    switch (_selectedFilter) {
      case FilterOption.nearest:
        sortedOutlets.sort((a, b) {
          final distA = a.distance ?? double.infinity;
          final distB = b.distance ?? double.infinity;
          return distA.compareTo(distB);
        });
        break;

      case FilterOption.priceAsc:
        sortedOutlets.sort((a, b) {
          final minPriceA = a.products.isEmpty
              ? double.infinity
              : a.products.map((p) => p.price).reduce((a, b) => a < b ? a : b);
          final minPriceB = b.products.isEmpty
              ? double.infinity
              : b.products.map((p) => p.price).reduce((a, b) => a < b ? a : b);
          return minPriceA.compareTo(minPriceB);
        });
        break;

      case FilterOption.priceDesc:
        sortedOutlets.sort((a, b) {
          final maxPriceA = a.products.isEmpty
              ? 0.0
              : a.products.map((p) => p.price).reduce((a, b) => a > b ? a : b);
          final maxPriceB = b.products.isEmpty
              ? 0.0
              : b.products.map((p) => p.price).reduce((a, b) => a > b ? a : b);
          return maxPriceB.compareTo(maxPriceA);
        });
        break;

      case FilterOption.rating:
        sortedOutlets.sort((a, b) {
          final avgRatingA = a.products.isEmpty
              ? 0.0
              : a.products.map((p) => p.rating).reduce((a, b) => a + b) /
                  a.products.length;
          final avgRatingB = b.products.isEmpty
              ? 0.0
              : b.products.map((p) => p.rating).reduce((a, b) => a + b) /
                  b.products.length;
          return avgRatingB.compareTo(avgRatingA);
        });
        break;

      case FilterOption.availability:
        sortedOutlets.sort((a, b) {
          final availableA = a.products.where((p) => p.stock > 0).length;
          final availableB = b.products.where((p) => p.stock > 0).length;
          return availableB.compareTo(availableA);
        });
        break;
    }

    setState(() {
      _nearbyOutlets = sortedOutlets;
    });
  }

  // ============================================================================
  // ✅ Add to Cart with proper validation
  // ============================================================================
  Future<void> _handleAddToCart(Product product) async {
    try {
      if (product.id.isEmpty) {
        throw CartException('Product ID is missing');
      }

      if (product.title.isEmpty) {
        throw CartException('Product title is missing');
      }

      if (product.price <= 0) {
        throw CartException('Product price is invalid');
      }

      final String outletId = _getOutletId(product);

      if (outletId.isEmpty) {
        throw CartException('Outlet information is missing for this product');
      }

      debugPrint('─────────────────────────────────');
      debugPrint('📦 Adding to cart: ${product.title}');
      debugPrint('   Product ID: ${product.id}');
      debugPrint('   Outlet ID: $outletId');
      debugPrint('   Outlet: ${product.outletName ?? "Unknown"}');
      debugPrint('   Vendor: ${product.vendorName}');
      debugPrint('   Price: KSh ${product.price}');
      debugPrint('─────────────────────────────────');

      final Map<String, dynamic> cartItem = <String, dynamic>{
        'id': product.id,
        'product_id': product.id,
        'outlet_id': outletId,
        'outletId': outletId,
        'title': product.title,
        'price': product.price,
        'image': product.image,
        'vendorName': product.vendorName,
        'outletName': product.outletName ?? 'Unknown Outlet',
        'description': product.description ?? '',
        'brand': product.brand ?? '',
        'sizeSpecification': product.sizeSpecification ?? '',
        'stock': product.stock,
        'quantity': 1,
      };

      cart.addItem(cartItem);

      if (mounted) {
        _showSnack('${product.title} added to cart', isSuccess: true);
      }

      debugPrint(
          '🛒 Cart: ${cart.itemCount} items | Total: KSh ${cart.totalAmount.toStringAsFixed(2)}');
    } on CartException catch (e) {
      debugPrint('❌ Cart error: ${e.message}');
      if (mounted) {
        _showSnack(e.message);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Unexpected error adding to cart: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        _showSnack('Failed to add item to cart. Please try again.');
      }
    }
  }

  String _getOutletId(Product product) {
    if (product.outletId != null) {
      final String outletIdStr = product.outletId.toString();
      debugPrint('✅ Using product.outletId: $outletIdStr');
      return outletIdStr;
    }

    if (product.vendorName.isNotEmpty) {
      final int vendorHash = product.vendorName.hashCode.abs();
      final String fallbackId = 'vendor_$vendorHash';
      debugPrint('⚠️ Generated fallback outlet_id from vendor: $fallbackId');
      return fallbackId;
    }

    if (product.id.isNotEmpty) {
      final String fallbackId = 'product_${product.id}';
      debugPrint('⚠️ Using product_id as outlet fallback: $fallbackId');
      return fallbackId;
    }

    debugPrint('❌ WARNING: No outlet_id found for product ${product.id}');
    return '';
  }

  void _showSnack(String message, {bool isSuccess = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: <Widget>[
            Icon(
              isSuccess ? Icons.check_circle : Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isSuccess ? Colors.green[700] : Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
        duration: Duration(seconds: isSuccess ? 2 : 3),
        action: !isSuccess
            ? SnackBarAction(
                label: 'Dismiss',
                textColor: Colors.white,
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              )
            : null,
      ),
    );
  }

  Future<void> _handleLogout() async {
    try {
      await _authService.signOut();

      if (mounted) {
        _showSnack('Logged out successfully', isSuccess: true);
        setState(() {
          _isGuest = true;
          _userName = 'Guest';
        });
      }
    } catch (e) {
      debugPrint('❌ Logout error: $e');
      if (mounted) {
        _showSnack('Logout failed. Please try again.');
      }
    }
  }

  void _handleLogin() {
    if (mounted) {
      Navigator.pushNamed(context, Routes.signIn);
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  // ============================================================================
  // Build Methods
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    final NumberFormat currencyFormatter = NumberFormat.currency(
      locale: 'en_KE',
      symbol: 'KSh ',
      decimalDigits: 2,
    );

    return Scaffold(
      drawer: const AppDrawer(),
      body: Column(
        children: [
          Builder(
            builder: (context) => HomeHeader(
              userName: _userName,
              avatarUrl: _avatarUrl,
              notificationCount: _unreadNotifications,
              onMenuTap: () {
                Scaffold.of(context).openDrawer();
              },
              onSearch: (query) {
                // Handle search
              },
              onNotificationsTap: () {
                Navigator.pushNamed(context, Routes.notifications)
                    .then((_) => _fetchUnreadCount());
              },
              onProfileTap: () {
                // Home page stays underneath in the nav stack while
                // Profile is pushed, so its own state (including this
                // avatar) never sees a picture update made there unless
                // we explicitly refresh after coming back.
                Navigator.pushNamed(context, Routes.profile)
                    .then((_) => _fetchUserProfile());
              },
            ),
          ),
          Expanded(
            child: _buildBody(currencyFormatter),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: cart.itemCount > 0
                ? Badge(
                    label: Text('${cart.itemCount}'),
                    child: const Icon(Icons.shopping_cart),
                  )
                : const Icon(Icons.shopping_cart),
            label: 'Cart',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
        ],
        currentIndex: 0,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        onTap: (int index) {
          if (index == 1 && mounted) {
            Navigator.pushNamed(context, Routes.cart);
          } else if (index == 2 && mounted) {
            Navigator.pushNamed(context, Routes.orderHistory);
          }
        },
      ),
    );
  }

  // ============================================================================
  // ✅ FIXED: Display outlets directly, not grouped by vendor
  // ============================================================================
  Widget _buildBody(NumberFormat currencyFormatter) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.green),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red.shade300,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _fetchProducts(_currentLat, _currentLng),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text(
                  'Retry',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchProducts(_currentLat, _currentLng),
      color: Colors.green,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const PromoBanner(),

            FilterAndRadiusBar(
              selectedFilter: _selectedFilter,
              onFilterChanged: (FilterOption filter) {
                setState(() {
                  _selectedFilter = filter;
                  _applyFilter();
                });
              },
              radius: _radius,
              onRadiusChanged: (double value) {
                setState(() {
                  _radius = value;
                });
                _fetchProducts(_currentLat, _currentLng);
              },
            ),

            const CategorySection(),

            // ✅ Display outlets directly (each outlet is independent)
            if (_nearbyOutlets.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: <Widget>[
                      Icon(
                        Icons.shopping_bag_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No outlets available nearby',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Try increasing the search radius',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._nearbyOutlets.map((OutletProducts outlet) {
                return VendorProductsSection(
                  vendorName: outlet.vendorName,
                  outletName: outlet.outletName,
                  outletId: outlet.outletId,
                  distance: outlet.distance,
                  products: outlet.products,
                  onProductAdded: _handleAddToCart,
                );
              }).toList(),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// CartException Class
// ============================================================================
class CartException implements Exception {
  final String message;
  CartException(this.message);
}
