import CryptoKit
import Foundation

//MARK: PUBLIC
extension String {

  var sha1: String {
    guard #available(iOS 13, *) else {
      return SHA1.hexString(from: self)?
        .lowercased()
        .replacingOccurrences(of: " ", with: "") ?? ""
    }

    return Insecure.SHA1.hash(data: self.data(using: .utf8) ?? Data())
      .map {
        String(format: "%02hhx", $0)
      }.joined()
  }

  var formatToDitoString: String {
    Util.keywordVerification(self.checkCharacters)
    return self.replacingElements
  }

  var validateEmail: String? {

    let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
    let validate = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
      .evaluate(with: self)
    Util.validateEmail(validate)
    return validate ? self : nil
  }

  func convertToObject<T: Decodable>(type: T.Type) -> T? {

    guard let data = self.data(using: .utf8) else { return nil }
    let result = try? JSONDecoder().decode(T.self, from: data)
    return result
  }
}

//MARK: PRIVATE
extension String {

  private var ignoreAccentuation: String {
    return self.folding(options: .diacriticInsensitive, locale: .current)
  }

  private var containsUppercase: Bool {
    let uppercaseRegEx = ".*[A-Z]+.*"
    return NSPredicate(format: "SELF MATCHES %@", uppercaseRegEx).evaluate(
      with: self
    )
  }

  private var containsNumber: Bool {
    let numberRegEx = ".*[0-9]+.*"
    return NSPredicate(format: "SELF MATCHES %@", numberRegEx).evaluate(
      with: self
    )
  }

  private var containsSpecialCharacters: Bool {
    let specialRegEx = ".*[)(,.#?!@$%^&<>*~:`]+.*"
    return NSPredicate(format: "SELF MATCHES %@", specialRegEx).evaluate(
      with: self
    )
  }

  private var containsWhiteSpace: Bool {
    return self.contains(" ")
  }

  private var containsAccentuation: Bool {
    return self != self.ignoreAccentuation
  }

  private var checkCharacters: [DitoValidationCharacters] {

    var containsCharacters: [DitoValidationCharacters] = []

    if self.containsUppercase {
      containsCharacters.append(.uppercase)
    }

    if self.containsNumber {
      containsCharacters.append(.number)
    }

    if self.containsSpecialCharacters {
      containsCharacters.append(.special)
    }

    if self.containsWhiteSpace {
      containsCharacters.append(.whiteSpace)
    }

    if self.containsAccentuation {
      containsCharacters.append(.accentuation)
    }

    return containsCharacters
  }

  private var stripped: String {
    let okayChars = Set(
      "abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLKMNOPQRSTUVWXYZ-"
    )
    return self.filter { okayChars.contains($0) }
  }

  private var replacingElements: String {

    return self.replacingOccurrences(of: " ", with: "-")
      .replacingOccurrences(of: "--", with: "-")
      .lowercased()
      .ignoreAccentuation
      .stripped
  }
}
