import Foundation

class Util {

  static func toDate(_ date: Date?) -> String? {

    guard let date = date else {
      return Date().formatToDitoDate
    }
    return date.formatToDitoDate
  }

  static func toString(from json: Any?) -> String? {

    guard let json = json else { return nil }

    do {
      let data = try JSONSerialization.data(
        withJSONObject: json,
        options: .prettyPrinted
      )
      return String(data: data, encoding: .utf8)

    } catch let error {
      DitoLogger.error(error)
      return nil
    }
  }

  static func keywordVerification(
    _ containsCharacters: [DitoValidationCharacters]
  ) {

    var warning: String = ""

    containsCharacters.forEach {
      switch $0 {
      case .uppercase:
        warning += "Sua palavra chave contém letra maiúscula\n"
      case .accentuation:
        warning += "Sua palavra chave contém acentuação\n"
      case .whiteSpace:
        warning += "Sua palavra chave contém espaço em branco\n"
      case .special:
        warning += "Sua palavra chave contém caractere especial\n"
      case .number:
        warning += "Sua palavra chave contém número\n"
      }
    }

    if !warning.isEmpty {
      DitoLogger.warning(warning)
    }
  }

  static func validateEmail(_ isValidEmail: Bool) {

    if !isValidEmail {
      DitoLogger.warning("DTUser - e-mail inserido é inválido")
    }
  }
}
