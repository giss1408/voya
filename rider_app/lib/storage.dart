import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class RiderStorage {
  static const _nameKey = 'voya_name';
  static const _phoneKey = 'voya_phone';
  static const _bookingsKey = 'voya_bookings';

  Future<String?> getSavedName() async =>
      (await SharedPreferences.getInstance()).getString(_nameKey);

  Future<String?> getSavedPhone() async =>
      (await SharedPreferences.getInstance()).getString(_phoneKey);

  Future<void> saveProfile(String name, String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, name);
    await prefs.setString(_phoneKey, phone);
  }

  Future<List<SavedBookingRef>> getSavedBookings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_bookingsKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((j) => SavedBookingRef.fromJson(j)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addSavedBooking(SavedBookingRef ref) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getSavedBookings();
    final updated = [ref, ...existing.where((b) => b.bookingId != ref.bookingId)];
    final capped = updated.take(20).toList();
    await prefs.setString(_bookingsKey, jsonEncode(capped.map((b) => b.toJson()).toList()));
  }
}
