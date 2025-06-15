import 'package:flutter/material.dart';
import 'package:ontrack/services/oebb_api_service.dart';
import 'package:ontrack/pages/journey_detail_page.dart';

// --- Search Results Page ---
class SearchResultsPage extends StatefulWidget {
  final String fromId;
  final String toId;
  final DateTime? departure;
  final List<Map<String, dynamic>> journeys;
  final List<String>? via;
  final List<int?>? viaChangeMins;

  const SearchResultsPage({
    super.key,
    required this.fromId,
    required this.toId,
    this.departure,
    required this.journeys,
    this.via,
    this.viaChangeMins,
  });

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage> {
  late List<Map<String, dynamic>> _journeys;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _journeys = List<Map<String, dynamic>>.from(widget.journeys); // Use handed-over journeys
  }

  Future<void> _fetchLaterJourneys() async {
    if (_journeys.isEmpty) return;
    setState(() => _loadingMore = true);

    // Find first real leg of the last journey
    final lastJourney = _journeys.last;
    final lastLegs = lastJourney['legs'] as List<dynamic>? ?? [];
    Map<String, dynamic>? firstRealLeg;
    for (final leg in lastLegs) {
      final isWalking = leg['walking'] == true;
      final isPublic = leg['public'] != false;
      if (!isWalking && isPublic) {
        firstRealLeg = leg as Map<String, dynamic>;
        break;
      }
    }
    firstRealLeg ??= lastLegs.isNotEmpty ? lastLegs.first as Map<String, dynamic> : null;
    final firstDepartureStr = firstRealLeg?['departure'];
    if (firstDepartureStr != null) {
      final firstDeparture = DateTime.tryParse(firstDepartureStr)?.toLocal();
      if (firstDeparture != null) {
        final nextDeparture = firstDeparture.add(const Duration(minutes: 1));
        final moreJourneys = await OebbApiService.searchJourneys(
          widget.fromId,
          widget.toId,
          departure: nextDeparture,
          via: widget.via,
          viaChangeMins: widget.viaChangeMins,
        );
        // Avoid duplicates
        final more = moreJourneys.where((j) =>
          !_journeys.any((orig) => orig['refreshToken'] == j['refreshToken']));
        setState(() {
          _journeys = [..._journeys, ...more];
          _loadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_journeys.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('No journeys found.')),
      );
    }

    // Group journeys by departure date
    List<Widget> journeyWidgets = [];
    String? lastDate;

    for (int i = 0; i < _journeys.length; i++) {
      final journey = _journeys[i];
      final legs = journey['legs'] as List<dynamic>? ?? [];

      // Find first and last "real" leg (not walking, not public: false)
      Map<String, dynamic>? firstRealLeg;
      Map<String, dynamic>? lastRealLeg;
      for (final leg in legs) {
        final isWalking = leg['walking'] == true;
        final isPublic = leg['public'] != false;
        if (!isWalking && isPublic) {
          firstRealLeg ??= leg as Map<String, dynamic>;
          lastRealLeg = leg as Map<String, dynamic>;
        }
      }
      firstRealLeg ??= legs.isNotEmpty ? legs[0] as Map<String, dynamic> : null;
      lastRealLeg ??= legs.isNotEmpty ? legs.last as Map<String, dynamic> : null;

      final departureStr = firstRealLeg?['departure'];
      final arrivalStr = lastRealLeg?['arrival'];

      DateTime? depTime = departureStr != null ? DateTime.tryParse(departureStr)?.toLocal() : null;
      DateTime? arrTime = arrivalStr != null ? DateTime.tryParse(arrivalStr)?.toLocal() : null;

      // Format date for divider
      String dateLabel = depTime != null
          ? "${depTime.year}-${depTime.month.toString().padLeft(2, '0')}-${depTime.day.toString().padLeft(2, '0')}"
          : '';

      // Insert divider if date changes
      if (dateLabel != lastDate) {
        journeyWidgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    depTime != null
                        ? "${depTime.day.toString().padLeft(2, '0')}.${depTime.month.toString().padLeft(2, '0')}.${depTime.year}"
                        : '',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
          ),
        );
        lastDate = dateLabel;
      }

      // Collect all train names (line.name) for real legs, removing (Train-No. xxxx)
      final trainNames = legs
          .where((leg) => (leg['walking'] != true) && (leg['public'] != false))
          .map((leg) {
            final name = (leg['line'] as Map<String, dynamic>?)?['name'] ?? '';
            // Remove (Train-No. xxxx)
            return name.replaceAll(RegExp(r'\s*\(Train-No\. ?\d+\)'), '');
          })
          .where((name) => name.isNotEmpty)
          .join(' → ');

      // Duration
      String durationText = '';
      if (depTime != null && arrTime != null) {
        final duration = arrTime.difference(depTime);
        final hours = duration.inHours;
        final minutes = duration.inMinutes % 60;
        durationText = '${hours > 0 ? '$hours h ' : ''}$minutes min';
      }

      // Changes (number of real legs minus 1)
      final realLegsCount = legs.where((leg) => (leg['walking'] != true) && (leg['public'] != false)).length;
      final changes = realLegsCount > 1 ? realLegsCount - 1 : 0;

      // Time format
      String formatTime(DateTime? dt) {
        if (dt == null) return '';
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }

      journeyWidgets.add(
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => JourneyDetailPage(journey: journey),
              ));
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Row(
                children: [
                  // Departure time (left)
                  SizedBox(
                    width: 60,
                    child: Center(
                      child: Text(
                        formatTime(depTime),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Train names and info (center)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          trainNames,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$durationText • $changes change${changes == 1 ? '' : 's'}',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Arrival time (right)
                  SizedBox(
                    width: 60,
                    child: Center(
                      child: Text(
                        formatTime(arrTime),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Results')),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Match theme
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...journeyWidgets,
          const SizedBox(height: 16),
          if (_loadingMore)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            ),
          if (!_loadingMore)
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.arrow_downward, color: Colors.teal),
                label: const Text('Later', style: TextStyle(color: Colors.teal)),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                onPressed: _fetchLaterJourneys,
              ),
            ),
          const SizedBox(height: 32), // Extra space at the bottom
        ],
      ),
    );
  }
}