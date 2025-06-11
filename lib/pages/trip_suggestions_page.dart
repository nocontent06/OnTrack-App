import 'package:flutter/material.dart';
import 'package:ontrack/pages/journey_planner_page.dart';
// --- Trip Suggestions Page ---
class TripSuggestionsPage extends StatelessWidget {
  const TripSuggestionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Dummy suggestions
    final suggestions = [
      'Paris',
      'Berlin',
      'Rome',
      'Amsterdam',
      'Vienna',
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Trip Suggestions')),
      body: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: suggestions.length,
        itemBuilder: (context, i) {
          return Card(
            elevation: 3,
            margin: const EdgeInsets.only(bottom: 16),
            child: ListTile(
              leading: const Icon(Icons.location_city),
              title: Text(suggestions[i]),
              trailing: ElevatedButton(
                child: const Text('Plan Trip'),
                onPressed: () {
                  // Could prefill planner or show more info
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => JourneyPlannerPage(),
                  ));
                },
              ),
            ),
          );
        },
      ),
    );
  }
}