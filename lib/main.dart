import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ontrack/providers/journey_search_provider.dart';
import 'package:ontrack/providers/trips_provider.dart';
import 'package:ontrack/providers/theme_provider.dart';
import 'package:ontrack/providers/profile_provider.dart';
import 'package:ontrack/pages/journey_planner_page.dart';
import 'package:ontrack/pages/trip_page.dart';
import 'package:ontrack/pages/profile_page.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TripsProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => JourneySearchProvider()),
      ],
      child: const OnTrackApp(),
    ),
  );
}

class OnTrackApp extends StatelessWidget {
  const OnTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'OnTrack',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      darkTheme: themeProvider.darkTheme, // <-- Use your custom darkTheme here!
      themeMode: themeProvider.themeMode,
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const JourneyPlannerPage(),
    const TripPage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: _pages[_selectedIndex],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.train), label: 'Planner'),
          NavigationDestination(icon: Icon(Icons.explore), label: 'Trips'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}



