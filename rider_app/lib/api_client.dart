import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'models.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

/// Thin REST client for the Voya booking API.
///
/// Base URL resolution: override with `--dart-define=VOYA_API_BASE=...`
/// for a real device/server. Otherwise default to the host each platform
/// uses to reach "the machine running this backend" in local dev —
/// 10.0.2.2 is the Android emulator's alias for the host's localhost.
class ApiClient {
  final String baseUrl;
  final http.Client _client = http.Client();

  ApiClient({String? baseUrl}) : baseUrl = baseUrl ?? _defaultBaseUrl();

  static String _defaultBaseUrl() {
    const override = String.fromEnvironment('VOYA_API_BASE');
    if (override.isNotEmpty) return override;
    if (kIsWeb) return 'http://localhost:8008';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:8008';
    } catch (_) {
      // Platform.* throws on web, already handled above.
    }
    return 'http://localhost:8008';
  }

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: query);

  Future<dynamic> _handle(http.Response res) async {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(res.body);
    }
    String message = res.reasonPhrase ?? 'Request failed';
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['detail'] != null)
        message = body['detail'].toString();
    } catch (_) {}
    throw ApiException(message);
  }

  Future<List<Trip>> searchTrips(
      {String? origin, String? destination, String? date}) async {
    final query = <String, String>{};
    if (origin != null && origin.isNotEmpty) query['origin'] = origin;
    if (destination != null && destination.isNotEmpty)
      query['destination'] = destination;
    if (date != null && date.isNotEmpty) query['date'] = date;
    final res = await _client.get(_uri('/trips', query));
    final body = await _handle(res) as List;
    return body.map((j) => Trip.fromJson(j)).toList();
  }

  Future<Trip> getTrip(String tripId) async {
    final res = await _client.get(_uri('/trips/$tripId'));
    return Trip.fromJson(await _handle(res));
  }

  Future<SeatHold> holdSeat({
    required String tripId,
    required int seatNumber,
    required String riderPhone,
  }) async {
    final res = await _client.post(
      _uri('/seat-holds'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'trip_id': tripId,
        'seat_number': seatNumber,
        'rider_phone': riderPhone,
      }),
    );
    return SeatHold.fromJson(await _handle(res));
  }

  Future<Booking> createBooking({
    required String holdId,
    required String riderName,
    required String riderPhone,
    required String paymentMethod,
  }) async {
    final res = await _client.post(
      _uri('/bookings'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'hold_id': holdId,
        'rider_name': riderName,
        'rider_phone': riderPhone,
        'payment_method': paymentMethod,
        'booking_source': 'app',
      }),
    );
    return Booking.fromJson(await _handle(res));
  }

  Future<Booking> getBooking(String bookingId) async {
    final res = await _client.get(_uri('/bookings/$bookingId'));
    return Booking.fromJson(await _handle(res));
  }

  Future<Booking> confirmPayment(String bookingId, String pspReference) async {
    final res = await _client.post(
      _uri('/bookings/$bookingId/confirm-payment'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'psp_reference': pspReference}),
    );
    return Booking.fromJson(await _handle(res));
  }

  String ticketQrUrl(String ticketId) => '$baseUrl/tickets/$ticketId/qr.png';
}
