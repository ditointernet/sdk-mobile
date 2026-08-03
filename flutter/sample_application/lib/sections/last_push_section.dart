import 'dart:convert';

import 'package:dito_sdk/dito_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../sample_app_state.dart';

/// Último push recebido, cru e parseado, na tela.
///
/// Existe para a sessão de validação em device (E9): as etapas 5 (conferir a estrutura
/// do payload) e 6 (conferir a renderização) caberem num print só, em vez de exigir que
/// alguém cruze `adb logcat` com a tela do device.
///
/// Cobertura, dita na cara: o payload aparece aqui quando o push chega no Dart com o app
/// em **foreground**. Com o app em background ou morto, o `FirebaseMessaging.onMessage`
/// não dispara e a fonte da etapa 5 passa a ser o dump nativo de log (T9.1). O clique
/// aparece em qualquer estado, porque vem do stream do próprio SDK.
class LastPushSection extends StatelessWidget {
  const LastPushSection({super.key, required this.state});

  final SampleAppState state;

  @override
  Widget build(BuildContext context) {
    final payload = state.lastPushPayload;
    final data = state.lastPushData;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Último push recebido',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                if (data != null)
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    tooltip: 'Copiar payload cru',
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: _prettyJson(data)),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Payload copiado'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Só push em foreground. Em background, a fonte é o log nativo '
              '(DITO_PUSH_PAYLOAD).',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            if (data == null || payload == null)
              const Text(
                'Nenhum push recebido nesta sessão.',
                style: TextStyle(color: Colors.grey),
              )
            else ...[
              _label('Recebido em', _formatTime(state.lastPushAt)),
              const SizedBox(height: 12),
              _richContent(payload),
              const Divider(height: 24),
              const Text(
                'Payload cru',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SelectableText(
                  _prettyJson(data),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ],
            if (state.lastClick != null) ...[
              const Divider(height: 24),
              _clickBlock(state.lastClick!, state.lastClickAt),
            ],
          ],
        ),
      ),
    );
  }

  Widget _richContent(DitoPushPayload payload) {
    if (!payload.hasRichContent) {
      return Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Push sem campos ricos — nem imagem, nem botões, nem custom data.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Parsed', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (payload.image.isNotEmpty) ...[
          _label('Imagem', payload.image),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            // A imagem é baixada aqui de novo, não é a que a notificação exibiu.
            // Serve para separar "URL ruim" de "SDK não anexou".
            child: Image.network(
              payload.image,
              height: 140,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 60,
                color: Colors.red.shade50,
                alignment: Alignment.center,
                child: const Text(
                  'Falha ao carregar a imagem desta URL',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (payload.actions.isNotEmpty) ...[
          Text('Botões (${payload.actions.length})',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          // A ordem é significativa e faz parte do aceite: é a ordem que o
          // composer definiu e que a notificação tem que exibir.
          for (var i = 0; i < payload.actions.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${i + 1}. ',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(payload.actions[i].label,
                            style:
                                const TextStyle(fontWeight: FontWeight.w500)),
                        SelectableText(
                          '${payload.actions[i].id} → ${payload.actions[i].link.isEmpty ? '(sem link)' : payload.actions[i].link}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
        ],
        if (payload.customData.isNotEmpty) ...[
          Text('Custom data (${payload.customData.length})',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          // Variável não substituída aparece como *|VAR|* — é o jeito mais rápido
          // de ver que o backend não expandiu o valor.
          for (final entry in payload.customData.entries)
            _label(entry.key, entry.value),
        ],
      ],
    );
  }

  Widget _clickBlock(DitoNotificationClick click, DateTime? at) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Último clique',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: click.isActionClick ? Colors.green : Colors.blueGrey,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                click.isActionClick ? 'botão' : 'corpo',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _label('Horário', _formatTime(at)),
        if (click.isActionClick) ...[
          _label('action_id', click.actionId),
          _label('action_label', click.actionLabel),
        ],
        _label('Deeplink', click.deeplink.isEmpty ? '(vazio)' : click.deeplink),
        _label('notification', click.notificationId),
        if (click.customData.isNotEmpty)
          _label('custom_data', click.customData.toString()),
      ],
    );
  }

  Widget _label(String name, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              name,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime? time) {
    if (time == null) return '-';
    final local = time.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }

  /// JSON legível para o print da evidência. As chaves ricas chegam como strings
  /// JSON dentro do data map, então sem isto o print vira uma linha só ilegível.
  static String _prettyJson(Map<String, dynamic> data) {
    return const JsonEncoder.withIndent('  ').convert(data);
  }
}
