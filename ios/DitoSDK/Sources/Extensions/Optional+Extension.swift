import Foundation

protocol Defaultable {
  static var defaultValue: Self { get }
}

extension Optional where Wrapped: Defaultable {
  var unwrappedValue: Wrapped { return self ?? Wrapped.defaultValue }
}

extension String: Defaultable {
  static var defaultValue: String {
    ""
  }
}

extension Int: Defaultable {
  static var defaultValue: Int {
    return 0
  }
}

extension Double: Defaultable {
  static var defaultValue: Double {
    return 0.0
  }
}

extension Dictionary: Defaultable {
  static var defaultValue: [Key: Value] {
    return [:]
  }
}

extension Array: Defaultable {
  static var defaultValue: Array {
    return []
  }
}

extension Bool: Defaultable {
  static var defaultValue: Bool {
    return false
  }
}
