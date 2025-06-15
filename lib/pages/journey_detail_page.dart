import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'train_detail_page.dart';
import 'walk_detail_page.dart';
import 'package:provider/provider.dart';
import '../providers/trips_provider.dart';

class JourneyDetailPage extends StatefulWidget {
  final Map<String, dynamic> journey;
  final bool isAlreadySaved;

  const JourneyDetailPage({
    super.key,
    required this.journey,
    this.isAlreadySaved = false,
  });

  @override
  State<JourneyDetailPage> createState() => _JourneyDetailPageState();
}

class _JourneyDetailPageState extends State<JourneyDetailPage> {
  late final Map<String, dynamic> journey;
  bool isTripSaved = false;

  @override
  void initState() {
    super.initState();
    journey = widget.journey;
    // Using Provider in initState: safe with listen: false.
    isTripSaved = _isTripAlreadySaved();
  }

  bool _isTripAlreadySaved() {
    final trips = Provider.of<TripsProvider>(context, listen: false).trips;
    // Basic check: compare using key fields. Adjust as needed.
    return trips.any((t) =>
        t['from'] == journey['legs']?[0]?['origin']?['name'] &&
        t['to'] == journey['legs']?.last?['destination']?['name'] &&
        t['dep'] == journey['legs']?[0]?['departure']);
  }

  String formatTime(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Color getTrainColor(String lineName, String mode) {
    final upper = lineName.toUpperCase();
    if (mode == 'bus') return Colors.grey;
    if (upper.startsWith('ICE') ||
        upper.startsWith('IC') ||
        upper.startsWith('EC') ||
        upper.startsWith('D ') ||
        upper.startsWith('FR') ||
        upper.startsWith('RJ') ||
        upper.startsWith('RJX')) {
      return Colors.red;
    }
    if (upper.startsWith('RB') ||
        upper.startsWith('RE') ||
        upper.startsWith('BRB') ||
        upper.startsWith('S') ||
        upper.startsWith('REX')) {
      return Colors.blue;
    }
    if (upper.startsWith('WB')) {
      return Colors.lime;
    }
    if (upper.startsWith('SV') || upper.startsWith('BUSSV')) {
      return Colors.yellow[700]!;
    }
    return Colors.blue[700]!;
  }

  Widget buildLegCard(Map<String, dynamic> leg, int index) {
    final isWalking = leg['walking'] == true;
    final mode = (leg['line']?['mode'] ?? '');
    final line = leg['line'] as Map<String, dynamic>?;

    final depTime = formatTime(leg['departure']);
    final arrTime = formatTime(leg['arrival']);
    final origin = leg['origin']?['name'] ?? '';
    final destination = leg['destination']?['name'] ?? '';
    final platform = leg['departurePlatform'] ?? '';
    final arrPlatform = leg['arrivalPlatform'] ?? '';
    final direction = leg['direction'] ?? '';
    final lineName = line?['name'] ?? (isWalking ? 'Walk' : 'Unknown');
    final operatorName = line?['operator']?['name'] ?? '';
    final product = line?['productName'] ?? '';
    final remarks = (leg['remarks'] as List<dynamic>?)
        ?.map((r) => r['text'] as String?)
        .where((t) => t != null && t.isNotEmpty)
        .toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final walkingColor = isDark ? Colors.white : Colors.black;
    final trainColor = getTrainColor(lineName, mode);

    return GestureDetector(
      onTap: () async {
        if (isWalking || mode == 'walking') {
          String? prevArrival;
          String? nextDeparture;
          String? nextTrain;
          String? prevArrivalPlatform;
          String? nextDeparturePlatform;
          String? stationName;
          double? stationLat;
          double? stationLon;

          // Find previous train leg (for arrival platform)
          final legs = journey['legs'] as List<dynamic>? ?? [];
          for (int i = index - 1; i >= 0; i--) {
            final prevLeg = legs[i] as Map<String, dynamic>;
            if (prevLeg['walking'] != true && (prevLeg['line']?['mode'] ?? '') != 'walking') {
              prevArrival = prevLeg['arrival'];
              prevArrivalPlatform = prevLeg['arrivalPlatform'];
              stationName = prevLeg['destination']?['name'];
              stationLat = prevLeg['destination']?['location']?['latitude'];
              stationLon = prevLeg['destination']?['location']?['longitude'];
              break;
            }
          }
          // Find next train leg (for departure platform)
          for (int i = index + 1; i < legs.length; i++) {
            final nextLeg = legs[i] as Map<String, dynamic>;
            if (nextLeg['walking'] != true && (nextLeg['line']?['mode'] ?? '') != 'walking') {
              nextDeparture = nextLeg['departure'];
              nextTrain = nextLeg['line']?['name'] ??
                  nextLeg['line']?['productName'] ??
                  nextLeg['line']?['id'] ??
                  'Unknown';
              nextDeparturePlatform = nextLeg['departurePlatform'];
              break;
            }
          }

          // Calculate change time in minutes
          int changeTimeMinutes = 0;
          if (prevArrival != null && nextDeparture != null) {
            final arr = DateTime.tryParse(prevArrival);
            final dep = DateTime.tryParse(nextDeparture);
            if (arr != null && dep != null) {
              changeTimeMinutes = dep.difference(arr).inMinutes;
            }
          }

          // Calculate walking time from distance (meters) at 5km/h
          String? walkingTimeStr;
          dynamic distanceMeters = leg['distance'] ?? leg['Distance'];
          if (distanceMeters != null) {
            double? meters;
            if (distanceMeters is int) {
              meters = distanceMeters.toDouble();
            } else if (distanceMeters is double) {
              meters = distanceMeters;
            } else if (distanceMeters is String) {
              meters = double.tryParse(distanceMeters);
            }
            if (meters != null && meters > 0) {
              final walkingMinutes = (meters / (5000 / 60)).round();
              walkingTimeStr = '$walkingMinutes min';
            }
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WalkDetailPage(
                walk: leg,
                nextDeparture: nextDeparture,
                nextTrain: nextTrain,
                changeTime: changeTimeMinutes > 0 ? '$changeTimeMinutes min' : null,
                prevArrivalPlatform: prevArrivalPlatform,
                nextDeparturePlatform: nextDeparturePlatform,
                stationLat: stationLat,
                stationLon: stationLon,
                stationName: stationName,
                walkingTime: walkingTimeStr,
              ),
            ),
          );
        } else {
          final train = {
            'name': lineName,
            'operator': operatorName,
            'category': line?['category'] ?? '',
            'productName': product,
          };
          final stops = (leg['stops'] as List<dynamic>? ?? [])
              .map((s) => {
                    'name': s['name'] ?? '',
                    'lat': s['location']?['latitude'] ?? 47.0707,
                    'lon': s['location']?['longitude'] ?? 15.4395,
                    'plannedArrival': s['plannedArrival'] ?? '',
                    'actualArrival': s['actualArrival'] ?? '',
                  })
              .toList();
          LatLng? currentLocation;
          if (leg['currentLocation'] != null) {
            currentLocation = LatLng(
              leg['currentLocation']['latitude'],
              leg['currentLocation']['longitude'],
            );
          } else if (stops.isNotEmpty) {
            currentLocation = LatLng(stops.first['lat'], stops.first['lon']);
          }
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => TrainDetailPage(
              train: train,
              tripId: leg['tripId'] ?? '',
              currentLocation: currentLocation ?? LatLng(47.0707, 15.4395),
            ),
          ));
        }
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isWalking
                        ? Icons.directions_walk
                        : (mode == 'bus'
                            ? Icons.directions_bus
                            : Icons.train),
                    color: isWalking ? walkingColor : trainColor,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lineName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: isWalking ? walkingColor : trainColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                          softWrap: true,
                        ),
                        if (operatorName.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Text(
                              operatorName,
                              style: const TextStyle(fontSize: 13, color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (product.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Chip(
                      label: Text(
                        product,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black),
                      ),
                      backgroundColor: Colors.grey[200],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('From:', style: TextStyle(color: Colors.grey[600])),
                        Text(
                          origin,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                          softWrap: true,
                        ),
                        if (depTime.isNotEmpty)
                          Text('Dep: $depTime', style: const TextStyle(fontSize: 13)),
                        if (platform.isNotEmpty)
                          Text('Platform: $platform', style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('To:', style: TextStyle(color: Colors.grey[600])),
                        Text(
                          destination,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                          softWrap: true,
                          textAlign: TextAlign.right,
                        ),
                        if (arrTime.isNotEmpty)
                          Text('Arr: $arrTime', style: const TextStyle(fontSize: 13)),
                        if (arrPlatform.isNotEmpty)
                          Text('Platform: $arrPlatform', style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              if (direction.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text('Direction: $direction',
                      style: const TextStyle(fontSize: 13, color: Colors.grey)),
                ),
              if (remarks != null && remarks.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: remarks
                        .map((t) => Row(
                              children: [
                                const Icon(Icons.info_outline, size: 16, color: Colors.teal),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    t!,
                                    style: const TextStyle(fontSize: 13, color: Colors.teal),
                                  ),
                                ),
                              ],
                            ))
                        .toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> saveTripWithStopovers(Map<String, dynamic> journey) async {
    // Convert stopovers to stops if any
    for (final leg in journey['legs']) {
      final mode = leg['line']?['mode'] ?? leg['mode'];
      if (mode == 'train' && leg['stopovers'] != null) {
        leg['stops'] = (leg['stopovers'] as List)
            .map((s) => {
                  'location': s['stop']?['location'],
                })
            .where((s) => s['location'] != null)
            .toList();
      }
    }
    // Instead of using the old SavedTrips, use the provider to add the trip.
    Provider.of<TripsProvider>(context, listen: false).addTrip({
      'from': journey['legs']?[0]?['origin']?['name'] ?? '',
      'to': journey['legs']?.last?['destination']?['name'] ?? '',
      'dep': journey['legs']?[0]?['departure'],
      'arr': journey['legs']?.last?['arrival'],
      'legs': journey['legs'],
    });
  }

  Future<void> _toggleSaveTrip() async {
    setState(() => isTripSaved = !isTripSaved);
    if (isTripSaved) {
      await saveTripWithStopovers(journey);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip saved!')),
      );
    } else {
      // Remove trip using provider. Here we use a basic equality check – adjust as needed.
      Provider.of<TripsProvider>(context, listen: false).removeTrip(journey);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip unsaved!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final legs = journey['legs'] as List<dynamic>? ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journey Details'),
        backgroundColor: Colors.teal,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Action chips row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 10,
              children: [
                ActionChip(
                  avatar: Icon(Icons.star, color: isTripSaved ? Colors.black : Colors.amber),
                  label: Text(
                    isTripSaved ? 'Unsave Trip' : 'Save Trip',
                    style: TextStyle(
                      color: isTripSaved ? Colors.black : null,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: isTripSaved ? Colors.amber : null,
                  onPressed: _toggleSaveTrip,
                ),
                ActionChip(
                  avatar: const Icon(Icons.share, color: Colors.teal),
                  label: const Text('Share'),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Share coming soon!')),
                    );
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.notifications, color: Colors.blue),
                  label: const Text('Notify Me'),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Notifications enabled!')),
                    );
                  },
                ),
              ],
            ),
          ),
          // Trip details list
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ...legs.asMap().entries.map((entry) => buildLegCard(entry.value as Map<String, dynamic>, entry.key)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}