import Combine
import DitoSDK
import Foundation
import UIKit

class NotificationDebugViewModel: ObservableObject {
    @Published var notifications: [[String: Any]] = []
    @Published var selectedNotification: [String: Any]?
    @Published var selectedJSON: String = "Selecione uma notificação para ver o conteúdo"
    @Published var showToast = false
    @Published var toastMessage = ""
    @Published var optSound: String = ""
    @Published var optSmallIcon: String = ""
    @Published var optAccentColor: String = ""

    var notificationCount: Int {
        notifications.count
    }

    init() {
        loadNotifications()
    }

    func loadNotifications() {
        notifications = NotificationDebugHelper.getAllNotifications()
    }

    func refresh() {
        loadNotifications()
        showToastMessage("Lista atualizada")
    }

    func selectLatest() {
        if let latest = NotificationDebugHelper.getLatestNotification() {
            selectNotification(latest)
        } else {
            showToastMessage("Nenhuma notificação salva")
        }
    }

    func selectNotification(_ notification: [String: Any]) {
        selectedNotification = notification
        selectedJSON = NotificationDebugHelper.readNotificationJSON(notification)
    }

    func copyJSON() {
        guard let notification = selectedNotification else { return }

        let jsonString = NotificationDebugHelper.readNotificationJSON(notification)
        UIPasteboard.general.string = jsonString
        showToastMessage("JSON copiado para área de transferência")
    }

    func simulate() {
        guard let notification = selectedNotification else { return }

        if let appDelegate = UIApplication.shared.delegate as? AppDelegate,
           let token = appDelegate.fcmToken {
            NotificationDebugHelper.simulateNotification(notification, token: token)
            showToastMessage("Notificação simulada com sucesso!")
        } else {
            showToastMessage("Token FCM não disponível")
        }
    }

    func applyNotificationOptions() {
        let options = DitoNotificationOptions(
            soundName: optSound.isEmpty ? nil : optSound
        )
        Dito.setNotificationOptions(options)
        showToastMessage("Notification Options aplicadas")
    }

    private func showToastMessage(_ message: String) {
        toastMessage = message
        showToast = true
    }
}
