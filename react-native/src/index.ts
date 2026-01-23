import { NativeModules } from 'react-native';
import {
  validateApiKey,
  validateApiSecret,
  validateId,
  validateAction,
  validateToken,
  validateEmail,
} from './parameter_validator';
import { createError, mapNativeError, DitoErrorCode } from './error_handler';

const { DitoSdkModule } = NativeModules;

if (!DitoSdkModule) {
  throw new Error(
    'DitoSdkModule native module is not available. Make sure you have properly linked the native module.',
  );
}

class DitoSdk {
  private static _isInitialized = false;

  static get isInitialized(): boolean {
    return this._isInitialized;
  }

  /**
   * Initializes the Dito SDK with the provided API credentials.
   *
   * This method must be called before using any other SDK methods.
   * It configures the SDK with the provided apiKey and apiSecret.
   *
   * @param options - Configuration options
   * @param options.apiKey - API key provided by Dito (required)
   * @param options.apiSecret - API secret provided by Dito (required)
   * @throws {DitoError} Throws error with code INVALID_PARAMETERS if apiKey or apiSecret are null or empty
   * @throws {DitoError} Throws error with code INITIALIZATION_FAILED or INVALID_CREDENTIALS if SDK fails to initialize
   *
   * @example
   * ```typescript
   * try {
   *   await DitoSdk.initialize({
   *     apiKey: 'your-api-key',
   *     apiSecret: 'your-api-secret',
   *   });
   *   console.log('SDK initialized successfully');
   * } catch (error) {
   *   console.error('Failed to initialize:', error.message);
   * }
   * ```
   */
  static async initialize(options: {
    apiKey: string;
    apiSecret: string;
  }): Promise<void> {
    validateApiKey(options.apiKey);
    validateApiSecret(options.apiSecret);

    try {
      await DitoSdkModule.initialize(options.apiKey, options.apiSecret);
      this._isInitialized = true;
    } catch (error: any) {
      const mappedError = mapNativeError(error);
      if (
        mappedError.code === DitoErrorCode.INITIALIZATION_FAILED ||
        mappedError.code === DitoErrorCode.INVALID_CREDENTIALS
      ) {
        throw mappedError;
      }
      throw mapNativeError(error);
    }
  }

  /**
   * Identifies a user in Dito CRM.
   *
   * This method must be called after initialize().
   *
   * @param options - User identification options
   * @param options.id - Unique user identifier (required)
   * @param options.name - User's name (optional)
   * @param options.email - User's email (optional, must be valid if provided)
   * @param options.customData - Additional custom data as object (optional)
   * @throws {DitoError} Throws error with code NOT_INITIALIZED if SDK is not initialized
   * @throws {DitoError} Throws error with code INVALID_PARAMETERS if id is null or empty, or email is invalid
   *
   * @example
   * ```typescript
   * await DitoSdk.identify({
   *   id: 'user123',
   *   name: 'John Doe',
   *   email: 'john@example.com',
   *   customData: { type: 'premium', points: 1500 },
   * });
   * ```
   */
  static async identify(options: {
    id: string;
    name?: string;
    email?: string;
    customData?: Record<string, any>;
  }): Promise<void> {
    this._checkInitialized();
    this._validateIdentifyParameters(options.id, options.email);
    await this._performIdentify(options);
  }

  private static _validateIdentifyParameters(
    id: string,
    email?: string,
  ): void {
    validateId(id);
    validateEmail(email);
  }

  private static async _performIdentify(options: {
    id: string;
    name?: string;
    email?: string;
    customData?: Record<string, any>;
  }): Promise<void> {
    try {
      await DitoSdkModule.identify(
        options.id,
        options.name || null,
        options.email || null,
        options.customData || null,
      );
    } catch (error: any) {
      throw mapNativeError(error);
    }
  }

  /**
   * Tracks an event in Dito CRM.
   *
   * This method must be called after initialize().
   *
   * @param options - Event tracking options
   * @param options.action - Event action name (required)
   * @param options.data - Additional event data as object (optional)
   * @throws {DitoError} Throws error with code NOT_INITIALIZED if SDK is not initialized
   * @throws {DitoError} Throws error with code INVALID_PARAMETERS if action is null or empty
   *
   * @example
   * ```typescript
   * await DitoSdk.track({
   *   action: 'purchase',
   *   data: { product: 'item123', price: 99.99 },
   * });
   * ```
   */
  static async track(options: {
    action: string;
    data?: Record<string, any>;
  }): Promise<void> {
    this._checkInitialized();
    this._validateTrackParameters(options.action);
    await this._performTrack(options);
  }

  private static _validateTrackParameters(action: string): void {
    validateAction(action);
  }

  private static async _performTrack(options: {
    action: string;
    data?: Record<string, any>;
  }): Promise<void> {
    try {
      await DitoSdkModule.track(options.action, options.data || null);
    } catch (error: any) {
      throw mapNativeError(error);
    }
  }

  /**
   * Registers a device token for push notifications.
   *
   * This method must be called after initialize().
   *
   * @param token - Device token for push notifications (required)
   * @throws {DitoError} Throws error with code NOT_INITIALIZED if SDK is not initialized
   * @throws {DitoError} Throws error with code INVALID_PARAMETERS if token is null or empty
   *
   * @example
   * ```typescript
   * await DitoSdk.registerDeviceToken('fcm-device-token');
   * ```
   */
  static async registerDeviceToken(token: string): Promise<void> {
    this._checkInitialized();
    this._validateRegisterDeviceTokenParameters(token);
    await this._performRegisterDeviceToken(token);
  }

  private static _validateRegisterDeviceTokenParameters(token: string): void {
    validateToken(token);
  }

  private static async _performRegisterDeviceToken(
    token: string,
  ): Promise<void> {
    try {
      await DitoSdkModule.registerDeviceToken(token);
    } catch (error: any) {
      throw mapNativeError(error);
    }
  }

  /**
   * Unregisters a device token for push notifications.
   *
   * This method must be called after initialize().
   *
   * @param token - Device token for push notifications (required)
   * @throws {DitoError} Throws error with code NOT_INITIALIZED if SDK is not initialized
   * @throws {DitoError} Throws error with code INVALID_PARAMETERS if token is null or empty
   *
   * @example
   * ```typescript
   * await DitoSdk.unregisterDeviceToken('fcm-device-token');
   * ```
   */
  static async unregisterDeviceToken(token: string): Promise<void> {
    this._checkInitialized();
    this._validateUnregisterDeviceTokenParameters(token);
    await this._performUnregisterDeviceToken(token);
  }

  private static _validateUnregisterDeviceTokenParameters(token: string): void {
    validateToken(token);
  }

  private static async _performUnregisterDeviceToken(
    token: string,
  ): Promise<void> {
    try {
      await DitoSdkModule.unregisterDeviceToken(token);
    } catch (error: any) {
      throw mapNativeError(error);
    }
  }

  private static _checkInitialized(): void {
    if (!this._isInitialized) {
      throw createError(
        DitoErrorCode.NOT_INITIALIZED,
        'DitoSdk must be initialized before calling this method. Call initialize() first.',
      );
    }
  }
}

export default DitoSdk;
export { DitoErrorCode, type DitoError } from './error_handler';
