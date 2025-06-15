import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SavedTripsService {
  // In a real app, load from persistence; here we use an in‑memory list.
  final List<Map<String, dynamic>> _trips = [];

  Future<List<Map<String, dynamic>>> loadTrips() async {
    // Simulate delay from I/O
    await Future.delayed(const Duration(milliseconds: 300));
    return _trips;
  }

  Future<void> addTrip(Map<String, dynamic> trip) async {
    // In a real app, add error handling and persistence here
    _trips.add(trip);
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<void> removeTrip(Map<String, dynamic> trip) async {
    _trips.removeWhere((t) => t == trip);
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<void> clearTrips() async {
    _trips.clear();
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<void> updateTrip(Map<String, dynamic> trip) async {
    final trips = await loadTrips();
    final index = trips.indexWhere((t) =>
        t['dep'] == trip['dep'] &&
        t['arr'] == trip['arr'] &&
        t['from'] == trip['from'] &&
        t['to'] == trip['to']);
    if (index != -1) {
      trips[index] = trip;
      await saveTrips(trips);
    }
  }

  Future<void> saveTrips(List<Map<String, dynamic>> trips) async {
    final prefs = await SharedPreferences.getInstance();
    final tripStrings = trips.map((t) => jsonEncode(t)).toList();
    await prefs.setStringList('savedTrips', tripStrings);
  }
}