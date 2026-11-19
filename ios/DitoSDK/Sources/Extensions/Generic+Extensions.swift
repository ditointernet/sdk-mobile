import Foundation

extension UserDefaults {

  private enum Keys {
    static let firstSave = "firstSave"
    static let identifyKey = "identify"
    static let savingState = "savingState"
    static let notificationRegisterKey = "notificationRegister"
    static let lastPushToken = "lastPushToken"
    static let lastUserTokenRegister = "lastUserTokenRegister"
    static let anonymousIdentifyMark = "anonymousIdentifyMark"
  }

  class var firstSave: Bool {
    get {
      UserDefaults.standard.bool(forKey: Keys.firstSave)
    }
    set {
      UserDefaults.standard.set(newValue, forKey: Keys.firstSave)
      UserDefaults.standard.synchronize()
    }
  }

  class var identify: IdentifyDefaults? {
    get {

      if let data = UserDefaults.standard.data(forKey: Keys.identifyKey) {
        do {
          let decoder = JSONDecoder()

          let decodedData = try decoder.decode(
            IdentifyDefaults.self,
            from: data
          )
          return decodedData

        } catch {
          DitoLogger.error("Unable to Decode Note (\(error))")
        }
      }
      return nil
    }
    set {

      if newValue == nil {
        UserDefaults.standard.removeObject(forKey: Keys.identifyKey)
      } else {

        do {
          let encoder = JSONEncoder()
          let endcodedData = try encoder.encode(newValue)
          UserDefaults.standard.set(
            endcodedData,
            forKey: Keys.identifyKey
          )
          UserDefaults.standard.synchronize()
        } catch {
          DitoLogger.error("Unable to Encode Note (\(error))")
        }
      }
    }
  }

  class var savingState: Double {
    get {
      UserDefaults.standard.double(forKey: Keys.savingState)
    }
    set {
      if newValue == -1 {
        UserDefaults.standard.removeObject(forKey: Keys.savingState)
      } else {
        UserDefaults.standard.set(newValue, forKey: Keys.savingState)
      }
      UserDefaults.standard.synchronize()
    }

  }

  class var notificationRegister: NotificationDefaults? {
    get {
      if let data = UserDefaults.standard.data(
        forKey: Keys.notificationRegisterKey
      ) {
        do {
          let decoder = JSONDecoder()

          let decodedData = try decoder.decode(
            NotificationDefaults.self,
            from: data
          )
          return decodedData

        } catch {
          DitoLogger.error("Unable to Decode Note (\(error))")
        }
      }
      return nil
    }
    set {

      if newValue == nil {
        UserDefaults.standard.removeObject(
          forKey: Keys.notificationRegisterKey
        )
      } else {

        do {
          let encoder = JSONEncoder()
          let endcodedData = try encoder.encode(newValue)
          UserDefaults.standard.set(
            endcodedData,
            forKey: Keys.notificationRegisterKey
          )
          UserDefaults.standard.synchronize()
        } catch {
          DitoLogger.error("Unable to Encode Note (\(error))")
        }
      }
    }
  }

  class var lastPushToken: String? {
    get {
      UserDefaults.standard.string(forKey: Keys.lastPushToken)
    }
    set {
      UserDefaults.standard.set(newValue, forKey: Keys.lastPushToken)
    }
  }

  /// ["user_id", "token"] of the last register confirmed with a logged-in user.
  class var lastUserTokenRegister: [String: String]? {
    get {
      UserDefaults.standard.dictionary(forKey: Keys.lastUserTokenRegister) as? [String: String]
    }
    set {
      UserDefaults.standard.set(newValue, forKey: Keys.lastUserTokenRegister)
    }
  }

  class var anonymousIdentifyMark: [String: String]? {
    get {
      UserDefaults.standard.dictionary(forKey: Keys.anonymousIdentifyMark) as? [String: String]
    }
    set {
      UserDefaults.standard.set(newValue, forKey: Keys.anonymousIdentifyMark)
    }
  }

  class func clearIdentityState() {
    identify = nil
    lastUserTokenRegister = nil
    savingState = -1
  }
}

extension Bundle {

  var appKey: String {
    return object(forInfoDictionaryKey: "AppKey") as? String ?? ""
  }

  var appSecret: String {
    return object(forInfoDictionaryKey: "AppSecret") as? String ?? ""
  }

  var appSecretDecoded: String {
    guard let encodedSecret = object(forInfoDictionaryKey: "AppSecret") as? String,
          let data = Data(base64Encoded: encodedSecret),
          let decodedSecret = String(data: data, encoding: .utf8) else {
      return ""
    }
    return decodedSecret
  }
}

extension Int {

  var toString: String {
    return String(self)
  }
}
