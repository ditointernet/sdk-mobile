import Foundation
import Security

enum DeviceIdProvider {
    private static let account = "br.com.dito.device_id"
    private static let lock = NSLock()
    nonisolated(unsafe) private static var cached: String?
    #if DEBUG
    nonisolated(unsafe) static var copyMatching: (CFDictionary, UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus = SecItemCopyMatching
    nonisolated(unsafe) static var addItem: (CFDictionary, UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus = SecItemAdd
    #else
    private static let copyMatching: (CFDictionary, UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus = SecItemCopyMatching
    private static let addItem: (CFDictionary, UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus = SecItemAdd
    #endif

    /// Returns "" when the Keychain cannot be read (e.g. before the first unlock); the next call retries.
    static func get() -> String {
        lock.lock()
        defer { lock.unlock() }
        if let cachedId = cached { return cachedId }

        let stored = read()
        if let id = stored.id {
            cached = id
            return id
        }
        // Generating an id on any other read error would replace the device's identity.
        guard stored.status == errSecItemNotFound else { return "" }

        let newId = UUID().uuidString
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(newId.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        switch addItem(addQuery as CFDictionary, nil) {
        case errSecSuccess:
            cached = newId
            return newId
        case errSecDuplicateItem:
            guard let id = read().id else { return "" }
            cached = id
            return id
        default:
            return ""
        }
    }

    private static func read() -> (status: OSStatus, id: String?) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        var result: CFTypeRef?
        let status = copyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let id = String(data: data, encoding: .utf8)
        else { return (status, nil) }
        return (status, id)
    }

    #if DEBUG
    static func setForTests(_ id: String?) {
        lock.lock()
        defer { lock.unlock() }
        cached = id
    }

    static func resetForTests() {
        setForTests(nil)
        copyMatching = SecItemCopyMatching
        addItem = SecItemAdd
    }
    #endif
}
