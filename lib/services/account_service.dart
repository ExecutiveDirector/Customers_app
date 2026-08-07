// lib/services/account_service.dart
//
// Backs the redesigned Account page (screens/account_screen.dart). Talks to
// the /api/v1/users wallet, loyalty and account-summary endpoints — all of
// which previously either didn't exist or were broken on the backend (wrong
// Sequelize model names), so this account page was rendering hardcoded mock
// data. See controllers/userController.js for the corresponding fixes.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────

class AccountSummary {
  final int userId;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phoneNumber;
  final String? avatarUrl;
  final bool isPremium;
  final String referralCode;
  final int totalOrders;
  final double totalSpent;
  final int loyaltyPoints;
  final double walletBalance;
  final double pendingBalance;
  final double walletTotalEarned;
  final double walletTotalSpent;

  const AccountSummary({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.isPremium,
    required this.referralCode,
    required this.totalOrders,
    required this.totalSpent,
    required this.loyaltyPoints,
    required this.walletBalance,
    required this.pendingBalance,
    required this.walletTotalEarned,
    required this.walletTotalSpent,
    this.email,
    this.phoneNumber,
    this.avatarUrl,
  });

  String get fullName => '$firstName $lastName'.trim();

  static double _num(dynamic v) => (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;
  static int _int(dynamic v) => (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;

  factory AccountSummary.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> user =
        (json['user'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final Map<String, dynamic> wallet =
        (json['wallet'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

    return AccountSummary(
      userId: _int(user['user_id']),
      firstName: user['first_name']?.toString() ?? '',
      lastName: user['last_name']?.toString() ?? '',
      email: user['email']?.toString(),
      phoneNumber: user['phone_number']?.toString(),
      avatarUrl: user['avatar_url']?.toString(),
      isPremium: user['is_premium'] == true || user['is_premium'] == 1,
      referralCode: user['referral_code']?.toString() ?? '',
      totalOrders: _int(user['total_orders']),
      totalSpent: _num(user['total_spent']),
      loyaltyPoints: _int(user['loyalty_points']),
      walletBalance: _num(wallet['balance']),
      pendingBalance: _num(wallet['pending_balance']),
      walletTotalEarned: _num(wallet['total_earned']),
      walletTotalSpent: _num(wallet['total_spent']),
    );
  }
}

class WalletTransactionItem {
  final String id;
  final String type; // credit | debit | hold | release | cashback | refund
  final double amount;
  final double newBalance;
  final String? description;
  final DateTime createdAt;

  const WalletTransactionItem({
    required this.id,
    required this.type,
    required this.amount,
    required this.newBalance,
    required this.createdAt,
    this.description,
  });

  bool get isCredit => <String>['credit', 'cashback', 'refund', 'release'].contains(type);

  factory WalletTransactionItem.fromJson(Map<String, dynamic> json) {
    return WalletTransactionItem(
      id: json['wallet_transaction_id']?.toString() ?? '',
      type: json['transaction_type']?.toString() ?? 'credit',
      amount: (json['amount'] is num)
          ? (json['amount'] as num).toDouble()
          : double.tryParse('${json['amount']}') ?? 0,
      newBalance: (json['new_balance'] is num)
          ? (json['new_balance'] as num).toDouble()
          : double.tryParse('${json['new_balance']}') ?? 0,
      description: json['description']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class LoyaltyTransactionItem {
  final String id;
  final String type; // earned | redeemed | expired | bonus | adjustment
  final int points;
  final int newBalance;
  final String? description;
  final DateTime createdAt;

  const LoyaltyTransactionItem({
    required this.id,
    required this.type,
    required this.points,
    required this.newBalance,
    required this.createdAt,
    this.description,
  });

  factory LoyaltyTransactionItem.fromJson(Map<String, dynamic> json) {
    return LoyaltyTransactionItem(
      id: json['point_transaction_id']?.toString() ?? '',
      type: json['transaction_type']?.toString() ?? 'earned',
      points: (json['points'] is num)
          ? (json['points'] as num).toInt()
          : int.tryParse('${json['points']}') ?? 0,
      newBalance: (json['new_balance'] is num)
          ? (json['new_balance'] as num).toInt()
          : int.tryParse('${json['new_balance']}') ?? 0,
      description: json['description']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class LoyaltyReward {
  final int rewardId;
  final String name;
  final String type; // discount_percentage | discount_fixed | free_delivery | free_product | cashback
  final int pointsRequired;
  final double? value;

  const LoyaltyReward({
    required this.rewardId,
    required this.name,
    required this.type,
    required this.pointsRequired,
    this.value,
  });

  String get description {
    switch (type) {
      case 'discount_percentage':
        return 'Save ${value?.toStringAsFixed(0) ?? ''}% on your order';
      case 'discount_fixed':
        return 'Save KES ${value?.toStringAsFixed(0) ?? ''}';
      case 'free_delivery':
        return 'Free delivery on your next order';
      case 'cashback':
        return 'Get KES ${value?.toStringAsFixed(0) ?? ''} cashback';
      case 'free_product':
        return 'A free product on your next order';
      default:
        return 'Special reward';
    }
  }

  factory LoyaltyReward.fromJson(Map<String, dynamic> json) {
    return LoyaltyReward(
      rewardId: (json['reward_id'] is num)
          ? (json['reward_id'] as num).toInt()
          : int.tryParse('${json['reward_id']}') ?? 0,
      name: json['reward_name']?.toString() ?? 'Reward',
      type: json['reward_type']?.toString() ?? 'discount_percentage',
      pointsRequired: (json['points_required'] is num)
          ? (json['points_required'] as num).toInt()
          : int.tryParse('${json['points_required']}') ?? 0,
      value: json['reward_value'] == null
          ? null
          : ((json['reward_value'] is num)
              ? (json['reward_value'] as num).toDouble()
              : double.tryParse('${json['reward_value']}')),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────

class AccountService {
  static const String _baseUrl = 'https://aquagas-backend.onrender.com/api/v1/users';

  final AuthService _authService = AuthService();

  Future<Map<String, String>> _headers() async {
    final String? token = await _authService.getToken();
    return <String, String>{
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Exception _friendlyError(Object e) {
    if (e is TimeoutException) {
      return Exception('Connection timed out. Please try again.');
    }
    if (e is SocketException) {
      return Exception('No internet connection. Please check your network.');
    }
    if (e is Exception && e.toString().startsWith('Exception: ')) return e;
    return Exception('Something went wrong. Please try again.');
  }

  Future<AccountSummary> getAccountSummary() async {
    try {
      final http.Response response = await http
          .get(Uri.parse('$_baseUrl/account-summary'), headers: await _headers())
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return AccountSummary.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      }
      throw Exception('Failed to load account (${response.statusCode}).');
    } catch (e) {
      throw _friendlyError(e);
    }
  }

  Future<List<WalletTransactionItem>> getWalletTransactions() async {
    try {
      final http.Response response = await http
          .get(Uri.parse('$_baseUrl/wallet/transactions'), headers: await _headers())
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        return data
            .map((dynamic e) => WalletTransactionItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw Exception('Failed to load wallet transactions (${response.statusCode}).');
    } catch (e) {
      throw _friendlyError(e);
    }
  }

  Future<List<LoyaltyTransactionItem>> getLoyaltyHistory() async {
    try {
      final http.Response response = await http
          .get(Uri.parse('$_baseUrl/loyalty-history'), headers: await _headers())
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        return data
            .map((dynamic e) => LoyaltyTransactionItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw Exception('Failed to load points history (${response.statusCode}).');
    } catch (e) {
      throw _friendlyError(e);
    }
  }

  Future<List<LoyaltyReward>> getLoyaltyRewards() async {
    try {
      final http.Response response = await http
          .get(Uri.parse('$_baseUrl/loyalty-rewards'), headers: await _headers())
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        return data
            .map((dynamic e) => LoyaltyReward.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw Exception('Failed to load rewards (${response.statusCode}).');
    } catch (e) {
      throw _friendlyError(e);
    }
  }

  /// Redeems a reward. Returns the new points balance on success; throws
  /// with the backend's message (e.g. "Not enough points") on failure.
  Future<int> redeemReward(int rewardId) async {
    try {
      final http.Response response = await http
          .post(Uri.parse('$_baseUrl/loyalty-rewards/$rewardId/redeem'), headers: await _headers())
          .timeout(const Duration(seconds: 15));

      final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return (data['newBalance'] is num) ? (data['newBalance'] as num).toInt() : 0;
      }
      throw Exception(data['error']?.toString() ?? 'Failed to redeem reward.');
    } catch (e) {
      throw _friendlyError(e);
    }
  }
}
