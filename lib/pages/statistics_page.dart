import 'dart:convert';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart'; // Add this import for date formatting
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:ontrack/providers/trips_provider.dart';
import 'package:ontrack/services/oebb_api_service.dart';
import 'package:ontrack/services/search_history_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StatsCalculator {
  final List<dynamic> trips;
  final Distance distanceCalculator = const Distance();

  StatsCalculator(this.trips);

  // Computes the total distance for one trip.
  double _calculateTripDistance(Map<String, dynamic> trip) {
    double d = 0.0;
    final legs = trip['legs'] as List<dynamic>? ?? [];
    for (var leg in legs) {
      final mode = leg['line']?['mode'] ?? leg['mode'] ?? '';
      double legDistance = 0.0;
      if (mode == 'train') {
        final stopovers = leg['stopovers'] as List<dynamic>? ?? [];
        if (stopovers.isNotEmpty) {
          final fromName = leg['origin']?['name'];
          final toName = leg['destination']?['name'];
          legDistance = _computeDistanceFromStopovers(stopovers, fromName, toName);
          //debugPrint('Computed distance from stopovers: $legDistance km');
        }
      } else {
        // For changeovers or other modes, use provided distance in meters.
        if (leg.containsKey('distance') && leg['distance'] != null) {
          double m = 0;
          if (leg['distance'] is int) {
            m = (leg['distance'] as int).toDouble();
          } else if (leg['distance'] is double) {
            m = leg['distance'];
          } else if (leg['distance'] is String) {
            m = double.tryParse(leg['distance']) ?? 0;
          }
          legDistance = m / 1000.0;
          //debugPrint('Using API provided distance: $legDistance km');
        }
      }
      d += legDistance;
    }
    //debugPrint('Total distance for trip "${trip['from'] ?? ''} - ${trip['to'] ?? ''}": $d km');

    // If there are no stops, try computing directly from from/to locations:
    if (legs.isEmpty && trip['fromLocation'] != null && trip['toLocation'] != null) {
      final from = LatLng(
        (trip['fromLocation']['latitude'] as num).toDouble(),
        (trip['fromLocation']['longitude'] as num).toDouble(),
      );
      final to = LatLng(
        (trip['toLocation']['latitude'] as num).toDouble(),
        (trip['toLocation']['longitude'] as num).toDouble(),
      );
      double fallbackDistance = distanceCalculator(from, to) / 1000.0;
      //debugPrint('Fallback computed distance: $fallbackDistance km');
      return fallbackDistance;
    }

    return d;
  }

  double _computeDistanceFromStops(List<dynamic> stops) {
    double totalMeters = 0;
    for (int i = 1; i < stops.length; i++) {
      final prev = stops[i - 1];
      final curr = stops[i];
      if (_hasValidLocation(prev['location']) && _hasValidLocation(curr['location'])) {
        final from = LatLng(
          (prev['location']['latitude'] as num).toDouble(),
          (prev['location']['longitude'] as num).toDouble(),
        );
        final to = LatLng(
          (curr['location']['latitude'] as num).toDouble(),
          (curr['location']['longitude'] as num).toDouble(),
        );
        totalMeters += distanceCalculator(from, to);
      }
    }
    return totalMeters / 1000.0;
  }

  double _computeDistanceFromStopovers(List<dynamic> stopovers, String fromName, String toName) {
    int fromIdx = stopovers.indexWhere((s) =>
        (s['name'] ?? s['stop']?['name']) == fromName);
    int toIdx = stopovers.indexWhere((s) =>
        (s['name'] ?? s['stop']?['name']) == toName);

    if (fromIdx == -1 || toIdx == -1 || fromIdx >= toIdx) return 0.0;

    double totalMeters = 0;
    for (int i = fromIdx; i < toIdx; i++) {
      double? lat1 = (stopovers[i]['lat'] ?? stopovers[i]['stop']?['location']?['latitude'])?.toDouble();
      double? lon1 = (stopovers[i]['lon'] ?? stopovers[i]['stop']?['location']?['longitude'])?.toDouble();
      double? lat2 = (stopovers[i+1]['lat'] ?? stopovers[i+1]['stop']?['location']?['latitude'])?.toDouble();
      double? lon2 = (stopovers[i+1]['lon'] ?? stopovers[i+1]['stop']?['location']?['longitude'])?.toDouble();

      if (lat1 != null && lon1 != null && lat2 != null && lon2 != null) {
        totalMeters += distanceCalculator(LatLng(lat1, lon1), LatLng(lat2, lon2));
      }
    }
    return totalMeters / 1000.0;
  }

  bool _hasValidLocation(dynamic location) {
    return location != null &&
           location['latitude'] != null &&
           location['longitude'] != null;
  }

  double get totalKilometers {
    double sum = 0;
    for (var trip in trips) {
      sum += _calculateTripDistance(trip);
    }
    return sum;
  }

  int get totalTrips => trips.length;

  double get totalTravelHours {
    double totalMinutes = 0;
    for (var trip in trips) {
      final legs = trip['legs'] as List<dynamic>? ?? [];
      for (var leg in legs) {
        // Prefer 'duration' if available, otherwise calculate from departure/arrival
        if (leg['duration'] != null) {
          totalMinutes += (leg['duration'] as num).toDouble();
        } else if (leg['departure'] != null && leg['arrival'] != null) {
          final dep = DateTime.tryParse(leg['departure']);
          final arr = DateTime.tryParse(leg['arrival']);
          if (dep != null && arr != null) {
            totalMinutes += arr.difference(dep).inMinutes;
          }
        }
      }
    }
    return totalMinutes / 60.0;
  }

  String get totalTravelHoursAndMinutes {
    int totalMinutes = 0;
    for (var trip in trips) {
      final legs = trip['legs'] as List<dynamic>? ?? [];
      for (var leg in legs) {
        final depStr = leg['departure'];
        final arrStr = leg['arrival'];
        if (depStr != null && arrStr != null) {
          final dep = DateTime.tryParse(depStr);
          final arr = DateTime.tryParse(arrStr);
          if (dep != null && arr != null) {
            final diff = arr.difference(dep).inMinutes;
            if (diff > 0) {
              totalMinutes += diff;
              //debugPrint('Adding ${diff} min for leg: $depStr to $arrStr');
            }
          }
        }
      }
    }
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    //debugPrint('Total travel time: $hours hrs $minutes min');
    return '$hours hrs $minutes min';
  }

  int get totalPlaces {
    Set<String> places = {};
    for (var trip in trips) {
      if (trip['from'] != null) places.add(trip['from']);
      if (trip['to'] != null) places.add(trip['to']);
      if (trip['via'] != null && trip['via'] is List) {
        places.addAll(List<String>.from(trip['via']));
      }
    }
    return places.length;
  }

  Map<String, int> get stationSearches {
    Map<String, int> counts = {};
    for (var trip in trips) {
      if (trip['from'] != null) {
        counts[trip['from']] = (counts[trip['from']] ?? 0) + 1;
      }
      if (trip['to'] != null) {
        counts[trip['to']] = (counts[trip['to']] ?? 0) + 1;
      }
      if (trip['via'] != null && trip['via'] is List) {
        for (var station in trip['via']) {
          counts[station] = (counts[station] ?? 0) + 1;
        }
      }
    }
    print("Station searches: $counts");
    return counts;
  }

  String get mostSearchedStation {
    String most = "";
    int max = 0;
    stationSearches.forEach((station, count) {
      if (count > max) {
        max = count;
        most = station;
      }
    });
    return most;
  }

  List<MapEntry<String, int>> get topSearches {
    var entries = stationSearches.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries.take(5).toList();
  }
}

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});
 
  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}
 
class _StatisticsPageState extends State<StatisticsPage> {
  bool _loadingStopovers = true;
  Map<String, int> _stationSearchCounts = {};
  String _mostSearchedStation = '';
  List<MapEntry<String, int>> _topSearches = [];

  @override
  void initState() {
    super.initState();
    _loadStopoversForTrips();
    _loadSearchCounts();
  }
  
  Future<void> _loadStopoversForTrips() async {
    // Retrieve trips from the provider.
    final tripsProvider = Provider.of<TripsProvider>(context, listen: false);
    final trips = tripsProvider.trips;
    bool updated = false;
    
    // Iterate over all trips and their legs.
    for (var trip in trips) {
      if (trip['legs'] is List) {
        for (var leg in trip['legs']) {
          //print('Leg tripId: ${leg['tripId']}');
          if (leg['tripId'] != null) {
            // Fetch stopovers using leg['tripId']
            final fetchedStopovers = await OebbApiService.getStopovers(leg['tripId']);
            if (fetchedStopovers.isNotEmpty) {
              //print('Fetched ${fetchedStopovers.length} stopovers for trip ${leg['tripId']}');
              leg['stopovers'] = fetchedStopovers;
              updated = true;
              //debugPrint('Loaded ${fetchedStopovers.length} stopovers for trip ${leg['tripId']}');
            }
          }
        }
      }
    }
    if (updated) {
      setState(() {});
    }
    setState(() {
      _loadingStopovers = false;
    });
  }

  Future<void> _loadSearchCounts() async {
    final counts = await StationSearchHistoryService.loadStationSearchCounts();
    setState(() {
      _stationSearchCounts = counts;
      _mostSearchedStation = counts.entries.isEmpty
          ? ''
          : counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      _topSearches = counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (_topSearches.length > 5) _topSearches = _topSearches.take(5).toList();
    });
  }
 
  @override
  Widget build(BuildContext context) {
    final trips = Provider.of<TripsProvider>(context).trips;
    final stats = StatsCalculator(trips);
 
    return Scaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Travel Statistics',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _loadingStopovers
                ? const Center(child: CircularProgressIndicator())
                : Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _buildStatCard('Kilometers Traveled', '${stats.totalKilometers.toInt()} km', const Duration(seconds: 2)),
                      _buildStatCard('Total Trips', '${stats.totalTrips}', const Duration(seconds: 2)),
                      _buildStatCard('Hours Traveling', stats.totalTravelHoursAndMinutes, const Duration(seconds: 2)),
                      _buildStatCard('Places Visited', '${stats.totalPlaces}', const Duration(seconds: 2)),
                    ],
                  ),
            const SizedBox(height: 24),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              child: ListTile(
                leading: const Icon(Icons.star, color: Colors.amber),
                title: const Text('Most Searched Station'),
                subtitle: Text(
                  _mostSearchedStation,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              child: SizedBox(
                width: double.infinity,
                height: 320, // Increased height for better chart fit
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: DistanceChart(
                    trips: trips,
                    getTripDistance: (trip) => StatsCalculator([trip]).totalKilometers,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Top Searches',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildTopSearches(),
          ],
        ),
      ),
    );
  }
 
  Widget _buildStatCard(String label, String value, Duration duration) {
    // Special handling for time values like "X hrs Y min"
    if (label == 'Hours Traveling' && value.contains('hrs')) {
      // Extract total minutes from your getter for animation
      final totalMinutes = RegExp(r'(\d+)\s*hrs\s*(\d+)\s*min')
          .firstMatch(value)
          ?.groups([1, 2])
          ?.map((e) => int.tryParse(e ?? '0') ?? 0)
          ?.toList();
      final total = (totalMinutes != null && totalMinutes.length == 2)
          ? totalMinutes[0] * 60 + totalMinutes[1]
          : 0;

      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          width: 150,
          child: Column(
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: total.toDouble()),
                duration: duration,
                builder: (context, val, child) {
                  final hours = val ~/ 60;
                  final minutes = (val % 60).toInt();
                  return Text(
                    '$hours hrs\n$minutes min',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  );
                },
              ),
            ],
          ),
        ),
      );
    }

    // Default for other stats
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        width: 150,
        child: Column(
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(
                  begin: 0,
                  end: double.tryParse(value.replaceAll(RegExp(r'\D'), '')) ?? 0),
              duration: duration,
              builder: (context, val, child) {
                String suffix = value.replaceAll(RegExp(r'\d'), '');
                return Text(
                  '${val.toInt()}$suffix',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                );
              },
            ),
          ],
        ),
      )
    );
  }
 
  Widget _buildTopSearches() {
    return Column(
      children: _topSearches.map((entry) {
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: const Icon(Icons.location_on),
            title: Text(entry.key),
            trailing: Text('${entry.value} searches'),
          ),
        );
      }).toList(),
    );
  }
}

Future<Map<String, int>> loadStationSearchCounts() async {
  final prefs = await SharedPreferences.getInstance();
  final history = prefs.getStringList('searchHistory') ?? [];
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

enum ChartPeriod { day, week, month, year }

class DistanceChart extends StatefulWidget {
  final List<Map<String, dynamic>> trips;
  final double Function(Map<String, dynamic>) getTripDistance;

  const DistanceChart({super.key, required this.trips, required this.getTripDistance});

  @override
  State<DistanceChart> createState() => _DistanceChartState();
}

class _DistanceChartState extends State<DistanceChart> {
  ChartPeriod _selectedPeriod = ChartPeriod.month;

  @override
  Widget build(BuildContext context) {
    final groupedData = _groupTripsByPeriod(widget.trips, _selectedPeriod);

    final sortedKeys = groupedData.keys.toList()..sort();
    final spots = [
      for (int i = 0; i < sortedKeys.length; i++)
        FlSpot(i.toDouble(), groupedData[sortedKeys[i]]!)
    ];

    // Calculate maxY and round up to next "nice" unit
    final maxY = spots.isEmpty
        ? 10.0
        : ((spots.map((e) => e.y).reduce((a, b) => a > b ? a : b) / 10).ceil() * 10).toDouble();

    // Calculate y-axis interval so there are at most 10 labels
    double interval = 10;
    if (maxY > 0) {
      interval = (maxY / 8).ceilToDouble();
      // Round interval to nearest 10, 50, 100, etc. for nicer labels
      if (interval > 10) {
        int magnitude = interval.toInt().toString().length - 1;
        int base = pow(10, magnitude).toInt();
        interval = (((interval / base).ceil()) * base).toDouble();
      }
    }

    // Add padding to left and right so dots are not on the border
    final minX = spots.isEmpty ? 0.0 : -0.5;
    final maxX = spots.isEmpty ? 0.0 : (spots.length - 1).toDouble() + 0.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: ChartPeriod.values.map((period) {
            final label = period.name[0].toUpperCase() + period.name.substring(1);
            return ChoiceChip(
              label: Text(label),
              selected: _selectedPeriod == period,
              onSelected: (_) => setState(() => _selectedPeriod = period),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: spots.isEmpty
                ? const Center(child: Text('No data'))
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(show: true),
                      clipData: FlClipData.all(),
                      borderData: FlBorderData(
                        show: true,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            interval: interval,
                          ),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              // Only show label if value is a whole number and matches a data point
                              if (idx < 0 || idx >= sortedKeys.length || value != idx.toDouble()) {
                                return const SizedBox.shrink();
                              }
                              final date = sortedKeys[idx];
                              switch (_selectedPeriod) {
                                case ChartPeriod.day:
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(DateFormat('dd.MM.').format(date)),
                                  );
                                case ChartPeriod.week:
                                  final week = _isoWeekNumber(date);
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text('CW $week'),
                                  );
                                case ChartPeriod.month:
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(DateFormat('MMM yyyy').format(date)),
                                  );
                                case ChartPeriod.year:
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(DateFormat('yyyy').format(date)),
                                  );
                              }
                            },
                            interval: 1,
                          ),
                        ),
                      ),
                      minY: 0,
                      maxY: maxY,
                      minX: minX,
                      maxX: maxX,
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: false,
                          color: Theme.of(context).colorScheme.primary,
                          barWidth: 3,
                          dotData: FlDotData(show: true),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Map<DateTime, double> _groupTripsByPeriod(List<Map<String, dynamic>> trips, ChartPeriod period) {
    final Map<DateTime, double> grouped = {};
    for (final trip in trips) {
      final depStr = trip['dep'] ?? trip['departure'];
      if (depStr == null) continue;
      final dep = DateTime.tryParse(depStr);
      if (dep == null) continue;
      DateTime key;
      switch (period) {
        case ChartPeriod.day:
          key = DateTime(dep.year, dep.month, dep.day);
          break;
        case ChartPeriod.week:
          final monday = dep.subtract(Duration(days: dep.weekday - 1));
          key = DateTime(monday.year, monday.month, monday.day);
          break;
        case ChartPeriod.month:
          key = DateTime(dep.year, dep.month);
          break;
        case ChartPeriod.year:
          key = DateTime(dep.year);
          break;
      }
      grouped[key] = (grouped[key] ?? 0) + widget.getTripDistance(trip);
    }
    return grouped;
  }

  int _isoWeekNumber(DateTime date) {
    final thursday = date.add(Duration(days: 4 - (date.weekday == 7 ? 0 : date.weekday)));
    final firstDayOfYear = DateTime(thursday.year, 1, 1);
    final days = thursday.difference(firstDayOfYear).inDays;
    return 1 + (days / 7).floor();
  }
}