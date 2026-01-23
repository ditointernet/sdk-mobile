export enum DitoErrorCode {
  INITIALIZATION_FAILED = 'INITIALIZATION_FAILED',
  INVALID_CREDENTIALS = 'INVALID_CREDENTIALS',
  NOT_INITIALIZED = 'NOT_INITIALIZED',
  INVALID_PARAMETERS = 'INVALID_PARAMETERS',
  NETWORK_ERROR = 'NETWORK_ERROR',
}

export interface DitoError extends Error {
  code: DitoErrorCode;
  message: string;
  details?: any;
}

export function mapNativeError(error: any): DitoError {
  if (error?.code && Object.values(DitoErrorCode).includes(error.code)) {
    return {
      name: 'DitoError',
      code: error.code as DitoErrorCode,
      message: enhanceErrorMessage(error.code as DitoErrorCode, error.message || 'Unknown error'),
      details: error.details,
    };
  }

  return {
    name: 'DitoError',
    code: DitoErrorCode.NETWORK_ERROR,
    message: `Network error occurred: ${error?.message || String(error) || 'Unknown error'}. Please check your internet connection and try again.`,
    details: error,
  };
}

function enhanceErrorMessage(code: DitoErrorCode, originalMessage: string): string {
  switch (code) {
    case DitoErrorCode.INITIALIZATION_FAILED:
      return `Failed to initialize Dito SDK. ${originalMessage}. Please verify your API credentials and ensure the SDK is properly configured.`;
    case DitoErrorCode.INVALID_CREDENTIALS:
      return `Invalid API credentials provided. ${originalMessage}. Please check your apiKey and apiSecret and ensure they are correct.`;
    case DitoErrorCode.NOT_INITIALIZED:
      return `Dito SDK is not initialized. ${originalMessage}. Call DitoSdk.initialize() before using any other SDK methods.`;
    case DitoErrorCode.INVALID_PARAMETERS:
      return `Invalid parameters provided. ${originalMessage}. Please check the method documentation for required parameters.`;
    case DitoErrorCode.NETWORK_ERROR:
      return `Network error occurred. ${originalMessage}. Please check your internet connection and try again.`;
    default:
      return originalMessage || `An error occurred: ${code}. Please try again or contact support if the problem persists.`;
  }
}

export function createError(
  code: DitoErrorCode,
  message: string,
  details?: any,
): DitoError {
  return {
    name: 'DitoError',
    code,
    message,
    details,
  };
}
