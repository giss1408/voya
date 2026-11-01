import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api_client.dart';
import '../models.dart';
import 'package:voya_ui/voya_ui.dart';
import '../ui/user_message.dart';
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
  final _destFocus = FocusNode();
  DateTime? _date;

  bool _loading = false;
  String? _error;
  List<Trip>? _results;

  @override
  void initState() {
    super.initState();
    // Empty filters return every open trip, so riders see choices right away.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _search();
    });
  }

  bool get _filtered =>
      _originCtrl.text.trim().isNotEmpty ||
      _destCtrl.text.trim().isNotEmpty ||
      _date != null;

  @override
  void dispose() {
    _originCtrl.dispose();
    _destCtrl.dispose();
    _destFocus.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    FocusScope.of(context).unfocus();
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
      if (!mounted) return;
      setState(() => _results = trips);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _results = null;
        _error = userMessage(e);
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (picked == null) return;
    setState(() => _date = picked);
    _search();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const VoyaLogo(markSize: 28)),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(Space.md),
        children: [
          Text('Find a trip', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: Space.md),
          TextField(
            controller: _originCtrl,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            onSubmitted: (_) => _destFocus.requestFocus(),
            decoration: const InputDecoration(
              labelText: 'From',
              hintText: 'e.g. Abidjan',
              prefixIcon: Icon(Icons.trip_origin, size: 20),
            ),
          ),
          const SizedBox(height: Space.sm + 4),
          TextField(
            controller: _destCtrl,
            focusNode: _destFocus,
            textInputAction: TextInputAction.search,
            textCapitalization: TextCapitalization.words,
            onSubmitted: (_) => _loading ? null : _search(),
            decoration: const InputDecoration(
              labelText: 'To',
              hintText: 'e.g. Bouaké',
              prefixIcon: Icon(Icons.place_outlined, size: 20),
            ),
          ),
          const SizedBox(height: Space.sm + 4),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text(_date == null
                ? 'Any date'
                : DateFormat('EEE, d MMM').format(_date!)),
          ),
          const SizedBox(height: Space.md),
          ElevatedButton(
            onPressed: _loading ? null : _search,
            child:
                _loading ? const ButtonSpinner() : const Text('Search trips'),
          ),
          const SizedBox(height: Space.lg),
          _buildBody(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const TripListSkeleton();
    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _search);
    }
    final results = _results;
    if (results == null) return const SizedBox.shrink();
    if (results.isEmpty) {
      return EmptyState(
        icon: Icons.directions_bus_outlined,
        message: _filtered
            ? 'No trips found. Try a different route or date.'
            : 'No trips are scheduled yet. Check back soon.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _filtered
              ? '${results.length} trip${results.length == 1 ? '' : 's'}'
              : 'Available trips (${results.length})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: Space.sm),
        for (final trip in results)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm + 4),
            child: _TripCard(trip: trip, onTap: () => _openTrip(trip)),
          ),
      ],
    );
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
    final t = Theme.of(context).textTheme;
    final free = trip.seatsAvailable;
    final (tone, icon, seatLabel) = free == 0
        ? (BadgeTone.warn, Icons.block, 'Fully booked')
        : free <= 3
            ? (
                BadgeTone.warn,
                Icons.event_seat,
                '$free seat${free == 1 ? '' : 's'} left'
              )
            : (BadgeTone.good, Icons.event_seat, '$free seats left');
    final when = DateFormat('EEE d MMM, HH:mm').format(trip.departureAt);

    return Semantics(
      button: free > 0,
      label: '${trip.origin} to ${trip.destination}, $when, '
          '${formatFare(trip.fare)}, $seatLabel',
      excludeSemantics: true,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.md),
          onTap: free == 0 ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.all(Space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${trip.origin} → ${trip.destination}',
                    style: t.titleMedium),
                const SizedBox(height: Space.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(child: Text(when, style: t.bodySmall)),
                    Text(
                      formatFare(trip.fare),
                      style: t.titleMedium?.copyWith(color: VoyaColors.ochre),
                    ),
                  ],
                ),
                const SizedBox(height: Space.sm),
                StatusBadge(label: seatLabel, tone: tone, icon: icon),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
