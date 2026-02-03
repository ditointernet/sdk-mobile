import 'package:flutter/material.dart';

import '../sample_app_state.dart';

class TokenSection extends StatelessWidget {
  const TokenSection({super.key, required this.state});

  final SampleAppState state;

  @override
  Widget build(BuildContext context) {
    final fcm = state.fcmDebugStatus;
    final isReady = fcm.startsWith('Ready');
    final isError =
        fcm.startsWith('Error') || fcm.startsWith('Push not');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Device Token',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: isReady
                    ? Colors.green.shade50
                    : isError
                        ? Colors.red.shade50
                        : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FCM status: $fcm',
                    style: TextStyle(
                      fontSize: 12,
                      color: isReady
                          ? Colors.green.shade800
                          : isError
                              ? Colors.red.shade800
                              : Colors.orange.shade800,
                    ),
                  ),
                  if (state.fcmPushReceivedCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Push received (foreground): ${state.fcmPushReceivedCount}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: state.tokenController,
              decoration: const InputDecoration(
                labelText: 'FCM Device Token',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: state.registerToken,
                    child: const Text('Register Token'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: state.unregisterToken,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    child: const Text('Unregister Token'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
