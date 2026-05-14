const mockNativeModule = {
  addListener: jest.fn(),
  getNotifications: jest.fn(),
  handleNotificationClick: jest.fn(),
  initialize: jest.fn(),
  initializeWithApiKey: jest.fn(),
  identify: jest.fn(),
  logout: jest.fn(),
  markNotificationAsRead: jest.fn(),
  registerDeviceToken: jest.fn(),
  removeListeners: jest.fn(),
  setNotificationOptions: jest.fn(),
  track: jest.fn(),
  unregisterDeviceToken: jest.fn(),
};

jest.mock('react-native', () => {
  const RN = jest.requireActual('react-native');
  RN.NativeModules.DitoSdkModule = mockNativeModule;
  return RN;
});

const { NativeModules } = require('react-native');
const DitoModule = require('../src/index');
const DitoSdk = DitoModule.default;
const { DitoErrorCode } = DitoModule;

describe('DitoSdk', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    (DitoSdk as any)._isInitialized = false;
  });

  describe('public API', () => {
    it('should expose compatible public methods and notification types', () => {
      // Arrange
      const publicMethods = [
        'addNotificationClickListener',
        'getNotifications',
        'handleNotificationClick',
        'identify',
        'initialize',
        'initializeWithApiKey',
        'logout',
        'markNotificationAsRead',
        'registerDeviceToken',
        'setNotificationOptions',
        'track',
        'unregisterDeviceToken',
      ];

      // Act & Assert
      publicMethods.forEach((method) => {
        expect(typeof DitoSdk[method]).toBe('function');
      });
      expect(DitoModule.DitoNotificationListener).toBeDefined();
    });
  });

  describe('initialize', () => {
    it('should initialize successfully with valid credentials', async () => {
      mockNativeModule.initialize.mockResolvedValue(undefined);

      await DitoSdk.initialize({
        apiKey: 'test-api-key',
        apiSecret: 'test-api-secret',
      });

      expect(mockNativeModule.initialize).toHaveBeenCalledWith(
        'test-api-key',
        'test-api-secret',
      );
      expect(DitoSdk.isInitialized).toBe(true);
    });

    it('should throw NOT_INITIALIZED error when methods called before initialization', async () => {
      (DitoSdk as any)._isInitialized = false;

      await expect(
        DitoSdk.identify({
          id: 'user123',
        }),
      ).rejects.toMatchObject({
        code: DitoErrorCode.NOT_INITIALIZED,
      });
    });

    it('should throw INVALID_PARAMETERS error with empty apiKey', async () => {
      await expect(
        DitoSdk.initialize({
          apiKey: '',
          apiSecret: 'secret',
        }),
      ).rejects.toMatchObject({
        code: DitoErrorCode.INVALID_PARAMETERS,
      });
    });

    it('should throw INVALID_PARAMETERS error with empty apiSecret', async () => {
      await expect(
        DitoSdk.initialize({
          apiKey: 'key',
          apiSecret: '',
        }),
      ).rejects.toMatchObject({
        code: DitoErrorCode.INVALID_PARAMETERS,
      });
    });
  });

  describe('initializeWithApiKey', () => {
    it('should initialize successfully with apiKey and bundleId', async () => {
      mockNativeModule.initializeWithApiKey.mockResolvedValue(undefined);

      await DitoSdk.initializeWithApiKey({
        apiKey: 'test-api-key',
        bundleId: 'br.com.dito.app',
      });

      expect(mockNativeModule.initializeWithApiKey).toHaveBeenCalledWith(
        'test-api-key',
        'br.com.dito.app',
      );
      expect(DitoSdk.isInitialized).toBe(true);
    });
  });

  describe('identify', () => {
    it('should identify user successfully', async () => {
      mockNativeModule.initialize.mockResolvedValue(undefined);
      mockNativeModule.identify.mockResolvedValue(undefined);

      await DitoSdk.initialize({
        apiKey: 'test-api-key',
        apiSecret: 'test-api-secret',
      });

      await DitoSdk.identify({
        id: 'user123',
        name: 'John Doe',
        email: 'john@example.com',
        customData: { type: 'premium' },
      });

      expect(mockNativeModule.identify).toHaveBeenCalledWith(
        'user123',
        'John Doe',
        'john@example.com',
        { type: 'premium' },
      );
    });
  });

  describe('track', () => {
    it('should track event successfully', async () => {
      mockNativeModule.initialize.mockResolvedValue(undefined);
      mockNativeModule.track.mockResolvedValue(undefined);

      await DitoSdk.initialize({
        apiKey: 'test-api-key',
        apiSecret: 'test-api-secret',
      });

      await DitoSdk.track({
        action: 'purchase',
        data: { product: 'item123', price: 99.99 },
      });

      expect(mockNativeModule.track).toHaveBeenCalledWith(
        'purchase',
        { product: 'item123', price: 99.99 },
      );
    });
  });

  describe('logout', () => {
    it('should throw NOT_INITIALIZED error before initialization', async () => {
      await expect(DitoSdk.logout()).rejects.toMatchObject({
        code: DitoErrorCode.NOT_INITIALIZED,
      });
      expect(mockNativeModule.logout).not.toHaveBeenCalled();
    });

    it('should call native module without payload', async () => {
      mockNativeModule.initialize.mockResolvedValue(undefined);
      mockNativeModule.logout.mockResolvedValue(undefined);

      await DitoSdk.initialize({
        apiKey: 'test-api-key',
        apiSecret: 'test-api-secret',
      });
      await DitoSdk.logout();

      expect(mockNativeModule.logout).toHaveBeenCalledTimes(1);
      expect(mockNativeModule.logout).toHaveBeenCalledWith();
    });
  });

  describe('registerDeviceToken', () => {
    it('should register device token successfully', async () => {
      mockNativeModule.initialize.mockResolvedValue(undefined);
      mockNativeModule.registerDeviceToken.mockResolvedValue(undefined);

      await DitoSdk.initialize({
        apiKey: 'test-api-key',
        apiSecret: 'test-api-secret',
      });

      await DitoSdk.registerDeviceToken('test-device-token');

      expect(mockNativeModule.registerDeviceToken).toHaveBeenCalledWith(
        'test-device-token',
      );
    });
  });

  describe('handleNotificationClick', () => {
    it('should forward notification click payload to native module', async () => {
      mockNativeModule.handleNotificationClick.mockResolvedValue(true);

      const handled = await DitoSdk.handleNotificationClick({
        channel: 'DITO',
        link: 'app://notification',
        notification: 'notification-123',
        reference: 'user-123',
      });

      expect(handled).toBe(true);
      expect(mockNativeModule.handleNotificationClick).toHaveBeenCalledWith({
        channel: 'DITO',
        link: 'app://notification',
        notification: 'notification-123',
        reference: 'user-123',
      });
    });
  });

  describe('notification inbox', () => {
    it('should return notifications from native inbox', async () => {
      // Arrange
      mockNativeModule.initialize.mockResolvedValue(undefined);
      mockNativeModule.getNotifications.mockResolvedValue([
        {
          id: 'inbox-1',
          notificationId: 'notification-123',
          reference: 'user-123',
          title: 'Title',
          message: 'Message',
          link: 'app://notification',
          receivedAt: 1710000000000,
          isRead: false,
        },
      ]);

      // Act
      await DitoSdk.initialize({
        apiKey: 'test-api-key',
        apiSecret: 'test-api-secret',
      });
      const notifications = await DitoSdk.getNotifications();

      // Assert
      expect(mockNativeModule.getNotifications).toHaveBeenCalledTimes(1);
      expect(notifications).toEqual([
        {
          id: 'inbox-1',
          notificationId: 'notification-123',
          reference: 'user-123',
          title: 'Title',
          message: 'Message',
          link: 'app://notification',
          receivedAt: 1710000000000,
          isRead: false,
        },
      ]);
    });

    it('should mark notification as read through native inbox', async () => {
      // Arrange
      mockNativeModule.initialize.mockResolvedValue(undefined);
      mockNativeModule.markNotificationAsRead.mockResolvedValue(undefined);

      // Act
      await DitoSdk.initialize({
        apiKey: 'test-api-key',
        apiSecret: 'test-api-secret',
      });
      await DitoSdk.markNotificationAsRead('inbox-1');

      // Assert
      expect(mockNativeModule.markNotificationAsRead).toHaveBeenCalledWith('inbox-1');
    });
  });

  describe('error handling', () => {
    it('should provide enhanced error message for INITIALIZATION_FAILED', async () => {
      mockNativeModule.initialize.mockRejectedValue({
        code: DitoErrorCode.INITIALIZATION_FAILED,
        message: 'SDK initialization failed',
      });

      try {
        await DitoSdk.initialize({
          apiKey: 'test-api-key',
          apiSecret: 'test-api-secret',
        });
        fail('Should have thrown error');
      } catch (error: any) {
        expect(error.code).toBe(DitoErrorCode.INITIALIZATION_FAILED);
        expect(error.message).toContain('Failed to initialize Dito SDK');
        expect(error.message).toContain('verify your API credentials');
      }
    });

    it('should provide enhanced error message for NETWORK_ERROR', async () => {
      mockNativeModule.initialize.mockResolvedValue(undefined);
      mockNativeModule.identify.mockRejectedValue({
        code: DitoErrorCode.NETWORK_ERROR,
        message: 'Connection timeout',
      });

      await DitoSdk.initialize({
        apiKey: 'test-api-key',
        apiSecret: 'test-api-secret',
      });

      try {
        await DitoSdk.identify({ id: 'user123' });
        fail('Should have thrown error');
      } catch (error: any) {
        expect(error.code).toBe(DitoErrorCode.NETWORK_ERROR);
        expect(error.message).toContain('Network error occurred');
        expect(error.message).toContain('check your internet connection');
      }
    });

    it('should provide enhanced error message for INVALID_CREDENTIALS', async () => {
      mockNativeModule.initialize.mockRejectedValue({
        code: DitoErrorCode.INVALID_CREDENTIALS,
        message: 'Invalid API key',
      });

      try {
        await DitoSdk.initialize({
          apiKey: 'invalid-key',
          apiSecret: 'invalid-secret',
        });
        fail('Should have thrown error');
      } catch (error: any) {
        expect(error.code).toBe(DitoErrorCode.INVALID_CREDENTIALS);
        expect(error.message).toContain('Invalid API credentials');
        expect(error.message).toContain('check your apiKey and apiSecret');
      }
    });
  });
});
