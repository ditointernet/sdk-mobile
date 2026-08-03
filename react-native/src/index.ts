import {
  NativeEventEmitter,
  NativeModules,
  type EmitterSubscription,
} from 'react-native';
import {
  validateApiKey,
  validateApiSecret,
  validateId,
  validateAction,
  validateToken,
  validateEmail,
} from './parameter_validator';
import { createError, mapNativeError, DitoErrorCode } from './error_handler';
import {
  NOTIFICATION_CLICK_EVENT,
  parseNotificationClick,
  parseNotificationInfo,
  type DitoNotificationClick,
  type DitoNotificationInfo,
} from './notification_events';

const { DitoSdkModule } = NativeModules;

if (!DitoSdkModule) {
  throw new Error(
    'DitoSdkModule native module is not available. Make sure you have properly linked the native module.',
  );
}

class DitoSdk {
  private static _isInitialized = false;
  private static _emitter: NativeEventEmitter | null = null;

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

  /**
   * Subscribes to notification clicks, including taps on rich push action buttons.
   *
   * This is the only place JavaScript can tell an action-button tap apart from a tap on
   * the notification body: on Android the button's `PendingIntent` targets the SDK's own
   * activity, so `onMessageOpenedApp` from a Firebase library never fires for it.
   *
   * Deliberately **not** gated on {@link initialize}: a tap on a notification cold-starts
   * the app, so the click can reach the native side before the app has had a chance to
   * initialize the SDK. Subscribe as early as possible — ideally at module scope or in the
   * root component — and pair this with {@link getInitialNotificationClick} for the click
   * that arrived before any listener existed.
   *
   * @param listener - Called once per click
   * @returns A subscription; call `remove()` to stop listening
   *
   * @example
   * ```typescript
   * const subscription = DitoSdk.onNotificationClick((click) => {
   *   if (isActionClick(click)) {
   *     console.log('button', click.actionId, 'opens', click.deeplink);
   *   }
   *   navigate(click.deeplink);
   * });
   * // later
   * subscription.remove();
   * ```
   */
  static onNotificationClick(
    listener: (click: DitoNotificationClick) => void,
  ): EmitterSubscription {
    return this._notificationEmitter().addListener(
      NOTIFICATION_CLICK_EVENT,
      (event: unknown) => listener(parseNotificationClick(event)),
    );
  }

  /**
   * Returns the click that opened the app, when there was no listener to receive it.
   *
   * The native side holds a click only while no JavaScript listener is attached, and
   * hands it over exactly once — so a click is delivered either here or through
   * {@link onNotificationClick}, never both and never twice. Returns `null` when the app
   * was not opened from a notification, or when the click already reached a listener.
   *
   * Same idea as `getInitialMessage()` in the Firebase libraries, and it is safe to call
   * before {@link initialize}.
   *
   * @example
   * ```typescript
   * const click = await DitoSdk.getInitialNotificationClick();
   * if (click) {
   *   navigate(click.deeplink);
   * }
   * ```
   */
  static async getInitialNotificationClick(): Promise<DitoNotificationClick | null> {
    try {
      const event = await DitoSdkModule.getInitialNotificationClick();
      return event ? parseNotificationClick(event) : null;
    } catch (error: any) {
      throw mapNativeError(error);
    }
  }

  /**
   * Lists the notifications stored in the SDK's local inbox, newest first.
   *
   * Each record carries the campaign's `image` and `customData`, so a rich push can be
   * rendered again from the inbox after the system notification is gone.
   *
   * @throws {DitoError} Throws error with code NOT_INITIALIZED if SDK is not initialized
   *
   * @example
   * ```typescript
   * const notifications = await DitoSdk.getNotifications();
   * ```
   */
  static async getNotifications(): Promise<DitoNotificationInfo[]> {
    this._checkInitialized();
    try {
      const records = await DitoSdkModule.getNotifications();
      return Array.isArray(records) ? records.map(parseNotificationInfo) : [];
    } catch (error: any) {
      throw mapNativeError(error);
    }
  }

  /**
   * Marks an inbox notification as read.
   *
   * @param id - Inbox record id, as returned by {@link getNotifications}
   * @throws {DitoError} Throws error with code NOT_INITIALIZED if SDK is not initialized
   * @throws {DitoError} Throws error with code INVALID_PARAMETERS if id is null or empty
   */
  static async markNotificationAsRead(id: string): Promise<void> {
    this._checkInitialized();
    validateId(id);
    try {
      await DitoSdkModule.markNotificationAsRead(id);
    } catch (error: any) {
      throw mapNativeError(error);
    }
  }

  /**
   * Emitter is built on first use, not at import time.
   *
   * `NativeEventEmitter` reaches into the native module as soon as it is constructed, and
   * this file is imported by apps that never touch notifications.
   */
  private static _notificationEmitter(): NativeEventEmitter {
    if (!this._emitter) {
      this._emitter = new NativeEventEmitter(DitoSdkModule);
    }
    return this._emitter;
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
export {
  NOTIFICATION_CLICK_EVENT,
  isActionClick,
  parseNotificationClick,
  parseNotificationInfo,
  readCustomDataField,
  type DitoNotificationClick,
  type DitoNotificationInfo,
} from './notification_events';
export {
  parsePushPayload,
  hasRichContent,
  MAX_PUSH_ACTIONS,
  type DitoPushAction,
  type DitoPushPayload,
} from './push_payload';
