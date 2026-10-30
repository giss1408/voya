class StaffUser {
  final String id;
  final String? operatorId;
  final String name;
  final String phone;
  final String role; // dispatcher | finance | agent | admin

  StaffUser({
    required this.id,
    required this.operatorId,
    required this.name,
    required this.phone,
    required this.role,
  });

  bool get isPlatformAdmin => role == 'admin' && operatorId == null;

  factory StaffUser.fromJson(Map<String, dynamic> j) => StaffUser(
        id: j['id'],
        operatorId: j['operator_id'],
        name: j['name'],
        phone: j['phone'],
        role: j['role'],
      );
}

class Operator {
  final String id;
  final String name;
  final String country;
  final String status; // pending | verified | suspended

  Operator({required this.id, required this.name, required this.country, required this.status});

  factory Operator.fromJson(Map<String, dynamic> j) => Operator(
        id: j['id'],
        name: j['name'],
        country: j['country'],
        status: j['status'],
      );
}

class Vehicle {
  final String id;
  final String plateNumber;
  final int seatCount;
  final String vehicleType;

  Vehicle({required this.id, required this.plateNumber, required this.seatCount, required this.vehicleType});

  factory Vehicle.fromJson(Map<String, dynamic> j) => Vehicle(
        id: j['id'],
        plateNumber: j['plate_number'],
        seatCount: j['seat_count'],
        vehicleType: j['vehicle_type'],
      );
}

class RouteModel {
  final String id;
  final String origin;
  final String destination;
  final num baseFare;
  final bool isActive;

  RouteModel({
    required this.id,
    required this.origin,
    required this.destination,
    required this.baseFare,
    required this.isActive,
  });

  factory RouteModel.fromJson(Map<String, dynamic> j) => RouteModel(
        id: j['id'],
        origin: j['origin'],
        destination: j['destination'],
        baseFare: j['base_fare'] is String ? num.parse(j['base_fare']) : j['base_fare'],
        isActive: j['is_active'],
      );
}

class Seat {
  final String id;
  final int seatNumber;
  final String status;

  Seat({required this.id, required this.seatNumber, required this.status});

  factory Seat.fromJson(Map<String, dynamic> j) => Seat(
        id: j['id'],
        seatNumber: j['seat_number'],
        status: j['status'],
      );
}

class TripDetail {
  final String id;
  final String routeId;
  final String vehicleId;
  final DateTime departureAt;
  final num fare;
  final String status;
  final String origin;
  final String destination;
  final List<Seat> seats;

  TripDetail({
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

  factory TripDetail.fromJson(Map<String, dynamic> j) => TripDetail(
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

class ManifestEntry {
  final String id;
  final String seatId;
  final String riderName;
  final String riderPhone;
  final String bookingSource;
  final String status;

  ManifestEntry({
    required this.id,
    required this.seatId,
    required this.riderName,
    required this.riderPhone,
    required this.bookingSource,
    required this.status,
  });

  factory ManifestEntry.fromJson(Map<String, dynamic> j) => ManifestEntry(
        id: j['id'],
        seatId: j['seat_id'],
        riderName: j['rider_name'],
        riderPhone: j['rider_phone'],
        bookingSource: j['booking_source'] ?? 'app',
        status: j['status'],
      );
}
