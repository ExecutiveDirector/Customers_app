// lib/screens/wallet_topup_screen.dart
//
// Add money to the AquaGas wallet. The amount is chosen here, the payment happens on the
// Pesapal page (M-Pesa / card), and the SERVER confirms the payment with Pesapal and credits
// the wallet — this screen never decides that money arrived.

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:aquagas/services/account_service.dart';

class WalletTopUpScreen extends StatefulWidget {
  const WalletTopUpScreen({super.key});

  @override
  State<WalletTopUpScreen> createState() => _WalletTopUpScreenState();
}

class _WalletTopUpScreenState extends State<WalletTopUpScreen> {
  static const List<int> _quick = <int>[500, 1000, 2000, 5000];
  static const double _min = 50;
  static const double _max = 70000;

  final AccountService _service = AccountService();
  final TextEditingController _amount = TextEditingController(text: '1000');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  double? get _value => double.tryParse(_amount.text.trim());

  Future<void> _continue() async {
    final double? v = _value;
    if (v == null || v < _min || v > _max) {
      setState(() => _error = 'Enter an amount between KES ${_min.toInt()} and KES ${_max.toInt()}.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ({String redirectUrl, String trackingId}) start = await _service.startTopUp(v);
      if (!mounted) return;
      final String? result = await Navigator.of(context).push<String>(
        MaterialPageRoute<String>(
          builder: (_) => _TopUpWebView(url: start.redirectUrl, trackingId: start.trackingId, service: _service),
        ),
      );
      if (!mounted) return;
      if (result == 'completed') {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() {
        _error = result == 'failed'
            ? 'The payment did not go through. You have not been charged.'
            : result == 'pending'
                ? 'We have not received confirmation yet. If you paid, your balance will update shortly — pull to refresh on the account page.'
                : null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Top up wallet')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          const Text('How much would you like to add?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final int q in _quick)
                ChoiceChip(
                  label: Text('KES $q'),
                  selected: _value == q.toDouble(),
                  onSelected: _busy ? null : (_) => setState(() => _amount.text = '$q'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amount,
            enabled: !_busy,
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            decoration: const InputDecoration(labelText: 'Amount (KES)', border: OutlineInputBorder()),
            onChanged: (_) => setState(() => _error = null),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _busy ? null : _continue,
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Continue to payment'),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'You will pay securely with M-Pesa or card. Your wallet is credited only after the payment is confirmed.',
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Shows the Pesapal page. When Pesapal redirects back, the page is closed and the payment is verified.
class _TopUpWebView extends StatefulWidget {
  final String url;
  final String trackingId;
  final AccountService service;
  const _TopUpWebView({required this.url, required this.trackingId, required this.service});

  @override
  State<_TopUpWebView> createState() => _TopUpWebViewState();
}

class _TopUpWebViewState extends State<_TopUpWebView> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // Pesapal shows a blank page to the default Android WebView user agent.
      ..setUserAgent('Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36')
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (NavigationRequest r) {
          // Pesapal redirects here when the customer is done (paid, failed or cancelled).
          if (r.url.contains('topup-callback') || r.url.contains('/payments/callback')) {
            _finish();
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _finish() async {
    if (_verifying) return;
    setState(() => _verifying = true);
    // M-Pesa can take a few seconds to settle: check up to 4 times.
    String result = 'pending';
    for (int i = 0; i < 4; i++) {
      result = await widget.service.verifyTopUp(widget.trackingId);
      if (result != 'pending') break;
      await Future<void>.delayed(const Duration(seconds: 3));
    }
    if (mounted) Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pay'),
        actions: <Widget>[
          // If the customer paid but the redirect never came back, they can check manually.
          TextButton(onPressed: _verifying ? null : _finish, child: const Text('I have paid', style: TextStyle(color: Colors.white))),
        ],
      ),
      body: Stack(
        children: <Widget>[
          WebViewWidget(controller: _controller),
          if (_loading || _verifying)
            Container(
              color: Colors.white70,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const CircularProgressIndicator(),
                  if (_verifying) const Padding(padding: EdgeInsets.only(top: 12), child: Text('Confirming your payment…')),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
