// lib/screens/home/widgets/quick_actions.dart
//
// 4-tile quick-action row, just under the promo.
//
// Tiles: Track Order · My Orders · Help · Reorder
// (Reorder stays enabled even for new accounts — it just becomes a
// no-op or scrolls to categories. Hooking it to a real "past orders"
// endpoint is a separate backend task.)
//
// Each tile is a self-contained, very small InkWell on a soft-tint
// card so the row reads as a single horizontal scannable strip.
import 'package:flutter/material.dart';

import 'package:aquagas/theme/app_colors.dart';

class QuickAction {
  final String label;
  final IconData icon;
  final Color tint;
  final Color accent;
  final VoidCallback onTap;

  const QuickAction({
    required this.label,
    required this.icon,
    required this.tint,
    required this.accent,
    required this.onTap,
  });
}

class QuickActionsRow extends StatelessWidget {
  final List<QuickAction> actions;
  const QuickActionsRow({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < actions.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: AppSpacing.xs),
            Expanded(child: _QuickActionTile(action: actions[i])),
          ],
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action});
  final QuickAction action;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: action.tint,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: action.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm,
            horizontal: AppSpacing.xs,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(action.icon, color: action.accent, size: 22),
              ),
              const SizedBox(height: 6),
              Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: action.accent,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
