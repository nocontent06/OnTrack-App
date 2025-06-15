import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ontrack/providers/trips_provider.dart';
import 'journey_detail_page.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

enum TripTab { saved, favourite, archive }

class TripPage extends StatefulWidget {
  const TripPage({super.key});
  @override
  State<TripPage> createState() => _TripPageState();
}

class _TripPageState extends State<TripPage> {
  TripTab _selectedTab = TripTab.saved;

  @override
  Widget build(BuildContext context) {
    final tripsProvider = Provider.of<TripsProvider>(context);
    final trips = tripsProvider.trips;
    final favouriteTrips = trips.where((t) => t['favourite'] == true).toList();
    final archivedTrips = trips.where((t) => t['archived'] == true).toList();

    List<Map<String, dynamic>> shownTrips;
    switch (_selectedTab) {
      case TripTab.favourite:
        shownTrips = favouriteTrips;
        break;
      case TripTab.archive:
        shownTrips = archivedTrips;
        break;
      case TripTab.saved:
      default:
        shownTrips = trips.where((t) => t['archived'] != true).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Trips', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onPrimary),
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              child: Text('Trip Menu', style: Theme.of(context).textTheme.headlineSmall),
            ),
            ListTile(
              leading: const Icon(Icons.star),
              title: const Text('Saved'),
              selected: _selectedTab == TripTab.saved,
              onTap: () {
                Navigator.pop(context);
                setState(() => _selectedTab = TripTab.saved);
              },
            ),
            ListTile(
              leading: const Icon(Icons.favorite),
              title: const Text('Favourite'),
              selected: _selectedTab == TripTab.favourite,
              onTap: () {
                Navigator.pop(context);
                setState(() => _selectedTab = TripTab.favourite);
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive),
              title: const Text('Archive'),
              selected: _selectedTab == TripTab.archive,
              onTap: () {
                Navigator.pop(context);
                setState(() => _selectedTab = TripTab.archive);
              },
            ),
          ],
        ),
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: shownTrips.isEmpty
          ? const Center(child: Text('No trips here yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: shownTrips.length,
              itemBuilder: (context, index) {
                final trip = shownTrips[index];
                return SavedTripCard(
                  key: ValueKey('${trip['dep']}_${trip['arr']}_$index'),
                  trip: trip,
                  onView: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => JourneyDetailPage(
                        journey: {'legs': trip['legs']},
                        isAlreadySaved: true,
                      ),
                    ));
                  },
                  onDelete: () {
                    tripsProvider.removeTrip(trip);
                  },
                  onToggleFavourite: () {
                    tripsProvider.toggleFavourite(trip);
                  },
                  onArchive: () {
                    tripsProvider.archiveTrip(trip);
                  },
                  onSearchAgain: () {
                    // Implement direct search logic
                  },
                );
              },
            ),
    );
  }
}

class SavedTripCard extends StatelessWidget {
  final Map<String, dynamic> trip;
  final VoidCallback onView;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavourite;
  final VoidCallback onArchive;
  final VoidCallback onSearchAgain;

  const SavedTripCard({
    super.key,
    required this.trip,
    required this.onView,
    required this.onDelete,
    required this.onToggleFavourite,
    required this.onArchive,
    required this.onSearchAgain,
  });

  @override
  Widget build(BuildContext context) {
    final dep = trip['dep'];
    final arr = trip['arr'];
    final from = trip['from'] ?? '';
    final to = trip['to'] ?? '';
    final legs = (trip['legs'] as List<dynamic>? ?? []);
    final duration = _calculateTripDuration(legs);
    final distance = _calculateTripDistance(legs);
    final transfers = legs.length > 1 ? legs.length - 1 : 0;
    final modes = legs.map((l) => l['line']?['mode'] ?? l['mode']).toSet();
    final tripDate = dep != null ? DateFormat('EEE, dd MMM yyyy').format(DateTime.parse(dep)) : '';
    final depTime = dep != null ? DateFormat('HH:mm').format(DateTime.parse(dep)) : '';
    final arrTime = arr != null ? DateFormat('HH:mm').format(DateTime.parse(arr)) : '';
    final now = DateTime.now();
    String tripStatus = '';
    if (dep != null && arr != null) {
      final depDt = DateTime.tryParse(dep);
      final arrDt = DateTime.tryParse(arr);
      if (depDt != null && arrDt != null) {
        if (arrDt.isBefore(now)) {
          tripStatus = 'Completed';
        } else if (depDt.isAfter(now)) {
          tripStatus = 'Upcoming at $depTime';
        } else {
          tripStatus = 'Ongoing';
        }
      }
    }

    // --- Delay detection ---
    int maxDelay = 0;
    for (final leg in legs) {
      final delay = (leg['departureDelay'] ?? leg['delay'] ?? 0) as int;
      if (delay > maxDelay) maxDelay = delay;
    }

    // --- Map Markers and Polyline ---
    final List<LatLng> points = [];
    final List<Marker> markers = [];

    // Origin marker
    if (legs.isNotEmpty && legs.first['origin']?['location'] != null) {
      final loc = legs.first['origin']['location'];
      final origin = LatLng(loc['latitude'], loc['longitude']);
      points.add(origin);
      markers.add(
        Marker(
          point: origin,
          width: 40,
          height: 40,
          child: const Icon(Icons.location_on, color: Colors.green, size: 32),
        ),
      );
    }

    // Change/transfer markers (all leg destinations except last)
    for (int i = 0; i < legs.length; i++) {
      final leg = legs[i];
      if (leg['destination']?['location'] != null) {
        final loc = leg['destination']['location'];
        final dest = LatLng(loc['latitude'], loc['longitude']);
        points.add(dest);

        // If not the last leg, it's a transfer point
        if (i < legs.length - 1) {
          markers.add(
            Marker(
              point: dest,
              width: 24,
              height: 24,
              child: const Icon(Icons.circle, color: Colors.blue, size: 16),
            ),
          );
        }
      }
    }

    // Destination marker (last point)
    if (points.isNotEmpty) {
      markers.add(
        Marker(
          point: points.last,
          width: 40,
          height: 40,
          child: const Icon(Icons.flag, color: Colors.red, size: 32),
        ),
      );
    }

    final mapCenter = points.isNotEmpty ? points.first : LatLng(48.2082, 16.3738);

    final stops = [
      if (legs.isNotEmpty) legs.first['origin']?['name'],
      ...legs.skip(1).map((l) => l['origin']?['name']),
      if (legs.isNotEmpty) legs.last['destination']?['name'],
    ].whereType<String>().toList();

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Favourite, From→To, Archive/Delete
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    trip['favourite'] == true ? Icons.favorite : Icons.favorite_border,
                    color: Colors.redAccent,
                  ),
                  tooltip: trip['favourite'] == true ? 'Unfavourite' : 'Mark as favourite',
                  onPressed: onToggleFavourite,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$from → $to',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.archive),
                  tooltip: 'Archive',
                  onPressed: onArchive,
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: 'Delete',
                  onPressed: onDelete,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Trip Date and Times
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 18),
                const SizedBox(width: 6),
                Flexible(child: Text(tripDate, style: Theme.of(context).textTheme.bodyMedium)),
                const SizedBox(width: 12),
                const Icon(Icons.access_time, size: 18),
                const SizedBox(width: 4),
                Text('$depTime - $arrTime', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            const SizedBox(height: 6),
            // Info row: duration, distance, transfers, status
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.schedule, size: 18),
                    const SizedBox(width: 4),
                    Text(duration, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.route, size: 18),
                    const SizedBox(width: 4),
                    Text('$distance km', style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.compare_arrows, size: 18),
                    const SizedBox(width: 4),
                    Text('$transfers transfers', style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tripStatus.startsWith('Upcoming')
                          ? Icons.access_time
                          : tripStatus == 'Completed'
                              ? Icons.check_circle
                              : Icons.directions_run,
                      size: 18,
                      color: tripStatus.startsWith('Upcoming')
                          ? Colors.blue
                          : tripStatus == 'Completed'
                              ? Colors.green
                              : Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(tripStatus, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
                if (maxDelay > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning, color: Colors.orange, size: 18),
                      const SizedBox(width: 4),
                      Text('Delayed by $maxDelay min', style: TextStyle(color: Colors.orange)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Map Preview (bigger, with all markers and polyline)
            SizedBox(
              height: 200,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FlutterMap(
                  options: MapOptions(
                    // Center and zoom fallback if not enough points for bounds
                    initialCenter: points.isNotEmpty ? points.first : fallbackCenter,
                    initialZoom: points.isEmpty ? 7.5 : 15.0,
                    initialCameraFit: points.length >= 2
                        ? CameraFit.bounds(bounds: LatLngBounds.fromPoints(points), padding: const EdgeInsets.all(32))
                        : null,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.ontrack',
                    ),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: points,
                          color: Colors.blue,
                          strokeWidth: 4,
                        ),
                      ],
                    ),
                    MarkerLayer(markers: markers),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Action buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('View'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber[700],
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: onView,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Share'),
                  onPressed: () => _showExportOptions(context, trip),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('Search Again'),
                  onPressed: onSearchAgain,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- SHARE/EXPORT LOGIC ---
  void _showExportOptions(BuildContext context, Map<String, dynamic> trip) async {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('PDF (Short)'),
              onTap: () async {
                Navigator.pop(ctx);
                await _exportPdf(context, trip, short: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('PDF (Long)'),
              onTap: () async {
                Navigator.pop(ctx);
                await _exportPdf(context, trip, short: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.text_snippet),
              title: const Text('Text'),
              onTap: () async {
                Navigator.pop(ctx);
                await _exportText(context, trip);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy to Clipboard'),
              onTap: () async {
                Navigator.pop(ctx);
                await _copyToClipboard(context, trip);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportPdf(BuildContext context, Map<String, dynamic> trip, {required bool short}) async {
    final pdf = pw.Document();
    final from = trip['from'] ?? '';
    final to = trip['to'] ?? '';
    final dep = trip['dep'];
    final arr = trip['arr'];
    final legs = (trip['legs'] as List<dynamic>? ?? []);
    final duration = _calculateTripDuration(legs);
    final distance = _calculateTripDistance(legs);
    final transfers = legs.length > 1 ? legs.length - 1 : 0;
    final tripDate = dep != null ? DateFormat('EEE, dd MMM yyyy').format(DateTime.parse(dep)) : '';

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Journey: $from → $to', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Text('Date: $tripDate'),
              pw.Text('Duration: $duration'),
              pw.Text('Distance: $distance km'),
              pw.Text('Transfers: $transfers'),
              if (!short) ...[
                pw.SizedBox(height: 12),
                pw.Text('Legs:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                for (final leg in legs)
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '${leg['origin']?['name'] ?? ''} → ${leg['destination']?['name'] ?? ''}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text('  Departure: ${leg['departure'] ?? ''}'),
                      pw.Text('  Arrival: ${leg['arrival'] ?? ''}'),
                      if (leg['line'] != null)
                        pw.Text('  Line: ${leg['line']['name'] ?? ''} (${leg['line']['mode'] ?? ''})'),
                      if (leg['distance'] != null)
                        pw.Text('  Distance: ${((leg['distance'] as num) / 1000).toStringAsFixed(1)} km'),
                      pw.SizedBox(height: 4),
                    ],
                  ),
              ],
            ],
          );
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/trip_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles([XFile(file.path)], text: 'My Journey: $from → $to');
  }

  Future<void> _exportText(BuildContext context, Map<String, dynamic> trip) async {
    final from = trip['from'] ?? '';
    final to = trip['to'] ?? '';
    final dep = trip['dep'];
    final arr = trip['arr'];
    final fromDate = dep != null ? DateFormat('dd.MM.yyyy HH:mm').format(DateTime.parse(dep)) : '';
    final toDate = arr != null ? DateFormat('dd.MM.yyyy HH:mm').format(DateTime.parse(arr)) : '';
    final text = 'Journey $from to $to on $fromDate - $toDate';
    await Share.share(text);
  }

  Future<void> _copyToClipboard(BuildContext context, Map<String, dynamic> trip) async {
    final from = trip['from'] ?? '';
    final to = trip['to'] ?? '';
    final dep = trip['dep'];
    final arr = trip['arr'];
    final fromDate = dep != null ? DateFormat('dd.MM.yyyy HH:mm').format(DateTime.parse(dep)) : '';
    final toDate = arr != null ? DateFormat('dd.MM.yyyy HH:mm').format(DateTime.parse(arr)) : '';
    final text = 'Journey $from to $to on $fromDate - $toDate';
    await Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
  }

  String _calculateTripDuration(List<dynamic> legs) {
    if (legs.isEmpty) return '';
    final dep = legs.first['departure'];
    final arr = legs.last['arrival'];
    if (dep == null || arr == null) return '';
    final depDt = DateTime.tryParse(dep);
    final arrDt = DateTime.tryParse(arr);
    if (depDt == null || arrDt == null) return '';
    final diff = arrDt.difference(depDt);
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  String _calculateTripDistance(List<dynamic> legs) {
    double km = 0;
    for (final leg in legs) {
      if (leg['distance'] != null) {
        km += (leg['distance'] as num).toDouble() / 1000.0;
      }
    }
    return km.toStringAsFixed(1);
  }

  IconData _modeToIcon(String? mode) {
    switch (mode) {
      case 'train':
        return Icons.train;
      case 'bus':
        return Icons.directions_bus;
      case 'tram':
        return Icons.tram;
      case 'subway':
        return Icons.subway;
      case 'ferry':
        return Icons.directions_boat;
      default:
        return Icons.directions_transit;
    }
  }
}

final fallbackCenter = LatLng(48.2082, 16.3738); // Vienna as fallback