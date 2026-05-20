import 'package:flutter/material.dart';

import '../sample_app_state.dart';

class NotificationOptionsSection extends StatelessWidget {
  const NotificationOptionsSection({super.key, required this.state});

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
              'Notification Options',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: state.smallIconController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Small Icon (Android, resource ID)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: state.largeIconController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Large Icon (Android, resource ID)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: state.soundController,
              decoration: const InputDecoration(
                labelText: 'Sound (resource name)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: state.accentColorController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Accent Color (Android, int ARGB)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: state.applyNotificationOptions,
              child: const Text('Aplicar Notification Options'),
            ),
          ],
        ),
      ),
    );
  }
}
