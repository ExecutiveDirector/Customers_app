// lib/screens/pesapal_webview.dart
//
// THE CORE FIX:
//   Flutter sends callback_url = backend callback endpoint to /payments/initiate.
//   Pesapal redirects to:
//     https://aquagas-backend.onrender.com/api/v1/payments/callback
//       ?OrderTrackingId=XXX&OrderMerchantReference=YYY
//   onNavigationRequest intercepts that URL BEFORE it loads,
//   extracts the params, and pushes PaymentConfirmationScreen directly.
//   The backend never needs to run its redirect logic for Flutter users.

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:aquagas/screens/payment_confirmation_screen.dart';

class PesapalWebView extends StatefulWidget {
  final String url;
  final String orderId;

  const PesapalWebView({
    Key? key,
    required this.url,
    required this.orderId,
  }) : super(key: key);

  @override
  State<PesapalWebView> createState() => _PesapalWebViewState();
}

class _PesapalWebViewState extends State<PesapalWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMsg = '';

  // This is the callback_url we send to the backend's /payments/initiate.
  // Pesapal will redirect here after payment with ?OrderTrackingId=&OrderMerchantReference=
  // We intercept this URL in onNavigationRequest BEFORE it ever loads.
  static const String _flutterCallbackBase =
      'https://aquagas-backend.onrender.com/api/v1/payments/callback';

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF5F7FA))
      // Real Chrome UA — Pesapal blocks the default Android WebView UA ("wv")
      // and shows a broken/blank page without this.
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 13; Pixel 7) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/120.0.0.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (NavigationRequest request) {
          final String url = request.url;
          debugPrint('🌐 WebView nav: $url');

          // ── INTERCEPT: Pesapal callback redirect ──────────────────────
          // Pesapal sends user to our callback URL with query params.
          // We catch it here (before it loads) and handle in Flutter.
          if (url.startsWith(_flutterCallbackBase)) {
            _handlePesapalCallback(url);
            return NavigationDecision.prevent; // don't actually load the URL
          }

          // Pesapal sometimes opens links in new tabs (isMainFrame = false).
          // Load them in the same WebView so they don't silently vanish.
          if (!request.isMainFrame) {
            _controller.loadRequest(Uri.parse(url));
            return NavigationDecision.prevent;
          }

          return NavigationDecision.navigate;
        },
        onPageStarted: (_) {
          if (mounted)
            setState(() {
              _isLoading = true;
              _hasError = false;
            });
        },
        onPageFinished: (String url) {
          if (mounted) setState(() => _isLoading = false);
          debugPrint('✅ Page loaded: $url');
        },
        onWebResourceError: (WebResourceError error) {
          debugPrint('❌ WebView error: ${error.description}');
          // Only surface main-frame errors — sub-resource errors (fonts,
          // analytics) are normal and shouldn't show the error screen.
          if (error.isForMainFrame ?? false) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _hasError = true;
                _errorMsg = error.description;
              });
            }
          }
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  // ── Handle Pesapal's callback redirect ─────────────────────────────────────
  void _handlePesapalCallback(String url) {
    final Uri uri = Uri.parse(url);
    final String? trackingId = uri.queryParameters['OrderTrackingId'];
    final String? merchantRef = uri.queryParameters['OrderMerchantReference'];

    debugPrint('🎯 Pesapal callback intercepted');
    debugPrint('   OrderTrackingId      : $trackingId');
    debugPrint('   OrderMerchantReference: $merchantRef');

    if (!mounted) return;

    // Navigate to the confirmation screen.
    // PaymentConfirmationScreen takes positional named params (from existing code).
    Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute<void>(
        builder: (_) => PaymentConfirmationScreen(
          paymentOption: 'Pesapal',
          orderId: merchantRef ?? widget.orderId,
          address: null,
        ),
      ),
    );
  }

  // ── Back / cancel handling ──────────────────────────────────────────────────
  Future<bool> _onWillPop() async {
    // Try going back within the WebView first (e.g. M-Pesa prompt → main page)
    final bool canGoBack = await _controller.canGoBack();
    if (canGoBack) {
      await _controller.goBack();
      return false;
    }

    final bool? leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Payment?'),
        content: const Text(
          'Are you sure you want to cancel?\nYour order will not be confirmed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Stay'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (leave == true) {
      if (mounted) Navigator.of(context).pop(false);
    }
    return false;
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('Complete Payment',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF10B981),
          iconTheme: const IconThemeData(color: Colors.white),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async => _onWillPop(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              tooltip: 'Reload',
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _hasError = false;
                });
                _controller.reload();
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            if (!_hasError) WebViewWidget(controller: _controller),
            if (_hasError) _errorWidget(),
            if (_isLoading && !_hasError) _loadingWidget(),
          ],
        ),
      ),
    );
  }

  Widget _loadingWidget() => Container(
        color: const Color(0xFFF5F7FA),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: const Icon(Icons.lock_outline,
                    size: 36, color: Color(0xFF10B981)),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(
                  color: Color(0xFF10B981), strokeWidth: 3),
              const SizedBox(height: 16),
              const Text('Loading secure payment page…',
                  style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              const Text('Please do not close this screen',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            ],
          ),
        ),
      );

  Widget _errorWidget() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.wifi_off_rounded,
                    size: 40, color: Colors.red.shade400),
              ),
              const SizedBox(height: 24),
              const Text('Could Not Load Payment Page',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B)),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Check your internet connection and try again.'
                '${_errorMsg.isNotEmpty ? '\n\n$_errorMsg' : ''}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade400),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Go Back'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                        _hasError = false;
                      });
                      _controller.loadRequest(Uri.parse(widget.url));
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}
