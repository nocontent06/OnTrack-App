import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StationSearchHistoryService {
  static const String _key = 'searchHistory';

  static Future<void> saveSearch(String from, String to, DateTime? dateTime) async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_key) ?? [];
    final dt = dateTime?.toIso8601String() ?? '';
    final entry = jsonEncode({'from': from, 'to': to, 'dateTime': dt});
    if (!history.contains(entry)) {
      history.add(entry);
      await prefs.setStringList(_key, history);
    }
  }

  static Future<Map<String, int>> loadStationSearchCounts() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_key) ?? [];
    final Map<String, int> counts = {};
    for (final entry in history) {
      final data = jsonDecode(entry);
      for (final station in [data['from'], data['to']]) {
        if (station != null && station is String && station.isNotEmpty) {
          counts[station] = (counts[station] ?? 0) + 1;
        }
      }
    }
    return counts;
  }
}