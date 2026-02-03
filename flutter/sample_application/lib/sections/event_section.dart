import 'package:flutter/material.dart';

import '../sample_app_state.dart';

class EventSection extends StatelessWidget {
  const EventSection({super.key, required this.state});

  final SampleAppState state;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Track Event',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: state.eventNameController,
              decoration: const InputDecoration(
                labelText: 'Event Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: state.track,
              child: const Text('Track Event'),
            ),
          ],
        ),
      ),
    );
  }
}
