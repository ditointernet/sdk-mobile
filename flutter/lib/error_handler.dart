import 'package:flutter/services.dart';

class DitoError {
  static const String initializationFailed = 'INITIALIZATION_FAILED';
  static const String invalidCredentials = 'INVALID_CREDENTIALS';
  static const String notInitialized = 'NOT_INITIALIZED';
  static const String invalidParameters = 'INVALID_PARAMETERS';
  static const String networkError = 'NETWORK_ERROR';
}

PlatformException mapNativeError(dynamic error) {
  if (error is PlatformException) {
    return PlatformException(
      code: error.code,
      message: _enhanceErrorMessage(error.code, error.message ?? ''),
      details: error.details,
      stacktrace: error.stacktrace,
    );
  }

  if (error is MissingPluginException) {
    return PlatformException(
      code: DitoError.initializationFailed,
      message:
          'Missing plugin implementation. Rebuild the app so native changes are compiled (flutter clean, flutter pub get, reinstall).',
    );
  }

  if (error is Exception) {
    return PlatformException(
      code: DitoError.networkError,
      message: 'Network error occurred: ${error.toString()}. Please check your internet connection and try again.',
    );
  }

  return PlatformException(
    code: DitoError.networkError,
    message: 'An unexpected error occurred: $error. Please try again or contact support if the problem persists.',
  );
}

String _enhanceErrorMessage(String code, String originalMessage) {
  switch (code) {
    case DitoError.initializationFailed:
      return 'Failed to initialize Dito SDK. $originalMessage. Please verify your API credentials and ensure the SDK is properly configured.';
    case DitoError.invalidCredentials:
      return 'Invalid API credentials provided. $originalMessage. Please check your apiKey and apiSecret and ensure they are correct.';
    case DitoError.notInitialized:
      return 'Dito SDK is not initialized. $originalMessage. Call DitoSdk.initialize() before using any other SDK methods.';
    case DitoError.invalidParameters:
      return 'Invalid parameters provided. $originalMessage. Please check the method documentation for required parameters.';
    case DitoError.networkError:
      return 'Network error occurred. $originalMessage. Please check your internet connection and try again.';
    default:
      return originalMessage.isNotEmpty
          ? originalMessage
          : 'An error occurred: $code. Please try again or contact support if the problem persists.';
  }
}

PlatformException createError(String code, String message) {
  return PlatformException(
    code: code,
    message: message,
  );
}
