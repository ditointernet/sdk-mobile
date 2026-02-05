import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:dito_sdk/dito_sdk.dart';
import 'package:dito_sdk/dito_sdk_platform_interface.dart';
import 'package:dito_sdk/dito_sdk_method_channel.dart';
import 'package:dito_sdk/error_handler.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockDitoSdkPlatform
    with MockPlatformInterfaceMixin
    implements DitoSdkPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<void> initialize({required String appKey, required String appSecret}) {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  @override
  Future<void> identify({
    required String id,
    String? name,
    String? email,
    Map<String, dynamic>? customData,
  }) {
    throw UnimplementedError('identify() has not been implemented.');
  }

  @override
  Future<void> track({
    required String action,
    Map<String, dynamic>? data,
  }) {
    throw UnimplementedError('track() has not been implemented.');
  }

  @override
  Future<void> registerDeviceToken(String token) {
    throw UnimplementedError('registerDeviceToken() has not been implemented.');
  }

  @override
  Future<void> unregisterDeviceToken(String token) {
    throw UnimplementedError(
      'unregisterDeviceToken() has not been implemented.',
    );
  }

  @override
  Future<void> setDebugMode({required bool enabled}) {
    throw UnimplementedError('setDebugMode() has not been implemented.');
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

  test('getPlatformVersion', () async {
    DitoSdk ditoSdkPlugin = DitoSdk();
    MockDitoSdkPlatform fakePlatform = MockDitoSdkPlatform();
    DitoSdkPlatform.instance = fakePlatform;

    expect(await ditoSdkPlugin.getPlatformVersion(), '42');
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

    test('should throw NOT_INITIALIZED error when methods called before initialization', () async {
      final ditoSdk = DitoSdk();

      expect(
        () => ditoSdk.identify(id: 'user123'),
        throwsA(isA<PlatformException>().having(
          (e) => e.code,
          'code',
          DitoError.notInitialized,
        )),
      );
    });

    test('should throw INVALID_PARAMETERS error with empty apiKey', () async {
      final ditoSdk = DitoSdk();

      expect(
        () => ditoSdk.initialize(appKey: '', appSecret: 'secret'),
        throwsA(isA<PlatformException>().having(
          (e) => e.code,
          'code',
          DitoError.invalidParameters,
        )),
      );
    });

    test('should throw INVALID_PARAMETERS error with empty apiSecret', () async {
      final ditoSdk = DitoSdk();

      expect(
        () => ditoSdk.initialize(appKey: 'key', appSecret: ''),
        throwsA(isA<PlatformException>().having(
          (e) => e.code,
          'code',
          DitoError.invalidParameters,
        )),
      );
    });
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
          return null;
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
          return null;
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
          return null;
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

    test('should provide enhanced error message for INITIALIZATION_FAILED', () async {
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
    });

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

    test('should provide enhanced error message for INVALID_CREDENTIALS', () async {
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
    });
  });
}
