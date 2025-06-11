import 'dart:convert';
import 'package:http/http.dart' as http;

class OebbApiService {
  static const String baseUrl = 'https://oebb.macistry.com/api'; // Replace with your actual base URL

  // Search for stops
  static Future<List<Map<String, dynamic>>> searchStops(String query) async {
    final url = '$baseUrl/locations?query=$query';
    print('Calling: $url');
    final response = await http.get(Uri.parse(url));
    print('Response: ${response.body}');
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is List) {
        // Each item is a stop, e.g. data[0]['name']
        return List<Map<String, dynamic>>.from(data);
      } else if (data is Map && data['locations'] is List) {
        // In case the API wraps it in a 'locations' key
        return List<Map<String, dynamic>>.from(data['locations']);
      } else {
        return [];
      }
    }
    throw Exception('Failed to load stops');
  }

  // Search for journeys
  static Future<List<Map<String, dynamic>>> searchJourneys(
    String fromId,
    String toId, {
    DateTime? departure,
    int maxJourneys = 10,
  }) async {
    String url = '$baseUrl/journeys?from=$fromId&to=$toId';
    if (departure != null) {
      url += '&departure=${Uri.encodeComponent(departure.toUtc().toIso8601String())}';
    }
    print('Calling: $url');
    final response = await http.get(Uri.parse(url));
    print('Response: ${response.body}');
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      } else if (data is Map && data['journeys'] is List) {
        return List<Map<String, dynamic>>.from(data['journeys']);
      } else {
        return [];
      }
    }
    throw Exception('Failed to load journeys');
  }

  static Future<List<Map<String, dynamic>>> getStopovers(String tripId) async {
    final encodedTripId = Uri.encodeComponent(tripId);
    final url = Uri.parse('$baseUrl/trips/$encodedTripId?stopovers=true');
    final response = await http.get(url);
    print('Stopovers response: ${response.statusCode} ${response.body}');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final stopovers = (data['trip']?['stopovers'] as List<dynamic>? ?? []);
      final stops = stopovers
          .map((s) => {
                'name': s['stop']['name'],
                'lat': s['stop']['location']['latitude'],
                'lon': s['stop']['location']['longitude'],
                'plannedArrival': s['plannedArrival'],
                'actualArrival': s['actualArrival'],
              })
          .toList();
      return List<Map<String, dynamic>>.from(stops);
    } else {
      throw Exception('Failed to load stopovers');
    }
  }
}