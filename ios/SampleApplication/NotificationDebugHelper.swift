import Foundation
import DitoSDK

class NotificationDebugHelper {

    private static let debugDirName = "dito_notifications_debug"
    private static let maxFiles = 10

    /// Salva o payload de uma notificação recebida
    static func saveNotification(_ userInfo: [AnyHashable: Any]) {
        do {
            let debugDir = getDebugDirectory()
            try FileManager.default.createDirectory(at: debugDir, withIntermediateDirectories: true)

            let timestamp = DateFormatter.timestampFormatter.string(from: Date())
            let filename = "notification_\(timestamp).json"
            let fileURL = debugDir.appendingPathComponent(filename)

            // Criar payload estruturado
            var payload: [String: Any] = [
                "timestamp": timestamp,
                "data": userInfo
            ]

            // Adicionar informações adicionais se disponíveis
            if let aps = userInfo["aps"] as? [AnyHashable: Any] {
                payload["aps"] = aps
            }

            // Converter para JSON
            let jsonData = try JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted)
            try jsonData.write(to: fileURL)

            print("✅ NotificationDebugHelper: Notification saved to \(fileURL.path)")

            // Limpar arquivos antigos
            cleanOldFiles(in: debugDir)

        } catch {
            print("❌ NotificationDebugHelper: Error saving notification: \(error.localizedDescription)")
        }
    }

    /// Retorna todas as notificações salvas
    static func getAllNotifications() -> [[String: Any]] {
        let debugDir = getDebugDirectory()
        guard FileManager.default.fileExists(atPath: debugDir.path) else {
            return []
        }

        do {
            let files = try FileManager.default.contentsOfDirectory(at: debugDir, includingPropertiesForKeys: [.creationDateKey], options: [])
                .filter { $0.lastPathComponent.hasPrefix("notification_") && $0.pathExtension == "json" }
                .sorted { url1, url2 in
                    let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                    let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                    return date1 > date2 // Mais recente primeiro
                }

            var notifications: [[String: Any]] = []
            for fileURL in files {
                if let data = try? Data(contentsOf: fileURL),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    notifications.append(json)
                }
            }

            return notifications
        } catch {
            print("❌ NotificationDebugHelper: Error reading notifications: \(error.localizedDescription)")
            return []
        }
    }

    /// Retorna a notificação mais recente
    static func getLatestNotification() -> [String: Any]? {
        return getAllNotifications().first
    }

    /// Lê o conteúdo de uma notificação como string JSON
    static func readNotificationJSON(_ notification: [String: Any]) -> String {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: notification, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8) ?? "{}"
        } catch {
            print("❌ NotificationDebugHelper: Error converting to JSON: \(error.localizedDescription)")
            return "{}"
        }
    }

    /// Simula uma notificação usando o payload fornecido
    static func simulateNotification(_ payload: [String: Any], token: String) {
        // Chamar o método do Dito SDK para simular recebimento
        Dito.notificationReceived(userInfo: payload, token: token)
        print("✅ NotificationDebugHelper: Notification simulated")
    }

    /// Limpa todas as notificações salvas
    static func clearAllNotifications() {
        let debugDir = getDebugDirectory()
        do {
            let files = try FileManager.default.contentsOfDirectory(at: debugDir, includingPropertiesForKeys: nil, options: [])
                .filter { $0.lastPathComponent.hasPrefix("notification_") && $0.pathExtension == "json" }

            for fileURL in files {
                try? FileManager.default.removeItem(at: fileURL)
            }

            print("✅ NotificationDebugHelper: Cleared \(files.count) notifications")
        } catch {
            print("❌ NotificationDebugHelper: Error clearing notifications: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Helpers

    private static func getDebugDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent(debugDirName)
    }

    private static func cleanOldFiles(in directory: URL) {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey], options: [])
                .filter { $0.lastPathComponent.hasPrefix("notification_") && $0.pathExtension == "json" }
                .sorted { url1, url2 in
                    let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                    let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                    return date1 > date2
                }

            if files.count > maxFiles {
                let filesToDelete = files.dropFirst(maxFiles)
                for fileURL in filesToDelete {
                    try? FileManager.default.removeItem(at: fileURL)
                    print("🗑️ NotificationDebugHelper: Deleted old notification file: \(fileURL.lastPathComponent)")
                }
            }
        } catch {
            print("❌ NotificationDebugHelper: Error cleaning old files: \(error.localizedDescription)")
        }
    }
}

// MARK: - DateFormatter Extension
extension DateFormatter {
    static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()
}
