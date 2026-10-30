class Seat {
  final String id;
  final int seatNumber;
  final String status; // available | held | booked

  Seat({required this.id, required this.seatNumber, required this.status});

  factory Seat.fromJson(Map<String, dynamic> j) => Seat(
        id: j['id'],
        seatNumber: j['seat_number'],
        status: j['status'],
      );
}

class Trip {
  final String id;
  final String routeId;
  final String vehicleId;
  final DateTime departureAt;
  final num fare;
  final String status;
  final String origin;
  final String destination;
  final List<Seat> seats;

  Trip({
    required this.id,
    required this.routeId,
    required this.vehicleId,
    required this.departureAt,
    required this.fare,
    required this.status,
    required this.origin,
    required this.destination,
    required this.seats,
  });

  int get seatsAvailable => seats.where((s) => s.status == 'available').length;

  factory Trip.fromJson(Map<String, dynamic> j) => Trip(
        id: j['id'],
        routeId: j['route_id'],
        vehicleId: j['vehicle_id'],
        departureAt: DateTime.parse(j['departure_at']),
        fare: j['fare'] is String ? num.parse(j['fare']) : j['fare'],
        status: j['status'],
        origin: j['origin'],
        destination: j['destination'],
        seats: (j['seats'] as List).map((s) => Seat.fromJson(s)).toList(),
      );
}

class SeatHold {
  final String holdId;
  final String seatId;
  final DateTime expiresAt;

  SeatHold({required this.holdId, required this.seatId, required this.expiresAt});

  factory SeatHold.fromJson(Map<String, dynamic> j) => SeatHold(
        holdId: j['hold_id'],
        seatId: j['seat_id'],
        expiresAt: DateTime.parse(j['expires_at']),
      );
}

class Ticket {
  final String id;
  final String code;
  final String signedToken;
  final DateTime issuedAt;

  Ticket({required this.id, required this.code, required this.signedToken, required this.issuedAt});

  factory Ticket.fromJson(Map<String, dynamic> j) => Ticket(
        id: j['id'],
        code: j['code'],
        signedToken: j['signed_token'],
        issuedAt: DateTime.parse(j['issued_at']),
      );
}

class Booking {
  final String id;
  final String tripId;
  final String seatId;
  final String riderName;
  final String riderPhone;
  final String status; // pending_payment | confirmed | cancelled | boarded
  final Ticket? ticket;

  Booking({
    required this.id,
    required this.tripId,
    required this.seatId,
    required this.riderName,
    required this.riderPhone,
    required this.status,
    this.ticket,
  });

  factory Booking.fromJson(Map<String, dynamic> j) => Booking(
        id: j['id'],
        tripId: j['trip_id'],
        seatId: j['seat_id'],
        riderName: j['rider_name'],
        riderPhone: j['rider_phone'],
        status: j['status'],
        ticket: j['ticket'] != null ? Ticket.fromJson(j['ticket']) : null,
      );
}

/// A lightweight local record of a past booking, kept on-device for the
/// "My tickets" tab (mirrors the rider web app's localStorage behavior).
class SavedBookingRef {
  final String bookingId;
  final String origin;
  final String destination;
  final DateTime departureAt;
  final int seatNumber;

  SavedBookingRef({
    required this.bookingId,
    required this.origin,
    required this.destination,
    required this.departureAt,
    required this.seatNumber,
  });

  Map<String, dynamic> toJson() => {
        'bookingId': bookingId,
        'origin': origin,
        'destination': destination,
        'departureAt': departureAt.toIso8601String(),
        'seatNumber': seatNumber,
      };

  factory SavedBookingRef.fromJson(Map<String, dynamic> j) => SavedBookingRef(
        bookingId: j['bookingId'],
        origin: j['origin'],
        destination: j['destination'],
        departureAt: DateTime.parse(j['departureAt']),
        seatNumber: j['seatNumber'],
      );
}
