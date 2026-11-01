import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api_client.dart';
import '../models.dart';
import '../storage.dart';
import 'package:voya_ui/voya_ui.dart';
import '../ui/user_message.dart';
import 'rider_details_screen.dart';

class SeatMapScreen extends StatefulWidget {
  final ApiClient api;
  final Trip trip;
  const SeatMapScreen({super.key, required this.api, required this.trip});

  @override
  State<SeatMapScreen> createState() => _SeatMapScreenState();
}

class _SeatMapScreenState extends State<SeatMapScreen> {
  late Trip _trip;
  int? _selectedSeat;
  bool _holding = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
  }

  Future<void> _refresh() async {
    final fresh = await widget.api.getTrip(_trip.id);
    if (mounted) setState(() => _trip = fresh);
  }

  Future<void> _holdSeat() async {
    if (_selectedSeat == null) return;
    setState(() {
      _holding = true;
      _error = null;
    });
    try {
      final phone = await RiderStorage().getSavedPhone() ?? 'unknown';
      final hold = await widget.api.holdSeat(
        tripId: _trip.id,
        seatNumber: _selectedSeat!,
        riderPhone: phone,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RiderDetailsScreen(
            api: widget.api,
            trip: _trip,
            seatNumber: _selectedSeat!,
            hold: hold,
          ),
        ),
      );
      // Seat may now be booked/held by us or released back — refresh either way.
      await _refresh();
      if (mounted) setState(() => _selectedSeat = null);
    } catch (e) {
      if (mounted) setState(() => _error = userMessage(e));
      try {
        await _refresh();
      } catch (_) {}
    } finally {
      if (mounted) setState(() => _holding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [..._trip.seats]
      ..sort((a, b) => a.seatNumber.compareTo(b.seatNumber));

    return Scaffold(
      appBar: AppBar(title: const Text('Choose a seat')),
      body: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_trip.origin} → ${_trip.destination}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: Space.xs),
            Text(
              '${DateFormat('EEE d MMM, HH:mm').format(_trip.departureAt)} · ${formatFare(_trip.fare)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: Space.md),
            Expanded(
              child: GridView.builder(
                itemCount: sorted.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1,
                ),
                itemBuilder: (_, i) => _SeatTile(
                  seat: sorted[i],
                  selected: _selectedSeat == sorted[i].seatNumber,
                  onTap: sorted[i].status == 'available'
                      ? () =>
                          setState(() => _selectedSeat = sorted[i].seatNumber)
                      : null,
                ),
              ),
            ),
            const _Legend(),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: const TextStyle(color: VoyaColors.crit, fontSize: 14)),
            ],
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _selectedSeat == null || _holding ? null : _holdSeat,
              child: _holding
                  ? const ButtonSpinner()
                  : Text(_selectedSeat == null
                      ? 'Select a seat to continue'
                      : 'Hold seat $_selectedSeat for 90s'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeatTile extends StatelessWidget {
  final Seat seat;
  final bool selected;
  final VoidCallback? onTap;
  const _SeatTile(
      {required this.seat, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final available = seat.status == 'available';
    final held = seat.status == 'held';
    Color bg = VoyaColors.surface;
    Color fg = VoyaColors.ink;
    IconData? mark;
    if (!available) {
      bg = VoyaColors.line;
      fg = VoyaColors.inkSoft;
      mark = held ? Icons.schedule : Icons.lock;
    } else if (selected) {
      bg = VoyaColors.ochre;
      fg = Colors.white;
      mark = Icons.check;
    }
    final state = selected
        ? 'selected'
        : available
            ? 'free'
            : held
                ? 'held by someone else'
                : 'taken';

    return Semantics(
      button: available,
      selected: selected,
      label: 'Seat ${seat.seatNumber}, $state',
      excludeSemantics: true,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.sm),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.sm),
              border: Border.all(
                  color: selected ? VoyaColors.ochre : VoyaColors.line),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${seat.seatNumber}',
                  style: TextStyle(
                      color: fg, fontWeight: FontWeight.w700, fontSize: 16),
                ),
                if (mark != null) Icon(mark, size: 12, color: fg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget item(Color c, IconData? icon, String label, {bool border = false}) =>
        Padding(
          padding: const EdgeInsets.only(right: Space.md),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                margin: const EdgeInsets.only(right: Space.xs + 2),
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: VoyaColors.line),
                ),
                child: icon == null
                    ? null
                    : Icon(icon,
                        size: 10,
                        color: c == VoyaColors.ochre
                            ? Colors.white
                            : VoyaColors.inkSoft),
              ),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.only(top: Space.sm + 2),
      child: Wrap(
        runSpacing: Space.xs,
        children: [
          item(VoyaColors.surface, null, 'Free'),
          item(VoyaColors.line, Icons.schedule, 'Held'),
          item(VoyaColors.line, Icons.lock, 'Taken'),
          item(VoyaColors.ochre, Icons.check, 'Selected'),
        ],
      ),
    );
  }
}
