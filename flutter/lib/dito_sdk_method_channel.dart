import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'dito_sdk_platform_interface.dart';
import 'error_handler.dart';

/// An implementation of [DitoSdkPlatform] that uses method channels.
class MethodChannelDitoSdk extends DitoSdkPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('br.com.dito/dito_sdk');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<void> setDebugMode({required bool enabled}) async {
    try {
      await methodChannel.invokeMethod<void>('setDebugMode', {
        'enabled': enabled,
      });
    } on PlatformException catch (e) {
      throw e;
    } catch (e) {
      throw mapNativeError(e);
    }
  }

  @override
  Future<void> initialize({
    required String appKey,
    required String appSecret,
  }) async {
    try {
      await methodChannel.invokeMethod<void>(
        'initialize',
        {
        'appKey': appKey,
        'appSecret': appSecret,
        },
      );
    } on PlatformException catch (e) {
      throw e;
    } catch (e) {
      throw mapNativeError(e);
    }
  }

  @override
  Future<void> identify({
    required String id,
    String? name,
    String? email,
    Map<String, dynamic>? customData,
  }) async {
    try {
      await methodChannel.invokeMethod<void>(
        'identify',
        {
          'id': id,
          'name': name,
          'email': email,
          'customData': customData,
        },
      );
    } on PlatformException catch (e) {
      throw e;
    } catch (e) {
      throw mapNativeError(e);
    }
  }

  @override
  Future<void> track({
    required String action,
    Map<String, dynamic>? data,
  }) async {
    try {
      await methodChannel.invokeMethod<void>(
        'track',
        {
          'action': action,
          'data': data,
        },
      );
    } on PlatformException catch (e) {
      throw e;
    } catch (e) {
      throw mapNativeError(e);
    }
  }

  @override
  Future<void> registerDeviceToken(String token) async {
    try {
      await methodChannel.invokeMethod<void>(
        'registerDeviceToken',
        {
          'token': token,
        },
      );
    } on PlatformException catch (e) {
      throw e;
    } catch (e) {
      throw mapNativeError(e);
    }
  }

  @override
  Future<void> unregisterDeviceToken(String token) async {
    try {
      await methodChannel.invokeMethod<void>(
        'unregisterDeviceToken',
        {
          'token': token,
        },
      );
    } on PlatformException catch (e) {
      throw e;
    } catch (e) {
      throw mapNativeError(e);
    }
  }
}
