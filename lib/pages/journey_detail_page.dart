import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart'; // Add this import if you use latlong2 package
import 'train_detail_page.dart'; // Make sure this import points to the file where TrainDetailPage is defined

class JourneyDetailPage extends StatelessWidget {
  final Map<String, dynamic> journey;

  const JourneyDetailPage({super.key, required this.journey});

  @override
  Widget build(BuildContext context) {
    final legs = journey['legs'] as List<dynamic>? ?? [];

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
      if (upper.startsWith('SV') ||
          upper.startsWith('BUSSV')) {
        return Colors.yellow[700]!;
      }
      return Colors.blue[700]!;
    }

    Widget buildLegCard(Map<String, dynamic> leg) {
      final isWalking = leg['walking'] == true;
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
      final mode = line?['mode'] ?? '';
      final remarks = (leg['remarks'] as List<dynamic>?)
          ?.map((r) => r['text'] as String?)
          .where((t) => t != null && t.isNotEmpty)
          .toList();

      final isDark = Theme.of(context).brightness == Brightness.dark;
      final walkingColor = isDark ? Colors.white : Colors.black;
      final trainColor = getTrainColor(lineName, mode);

      return GestureDetector(
        onTap: () {
          // Prepare train, stops, and currentLocation data
          final train = {
            'name': lineName,
            'operator': operatorName,
            'category': line?['category'],
            'productName': product,
          };
          final stops = (leg['stops'] as List<dynamic>? ?? [])
              .map((s) => {
                    'name': s['name'],
                    'lat': s['location']?['latitude'] ?? 47.0707,
                    'lon': s['location']?['longitude'] ?? 15.4395,
                    'plannedArrival': s['plannedArrival'],
                    'actualArrival': s['actualArrival'],
                  })
              .toList();
          // Example: get current location from leg['currentLocation'] or fallback to first stop
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
              tripId: leg['tripId'],
              currentLocation: currentLocation,
            ),
          ));
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
                          style: const TextStyle(color: Colors.black), // <-- Set text color to black
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journey Details'),
        backgroundColor: Colors.teal,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...legs.map((leg) => buildLegCard(leg as Map<String, dynamic>)),
        ],
      ),
    );
  }
}