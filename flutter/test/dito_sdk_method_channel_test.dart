import 'package:dito_sdk/dito_notification_options.dart';
import 'package:dito_sdk/dito_operation_result.dart';
import 'package:dito_sdk/dito_sdk_method_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('br.com.dito/dito_sdk');
  late List<MethodCall> calls;
  late Object? operationResponse;
  PlatformException? operationException;
  late MethodChannelDitoSdk platform;

  setUp(() {
    calls = <MethodCall>[];
    operationResponse = <String, Object?>{'status': 'sent'};
    operationException = null;
    platform = MethodChannelDitoSdk();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          calls.add(methodCall);

          switch (methodCall.method) {
            case 'getPlatformVersion':
              return '42';
            case 'identify':
            case 'track':
            case 'registerDeviceToken':
            case 'unregisterDeviceToken':
              final exception = operationException;
              if (exception != null) {
                throw exception;
              }
              return operationResponse;
            case 'handleNotificationClick':
              return true;
            case 'getNotifications':
              return <Map<String, Object?>>[
                <String, Object?>{
                  'id': 'inbox-id',
                  'notificationId': 'notification-id',
                  'reference': 'reference',
                  'title': 'Title',
                  'message': 'Message',
                  'link': 'dito://notification',
                  'receivedAt': 1710000000000,
                  'isRead': true,
                },
              ];
          }

          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<DitoOperationResult> callOperation(String method) {
    switch (method) {
      case 'identify':
        return platform.identify(
          id: 'user-id',
          name: 'User Name',
          email: 'user@example.com',
          customData: <String, Object?>{'plan': 'premium'},
        );
      case 'track':
        return platform.track(
          action: 'purchase',
          data: <String, Object?>{'sku': 'sku-1'},
        );
      case 'registerDeviceToken':
        return platform.registerDeviceToken('device-token');
      case 'unregisterDeviceToken':
        return platform.unregisterDeviceToken('device-token');
    }

    throw ArgumentError.value(method, 'method', 'Unsupported operation');
  }

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });

  test('initialize sends app credentials to native channel', () async {
    await platform.initialize(appKey: 'app-key', appSecret: 'app-secret');

    expect(calls.single.method, 'initialize');
    expect(calls.single.arguments, <String, Object?>{
      'appKey': 'app-key',
      'appSecret': 'app-secret',
    });
  });

  test(
    'initializeWithApiKey sends API key credentials to native channel',
    () async {
      await platform.initializeWithApiKey(
        apiKey: 'api-key',
        bundleId: 'br.com.dito.app',
      );

      expect(calls.single.method, 'initializeWithApiKey');
      expect(calls.single.arguments, <String, Object?>{
        'apiKey': 'api-key',
        'bundleId': 'br.com.dito.app',
      });
    },
  );

  test('identify preserves current public payload shape', () async {
    await platform.identify(
      id: 'user-id',
      name: 'User Name',
      email: 'user@example.com',
      customData: <String, Object?>{'plan': 'premium'},
    );

    expect(calls.single.method, 'identify');
    expect(calls.single.arguments, <String, Object?>{
      'id': 'user-id',
      'name': 'User Name',
      'email': 'user@example.com',
      'customData': <String, Object?>{'plan': 'premium'},
    });
  });

  test('track preserves current public payload shape', () async {
    await platform.track(
      action: 'purchase',
      data: <String, Object?>{'sku': 'sku-1'},
    );

    expect(calls.single.method, 'track');
    expect(calls.single.arguments, <String, Object?>{
      'action': 'purchase',
      'data': <String, Object?>{'sku': 'sku-1'},
    });
  });

  test('logout invokes native channel without payload', () async {
    await platform.logout();

    expect(calls.single.method, 'logout');
    expect(calls.single.arguments, isNull);
  });

  test('device token methods send token payloads to native channel', () async {
    await platform.registerDeviceToken('device-token');
    await platform.unregisterDeviceToken('device-token');

    expect(calls[0].method, 'registerDeviceToken');
    expect(calls[0].arguments, <String, Object?>{'token': 'device-token'});
    expect(calls[1].method, 'unregisterDeviceToken');
    expect(calls[1].arguments, <String, Object?>{'token': 'device-token'});
  });

  for (final method in <String>[
    'identify',
    'track',
    'registerDeviceToken',
    'unregisterDeviceToken',
  ]) {
    test('$method parses sent operation result', () async {
      operationResponse = <String, Object?>{'status': 'sent'};

      final result = await callOperation(method);

      expect(result.status, DitoOperationStatus.sent);
      expect(result.wasSavedLocally, isFalse);
    });

    test('$method parses saved locally operation result', () async {
      operationResponse = <String, Object?>{'status': 'saved_locally'};

      final result = await callOperation(method);

      expect(result.status, DitoOperationStatus.savedLocally);
      expect(result.wasSavedLocally, isTrue);
    });

    test('$method propagates native PlatformException', () async {
      operationException = PlatformException(
        code: 'NATIVE_FAILURE',
        message: '$method failed',
      );

      expect(
        () => callOperation(method),
        throwsA(
          isA<PlatformException>().having(
            (exception) => exception.code,
            'code',
            'NATIVE_FAILURE',
          ),
        ),
      );
    });

    test('$method rejects invalid native operation result', () async {
      operationResponse = <String, Object?>{'status': 'queued'};

      await expectLater(
        () => callOperation(method),
        throwsA(isA<PlatformException>()),
      );
    });
  }

  test('setDebugMode sends enabled flag to native channel', () async {
    await platform.setDebugMode(enabled: true);

    expect(calls.single.method, 'setDebugMode');
    expect(calls.single.arguments, <String, Object?>{'enabled': true});
  });

  test('handleNotificationClick returns native handled result', () async {
    final handled = await platform.handleNotificationClick(<String, dynamic>{
      'deeplink': 'dito://notification',
      'notificationId': 'notification-id',
    });

    expect(handled, isTrue);
    expect(calls.single.method, 'handleNotificationClick');
    expect(calls.single.arguments, <String, Object?>{
      'deeplink': 'dito://notification',
      'notificationId': 'notification-id',
    });
  });

  test('setNotificationOptions sends all supported native fields', () async {
    const options = DitoNotificationOptions(
      accentColor: 0xFF336699,
      badgeEnabled: false,
      largeIconResId: 10,
      smallIconResId: 20,
      soundResourceName: 'custom_sound',
    );

    await platform.setNotificationOptions(options);

    expect(calls.single.method, 'setNotificationOptions');
    expect(calls.single.arguments, <String, Object?>{
      'accentColor': 0xFF336699,
      'badgeEnabled': false,
      'largeIconResId': 10,
      'smallIconResId': 20,
      'soundResourceName': 'custom_sound',
    });
  });

  test('getNotifications parses native inbox payload', () async {
    final notifications = await platform.getNotifications();

    expect(calls.single.method, 'getNotifications');
    expect(notifications, hasLength(1));
    expect(notifications.single.id, 'inbox-id');
    expect(notifications.single.notificationId, 'notification-id');
    expect(notifications.single.reference, 'reference');
    expect(notifications.single.title, 'Title');
    expect(notifications.single.message, 'Message');
    expect(notifications.single.link, 'dito://notification');
    expect(
      notifications.single.receivedAt,
      DateTime.fromMillisecondsSinceEpoch(1710000000000),
    );
    expect(notifications.single.isRead, isTrue);
  });

  test('markNotificationAsRead sends inbox id to native channel', () async {
    await platform.markNotificationAsRead('inbox-id');

    expect(calls.single.method, 'markNotificationAsRead');
    expect(calls.single.arguments, <String, Object?>{'id': 'inbox-id'});
  });
}
