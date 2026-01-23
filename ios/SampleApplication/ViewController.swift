import CoreData
import DitoSDK
import FirebaseMessaging
import Toast_Swift
import UIKit

class ViewController: UIViewController {
  @IBOutlet weak var fieldCpf: UITextField!
  @IBOutlet weak var fieldEmail: UITextField!
  @IBOutlet weak var buttonRegisterDevice: UIButton!
  @IBOutlet weak var buttonNotification: UIButton!

  var identified: Bool = false

  private var birthday: Date? {
    let birthdayString = "16/06/1994"
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "dd/MM/yyyy"
    return dateFormatter.date(from: birthdayString)
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    configureKeyboardDismissGesture()
    fieldEmail?.becomeFirstResponder()
  }

  @IBAction func didTapIdentify(_ sender: Any) {
    handleIndentifyClick()
  }

  @IBAction func didTapNotification(_ sender: Any) {
    handleNotificationClick()
  }

  @IBAction func didTapRegistration(_ sender: Any) {
    handleDeviceRegistration()
  }
}

extension ViewController {

  // MARK: - Actions
  func handleIndentifyClick() {
    // Garante que teremos um campo de email válido (via IBOutlet ou fallback)
    guard let emailField = fieldEmail else {
      showToast("Campo de e-mail não disponível. Verifique conexões no storyboard.")
      return
    }

    //  Normaliza e valida e-mail
    let normalizedEmail = normalizeEmail(emailField.text)

    // Verifica se o e-mail foi informado
    guard let email = normalizedEmail, !email.isEmpty else {
      showToast("E-mail não informado")
      emailField.becomeFirstResponder()
      return
    }

    // Monta o usuário; o SDK validará o formato do e-mail
    let user = DitoUser(
      name: "Dito user teste",
      gender: .masculino,
      email: email,
      birthday: birthday,
      location: "Florianópolis"
    )

    // ID estável via SHA1 (email normalizado)
    let userId = Dito.sha1(for: email)

    // Identifica no Dito
    Dito.identify(id: userId, data: user)
    identified = true

    showToast("Usuário identificado")

    buttonRegisterDevice.isEnabled = true
    buttonNotification.isEnabled = true
  }

  func handleNotificationClick() {
    // Cria objeto evento de comportamento customizado
    let event = DitoEvent(
      action: "teste-behavior",
      customData: ["id_loja": 123]
    )
    // Dispara o evento no Dito SDK
    Dito.track(event: event)
    showToast("Evento disparado")
  }

  func handleDeviceRegistration() {
    Messaging.messaging().token { fcmToken, error in
      if let error = error {
        // Evita crash em background thread ao mostrar toast
        DispatchQueue.main.async {
          self.showToast("Falha ao obter token FCM")
        }
        print("Error fetching FCM registration token: \(error)")
      } else if let fcmToken = fcmToken {
        // Registra o dispositivo no Dito SDK em MainActor
        Task {
          Dito.registerDevice(token: fcmToken)
        }
        DispatchQueue.main.async {
          self.showToast("Dispositivo registrado")
        }
      } else {
        DispatchQueue.main.async {
          self.showToast("Token FCM indisponível")
        }
      }
    }
  }
}

// MARK: - UI/UX helpers
extension ViewController {

  fileprivate func configureKeyboardDismissGesture() {
    let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
    tap.cancelsTouchesInView = false
    view.addGestureRecognizer(tap)
  }

  @objc fileprivate func dismissKeyboard() {
    view.endEditing(true)
  }

  fileprivate func showToast(_ message: String) {
    var style = ToastStyle()
    style.messageAlignment = .center
    view.makeToast(message, duration: 2.0, position: .bottom, style: style)
  }

  fileprivate func normalizeEmail(_ text: String?) -> String? {
    let trimmed = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    return trimmed.lowercased()
  }
}
