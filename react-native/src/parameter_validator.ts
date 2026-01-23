import { createError, DitoErrorCode } from './error_handler';

export function validateApiKey(apiKey: string | null | undefined): void {
  if (!apiKey || apiKey.trim().length === 0) {
    throw createError(
      DitoErrorCode.INVALID_PARAMETERS,
      'apiKey is required and cannot be empty',
    );
  }
}

export function validateApiSecret(apiSecret: string | null | undefined): void {
  if (!apiSecret || apiSecret.trim().length === 0) {
    throw createError(
      DitoErrorCode.INVALID_PARAMETERS,
      'apiSecret is required and cannot be empty',
    );
  }
}

export function validateId(id: string | null | undefined): void {
  if (!id || id.trim().length === 0) {
    throw createError(
      DitoErrorCode.INVALID_PARAMETERS,
      'id is required and cannot be empty',
    );
  }
}

export function validateEmail(email: string | null | undefined): void {
  if (email && email.trim().length > 0) {
    const emailRegex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
    if (!emailRegex.test(email)) {
      throw createError(
        DitoErrorCode.INVALID_PARAMETERS,
        'email must be a valid email address',
      );
    }
  }
}

export function validateAction(action: string | null | undefined): void {
  if (!action || action.trim().length === 0) {
    throw createError(
      DitoErrorCode.INVALID_PARAMETERS,
      'action is required and cannot be empty',
    );
  }
}

export function validateToken(token: string | null | undefined): void {
  if (!token || token.trim().length === 0) {
    throw createError(
      DitoErrorCode.INVALID_PARAMETERS,
      'token is required and cannot be empty',
    );
  }
}
