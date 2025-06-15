import 'dart:convert';
import 'package:http/http.dart' as http;

// Simple in-memory cache
final Map<String, String> _countryCache = {};

Future<String?> getCountryFromLatLon(double lat, double lon) async {
  final key = '${lat.toStringAsFixed(5)},${lon.toStringAsFixed(5)}';
  if (_countryCache.containsKey(key)) {
    return _countryCache[key];
  }
  final url = 'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lon';
  final response = await http.get(Uri.parse(url), headers: {
    'User-Agent': 'OnTrackApp/1.0 (admin@macistry.com)' // Nominatim requires a user agent
  });
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    final country = data['address']?['country'];
    print('Country for $key: $country');
    if (country != null) {
      _countryCache[key] = country;
    }
    return country;
  }
  return null;
}