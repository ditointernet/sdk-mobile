import 'package:dito_sdk/dito_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sample_application/sample_app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows error feedback when identify fails natively', (
    tester,
  ) async {
    final ditoSdk = _FakeDitoSdk()
      ..identifyException = PlatformException(
        code: 'INVALID_CREDENTIALS',
        message: 'invalid credentials',
      );
    final appState = await _pumpSampleAppState(tester, ditoSdk);
    appState.userIdController.text = 'user-id';
    appState.userEmailController.text = 'user@example.com';

    await appState.identify();
    await tester.pump();

    _expectSnackBar(
      text: 'Identify failed: invalid credentials',
      backgroundColor: Colors.red,
    );
  });

  testWidgets('shows success feedback when identify is sent', (tester) async {
    final ditoSdk = _FakeDitoSdk()
      ..identifyResult = const DitoOperationResult(DitoOperationStatus.sent);
    final appState = await _pumpSampleAppState(tester, ditoSdk);
    appState.userIdController.text = 'user-id';
    appState.userEmailController.text = 'user@example.com';

    await appState.identify();
    await tester.pump();

    _expectSnackBar(
      text: 'Identify sent',
      backgroundColor: Colors.green,
    );
  });

  testWidgets('shows warning feedback when event is saved locally', (
    tester,
  ) async {
    final ditoSdk = _FakeDitoSdk()
      ..trackResult = const DitoOperationResult(
        DitoOperationStatus.savedLocally,
      );
    final appState = await _pumpSampleAppState(tester, ditoSdk);
    appState.eventNameController.text = 'purchase';

    await appState.track();
    await tester.pump();

    _expectSnackBar(
      text: 'Event saved locally',
      backgroundColor: Colors.orange,
    );
  });

  testWidgets('shows warning feedback when token is saved locally', (
    tester,
  ) async {
    final ditoSdk = _FakeDitoSdk()
      ..registerTokenResult = const DitoOperationResult(
        DitoOperationStatus.savedLocally,
      );
    final appState = await _pumpSampleAppState(tester, ditoSdk);
    appState.tokenController.text = 'device-token';

    await appState.registerToken();
    await tester.pump();

    _expectSnackBar(
      text: 'Device token saved locally',
      backgroundColor: Colors.orange,
    );
  });

  testWidgets('shows success feedback when token is sent', (tester) async {
    final ditoSdk = _FakeDitoSdk()
      ..registerTokenResult =
          const DitoOperationResult(DitoOperationStatus.sent);
    final appState = await _pumpSampleAppState(tester, ditoSdk);
    appState.tokenController.text = 'device-token';

    await appState.registerToken();
    await tester.pump();

    _expectSnackBar(
      text: 'Device token sent',
      backgroundColor: Colors.green,
    );
  });
}

Future<SampleAppState> _pumpSampleAppState(
  WidgetTester tester,
  DitoSdk ditoSdk,
) async {
  final scaffoldKey = GlobalKey<ScaffoldMessengerState>();
  await tester.pumpWidget(
    MaterialApp(
      scaffoldMessengerKey: scaffoldKey,
      home: const Scaffold(body: SizedBox.shrink()),
    ),
  );

  return SampleAppState(
    setState: (callback) => callback(),
    scaffoldKey: scaffoldKey,
    ditoSdk: ditoSdk,
  );
}

void _expectSnackBar({
  required String text,
  required Color backgroundColor,
}) {
  expect(find.text(text), findsOneWidget);
  final snackBar = testerWidget<SnackBar>(find.byType(SnackBar));
  expect(snackBar.backgroundColor, backgroundColor);
}

T testerWidget<T extends Widget>(Finder finder) {
  final element = finder.evaluate().single;
  return element.widget as T;
}

class _FakeDitoSdk extends DitoSdk {
  DitoOperationResult identifyResult = const DitoOperationResult(
    DitoOperationStatus.sent,
  );
  DitoOperationResult trackResult = const DitoOperationResult(
    DitoOperationStatus.sent,
  );
  DitoOperationResult registerTokenResult = const DitoOperationResult(
    DitoOperationStatus.sent,
  );
  PlatformException? identifyException;

  @override
  Future<DitoOperationResult> identify({
    required String id,
    String? name,
    String? email,
    Map<String, dynamic>? customData,
  }) async {
    final exception = identifyException;
    if (exception != null) {
      throw exception;
    }
    return identifyResult;
  }

  @override
  Future<DitoOperationResult> track({
    required String action,
    Map<String, dynamic>? data,
  }) async {
    return trackResult;
  }

  @override
  Future<DitoOperationResult> registerDeviceToken(String token) async {
    return registerTokenResult;
  }
}
