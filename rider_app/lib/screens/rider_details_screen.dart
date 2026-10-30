import 'dart:async';

import 'package:flutter/material.dart';

import '../api_client.dart';
import '../models.dart';
import '../storage.dart';
import '../theme.dart';
import 'ticket_screen.dart';

class RiderDetailsScreen extends StatefulWidget {
  final ApiClient api;
  final Trip trip;
  final int seatNumber;
  final SeatHold hold;

  const RiderDetailsScreen({
    super.key,
    required this.api,
    required this.trip,
    required this.seatNumber,
    required this.hold,
  });

  @override
  State<RiderDetailsScreen> createState() => _RiderDetailsScreenState();
}

class _RiderDetailsScreenState extends State<RiderDetailsScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _paymentMethod = 'cash_on_boarding';
  bool _submitting = false;
  String? _error;
  Timer? _timer;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _startCountdown();
  }

  Future<void> _loadProfile() async {
    final storage = RiderStorage();
    final name = await storage.getSavedName();
    final phone = await storage.getSavedPhone();
    if (name != null) _nameCtrl.text = name;
    if (phone != null) _phoneCtrl.text = phone;
  }

  void _startCountdown() {
    void tick() {
      final left = widget.hold.expiresAt.difference(DateTime.now()).inSeconds;
      setState(() => _secondsLeft = left < 0 ? 0 : left);
      if (left <= 0) _timer?.cancel();
    }

    tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter your full name.');
      return;
    }
    if (phone.isEmpty) {
      setState(() => _error = 'Enter a phone number.');
      return;
    }
    if (_secondsLeft <= 0) {
      setState(() => _error = 'Your seat hold expired — search again');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await RiderStorage().saveProfile(name, phone);
      final booking = await widget.api.createBooking(
        holdId: widget.hold.holdId,
        riderName: name,
        riderPhone: phone,
        paymentMethod: _paymentMethod,
      );
      await RiderStorage().addSavedBooking(SavedBookingRef(
        bookingId: booking.id,
        origin: widget.trip.origin,
        destination: widget.trip.destination,
        departureAt: widget.trip.departureAt,
        seatNumber: widget.seatNumber,
      ));
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => TicketScreen(
            api: widget.api,
            trip: widget.trip,
            seatNumber: widget.seatNumber,
            booking: booking,
          ),
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expired = _secondsLeft <= 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Your details')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF6E6D8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              expired
                  ? 'Your seat hold expired — search again'
                  : 'Seat held for ${_secondsLeft}s — complete booking before it expires',
              textAlign: TextAlign.center,
              style: const TextStyle(color: VoyaColors.warn, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Full name', hintText: 'As it appears on ID'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone number', hintText: '+225 07 00 00 00 00'),
          ),
          const SizedBox(height: 22),
          const Text('How will you pay?', style: TextStyle(fontWeight: FontWeight.w600, color: VoyaColors.inkSoft, fontSize: 13)),
          const SizedBox(height: 8),
          _PayOption(
            label: 'Cash on boarding',
            sub: 'Pay the agent when you board',
            value: 'cash_on_boarding',
            group: _paymentMethod,
            onChanged: (v) => setState(() => _paymentMethod = v),
          ),
          _PayOption(
            label: 'Mobile money',
            sub: 'MTN MoMo, Orange Money, Wave',
            value: 'mobile_money',
            group: _paymentMethod,
            onChanged: (v) => setState(() => _paymentMethod = v),
          ),
          _PayOption(
            label: 'Card',
            sub: 'Visa, Mastercard',
            value: 'card',
            group: _paymentMethod,
            onChanged: (v) => setState(() => _paymentMethod = v),
          ),
          const SizedBox(height: 18),
          _SummaryRow(label: 'Seat', value: '#${widget.seatNumber}'),
          _SummaryRow(label: 'Route', value: '${widget.trip.origin} → ${widget.trip.destination}'),
          _SummaryRow(label: 'Total', value: widget.trip.fare.toStringAsFixed(0), bold: true),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: VoyaColors.crit, fontSize: 13)),
          ],
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: (_submitting || expired) ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Confirm booking'),
          ),
        ],
      ),
    );
  }
}

class _PayOption extends StatelessWidget {
  final String label;
  final String sub;
  final String value;
  final String group;
  final ValueChanged<String> onChanged;

  const _PayOption({
    required this.label,
    required this.sub,
    required this.value,
    required this.group,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final active = group == value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: active ? const Color(0xFFFDF0E7) : VoyaColors.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => onChanged(value),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: active ? VoyaColors.ochre : VoyaColors.line),
            ),
            child: Row(
              children: [
                Radio<String>(
                  value: value,
                  groupValue: group,
                  onChanged: (v) => onChanged(v!),
                  activeColor: VoyaColors.ochre,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      Text(sub, style: const TextStyle(color: VoyaColors.inkSoft, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _SummaryRow({required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: VoyaColors.line)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
          Text(value, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
        ],
      ),
    );
  }
}
