import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'dito_sdk_method_channel.dart';

abstract class DitoSdkPlatform extends PlatformInterface {
  /// Constructs a DitoSdkPlatform.
  DitoSdkPlatform() : super(token: _token);

  static final Object _token = Object();

  static DitoSdkPlatform _instance = MethodChannelDitoSdk();

  /// The default instance of [DitoSdkPlatform] to use.
  ///
  /// Defaults to [MethodChannelDitoSdk].
  static DitoSdkPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [DitoSdkPlatform] when
  /// they register themselves.
  static set instance(DitoSdkPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<void> setDebugMode({required bool enabled}) {
    throw UnimplementedError('setDebugMode() has not been implemented.');
  }

  Future<void> initialize({
    required String appKey, required String appSecret,
  }) {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  Future<void> identify({
    required String id,
    String? name,
    String? email,
    Map<String, dynamic>? customData,
  }) {
    throw UnimplementedError('identify() has not been implemented.');
  }

  Future<void> track({
    required String action,
    Map<String, dynamic>? data,
  }) {
    throw UnimplementedError('track() has not been implemented.');
  }

  Future<void> registerDeviceToken(String token) {
    throw UnimplementedError('registerDeviceToken() has not been implemented.');
  }

  Future<void> unregisterDeviceToken(String token) {
    throw UnimplementedError('unregisterDeviceToken() has not been implemented.');
  }

  Future<bool> handleNotificationClick(Map<String, dynamic> userInfo) {
    throw UnimplementedError(
        'handleNotificationClick() has not been implemented.');
  }
}
