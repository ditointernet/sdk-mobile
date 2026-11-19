import Foundation
import Security

enum DeviceIdProvider {
    private static let account = "br.com.dito.device_id"
    private static let lock = NSLock()
    nonisolated(unsafe) private static var cached: String?
    typealias KeychainCall = (CFDictionary, UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus
    #if DEBUG
    nonisolated(unsafe) private static var copyMatchingCall: KeychainCall = SecItemCopyMatching
    nonisolated(unsafe) private static var addItemCall: KeychainCall = SecItemAdd
    #else
    private static let copyMatchingCall: KeychainCall = SecItemCopyMatching
    private static let addItemCall: KeychainCall = SecItemAdd
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
        switch addItemCall(addQuery as CFDictionary, nil) {
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
        let status = copyMatchingCall(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let id = String(data: data, encoding: .utf8)
        else { return (status, nil) }
        return (status, id)
    }

    #if DEBUG
    // `get()` holds `lock` (not recursive), so it uses the stored calls, never these.
    static var copyMatching: KeychainCall {
        get { lock.lock(); defer { lock.unlock() }; return copyMatchingCall }
        set { lock.lock(); defer { lock.unlock() }; copyMatchingCall = newValue }
    }

    static var addItem: KeychainCall {
        get { lock.lock(); defer { lock.unlock() }; return addItemCall }
        set { lock.lock(); defer { lock.unlock() }; addItemCall = newValue }
    }

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
