import 'package:flutter/material.dart';

import '../sample_app_state.dart';

class StatusSection extends StatelessWidget {
  const StatusSection({super.key, required this.state});

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
              'SDK Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Platform: ${state.platformVersion}'),
            const SizedBox(height: 4),
            Text('Status: ${state.status}'),
            const SizedBox(height: 4),
            Text('Initialized: ${state.isInitialized}'),
          ],
        ),
      ),
    );
  }
}
