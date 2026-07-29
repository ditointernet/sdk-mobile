import 'package:dito_sdk/dito_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../sample_app_state.dart';

class NotificationInboxSection extends StatefulWidget {
  const NotificationInboxSection({super.key, required this.state});

  final SampleAppState state;

  @override
  State<NotificationInboxSection> createState() => _NotificationInboxSectionState();
}

class _NotificationInboxSectionState extends State<NotificationInboxSection> {
  List<DitoNotificationInfo> _notifications = [];
  bool _loading = false;
  String? _error;

  Future<void> _loadNotifications() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.state.ditoSdk.getNotifications();
      setState(() => _notifications = list);
    } on PlatformException catch (e) {
      setState(() => _error = e.message ?? 'Erro ao carregar notificações');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _markAsRead(DitoNotificationInfo notification) async {
    try {
      await widget.state.ditoSdk.markNotificationAsRead(notification.id);
      await _loadNotifications();
    } on PlatformException catch (e) {
      setState(() => _error = e.message ?? 'Erro ao marcar como lida');
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notification Inbox',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loading ? null : _loadNotifications,
              child: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Ver notificações'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            if (_notifications.isNotEmpty) ...[
              const SizedBox(height: 8),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _notifications.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final n = _notifications[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            n.title,
                            style: TextStyle(
                              fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold,
                            ),
                          ),
                        ),
                        if (!n.isRead)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'não lida',
                              style: TextStyle(color: Colors.white, fontSize: 10),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n.message),
                        // Campos ricos persistidos no inbox: prova que a imagem e a
                        // custom data sobreviveram à migração de schema, não só à
                        // exibição da notificação.
                        if (n.image.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(
                                n.image,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Text(
                                  'imagem: ${n.image}',
                                  style: const TextStyle(fontSize: 11, color: Colors.red),
                                ),
                              ),
                            ),
                          ),
                        if (n.customData.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'custom data: ${n.customData}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        Text(
                          n.receivedAt.toLocal().toString().substring(0, 16),
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                    onTap: n.isRead ? null : () => _markAsRead(n),
                    trailing: n.isRead
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.mark_email_read, size: 20),
                            tooltip: 'Marcar como lida',
                            onPressed: () => _markAsRead(n),
                          ),
                  );
                },
              ),
            ] else if (!_loading && _error == null && _notifications.isEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Nenhuma notificação carregada.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
