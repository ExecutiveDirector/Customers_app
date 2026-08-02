// lib/screens/home/widgets/home_header.dart
//
// Modern, slim home header for AquaGas.
//
// Layout (3 rows, vertically compressed, sticky-feel gradient):
//   • Location row   [📍 current address ▾]                [bell with badge]
//   • Greeting row   [Hi, {name} 👋]              [profile avatar]
//   • Search row     [🔍 search products, gas, water...]
//
// The header is intentionally lighter than the previous one — no heavy
// double gradient + box-shadow combo, no white inner card on white surface.
// The location row replaces the static "Greeting / name" pair with the
// thing the user actually wants to scan on first paint: where am I and
// what's nearby.
import 'package:flutter/material.dart';

import 'package:aquagas/theme/app_colors.dart';

class HomeHeader extends StatefulWidget {
  final String? userName;
  final String? locationLabel;
  final String? avatarUrl;
  final int notificationCount;
  final ValueChanged<String>? onSearch;
  final VoidCallback? onProfileTap;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onLocationTap;
  final VoidCallback? onMenuTap;

  const HomeHeader({
    super.key,
    this.userName,
    this.locationLabel,
    this.avatarUrl,
    this.notificationCount = 0,
    this.onSearch,
    this.onProfileTap,
    this.onNotificationsTap,
    this.onLocationTap,
    this.onMenuTap,
  });

  @override
  State<HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends State<HomeHeader> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _greeting() {
    final int hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _displayName() {
    final name = widget.userName?.trim();
    return (name != null && name.isNotEmpty) ? name : 'Guest';
  }

  String _displayLocation() {
    final loc = widget.locationLabel?.trim();
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // ── Row 1: Menu · Location · Bell ───────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  _IconCircle(
                    icon: Icons.menu_rounded,
                    onTap: widget.onMenuTap,
                    tooltip: 'Menu',
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      onTap: widget.onLocationTap,
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
                  const SizedBox(width: AppSpacing.xs),
                  _NotificationBell(
                    count: widget.notificationCount,
                    onTap: widget.onNotificationsTap,
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.sm),

              // ── Row 2: Greeting + Avatar ────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          '${_greeting()},',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          _displayName(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _ProfileAvatar(
                    avatarUrl: widget.avatarUrl,
                    name: _displayName(),
                    onTap: widget.onProfileTap,
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.sm),

              // ── Row 3: Search ───────────────────────────────────
              _SearchField(
                controller: _searchController,
                onChanged: (String v) => setState(() {}),
                onSubmitted: (String v) =>
                    widget.onSearch?.call(v.trim()),
                onClear: () {
                  _searchController.clear();
                  widget.onSearch?.call('');
                  setState(() {});
                },
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

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.count, required this.onTap});
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: <Widget>[
        _IconCircle(
          icon: Icons.notifications_none_rounded,
          onTap: onTap,
        ),
        if (count > 0)
          Positioned(
            top: 2,
            right: 2,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
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
      ],
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.avatarUrl,
    required this.name,
    required this.onTap,
  });

  final String? avatarUrl;
  final String name;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
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

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 14, color: AppColors.slate800),
        decoration: InputDecoration(
          hintText: 'Search gas, water & accessories...',
          hintStyle: const TextStyle(
            color: AppColors.slate400,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 0,
            horizontal: AppSpacing.md,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.brandDark,
            size: 22,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (BuildContext context, TextEditingValue value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                splashRadius: 18,
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.slate500,
                  size: 18,
                ),
                onPressed: onClear,
              );
            },
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(
              color: Colors.white,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
