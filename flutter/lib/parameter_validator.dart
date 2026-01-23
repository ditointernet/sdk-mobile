import 'error_handler.dart';
import 'package:flutter/services.dart';

void validateApiKey(String? apiKey) {
  if (apiKey == null || apiKey.isEmpty) {
    throw createError(
      DitoError.invalidParameters,
      'apiKey is required and cannot be empty',
    );
  }
}

void validateApiSecret(String? apiSecret) {
  if (apiSecret == null || apiSecret.isEmpty) {
    throw createError(
      DitoError.invalidParameters,
      'apiSecret is required and cannot be empty',
    );
  }
}

void validateId(String? id) {
  if (id == null || id.isEmpty) {
    throw createError(
      DitoError.invalidParameters,
      'id is required and cannot be empty',
    );
  }
}

void validateEmail(String? email) {
  if (email != null && email.isNotEmpty) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(email)) {
      throw createError(
        DitoError.invalidParameters,
        'email must be a valid email address',
      );
    }
  }
}

void validateAction(String? action) {
  if (action == null || action.isEmpty) {
    throw createError(
      DitoError.invalidParameters,
      'action is required and cannot be empty',
    );
  }
}

void validateToken(String? token) {
  if (token == null || token.isEmpty) {
    throw createError(
      DitoError.invalidParameters,
      'token is required and cannot be empty',
    );
  }
}
