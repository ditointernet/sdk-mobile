export 'dito_notification_info.dart';
export 'dito_notification_listener.dart';
export 'dito_notification_options.dart';
export 'dito_operation_result.dart';

import 'package:flutter/services.dart';

import 'dito_notification_info.dart';
import 'dito_notification_listener.dart';
import 'dito_notification_options.dart';
import 'dito_operation_result.dart';
import 'dito_sdk_platform_interface.dart';
import 'error_handler.dart';
import 'parameter_validator.dart';

class DitoSdk {
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  static Stream<DitoNotificationClick> get onNotificationClick =>
      DitoNotificationListener.onNotificationClick;

  Future<String?> getPlatformVersion() {
    return DitoSdkPlatform.instance.getPlatformVersion();
  }

  Future<void> setDebugMode({required bool enabled}) async {
    try {
      await DitoSdkPlatform.instance.setDebugMode(enabled: enabled);
    } on PlatformException catch (e) {
      throw mapNativeError(e);
    } catch (e) {
      throw mapNativeError(e);
    }
  }

  /// Initializes the Dito SDK with the provided API credentials.
  ///
  /// This method must be called before using any other SDK methods.
  /// It configures the SDK with the provided [apiKey] and [apiSecret].
  ///
  /// Throws [PlatformException] with code [DitoError.invalidParameters] if
  /// [apiKey] or [apiSecret] are null or empty.
  ///
  /// Throws [PlatformException] with code [DitoError.initializationFailed] or
  /// [DitoError.invalidCredentials] if the SDK fails to initialize.
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   await DitoSdk.initialize(
  ///     apiKey: 'your-api-key',
  ///     apiSecret: 'your-api-secret',
  ///   );
  ///   print('SDK initialized successfully');
  /// } on PlatformException catch (e) {
  ///   print('Failed to initialize: ${e.message}');
  /// }
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
        appSecret: appSecret,
      );
      _isInitialized = true;
    } on PlatformException catch (e) {
      throw mapNativeError(e);
    } catch (e) {
      throw mapNativeError(e);
    }
  }

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
  /// await DitoSdk.identify(
  ///   id: 'user123',
  ///   name: 'John Doe',
  ///   email: 'john@example.com',
  ///   customData: {'type': 'premium', 'points': 1500},
  /// );
  /// ```
  Future<DitoOperationResult> identify({
    required String id,
    String? name,
    String? email,
    Map<String, dynamic>? customData,
  }) async {
    _checkInitialized();
    _validateIdentifyParameters(id, email);
    return _performIdentify(
      id: id,
      name: name,
      email: email,
      customData: customData,
    );
  }

  void _validateIdentifyParameters(String id, String? email) {
    validateId(id);
    validateEmail(email);
  }

  Future<DitoOperationResult> _performIdentify({
    required String id,
    String? name,
    String? email,
    Map<String, dynamic>? customData,
  }) async {
    try {
      return await DitoSdkPlatform.instance.identify(
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
  /// await DitoSdk.track(
  ///   action: 'purchase',
  ///   data: {'product': 'item123', 'price': 99.99},
  /// );
  /// ```
  Future<DitoOperationResult> track({
    required String action,
    Map<String, dynamic>? data,
  }) async {
    _checkInitialized();
    _validateTrackParameters(action);
    return _performTrack(action: action, data: data);
  }

  void _validateTrackParameters(String action) {
    validateAction(action);
  }

  Future<DitoOperationResult> _performTrack({
    required String action,
    Map<String, dynamic>? data,
  }) async {
    try {
      return await DitoSdkPlatform.instance.track(action: action, data: data);
    } on PlatformException catch (e) {
      throw mapNativeError(e);
    } catch (e) {
      throw mapNativeError(e);
    }
  }

  Future<void> logout() async {
    _checkInitialized();

    try {
      await DitoSdkPlatform.instance.logout();
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
  /// await DitoSdk.registerDeviceToken('fcm-device-token');
  /// ```
  Future<DitoOperationResult> registerDeviceToken(String token) async {
    _checkInitialized();
    _validateTokenParameter(token);
    return _performRegisterDeviceToken(token);
  }

  void _validateTokenParameter(String token) {
    validateToken(token);
  }

  Future<DitoOperationResult> _performRegisterDeviceToken(String token) async {
    try {
      return await DitoSdkPlatform.instance.registerDeviceToken(token);
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
  /// await DitoSdk.unregisterDeviceToken('fcm-device-token');
  /// ```
  Future<DitoOperationResult> unregisterDeviceToken(String token) async {
    _checkInitialized();
    _validateTokenParameter(token);
    return _performUnregisterDeviceToken(token);
  }

  Future<DitoOperationResult> _performUnregisterDeviceToken(
    String token,
  ) async {
    try {
      return await DitoSdkPlatform.instance.unregisterDeviceToken(token);
    } on PlatformException catch (e) {
      throw mapNativeError(e);
    } catch (e) {
      throw mapNativeError(e);
    }
  }

  Future<bool> handleNotificationClick(Map<String, dynamic> userInfo) async {
    try {
      return await DitoSdkPlatform.instance.handleNotificationClick(userInfo);
    } on PlatformException catch (e) {
      throw mapNativeError(e);
    } catch (e) {
      throw mapNativeError(e);
    }
  }

  Future<void> setNotificationOptions(DitoNotificationOptions options) async {
    try {
      await DitoSdkPlatform.instance.setNotificationOptions(options);
    } on PlatformException catch (e) {
      throw mapNativeError(e);
    } catch (e) {
      throw mapNativeError(e);
    }
  }

  Future<List<DitoNotificationInfo>> getNotifications() async {
    try {
      return await DitoSdkPlatform.instance.getNotifications();
    } on PlatformException catch (e) {
      throw mapNativeError(e);
    } catch (e) {
      throw mapNativeError(e);
    }
  }

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
