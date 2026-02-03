import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dito_sdk/dito_sdk.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'env_loader.dart';

class SampleAppState {
  SampleAppState({
    required void Function(void Function()) setState,
    required GlobalKey<ScaffoldMessengerState> scaffoldKey,
    required DitoSdk ditoSdk,
    String? initError,
  })  : _setState = setState,
        _scaffoldKey = scaffoldKey,
        ditoSdk = ditoSdk,
        status = initError != null
            ? 'Initialization failed: $initError'
            : 'Initialized successfully',
        isInitialized = initError == null;

  final void Function(void Function()) _setState;
  final GlobalKey<ScaffoldMessengerState> _scaffoldKey;

  final DitoSdk ditoSdk;

  String platformVersion = 'Unknown';
  String status;
  bool isInitialized;

  final TextEditingController apiKeyController = TextEditingController();
  final TextEditingController apiSecretController = TextEditingController();
  final TextEditingController userIdController = TextEditingController();
  final TextEditingController userNameController = TextEditingController();
  final TextEditingController userEmailController = TextEditingController();
  final TextEditingController userPhoneController = TextEditingController();
  final TextEditingController userAddressController = TextEditingController();
  final TextEditingController userCityController = TextEditingController();
  final TextEditingController userStateController = TextEditingController();
  final TextEditingController userZipController = TextEditingController();
  final TextEditingController userCountryController = TextEditingController();
  final TextEditingController eventNameController = TextEditingController();
  final TextEditingController tokenController = TextEditingController();

  String fcmDebugStatus = 'Checking...';
  int fcmPushReceivedCount = 0;
  StreamSubscription<String>? tokenRefreshSubscription;

  void loadEnvValues() {
    final identifyName = EnvLoader.getOrEmpty('IDENTIFY_NAME');
    final identifyEmail = EnvLoader.getOrEmpty('IDENTIFY_EMAIL');
    final identifyId = sha1.convert(utf8.encode(identifyEmail)).toString();

    _setState(() {
      apiKeyController.text = EnvLoader.getOrEmpty('API_KEY');
      apiSecretController.text = EnvLoader.getOrEmpty('API_SECRET');
      userIdController.text = identifyId;
      userNameController.text = identifyName;
      userEmailController.text = identifyEmail;
      userPhoneController.text = EnvLoader.getOrEmpty('USER_PHONE');
      userAddressController.text = EnvLoader.getOrEmpty('USER_ADDRESS');
      userCityController.text = EnvLoader.getOrEmpty('USER_CITY');
      userStateController.text = EnvLoader.getOrEmpty('USER_STATE');
      userZipController.text = EnvLoader.getOrEmpty('USER_ZIP');
      userCountryController.text = EnvLoader.getOrEmpty('USER_COUNTRY');
    });
  }

  Future<void> initPlatformVersion() async {
    try {
      final version = await ditoSdk.getPlatformVersion() ?? 'Unknown';
      _setState(() => platformVersion = version);
    } on PlatformException catch (e) {
      _setState(() => platformVersion = 'Failed: ${e.message}');
    }
  }

  Future<void> loadFcmToken() async {
    try {
      await FirebaseMessaging.instance.requestPermission();
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        tokenController.text = token;
        _setState(() => fcmDebugStatus = 'Ready (FCM token obtained)');
      }
      tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh
          .listen((newToken) {
        if (newToken.isNotEmpty) {
          _setState(() {
            tokenController.text = newToken;
            fcmDebugStatus = 'Ready (token refreshed)';
          });
        }
      });
    } on Exception catch (e, st) {
      if (kDebugMode) debugPrint('[PushDebug] loadFcmToken error: $e\n$st');
      _setState(() => fcmDebugStatus = 'Error: $e');
    }
  }

  Future<void> initFcmDebug() async {
    _setState(() => fcmDebugStatus = 'Checking...');
    try {
      if (Firebase.apps.isEmpty) {
        _setState(() => fcmDebugStatus = 'Error: Firebase not initialized');
        return;
      }
      final supported = await FirebaseMessaging.instance.isSupported();
      if (!supported) {
        _setState(() => fcmDebugStatus = 'Push not supported on this device');
        return;
      }
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (kDebugMode) {
        debugPrint('[PushDebug] requestPermission: ${settings.authorizationStatus}');
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        _setState(() => fcmDebugStatus = 'Ready (FCM token obtained)');
      } else {
        _setState(
          () => fcmDebugStatus =
              'Waiting for token (APNs may not have returned yet - check Xcode console for [PushDebug])',
        );
      }
    } on Exception catch (e, st) {
      if (kDebugMode) debugPrint('[PushDebug] initFcmDebug error: $e\n$st');
      _setState(() => fcmDebugStatus = 'Error: $e');
    }
  }

  void setupFcmMessageListeners(void Function() onPushReceived) {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        debugPrint('[PushDebug] Push reached app (foreground): messageId=${message.messageId}');
      }
      onPushReceived();
    });
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        debugPrint('[PushDebug] Push reached app (opened from notification): messageId=${message.messageId}');
      }
    });
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null && kDebugMode) {
        debugPrint('[PushDebug] Push reached app (launched from notification): messageId=${message.messageId}');
      }
    });
  }

  static bool validateEmail(String email) {
    if (email.isEmpty) return false;
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return emailRegex.hasMatch(email);
  }

  Future<void> identify() async {
    if (!isInitialized) {
      _showSnackBar('Please initialize SDK first', isError: true);
      return;
    }
    final userId = userIdController.text.trim();
    final email = userEmailController.text.trim();
    if (userId.isEmpty) {
      _showSnackBar('User ID is required', isError: true);
      return;
    }
    if (email.isNotEmpty && !validateEmail(email)) {
      _showSnackBar('Invalid email format', isError: true);
      return;
    }
    try {
      _log('identify start: $userId');
      final customData = <String, dynamic>{};
      final phone = userPhoneController.text.trim();
      if (phone.isNotEmpty) customData['phone'] = phone;
      final address = userAddressController.text.trim();
      if (address.isNotEmpty) customData['address'] = address;
      final city = userCityController.text.trim();
      if (city.isNotEmpty) customData['city'] = city;
      final state = userStateController.text.trim();
      if (state.isNotEmpty) customData['state'] = state;
      final zip = userZipController.text.trim();
      if (zip.isNotEmpty) customData['zip'] = zip;
      final country = userCountryController.text.trim();
      if (country.isNotEmpty) customData['country'] = country;

      await ditoSdk.identify(
        id: userId,
        name: userNameController.text.trim().isEmpty
            ? null
            : userNameController.text.trim(),
        email: email.isEmpty ? null : email,
        customData: customData.isEmpty ? null : customData,
      );
      _log('identify success: $userId');
      _showSnackBar('User identified successfully');
    } on PlatformException catch (e) {
      _log('identify error: ${e.code} ${e.message}');
      _showSnackBar('Error: ${e.message}', isError: true);
    }
  }

  Future<void> track() async {
    if (!isInitialized) {
      _showSnackBar('Please initialize SDK first', isError: true);
      return;
    }
    final eventName = eventNameController.text.trim();
    if (eventName.isEmpty) {
      _showSnackBar('Event name is required', isError: true);
      return;
    }
    try {
      _log('track start: $eventName');
      await ditoSdk.track(
        action: eventName,
        data: {
          'timestamp': DateTime.now().toIso8601String(),
          'platform': platformVersion,
        },
      );
      _log('track success: $eventName');
      _showSnackBar('Event tracked successfully');
    } on PlatformException catch (e) {
      _log('track error: ${e.code} ${e.message}');
      _showSnackBar('Error: ${e.message}', isError: true);
    }
  }

  Future<void> registerToken() async {
    if (!isInitialized) {
      _showSnackBar('Please initialize SDK first', isError: true);
      return;
    }
    final token = tokenController.text.trim();
    if (token.isEmpty) {
      _showSnackBar('Device token is required', isError: true);
      return;
    }
    try {
      _log('register token start');
      await ditoSdk.registerDeviceToken(token);
      _log('register token success');
      _showSnackBar('Device token registered successfully');
    } on PlatformException catch (e) {
      _log('register token error: ${e.code} ${e.message}');
      _showSnackBar('Error: ${e.message}', isError: true);
    }
  }

  Future<void> unregisterToken() async {
    if (!isInitialized) {
      _showSnackBar('Please initialize SDK first', isError: true);
      return;
    }
    final token = tokenController.text.trim();
    if (token.isEmpty) {
      _showSnackBar('Device token is required', isError: true);
      return;
    }
    try {
      _log('unregister token start');
      await ditoSdk.unregisterDeviceToken(token);
      _log('unregister token success');
      _showSnackBar('Device token unregistered successfully');
    } on PlatformException catch (e) {
      _log('unregister token error: ${e.code} ${e.message}');
      _showSnackBar('Error: ${e.message}', isError: true);
    }
  }

  void _log(String message) {
    debugPrint('[DitoSample] $message');
  }

  void _showSnackBar(String message, {bool isError = false}) {
    _scaffoldKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void dispose() {
    tokenRefreshSubscription?.cancel();
    apiKeyController.dispose();
    apiSecretController.dispose();
    userIdController.dispose();
    userNameController.dispose();
    userEmailController.dispose();
    userPhoneController.dispose();
    userAddressController.dispose();
    userCityController.dispose();
    userStateController.dispose();
    userZipController.dispose();
    userCountryController.dispose();
    eventNameController.dispose();
    tokenController.dispose();
  }
}
