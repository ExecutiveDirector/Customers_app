import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme_provider.dart';
import 'premium_dialogs.dart';
import 'package:aquagas/services/notification_service.dart';
import 'package:aquagas/screens/help_support_screen.dart';

/// Premium Settings Page with professional UX
class PremiumSettingsPage extends StatefulWidget {
  const PremiumSettingsPage({Key? key}) : super(key: key);

  @override
  State<PremiumSettingsPage> createState() => _PremiumSettingsPageState();
}

class _PremiumSettingsPageState extends State<PremiumSettingsPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  bool _notificationsEnabled = true;
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animController.forward();
    _loadNotificationPreference();
  }

  Future<void> _loadNotificationPreference() async {
    final prefs = await _notificationService.getPreferences();
    if (mounted) {
      setState(() {
        _notificationsEnabled = prefs['push_enabled'] as bool? ?? true;
      });
    }
  }

  Future<void> _onNotificationsToggled(bool enabled) async {
    setState(() => _notificationsEnabled = enabled);

    if (enabled) {
      // Android 13+ / iOS both require this to actually be granted before
      // any push will show, regardless of what the backend preference
      // says — ask for it right when the user opts in.
      final status = await Permission.notification.request();
      if (!status.isGranted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text("Notifications are blocked in your phone's settings, so "
                    "you won't receive alerts even with this on."),
          ),
        );
      }
    }

    try {
      await _notificationService.updatePreferences(<String, dynamic>{
        'push_enabled': enabled,
      });
    } catch (_) {
      // Preference still applies locally for this session; it'll sync
      // next time the toggle is touched or the preferences reload.
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _openThemeDialog() => showDialog<void>(
        context: context,
        builder: (_) => const PremiumThemeDialog(),
      );

  void _openRateDialog() => showDialog<void>(
        context: context,
        builder: (_) => const PremiumRateDialog(),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tp = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.light
          ? const Color(0xFFF8FAFB)
          : const Color(0xFF0A0E1A),
      body: CustomScrollView(
        slivers: [
          // Premium App Bar
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: theme.colorScheme.onSurface,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Settings',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22),
              ),
              titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primaryContainer.withOpacity(0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.settings_rounded, color: Colors.white),
                  onPressed: () {},
                ),
              ),
            ],
          ),

          // Content
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Appearance Section
                FadeTransition(
                  opacity: _animController,
                  child: _buildSection(
                    title: 'Appearance',
                    icon: Icons.palette_rounded,
                    children: [
                      _SettingTile(
                        icon: Icons.auto_awesome_rounded,
                        title: 'Theme',
                        subtitle: _getThemeLabel(tp.mode),
                        onTap: _openThemeDialog,
                        showChevron: true,
                      ),
                      _ToggleTile(
                        icon: Icons.palette_rounded,
                        title: 'Dynamic Colors',
                        subtitle: 'Match system color palette',
                        value: tp.useDynamicColor,
                        onChanged: (v) => tp.setUseDynamicColor(v),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // General Section
                FadeTransition(
                  opacity: _animController,
                  child: _buildSection(
                    title: 'General',
                    icon: Icons.tune_rounded,
                    children: [
                      _SettingTile(
                        icon: Icons.language_rounded,
                        title: 'Language',
                        subtitle: 'English (US)',
                        onTap: () => showDialog<void>(
                          context: context,
                          builder: (_) => AlertDialog(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            title: const Text('Language'),
                            content: const Text(
                                'AquaGas currently runs in English only. '
                                'Kiswahili and other languages are on the '
                                'roadmap.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Got it'),
                              ),
                            ],
                          ),
                        ),
                        showChevron: true,
                      ),
                      _ToggleTile(
                        icon: Icons.notifications_rounded,
                        title: 'Notifications',
                        subtitle: 'Order updates and offers',
                        value: _notificationsEnabled,
                        onChanged: _onNotificationsToggled,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Support Section
                FadeTransition(
                  opacity: _animController,
                  child: _buildSection(
                    title: 'Support & Feedback',
                    icon: Icons.help_rounded,
                    children: [
                      _SettingTile(
                        icon: Icons.message_rounded,
                        title: 'Feedback',
                        subtitle: 'Share your thoughts',
                        onTap: () async {
                          final uri = Uri(
                            scheme: 'mailto',
                            path: 'support@aquagas.co.ke',
                            query: 'subject=AquaGas app feedback',
                          );
                          if (await canLaunchUrl(uri)) await launchUrl(uri);
                        },
                        showChevron: true,
                      ),
                      _SettingTile(
                        icon: Icons.thumb_up_rounded,
                        title: 'Rate Us',
                        subtitle: 'Love the app? Leave a review!',
                        onTap: _openRateDialog,
                        badge: 'NEW',
                        showChevron: true,
                      ),
                      _SettingTile(
                        icon: Icons.mail_rounded,
                        title: 'Contact Support',
                        subtitle: 'We\'re here to help',
                        onTap: () => Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                              builder: (_) => const HelpSupportScreen()),
                        ),
                        showChevron: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Legal Section
                FadeTransition(
                  opacity: _animController,
                  child: _buildSection(
                    title: 'Legal & About',
                    icon: Icons.shield_rounded,
                    children: [
                      _SettingTile(
                        icon: Icons.privacy_tip_rounded,
                        title: 'Privacy Policy',
                        subtitle: 'How we protect your data',
                        onTap: () => Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const _LegalPagePlaceholder(
                              title: 'Privacy Policy',
                            ),
                          ),
                        ),
                        showChevron: true,
                      ),
                      _SettingTile(
                        icon: Icons.description_rounded,
                        title: 'Terms & Conditions',
                        subtitle: 'Our terms of service',
                        onTap: () => Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const _LegalPagePlaceholder(
                              title: 'Terms & Conditions',
                            ),
                          ),
                        ),
                        showChevron: true,
                      ),
                      _SettingTile(
                        icon: Icons.info_rounded,
                        title: 'Version',
                        subtitle: '1.1.7 (Latest)',
                        onTap: null,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Premium Ad Card
                _buildPremiumCard(theme),

                const SizedBox(height: 24),

                // Footer
                Center(
                  child: Column(
                    children: [
                      Text(
                        'Made with ❤️ by AquaGas Team',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '© 2025 All rights reserved',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          ...children.map((child) => Column(
                children: [
                  Divider(
                      height: 1,
                      color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
                  child,
                ],
              )),
        ],
      ),
    );
  }

  Widget _buildPremiumCard(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF9333EA), Color(0xFFDB2777)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9333EA).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            'Premium Feature',
            style: theme.textTheme.labelMedium?.copyWith(
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Go Ad-Free!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upgrade to Premium for the best experience',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF9333EA),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 8,
              shadowColor: Colors.white.withOpacity(0.5),
            ),
            child: const Text(
              'Learn More',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  String _getThemeLabel(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return 'Light mode';
      case AppThemeMode.dark:
        return 'Dark mode';
      default:
        return 'System default';
    }
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final String? badge;
  final bool showChevron;

  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.badge,
    this.showChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primaryContainer,
                    theme.colorScheme.primaryContainer.withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: theme.colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badge!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (showChevron)
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurface.withOpacity(0.3),
              ),
          ],
        ),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primaryContainer,
                  theme.colorScheme.primaryContainer.withOpacity(0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

/// Placeholder for Privacy Policy / Terms & Conditions.
///
/// Deliberately not filled with invented legal text — a privacy policy and
/// terms of service are legal documents that need to accurately describe
/// what AquaGas actually collects/does and ideally get a legal review.
/// Drop the real copy in below (or swap this for a WebView pointed at a
/// hosted page) once it's ready.
class _LegalPagePlaceholder extends StatelessWidget {
  const _LegalPagePlaceholder({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined,
                size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              '$title content goes here.',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'This screen is wired up and ready — replace this text with '
              'the real $title copy (or point it at a hosted page) before '
              'launch.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
