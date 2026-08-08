// lib/screens/account_screen.dart
//
// Redesign of the Account page. The previous version rendered entirely
// hardcoded mock data (fake name, fake wallet balance, fake loyalty
// history) inside a purple/pink gradient dashboard that didn't match the
// rest of the app. This version:
//   • Uses the shared AquaGas design tokens (AppColors/AppRadius/AppSpacing)
//     that the rest of the app (home, notifications, help & support) uses.
//   • Pulls real data from AccountService — profile, wallet, loyalty points,
//     transaction history and the rewards catalog — with loading, error and
//     empty states, plus pull-to-refresh.
//   • Lets a user actually redeem a reward, which calls the backend and
//     reflects the new points balance immediately.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:aquagas/services/account_service.dart';
import 'package:aquagas/services/auth_service.dart';
import 'package:aquagas/theme/app_colors.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final AccountService _service = AccountService();

  bool _isLoading = true;
  String? _error;

  AccountSummary? _summary;
  List<WalletTransactionItem> _walletTxns = <WalletTransactionItem>[];
  List<LoyaltyTransactionItem> _loyaltyTxns = <LoyaltyTransactionItem>[];
  List<LoyaltyReward> _rewards = <LoyaltyReward>[];
  ReferralSummary? _referralSummary;

  final Set<int> _redeemingRewardIds = <int>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<ReferralSummary?> _getReferralSummaryOrNull() async {
    try {
      return await _service.getReferralSummary();
    } catch (_) {
      return null;
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
        _service.getAccountSummary(),
        _service.getWalletTransactions().catchError((_) => <WalletTransactionItem>[]),
        _service.getLoyaltyHistory().catchError((_) => <LoyaltyTransactionItem>[]),
        _service.getLoyaltyRewards().catchError((_) => <LoyaltyReward>[]),
        _getReferralSummaryOrNull(),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as AccountSummary;
        _walletTxns = results[1] as List<WalletTransactionItem>;
        _loyaltyTxns = results[2] as List<LoyaltyTransactionItem>;
        _rewards = results[3] as List<LoyaltyReward>;
        _referralSummary = results[4] as ReferralSummary?;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  String _formatCurrency(double amount) {
    final bool negative = amount < 0;
    final String digits = amount.abs().toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
    return '${negative ? '-' : ''}KES $digits';
  }

  String _formatDate(DateTime date) {
    const List<String> months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _redeem(LoyaltyReward reward) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        title: Text('Redeem ${reward.name}?'),
        content: Text('${reward.pointsRequired} points will be deducted from your balance.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand, foregroundColor: Colors.white),
            child: const Text('Redeem'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _redeemingRewardIds.add(reward.rewardId));
    try {
      final int newBalance = await _service.redeemReward(reward.rewardId);
      if (!mounted) return;
      setState(() {
        _redeemingRewardIds.remove(reward.rewardId);
        final AccountSummary? s = _summary;
        if (s != null) {
          _summary = AccountSummary(
            userId: s.userId,
            firstName: s.firstName,
            lastName: s.lastName,
            email: s.email,
            phoneNumber: s.phoneNumber,
            avatarUrl: s.avatarUrl,
            isPremium: s.isPremium,
            referralCode: s.referralCode,
            totalOrders: s.totalOrders,
            totalSpent: s.totalSpent,
            loyaltyPoints: newBalance,
            walletBalance: s.walletBalance,
            pendingBalance: s.pendingBalance,
            walletTotalEarned: s.walletTotalEarned,
            walletTotalSpent: s.walletTotalSpent,
          );
        }
      });
      unawaited(_service.getLoyaltyHistory().then((List<LoyaltyTransactionItem> h) {
        if (mounted) setState(() => _loyaltyTxns = h);
      }).catchError((_) {}));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${reward.name} redeemed successfully!'), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _redeemingRewardIds.remove(reward.rewardId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _copyReferralCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Referral code copied')),
    );
  }

  void _shareReferralCode(ReferralSummary r) {
    final String message =
        'Get LPG delivered fast with AquaGas! Use my referral code ${r.referralCode} '
        'when you sign up and we both earn bonus points.';
    Clipboard.setData(ClipboardData(text: message));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Referral message copied — paste it anywhere to share')),
    );
  }

  void _showAllTransactions({
    required String title,
    required List<Widget> items,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (BuildContext context, ScrollController controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
              ),
              child: Column(
                children: <Widget>[
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.slate200,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(title,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.slate900)),
                  ),
                  Expanded(
                    child: items.isEmpty
                        ? const Center(
                            child: Text('Nothing here yet', style: TextStyle(color: AppColors.slate500)),
                          )
                        : ListView.separated(
                            controller: controller,
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                            itemCount: items.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.slate100),
                            itemBuilder: (BuildContext context, int i) => items[i],
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.slate900,
        title: const Text('My Account', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        top: false,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.brand));
    }
    if (_error != null) {
      return _buildErrorState();
    }
    final AccountSummary? summary = _summary;
    if (summary == null) return _buildErrorState();

    return RefreshIndicator(
      color: AppColors.brand,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.xxl),
        children: <Widget>[
          _buildProfileHeader(summary),
          const SizedBox(height: AppSpacing.md),
          _buildStatsRow(summary),
          const SizedBox(height: AppSpacing.lg),
          _buildWalletCard(summary),
          const SizedBox(height: AppSpacing.lg),
          _buildLoyaltySection(summary),
          if (_referralSummary != null) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            _buildReferralSection(_referralSummary!),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: <Widget>[
        const SizedBox(height: 80),
        const Icon(Icons.cloud_off_rounded, size: 56, color: AppColors.slate400),
        const SizedBox(height: AppSpacing.md),
        Text(
          _error ?? 'Something went wrong.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.slate600, fontSize: 15),
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
            ),
          ),
        ),
      ],
    );
  }

  // ── Header ────────────────────────────────────────────────────────────

  Widget _buildProfileHeader(AccountSummary s) {
    final String? avatar = AuthService.resolveMediaUrl(s.avatarUrl);
    final String initials = (s.firstName.isNotEmpty ? s.firstName[0] : '') +
        (s.lastName.isNotEmpty ? s.lastName[0] : '');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              gradient: AppColors.brandHeader,
              shape: BoxShape.circle,
            ),
            child: avatar != null
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: avatar,
                      fit: BoxFit.cover,
                      width: 60,
                      height: 60,
                      errorWidget: (_, __, ___) => _InitialsAvatar(initials: initials),
                    ),
                  )
                : _InitialsAvatar(initials: initials),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        s.fullName.isEmpty ? 'AquaGas Customer' : s.fullName,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.slate900),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (s.isPremium) ...<Widget>[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: AppColors.brandHeader,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(Icons.workspace_premium, color: Colors.white, size: 12),
                            SizedBox(width: 3),
                            Text('Premium',
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  s.phoneNumber ?? s.email ?? '',
                  style: const TextStyle(color: AppColors.slate500, fontSize: 13),
                ),
                if (s.referralCode.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => _copyReferralCode(s.referralCode),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.slate50,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: AppColors.slate200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text('Referral: ${s.referralCode}',
                              style: const TextStyle(fontSize: 11, color: AppColors.slate600, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 4),
                          const Icon(Icons.copy_rounded, size: 12, color: AppColors.slate500),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Stats ─────────────────────────────────────────────────────────────

  Widget _buildStatsRow(AccountSummary s) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _StatTile(
            icon: Icons.shopping_bag_rounded,
            color: AppColors.info,
            label: 'Orders',
            value: '${s.totalOrders}',
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatTile(
            icon: Icons.payments_rounded,
            color: AppColors.success,
            label: 'Total Spent',
            value: _formatCurrency(s.totalSpent),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatTile(
            icon: Icons.card_giftcard_rounded,
            color: AppColors.brand,
            label: 'Points',
            value: '${s.loyaltyPoints}',
          ),
        ),
      ],
    );
  }

  // ── Wallet ────────────────────────────────────────────────────────────

  Widget _buildWalletCard(AccountSummary s) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppColors.brandHeader,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppColors.headerShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Row(
                children: <Widget>[
                  Icon(Icons.account_balance_wallet_rounded, color: Colors.white70, size: 18),
                  SizedBox(width: 6),
                  Text('Wallet Balance', style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
              if (s.pendingBalance > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '${_formatCurrency(s.pendingBalance)} pending',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _formatCurrency(s.walletBalance),
            style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: _WalletMiniStat(label: 'Earned', value: _formatCurrency(s.walletTotalEarned)),
              ),
              Container(width: 1, height: 28, color: Colors.white24),
              Expanded(
                child: _WalletMiniStat(label: 'Spent', value: _formatCurrency(s.walletTotalSpent)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (_walletTxns.isNotEmpty) ...<Widget>[
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                children: <Widget>[
                  for (final WalletTransactionItem t in _walletTxns.take(3))
                    _WalletTransactionRow(
                      transaction: t,
                      formatCurrency: _formatCurrency,
                      formatDate: _formatDate,
                    ),
                  InkWell(
                    onTap: () => _showAllTransactions(
                      title: 'Wallet Transactions',
                      items: _walletTxns
                          .map((WalletTransactionItem t) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: _WalletTransactionRow(
                                  transaction: t,
                                  formatCurrency: _formatCurrency,
                                  formatDate: _formatDate,
                                ),
                              ))
                          .toList(),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('See all transactions',
                          style: TextStyle(color: AppColors.brandDark, fontWeight: FontWeight.w600, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
          ] else
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Text(
                'No wallet activity yet. Cashback and refunds will show up here.',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  // ── Loyalty ───────────────────────────────────────────────────────────

  Widget _buildLoyaltySection(AccountSummary s) {
    final int nextTier = _rewards
            .map((LoyaltyReward r) => r.pointsRequired)
            .where((int p) => p > s.loyaltyPoints)
            .fold<int?>(null, (int? min, int p) => (min == null || p < min) ? p : min) ??
        (s.loyaltyPoints > 0 ? s.loyaltyPoints : 500);
    final double progress = nextTier == 0 ? 1 : (s.loyaltyPoints / nextTier).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('Loyalty & Rewards',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.slate900)),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.emoji_events_rounded, color: AppColors.brand, size: 22),
                  const SizedBox(width: 8),
                  Text('${s.loyaltyPoints} points',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.slate900)),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: AppColors.slate100,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.brand),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                nextTier > s.loyaltyPoints
                    ? '${nextTier - s.loyaltyPoints} points to your next reward'
                    : 'You can redeem a reward right now!',
                style: const TextStyle(fontSize: 12, color: AppColors.slate500),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (_rewards.isNotEmpty) ...<Widget>[
          const Text('Available Rewards',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.slate900)),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 168,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _rewards.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (BuildContext context, int i) {
                final LoyaltyReward reward = _rewards[i];
                final bool canRedeem = s.loyaltyPoints >= reward.pointsRequired;
                final bool isRedeeming = _redeemingRewardIds.contains(reward.rewardId);
                return _RewardCard(
                  reward: reward,
                  canRedeem: canRedeem,
                  isRedeeming: isRedeeming,
                  onRedeem: () => _redeem(reward),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (_loyaltyTxns.isNotEmpty) ...<Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text('Points History',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.slate900)),
              InkWell(
                onTap: () => _showAllTransactions(
                  title: 'Points History',
                  items: _loyaltyTxns
                      .map((LoyaltyTransactionItem t) => _LoyaltyTransactionRow(
                            transaction: t,
                            formatDate: _formatDate,
                          ))
                      .toList(),
                ),
                child: const Text('See all',
                    style: TextStyle(color: AppColors.brandDark, fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: AppColors.cardShadow,
            ),
            child: Column(
              children: <Widget>[
                for (final LoyaltyTransactionItem t in _loyaltyTxns.take(4))
                  _LoyaltyTransactionRow(transaction: t, formatDate: _formatDate),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ── Referrals ─────────────────────────────────────────────────────────

  Widget _buildReferralSection(ReferralSummary r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('Refer & Earn',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.slate900)),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            gradient: AppColors.brandHeader,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppColors.headerShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Give ${r.refereeRewardPoints} pts, Get ${r.referrerRewardPoints} pts',
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Share your code. Your friend gets bonus points on signup, '
                'you get rewarded when they place their first order.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        r.referralCode.isEmpty ? '—' : r.referralCode,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.slate900,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _copyReferralCode(r.referralCode),
                      icon: const Icon(Icons.copy_rounded, color: AppColors.brand, size: 20),
                      tooltip: 'Copy code',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    IconButton(
                      onPressed: () => _shareReferralCode(r),
                      icon: const Icon(Icons.share_rounded, color: AppColors.brand, size: 20),
                      tooltip: 'Share',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            Expanded(
              child: _StatTile(
                icon: Icons.people_alt_rounded,
                color: AppColors.info,
                label: 'Referred',
                value: '${r.totalReferred}',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _StatTile(
                icon: Icons.hourglass_top_rounded,
                color: AppColors.warning,
                label: 'Pending',
                value: '${r.pendingCount}',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _StatTile(
                icon: Icons.emoji_events_rounded,
                color: AppColors.success,
                label: 'Points Earned',
                value: '${r.pointsEarnedFromReferrals}',
              ),
            ),
          ],
        ),
        if (r.referrals.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          const Text('Your Referrals',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.slate900)),
          const SizedBox(height: AppSpacing.xs),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: AppColors.cardShadow,
            ),
            child: Column(
              children: <Widget>[
                for (final ReferralItem item in r.referrals.take(6)) _ReferralRow(item: item, formatDate: _formatDate),
              ],
            ),
          ),
        ] else
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              'No referrals yet — share your code to start earning.',
              style: TextStyle(fontSize: 12.5, color: AppColors.slate500),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Small presentational widgets
// ─────────────────────────────────────────────────────────────────────────

class _InitialsAvatar extends StatelessWidget {
  final String initials;
  const _InitialsAvatar({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials.isEmpty ? '?' : initials.toUpperCase(),
        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _StatTile({required this.icon, required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(AppRadius.xs)),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.slate500)),
        ],
      ),
    );
  }
}

class _WalletMiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _WalletMiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _WalletTransactionRow extends StatelessWidget {
  final WalletTransactionItem transaction;
  final String Function(double) formatCurrency;
  final String Function(DateTime) formatDate;

  const _WalletTransactionRow({
    required this.transaction,
    required this.formatCurrency,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final bool credit = transaction.isCredit;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: (credit ? AppColors.success : AppColors.danger).withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Icon(credit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                color: credit ? AppColors.success : AppColors.danger, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  transaction.description ?? transaction.type,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.slate800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(formatDate(transaction.createdAt), style: const TextStyle(fontSize: 10.5, color: AppColors.slate500)),
              ],
            ),
          ),
          Text(
            '${credit ? '+' : '-'}${formatCurrency(transaction.amount.abs())}',
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.bold, color: credit ? AppColors.success : AppColors.danger),
          ),
        ],
      ),
    );
  }
}

class _LoyaltyTransactionRow extends StatelessWidget {
  final LoyaltyTransactionItem transaction;
  final String Function(DateTime) formatDate;

  const _LoyaltyTransactionRow({required this.transaction, required this.formatDate});

  @override
  Widget build(BuildContext context) {
    final bool positive = transaction.points > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: AppColors.slate100, borderRadius: BorderRadius.circular(AppRadius.xs)),
            child: Icon(positive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                color: positive ? AppColors.success : AppColors.danger, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  transaction.description ?? transaction.type,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.slate800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(formatDate(transaction.createdAt), style: const TextStyle(fontSize: 10.5, color: AppColors.slate500)),
              ],
            ),
          ),
          Text(
            '${positive ? '+' : ''}${transaction.points} pts',
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.bold, color: positive ? AppColors.success : AppColors.danger),
          ),
        ],
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  final LoyaltyReward reward;
  final bool canRedeem;
  final bool isRedeeming;
  final VoidCallback onRedeem;

  const _RewardCard({
    required this.reward,
    required this.canRedeem,
    required this.isRedeeming,
    required this.onRedeem,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: canRedeem ? AppColors.brand : AppColors.slate200, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: AppColors.brandLight, borderRadius: BorderRadius.circular(AppRadius.xs)),
                child: const Icon(Icons.card_giftcard_rounded, color: AppColors.brandDark, size: 14),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppColors.brandLight, borderRadius: BorderRadius.circular(AppRadius.pill)),
                child: Text('${reward.pointsRequired} pts',
                    style: const TextStyle(color: AppColors.brandDark, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(reward.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.slate900),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Expanded(
            child: Text(reward.description,
                style: const TextStyle(color: AppColors.slate500, fontSize: 10.5),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
          SizedBox(
            width: double.infinity,
            height: 30,
            child: ElevatedButton(
              onPressed: (canRedeem && !isRedeeming) ? onRedeem : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: canRedeem ? AppColors.brand : AppColors.slate200,
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xs)),
              ),
              child: isRedeeming
                  ? const SizedBox(
                      width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(canRedeem ? 'Redeem' : 'Locked', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferralRow extends StatelessWidget {
  final ReferralItem item;
  final String Function(DateTime) formatDate;

  const _ReferralRow({required this.item, required this.formatDate});

  Color get _statusColor {
    switch (item.status) {
      case 'rewarded':
        return AppColors.success;
      case 'expired':
        return AppColors.danger;
      case 'qualified':
        return AppColors.info;
      default:
        return AppColors.warning;
    }
  }

  String get _statusLabel {
    switch (item.status) {
      case 'rewarded':
        return 'Rewarded';
      case 'expired':
        return 'Expired';
      case 'qualified':
        return 'Qualified';
      default:
        return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: AppColors.slate100, shape: BoxShape.circle),
            child: const Icon(Icons.person_rounded, color: AppColors.slate500, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.refereeName,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.slate800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(formatDate(item.referredAt), style: const TextStyle(fontSize: 10.5, color: AppColors.slate500)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              _statusLabel,
              style: TextStyle(color: _statusColor, fontSize: 10.5, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
