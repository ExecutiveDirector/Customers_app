// lib/widgets/drawer.dart
//
// Production customer drawer for AquaGas delivery app.
// • Uses AuthService (FlutterSecureStorage) — matches auth_service.dart
// • Uses Routes constants from app.dart
// • Stats: total orders + active orders from OrderService.getUserOrders()
// • User data: first_name, last_name, email, referral_code from getCurrentUser()
// • Logout: calls authService.signOut() then navigates to Routes.signIn
// • All withOpacity() replaced with withValues(alpha:) — no deprecation warnings
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:aquagas/app.dart';
import 'package:aquagas/services/auth_service.dart';
import 'package:aquagas/services/push_notification_manager.dart';
import 'package:aquagas/services/order_service.dart';
import 'package:aquagas/src/ui/premium_settings_page.dart';

// ─── Palette ─────────────────────────────────────────────────────────────────
const Color _kGreen900 = Color(0xFF064E3B);
const Color _kGreen700 = Color(0xFF065F46);
const Color _kGreen500 = Color(0xFF10B981);
const Color _kSlate800 = Color(0xFF1E293B);
const Color _kSlate500 = Color(0xFF64748B);
const Color _kSlate200 = Color(0xFFE2E8F0);
const Color _kBg = Color(0xFFF8FAFC);

// ─────────────────────────────────────────────────────────────────────────────
//  AppDrawer
// ─────────────────────────────────────────────────────────────────────────────
class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  final AuthService _authService = AuthService();
  final OrderService _orderService = OrderService();

  // Profile state
  String _displayName = '';
  String _email = '';
  String _initials = '';
  String? _referralCode;
  String? _avatarUrl;
  bool _profileLoaded = false;

  // Stats state
  int _totalOrders = 0;
  int _activeOrders = 0;
  String? _activeOrderId;
  bool _statsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadStats();
  }

  // ── Loaders ───────────────────────────────────────────────────────────────

  Future<void> _loadProfile() async {
    try {
      final Map<String, dynamic>? user = await _authService.getCurrentUser();
      if (!mounted) return;

      // Backend stores full profile data; navigate the nested structure.
      // getCurrentUser() returns the raw JSON stored at login time.
      // Structure may be { account:{...}, profile:{...} } or flat.
      final Map<String, dynamic> flat = _flattenUser(user ?? {});

      final String firstName = flat['first_name']?.toString() ?? '';
      final String lastName = flat['last_name']?.toString() ?? '';
      final String email = flat['email']?.toString() ?? '';
      final String? referral = flat['referral_code']?.toString();

      String name = '$firstName $lastName'.trim();
      if (name.isEmpty) name = email.isNotEmpty ? email : 'User';

      setState(() {
        _displayName = name;
        _email = email;
        _initials = _buildInitials(name);
        _referralCode = referral;
        // Backend returns a relative path (/uploads/avatars/xyz.jpg) —
        // resolve it the same way profile_screen.dart does, or
        // Image.network below just fails silently.
        _avatarUrl = AuthService.resolveMediaUrl(flat['avatar_url']?.toString());
        _profileLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _profileLoaded = true);
    }
  }

  Future<void> _loadStats() async {
    try {
      final List<Map<String, dynamic>> orders =
          await _orderService.getUserOrders();
      if (!mounted) return;

      const Set<String> activeStatuses = {
        'pending',
        'confirmed',
        'preparing',
        'ready',
        'dispatched',
      };

      setState(() {
        _totalOrders = orders.length;
        final List<Map<String, dynamic>> active = orders.where((Map<String, dynamic> o) {
          final String status =
              (o['order_status'] ?? o['status'] ?? '').toString().toLowerCase();
          return activeStatuses.contains(status);
        }).toList();
        _activeOrders = active.length;
        _activeOrderId = active.isNotEmpty
            ? (active.first['id'] ?? active.first['order_id'])?.toString()
            : null;
        _statsLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _statsLoaded = true);
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> _logout() async {
    final bool confirmed = await _showLogoutDialog();
    if (!confirmed || !mounted) return;

    // Show loading
    if (mounted) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: _kGreen500),
        ),
      );
    }

    try {
      await PushNotificationManager.instance.unregister();
      await _authService.signOut();
    } catch (_) {
      // best-effort — always proceed to login
    }

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop(); // dismiss loader
      Navigator.pushNamedAndRemoveUntil(
        context,
        Routes.signIn,
        (Route<dynamic> route) => false,
      );
    }
  }

  Future<bool> _showLogoutDialog() async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        actionsPadding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        title: const Row(
          children: <Widget>[
            Icon(Icons.logout_rounded, color: Colors.red, size: 22),
            SizedBox(width: 10),
            Text('Logout', style: TextStyle(fontSize: 17)),
          ],
        ),
        content: const Text(
          'Are you sure you want to logout from your account?',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: _kSlate500, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text('Logout',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Backend may store { account:{email}, profile:{first_name} } or flat.
  /// Merge both layers so callers don't care about the structure.
  static Map<String, dynamic> _flattenUser(Map<String, dynamic> raw) {
    final Map<String, dynamic> merged = <String, dynamic>{...raw};
    final Object? account = raw['account'];
    final Object? profile = raw['profile'];
    final Object? user = raw['user'];
    if (account is Map) merged.addAll(account.cast<String, dynamic>());
    if (profile is Map) merged.addAll(profile.cast<String, dynamic>());
    if (user is Map) merged.addAll(user.cast<String, dynamic>());
    return merged;
  }

  static String _buildInitials(String name) {
    if (name.isEmpty) return 'U';
    final List<String> parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  // ── Navigation helper ─────────────────────────────────────────────────────

  void _navigate(String route, {Object? arguments}) {
    Navigator.pop(context);
    Navigator.pushNamed(context, route, arguments: arguments);
  }

  void _navigateReplace(String route) {
    Navigator.pop(context);
    Navigator.pushReplacementNamed(context, route);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: _kBg,
      width: 300,
      child: Column(
        children: <Widget>[
          // ── Header ────────────────────────────────────────────────────────
          _DrawerHeader(
            initials: _initials,
            name: _displayName.isEmpty ? 'Welcome' : _displayName,
            email: _email,
            referralCode: _referralCode,
            profileLoaded: _profileLoaded,
            avatarUrl: _avatarUrl,
          ),

          // ── Stats row ─────────────────────────────────────────────────────
          _StatsRow(
            loaded: _statsLoaded,
            totalOrders: _totalOrders,
            activeOrders: _activeOrders,
          ),

          // ── Nav items ─────────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              children: <Widget>[
                const _SectionLabel('Main'),
                _NavItem(
                  icon: Icons.home_rounded,
                  title: 'Home',
                  onTap: () => _navigateReplace(Routes.home),
                ),
                _NavItem(
                  icon: Icons.person_rounded,
                  title: 'My Profile',
                  onTap: () => _navigate(Routes.profile),
                ),
                _NavItem(
                  icon: Icons.shopping_cart_rounded,
                  title: 'Cart',
                  onTap: () => _navigateReplace(Routes.cart),
                ),
                _NavItem(
                  icon: Icons.history_rounded,
                  title: 'Order History',
                  onTap: () => _navigate(Routes.orderHistory),
                ),
                _NavItem(
                  icon: Icons.local_shipping_rounded,
                  title: 'Track Order',
                  badge: _activeOrders > 0 ? '$_activeOrders' : null,
                  onTap: () => _activeOrderId != null
                      ? _navigate(Routes.trackOrder,
                          arguments: _activeOrderId)
                      : _navigate(Routes.orderHistory),
                ),
                const SizedBox(height: 4),
                const _SectionLabel('Explore'),
                _NavItem(
                  icon: Icons.store_rounded,
                  title: 'Nearby Vendors',
                  onTap: () => _navigate(Routes.nearby),
                ),
                _NavItem(
                  icon: Icons.location_on_rounded,
                  title: 'Change Location',
                  onTap: () => _navigate(Routes.changeLocation),
                ),
                const SizedBox(height: 4),
                const _SectionLabel('Account'),
                _NavItem(
                  icon: Icons.account_circle_rounded,
                  title: 'Account',
                  onTap: () => _navigate(Routes.account),
                ),
                _NavItem(
                  icon: Icons.settings_rounded,
                  title: 'Settings',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const PremiumSettingsPage(),
                      ),
                    );
                  },
                ),
                _NavItem(
                  icon: Icons.help_rounded,
                  title: 'Help & Support',
                  onTap: () => _navigate(Routes.helpSupport),
                ),
              ],
            ),
          ),

          // ── Logout ───────────────────────────────────────────────────────
          _LogoutButton(onTap: _logout),
        ],
      ),
    );
  }

  // ── Help dialog ───────────────────────────────────────────────────────────

}

// ─────────────────────────────────────────────────────────────────────────────
//  Header
// ─────────────────────────────────────────────────────────────────────────────
class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({
    required this.initials,
    required this.name,
    required this.email,
    required this.profileLoaded,
    this.referralCode,
    this.avatarUrl,
  });

  final String initials;
  final String name;
  final String email;
  final bool profileLoaded;
  final String? referralCode;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kGreen900,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // ── Avatar ──────────────────────────────────────────────────
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25), width: 1.5),
                ),
                alignment: Alignment.center,
                child: !profileLoaded
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : (avatarUrl != null && avatarUrl!.isNotEmpty)
                        ? ClipOval(
                            child: Image.network(
                              avatarUrl!,
                              width: 54,
                              height: 54,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Text(
                                initials,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          )
                        : Text(
                            initials,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
              ),

              const SizedBox(width: 14),

              // ── Name / email / referral ──────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (email.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 3),
                      Text(
                        email,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (referralCode != null) ...<Widget>[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(Icons.card_giftcard_rounded,
                                size: 11, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              referralCode!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Stats row
// ─────────────────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.loaded,
    required this.totalOrders,
    required this.activeOrders,
  });

  final bool loaded;
  final int totalOrders;
  final int activeOrders;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kGreen900,
      child: Column(
        children: <Widget>[
          Divider(
              color: Colors.white.withValues(alpha: 0.08),
              thickness: 1,
              height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: !loaded
                ? _Skeleton()
                : Row(
                    children: <Widget>[
                      _StatCell(value: '$totalOrders', label: 'Total orders'),
                      _StatSep(),
                      _StatCell(
                        value: '$activeOrders',
                        label: 'Active',
                        valueColor: activeOrders > 0
                            ? const Color(0xFFFBBF24)
                            : Colors.white,
                      ),
                      _StatSep(),
                      _StatCell(
                          value: activeOrders > 0 ? 'In progress' : 'All done',
                          label: 'Status'),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.value,
    required this.label,
    this.valueColor = Colors.white,
  });

  final String value;
  final String label;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Text(
            value,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: valueColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              color: Colors.white.withValues(alpha: 0.5),
              letterSpacing: 0.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatSep extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.white.withValues(alpha: 0.1),
    );
  }
}

class _Skeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: List<Widget>.generate(
        3,
        (int i) => Expanded(
          child: Column(
            children: <Widget>[
              _SkeletonBox(width: 48, height: 16),
              const SizedBox(height: 5),
              _SkeletonBox(width: 32, height: 9),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.width, required this.height});
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Section label
// ─────────────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(0xFF94A3B8),
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Nav item
// ─────────────────────────────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          splashColor: _kGreen500.withValues(alpha: 0.08),
          highlightColor: _kGreen500.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: <Widget>[
                // Icon box
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _kGreen500.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: _kGreen700, size: 18),
                ),
                const SizedBox(width: 12),

                // Title
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _kSlate800,
                    ),
                  ),
                ),

                // Badge or chevron
                if (badge != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  )
                else
                  const Icon(Icons.chevron_right_rounded,
                      size: 16, color: _kSlate200),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Logout button
// ─────────────────────────────────────────────────────────────────────────────
class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const Divider(color: _kSlate200, thickness: 1, height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(10),
              splashColor: Colors.red.withValues(alpha: 0.06),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.red.withValues(alpha: 0.12), width: 1),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.logout_rounded,
                          color: Colors.red, size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Logout',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
