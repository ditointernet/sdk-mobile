import UserNotifications
import XCTest

@testable import DitoSDK

class DitoNotificationOptionsTests: XCTestCase {

    func testMakeNotificationContent_WithSoundName_UsesCustomSound() {
        // Arrange
        let notification = DitoNotification()
        notification.options = DitoNotificationOptions(soundName: "alert")

        // Act
        let content = notification.makeNotificationContent(title: "Title", body: "Body")

        // Assert
        XCTAssertEqual(content.sound, UNNotificationSound(named: UNNotificationSoundName("alert")))
    }

    func testMakeNotificationContent_WithoutSoundName_UsesDefaultSound() {
        // Arrange
        let notification = DitoNotification()
        notification.options = DitoNotificationOptions(soundName: nil)

        // Act
        let content = notification.makeNotificationContent(title: "Title", body: "Body")

        // Assert
        XCTAssertEqual(content.sound, UNNotificationSound.default)
    }

    func testMakeNotificationContent_SetsCorrectTitleAndBody() {
        // Arrange
        let notification = DitoNotification()

        // Act
        let content = notification.makeNotificationContent(title: "Test Title", body: "Test Body")

        // Assert
        XCTAssertEqual(content.title, "Test Title")
        XCTAssertEqual(content.body, "Test Body")
    }

    func testDitoNotificationOptions_DefaultValues() {
        // Arrange & Act
        let options = DitoNotificationOptions()

        // Assert
        XCTAssertNil(options.soundName)
        XCTAssertTrue(options.badgeEnabled)
    }

    func testDitoNotificationOptions_CustomValues() {
        // Arrange & Act
        let options = DitoNotificationOptions(soundName: "custom_sound", badgeEnabled: false)

        // Assert
        XCTAssertEqual(options.soundName, "custom_sound")
        XCTAssertFalse(options.badgeEnabled)
    }

    func testNotificationRead_BadgeEnabled_CallsBadgeUpdaterWithIncrement() {
        // Arrange
        let notification = DitoNotification()
        notification.options = DitoNotificationOptions(badgeEnabled: true)
        var capturedDelta: Int?
        notification.badgeUpdater = { delta in capturedDelta = delta }

        // Act
        notification.notificationRead(with: [:])

        // Assert
        XCTAssertEqual(capturedDelta, +1)
    }

    func testNotificationClick_BadgeEnabled_CallsBadgeUpdaterWithDecrement() {
        // Arrange
        let notification = DitoNotification()
        notification.options = DitoNotificationOptions(badgeEnabled: true)
        var capturedDelta: Int?
        notification.badgeUpdater = { delta in capturedDelta = delta }

        // Act
        notification.notificationClick(notificationId: "abc", reference: "ref", identifier: "id")

        // Assert
        XCTAssertEqual(capturedDelta, -1)
    }

    func testNotificationRead_BadgeDisabled_DoesNotCallBadgeUpdater() {
        // Arrange
        let notification = DitoNotification()
        notification.options = DitoNotificationOptions(badgeEnabled: false)
        var updaterCalled = false
        notification.badgeUpdater = { _ in updaterCalled = true }

        // Act
        notification.notificationRead(with: [:])

        // Assert
        XCTAssertFalse(updaterCalled)
    }

    func testNotificationClick_BadgeDisabled_DoesNotCallBadgeUpdater() {
        // Arrange
        let notification = DitoNotification()
        notification.options = DitoNotificationOptions(badgeEnabled: false)
        var updaterCalled = false
        notification.badgeUpdater = { _ in updaterCalled = true }

        // Act
        notification.notificationClick(notificationId: "abc", reference: "ref", identifier: "id")

        // Assert
        XCTAssertFalse(updaterCalled)
    }
}
