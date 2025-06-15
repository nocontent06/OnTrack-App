import 'dart:convert';
import 'package:http/http.dart' as http;

class OebbApiService {
  static const String baseUrl = 'https://oebb.macistry.com/api'; // Replace with your actual base URL

  // Search for stops
  static Future<List<Map<String, dynamic>>> searchStops(String query) async {
    final url = '$baseUrl/locations?query=$query';
    final response = await http.get(Uri.parse(url));
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

  static Future<Map<String, dynamic>> getJourney(String tripId) async {
    final encodedTripId = Uri.encodeComponent(tripId);
    final url = Uri.parse('$baseUrl/trips/$encodedTripId?stopovers=true');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['trip'];
    } else {
      throw Exception('Failed to load journey');
    }
  }

  /// Search for journeys, supporting via and via change duration (transferTime).
  static Future<List<Map<String, dynamic>>> searchJourneys(
    String fromId,
    String toId, {
    DateTime? departure,
    DateTime? arrival,
    int maxJourneys = 10,
    List<String>? via,
    List<int?>? viaChangeMins,
    int? transferTime,
    bool? accessibility,
    bool? bike,
    bool? startWithWalking,
    String? walkingSpeed,
    String? language,
    bool? nationalExpress,
    bool? national,
    bool? interregional,
    bool? regional,
    bool? suburban,
    bool? bus,
    bool? ferry,
    bool? subway,
    bool? tram,
    bool? onCall,
    bool? tickets,
    bool? polylines,
    bool? subStops,
    bool? entrances,
    bool? remarks,
    bool? scheduledDays,
    bool? pretty,
  }) async {
    final params = <String, dynamic>{
      'from': fromId,
      'to': toId,
      'results': '$maxJourneys',
    };

    if (departure != null) params['departure'] = departure.toUtc().toIso8601String();
    if (arrival != null) params['arrival'] = arrival.toUtc().toIso8601String();
    if (transferTime != null) params['transferTime'] = transferTime.toString();
    if (accessibility != null) params['accessibility'] = accessibility.toString();
    if (bike != null) params['bike'] = bike.toString();
    if (startWithWalking != null) params['startWithWalking'] = startWithWalking.toString();
    if (walkingSpeed != null) params['walkingSpeed'] = walkingSpeed;
    if (language != null) params['language'] = language;
    if (nationalExpress != null) params['nationalExpress'] = nationalExpress.toString();
    if (national != null) params['national'] = national.toString();
    if (interregional != null) params['interregional'] = interregional.toString();
    if (regional != null) params['regional'] = regional.toString();
    if (suburban != null) params['suburban'] = suburban.toString();
    if (bus != null) params['bus'] = bus.toString();
    if (ferry != null) params['ferry'] = ferry.toString();
    if (subway != null) params['subway'] = subway.toString();
    if (tram != null) params['tram'] = tram.toString();
    if (onCall != null) params['onCall'] = onCall.toString();
    if (tickets != null) params['tickets'] = tickets.toString();
    if (polylines != null) params['polylines'] = polylines.toString();
    if (subStops != null) params['subStops'] = subStops.toString();
    if (entrances != null) params['entrances'] = entrances.toString();
    if (remarks != null) params['remarks'] = remarks.toString();
    if (scheduledDays != null) params['scheduledDays'] = scheduledDays.toString();
    if (pretty != null) params['pretty'] = pretty.toString();

    // Build query string for multiple vias and transferTimes, paired by index
    final queryParts = <String>[];
    params.forEach((key, value) {
      if (value != null) {
        queryParts.add('${Uri.encodeQueryComponent(key)}=${Uri.encodeQueryComponent(value.toString())}');
      }
    });

    if (via != null && via.isNotEmpty) {
      for (var i = 0; i < via.length; i++) {
        queryParts.add('via=${Uri.encodeQueryComponent(via[i])}');
        if (viaChangeMins != null && i < viaChangeMins.length && viaChangeMins[i] != null) {
          queryParts.add('transferTime=${Uri.encodeQueryComponent(viaChangeMins[i].toString())}');
        }
      }
    }

    final url = '$baseUrl/journeys?${queryParts.join('&')}';

    print('Searching journeys with URL: $url'); // Debugging line
    print('Parameters: $params'); // Debugging line

    final response = await http.get(Uri.parse(url));
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
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final stopovers = (data['trip']?['stopovers'] as List<dynamic>?) ?? [];
      final stops = stopovers
          .map((s) => {
                'name': s['stop']['name'],
                'lat': s['stop']['location']['latitude'],
                'lon': s['stop']['location']['longitude'],
                'plannedArrival': s['plannedArrival'],
                'actualArrival': s['actualArrival']
              })
          .toList();
      return List<Map<String, dynamic>>.from(stops);
    } else {
      throw Exception('Failed to load stopovers');
    }
  }
}