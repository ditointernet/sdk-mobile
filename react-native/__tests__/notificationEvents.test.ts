const mockAddListener = jest.fn();
const mockNativeEventEmitterConstructor = jest.fn();
const mockNativeModule = {
  addListener: jest.fn(),
  removeListeners: jest.fn(),
};
const mockSubscription = {
  remove: jest.fn(),
};

jest.mock('react-native', () => ({
  NativeEventEmitter: jest.fn().mockImplementation((nativeModule) => {
    mockNativeEventEmitterConstructor(nativeModule);
    return {
      addListener: mockAddListener,
    };
  }),
  NativeModules: {
    DitoSdkModule: mockNativeModule,
  },
}));

const DitoSdk = require('../src/index').default;
const {
  default: DitoNotificationListener,
  NOTIFICATION_CLICK_EVENT,
} = require('../src/DitoNotificationListener');

describe('notification click events', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockAddListener.mockReturnValue(mockSubscription);
  });

  it('should subscribe to native click and deeplink events through DitoSdk', () => {
    // Arrange
    const listener = jest.fn();

    // Act
    const subscription = DitoSdk.addNotificationClickListener(listener);

    // Assert
    expect(mockNativeEventEmitterConstructor).toHaveBeenCalledWith(mockNativeModule);
    expect(mockAddListener).toHaveBeenCalledWith(NOTIFICATION_CLICK_EVENT, listener);
    expect(subscription).toBe(mockSubscription);
  });

  it('should deliver the native notification click contract to the listener', () => {
    // Arrange
    const listener = jest.fn();
    const event = {
      deeplink: 'app://notification',
      logId: 'log-123',
      notificationId: 'notification-123',
      notificationName: 'Campaign',
      reference: 'user-123',
      userId: 'user-123',
    };

    // Act
    DitoNotificationListener.addNotificationClickListener(listener);
    const registeredListener = mockAddListener.mock.calls[0][1];
    registeredListener(event);

    // Assert
    expect(listener).toHaveBeenCalledWith(event);
  });
});
