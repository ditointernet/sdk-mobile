import CryptoKit
import Foundation

extension String {
    func sha1() -> String {
        let data = Data(self.utf8)
        let digest = Insecure.SHA1.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
