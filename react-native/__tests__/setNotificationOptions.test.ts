import { NativeModules } from 'react-native';
import DitoSdk from '../src/index';

jest.mock('react-native', () => {
  const RN = jest.requireActual('react-native');
  RN.NativeModules.DitoSdkModule = {
    initialize: jest.fn(),
    identify: jest.fn(),
    track: jest.fn(),
    registerDeviceToken: jest.fn(),
    setNotificationOptions: jest.fn(),
  };
  return RN;
});

describe('DitoSdk.setNotificationOptions', () => {
  const nativeSetNotificationOptions =
    NativeModules.DitoSdkModule.setNotificationOptions as jest.Mock;

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('should call native module with badgeEnabled=false when explicitly set', async () => {
    // Arrange
    nativeSetNotificationOptions.mockResolvedValue(undefined);

    // Act
    await DitoSdk.setNotificationOptions({ badgeEnabled: false });

    // Assert
    expect(nativeSetNotificationOptions).toHaveBeenCalledWith({
      badgeEnabled: false,
    });
  });

  it('should call native module with badgeEnabled=true when not provided', async () => {
    // Arrange
    nativeSetNotificationOptions.mockResolvedValue(undefined);

    // Act
    await DitoSdk.setNotificationOptions({});

    // Assert
    expect(nativeSetNotificationOptions).toHaveBeenCalledWith({
      badgeEnabled: true,
    });
  });

  it('should call native module with soundResourceName and default badgeEnabled=true', async () => {
    // Arrange
    nativeSetNotificationOptions.mockResolvedValue(undefined);

    // Act
    await DitoSdk.setNotificationOptions({ soundResourceName: 'ping' });

    // Assert
    expect(nativeSetNotificationOptions).toHaveBeenCalledWith({
      soundResourceName: 'ping',
      badgeEnabled: true,
    });
  });

  it('should serialize all Android 3.4.0 and iOS 3.3.1 notification options', async () => {
    // Arrange
    nativeSetNotificationOptions.mockResolvedValue(undefined);

    // Act
    await DitoSdk.setNotificationOptions({
      accentColor: 0xff0055,
      badgeEnabled: false,
      largeIconResId: 456,
      smallIconResId: 123,
      soundResourceName: 'notification_sound',
    });

    // Assert
    expect(nativeSetNotificationOptions).toHaveBeenCalledWith({
      accentColor: 0xff0055,
      badgeEnabled: false,
      largeIconResId: 456,
      smallIconResId: 123,
      soundResourceName: 'notification_sound',
    });
  });

  it('should propagate native errors', async () => {
    // Arrange
    nativeSetNotificationOptions.mockRejectedValue({
      code: 'UNKNOWN_ERROR',
      message: 'Native error',
    });

    // Act & Assert
    await expect(DitoSdk.setNotificationOptions({})).rejects.toBeDefined();
  });
});
