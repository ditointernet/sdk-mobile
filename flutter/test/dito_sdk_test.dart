import 'package:dito_sdk/dito_sdk.dart';
import 'package:dito_sdk/dito_sdk_method_channel.dart';
import 'package:dito_sdk/dito_sdk_platform_interface.dart';
import 'package:dito_sdk/error_handler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockDitoSdkPlatform
    with MockPlatformInterfaceMixin
    implements DitoSdkPlatform {
  bool debugModeEnabled = false;
  bool handleNotificationClickResult = true;
  DitoNotificationOptions? notificationOptions;
  List<DitoNotificationInfo> notifications = <DitoNotificationInfo>[];
  Map<String, dynamic>? notificationClickPayload;
  Map<String, dynamic>? identifyPayload;
  Map<String, dynamic>? trackPayload;
  bool logoutCalled = false;
  String? appKey;
  String? appSecret;
  String? apiKey;
  String? bundleId;
  String? registeredToken;
  String? unregisteredToken;
  String? readNotificationId;

  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<void> initialize({required String appKey, required String appSecret}) {
    this.appKey = appKey;
    this.appSecret = appSecret;
    return Future.value();
  }

  @override
  Future<void> initializeWithApiKey({
    required String apiKey,
    required String bundleId,
  }) {
    this.apiKey = apiKey;
    this.bundleId = bundleId;
    return Future.value();
  }

  @override
  Future<DitoOperationResult> identify({
    required String id,
    String? name,
    String? email,
    Map<String, dynamic>? customData,
  }) {
    identifyPayload = <String, dynamic>{
      'id': id,
      'name': name,
      'email': email,
      'customData': customData,
    };
    return Future.value(const DitoOperationResult(DitoOperationStatus.sent));
  }

  @override
  Future<DitoOperationResult> track({
    required String action,
    Map<String, dynamic>? data,
  }) {
    trackPayload = <String, dynamic>{'action': action, 'data': data};
    return Future.value(const DitoOperationResult(DitoOperationStatus.sent));
  }

  @override
  Future<void> logout() {
    logoutCalled = true;
    return Future.value();
  }

  @override
  Future<DitoOperationResult> registerDeviceToken(String token) {
    registeredToken = token;
    return Future.value(const DitoOperationResult(DitoOperationStatus.sent));
  }

  @override
  Future<DitoOperationResult> unregisterDeviceToken(String token) {
    unregisteredToken = token;
    return Future.value(const DitoOperationResult(DitoOperationStatus.sent));
  }

  @override
  Future<void> setDebugMode({required bool enabled}) {
    debugModeEnabled = enabled;
    return Future.value();
  }

  @override
  Future<bool> handleNotificationClick(Map<String, dynamic> userInfo) {
    notificationClickPayload = userInfo;
    return Future.value(handleNotificationClickResult);
  }

  @override
  Future<void> setNotificationOptions(DitoNotificationOptions options) =>
      Future<void>(() => notificationOptions = options);

  @override
  Future<List<DitoNotificationInfo>> getNotifications() =>
      Future.value(notifications);

  @override
  Future<void> markNotificationAsRead(String id) {
    readNotificationId = id;
    return Future.value();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final DitoSdkPlatform initialPlatform = DitoSdkPlatform.instance;

  setUp(() {
    DitoSdkPlatform.instance = MethodChannelDitoSdk();
  });

  test('$MethodChannelDitoSdk is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelDitoSdk>());
  });

  group('DitoOperationResult', () {
    test('builds sent and saved locally results', () {
      const sent = DitoOperationResult(DitoOperationStatus.sent);
      const savedLocally = DitoOperationResult(
        DitoOperationStatus.savedLocally,
      );

      expect(sent.status, DitoOperationStatus.sent);
      expect(sent.wasSavedLocally, isFalse);
      expect(savedLocally.status, DitoOperationStatus.savedLocally);
      expect(savedLocally.wasSavedLocally, isTrue);
    });

    test('parses known native operation statuses', () {
      final sent = DitoOperationResult.fromMap(<Object?, Object?>{
        'status': 'sent',
      });
      final savedLocally = DitoOperationResult.fromMap(<Object?, Object?>{
        'status': 'saved_locally',
      });

      expect(sent.status, DitoOperationStatus.sent);
      expect(savedLocally.status, DitoOperationStatus.savedLocally);
    });

    test('rejects missing native operation map', () {
      expect(
        () => DitoOperationResult.fromMap(null),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects missing native operation status', () {
      expect(
        () => DitoOperationResult.fromMap(<Object?, Object?>{}),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects unknown native operation status', () {
      expect(
        () =>
            DitoOperationResult.fromMap(<Object?, Object?>{'status': 'queued'}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  test('getPlatformVersion', () async {
    DitoSdk ditoSdkPlugin = DitoSdk();
    MockDitoSdkPlatform fakePlatform = MockDitoSdkPlatform();
    DitoSdkPlatform.instance = fakePlatform;

    expect(await ditoSdkPlugin.getPlatformVersion(), '42');
  });

  test('public API keeps current compatible signatures', () async {
    final ditoSdk = DitoSdk();
    final fakePlatform = MockDitoSdkPlatform()
      ..notifications = <DitoNotificationInfo>[
        DitoNotificationInfo(
          id: 'inbox-id',
          notificationId: 'notification-id',
          reference: 'reference',
          title: 'Title',
          message: 'Message',
          link: 'dito://notification',
          receivedAt: DateTime.fromMillisecondsSinceEpoch(1710000000000),
          isRead: false,
        ),
      ];
    DitoSdkPlatform.instance = fakePlatform;

    await ditoSdk.setDebugMode(enabled: true);
    await ditoSdk.initialize(appKey: 'app-key', appSecret: 'app-secret');
    await ditoSdk.initializeWithApiKey(
      apiKey: 'api-key',
      bundleId: 'br.com.dito.app',
    );
    await ditoSdk.identify(
      id: 'user-id',
      name: 'User Name',
      email: 'user@example.com',
      customData: <String, dynamic>{'plan': 'premium'},
    );
    await ditoSdk.track(
      action: 'purchase',
      data: <String, dynamic>{'sku': 'sku-1'},
    );
    await ditoSdk.logout();
    await ditoSdk.registerDeviceToken('device-token');
    await ditoSdk.unregisterDeviceToken('device-token');
    final handled = await ditoSdk.handleNotificationClick(<String, dynamic>{
      'deeplink': 'dito://notification',
      'notificationId': 'notification-id',
    });
    const options = DitoNotificationOptions(
      accentColor: 0xFF336699,
      badgeEnabled: false,
      largeIconResId: 10,
      smallIconResId: 20,
      soundResourceName: 'custom_sound',
    );
    await ditoSdk.setNotificationOptions(options);
    final notifications = await ditoSdk.getNotifications();
    await ditoSdk.markNotificationAsRead('inbox-id');

    expect(ditoSdk.isInitialized, isTrue);
    expect(fakePlatform.debugModeEnabled, isTrue);
    expect(fakePlatform.appKey, 'app-key');
    expect(fakePlatform.appSecret, 'app-secret');
    expect(fakePlatform.apiKey, 'api-key');
    expect(fakePlatform.bundleId, 'br.com.dito.app');
    expect(fakePlatform.identifyPayload, <String, dynamic>{
      'id': 'user-id',
      'name': 'User Name',
      'email': 'user@example.com',
      'customData': <String, dynamic>{'plan': 'premium'},
    });
    expect(fakePlatform.trackPayload, <String, dynamic>{
      'action': 'purchase',
      'data': <String, dynamic>{'sku': 'sku-1'},
    });
    expect(fakePlatform.logoutCalled, isTrue);
    expect(fakePlatform.registeredToken, 'device-token');
    expect(fakePlatform.unregisteredToken, 'device-token');
    expect(handled, isTrue);
    expect(fakePlatform.notificationClickPayload, <String, dynamic>{
      'deeplink': 'dito://notification',
      'notificationId': 'notification-id',
    });
    expect(fakePlatform.notificationOptions, options);
    expect(notifications.single.notificationId, 'notification-id');
    expect(fakePlatform.readNotificationId, 'inbox-id');
    expect(DitoSdk.onNotificationClick, isA<Stream<DitoNotificationClick>>());
  });

  group('initialize', () {
    const MethodChannel channel = MethodChannel('br.com.dito/dito_sdk');

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('should initialize successfully with valid credentials', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            if (methodCall.method == 'initialize') {
              return null;
            }
            return null;
          });

      final ditoSdk = DitoSdk();

      await ditoSdk.initialize(
        appKey: 'test-api-key',
        appSecret: 'test-api-secret',
      );

      expect(ditoSdk.isInitialized, isTrue);
    });

    test(
      'should throw NOT_INITIALIZED error when methods called before initialization',
      () async {
        final ditoSdk = DitoSdk();

        expect(
          () => ditoSdk.identify(id: 'user123'),
          throwsA(
            isA<PlatformException>().having(
              (e) => e.code,
              'code',
              DitoError.notInitialized,
            ),
          ),
        );
        expect(
          () => ditoSdk.logout(),
          throwsA(
            isA<PlatformException>().having(
              (e) => e.code,
              'code',
              DitoError.notInitialized,
            ),
          ),
        );
      },
    );

    test('should throw INVALID_PARAMETERS error with empty apiKey', () async {
      final ditoSdk = DitoSdk();

      expect(
        () => ditoSdk.initialize(appKey: '', appSecret: 'secret'),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            DitoError.invalidParameters,
          ),
        ),
      );
    });

    test(
      'should throw INVALID_PARAMETERS error with empty apiSecret',
      () async {
        final ditoSdk = DitoSdk();

        expect(
          () => ditoSdk.initialize(appKey: 'key', appSecret: ''),
          throwsA(
            isA<PlatformException>().having(
              (e) => e.code,
              'code',
              DitoError.invalidParameters,
            ),
          ),
        );
      },
    );
  });

  group('identify', () {
    const MethodChannel channel = MethodChannel('br.com.dito/dito_sdk');

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('should identify user successfully', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            if (methodCall.method == 'initialize') {
              return null;
            }
            if (methodCall.method == 'identify') {
              return <String, Object?>{'status': 'sent'};
            }
            return null;
          });

      final ditoSdk = DitoSdk();
      await ditoSdk.initialize(
        appKey: 'test-api-key',
        appSecret: 'test-api-secret',
      );

      await ditoSdk.identify(
        id: 'user123',
        name: 'John Doe',
        email: 'john@example.com',
        customData: {'type': 'premium'},
      );

      expect(ditoSdk.isInitialized, isTrue);
    });
  });

  group('track', () {
    const MethodChannel channel = MethodChannel('br.com.dito/dito_sdk');

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('should track event successfully', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            if (methodCall.method == 'initialize') {
              return null;
            }
            if (methodCall.method == 'track') {
              return <String, Object?>{'status': 'sent'};
            }
            return null;
          });

      final ditoSdk = DitoSdk();
      await ditoSdk.initialize(
        appKey: 'test-api-key',
        appSecret: 'test-api-secret',
      );

      await ditoSdk.track(
        action: 'purchase',
        data: {'product': 'item123', 'price': 99.99},
      );

      expect(ditoSdk.isInitialized, isTrue);
    });
  });

  group('logout', () {
    const MethodChannel channel = MethodChannel('br.com.dito/dito_sdk');
    MethodCall? capturedCall;

    setUp(() {
      capturedCall = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            capturedCall = methodCall;
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('should call platform logout after initialization', () async {
      final ditoSdk = DitoSdk();
      await ditoSdk.initialize(
        appKey: 'test-api-key',
        appSecret: 'test-api-secret',
      );

      await ditoSdk.logout();

      expect(capturedCall, isNotNull);
      expect(capturedCall!.method, 'logout');
      expect(capturedCall!.arguments, isNull);
    });
  });

  group('registerDeviceToken', () {
    const MethodChannel channel = MethodChannel('br.com.dito/dito_sdk');

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('should register device token successfully', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            if (methodCall.method == 'initialize') {
              return null;
            }
            if (methodCall.method == 'registerDeviceToken') {
              return <String, Object?>{'status': 'sent'};
            }
            return null;
          });

      final ditoSdk = DitoSdk();
      await ditoSdk.initialize(
        appKey: 'test-api-key',
        appSecret: 'test-api-secret',
      );

      await ditoSdk.registerDeviceToken('test-device-token');

      expect(ditoSdk.isInitialized, isTrue);
    });
  });

  group('setNotificationOptions', () {
    const MethodChannel channel = MethodChannel('br.com.dito/dito_sdk');
    MethodCall? capturedCall;

    setUp(() {
      capturedCall = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            capturedCall = methodCall;
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test(
      'should invoke setNotificationOptions with correct arguments',
      () async {
        // Arrange
        final ditoSdk = DitoSdk();
        const options = DitoNotificationOptions(badgeEnabled: false);

        // Act
        await ditoSdk.setNotificationOptions(options);

        // Assert
        expect(capturedCall, isNotNull);
        expect(capturedCall!.method, 'setNotificationOptions');
        expect(capturedCall!.arguments['badgeEnabled'], false);
      },
    );

    test('should be callable before initialize without throwing', () async {
      // Arrange
      final ditoSdk = DitoSdk();
      const options = DitoNotificationOptions(badgeEnabled: true);

      // Act & Assert — must not throw even though SDK is not initialized
      await expectLater(ditoSdk.setNotificationOptions(options), completes);
    });

    test('should pass all options fields to native channel', () async {
      // Arrange
      final ditoSdk = DitoSdk();
      const options = DitoNotificationOptions(
        accentColor: 0xFF0000,
        badgeEnabled: false,
        largeIconResId: 1,
        smallIconResId: 2,
        soundResourceName: 'custom_sound',
      );

      // Act
      await ditoSdk.setNotificationOptions(options);

      // Assert
      expect(capturedCall!.method, 'setNotificationOptions');
      final args = capturedCall!.arguments as Map;
      expect(args['accentColor'], 0xFF0000);
      expect(args['badgeEnabled'], false);
      expect(args['largeIconResId'], 1);
      expect(args['smallIconResId'], 2);
      expect(args['soundResourceName'], 'custom_sound');
    });
  });

  group('error handling', () {
    const MethodChannel channel = MethodChannel('br.com.dito/dito_sdk');

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test(
      'should provide enhanced error message for INITIALIZATION_FAILED',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'initialize') {
                throw PlatformException(
                  code: DitoError.initializationFailed,
                  message: 'SDK initialization failed',
                );
              }
              return null;
            });

        final ditoSdk = DitoSdk();

        try {
          await ditoSdk.initialize(
            appKey: 'test-api-key',
            appSecret: 'test-api-secret',
          );
          fail('Should have thrown PlatformException');
        } on PlatformException catch (e) {
          expect(e.code, DitoError.initializationFailed);
          expect(e.message, contains('Failed to initialize Dito SDK'));
          expect(e.message, contains('verify your API credentials'));
        }
      },
    );

    test('should provide enhanced error message for NETWORK_ERROR', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            if (methodCall.method == 'initialize') {
              return null;
            }
            if (methodCall.method == 'identify') {
              throw PlatformException(
                code: DitoError.networkError,
                message: 'Connection timeout',
              );
            }
            return null;
          });

      final ditoSdk = DitoSdk();
      await ditoSdk.initialize(
        appKey: 'test-api-key',
        appSecret: 'test-api-secret',
      );

      try {
        await ditoSdk.identify(id: 'user123');
        fail('Should have thrown PlatformException');
      } on PlatformException catch (e) {
        expect(e.code, DitoError.networkError);
        expect(e.message, contains('Network error occurred'));
        expect(e.message, contains('check your internet connection'));
      }
    });

    test(
      'should provide enhanced error message for INVALID_CREDENTIALS',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'initialize') {
                throw PlatformException(
                  code: DitoError.invalidCredentials,
                  message: 'Invalid API key',
                );
              }
              return null;
            });

        final ditoSdk = DitoSdk();

        try {
          await ditoSdk.initialize(
            appKey: 'invalid-key',
            appSecret: 'invalid-secret',
          );
          fail('Should have thrown PlatformException');
        } on PlatformException catch (e) {
          expect(e.code, DitoError.invalidCredentials);
          expect(e.message, contains('Invalid API credentials'));
          expect(e.message, contains('check your apiKey and apiSecret'));
        }
      },
    );
  });
}
