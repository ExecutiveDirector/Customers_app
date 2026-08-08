// lib/services/review_service.dart
//
// Backs the "Rate your order" flow. Talks to /api/v1/reviews, which lets a
// customer rate the vendor, outlet, rider, each product, and the overall
// AquaGas service for any order of theirs that's been delivered.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────

/// One thing a customer could rate within an order (a vendor, an outlet, a
/// rider, or a product), and whether they already have.
class ReviewableTarget {
  final int id;
  final String name;
  final bool alreadyReviewed;

  const ReviewableTarget({required this.id, required this.name, required this.alreadyReviewed});

  factory ReviewableTarget.fromJson(Map<String, dynamic> json) {
    return ReviewableTarget(
      id: (json['id'] is num) ? (json['id'] as num).toInt() : int.tryParse('${json['id']}') ?? 0,
      name: json['name']?.toString() ?? '',
      alreadyReviewed: json['alreadyReviewed'] == true,
    );
  }
}

/// Everything a customer can rate for one order, and what's left to do.
class ReviewableOrder {
  final int orderId;
  final String orderStatus;
  final bool canReview;
  final ReviewableTarget? vendor;
  final ReviewableTarget? outlet;
  final ReviewableTarget? rider;
  final List<ReviewableTarget> products;
  final bool platformAlreadyReviewed;

  const ReviewableOrder({
    required this.orderId,
    required this.orderStatus,
    required this.canReview,
    required this.products,
    required this.platformAlreadyReviewed,
    this.vendor,
    this.outlet,
    this.rider,
  });

  /// True once every reviewable item for this order has been rated.
  bool get isFullyReviewed {
    final List<bool> flags = <bool>[
      if (vendor != null) vendor!.alreadyReviewed,
      if (outlet != null) outlet!.alreadyReviewed,
      if (rider != null) rider!.alreadyReviewed,
      ...products.map((ReviewableTarget p) => p.alreadyReviewed),
      platformAlreadyReviewed,
    ];
    return flags.isNotEmpty && flags.every((bool f) => f);
  }

  factory ReviewableOrder.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawProducts = (json['products'] as List<dynamic>?) ?? const <dynamic>[];
    return ReviewableOrder(
      orderId: (json['orderId'] is num) ? (json['orderId'] as num).toInt() : int.tryParse('${json['orderId']}') ?? 0,
      orderStatus: json['orderStatus']?.toString() ?? '',
      canReview: json['canReview'] == true,
      vendor: json['vendor'] == null ? null : ReviewableTarget.fromJson(json['vendor'] as Map<String, dynamic>),
      outlet: json['outlet'] == null ? null : ReviewableTarget.fromJson(json['outlet'] as Map<String, dynamic>),
      rider: json['rider'] == null ? null : ReviewableTarget.fromJson(json['rider'] as Map<String, dynamic>),
      products: rawProducts.map((dynamic p) => ReviewableTarget.fromJson(p as Map<String, dynamic>)).toList(),
      platformAlreadyReviewed: (json['platform'] as Map<String, dynamic>?)?['alreadyReviewed'] == true,
    );
  }
}

/// review type sent to / received from the backend.
enum ReviewType { product, vendor, outlet, rider, platform }

extension ReviewTypeApi on ReviewType {
  String get apiValue => name;
}

class ReviewSummary {
  final double averageRating;
  final int totalReviews;
  final Map<int, int> distribution; // star (1-5) -> count

  const ReviewSummary({required this.averageRating, required this.totalReviews, required this.distribution});

  factory ReviewSummary.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> rawDist = (json['distribution'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    return ReviewSummary(
      averageRating: (json['averageRating'] is num) ? (json['averageRating'] as num).toDouble() : 0,
      totalReviews: (json['totalReviews'] is num) ? (json['totalReviews'] as num).toInt() : 0,
      distribution: rawDist.map((String k, dynamic v) => MapEntry(int.tryParse(k) ?? 0, (v is num) ? v.toInt() : 0)),
    );
  }

  static const ReviewSummary empty = ReviewSummary(
    averageRating: 0,
    totalReviews: 0,
    distribution: <int, int>{5: 0, 4: 0, 3: 0, 2: 0, 1: 0},
  );
}

class ReviewItem {
  final int reviewId;
  final double overallRating;
  final String? title;
  final String? text;
  final bool isVerified;
  final DateTime createdAt;
  final String reviewerName;
  final String? reviewerAvatar;
  final String? vendorResponse;

  const ReviewItem({
    required this.reviewId,
    required this.overallRating,
    required this.isVerified,
    required this.createdAt,
    required this.reviewerName,
    this.title,
    this.text,
    this.reviewerAvatar,
    this.vendorResponse,
  });

  factory ReviewItem.fromJson(Map<String, dynamic> json) {
    return ReviewItem(
      reviewId: (json['review_id'] is num) ? (json['review_id'] as num).toInt() : int.tryParse('${json['review_id']}') ?? 0,
      overallRating: (json['overall_rating'] is num) ? (json['overall_rating'] as num).toDouble() : 0,
      title: json['title']?.toString(),
      text: json['text']?.toString(),
      isVerified: json['is_verified'] == true,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      reviewerName: json['reviewer_name']?.toString() ?? 'AquaGas user',
      reviewerAvatar: json['reviewer_avatar']?.toString(),
      vendorResponse: json['vendor_response']?.toString(),
    );
  }
}

class ReviewListPage {
  final ReviewSummary summary;
  final int page;
  final bool hasMore;
  final List<ReviewItem> reviews;

  const ReviewListPage({
    required this.summary,
    required this.page,
    required this.hasMore,
    required this.reviews,
  });

  factory ReviewListPage.fromJson(Map<String, dynamic> json) {
    final List<dynamic> raw = (json['reviews'] as List<dynamic>?) ?? const <dynamic>[];
    return ReviewListPage(
      summary: ReviewSummary.fromJson((json['summary'] as Map<String, dynamic>?) ?? const <String, dynamic>{}),
      page: (json['page'] is num) ? (json['page'] as num).toInt() : 1,
      hasMore: json['has_more'] == true,
      reviews: raw.map((dynamic r) => ReviewItem.fromJson(r as Map<String, dynamic>)).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────

class ReviewService {
  static const String _baseUrl = 'https://aquagas-backend.onrender.com/api/v1/reviews';

  final AuthService _authService = AuthService();

  Future<Map<String, String>> _headers() async {
    final String? token = await _authService.getToken();
    return <String, String>{
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Exception _friendlyError(Object e) {
    if (e is TimeoutException) return Exception('Connection timed out. Please try again.');
    if (e is SocketException) return Exception('No internet connection. Please check your network.');
    if (e is Exception && e.toString().startsWith('Exception: ')) return e;
    return Exception('Something went wrong. Please try again.');
  }

  Future<ReviewableOrder> getReviewableForOrder(String orderId) async {
    try {
      final http.Response response = await http
          .get(Uri.parse('$_baseUrl/reviewable/$orderId'), headers: await _headers())
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return ReviewableOrder.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      }
      throw Exception('Failed to load review status for this order.');
    } catch (e) {
      throw _friendlyError(e);
    }
  }

  /// Submits one review. [targetId] is required for every type except
  /// [ReviewType.platform]. Returns the points the reviewer just earned.
  Future<int> submitReview({
    required String orderId,
    required ReviewType type,
    int? targetId,
    required double overallRating,
    String? title,
    String? text,
    bool isAnonymous = false,
  }) async {
    try {
      final http.Response response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: await _headers(),
            body: jsonEncode(<String, dynamic>{
              'orderId': orderId,
              'reviewType': type.apiValue,
              if (targetId != null) 'targetId': targetId,
              'overallRating': overallRating,
              if (title != null && title.isNotEmpty) 'title': title,
              if (text != null && text.isNotEmpty) 'text': text,
              'isAnonymous': isAnonymous,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 201) {
        return (data['pointsEarned'] is num) ? (data['pointsEarned'] as num).toInt() : 0;
      }
      throw Exception(data['error']?.toString() ?? 'Failed to submit review.');
    } catch (e) {
      throw _friendlyError(e);
    }
  }

  Future<ReviewListPage> getReviews({
    required ReviewType type,
    int? targetId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final Map<String, String> query = <String, String>{
        'type': type.apiValue,
        if (targetId != null) 'targetId': '$targetId',
        'page': '$page',
        'limit': '$limit',
      };
      final Uri uri = Uri.parse(_baseUrl).replace(queryParameters: query);
      final http.Response response = await http.get(uri, headers: await _headers()).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return ReviewListPage.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      }
      throw Exception('Failed to load reviews.');
    } catch (e) {
      throw _friendlyError(e);
    }
  }

  Future<ReviewSummary> getSummary({required ReviewType type, int? targetId}) async {
    try {
      final Map<String, String> query = <String, String>{
        'type': type.apiValue,
        if (targetId != null) 'targetId': '$targetId',
      };
      final Uri uri = Uri.parse('$_baseUrl/summary').replace(queryParameters: query);
      final http.Response response = await http.get(uri, headers: await _headers()).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return ReviewSummary.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      }
      throw Exception('Failed to load rating summary.');
    } catch (e) {
      throw _friendlyError(e);
    }
  }
}
