import 'package:flutter/material.dart';
import 'package:ontrack/providers/theme_provider.dart';
import 'package:provider/provider.dart';

// --- Settings Page ---
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

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
            subtitle: Text('1.0.0'),
          ),
        ],
      ),
    );
  }
}