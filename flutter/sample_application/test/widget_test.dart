// Smoke test da seção "último push recebido".
//
// Substitui o teste de contador que vinha do template do `flutter create` e nunca foi
// adaptado: ele chamava `MyApp()` sem os parâmetros obrigatórios e procurava um botão de
// incremento que este app nunca teve, então não compilava e derrubava o `flutter analyze`
// do sample.
//
// O alvo aqui é a seção do E9/T9.2, que é onde a sessão de validação em device lê o
// payload. Um teste de widget não substitui o print no device, mas trava a forma da tela.

import 'package:dito_sdk/dito_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sample_application/sample_app_state.dart';
import 'package:sample_application/sections/last_push_section.dart';

SampleAppState _buildState() {
  return SampleAppState(
    setState: (fn) => fn(),
    scaffoldKey: GlobalKey<ScaffoldMessengerState>(),
    ditoSdk: DitoSdk(),
  );
}

Future<void> _pump(WidgetTester tester, SampleAppState state) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: LastPushSection(state: state)),
      ),
    ),
  );
}

void main() {
  testWidgets('sem push recebido, mostra o estado vazio', (tester) async {
    await _pump(tester, _buildState());

    expect(find.text('Nenhum push recebido nesta sessão.'), findsOneWidget);
  });

  testWidgets('push rico mostra botões na ordem e custom data', (tester) async {
    final state = _buildState();
    const data = {
      'channel': 'DITO',
      'actions':
          '[{"id":"comprar_agora","label":"Comprar agora","link":"https://loja/x"},'
              '{"id":"ver_promocao","label":"Ver promoção","link":"brandapp://promo"}]',
      'custom_data': '{"nivel_programa":"ouro"}',
    };
    state.lastPushData = Map<String, dynamic>.from(data);
    state.lastPushPayload = DitoSdk.parsePushPayload(data);
    state.lastPushAt = DateTime(2026, 7, 29, 10, 30, 15);

    await _pump(tester, state);

    expect(find.text('Botões (2)'), findsOneWidget);
    expect(find.text('Comprar agora'), findsOneWidget);
    expect(find.text('Ver promoção'), findsOneWidget);
    // A ordem do array é significativa e faz parte do aceite.
    expect(find.text('1. '), findsOneWidget);
    expect(find.text('2. '), findsOneWidget);
    expect(find.text('Custom data (1)'), findsOneWidget);
    expect(find.text('ouro'), findsOneWidget);
    expect(find.text('10:30:15'), findsOneWidget);
  });

  testWidgets('push sem campos ricos diz isso, em vez de parecer quebrado',
      (tester) async {
    final state = _buildState();
    const data = {'channel': 'DITO', 'title': 'Oi'};
    state.lastPushData = Map<String, dynamic>.from(data);
    state.lastPushPayload = DitoSdk.parsePushPayload(data);
    state.lastPushAt = DateTime(2026, 7, 29, 10, 30, 15);

    await _pump(tester, state);

    expect(find.textContaining('Push sem campos ricos'), findsOneWidget);
  });

  testWidgets('clique em botão é rotulado como botão, com action_id',
      (tester) async {
    final state = _buildState();
    state.lastClick = const DitoNotificationClick(
      deeplink: 'https://loja/x',
      notificationId: '123',
      reference: 'ref-1',
      logId: 'log-1',
      notificationName: 'Promo',
      userId: 'user-1',
      actionId: 'comprar_agora',
      actionLabel: 'Comprar agora',
    );
    state.lastClickAt = DateTime(2026, 7, 29, 10, 31, 0);

    await _pump(tester, state);

    expect(find.text('botão'), findsOneWidget);
    expect(find.text('comprar_agora'), findsOneWidget);
    expect(find.text('10:31:00'), findsOneWidget);
  });

  testWidgets('clique no corpo é rotulado como corpo, sem action',
      (tester) async {
    final state = _buildState();
    state.lastClick = const DitoNotificationClick(
      deeplink: 'brandapp://home',
      notificationId: '123',
      reference: 'ref-1',
      logId: '',
      notificationName: '',
      userId: '',
    );
    state.lastClickAt = DateTime(2026, 7, 29, 10, 31, 0);

    await _pump(tester, state);

    expect(find.text('corpo'), findsOneWidget);
    expect(find.text('action_id'), findsNothing);
  });
}
