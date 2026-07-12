// lib/screens/help_support_screen.dart
//
// Replaces drawer.dart's _showHelpDialog() — a static AlertDialog with a
// placeholder phone number that didn't do anything. The backend already
// has a full ticket system (support_tickets/support_messages) that this
// screen is the first thing in the app to actually call.
//
// NOTE ON THE "CALL US" NUMBER BELOW:
// I've set it to 0710820666 (the AquaGas business line on file). If
// support should ring a different line than order dispatch, change
// _supportPhone/_supportEmail below.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:aquagas/services/order_service.dart';
import 'package:aquagas/services/support_service.dart';
import 'package:aquagas/theme/app_colors.dart';

const String _supportPhone = '0710820666';
const String _supportEmail = 'support@aquagas.co.ke';

String _categoryLabel(String raw) {
  switch (raw) {
    case 'order_issue':
      return 'Order issue';
    case 'delivery_problem':
      return 'Delivery problem';
    case 'payment_issue':
      return 'Payment issue';
    case 'product_quality':
      return 'Product quality';
    case 'account_issue':
      return 'Account issue';
    case 'technical_support':
      return 'App / technical support';
    case 'billing_inquiry':
      return 'Billing inquiry';
    default:
      return 'Other';
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'open':
      return AppColors.blue500;
    case 'in_progress':
      return AppColors.amber500;
    case 'resolved':
    case 'closed':
      return AppColors.green600;
    default:
      return AppColors.slate500;
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'in_progress':
      return 'In progress';
    default:
      return status.isEmpty
          ? 'Open'
          : '${status[0].toUpperCase()}${status.substring(1)}';
  }
}

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final SupportService _service = SupportService();
  List<SupportTicket>? _tickets;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final List<SupportTicket> tickets = await _service.getMyTickets();
      if (!mounted) return;
      setState(() => _tickets = tickets);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _call() async {
    final Uri uri = Uri(scheme: 'tel', path: _supportPhone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _email() async {
    final Uri uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      query: 'subject=AquaGas support request',
    );
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openNewTicket() async {
    final Map<String, dynamic>? result =
        await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewTicketSheet(service: _service),
    );
    if (result == null || result['success'] != true) return;

    _load();
    if (!mounted) return;

    if (result['attachmentWarning'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Request submitted. Some photos could not be uploaded — you can add them later by replying on the ticket.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your request has been submitted.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openTicket(SupportTicket ticket) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            _TicketDetailScreen(ticketId: ticket.id, service: _service),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate100,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 16, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 8,
                      offset: Offset(0, 2)),
                ],
              ),
              child: Row(
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: AppColors.slate800),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Text(
                    'Help & Support',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate800),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.green500,
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    _buildQuickContact(),
                    const SizedBox(height: 20),
                    _buildTicketsSection(),
                    const SizedBox(height: 24),
                    _buildFaqSection(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickContact() {
    return Row(
      children: <Widget>[
        Expanded(
          child: _ContactButton(
            icon: Icons.call_rounded,
            label: 'Call us',
            sublabel: _supportPhone,
            onTap: _call,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ContactButton(
            icon: Icons.email_rounded,
            label: 'Email us',
            sublabel: 'Get a reply by email',
            onTap: _email,
          ),
        ),
      ],
    );
  }

  Widget _buildTicketsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.softShadow(),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text('My requests',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate800)),
              ),
              TextButton.icon(
                onPressed: _openNewTicket,
                icon: const Icon(Icons.add_rounded,
                    size: 18, color: AppColors.green600),
                label: const Text('New',
                    style: TextStyle(
                        color: AppColors.green600,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_error!,
                  style: const TextStyle(color: AppColors.slate500)),
            )
          else if (_tickets == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                  child: CircularProgressIndicator(
                      color: AppColors.green500, strokeWidth: 2)),
            )
          else if (_tickets!.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                "You haven't contacted support yet. Tap New if something needs our attention.",
                style: TextStyle(color: AppColors.slate500),
              ),
            )
          else
            ..._tickets!.map((SupportTicket t) => _TicketRow(
                  ticket: t,
                  onTap: () => _openTicket(t),
                )),
        ],
      ),
    );
  }

  Widget _buildFaqSection() {
    // Written for customers specifically — the backend's /support/faq
    // content (getFAQ) is answered from a vendor's point of view (payouts,
    // updating outlet listings, etc.) so it isn't reused verbatim here.
    const List<List<String>> faqs = <List<String>>[
      <String>[
        'How do I track my order?',
        "Open Track Order from the menu, or tap the notification you get once a rider is assigned. You'll see live status from dispatch to delivery.",
      ],
      <String>[
        'What payment methods are accepted?',
        'M-Pesa via Pesapal is currently supported at checkout. You\'ll get a payment prompt on your phone to complete it.',
      ],
      <String>[
        'My order is late or the wrong item arrived',
        'Contact us with your order number using Call us, Email us, or New request above and we\'ll sort it out quickly.',
      ],
      <String>[
        'Can I cancel or change my order?',
        'You can cancel from Order History while it\'s still pending or confirmed. Once it\'s dispatched, contact support instead.',
      ],
      <String>[
        'How do refunds work?',
        "Raise a request with your order number if a delivery didn't go through after payment. Refunds are processed back to the M-Pesa number used.",
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.only(bottom: 8, left: 4),
          child: Text('Frequently asked questions',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slate800)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppColors.softShadow(),
          ),
          child: Column(
            children: faqs
                .map((List<String> qa) => Theme(
                      data: Theme.of(context)
                          .copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        title: Text(qa[0],
                            style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.slate800)),
                        childrenPadding:
                            const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        expandedCrossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(qa[1],
                              style: const TextStyle(
                                  color: AppColors.slate500,
                                  fontSize: 13,
                                  height: 1.4)),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _ContactButton extends StatelessWidget {
  const _ContactButton({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String sublabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.softShadow(),
        ),
        child: Column(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                  color: AppColors.green50, shape: BoxShape.circle),
              child: Icon(icon, color: AppColors.green600),
            ),
            const SizedBox(height: 10),
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate800,
                    fontSize: 13.5)),
            const SizedBox(height: 2),
            Text(sublabel,
                style: TextStyle(color: AppColors.slate500, fontSize: 11.5),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _TicketRow extends StatelessWidget {
  const _TicketRow({required this.ticket, required this.onTap});

  final SupportTicket ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(ticket.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.slate800,
                          fontSize: 13.5)),
                  const SizedBox(height: 2),
                  Text(
                      '${_categoryLabel(ticket.category)} · #${ticket.ticketNumber}',
                      style: const TextStyle(
                          color: AppColors.slate500, fontSize: 11.5)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor(ticket.status).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(_statusLabel(ticket.status),
                  style: TextStyle(
                      color: _statusColor(ticket.status),
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewTicketSheet extends StatefulWidget {
  const _NewTicketSheet({required this.service});
  final SupportService service;

  @override
  State<_NewTicketSheet> createState() => _NewTicketSheetState();
}

class _NewTicketSheetState extends State<_NewTicketSheet> {
  final TextEditingController _subject = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final OrderService _orderService = OrderService();
  final ImagePicker _picker = ImagePicker();

  String _category = 'order_issue';
  bool _submitting = false;
  String? _error;

  // Order linking (optional) — the ticket API itself has no order_id
  // field, so the selected order number gets woven into the description
  // text instead. This needs no backend changes to work.
  List<Map<String, dynamic>>? _orders;
  Map<String, dynamic>? _selectedOrder;

  // Photo attachments (optional, up to 3). Uploaded best-effort after
  // the ticket is created — see uploadTicketAttachment's doc comment
  // for why this is treated as non-fatal.
  static const int _maxImages = 3;
  final List<XFile> _images = <XFile>[];

  static const List<String> _categories = <String>[
    'order_issue',
    'delivery_problem',
    'payment_issue',
    'product_quality',
    'account_issue',
    'technical_support',
    'billing_inquiry',
    'other',
  ];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  /// Loads recent orders for the "link an order" picker. This is a
  /// best-effort convenience feature — if it fails, the order picker
  /// just shows an empty/error state and the rest of the form still
  /// works normally.
  Future<void> _loadOrders() async {
    try {
      final List<Map<String, dynamic>> orders =
          await _orderService.getUserOrders();
      if (mounted) setState(() => _orders = orders);
    } catch (_) {
      if (mounted) setState(() => _orders = <Map<String, dynamic>>[]);
    }
  }

  String _orderLabel(Map<String, dynamic> order) {
    final String number = order['order_number']?.toString() ??
        order['id']?.toString() ??
        order['order_id']?.toString() ??
        '';
    return number.isEmpty ? 'Order' : '#$number';
  }

  String _orderDateLabel(Map<String, dynamic> order) {
    final DateTime? dt =
        DateTime.tryParse(order['created_at']?.toString() ?? '');
    if (dt == null) return '';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  Future<void> _pickOrder() async {
    final Map<String, dynamic>? chosen =
        await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                        color: AppColors.slate100,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const Text('Select an order',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate800)),
                const SizedBox(height: 12),
                if (_orders == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.green500, strokeWidth: 2)),
                  )
                else if (_orders!.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      "We couldn't find any past orders to link. You can still describe the order in your message.",
                      style: TextStyle(color: AppColors.slate500),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _orders!.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: AppColors.slate100),
                      itemBuilder: (context, index) {
                        final Map<String, dynamic> order = _orders![index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.receipt_long_rounded,
                              color: AppColors.green600),
                          title: Text(_orderLabel(order),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.slate800)),
                          subtitle: Text(
                            <String>[
                              if (_orderDateLabel(order).isNotEmpty)
                                _orderDateLabel(order),
                              if ((order['status']?.toString() ?? '')
                                  .isNotEmpty)
                                order['status'].toString(),
                            ].join(' · '),
                            style:
                                const TextStyle(color: AppColors.slate500),
                          ),
                          onTap: () => Navigator.pop(context, order),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (chosen != null) setState(() => _selectedOrder = chosen);
  }

  Future<void> _addPhoto() async {
    if (_images.length >= _maxImages) return;
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading:
                  const Icon(Icons.camera_alt_rounded, color: AppColors.green600),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: AppColors.green600),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 80,
      );
      if (file != null && mounted) {
        setState(() => _images.add(file));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not access photos: $e')),
        );
      }
    }
  }

  void _removePhoto(int index) {
    setState(() => _images.removeAt(index));
  }

  Future<void> _submit() async {
    if (_subject.text.trim().isEmpty || _description.text.trim().isEmpty) {
      setState(() => _error = 'Please fill in both fields.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });

    // Fold the linked order number into the description text, since the
    // ticket API doesn't have a dedicated order_id field.
    final String description = _selectedOrder == null
        ? _description.text.trim()
        : 'Order ${_orderLabel(_selectedOrder!)}\n\n${_description.text.trim()}';

    try {
      final SupportTicket ticket = await widget.service.createTicket(
        subject: _subject.text.trim(),
        description: description,
        category: _category,
      );

      int failedUploads = 0;
      for (final XFile image in _images) {
        try {
          await widget.service.uploadTicketAttachment(
            ticket.id,
            File(image.path),
          );
        } catch (_) {
          failedUploads++;
        }
      }

      if (mounted) {
        Navigator.pop(context, <String, dynamic>{
          'success': true,
          'attachmentWarning': failedUploads > 0,
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: AppColors.slate100,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const Text('New support request',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.slate800)),
              const SizedBox(height: 4),
              const Text(
                'Linking your order and adding a photo helps us resolve it faster.',
                style: TextStyle(color: AppColors.slate500, fontSize: 12.5),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: _fieldDecoration('Category'),
                items: _categories
                    .map((String c) => DropdownMenuItem<String>(
                        value: c, child: Text(_categoryLabel(c))))
                    .toList(),
                onChanged: (String? v) =>
                    setState(() => _category = v ?? _category),
              ),
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _pickOrder,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.slate100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.receipt_long_rounded,
                          color: AppColors.slate500, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _selectedOrder == null
                              ? 'Select order number (optional)'
                              : 'Order ${_orderLabel(_selectedOrder!)}',
                          style: TextStyle(
                            color: _selectedOrder == null
                                ? AppColors.slate500
                                : AppColors.slate800,
                            fontWeight: _selectedOrder == null
                                ? FontWeight.normal
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (_selectedOrder != null)
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              size: 18, color: AppColors.slate500),
                          onPressed: () =>
                              setState(() => _selectedOrder = null),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        )
                      else
                        const Icon(Icons.chevron_right_rounded,
                            color: AppColors.slate500),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _subject,
                decoration: _fieldDecoration('Subject'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                decoration: _fieldDecoration('Tell us what happened'),
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              const Text('Photos (optional)',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate800)),
              const SizedBox(height: 8),
              SizedBox(
                height: 76,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: <Widget>[
                    for (int i = 0; i < _images.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: <Widget>[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                File(_images[i].path),
                                width: 76,
                                height: 76,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: -6,
                              right: -6,
                              child: GestureDetector(
                                onTap: () => _removePhoto(i),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                      color: AppColors.slate800,
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.close_rounded,
                                      size: 12, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_images.length < _maxImages)
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _addPhoto,
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: AppColors.slate100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.slate100, width: 1),
                          ),
                          child: const Icon(Icons.add_a_photo_rounded,
                              color: AppColors.slate500),
                        ),
                      ),
                  ],
                ),
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(_error!,
                    style: const TextStyle(
                        color: AppColors.red500, fontSize: 12.5)),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green500,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Submit',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.slate100,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
      );
}

class _TicketDetailScreen extends StatefulWidget {
  const _TicketDetailScreen({required this.ticketId, required this.service});
  final String ticketId;
  final SupportService service;

  @override
  State<_TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<_TicketDetailScreen> {
  final TextEditingController _reply = TextEditingController();
  SupportTicket? _ticket;
  String? _error;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final SupportTicket t =
          await widget.service.getTicketDetails(widget.ticketId);
      if (mounted) setState(() => _ticket = t);
    } catch (e) {
      if (mounted)
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _send() async {
    if (_reply.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await widget.service.replyToTicket(widget.ticketId, _reply.text.trim());
      _reply.clear();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool closed =
        _ticket?.status == 'closed' || _ticket?.status == 'resolved';

    return Scaffold(
      backgroundColor: AppColors.slate100,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 16, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 8,
                      offset: Offset(0, 2))
                ],
              ),
              child: Row(
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: AppColors.slate800),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(_ticket?.subject ?? 'Support request',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.slate800)),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Expanded(
                  child: Center(
                      child: Text(_error!,
                          style: const TextStyle(color: AppColors.slate500))))
            else if (_ticket == null)
              const Expanded(
                  child: Center(
                      child:
                          CircularProgressIndicator(color: AppColors.green500)))
            else
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14)),
                      child: Text(_ticket!.description,
                          style: const TextStyle(
                              color: AppColors.slate800, height: 1.4)),
                    ),
                    const SizedBox(height: 16),
                    ..._ticket!.messages.map((SupportMessage m) => Align(
                          alignment: m.isFromCustomer
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.75),
                            decoration: BoxDecoration(
                              color: m.isFromCustomer
                                  ? AppColors.green500
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                if (!m.isFromCustomer)
                                  Text(m.senderName,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.green600)),
                                Text(m.text,
                                    style: TextStyle(
                                        color: m.isFromCustomer
                                            ? Colors.white
                                            : AppColors.slate800)),
                              ],
                            ),
                          ),
                        )),
                  ],
                ),
              ),
            if (_ticket != null && !closed)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 8,
                        offset: Offset(0, -2))
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _reply,
                          decoration: InputDecoration(
                            hintText: 'Type a message',
                            filled: true,
                            fillColor: AppColors.slate100,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _sending ? null : _send,
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppColors.green500))
                            : const Icon(Icons.send_rounded,
                                color: AppColors.green500),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}