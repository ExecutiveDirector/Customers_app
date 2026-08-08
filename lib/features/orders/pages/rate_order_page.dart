// lib/features/orders/pages/rate_order_page.dart
//
// Lets a customer rate everything tied to one delivered order: the vendor,
// the outlet, the rider, each product they bought, and AquaGas's overall
// service — each rated and submitted independently, each earning a small
// points reward. Replaces the old stub that only had a single generic
// star rating wired to an OrderService.submitReview() that threw
// UnimplementedError.
import 'package:flutter/material.dart';

import 'package:aquagas/services/review_service.dart';
import 'package:aquagas/theme/app_colors.dart';

class RateOrderPage extends StatefulWidget {
  final String orderId;

  const RateOrderPage({super.key, required this.orderId});

  @override
  State<RateOrderPage> createState() => _RateOrderPageState();
}

class _RateOrderPageState extends State<RateOrderPage> {
  final ReviewService _service = ReviewService();

  bool _isLoading = true;
  String? _error;
  ReviewableOrder? _data;
  int _pointsEarnedThisSession = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final ReviewableOrder data = await _service.getReviewableForOrder(widget.orderId);
      if (!mounted) return;
      setState(() {
        _data = data;
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

  void _onSectionSubmitted(int pointsEarned) {
    setState(() => _pointsEarnedThisSession += pointsEarned);
    // Refresh from the server so "alreadyReviewed" flags stay accurate
    // even if the user backgrounds the app mid-flow.
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Rate Your Order'),
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.slate900,
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.brand));
    }
    if (_error != null) {
      return _buildMessageState(
        icon: Icons.cloud_off_rounded,
        message: _error!,
        actionLabel: 'Try Again',
        onAction: _load,
      );
    }
    final ReviewableOrder? data = _data;
    if (data == null) return const SizedBox.shrink();

    if (!data.canReview) {
      return _buildMessageState(
        icon: Icons.hourglass_top_rounded,
        message: 'You can rate this order once it has been delivered.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        if (_pointsEarnedThisSession > 0)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.emoji_events_rounded, color: AppColors.success, size: 18),
                const SizedBox(width: 8),
                Text(
                  'You\'ve earned $_pointsEarnedThisSession points from this order\'s reviews!',
                  style: const TextStyle(color: AppColors.success, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        if (data.vendor != null)
          _ReviewCard(
            key: ValueKey<String>('vendor-${data.vendor!.id}'),
            icon: Icons.storefront_rounded,
            label: 'Rate the Vendor',
            targetName: data.vendor!.name,
            alreadyReviewed: data.vendor!.alreadyReviewed,
            onSubmit: (double rating, String? text) => _service.submitReview(
              orderId: widget.orderId,
              type: ReviewType.vendor,
              targetId: data.vendor!.id,
              overallRating: rating,
              text: text,
            ),
            onSubmitted: _onSectionSubmitted,
          ),
        if (data.outlet != null)
          _ReviewCard(
            key: ValueKey<String>('outlet-${data.outlet!.id}'),
            icon: Icons.store_mall_directory_rounded,
            label: 'Rate the Outlet',
            targetName: data.outlet!.name,
            alreadyReviewed: data.outlet!.alreadyReviewed,
            onSubmit: (double rating, String? text) => _service.submitReview(
              orderId: widget.orderId,
              type: ReviewType.outlet,
              targetId: data.outlet!.id,
              overallRating: rating,
              text: text,
            ),
            onSubmitted: _onSectionSubmitted,
          ),
        if (data.rider != null)
          _ReviewCard(
            key: ValueKey<String>('rider-${data.rider!.id}'),
            icon: Icons.delivery_dining_rounded,
            label: 'Rate Your Rider',
            targetName: data.rider!.name,
            alreadyReviewed: data.rider!.alreadyReviewed,
            onSubmit: (double rating, String? text) => _service.submitReview(
              orderId: widget.orderId,
              type: ReviewType.rider,
              targetId: data.rider!.id,
              overallRating: rating,
              text: text,
            ),
            onSubmitted: _onSectionSubmitted,
          ),
        for (final ReviewableTarget product in data.products)
          _ReviewCard(
            key: ValueKey<String>('product-${product.id}'),
            icon: Icons.propane_tank_rounded,
            label: 'Rate This Product',
            targetName: product.name,
            alreadyReviewed: product.alreadyReviewed,
            onSubmit: (double rating, String? text) => _service.submitReview(
              orderId: widget.orderId,
              type: ReviewType.product,
              targetId: product.id,
              overallRating: rating,
              text: text,
            ),
            onSubmitted: _onSectionSubmitted,
          ),
        _ReviewCard(
          icon: Icons.local_shipping_rounded,
          label: 'Rate AquaGas Service',
          targetName: 'Overall delivery experience',
          alreadyReviewed: data.platformAlreadyReviewed,
          onSubmit: (double rating, String? text) => _service.submitReview(
            orderId: widget.orderId,
            type: ReviewType.platform,
            overallRating: rating,
            text: text,
          ),
          onSubmitted: _onSectionSubmitted,
        ),
        if (data.isFullyReviewed)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: Column(
                children: <Widget>[
                  const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 36),
                  const SizedBox(height: 8),
                  const Text(
                    'All done — thanks for your feedback!',
                    style: TextStyle(color: AppColors.slate600, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMessageState({
    required IconData icon,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        const SizedBox(height: 80),
        Icon(icon, size: 56, color: AppColors.slate400),
        const SizedBox(height: 16),
        Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.slate600, fontSize: 15)),
        if (actionLabel != null && onAction != null) ...<Widget>[
          const SizedBox(height: 20),
          Center(
            child: ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
              ),
              child: Text(actionLabel),
            ),
          ),
        ],
      ],
    );
  }
}

/// A single self-contained "rate this thing" card: star picker, optional
/// comment, its own submit button and its own loading/submitted state.
class _ReviewCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final String targetName;
  final bool alreadyReviewed;
  final Future<int> Function(double rating, String? text) onSubmit;
  final void Function(int pointsEarned) onSubmitted;

  const _ReviewCard({
    super.key,
    required this.icon,
    required this.label,
    required this.targetName,
    required this.alreadyReviewed,
    required this.onSubmit,
    required this.onSubmitted,
  });

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  double _rating = 0;
  final TextEditingController _textController = TextEditingController();
  bool _submitting = false;
  bool _justSubmitted = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tap a star to rate first')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final int points = await widget.onSubmit(_rating, _textController.text.trim());
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _justSubmitted = true;
      });
      widget.onSubmitted(points);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Thanks! +$points points'), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool done = widget.alreadyReviewed || _justSubmitted;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.brandLight, borderRadius: BorderRadius.circular(AppRadius.xs)),
                child: Icon(widget.icon, color: AppColors.brandDark, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(widget.label,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.slate900)),
                    Text(widget.targetName,
                        style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (done) const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22),
            ],
          ),
          if (!done) ...<Widget>[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(5, (int i) {
                final int starValue = i + 1;
                return IconButton(
                  onPressed: _submitting ? null : () => setState(() => _rating = starValue.toDouble()),
                  icon: Icon(
                    starValue <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: starValue <= _rating ? Colors.amber : AppColors.slate300,
                    size: 30,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                );
              }),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _textController,
              enabled: !_submitting,
              maxLines: 2,
              maxLength: 280,
              decoration: InputDecoration(
                hintText: 'Add a comment (optional)',
                hintStyle: const TextStyle(fontSize: 12.5),
                isDense: true,
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: const BorderSide(color: AppColors.slate200),
                ),
              ),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                ),
                child: _submitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Submit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
