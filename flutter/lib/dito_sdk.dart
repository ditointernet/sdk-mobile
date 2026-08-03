export 'dito_notification_info.dart';
export 'dito_notification_listener.dart';
export 'dito_notification_options.dart';
export 'dito_push_payload.dart';

import 'package:flutter/services.dart';

import 'dito_notification_info.dart';
import 'dito_notification_listener.dart';
import 'dito_notification_options.dart';
import 'dito_push_payload.dart';
import 'dito_sdk_platform_interface.dart';
import 'error_handler.dart';
import 'parameter_validator.dart';

class DitoSdk {
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  static Stream<DitoNotificationClick> get onNotificationClick =>
      DitoNotificationListener.onNotificationClick;

  /// Extrai imagem, botões e custom data de um data map de push.
  ///
  /// Atalho para [DitoPushPayload.fromData], para quem recebe o payload cru de um
  /// handler do `firebase_messaging` (`RemoteMessage.data`). Não fala com o nativo:
  /// é parsing puro, então pode rodar em background handler e em teste.
  static DitoPushPayload parsePushPayload(Map<dynamic, dynamic>? data) =>
      DitoPushPayload.fromData(data);

  Future<String?> getPlatformVersion() {
    return DitoSdkPlatform.instance.getPlatformVersion();
  }

  /// Enables or disables native SDK debug logging. May be called before [initialize].
  Future<void> setDebugMode({required bool enabled}) async {
    try {
      await DitoSdkPlatform.instance.setDebugMode(enabled: enabled);
    } on PlatformException catch (e) {
      throw mapNativeError(e);
    } catch (e) {
      throw mapNativeError(e);
    }
  }

  /// Initializes the Dito SDK with [appKey] and [appSecret].
  ///
  /// Must be called before [identify], [track], and other methods that require
  /// [isInitialized]. Sets [isInitialized] to true on success.
  ///
  /// Throws [PlatformException] with [DitoError.invalidParameters] if
  /// [appKey] or [appSecret] are empty.
  ///
  /// Example:
  /// ```dart
  /// final ditoSdk = DitoSdk();
  /// await ditoSdk.initialize(
  ///   appKey: 'your-app-key',
  ///   appSecret: 'your-app-secret',
  /// );
  /// ```
  Future<void> initialize({
    required String appKey,
    required String appSecret,
  }) async {
    validateAppKey(appKey);
    validateAppSecret(appSecret);

    try {
      await DitoSdkPlatform.instance.initialize(
        appKey: appKey,
        appSecret: appSecret
      );
      _isInitialized = true;
    } on PlatformException catch (e) {
      throw mapNativeError(e);
    } catch (e) {
      throw mapNativeError(e);
    }
  }

  /// Initializes the SDK with [apiKey] and [bundleId] only (no app secret).
  Future<void> initializeWithApiKey({
    required String apiKey,
    required String bundleId,
  }) async {
    try {
      await DitoSdkPlatform.instance.initializeWithApiKey(
        apiKey: apiKey,
        bundleId: bundleId,
      );
      _isInitialized = true;
    } on PlatformException catch (e) {
      throw mapNativeError(e);
    } catch (e) {
      throw mapNativeError(e);
    }
  }

  /// Identifies a user in Dito CRM.
  ///
  /// This method must be called after [initialize].
  ///
  /// Throws [PlatformException] with code [DitoError.notInitialized] if SDK is not initialized.
  /// Throws [PlatformException] with code [DitoError.invalidParameters] if [id] is null or empty, or [email] is invalid.
  ///
  /// Example:
  /// ```dart
  /// final ditoSdk = DitoSdk();
  /// await ditoSdk.identify(
  ///   id: 'user123',
  ///   name: 'John Doe',
  ///   email: 'john@example.com',
  ///   customData: {'type': 'premium', 'points': 1500},
  /// );
  /// ```
  Future<void> identify({
    required String id,
    String? name,
    String? email,
    Map<String, dynamic>? customData,
  }) async {
    _checkInitialized();
    _validateIdentifyParameters(id, email);
    await _performIdentify(id: id, name: name, email: email, customData: customData);
  }

  void _validateIdentifyParameters(String id, String? email) {
    validateId(id);
    validateEmail(email);
  }

  Future<void> _performIdentify({
    required String id,
    String? name,
    String? email,
    Map<String, dynamic>? customData,
  }) async {
    try {
      await DitoSdkPlatform.instance.identify(
        id: id,
        name: name,
        email: email,
        customData: customData,
      );
    } on PlatformException catch (e) {
      throw mapNativeError(e);
    } catch (e) {
      throw mapNativeError(e);
    }
  }

  /// Tracks an event in Dito CRM.
  ///
  /// This method must be called after [initialize].
  ///
  /// Throws [PlatformException] with code [DitoError.notInitialized] if SDK is not initialized.
  /// Throws [PlatformException] with code [DitoError.invalidParameters] if [action] is null or empty.
  ///
  /// Example:
  /// ```dart
  /// final ditoSdk = DitoSdk();
  /// await ditoSdk.track(
  ///   action: 'purchase',
  ///   data: {'product': 'item123', 'price': 99.99},
  /// );
  /// ```
  Future<void> track({
    required String action,
    Map<String, dynamic>? data,
  }) async {
    _checkInitialized();
    _validateTrackParameters(action);
    await _performTrack(action: action, data: data);
  }

  void _validateTrackParameters(String action) {
    validateAction(action);
  }

  Future<void> _performTrack({
    required String action,
    Map<String, dynamic>? data,
  }) async {
    try {
      await DitoSdkPlatform.instance.track(
        action: action,
        data: data,
      );
    } on PlatformException catch (e) {
      throw mapNativeError(e);
    } catch (e) {
      throw mapNativeError(e);
    }
  }

  /// Registers a device token for push notifications.
  ///
  /// This method must be called after [initialize].
  ///
  /// Throws [PlatformException] with code [DitoError.notInitialized] if SDK is not initialized.
  /// Throws [PlatformException] with code [DitoError.invalidParameters] if [token] is null or empty.
  ///
  /// Example:
  /// ```dart
  /// final ditoSdk = DitoSdk();
  /// await ditoSdk.registerDeviceToken('fcm-device-token');
  /// ```
  Future<void> registerDeviceToken(String token) async {
    _checkInitialized();
    _validateTokenParameter(token);
    await _performRegisterDeviceToken(token);
  }

  void _validateTokenParameter(String token) {
    validateToken(token);
  }

  Future<void> _performRegisterDeviceToken(String token) async {
    try {
      await DitoSdkPlatform.instance.registerDeviceToken(token);
    } on PlatformException catch (e) {
      throw mapNativeError(e);
    } catch (e) {
      throw mapNativeError(e);
    }
  }

  /// Unregisters a device token for push notifications.
  ///
  /// This method must be called after [initialize].
  ///
  /// Throws [PlatformException] with code [DitoError.notInitialized] if SDK is not initialized.
  /// Throws [PlatformException] with code [DitoError.invalidParameters] if [token] is null or empty.
  ///
  /// Example:
  /// ```dart
  /// final ditoSdk = DitoSdk();
  /// await ditoSdk.unregisterDeviceToken('fcm-device-token');
  /// ```
  Future<void> unregisterDeviceToken(String token) async {
    _checkInitialized();
    _validateTokenParameter(token);
    await _performUnregisterDeviceToken(token);
  }

  Future<void> _performUnregisterDeviceToken(String token) async {
    try {
      await DitoSdkPlatform.instance.unregisterDeviceToken(token);
    } on PlatformException catch (e) {
      throw mapNativeError(e);
    } catch (e) {
      throw mapNativeError(e);
    }
  }

  /// Forwards a notification payload to the native SDK. Returns true if handled (e.g. channel DITO).
  Future<bool> handleNotificationReceived(Map<String, dynamic> userInfo) async {
    try {
      return await DitoSdkPlatform.instance.handleNotificationReceived(userInfo);
    } on PlatformException catch (e) {
      throw mapNativeError(e);
    } catch (e) {
      throw mapNativeError(e);
    }
  }

  /// Forwards a notification click payload to the native SDK (tracking and [onNotificationClick]).
  Future<bool> handleNotificationClick(Map<String, dynamic> userInfo) async {
    try {
      return await DitoSdkPlatform.instance.handleNotificationClick(userInfo);
    } on PlatformException catch (e) {
      throw mapNativeError(e);
    } catch (e) {
      throw mapNativeError(e);
    }
  }

  /// Sets push notification display options. May be called before or after [initialize].
  Future<void> setNotificationOptions(DitoNotificationOptions options) async {
    try {
      await DitoSdkPlatform.instance.setNotificationOptions(options);
    } on PlatformException catch (e) {
      throw mapNativeError(e);
    } catch (e) {
      throw mapNativeError(e);
    }
  }

  /// Returns notifications stored in the native local inbox.
  Future<List<DitoNotificationInfo>> getNotifications() async {
    try {
      return await DitoSdkPlatform.instance.getNotifications();
    } on PlatformException catch (e) {
      throw mapNativeError(e);
    } catch (e) {
      throw mapNativeError(e);
    }
  }

  /// Marks an inbox notification as read by [id] from [DitoNotificationInfo.id].
  Future<void> markNotificationAsRead(String id) async {
    try {
      await DitoSdkPlatform.instance.markNotificationAsRead(id);
    } on PlatformException catch (e) {
      throw mapNativeError(e);
    } catch (e) {
      throw mapNativeError(e);
    }
  }

  void _checkInitialized() {
    if (!_isInitialized) {
      throw createError(
        DitoError.notInitialized,
        'DitoSdk must be initialized before calling this method. Call initialize() first.',
      );
    }
  }
}
