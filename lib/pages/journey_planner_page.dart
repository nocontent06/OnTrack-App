import 'dart:async';
import 'dart:io'; // For SocketException
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ontrack/pages/search_results_page.dart';
import 'package:ontrack/providers/journey_search_provider.dart';
import 'package:ontrack/services/oebb_api_service.dart';
import 'package:ontrack/services/search_history_service.dart';
import 'package:ontrack/utils/ui_helpers.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class JourneyPlannerPage extends StatefulWidget {
  const JourneyPlannerPage({super.key});

  @override
  State<JourneyPlannerPage> createState() => _JourneyPlannerPageState();
}

class _JourneyPlannerPageState extends State<JourneyPlannerPage> {
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  String? _fromStationId;
  String? _toStationId;

  final Set<String> _favoriteStations = {};
  final Map<String, String> _favoriteStationNames = {}; // id -> name
  final List<Map<String, dynamic>> _recentJourneys = [];

  bool _isLoading = false;
  bool _showLoadingText = false;
  int _loadingTextIndex = 0;
  Timer? _loadingTextTimer;

  static const List<String> _loadingTexts = [
    "We're searching through the rail network...",
    "Switching tracks to find your best connection...",
    "Checking timetables and coupling carriages...",
    "Waiting for the signal to proceed...",
    "Making sure your train is on the right platform...",
    "Consulting the station master for the fastest route...",
    "Synchronizing clocks with the central station...",
    "Ensuring all doors are closed before departure...",
    "Looking for the smoothest ride across the rails...",
    "Polishing the locomotive for your journey...",
    "Checking for delays and clear tracks ahead...",
    "Connecting carriages for your seamless transfer...",
    "Listening for the conductor’s whistle...",
    "Mapping out your journey across the railway lines...",
    "Making sure your seat is reserved...",
    "Fueling up the engine for your trip...",
    "Inspecting the rails for a safe journey...",
    "Coordinating with signal boxes along the route...",
    "Ensuring your journey is right on schedule...",
    "Preparing your ticket for validation...",
  ];

  int? _generalTransferTime; // in minutes, null means default

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _loadRecents();
    _loadLastUsed();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favIds = prefs.getStringList('favoriteStations') ?? [];
    final favNames = prefs.getStringList('favoriteStationNames') ?? [];
    setState(() {
      _favoriteStations.clear();
      _favoriteStations.addAll(favIds);
      _favoriteStationNames.clear();
      for (int i = 0; i < favIds.length; i++) {
        _favoriteStationNames[favIds[i]] = i < favNames.length ? favNames[i] : '';
      }
    });
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList('favoriteStations', _favoriteStations.toList());
    prefs.setStringList('favoriteStationNames', _favoriteStations.map((id) => _favoriteStationNames[id] ?? '').toList());
  }

  Future<void> _loadRecents() async {
    final prefs = await SharedPreferences.getInstance();
    final recents = prefs.getStringList('recentJourneys') ?? [];
    setState(() {
      _recentJourneys.clear();
      for (final r in recents) {
        final map = jsonDecode(r);
        // Parse date and time back
        if (map['date'] != null) {
          map['date'] = DateTime.tryParse(map['date']);
        }
        if (map['time'] != null) {
          final t = map['time'].split(':');
          if (t.length == 2) {
            map['time'] = TimeOfDay(hour: int.parse(t[0]), minute: int.parse(t[1]));
          } else {
            map['time'] = null;
          }
        }
        _recentJourneys.add(map);
      }
    });
  }

  Future<void> _saveRecents() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList('recentJourneys', _recentJourneys.map((j) {
      final map = Map<String, dynamic>.from(j);
      // Serialize date and time
      if (map['date'] is DateTime) {
        map['date'] = (map['date'] as DateTime).toIso8601String();
      }
      if (map['time'] is TimeOfDay) {
        final t = map['time'] as TimeOfDay;
        map['time'] = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
      }
      return jsonEncode(map);
    }).toList());
  }

  void _toggleFavorite(String stationId, String stationName) {
    setState(() {
      if (_favoriteStations.contains(stationId)) {
        _favoriteStations.remove(stationId);
        _favoriteStationNames.remove(stationId);
      } else {
        _favoriteStations.add(stationId);
        _favoriteStationNames[stationId] = stationName;
      }
    });
    _saveFavorites();
  }

  void _saveRecentJourney() {
    final journeyProvider = Provider.of<JourneySearchProvider>(context, listen: false);
    if (_fromStationId != null && _toStationId != null) {
      final recent = {
        'fromId': _fromStationId,
        'fromName': _fromController.text,
        'toId': _toStationId,
        'toName': _toController.text,
        'date': journeyProvider.selectedDate,
        'time': journeyProvider.selectedTime,
      };
      setState(() {
        _recentJourneys.removeWhere((j) =>
          j['fromId'] == recent['fromId'] &&
          j['toId'] == recent['toId'] &&
          (j['date']?.toString() ?? '') == (recent['date']?.toString() ?? '') &&
          (j['time']?.toString() ?? '') == (recent['time']?.toString() ?? ''));
        _recentJourneys.insert(0, recent);
        if (_recentJourneys.length > 5) _recentJourneys.removeLast();
      });
      _saveRecents();
    }
  }

  // For "Via" stations
  final List<TextEditingController> _viaControllers = [];
  final List<String?> _viaStationIds = [];
  final List<Duration?> _viaChangeDurations = [];

  void _addVia() {
    setState(() {
      _viaControllers.add(TextEditingController());
      _viaStationIds.add(null);
      _viaChangeDurations.add(null);
    });
  }

  void _removeVia(int index) {
    setState(() {
      _viaControllers[index].dispose();
      _viaControllers.removeAt(index);
      _viaStationIds.removeAt(index);
      _viaChangeDurations.removeAt(index);
    });
  }

  Future<void> _pickViaStation(int index) async {
    List<Map<String, dynamic>> results = [];
    bool isLoading = false;

    await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Via Station', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search station...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) async {
                      if (val.length > 2) {
                        setSheetState(() => isLoading = true);
                        try {
                          results = await OebbApiService.searchStops(val);
                          setSheetState(() => isLoading = false);
                        } on SocketException {
                          setSheetState(() => isLoading = false);
                          showApiUnreachableSnackbar(context);
                        } catch (e) {
                          setSheetState(() => isLoading = false);
                          showErrorDialog(context, e.toString());
                        }
                      } else {
                        setSheetState(() => results = []);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  if (!isLoading)
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: results.length,
                        itemBuilder: (context, i) {
                          final station = results[i];
                          return ListTile(
                            leading: const Icon(Icons.location_on),
                            title: Text(station['name'] ?? ''),
                            onTap: () => Navigator.pop(context, station),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    ).then((selected) {
      if (selected != null) {
        _viaControllers[index].text = selected['name'];
        _viaControllers[index].selection = TextSelection.collapsed(offset: _viaControllers[index].text.length);
        setState(() {
          _viaStationIds[index] = selected['id'];
        });
      }
    });
  }

  Future<void> _pickChangeDuration(int index) async {
    Duration? picked;
    await showModalBottomSheet(
      context: context,
      builder: (context) {
        int minutes = _viaChangeDurations[index]?.inMinutes ?? 10;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Change Duration (min)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: minutes > 1
                            ? () => setSheetState(() => minutes--)
                            : null,
                      ),
                      Text(
                        '$minutes',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () => setSheetState(() => minutes++),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      picked = Duration(minutes: minutes);
                      Navigator.pop(context);
                    },
                    child: const Text('Set'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (picked != null) {
      setState(() {
        _viaChangeDurations[index] = picked;
      });
    }
  }

  void _startSearch() {
    setState(() {
      _isLoading = true;
      _showLoadingText = false;
      _loadingTextIndex = 0;
    });

    // Show loading text after 1 second
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _isLoading) {
        setState(() {
          _showLoadingText = true;
        });
        _startLoadingTextTimer();
      }
    });

    // ... your search logic ...
    // When search is done, call _stopLoading()
  }

  void _startLoadingTextTimer() {
    _loadingTextTimer?.cancel();
    _loadingTextTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_isLoading) {
        timer.cancel();
        return;
      }
      setState(() {
        _loadingTextIndex = (_loadingTextIndex + 1) % _loadingTexts.length;
      });
    });
  }

  void _stopLoading() {
    setState(() {
      _isLoading = false;
      _showLoadingText = false;
      _loadingTextIndex = 0;
    });
    _loadingTextTimer?.cancel();
  }

  @override
  void dispose() {
    _loadingTextTimer?.cancel();
    for (final c in _viaControllers) {
      c.dispose();
    }
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  // --- Update search logic to include vias and change durations ---
  void _searchTrains({bool saveRecent = true}) async {
    if (_fromStationId != null && _toStationId != null) {
      _startSearch();
      final journeyProvider = Provider.of<JourneySearchProvider>(context, listen: false);
      DateTime? departure;
      if (journeyProvider.selectedDate != null && journeyProvider.selectedTime != null) {
        departure = DateTime(
          journeyProvider.selectedDate!.year,
          journeyProvider.selectedDate!.month,
          journeyProvider.selectedDate!.day,
          journeyProvider.selectedTime!.hour,
          journeyProvider.selectedTime!.minute,
        );
      } else if (journeyProvider.selectedDate != null) {
        departure = DateTime(
          journeyProvider.selectedDate!.year,
          journeyProvider.selectedDate!.month,
          journeyProvider.selectedDate!.day,
        );
      } else {
        departure = DateTime.now();
      }
      if (saveRecent) _saveRecentJourney();

      try {
        // Prepare via parameters
        final List<String> viaIds = [];
        final List<int?> viaMins = [];
        for (int i = 0; i < _viaStationIds.length; i++) {
          if (_viaStationIds[i] != null) {
            viaIds.add(_viaStationIds[i]!);
            viaMins.add(_viaChangeDurations[i]?.inMinutes);
          }
        }

        // --- Real search logic with vias and change durations ---
        final journeys = await OebbApiService.searchJourneys(
          _fromStationId!,
          _toStationId!,
          departure: departure,
          via: viaIds.isNotEmpty ? viaIds : null,
          viaChangeMins: viaMins.isNotEmpty ? viaMins : null,
          transferTime: journeyProvider.transferTime,
          accessibility: journeyProvider.accessibility,
          bike: journeyProvider.bike,
          startWithWalking: journeyProvider.startWithWalking,
          walkingSpeed: journeyProvider.walkingSpeed,
          language: journeyProvider.language,
          nationalExpress: journeyProvider.nationalExpress,
          national: journeyProvider.national,
          interregional: journeyProvider.interregional,
          regional: journeyProvider.regional,
          suburban: journeyProvider.suburban,
          bus: journeyProvider.bus,
          ferry: journeyProvider.ferry,
          subway: journeyProvider.subway,
          tram: journeyProvider.tram,
          onCall: journeyProvider.onCall,
          tickets: journeyProvider.tickets,
          polylines: journeyProvider.polylines,
          subStops: journeyProvider.subStops,
          entrances: journeyProvider.entrances,
          remarks: journeyProvider.remarks,
          scheduledDays: journeyProvider.scheduledDays,
          pretty: journeyProvider.pretty,
        );
        print('Found ${journeys.length} journeys from $_fromStationId to $_toStationId');
        if (mounted) {
          await Navigator.of(context).push(
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 600),
              pageBuilder: (context, animation, secondaryAnimation) => SearchResultsPage(
                fromId: _fromStationId!,
                toId: _toStationId!,
                departure: departure,
                journeys: journeys,
                via: viaIds.isNotEmpty ? viaIds : null,
                viaChangeMins: viaMins.isNotEmpty ? viaMins : null,
              ),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                final fade = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
                final slide = Tween<Offset>(
                  begin: const Offset(0, 0.08),
                  end: Offset.zero,
                ).animate(fade);
                return FadeTransition(
                  opacity: fade,
                  child: SlideTransition(
                    position: slide,
                    child: child,
                  ),
                );
              },
            ),
          );
          _stopLoading();
          print('Navigating to SearchResultsPage');
        }
      } catch (e) {
        _stopLoading();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Search failed: $e')),
          );
        }
      }

      // Save search history
      await StationSearchHistoryService.saveSearch(
        _fromController.text,
        _toController.text,
        departure,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both stations.')),
      );
    }
  }

  Future<void> _pickStation(TextEditingController controller, String label) async {
    List<Map<String, dynamic>> results = [];
    bool isLoading = false;

    await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        bool showFavorites = true;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            // Build favorites list for the picker
            final favoriteList = _favoriteStations
                .map((id) => {
                      'id': id,
                      'name': _favoriteStationNames[id] ?? id,
                    })
                .toList();

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select $label Station', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  // Collapsible Favorites section
                  if (favoriteList.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => setSheetState(() => showFavorites = !showFavorites),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.withAlpha((0.08 * 255).toInt()),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  showFavorites ? Icons.expand_less : Icons.expand_more,
                                  size: 22,
                                  color: Colors.amber[800],
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Favorites',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  showFavorites ? 'Hide' : 'Show',
                                  style: TextStyle(
                                    color: Colors.amber[800],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (showFavorites)
                          ...favoriteList.map((fav) => ListTile(
                                leading: const Icon(Icons.star, color: Colors.amber),
                                title: Text(fav['name'] ?? fav['id'] ?? ''),
                                onTap: () => Navigator.pop(context, fav),
                              )),
                        const Divider(),
                      ],
                    ),
                  TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search station...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) async {
                      if (val.length > 2) {
                        setSheetState(() => isLoading = true);
                        try {
                          // Example: searching for stations
                          results = await OebbApiService.searchStops(val);
                          setSheetState(() => isLoading = false);
                        } on SocketException {
                          setSheetState(() => isLoading = false);
                          showApiUnreachableSnackbar(context);
                        } catch (e) {
                          setSheetState(() => isLoading = false);
                          showErrorDialog(context, e.toString());
                        }
                      } else {
                        setSheetState(() => results = []);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  if (!isLoading)
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: results.length,
                        itemBuilder: (context, i) {
                          final station = results[i];
                          final isFav = _favoriteStations.contains(station['id']);
                          return ListTile(
                            leading: const Icon(Icons.location_on),
                            title: Text(station['name'] ?? ''),
                            trailing: IconButton(
                              icon: Icon(
                                isFav ? Icons.star : Icons.star_border,
                                color: isFav ? Colors.amber : Colors.grey,
                              ),
                              onPressed: () {
                                _toggleFavorite(station['id'], station['name']);
                                setSheetState(() {});
                              },
                            ),
                            onTap: () => Navigator.pop(context, station),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    ).then((selected) {
      if (selected != null) {
        controller.text = selected['name'];
        controller.selection = TextSelection.collapsed(offset: controller.text.length);
        setState(() {
          if (label == 'From') {
            _fromStationId = selected['id'];
          } else {
            _toStationId = selected['id'];
          }
        });
        _saveLastUsed();
      }
    });
  }

  Future<void> _loadLastUsed() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _fromController.text = prefs.getString('lastFromName') ?? '';
      _toController.text = prefs.getString('lastToName') ?? '';
      _fromStationId = prefs.getString('lastFromId');
      _toStationId = prefs.getString('lastToId');
      final dateStr = prefs.getString('lastDate');
      final timeStr = prefs.getString('lastTime');
      _selectedDate = dateStr != null ? DateTime.tryParse(dateStr) : null;
      if (timeStr != null) {
        final t = timeStr.split(':');
        if (t.length == 2) {
          _selectedTime = TimeOfDay(hour: int.parse(t[0]), minute: int.parse(t[1]));
        }
      }
    });
  }

  Future<void> _saveLastUsed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastFromName', _fromController.text);
    await prefs.setString('lastToName', _toController.text);
    if (_fromStationId != null) await prefs.setString('lastFromId', _fromStationId!);
    if (_toStationId != null) await prefs.setString('lastToId', _toStationId!);
    if (_selectedDate != null) await prefs.setString('lastDate', _selectedDate!.toIso8601String());
    if (_selectedTime != null) {
      await prefs.setString('lastTime', '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}');
    }
  }

  Future<void> saveSearchHistory(String from, String to, DateTime? dateTime) async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('searchHistory') ?? [];
    // Use ISO8601 for dateTime, or empty string if null
    final dt = dateTime?.toIso8601String() ?? '';
    final entry = jsonEncode({'from': from, 'to': to, 'dateTime': dt});
    // Only add if not already present (for this from/to/dateTime)
    if (!history.contains(entry)) {
      history.add(entry);
      await prefs.setStringList('searchHistory', history);
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

  @override
  Widget build(BuildContext context) {
    // Always get the provider at the top of build
    final journeyProvider = Provider.of<JourneySearchProvider>(context);

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 32),
            SizedBox(
              height: 40, // Reserve space for the text
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 1500),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  // Combine fade and slide for both in and out
                  final inAnimation = Tween<Offset>(
                    begin: const Offset(0, 0.4),
                    end: Offset.zero,
                  ).animate(animation);
                  final outAnimation = Tween<Offset>(
                    begin: Offset.zero,
                    end: const Offset(0, -0.4),
                  ).animate(animation);

                  if (child.key == ValueKey(_loadingTextIndex)) {
                    // Incoming child: slide up and fade in
                    return SlideTransition(
                      position: inAnimation,
                      child: FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                    );
                  } else {
                    // Outgoing child: slide up and fade out
                    return SlideTransition(
                      position: outAnimation,
                      child: FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                    );
                  }
                },
                child: _showLoadingText
                    ? Center(
                        key: ValueKey(_loadingTextIndex),
                        child: Text(
                          _loadingTexts[_loadingTextIndex],
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.teal,
                                fontWeight: FontWeight.w500,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : const SizedBox(
                        key: ValueKey('empty'),
                      ),
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Journey Planner',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black
                : Theme.of(context).colorScheme.onPrimary,
          ),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onPrimary,
        ),
        actions: [],
      ),
      extendBodyBehindAppBar: true,
      body: Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 1,
          left: 24,
          right: 24,
        ),
        child: ListView(
          children: [
            // From field with Via button
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickStation(_fromController, 'From'),
                    child: AbsorbPointer(
                      child: TextField(
                        controller: _fromController,
                        decoration: const InputDecoration(
                          labelText: 'From',
                          prefixIcon: Icon(Icons.location_on),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.swap_calls, color: Colors.teal),
                  tooltip: 'Add Via',
                  onPressed: _addVia,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // To field with Journey Settings button
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickStation(_toController, 'To'),
                    child: AbsorbPointer(
                      child: TextField(
                        controller: _toController,
                        decoration: const InputDecoration(
                          labelText: 'To',
                          prefixIcon: Icon(Icons.flag),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.settings, color: Colors.teal),
                  tooltip: 'Journey Settings',
                  onPressed: () => _showJourneySettingsSheet(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Via fields
            if (_viaControllers.isNotEmpty)
              ...List.generate(_viaControllers.length, (i) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _pickViaStation(i),
                        child: AbsorbPointer(
                          child: TextField(
                            controller: _viaControllers[i],
                            decoration: InputDecoration(
                              labelText: 'Via',
                              prefixIcon: const Icon(Icons.transfer_within_a_station),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                      tooltip: 'Remove Via',
                      onPressed: () => _removeVia(i),
                    ),
                    IconButton(
                      icon: const Icon(Icons.access_time, color: Colors.teal),
                      tooltip: 'Change Duration',
                      onPressed: () => _pickChangeDuration(i),
                    ),
                    if (_viaChangeDurations[i] != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          '${_viaChangeDurations[i]!.inMinutes} min',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
                        ),
                      ),
                  ],
                ),
              )),
            // Date & Time ListTile (uses provider)
            Builder(
              builder: (context) {
                final selectedDate = journeyProvider.selectedDate;
                final selectedTime = journeyProvider.selectedTime;

                final isNow = (selectedDate == null || _isToday(selectedDate)) && selectedTime == null;

                String displayText;
                if (isNow) {
                  displayText = 'Now';
                } else {
                  final dateStr = selectedDate != null
                      ? MaterialLocalizations.of(context).formatMediumDate(selectedDate)
                      : MaterialLocalizations.of(context).formatMediumDate(DateTime.now());
                  final timeStr = selectedTime != null
                      ? selectedTime.format(context)
                      : TimeOfDay.now().format(context);
                  displayText = '$dateStr at $timeStr';
                }

                return ListTile(
                  leading: const Icon(Icons.access_time),
                  title: Text(displayText),
                  trailing: isNow
                      ? null
                      : TextButton(
                          onPressed: () {
                            journeyProvider.setNow();
                            _saveLastUsed();
                          },
                          child: const Text('Now'),
                        ),
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: selectedDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (pickedDate != null) {
                      final pickedTime = await showTimePicker(
                        context: context,
                        initialTime: selectedTime ?? TimeOfDay.now(),
                      );
                      journeyProvider.setDate(pickedDate);
                      journeyProvider.setTime(pickedTime);
                      _saveLastUsed();
                    }
                  },
                );
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _searchTrains,
              icon: const Icon(Icons.search, color: Colors.teal),
              label: Text(
                'Search Trains',
                style: const TextStyle(
                  color: Colors.teal,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: Theme.of(context).brightness == Brightness.dark
                      ? const BorderSide(color: Colors.white, width: 2)
                      : BorderSide.none,
                ),
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.transparent
                    : Colors.white,
                elevation: Theme.of(context).brightness == Brightness.dark ? 0 : 2,
                shadowColor: Colors.transparent,
              ),
            ),
            // Recently searched journeys
            if (_recentJourneys.isNotEmpty) ...[
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(child: Divider(thickness: 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Recently searched',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.teal[700],
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(thickness: 1)),
                ],
              ),
              const SizedBox(height: 12),
              ..._recentJourneys.map((j) => Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: const Icon(Icons.history, color: Colors.teal),
                  title: Text(
                    '${j['fromName']} → ${j['toName']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    [
                      if (j['date'] != null && j['date'] is DateTime)
                        MaterialLocalizations.of(context).formatMediumDate(j['date'] as DateTime)
                      else
                        'Today',
                      if (j['time'] != null && j['time'] is TimeOfDay)
                        (j['time'] as TimeOfDay).format(context)
                      else
                        'Now',
                    ].join(' • '),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                  onTap: () {
                    setState(() {
                      _fromController.text = j['fromName'];
                      _toController.text = j['toName'];
                      _fromStationId = j['fromId'];
                      _toStationId = j['toId'];
                    });
                    final journeyProvider = Provider.of<JourneySearchProvider>(context, listen: false);
                    journeyProvider.setDate(j['date'] is DateTime ? j['date'] : null);
                    journeyProvider.setTime(j['time'] is TimeOfDay ? j['time'] : null);
                    _searchTrains(saveRecent: false);
                  },
                ),
              )),
            ],
            const SizedBox(height: 16),
            // General transfer time setting
            
          ],
        ),
      ),
    );
  }

  // Helper function (add this to your _JourneyPlannerPageState class)
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  void _showJourneySettingsSheet(BuildContext context) {
    final journeyProvider = Provider.of<JourneySearchProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        // Use provider values as initial state
        int transferTime = journeyProvider.transferTime ?? 10;
        bool accessibility = journeyProvider.accessibility;
        bool bike = journeyProvider.bike;
        bool startWithWalking = journeyProvider.startWithWalking;
        String walkingSpeed = journeyProvider.walkingSpeed;
        String language = journeyProvider.language;
        bool nationalExpress = journeyProvider.nationalExpress;
        bool national = journeyProvider.national;
        bool interregional = journeyProvider.interregional;
        bool regional = journeyProvider.regional;
        bool suburban = journeyProvider.suburban;
        bool bus = journeyProvider.bus;
        bool ferry = journeyProvider.ferry;
        bool subway = journeyProvider.subway;
        bool tram = journeyProvider.tram;
        bool onCall = journeyProvider.onCall;
        bool tickets = journeyProvider.tickets;
        bool polylines = journeyProvider.polylines;
        bool subStops = journeyProvider.subStops;
        bool entrances = journeyProvider.entrances;
        bool remarks = journeyProvider.remarks;
        bool scheduledDays = journeyProvider.scheduledDays;
        bool pretty = journeyProvider.pretty;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Center(
                      child: Text(
                        'Journey Settings',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.teal[700],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Transfer Time
                    Row(
                      children: [
                        const Icon(Icons.timer, color: Colors.teal),
                        const SizedBox(width: 12),
                        const Text('Minimum Transfer Time'),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: transferTime > 1
                              ? () => setSheetState(() => transferTime--)
                              : null,
                        ),
                        Text('$transferTime min', style: const TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () => setSheetState(() => transferTime++),
                        ),
                      ],
                    ),
                    const Divider(),
                    // Accessibility
                    SwitchListTile(
                      secondary: const Icon(Icons.accessible, color: Colors.teal),
                      title: const Text('Accessible Journey'),
                      value: accessibility,
                      onChanged: (v) => setSheetState(() => accessibility = v),
                    ),
                    // Bike
                    SwitchListTile(
                      secondary: const Icon(Icons.directions_bike, color: Colors.teal),
                      title: const Text('Bike Allowed'),
                      value: bike,
                      onChanged: (v) => setSheetState(() => bike = v),
                    ),
                    // Start with walking
                    SwitchListTile(
                      secondary: const Icon(Icons.directions_walk, color: Colors.teal),
                      title: const Text('Start with Walking'),
                      value: startWithWalking,
                      onChanged: (v) => setSheetState(() => startWithWalking = v),
                    ),
                    // Walking speed
                    ListTile(
                      leading: const Icon(Icons.speed, color: Colors.teal),
                      title: const Text('Walking Speed'),
                      trailing: DropdownButton<String>(
                        value: walkingSpeed,
                        items: const [
                          DropdownMenuItem(value: 'slow', child: Text('Slow')),
                          DropdownMenuItem(value: 'normal', child: Text('Normal')),
                          DropdownMenuItem(value: 'fast', child: Text('Fast')),
                        ],
                        onChanged: (v) => setSheetState(() => walkingSpeed = v ?? 'normal'),
                      ),
                    ),
                    const Divider(),
                    // Language
                    ListTile(
                      leading: const Icon(Icons.language, color: Colors.teal),
                      title: const Text('Language'),
                      trailing: DropdownButton<String>(
                        value: language,
                        items: const [
                          DropdownMenuItem(value: 'en', child: Text('English')),
                          DropdownMenuItem(value: 'de', child: Text('Deutsch')),
                          DropdownMenuItem(value: 'fr', child: Text('Français')),
                          DropdownMenuItem(value: 'it', child: Text('Italiano')),
                          DropdownMenuItem(value: 'nl', child: Text('Nederlands')),
                        ],
                        onChanged: (v) => setSheetState(() => language = v ?? 'en'),
                      ),
                    ),
                    const Divider(),
                    // Transport types
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('Transport Types', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('National Express'),
                          selected: nationalExpress,
                          onSelected: (v) => setSheetState(() => nationalExpress = v),
                          avatar: const Icon(Icons.train, color: Colors.teal),
                        ),
                        FilterChip(
                          label: const Text('National'),
                          selected: national,
                          onSelected: (v) => setSheetState(() => national = v),
                          avatar: const Icon(Icons.train, color: Colors.teal),
                        ),
                        FilterChip(
                          label: const Text('Interregional'),
                          selected: interregional,
                          onSelected: (v) => setSheetState(() => interregional = v),
                          avatar: const Icon(Icons.train, color: Colors.teal),
                        ),
                        FilterChip(
                          label: const Text('Regional'),
                          selected: regional,
                          onSelected: (v) => setSheetState(() => regional = v),
                          avatar: const Icon(Icons.train, color: Colors.teal),
                        ),
                        FilterChip(
                          label: const Text('Suburban'),
                          selected: suburban,
                          onSelected: (v) => setSheetState(() => suburban = v),
                          avatar: const Icon(Icons.train, color: Colors.teal),
                        ),
                        FilterChip(
                          label: const Text('Bus'),
                          selected: bus,
                          onSelected: (v) => setSheetState(() => bus = v),
                          avatar: const Icon(Icons.directions_bus, color: Colors.teal),
                        ),
                        FilterChip(
                          label: const Text('Ferry'),
                          selected: ferry,
                          onSelected: (v) => setSheetState(() => ferry = v),
                          avatar: const Icon(Icons.directions_boat, color: Colors.teal),
                        ),
                        FilterChip(
                          label: const Text('Subway'),
                          selected: subway,
                          onSelected: (v) => setSheetState(() => subway = v),
                          avatar: const Icon(Icons.subway, color: Colors.teal),
                        ),
                        FilterChip(
                          label: const Text('Tram'),
                          selected: tram,
                          onSelected: (v) => setSheetState(() => tram = v),
                          avatar: const Icon(Icons.tram, color: Colors.teal),
                        ),
                        FilterChip(
                          label: const Text('On Call'),
                          selected: onCall,
                          onSelected: (v) => setSheetState(() => onCall = v),
                          avatar: const Icon(Icons.phone, color: Colors.teal),
                        ),
                      ],
                    ),
                    const Divider(),
                    // Extra API options
                    SwitchListTile(
                      secondary: const Icon(Icons.confirmation_number, color: Colors.teal),
                      title: const Text('Include Tickets'),
                      value: tickets,
                      onChanged: (v) => setSheetState(() => tickets = v),
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.timeline, color: Colors.teal),
                      title: const Text('Include Polylines'),
                      value: polylines,
                      onChanged: (v) => setSheetState(() => polylines = v),
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.stop_circle, color: Colors.teal),
                      title: const Text('Include SubStops'),
                      value: subStops,
                      onChanged: (v) => setSheetState(() => subStops = v),
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.door_front_door, color: Colors.teal),
                      title: const Text('Include Entrances'),
                      value: entrances,
                      onChanged: (v) => setSheetState(() => entrances = v),
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.info_outline, color: Colors.teal),
                      title: const Text('Include Remarks'),
                      value: remarks,
                      onChanged: (v) => setSheetState(() => remarks = v),
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.calendar_today, color: Colors.teal),
                      title: const Text('Include Scheduled Days'),
                      value: scheduledDays,
                      onChanged: (v) => setSheetState(() => scheduledDays = v),
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.format_paint, color: Colors.teal),
                      title: const Text('Pretty JSON'),
                      value: pretty,
                      onChanged: (v) => setSheetState(() => pretty = v),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check, color: Colors.white),
                      label: const Text('Apply Settings'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        journeyProvider.setJourneyOptions(
                          transferTime: transferTime,
                          accessibility: accessibility,
                          bike: bike,
                          startWithWalking: startWithWalking,
                          walkingSpeed: walkingSpeed,
                          language: language,
                          nationalExpress: nationalExpress,
                          national: national,
                          interregional: interregional,
                          regional: regional,
                          suburban: suburban,
                          bus: bus,
                          ferry: ferry,
                          subway: subway,
                          tram: tram,
                          onCall: onCall,
                          tickets: tickets,
                          polylines: polylines,
                          subStops: subStops,
                          entrances: entrances,
                          remarks: remarks,
                          scheduledDays: scheduledDays,
                          pretty: pretty,
                        );
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );},
          );
        }
    );
  }
}

