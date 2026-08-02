// ============================================================================
// lib/screens/home/home_page.dart - OUTLET-BASED VERSION
// ============================================================================
//
// Home page composition update for the new design system. Public API and
// data flow are unchanged (HomePage is still constructed with
// (userLat, userLng), still consumes the same ProductService + cart, and
// still routes to the same destinations). The composition is updated:
//
//   Header (location + greeting + search + bell)
//   PromoBanner              (3 on-brand teal promos)
//   QuickActionsRow          (Track / Orders / Help / Reorder)
//   CategorySection          (real categories + See all)
//   FeaturedProducts         (top-rated carousel — no extra API call)
//   FilterAndRadiusBar       (compact chip row)
//   Outlets near you         (one section per outlet, modern cards)
//
// Empty / loading / error states all redesigned with the new system
// (friendly illustration, brand teal, single primary action).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'package:aquagas/cart.dart';
import 'package:aquagas/models/product.dart';
import 'package:aquagas/models/outlet_products.dart';
import 'package:aquagas/app.dart';
import 'package:aquagas/screens/home/widgets/home_header.dart';
import 'package:aquagas/screens/home/widgets/promo_banner.dart';
import 'package:aquagas/screens/home/widgets/filter_bar.dart';
import 'package:aquagas/screens/home/widgets/category_section.dart';
import 'package:aquagas/screens/home/widgets/vendor_products_section.dart';
import 'package:aquagas/screens/home/widgets/quick_actions.dart';
import 'package:aquagas/screens/home/widgets/featured_products.dart';
import 'package:aquagas/services/product_service.dart';
import 'package:aquagas/services/auth_service.dart';
import 'package:aquagas/services/notification_service.dart';
import 'package:aquagas/services/push_notification_manager.dart';
import 'package:aquagas/screens/models/filter_option.dart';
import 'package:aquagas/theme/app_colors.dart';
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
  String? _locationLabel;
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
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentLat = widget.userLat;
    _currentLng = widget.userLng;
    _initialize();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _searchController.dispose();
    super.dispose();
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
          _avatarUrl =
              AuthService.resolveMediaUrl(flat['avatar_url'] as String?);
          _locationLabel = flat['address'] as String? ??
              flat['location'] as String? ??
              flat['city'] as String?;
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
  //  Apply filter directly to outlets list
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
  // Add to Cart with proper validation
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
        backgroundColor: isSuccess ? AppColors.success : AppColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        margin: const EdgeInsets.all(AppSpacing.md),
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

  // ============================================================================
  // Build Methods
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      backgroundColor: AppColors.background,
      body: Column(
        children: <Widget>[
          Builder(
            builder: (context) => HomeHeader(
              userName: _userName,
              avatarUrl: _avatarUrl,
              locationLabel: _locationLabel,
              notificationCount: _unreadNotifications,
              onMenuTap: () => Scaffold.of(context).openDrawer(),
              onNotificationsTap: () {
                Navigator.pushNamed(context, Routes.notifications)
                    .then((_) => _fetchUnreadCount());
              },
              onLocationTap: () {
                Navigator.pushNamed(context, Routes.changeLocation)
                    .then((_) => _fetchUserProfile());
              },
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: AppColors.cardShadow,
      ),
      child: SafeArea(
        top: false,
        child: BottomNavigationBar(
          backgroundColor: Colors.white,
          items: <BottomNavigationBarItem>[
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: cart.itemCount > 0
                  ? Badge(
                      label: Text('${cart.itemCount}'),
                      backgroundColor: AppColors.danger,
                      child: const Icon(Icons.shopping_cart_outlined),
                    )
                  : const Icon(Icons.shopping_cart_outlined),
              activeIcon: cart.itemCount > 0
                  ? Badge(
                      label: Text('${cart.itemCount}'),
                      backgroundColor: AppColors.danger,
                      child: const Icon(Icons.shopping_cart_rounded),
                    )
                  : const Icon(Icons.shopping_cart_rounded),
              label: 'Cart',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long_rounded),
              label: 'Orders',
            ),
          ],
          currentIndex: 0,
          selectedItemColor: AppColors.brandDark,
          unselectedItemColor: AppColors.slate500,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 11.5,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 11.5,
          ),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          onTap: (int index) {
            if (index == 1 && mounted) {
              Navigator.pushNamed(context, Routes.cart);
            } else if (index == 2 && mounted) {
              Navigator.pushNamed(context, Routes.orderHistory);
            }
          },
        ),
      ),
    );
  }

  // ============================================================================
  // Body states
  // ============================================================================
  Widget _buildBody() {
    if (_isLoading) return const _LoadingBody();
    if (_errorMessage != null) {
      return _ErrorBody(
        message: _errorMessage!,
        onRetry: () => _fetchProducts(_currentLat, _currentLng),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchProducts(_currentLat, _currentLng),
      color: AppColors.brand,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const PromoBanner(),
            QuickActionsRow(actions: _buildQuickActions()),
            const CategorySection(),
            if (_nearbyOutlets.isNotEmpty)
              FeaturedProducts(
                outlets: _nearbyOutlets,
                onAddToCart: _handleAddToCart,
              ),
            const SizedBox(height: AppSpacing.xs),
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
                setState(() => _radius = value);
                _fetchProducts(_currentLat, _currentLng);
              },
            ),
            const SizedBox(height: AppSpacing.xs),
            _OutletsHeader(count: _nearbyOutlets.length),
            if (_nearbyOutlets.isEmpty)
              const _EmptyOutletsBody()
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
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  List<QuickAction> _buildQuickActions() {
    return <QuickAction>[
      QuickAction(
        label: 'Track',
        icon: Icons.local_shipping_rounded,
        tint: AppColors.green50,
        accent: AppColors.green600,
        onTap: () {
          // No active order id known up front — push the order history
          // page where the user can pick one. (route remains stable)
          Navigator.pushNamed(context, Routes.orderHistory);
        },
      ),
      QuickAction(
        label: 'Orders',
        icon: Icons.receipt_long_rounded,
        tint: const Color(0xFFEFF6FF),
        accent: AppColors.info,
        onTap: () => Navigator.pushNamed(context, Routes.orderHistory),
      ),
      QuickAction(
        label: 'Help',
        icon: Icons.support_agent_rounded,
        tint: const Color(0xFFFEF3C7),
        accent: AppColors.warning,
        onTap: () => Navigator.pushNamed(context, Routes.helpSupport),
      ),
      QuickAction(
        label: 'Account',
        icon: Icons.person_rounded,
        tint: const Color(0xFFF5F3FF),
        accent: const Color(0xFF7C3AED),
        onTap: () {
          if (_isGuest) {
            _handleLogin();
          } else {
            Navigator.pushNamed(context, Routes.profile)
                .then((_) => _fetchUserProfile());
          }
        },
      ),
    ];
  }
}

// ============================================================================
// CartException Class
// ============================================================================
class CartException implements Exception {
  final String message;
  CartException(this.message);
}

// ============================================================================
// Body states (private to the file)
// ============================================================================
class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      physics: const AlwaysScrollableScrollPhysics(),
      children: const <Widget>[
        _Skeleton(height: 150, margin: AppSpacing.md),
        SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            SizedBox(width: AppSpacing.md),
            _Skeleton(width: 80, height: 80),
            SizedBox(width: AppSpacing.xs),
            _Skeleton(width: 80, height: 80),
            SizedBox(width: AppSpacing.xs),
            _Skeleton(width: 80, height: 80),
            SizedBox(width: AppSpacing.xs),
            _Skeleton(width: 80, height: 80),
          ],
        ),
        SizedBox(height: AppSpacing.md),
        _Skeleton(height: 100, margin: AppSpacing.md),
        SizedBox(height: AppSpacing.md),
        _Skeleton(height: 200, margin: AppSpacing.md),
      ],
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({
    this.width = double.infinity,
    required this.height,
    this.margin = 0,
  });
  final double width;
  final double height;
  final double margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: EdgeInsets.symmetric(horizontal: margin),
      decoration: BoxDecoration(
        color: AppColors.slate100,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.dangerSoft,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                color: AppColors.danger,
                size: 40,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'We couldn\'t reach the store',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.slate900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: const TextStyle(
                color: AppColors.slate500,
                fontSize: 14,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text(
                'Try again',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyOutletsBody extends StatelessWidget {
  const _EmptyOutletsBody();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: <Widget>[
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.brandLight,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: const Icon(
                Icons.storefront_rounded,
                color: AppColors.brandDark,
                size: 40,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'No outlets nearby',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.slate900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'Try widening your search radius from the filter bar — or '
              'browse by category above.',
              style: TextStyle(
                color: AppColors.slate500,
                fontSize: 14,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _OutletsHeader extends StatelessWidget {
  const _OutletsHeader({required this.count});
  final int count;

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
        children: <Widget>[
          const Text(
            'Outlets near you',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.slate900,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.slate100,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.slate600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
