import fs from 'fs';
import path from 'path';

describe('Push Notification Integration', () => {
  const androidModulePath = path.join(
    __dirname,
    '../android/src/main/java/br/com/dito/DitoSdkModule.kt',
  );
  const iosBridgePath = path.join(__dirname, '../ios/DitoSdkModule.m');
  const iosModulePath = path.join(__dirname, '../ios/DitoSdkModule.swift');

  it('should expose native notification inbox bridge methods on Android and iOS', () => {
    // Arrange
    const androidModule = fs.readFileSync(androidModulePath, 'utf8');
    const iosBridge = fs.readFileSync(iosBridgePath, 'utf8');
    const iosModule = fs.readFileSync(iosModulePath, 'utf8');

    // Act & Assert
    expect(androidModule).toContain('@ReactMethod\n    fun getNotifications');
    expect(androidModule).toContain('@ReactMethod\n    fun markNotificationAsRead');
    expect(iosBridge).toContain('RCT_EXTERN_METHOD(getNotifications');
    expect(iosBridge).toContain('RCT_EXTERN_METHOD(markNotificationAsRead');
    expect(iosModule).toContain('func getNotifications');
    expect(iosModule).toContain('func markNotificationAsRead');
  });

  it('should expose native notification click and deeplink bridge methods on Android and iOS', () => {
    // Arrange
    const androidModule = fs.readFileSync(androidModulePath, 'utf8');
    const iosBridge = fs.readFileSync(iosBridgePath, 'utf8');
    const iosModule = fs.readFileSync(iosModulePath, 'utf8');

    // Act & Assert
    expect(androidModule).toContain('private const val NOTIFICATION_CLICK_EVENT = "DitoNotificationClick"');
    expect(androidModule).toContain('@ReactMethod\n    fun handleNotificationClick');
    expect(iosBridge).toContain('RCT_EXTERN_METHOD(handleNotificationClick');
    expect(iosModule).toContain('private static let notificationClickEvent = "DitoNotificationClick"');
    expect(iosModule).toContain('func handleNotificationClick');
  });
});
