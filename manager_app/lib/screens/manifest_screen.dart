import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api_client.dart';
import '../models.dart';
import '../theme.dart';

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
      setState(() {
        _trip = trip;
        _entries = entries;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = _trip ?? widget.trip;
    final sortedSeats = [...trip.seats]..sort((a, b) => a.seatNumber.compareTo(b.seatNumber));

    return Scaffold(
      appBar: AppBar(title: Text('${trip.origin} → ${trip.destination}')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Text(
              DateFormat('EEE d MMM, HH:mm').format(trip.departureAt),
              style: const TextStyle(color: VoyaColors.inkSoft),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: VoyaColors.crit)),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sortedSeats.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemBuilder: (_, i) {
                final seat = sortedSeats[i];
                Color color;
                switch (seat.status) {
                  case 'available':
                    color = VoyaColors.good;
                    break;
                  case 'held':
                    color = VoyaColors.gold;
                    break;
                  default:
                    color = VoyaColors.crit;
                }
                return Container(
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                  alignment: Alignment.center,
                  child: Text(
                    '${seat.seatNumber}',
                    style: TextStyle(
                      color: seat.status == 'held' ? VoyaColors.ink : Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text('Manifest', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 10),
            if (_entries == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_entries!.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('No bookings yet.', style: TextStyle(color: VoyaColors.inkSoft)),
              )
            else
              ..._entries!.map((e) {
                final seat = trip.seats.where((s) => s.id == e.seatId).toList();
                final seatNumber = seat.isNotEmpty ? seat.first.seatNumber.toString() : '—';
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(e.riderName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${e.riderPhone} · seat $seatNumber · ${e.bookingSource}'),
                    trailing: _StatusPill(status: e.status),
                  ),
                );
              }),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}
