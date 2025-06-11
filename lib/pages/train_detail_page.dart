import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import '../services/oebb_api_service.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchStops();
  }

  Future<void> _fetchStops() async {
    try {
      final fetchedStops = await OebbApiService.getStopovers(widget.tripId);
      setState(() {
        stops = fetchedStops;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
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

  // Helper to get a color for the train line
  Color getTrainColor() {
    // Try to use a color from the train data, fallback to blue
    final colorHex = widget.train['color'] as String?;
    if (colorHex != null && colorHex.length == 7 && colorHex.startsWith('#')) {
      return Color(int.parse(colorHex.substring(1), radix: 16) + 0xFF000000);
    }
    // Fallback: use productName or category for a color
    final product = (widget.train['productName'] ?? widget.train['category'] ?? '').toString().toLowerCase();
    // Assign colors based on common Austrian/German train abbreviations
    if (product.contains('rjx')) return Colors.red;         // Railjet Xpress
    if (product.contains('rj')) return Colors.red;          // Railjet
    if (product.contains('railjet')) return Colors.red;
    if (product.contains('westbahn')) return Colors.lightGreen; // WESTbahn
    if (product.contains('d ')) return Colors.brown;        // D-Zug (Fernzug)
    if (product.contains('d-')) return Colors.brown;
    if (product == 'd') return Colors.brown;
    if (product.contains('rex')) return Colors.orange;      // RegionalExpress
    if (product.contains('re')) return Colors.orange;       // RegionalExpress (DE)
    if (product.contains('s ')) return Colors.purple;       // S-Bahn
    if (product.contains('s-bahn')) return Colors.purple;
    if (product.contains('ic')) return Colors.blue;         // InterCity
    if (product.contains('ec')) return Colors.green;        // EuroCity
    if (product.contains('nj')) return Colors.indigo;       // Nightjet
    if (product.contains('nightjet')) return Colors.indigo;
    if (product.contains('ic')) return Colors.blue;
    if (product.contains('ec')) return Colors.green;
    if (product.contains('s-bahn')) return Colors.purple;
    if (product.contains('nightjet')) return Colors.indigo;
    return Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    final isRunning = widget.currentLocation != null;
    final theme = Theme.of(context);

    // Prepare polyline points from stops
    final polylinePoints = stops
        .map((stop) => LatLng(stop['lat'], stop['lon']))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.train['name'] ?? 'Train'} Details'),
        backgroundColor: theme.colorScheme.primary,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
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
                                'Operator: ${widget.train['operator']}',
                                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                              ),
                            if (widget.train['category'] != null)
                              Text(
                                'Category: ${widget.train['category']}',
                                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                              ),
                            if (widget.train['productName'] != null)
                              Text(
                                'Product: ${widget.train['productName']}',
                                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Map section
                    Container(
                      height: 220,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.teal.withAlpha((0.2 * 255).toInt())),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: isRunning
                              ? widget.currentLocation!
                              : (stops.isNotEmpty
                                  ? LatLng(stops.first['lat'], stops.first['lon'])
                                  : LatLng(47.0707, 15.4395)),
                          initialZoom: 10,
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
                                  point: widget.currentLocation!,
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
                    ),
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
                        separatorBuilder: (_, _) => Divider(height: 1, color: Colors.grey[300]),
                        itemBuilder: (context, i) {
                          final stop = stops[i];
                          final plannedArrival = stop['plannedArrival'];
                          final actualArrival = stop['actualArrival'];
                          final delayStr = formatDelay(plannedArrival, actualArrival);
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
                            subtitle: plannedArrival != null
                                ? Text(formatArrival(plannedArrival))
                                : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (delayStr != null)
                                  Text(
                                    delayStr,
                                    style: TextStyle(
                                      color: delayStr.startsWith('+')
                                          ? Colors.orange
                                          : Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                if (actualArrival != null)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8.0),
                                    child: Text(
                                      DateFormat('HH:mm').format(DateTime.parse(actualArrival).toLocal()),
                                      style: TextStyle(
                                        color: (actualArrival == plannedArrival)
                                            ? Colors.green
                                            : Colors.orange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}