import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dito_sdk/dito_sdk.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'env_loader.dart';

class SampleAppState {
  SampleAppState({
    required void Function(void Function()) setState,
    required GlobalKey<ScaffoldMessengerState> scaffoldKey,
    required this.ditoSdk,
    String? initError,
  })  : _setState = setState,
        _scaffoldKey = scaffoldKey,
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
  final TextEditingController smallIconController = TextEditingController();
  final TextEditingController largeIconController = TextEditingController();
  final TextEditingController soundController = TextEditingController();
  final TextEditingController accentColorController = TextEditingController();

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
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await FirebaseMessaging.instance.requestPermission();
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        tokenController.text = token;
        _setState(() => fcmDebugStatus = 'Ready (FCM token obtained)');
      } else {
        _setState(() => fcmDebugStatus = 'Waiting for FCM token');
      }
      tokenRefreshSubscription =
          FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
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

  void setupFcmMessageListeners(void Function() onPushReceived) {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        debugPrint(
          '[PushDebug] Push reached Dart (foreground): messageId=${message.messageId} dataKeys=${message.data.keys.toList()}',
        );
      }
      onPushReceived();
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

      final result = await ditoSdk.identify(
        id: userId,
        name: userNameController.text.trim().isEmpty
            ? null
            : userNameController.text.trim(),
        email: email.isEmpty ? null : email,
        customData: customData.isEmpty ? null : customData,
      );
      _showOperationFeedback(
        operation: _SampleOperation.identify,
        context: userId,
        feedback: _operationFeedback(_SampleOperation.identify, result),
      );
    } on PlatformException catch (e) {
      _showOperationFeedback(
        operation: _SampleOperation.identify,
        context: userId,
        feedback: _platformExceptionFeedback(_SampleOperation.identify, e),
      );
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
      final result = await ditoSdk.track(
        action: eventName,
        data: {
          'timestamp': DateTime.now().toIso8601String(),
          'platform': platformVersion,
        },
      );
      _showOperationFeedback(
        operation: _SampleOperation.track,
        context: eventName,
        feedback: _operationFeedback(_SampleOperation.track, result),
      );
    } on PlatformException catch (e) {
      _showOperationFeedback(
        operation: _SampleOperation.track,
        context: eventName,
        feedback: _platformExceptionFeedback(_SampleOperation.track, e),
      );
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
      final result = await ditoSdk.registerDeviceToken(token);
      _showOperationFeedback(
        operation: _SampleOperation.registerToken,
        feedback: _operationFeedback(_SampleOperation.registerToken, result),
      );
    } on PlatformException catch (e) {
      _showOperationFeedback(
        operation: _SampleOperation.registerToken,
        feedback: _platformExceptionFeedback(_SampleOperation.registerToken, e),
      );
    }
  }

  Future<void> applyNotificationOptions() async {
    try {
      final options = DitoNotificationOptions(
        accentColor: int.tryParse(accentColorController.text),
        largeIconResId: int.tryParse(largeIconController.text),
        smallIconResId: int.tryParse(smallIconController.text),
        soundResourceName:
            soundController.text.isEmpty ? null : soundController.text,
      );
      await ditoSdk.setNotificationOptions(options);
      _showSnackBar('Notification Options aplicadas');
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
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
      final result = await ditoSdk.unregisterDeviceToken(token);
      _showOperationFeedback(
        operation: _SampleOperation.unregisterToken,
        feedback: _operationFeedback(_SampleOperation.unregisterToken, result),
      );
    } on PlatformException catch (e) {
      _showOperationFeedback(
        operation: _SampleOperation.unregisterToken,
        feedback: _platformExceptionFeedback(_SampleOperation.unregisterToken, e),
      );
    }
  }

  void _log(String message) {
    debugPrint('[DitoSample] $message');
  }

  _OperationFeedback _operationFeedback(
    _SampleOperation operation,
    DitoOperationResult result,
  ) {
    switch (result.status) {
      case DitoOperationStatus.sent:
        return _OperationFeedback(
          message: operation.sentMessage,
          severity: _FeedbackSeverity.success,
        );
      case DitoOperationStatus.savedLocally:
        return _OperationFeedback(
          message: operation.savedLocallyMessage,
          severity: _FeedbackSeverity.warning,
        );
    }
  }

  _OperationFeedback _platformExceptionFeedback(
    _SampleOperation operation,
    PlatformException exception,
  ) {
    final reason = exception.message ?? exception.code;
    return _OperationFeedback(
      message: '${operation.failureLabel} failed: $reason',
      severity: _FeedbackSeverity.error,
    );
  }

  void _showOperationFeedback({
    required _SampleOperation operation,
    required _OperationFeedback feedback,
    String? context,
  }) {
    final logContext = context == null ? '' : ': $context';
    _log('${operation.logPrefix} ${feedback.message}$logContext');
    _showSnackBar(feedback.message, severity: feedback.severity);
  }

  void _showSnackBar(
    String message, {
    _FeedbackSeverity severity = _FeedbackSeverity.success,
    bool? isError,
  }) {
    final effectiveSeverity = isError == true ? _FeedbackSeverity.error : severity;
    _scaffoldKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _snackBarColor(effectiveSeverity),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Color _snackBarColor(_FeedbackSeverity severity) {
    switch (severity) {
      case _FeedbackSeverity.success:
        return Colors.green;
      case _FeedbackSeverity.warning:
        return Colors.orange;
      case _FeedbackSeverity.error:
        return Colors.red;
    }
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
    smallIconController.dispose();
    largeIconController.dispose();
    soundController.dispose();
    accentColorController.dispose();
  }
}

enum _FeedbackSeverity { success, warning, error }

enum _SampleOperation {
  identify(
    logPrefix: 'identify',
    sentMessage: 'Identify sent',
    savedLocallyMessage: 'Identify saved locally',
    failureLabel: 'Identify',
  ),
  track(
    logPrefix: 'track',
    sentMessage: 'Event sent',
    savedLocallyMessage: 'Event saved locally',
    failureLabel: 'Event',
  ),
  registerToken(
    logPrefix: 'register token',
    sentMessage: 'Device token sent',
    savedLocallyMessage: 'Device token saved locally',
    failureLabel: 'Device token registration',
  ),
  unregisterToken(
    logPrefix: 'unregister token',
    sentMessage: 'Device token removal sent',
    savedLocallyMessage: 'Device token removal saved locally',
    failureLabel: 'Device token removal',
  );

  const _SampleOperation({
    required this.logPrefix,
    required this.sentMessage,
    required this.savedLocallyMessage,
    required this.failureLabel,
  });

  final String logPrefix;
  final String sentMessage;
  final String savedLocallyMessage;
  final String failureLabel;
}

class _OperationFeedback {
  const _OperationFeedback({
    required this.message,
    required this.severity,
  });

  final String message;
  final _FeedbackSeverity severity;
}
