import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api_client.dart';
import '../models.dart';
import 'package:voya_ui/voya_ui.dart';
import '../ui/user_message.dart';

class ManifestScreen extends StatefulWidget {
  final ApiClient api;
  final TripDetail trip;
  const ManifestScreen({super.key, required this.api, required this.trip});

  @override
  State<ManifestScreen> createState() => _ManifestScreenState();
}

class _ManifestScreenState extends State<ManifestScreen> {
  TripDetail? _trip;
  List<ManifestEntry>? _entries;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final trip = await widget.api.getTrip(widget.trip.id);
      final entries = await widget.api.getManifest(widget.trip.id);
      if (!mounted) return;
      setState(() {
        _trip = trip;
        _entries = entries;
      });
    } catch (e) {
      if (mounted) setState(() => _error = userMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = _trip ?? widget.trip;
    final sortedSeats = [...trip.seats]
      ..sort((a, b) => a.seatNumber.compareTo(b.seatNumber));
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text('${trip.origin} → ${trip.destination}')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(Space.md),
              children: [
                Text(DateFormat('EEE d MMM, HH:mm').format(trip.departureAt),
                    style: text.bodySmall),
                const SizedBox(height: Space.md),
                const Wrap(
                  spacing: Space.md,
                  runSpacing: Space.sm,
                  children: [
                    _LegendItem(
                        status: 'available', label: 'Available'),
                    _LegendItem(status: 'held', label: 'Held'),
                    _LegendItem(status: 'booked', label: 'Booked'),
                  ],
                ),
                const SizedBox(height: Space.md),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sortedSeats.length,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 56,
                    mainAxisSpacing: Space.sm,
                    crossAxisSpacing: Space.sm,
                  ),
                  itemBuilder: (_, i) => _SeatTile(seat: sortedSeats[i]),
                ),
                const SizedBox(height: Space.lg),
                const SectionHeader(title: 'Manifest'),
                if (_error != null)
                  ErrorState(message: _error!, onRetry: _load)
                else if (_entries == null)
                  const ListSkeleton()
                else if (_entries!.isEmpty)
                  const EmptyState(
                      icon: Icons.event_seat_outlined,
                      message: 'No bookings yet.')
                else
                  for (final e in _entries!)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.sm),
                      child: _ManifestTile(entry: e, seats: trip.seats),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

(Color, Color, IconData, String) _seatStyle(String status) =>
    switch (status) {
      'available' => (
          VoyaColors.goodTint,
          VoyaColors.good,
          Icons.check,
          'available'
        ),
      'held' => (VoyaColors.warnTint, VoyaColors.warn, Icons.schedule, 'held'),
      _ => (VoyaColors.critTint, VoyaColors.crit, Icons.lock_outline, 'booked'),
    };

class _SeatTile extends StatelessWidget {
  final Seat seat;
  const _SeatTile({required this.seat});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon, label) = _seatStyle(seat.status);
    return Semantics(
      label: 'Seat ${seat.seatNumber}, $label',
      child: ExcludeSemantics(
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(Radii.sm),
            border: Border.all(color: fg.withOpacity(0.4)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${seat.seatNumber}',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: fg)),
              Icon(icon, size: 12, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String status;
  final String label;
  const _LegendItem({required this.status, required this.label});

  @override
  Widget build(BuildContext context) {
    final (_, fg, icon, _) = _seatStyle(status);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: fg),
        const SizedBox(width: Space.xs),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _ManifestTile extends StatelessWidget {
  final ManifestEntry entry;
  final List<Seat> seats;
  const _ManifestTile({required this.entry, required this.seats});

  @override
  Widget build(BuildContext context) {
    final seat = seats.where((s) => s.id == entry.seatId).toList();
    final seatNumber =
        seat.isNotEmpty ? seat.first.seatNumber.toString() : '—';
    final (tone, icon) = switch (entry.status) {
      'confirmed' => (BadgeTone.good, Icons.check_circle_outline),
      'boarded' => (BadgeTone.info, Icons.directions_bus_outlined),
      _ => (BadgeTone.warn, Icons.schedule),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.riderName,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: Space.xs),
                  Text(
                      '${entry.riderPhone} · seat $seatNumber · ${entry.bookingSource}',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: Space.sm),
            StatusBadge(
                label: entry.status.replaceAll('_', ' '),
                tone: tone,
                icon: icon),
          ],
        ),
      ),
    );
  }
}
