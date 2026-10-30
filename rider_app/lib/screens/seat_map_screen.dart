import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api_client.dart';
import '../models.dart';
import '../storage.dart';
import '../theme.dart';
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
    setState(() => _trip = fresh);
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
      setState(() => _selectedSeat = null);
    } catch (e) {
      setState(() => _error = e.toString());
      await _refresh();
    } finally {
      setState(() => _holding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [..._trip.seats]..sort((a, b) => a.seatNumber.compareTo(b.seatNumber));

    return Scaffold(
      appBar: AppBar(title: const Text('Choose a seat')),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_trip.origin} → ${_trip.destination}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
            ),
            const SizedBox(height: 4),
            Text(
              '${DateFormat('EEE d MMM, HH:mm').format(_trip.departureAt)} · ${_trip.fare.toStringAsFixed(0)} fare',
              style: const TextStyle(color: VoyaColors.inkSoft, fontSize: 13),
            ),
            const SizedBox(height: 18),
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
                      ? () => setState(() => _selectedSeat = sorted[i].seatNumber)
                      : null,
                ),
              ),
            ),
            const _Legend(),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: VoyaColors.crit, fontSize: 13)),
            ],
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _selectedSeat == null || _holding ? null : _holdSeat,
              child: _holding
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
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
  const _SeatTile({required this.seat, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final taken = seat.status != 'available';
    Color bg = VoyaColors.surface;
    Color fg = VoyaColors.ink;
    if (taken) {
      bg = VoyaColors.line;
      fg = VoyaColors.inkSoft;
    } else if (selected) {
      bg = VoyaColors.ochre;
      fg = Colors.white;
    }

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: VoyaColors.line),
          ),
          alignment: Alignment.center,
          child: Text(
            '${seat.seatNumber}',
            style: TextStyle(color: fg, fontWeight: FontWeight.w700),
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
    Widget swatch(Color c) => Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
        );

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          swatch(VoyaColors.surface),
          const Text('Free', style: TextStyle(fontSize: 12, color: VoyaColors.inkSoft)),
          const SizedBox(width: 16),
          swatch(VoyaColors.line),
          const Text('Taken', style: TextStyle(fontSize: 12, color: VoyaColors.inkSoft)),
          const SizedBox(width: 16),
          swatch(VoyaColors.ochre),
          const Text('Selected', style: TextStyle(fontSize: 12, color: VoyaColors.inkSoft)),
        ],
      ),
    );
  }
}
