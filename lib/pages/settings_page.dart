import 'package:flutter/material.dart';
import 'package:ontrack/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- Settings Page ---
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _clearCache(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('lastFromName');
    await prefs.remove('lastToName');
    await prefs.remove('lastFromId');
    await prefs.remove('lastToId');
    await prefs.remove('lastDate');
    await prefs.remove('lastTime');
    await prefs.remove('favoriteStations');
    await prefs.remove('favoriteStationNames');
    await prefs.remove('recentJourneys');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cache cleared!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final current = themeProvider.mode;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const ListTile(
            leading: Icon(Icons.palette),
            title: Text('Appearance'),
          ),
          RadioListTile<AppThemeMode>(
            title: const Text('System'),
            value: AppThemeMode.system,
            groupValue: current,
            onChanged: (val) => themeProvider.setMode(val!),
          ),
          RadioListTile<AppThemeMode>(
            title: const Text('Light'),
            value: AppThemeMode.light,
            groupValue: current,
            onChanged: (val) => themeProvider.setMode(val!),
          ),
          RadioListTile<AppThemeMode>(
            title: const Text('Dark'),
            value: AppThemeMode.dark,
            groupValue: current,
            onChanged: (val) => themeProvider.setMode(val!),
          ),
          RadioListTile<AppThemeMode>(
            title: const Text('OLED Dark'),
            value: AppThemeMode.oledDark,
            groupValue: current,
            onChanged: (val) => themeProvider.setMode(val!),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.info),
            title: Text('Version'),
            subtitle: Text('1.1.0 (Build 1A2a)'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.cleaning_services, color: Colors.teal),
            title: const Text('Clear Cache'),
            subtitle: const Text(
              'Remove all saved stations, recent journeys, and reset date/time to today and now.',
              style: TextStyle(fontSize: 13),
            ),
            trailing: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              onPressed: () => _clearCache(context),
              child: const Text('Clear'),
            ),
          ),
        ],
      ),
    );
  }
}