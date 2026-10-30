import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api_client.dart';
import '../models.dart';
import '../theme.dart';
import 'seat_map_screen.dart';

class SearchScreen extends StatefulWidget {
  final ApiClient api;
  const SearchScreen({super.key, required this.api});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _originCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  DateTime? _date;

  bool _loading = false;
  String? _error;
  List<Trip>? _results;

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final trips = await widget.api.searchTrips(
        origin: _originCtrl.text.trim(),
        destination: _destCtrl.text.trim(),
        date: _date != null ? DateFormat('yyyy-MM-dd').format(_date!) : null,
      );
      setState(() => _results = trips);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find a trip')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          TextField(
            controller: _originCtrl,
            decoration: const InputDecoration(labelText: 'From', hintText: 'e.g. Abidjan'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _destCtrl,
            decoration: const InputDecoration(labelText: 'To', hintText: 'e.g. Bouaké'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text(_date == null
                ? 'Any date'
                : DateFormat('EEE, d MMM').format(_date!)),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: _loading ? null : _search,
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Search trips'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: VoyaColors.crit)),
          ],
          const SizedBox(height: 24),
          if (_results != null) ..._buildResults(),
        ],
      ),
    );
  }

  List<Widget> _buildResults() {
    if (_results!.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 30),
          child: Center(
            child: Text(
              'No trips found. Try a different route or date.',
              style: TextStyle(color: VoyaColors.inkSoft),
            ),
          ),
        ),
      ];
    }
    return _results!
        .map((trip) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TripCard(trip: trip, onTap: () => _openTrip(trip)),
            ))
        .toList();
  }

  void _openTrip(Trip trip) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SeatMapScreen(api: widget.api, trip: trip),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final Trip trip;
  final VoidCallback onTap;
  const _TripCard({required this.trip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final free = trip.seatsAvailable;
    final seatColor = free == 0
        ? VoyaColors.crit
        : free <= 3
            ? VoyaColors.warn
            : VoyaColors.good;
    final seatLabel = free == 0 ? 'Fully booked' : '$free seat${free == 1 ? '' : 's'} left';

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: free == 0 ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${trip.origin} → ${trip.destination}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('EEE d MMM, HH:mm').format(trip.departureAt),
                    style: const TextStyle(color: VoyaColors.inkSoft, fontSize: 13),
                  ),
                  Text(
                    trip.fare.toStringAsFixed(0),
                    style: const TextStyle(
                      color: VoyaColors.ochre,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(seatLabel, style: TextStyle(color: seatColor, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
