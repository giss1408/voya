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

/// REST client for the Voya Fleet dashboard.
///
/// The backend's /auth/login sets an httponly session cookie. package:http
/// does not manage cookies itself (that's a browser feature), so this
/// client captures Set-Cookie from the login response and replays it on
/// every later request, same as a browser would for this backend.
class ApiClient {
  final String baseUrl;
  final http.Client _client = http.Client();
  String? _sessionCookie;

  ApiClient({String? baseUrl}) : baseUrl = baseUrl ?? _defaultBaseUrl();

  static String _defaultBaseUrl() {
    const override = String.fromEnvironment('VOYA_API_BASE');
    if (override.isNotEmpty) return override;
    if (kIsWeb) return 'http://localhost:8008';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:8008';
    } catch (_) {}
    return 'http://localhost:8008';
  }

  bool get isAuthenticated => _sessionCookie != null;

  Map<String, String> _headers({bool json = false}) => {
        if (json) 'Content-Type': 'application/json',
        if (_sessionCookie != null) 'Cookie': _sessionCookie!,
      };

  void _captureCookie(http.Response res) {
    final setCookie = res.headers['set-cookie'];
    if (setCookie != null) {
      // Keep only "name=value" (drop attributes like Path/HttpOnly/SameSite).
      _sessionCookie = setCookie.split(';').first;
    }
  }

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: query);

  Future<dynamic> _handle(http.Response res) async {
    _captureCookie(res);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(res.body);
    }
    String message = res.reasonPhrase ?? 'Request failed';
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['detail'] != null) message = body['detail'].toString();
    } catch (_) {}
    if (res.statusCode == 401) _sessionCookie = null;
    throw ApiException(message);
  }

  Future<StaffUser> login(String phone, String password) async {
    final res = await _client.post(
      _uri('/auth/login'),
      headers: _headers(json: true),
      body: jsonEncode({'phone': phone, 'password': password}),
    );
    return StaffUser.fromJson(await _handle(res));
  }

  Future<void> logout() async {
    try {
      await _client.post(_uri('/auth/logout'), headers: _headers());
    } finally {
      _sessionCookie = null;
    }
  }

  Future<StaffUser> me() async {
    final res = await _client.get(_uri('/auth/me'), headers: _headers());
    return StaffUser.fromJson(await _handle(res));
  }

  Future<List<Operator>> listOperators() async {
    final res = await _client.get(_uri('/operators'), headers: _headers());
    final body = await _handle(res) as List;
    return body.map((j) => Operator.fromJson(j)).toList();
  }

  Future<Operator> createOperator(String name, String country) async {
    final res = await _client.post(
      _uri('/operators'),
      headers: _headers(json: true),
      body: jsonEncode({'name': name, 'country': country}),
    );
    return Operator.fromJson(await _handle(res));
  }

  Future<Operator> updateOperatorStatus(String operatorId, String status) async {
    final res = await _client.post(
      _uri('/operators/$operatorId/status'),
      headers: _headers(json: true),
      body: jsonEncode({'status': status}),
    );
    return Operator.fromJson(await _handle(res));
  }

  Future<List<Vehicle>> listVehicles(String operatorId) async {
    final res = await _client.get(_uri('/operators/$operatorId/vehicles'), headers: _headers());
    final body = await _handle(res) as List;
    return body.map((j) => Vehicle.fromJson(j)).toList();
  }

  Future<Vehicle> createVehicle(String operatorId, String plateNumber, int seatCount) async {
    final res = await _client.post(
      _uri('/operators/vehicles'),
      headers: _headers(json: true),
      body: jsonEncode({'operator_id': operatorId, 'plate_number': plateNumber, 'seat_count': seatCount}),
    );
    return Vehicle.fromJson(await _handle(res));
  }

  Future<List<RouteModel>> listRoutes() async {
    final res = await _client.get(_uri('/routes'), headers: _headers());
    final body = await _handle(res) as List;
    return body.map((j) => RouteModel.fromJson(j)).toList();
  }

  Future<RouteModel> createRoute(String operatorId, String origin, String destination, num baseFare) async {
    final res = await _client.post(
      _uri('/routes'),
      headers: _headers(json: true),
      body: jsonEncode({
        'operator_id': operatorId,
        'origin': origin,
        'destination': destination,
        'base_fare': baseFare,
      }),
    );
    return RouteModel.fromJson(await _handle(res));
  }

  Future<List<TripDetail>> listTrips() async {
    final res = await _client.get(_uri('/trips'), headers: _headers());
    final body = await _handle(res) as List;
    return body.map((j) => TripDetail.fromJson(j)).toList();
  }

  Future<TripDetail> createTrip(String routeId, String vehicleId, DateTime departureAt) async {
    final res = await _client.post(
      _uri('/trips'),
      headers: _headers(json: true),
      body: jsonEncode({
        'route_id': routeId,
        'vehicle_id': vehicleId,
        'departure_at': departureAt.toIso8601String(),
      }),
    );
    return TripDetail.fromJson(await _handle(res));
  }

  Future<TripDetail> getTrip(String tripId) async {
    final res = await _client.get(_uri('/trips/$tripId'), headers: _headers());
    return TripDetail.fromJson(await _handle(res));
  }

  Future<List<ManifestEntry>> getManifest(String tripId) async {
    final res = await _client.get(_uri('/trips/$tripId/manifest'), headers: _headers());
    final body = await _handle(res) as List;
    return body.map((j) => ManifestEntry.fromJson(j)).toList();
  }
}
