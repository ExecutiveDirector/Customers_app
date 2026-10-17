// lib/features/chat/order_chat_page.dart
// Chat with the delivery rider. Phone numbers stay private: the server hides
// any number typed into a message. Polls every 4s while open.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:aquagas/services/auth_service.dart';

class _Msg {
  final String id;
  final bool mine;
  final String body;
  final DateTime? at;
  _Msg(this.id, this.mine, this.body, this.at);
}

class OrderChatPage extends StatefulWidget {
  final String orderId;
  const OrderChatPage({super.key, required this.orderId});

  @override
  State<OrderChatPage> createState() => _OrderChatPageState();
}

class _OrderChatPageState extends State<OrderChatPage> {
  static const String _baseUrl = 'https://aquagas-backend.onrender.com/api/v1';
  final AuthService _auth = AuthService();
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_Msg> _msgs = <_Msg>[];
  Timer? _timer;
  bool _canSend = true;
  String? _closedReason;
  bool _sending = false;
  bool _loadFailed = false;

  static const List<String> _quick = <String>[
    'Please come to the gate',
    "I'm at the door",
    'Call me when you arrive',
    'Thank you!',
  ];

  Uri get _uri => Uri.parse('$_baseUrl/orders/${widget.orderId}/messages');

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<Map<String, String>> _headers() async {
    final String? token = await _auth.getToken();
    return <String, String>{
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> _load() async {
    try {
      final int after = _msgs.isEmpty ? 0 : int.tryParse(_msgs.last.id) ?? 0;
      final Uri uri = after > 0
          ? _uri.replace(queryParameters: <String, String>{'after': '$after'})
          : _uri;
      final http.Response res = await http
          .get(uri, headers: await _headers())
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final dynamic decoded = jsonDecode(res.body);
      final Map<String, dynamic> data =
          decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
      final List<_Msg> fresh = ((data['messages'] as List<dynamic>?) ?? <dynamic>[])
          .map((dynamic e) => Map<String, dynamic>.from(e as Map))
          .map((Map<String, dynamic> m) => _Msg(
              m['id'].toString(),
              m['mine'] == true,
              (m['body'] ?? '').toString(),
              DateTime.tryParse('${m['created_at']}')?.toLocal()))
          .where((_Msg m) => !_msgs.any((_Msg x) => x.id == m.id))
          .toList();
      if (!mounted) return;
      setState(() {
        _loadFailed = false;
        _canSend = data['can_send'] != false;
        _closedReason = data['closed_reason']?.toString();
        if (fresh.isNotEmpty) _msgs.addAll(fresh);
      });
      if (fresh.isNotEmpty) _toBottom();
    } catch (_) {
      if (mounted && _msgs.isEmpty) setState(() => _loadFailed = true);
    }
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut);
        }
      });

  Future<void> _send(String text) async {
    final String body = text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final http.Response res = await http
          .post(_uri,
              headers: await _headers(), body: jsonEncode(<String, dynamic>{'body': body}))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode >= 300) throw Exception('HTTP ${res.statusCode}');
      _input.clear();
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Couldn't send. Check your connection and try again."),
            behavior: SnackBarBehavior.floating));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _time(DateTime? t) => t == null
      ? ''
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Chat with your rider')),
      body: Column(
        children: <Widget>[
          Expanded(
            child: _msgs.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _loadFailed
                            ? "Couldn't load messages."
                            : 'No messages yet. Your phone number stays private.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: _msgs.length,
                    itemBuilder: (BuildContext _, int i) {
                      final _Msg m = _msgs[i];
                      return Align(
                        alignment:
                            m.mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.75),
                          decoration: BoxDecoration(
                            color: m.mine ? cs.primary : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: <Widget>[
                              Text(m.body,
                                  style: TextStyle(
                                      color: m.mine ? Colors.white : Colors.black87)),
                              const SizedBox(height: 2),
                              Text(_time(m.at),
                                  style: TextStyle(
                                      fontSize: 10,
                                      color:
                                          m.mine ? Colors.white70 : Colors.black45)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (!_canSend)
            Container(
              width: double.infinity,
              color: Colors.amber.shade50,
              padding: const EdgeInsets.all(12),
              child: Text(_closedReason ?? 'Chat is closed for this order.'),
            )
          else ...<Widget>[
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: <Widget>[
                  for (final String q in _quick)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                          label: Text(q, style: const TextStyle(fontSize: 12)),
                          onPressed: _sending ? null : () => _send(q)),
                    ),
                ],
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _input,
                        maxLength: 500,
                        textInputAction: TextInputAction.send,
                        onSubmitted: _send,
                        decoration: const InputDecoration(
                            hintText: 'Message your rider',
                            counterText: '',
                            border: OutlineInputBorder()),
                      ),
                    ),
                    IconButton(
                      onPressed: _sending ? null : () => _send(_input.text),
                      icon: Icon(Icons.send, color: cs.primary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
