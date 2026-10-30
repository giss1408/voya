import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api_client.dart';
import '../models.dart';
import '../storage.dart';
import '../theme.dart';
import 'ticket_screen.dart';

class MyTicketsScreen extends StatefulWidget {
  final ApiClient api;
  const MyTicketsScreen({super.key, required this.api});

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  List<SavedBookingRef>? _saved;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final saved = await RiderStorage().getSavedBookings();
    if (mounted) setState(() => _saved = saved);
  }

  Future<void> _open(SavedBookingRef ref) async {
    try {
      final booking = await widget.api.getBooking(ref.bookingId);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TicketScreen(
            api: widget.api,
            trip: _TripStub(origin: ref.origin, destination: ref.destination, departureAt: ref.departureAt),
            seatNumber: ref.seatNumber,
            booking: booking,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't load this booking: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My tickets')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _saved == null
            ? const SizedBox.shrink()
            : _saved!.isEmpty
                ? ListView(
                    children: const [
                      Padding(
                        padding: EdgeInsets.only(top: 80),
                        child: Center(
                          child: Text(
                            'No bookings yet on this device.\nSearch a route to book your first trip.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: VoyaColors.inkSoft),
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(18),
                    itemCount: _saved!.length,
                    itemBuilder: (_, i) {
                      final ref = _saved![i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Card(
                          child: ListTile(
                            onTap: () => _open(ref),
                            title: Text(
                              '${ref.origin} → ${ref.destination}',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              '${DateFormat('EEE d MMM, HH:mm').format(ref.departureAt)} · Seat #${ref.seatNumber}',
                              style: const TextStyle(color: VoyaColors.inkSoft, fontSize: 12),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

/// TicketScreen only needs origin/destination/departure for display; a
/// saved booking ref carries those locally without a trip refetch.
class _TripStub extends Trip {
  _TripStub({required String origin, required String destination, required DateTime departureAt})
      : super(
          id: '',
          routeId: '',
          vehicleId: '',
          departureAt: departureAt,
          fare: 0,
          status: '',
          origin: origin,
          destination: destination,
          seats: const [],
        );
}
