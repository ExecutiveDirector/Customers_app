// lib/screens/home/widgets/home_header.dart
//
// Slim, single-row home header for AquaGas.
//
// Layout (1 row):
//   [menu]   [📍 current address ▾]              [avatar + notif badge]
//
// The greeting row, profile-name pair, and inline search field were
// removed — the header now shows only what a user needs on first paint:
// where they're delivering to, and whether they have unread notifications.
// The avatar-shaped icon on the right carries the notification badge and
// opens Notifications on tap. Profile itself is still one tap away from
// the drawer ("My Profile"), so nothing was made unreachable.
import 'package:flutter/material.dart';

import 'package:aquagas/theme/app_colors.dart';

class HomeHeader extends StatelessWidget {
  final String? userName;
  final String? locationLabel;
  final String? avatarUrl;
  final int notificationCount;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onLocationTap;
  final VoidCallback? onMenuTap;

  const HomeHeader({
    super.key,
    this.userName,
    this.locationLabel,
    this.avatarUrl,
    this.notificationCount = 0,
    this.onNotificationsTap,
    this.onLocationTap,
    this.onMenuTap,
  });

  String _displayName() {
    final name = userName?.trim();
    return (name != null && name.isNotEmpty) ? name : 'Guest';
  }

  String _displayLocation() {
    final loc = locationLabel?.trim();
    return (loc != null && loc.isNotEmpty) ? loc : 'Set your location';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.brandHeader,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppRadius.xl),
          bottomRight: Radius.circular(AppRadius.xl),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              _IconCircle(
                icon: Icons.menu_rounded,
                onTap: onMenuTap,
                tooltip: 'Menu',
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  onTap: onLocationTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xxs,
                      horizontal: AppSpacing.xxs,
                    ),
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          Icons.location_on_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                'Deliver to',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Row(
                                children: <Widget>[
                                  Flexible(
                                    child: Text(
                                      _displayLocation(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.1,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _ProfileWithBadge(
                avatarUrl: avatarUrl,
                name: _displayName(),
                count: notificationCount,
                onTap: onNotificationsTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Sub-widgets (kept private to the header) ─────────────────────────────

class _IconCircle extends StatelessWidget {
  const _IconCircle({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final Widget btn = Material(
      color: Colors.white.withOpacity(0.18),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

/// The profile avatar, carrying the unread-notifications badge. Tapping it
/// opens Notifications — Profile itself stays reachable via the drawer's
/// "My Profile" entry, so this doesn't remove access to either screen.
class _ProfileWithBadge extends StatelessWidget {
  const _ProfileWithBadge({
    required this.avatarUrl,
    required this.name,
    required this.count,
    required this.onTap,
  });

  final String? avatarUrl;
  final String name;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: <Widget>[
        Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.7),
                  width: 2,
                ),
                color: Colors.white,
              ),
              child: ClipOval(
                child: (avatarUrl != null && avatarUrl!.isNotEmpty)
                    ? Image.network(
                        avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _Initial(name: name),
                      )
                    : _Initial(name: name),
              ),
            ),
          ),
        ),
        if (count > 0)
          Positioned(
            top: -2,
            right: -2,
            child: IgnorePointer(
              child: Container(
                constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: AppColors.brandDark, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    count > 9 ? '9+' : '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.brandHeader,
      ),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 16,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
