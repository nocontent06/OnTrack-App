import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import '../services/osm_platform_service.dart';

class WalkDetailPage extends StatefulWidget {
  final Map<String, dynamic> walk;
  final String? nextDeparture;
  final String? nextTrain;
  final String? changeTime;
  final String? walkingTime;
  final String? prevArrivalPlatform;
  final String? nextDeparturePlatform;
  final double? stationLat;
  final double? stationLon;
  final String? stationName;

  const WalkDetailPage({
    super.key,
    required this.walk,
    this.nextDeparture,
    this.nextTrain,
    this.changeTime,
    this.walkingTime,
    this.prevArrivalPlatform,
    this.nextDeparturePlatform,
    this.stationLat,
    this.stationLon,
    this.stationName,
  });

  @override
  State<WalkDetailPage> createState() => _WalkDetailPageState();
}

class _WalkDetailPageState extends State<WalkDetailPage> {
  Map<String, dynamic>? fromPlatformMarker;
  Map<String, dynamic>? toPlatformMarker;
  bool loadingPlatforms = false;
  String? platformError;

  @override
  void initState() {
    super.initState();
    _fetchPlatformMarkers();
  }

  Future<void> _fetchPlatformMarkers() async {
    if (widget.stationLat == null || widget.stationLon == null) return;
    setState(() {
      loadingPlatforms = true;
      platformError = null;
    });
    try {
      final platforms = await fetchPlatforms(widget.stationLat!, widget.stationLon!);
      fromPlatformMarker = findPlatform(platforms, widget.prevArrivalPlatform);
      toPlatformMarker = findPlatform(platforms, widget.nextDeparturePlatform);
    } catch (e) {
      platformError = 'Could not load platform locations.';
    }
    setState(() {
      loadingPlatforms = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fromName = widget.walk['origin']?['name'] ?? 'Origin';
    final toName = widget.walk['destination']?['name'] ?? 'Destination';

    // Fallback: use station coordinates if platform not found
    LatLng? fromLatLng;
    LatLng? toLatLng;
    if (fromPlatformMarker != null) {
      fromLatLng = fromPlatformMarker!['lat'] != null
          ? LatLng(fromPlatformMarker!['lat'], fromPlatformMarker!['lon'])
          : LatLng(fromPlatformMarker!['center']['lat'], fromPlatformMarker!['center']['lon']);
    } else if (widget.stationLat != null && widget.stationLon != null) {
      fromLatLng = LatLng(widget.stationLat!, widget.stationLon!);
    }
    if (toPlatformMarker != null) {
      toLatLng = toPlatformMarker!['lat'] != null
          ? LatLng(toPlatformMarker!['lat'], toPlatformMarker!['lon'])
          : LatLng(toPlatformMarker!['center']['lat'], toPlatformMarker!['center']['lon']);
    } else if (widget.stationLat != null && widget.stationLon != null) {
      toLatLng = LatLng(widget.stationLat!, widget.stationLon!);
    }

    String nextDepStr = '';
    if (widget.nextDeparture != null && widget.nextDeparture!.isNotEmpty) {
      final dt = DateTime.tryParse(widget.nextDeparture!)?.toLocal();
      if (dt != null) {
        nextDepStr = DateFormat('HH:mm').format(dt);
      }
    }

    final bool hasWalkingTime = widget.walkingTime != null && widget.walkingTime != 'Unknown';
    final String changeTimeLabel = hasWalkingTime ? 'Up to' : 'Time:';
    final String changeTimeValue = widget.changeTime ?? 'Unknown';
    final String walkingTimeLabel = hasWalkingTime ? 'Walking time:' : 'Change time:';
    final String walkingTimeValue = hasWalkingTime ? widget.walkingTime! : changeTimeValue;

    return Scaffold(
      appBar: AppBar(title: const Text('Changeover (Walk)')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(Icons.directions_walk, color: Colors.teal, size: 36),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Walk from',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                          ),
                          Text(
                            widget.prevArrivalPlatform != null && widget.prevArrivalPlatform!.isNotEmpty
                              ? '$fromName\n(Platform ${widget.prevArrivalPlatform})'
                              : fromName,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'to',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                          ),
                          Text(
                            widget.nextDeparturePlatform != null && widget.nextDeparturePlatform!.isNotEmpty
                              ? '$toName\n(Platform ${widget.nextDeparturePlatform})'
                              : toName,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    if (widget.changeTime != null && widget.changeTime!.isNotEmpty)
                      Column(
                        children: [
                          const Icon(Icons.directions_walk, color: Colors.orange, size: 20),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.center,
                            child: Text(
                              '$changeTimeLabel\n$walkingTimeValue',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.orange[800],
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Next connection:',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.train, color: Colors.teal, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          widget.nextTrain != null && widget.nextTrain!.isNotEmpty ? widget.nextTrain! : 'Unknown',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.schedule, color: Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          nextDepStr.isNotEmpty ? 'Leaving at: $nextDepStr' : 'No departure time',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.timer, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Change Time: $changeTimeValue',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Route',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (loadingPlatforms)
              const Center(child: CircularProgressIndicator())
            else if (platformError != null)
              Container(
                height: 120,
                alignment: Alignment.center,
                child: Text(platformError!),
              )
            else if (fromLatLng != null && toLatLng != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 220,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(
                        (fromLatLng.latitude + toLatLng.latitude) / 2,
                        (fromLatLng.longitude + toLatLng.longitude) / 2,
                      ),
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
                            points: [fromLatLng, toLatLng],
                            color: Colors.blue,
                            strokeWidth: 4,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: fromLatLng,
                            width: 40,
                            height: 40,
                            child: Column(
                              children: [
                                const Icon(Icons.train, color: Colors.green),
                                if (widget.prevArrivalPlatform != null)
                                  Text('P${widget.prevArrivalPlatform}', style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                          Marker(
                            point: toLatLng,
                            width: 40,
                            height: 40,
                            child: Column(
                              children: [
                                const Icon(Icons.train, color: Colors.red),
                                if (widget.nextDeparturePlatform != null)
                                  Text('P${widget.nextDeparturePlatform}', style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                height: 120,
                alignment: Alignment.center,
                child: const Text('No map data available for this walk.'),
              ),
          ],
        ),
      ),
    );
  }
}