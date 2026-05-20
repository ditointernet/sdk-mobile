import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'dito_notification_info.dart';
import 'dito_notification_options.dart';
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
    } on PlatformException {
      rethrow;
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
    } on PlatformException {
      rethrow;
    } catch (e) {
      throw mapNativeError(e);
    }
  }

  @override
  Future<void> initializeWithApiKey({
    required String apiKey,
    required String bundleId,
  }) async {
    try {
      await methodChannel.invokeMethod<void>('initializeWithApiKey', {
        'apiKey': apiKey,
        'bundleId': bundleId,
      });
    } on PlatformException {
      rethrow;
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
    } on PlatformException {
      rethrow;
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
    } on PlatformException {
      rethrow;
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
    } on PlatformException {
      rethrow;
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
    } on PlatformException {
      rethrow;
    } catch (e) {
      throw mapNativeError(e);
    }
  }

  @override
  Future<bool> handleNotificationClick(Map<String, dynamic> userInfo) async {
    try {
      final handled = await methodChannel.invokeMethod<bool>(
        'handleNotificationClick',
        userInfo,
      );
      return handled ?? false;
    } on PlatformException {
      rethrow;
    } catch (e) {
      throw mapNativeError(e);
    }
  }

  @override
  Future<void> setNotificationOptions(DitoNotificationOptions options) async {
    try {
      await methodChannel.invokeMethod<void>(
        'setNotificationOptions',
        options.toMap(),
      );
    } on PlatformException {
      rethrow;
    } catch (e) {
      throw mapNativeError(e);
    }
  }

  @override
  Future<List<DitoNotificationInfo>> getNotifications() async {
    try {
      final list = await methodChannel.invokeListMethod<Map<Object?, Object?>>('getNotifications');
      return (list ?? []).map(DitoNotificationInfo.fromMap).toList();
    } on PlatformException {
      rethrow;
    } catch (e) {
      throw mapNativeError(e);
    }
  }

  @override
  Future<void> markNotificationAsRead(String id) async {
    try {
      await methodChannel.invokeMethod<void>('markNotificationAsRead', {'id': id});
    } on PlatformException {
      rethrow;
    } catch (e) {
      throw mapNativeError(e);
    }
  }
}
