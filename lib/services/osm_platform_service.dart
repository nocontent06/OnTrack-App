// lib/services/osm_platform_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Fetch all platforms near the given coordinates.
Future<List<Map<String, dynamic>>> fetchPlatforms(double lat, double lon) async {
  final query = '''
[out:json][timeout:25];
(
  node["railway"="platform"](around:300,$lat,$lon);
  way["railway"="platform"](around:300,$lat,$lon);
  relation["railway"="platform"](around:300,$lat,$lon);
);
out center tags;
''';
  final url = 'https://overpass-api.de/api/interpreter';
  final response = await http.post(Uri.parse(url), body: {'data': query});
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return List<Map<String, dynamic>>.from(data['elements']);
  } else {
    throw Exception('Failed to fetch platforms');
  }
}

/// Filter platforms by platformRef (handles "1;11;21" etc).
Map<String, dynamic>? findPlatform(List<Map<String, dynamic>> platforms, String? platformRef) {
  if (platformRef == null) return null;
  for (final p in platforms) {
    final ref = p['tags']?['ref'];
    if (ref == null) continue;
    final refs = ref.split(';').map((s) => s.trim());
    if (refs.contains(platformRef)) return p;
  }
  return null;
}