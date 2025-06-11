import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ontrack/pages/search_results_page.dart';
import 'package:ontrack/services/oebb_api_service.dart';
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
    if (_fromStationId != null && _toStationId != null) {
      final recent = {
        'fromId': _fromStationId,
        'fromName': _fromController.text,
        'toId': _toStationId,
        'toName': _toController.text,
        'date': _selectedDate,
        'time': _selectedTime,
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

  void _searchTrains({bool saveRecent = true}) {
    if (_fromStationId != null && _toStationId != null) {
      DateTime? departure;
      if (_selectedDate != null && _selectedTime != null) {
        departure = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          _selectedTime!.hour,
          _selectedTime!.minute,
        );
      } else if (_selectedDate != null) {
        departure = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
        );
      }
      if (saveRecent) _saveRecentJourney();
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SearchResultsPage(
          fromId: _fromStationId!,
          toId: _toStationId!,
          departure: departure,
        ),
      ));
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
                        results = await OebbApiService.searchStops(val);
                        setSheetState(() => isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Journey Planner'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
      extendBodyBehindAppBar: true, // <-- Add this line
      body: Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 1, // <-- Add this
          left: 24,
          right: 24,
        ),
        child: ListView(
          children: [
            // From field with star
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
                  icon: Icon(
                    _fromStationId != null && _favoriteStations.contains(_fromStationId)
                        ? Icons.star
                        : Icons.star_border,
                    color: _fromStationId != null && _favoriteStations.contains(_fromStationId)
                        ? Colors.amber
                        : Colors.grey,
                  ),
                  onPressed: _fromStationId == null
                      ? null
                      : () => _toggleFavorite(_fromStationId!, _fromController.text),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // To field with star
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
                  icon: Icon(
                    _toStationId != null && _favoriteStations.contains(_toStationId)
                        ? Icons.star
                        : Icons.star_border,
                    color: _toStationId != null && _favoriteStations.contains(_toStationId)
                        ? Colors.amber
                        : Colors.grey,
                  ),
                  onPressed: _toStationId == null
                      ? null
                      : () => _toggleFavorite(_toStationId!, _toController.text),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(
                _selectedDate == null
                    ? 'Today'
                    : '${_selectedDate!.toLocal()}'.split(' ')[0]
              ),
              trailing: TextButton(
                onPressed: () {
                  setState(() {
                    _selectedDate = null; // Reset to "Today"
                    _selectedTime = null; // Reset to "Now"
                  });
                  _saveLastUsed();
                },
                child: const Text('Now'),
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  setState(() => _selectedDate = picked);
                  _saveLastUsed();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.access_time),
              title: Text(
                _selectedTime == null
                    ? 'Now'
                    : _selectedTime!.format(context)
              ),
              trailing: TextButton(
                onPressed: () {
                  setState(() {
                    _selectedTime = null; // Reset to "Now"
                  });
                  _saveLastUsed();
                },
                child: const Text('Now'),
              ),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (picked != null) {
                  setState(() => _selectedTime = picked);
                  _saveLastUsed();
                }
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
                        (j['date'] as DateTime).toLocal().toString().split(' ')[0]
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
                      _selectedDate = j['date'] is DateTime ? j['date'] : null;
                      _selectedTime = j['time'] is TimeOfDay ? j['time'] : null;
                    });
                    _searchTrains(saveRecent: false);
                  },
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }
}

