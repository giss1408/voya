import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../api_client.dart';
import '../models.dart';
import '../theme.dart';

class TicketScreen extends StatefulWidget {
  final ApiClient api;
  final Trip trip;
  final int seatNumber;
  final Booking booking;

  const TicketScreen({
    super.key,
    required this.api,
    required this.trip,
    required this.seatNumber,
    required this.booking,
  });

  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  late Booking _booking;
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
  }

  Future<void> _simulateMobileMoneyPay() async {
    setState(() => _confirming = true);
    try {
      final confirmed = await widget.api.confirmPayment(
        _booking.id,
        'DEMO-${DateTime.now().millisecondsSinceEpoch}',
      );
      setState(() => _booking = confirmed);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _booking.status == 'pending_payment';
    final ticket = _booking.ticket;

    return Scaffold(
      appBar: AppBar(title: Text(pending ? 'Awaiting payment' : 'Your ticket')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _StatusPill(status: _booking.status),
                  const SizedBox(height: 12),
                  Text(
                    '${widget.trip.origin} → ${widget.trip.destination}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('EEE d MMM, HH:mm').format(widget.trip.departureAt),
                    style: const TextStyle(color: VoyaColors.inkSoft, fontSize: 13),
                  ),
                  Text(
                    'Seat #${widget.seatNumber} · ${_booking.riderName}',
                    style: const TextStyle(color: VoyaColors.inkSoft, fontSize: 13),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(),
                  ),
                  if (ticket != null) ...[
                    QrImageView(
                      data: ticket.signedToken,
                      size: 180,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      ticket.code,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Show this QR or 6-digit code at boarding. Works offline.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: VoyaColors.inkSoft, fontSize: 12),
                    ),
                  ] else ...[
                    const Text(
                      'Complete payment to receive your boarding ticket.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: VoyaColors.inkSoft, fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: _confirming ? null : _simulateMobileMoneyPay,
                      child: _confirming
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text("I've paid — confirm now"),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: const Text('Book another trip'),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status) {
      case 'confirmed':
        bg = const Color(0xFFDFF0E3);
        fg = VoyaColors.good;
        break;
      case 'boarded':
        bg = const Color(0xFFDDE6ED);
        fg = VoyaColors.indigo;
        break;
      default:
        bg = const Color(0xFFF6E6D8);
        fg = VoyaColors.warn;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
      ),
    );
  }
}
