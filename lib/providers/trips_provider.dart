import 'package:flutter/material.dart';
import 'package:ontrack/services/saved_trips_service.dart';

class TripsProvider extends ChangeNotifier {
  final SavedTripsService _service = SavedTripsService();
  List<Map<String, dynamic>> _trips = [];

  List<Map<String, dynamic>> get trips => _trips;

  TripsProvider() {
    loadTrips();
  }

  Future<void> loadTrips() async {
    _trips = await _service.loadTrips();
    notifyListeners();
  }

  Future<void> addTrip(Map<String, dynamic> trip) async {
    await _service.addTrip(trip);
    await loadTrips();
  }

  Future<void> removeTrip(Map<String, dynamic> trip) async {
    await _service.removeTrip(trip);
    await loadTrips();
  }

  Future<void> clearTrips() async {
    await _service.clearTrips();
    await loadTrips();
  }

  Future<void> toggleFavourite(Map<String, dynamic> trip) async {
    trip['favourite'] = !(trip['favourite'] == true);
    await _service.updateTrip(trip);
    await loadTrips();
  }

  Future<void> archiveTrip(Map<String, dynamic> trip) async {
    trip['archived'] = true;
    await _service.updateTrip(trip);
    await loadTrips();
  }
}