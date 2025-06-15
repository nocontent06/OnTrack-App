import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import '../services/oebb_api_service.dart';
import 'package:ontrack/utils/ui_helpers.dart';
import 'dart:io';
import 'dart:async';

class TrainDetailPage extends StatefulWidget {
  final Map<String, dynamic> train;
  final String tripId;
  final LatLng? currentLocation;

  const TrainDetailPage({
    super.key,
    required this.train,
    required this.tripId,
    this.currentLocation,
  });

  @override
  State<TrainDetailPage> createState() => _TrainDetailPageState();

}

class _TrainDetailPageState extends State<TrainDetailPage> {
  List<Map<String, dynamic>> stops = [];
  bool isLoading = true;
  String? error;
  LatLng? currentLocation;

  Timer? _refreshTimer;
  final Duration _refreshInterval = const Duration(seconds: 2);

  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _fetchStops();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) => _fetchStops());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchStops({bool showLoading = false}) async {
    // Only update if the train is running

    // only fetch stops if the it's a train segment and not a walk/changeover
    if (widget.tripId.isEmpty) {
      setState(() {
        error = 'No trip ID provided';
        isLoading = false;
      });
      return;
    }

    if (showLoading) {
      setState(() {
        isLoading = true;
      });
    }
    try {
      final journey = await OebbApiService.getJourney(widget.tripId);
      final fetchedStops = (journey['stopovers'] as List<dynamic>? ?? [])
          .map((s) => {
                'name': s['stop']['name'],
                'lat': s['stop']['location']['latitude'],
                'lon': s['stop']['location']['longitude'],
                'plannedArrival': s['plannedArrival'],
                'arrival': s['arrival'],
                'arrivalDelay': s['arrivalDelay'],
                'plannedDeparture': s['plannedDeparture'],
                'departure': s['departure'],
                'departureDelay': s['departureDelay'],
              })
          .toList();

      LatLng? newLocation;
      if (journey['currentLocation'] != null) {
        final loc = journey['currentLocation'];
        newLocation = LatLng(loc['latitude'], loc['longitude']);
        print('currentLocation from API: $newLocation');
      } else if (fetchedStops.isNotEmpty) {
        final lastPassed = fetchedStops.lastWhere(
          (s) => s['actualArrival'] != null && s['lat'] != null && s['lon'] != null,
          orElse: () => <String, dynamic>{},
        );
        if (lastPassed.isNotEmpty) {
          newLocation = LatLng(lastPassed['lat'], lastPassed['lon']);
        }
      }

      setState(() {
        stops = fetchedStops;
        currentLocation = newLocation;
        error = null;
        isLoading = false;
      });
      if (newLocation != null && currentLocation != null) {
        print('Moving map to new location: $newLocation');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapController.move(newLocation!, 14);
        });
      }
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
      if (e is SocketException) {
        showApiUnreachableSnackbar(context);
      } else {
        showErrorDialog(context, e.toString());
      }
    }
  }

  String formatArrival(String? plannedArrival) {
    if (plannedArrival == null) return '';
    final now = DateTime.now();
    final arrival = DateTime.parse(plannedArrival).toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final arrivalDay = DateTime(arrival.year, arrival.month, arrival.day);

    String dayLabel;
    if (arrivalDay == today) {
      dayLabel = "Today";
    } else if (arrivalDay == today.add(const Duration(days: 1))) {
      dayLabel = "Tomorrow";
    } else {
      dayLabel = DateFormat('dd.MM.yyyy').format(arrival);
    }
    return "$dayLabel, ${DateFormat('HH:mm').format(arrival)}";
  }

  String? formatDelay(String? plannedArrival, String? actualArrival) {
    if (plannedArrival == null || actualArrival == null) return null;
    final planned = DateTime.parse(plannedArrival);
    final actual = DateTime.parse(actualArrival);
    final delay = actual.difference(planned).inMinutes;
    if (delay == 0) return null;
    return delay > 0 ? "+$delay min" : "$delay min";
  }

  Color getTrainColor() {
    final colorHex = widget.train['color'] as String?;
    if (colorHex != null && colorHex.length == 7 && colorHex.startsWith('#')) {
      return Color(int.parse(colorHex.substring(1), radix: 16) + 0xFF000000);
    }
    final product = (widget.train['productName'] ?? widget.train['category'] ?? '')
        .toString()
        .toLowerCase();
    if (product.contains('rjx')) return Colors.red;
    if (product.contains('rj')) return Colors.red;
    if (product.contains('railjet')) return Colors.red;
    if (product.contains('westbahn')) return Colors.lightGreen;
    if (product.contains('d ')) return Colors.brown;
    if (product.contains('d-')) return Colors.brown;
    if (product == 'd') return Colors.brown;
    if (product.contains('rex')) return Colors.orange;
    if (product.contains('re')) return Colors.orange;
    if (product.contains('s ')) return Colors.purple;
    if (product.contains('s-bahn')) return Colors.purple;
    if (product.contains('ic')) return Colors.blue;
    if (product.contains('ec')) return Colors.green;
    if (product.contains('nj')) return Colors.indigo;
    if (product.contains('nightjet')) return Colors.indigo;
    return Colors.blue;
  }

  String getProductLabel(Map<String, dynamic> train) {
    final name = (train['name'] ?? '').toString().toUpperCase();
    final product = (train['productName'] ?? train['category'] ?? '').toString().toUpperCase();

    if (name.startsWith('NJ') || product.contains('NIGHTJET')) return 'Nightjet';
    if (name.startsWith('RJX') || product.contains('RJX')) return 'Railjet Express';
    if (name.startsWith('RJ') || product.contains('RAILJET')) return 'Railjet';
    if (name.startsWith('WB') || product.contains('WESTBAHN')) return 'Westbahn';
    if (name.startsWith('D ') || name.startsWith('D-') || product == 'D' || product.contains('SCHNELLZUG')) return 'Schnellzug';
    if (name.startsWith('REX') || product.contains('REGIONALEXPRESS')) return 'RegionalExpress';
    if (name.startsWith('RE') || product.contains('REGIONALZUG')) return 'Regionalzug';
    if (name.startsWith('S ') || product.contains('S-BAHN')) return 'S-Bahn';
    if (name.startsWith('IC') || product.contains('INTERCITY')) return 'InterCity';
    if (name.startsWith('EC') || product.contains('EUROCITY')) return 'EuroCity';
    if (name.startsWith('ICE') || product.contains('INTERCITY EXPRESS')) return 'InterCity Express';
    if (name.startsWith('SV') || product.contains('SCHIENENERSATZVERKEHR')) return 'Schienenersatzverkehr';
    // Add more mappings as needed
    return product.isNotEmpty ? product : name;
  }

  String formatDelaySeconds(int? seconds) {
    if (seconds == null || seconds == 0) return '';
    final isNegative = seconds < 0;
    final absSeconds = seconds.abs();
    final hours = absSeconds ~/ 3600;
    final minutes = (absSeconds % 3600) ~/ 60;
    String result = '';
    if (hours > 0) result += '${hours}h ';
    if (minutes > 0 || hours == 0) result += '${minutes}m';
    return '${isNegative ? '-' : '+'}$result'.trim();
  }

  @override
  Widget build(BuildContext context) {
    final isRunning = currentLocation != null;
    final theme = Theme.of(context);

    final polylinePoints = stops
        .map((stop) => LatLng(stop['lat'], stop['lon']))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.train['name'] ?? 'Train'} Details'),
        backgroundColor: theme.colorScheme.primary,
        elevation: 0,
      ),
      body: error != null
          ? Center(child: Text('Error: $error'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Train info card
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.train['name'] ?? '',
                          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        if (widget.train['operator'] != null)
                          Text(
                            'Type: ${widget.train['operator'] ?? 'Unknown'}',
                            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                          ),
                        if (widget.train['category'] != null)
                          Text(
                            'Category: ${widget.train['category'] ?? 'Unknown'}',
                            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                          ),
                        if (widget.train['productName'] != null)
                          Text(
                            'Product: ${getProductLabel(widget.train)}',
                            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                          ),
                        if (currentLocation != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              'Current location:\nLat: ${currentLocation!.latitude.toStringAsFixed(5)},\nLon: ${currentLocation!.longitude.toStringAsFixed(5)}',
                              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (currentLocation != null) ...[
                  const SizedBox(height: 20),
                  // Map section
                  Container(
                    height: 220,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.teal.withAlpha((0.2 * 255).toInt())),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: currentLocation!,
                            initialZoom: 14,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.example.ontrack',
                            ),
                            if (polylinePoints.length > 1)
                              PolylineLayer(
                                polylines: [
                                  Polyline(
                                    points: polylinePoints,
                                    color: getTrainColor(),
                                    strokeWidth: 5,
                                  ),
                                ],
                              ),
                            if (isRunning)
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: currentLocation!,
                                    width: 40,
                                    height: 40,
                                    child: const Icon(Icons.train, color: Colors.red, size: 36),
                                  ),
                                ],
                              ),
                            MarkerLayer(
                              markers: stops.map((stop) {
                                return Marker(
                                  point: LatLng(stop['lat'], stop['lon']),
                                  width: 20,
                                  height: 20,
                                  child: const Icon(Icons.location_on, color: Colors.teal, size: 18),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                        // Loading overlay for manual refresh
                        if (isLoading)
                          Container(
                            color: Colors.black.withAlpha(80),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        // Manual refresh button (bottom right)
                        Positioned(
                          bottom: 12,
                          right: 12,
                          child: FloatingActionButton(
                            mini: true,
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.teal,
                            elevation: 2,
                            onPressed: () async {
                              await _fetchStops(showLoading: true);
                            },
                            child: const Icon(Icons.refresh),
                            tooltip: 'Refresh',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                
                // Stops list
                Text(
                  'Stops',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: stops.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[300]),
                    itemBuilder: (context, i) {
                      final stop = stops[i];
                      final plannedArrival = stop['plannedArrival'];
                      final actualArrival = stop['arrival'];
                      final arrivalDelay = stop['arrivalDelay'] ?? 0;
                      final arrivalDelayed = arrivalDelay != 0 && plannedArrival != null && actualArrival != null;
                      final plannedDeparture = stop['plannedDeparture'];
                      final actualDeparture = stop['departure'];
                      var departureDelay = stop['departureDelay'] ?? 0;
                      var departureDelayed = departureDelay != 0 && plannedDeparture != null && actualDeparture != null;

                      // print('Stop: ${stop['name']}');
                      // print('plannedArrival: $plannedArrival');
                      // print('actualArrival: $actualArrival');
                      // print('plannedDeparture: $plannedDeparture');
                      // print('actualDeparture: $actualDeparture');

                      // Helper to format time
                      String? formatTime(String? time) =>
                          time != null ? DateFormat('HH:mm').format(DateTime.parse(time).toLocal()) : null;

                      return ListTile(
                        leading: Icon(
                          i == 0
                              ? Icons.flag
                              : (i == stops.length - 1 ? Icons.flag_outlined : Icons.circle),
                          color: i == 0
                              ? Colors.green
                              : (i == stops.length - 1 ? Colors.red : Colors.teal),
                        ),
                        title: Text(stop['name'] ?? ''),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Arrival
                            if (plannedArrival != null)
                              Row(
                                children: [
                                  const Text('Arr: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                  if (arrivalDelayed) ...[
                                    Text(
                                      formatTime(plannedArrival)!,
                                      style: const TextStyle(
                                        decoration: TextDecoration.lineThrough,
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    formatTime(actualArrival ?? plannedArrival) ?? '',
                                    style: TextStyle(
                                      color: arrivalDelayed ? Colors.orange : Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (arrivalDelayed) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      formatDelaySeconds(arrivalDelay),
                                      style: const TextStyle(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            // Departure
                            if (plannedDeparture != null)
                              Row(
                                children: [
                                  const Text('Dep: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                  if (departureDelayed) ...[
                                    Text(
                                      formatTime(plannedDeparture)!,
                                      style: const TextStyle(
                                        decoration: TextDecoration.lineThrough,
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    formatTime(actualDeparture ?? plannedDeparture) ?? '',
                                    style: TextStyle(
                                      color: departureDelayed ? Colors.orange : Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (departureDelayed) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      formatDelaySeconds(departureDelay),
                                      style: const TextStyle(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                          ],
                        ),
                        // trailing: ... (keep your delay/minutes logic if you want)
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                // Changeover section
                if (widget.train['changeovers'] != null && (widget.train['changeovers'] as List).isNotEmpty) ...[
                  Text(
                    'Changeovers',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...((widget.train['changeovers'] as List).map<Widget>((changeover) {
                    final fromPlatform = changeover['fromPlatform'] ?? 'unknown';
                    final toPlatform = changeover['toPlatform'] ?? 'unknown';
                    final fromLat = changeover['fromLocation']?['latitude'];
                    final fromLon = changeover['fromLocation']?['longitude'];
                    final toLat = changeover['toLocation']?['latitude'];
                    final toLon = changeover['toLocation']?['longitude'];

                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Changeover at ${changeover['station'] ?? 'unknown station'}',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text('From platform: $fromPlatform', style: theme.textTheme.bodyMedium),
                            Text('To platform: $toPlatform', style: theme.textTheme.bodyMedium),
                            const SizedBox(height: 8),
                            if (fromLat != null && fromLon != null && toLat != null && toLon != null)
                              SizedBox(
                                height: 200,
                                child: FlutterMap(
                                  options: MapOptions(
                                    initialCenter: LatLng((fromLat + toLat) / 2, (fromLon + toLon) / 2),
                                    initialZoom: 17,
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      userAgentPackageName: 'com.example.ontrack',
                                    ),
                                    PolylineLayer(
                                      polylines: [
                                        Polyline(
                                          points: [
                                            LatLng(fromLat, fromLon),
                                            LatLng(toLat, toLon),
                                          ],
                                          color: Colors.blue,
                                          strokeWidth: 4,
                                        ),
                                      ],
                                    ),
                                    MarkerLayer(
                                      markers: [
                                        Marker(
                                          point: LatLng(fromLat, fromLon),
                                          width: 30,
                                          height: 30,
                                          child: const Icon(Icons.directions_walk, color: Colors.green),
                                        ),
                                        Marker(
                                          point: LatLng(toLat, toLon),
                                          width: 30,
                                          height: 30,
                                          child: const Icon(Icons.flag, color: Colors.red),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              )
                            else
                              Text('No map data available for this changeover.'),
                          ],
                        ),
                      ),
                    );
                  }).toList()),
                ],
              ],
            ),
    );
  }

  Widget buildSegment(Map<String, dynamic> segment) {
    // If it's a walk/changeover
    if (segment['name'] == 'Walk'|| segment['type'] == 'walk' || segment['mode'] == 'walking' || segment['tripId'] == null) {
      // Do NOT call getJourney for walks!
      // Just show the WalkMap or walk info
      print('WALKING!!');
      return WalkMap(walk: segment);
    } else {
      // Only call getJourney for train/bus segments
      // ... your existing logic ...
      // For now, return a placeholder widget
      return const SizedBox.shrink();
    }
  }
}

// Call this widget with your walk/changeover JSON as the 'walk' argument
class WalkMap extends StatelessWidget {
  final Map<String, dynamic> walk;

  const WalkMap({super.key, required this.walk});

  @override
  Widget build(BuildContext context) {
    final fromName = walk['origin']?['name'] ?? 'Origin';
    final toName = walk['destination']?['name'] ?? 'Destination';
    final fromLat = walk['origin']?['location']?['latitude'];
    final fromLon = walk['origin']?['location']?['longitude'];
    final toLat = walk['destination']?['location']?['latitude'];
    final toLon = walk['destination']?['location']?['longitude'];

    print('origin: ${walk['origin']}');
    print('destination: ${walk['destination']}');
    print('fromPlatform: ${walk['fromPlatform']}');
    print('toPlatform: ${walk['toPlatform']}');
    
    if (fromLat != null && fromLon != null && toLat != null && toLon != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Walk from "$fromName" to "$toName"',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng((fromLat + toLat) / 2, (fromLon + toLon) / 2),
                initialZoom: 18,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.ontrack',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [
                        LatLng(fromLat, fromLon),
                        LatLng(toLat, toLon),
                      ],
                      color: Colors.blue,
                      strokeWidth: 4,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(fromLat, fromLon),
                      width: 30,
                      height: 30,
                      child: const Icon(Icons.directions_walk, color: Colors.green),
                    ),
                    Marker(
                      point: LatLng(toLat, toLon),
                      width: 30,
                      height: 30,
                      child: const Icon(Icons.flag, color: Colors.red),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      return const Text('No map data available for this changeover.');
    }
  }
}