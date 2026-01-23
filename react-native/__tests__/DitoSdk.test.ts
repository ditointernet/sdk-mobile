import DitoSdk, { DitoErrorCode } from '../src/index';
import { NativeModules } from 'react-native';

const mockNativeModule = {
  initialize: jest.fn(),
  identify: jest.fn(),
  track: jest.fn(),
  registerDeviceToken: jest.fn(),
};

jest.mock('react-native', () => {
  const RN = jest.requireActual('react-native');
  RN.NativeModules.DitoSdkModule = mockNativeModule;
  return RN;
});

describe('DitoSdk', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    (DitoSdk as any)._isInitialized = false;
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
