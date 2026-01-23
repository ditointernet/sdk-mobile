import Foundation

extension UserDefaults {

  private enum Keys {
    static let firstSave = "firstSave"
    static let identifyKey = "identify"
    static let savingState = "savingState"
    static let notificationRegisterKey = "notificationRegister"
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
          print("Unable to Decode Note (\(error))")
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
          print("Unable to Encode Note (\(error))")
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
      }
      UserDefaults.standard.set(newValue, forKey: Keys.savingState)
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
          print("Unable to Decode Note (\(error))")
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
          print("Unable to Encode Note (\(error))")
        }
      }
    }
  }
}

extension Bundle {

  var apiKey: String {
    return object(forInfoDictionaryKey: "ApiKey") as? String ?? ""
  }

  var apiSecret: String {
    return object(forInfoDictionaryKey: "ApiSecret") as? String ?? ""
  }
}

extension Int {

  var toString: String {
    return String(self)
  }
}
