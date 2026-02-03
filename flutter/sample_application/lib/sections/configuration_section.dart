import 'package:flutter/material.dart';

import '../sample_app_state.dart';

class ConfigurationSection extends StatelessWidget {
  const ConfigurationSection({super.key, required this.state});

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
              'Configuration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'SDK initialized at startup (API Key/Secret from .env)',
              style: TextStyle(
                fontSize: 12,
                color: state.isInitialized
                    ? Colors.green.shade700
                    : Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: state.apiKeyController,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'API Key',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: state.apiSecretController,
              readOnly: true,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'API Secret',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
