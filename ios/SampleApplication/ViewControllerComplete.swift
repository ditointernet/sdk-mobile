import CoreData
import DitoSDK
import FirebaseMessaging
import UIKit

class ViewControllerComplete: UIViewController {

    // MARK: - Status
    @IBOutlet weak var statusLabel: UILabel!

    // MARK: - FCM Token
    @IBOutlet weak var fcmTokenLabel: UILabel!
    @IBOutlet weak var getFcmTokenButton: UIButton!

    // MARK: - Identify Fields
    @IBOutlet weak var identifyIdField: UITextField!
    @IBOutlet weak var identifyNameField: UITextField!
    @IBOutlet weak var identifyEmailField: UITextField!
    @IBOutlet weak var identifyCustomDataField: UITextView!
    @IBOutlet weak var testIdentifyButton: UIButton!

    // MARK: - Track Fields
    @IBOutlet weak var trackActionField: UITextField!
    @IBOutlet weak var trackDataField: UITextView!
    @IBOutlet weak var testTrackButton: UIButton!

    // MARK: - Register Device
    @IBOutlet weak var registerTokenField: UITextField!
    @IBOutlet weak var testRegisterDeviceButton: UIButton!

    // MARK: - Unregister Device
    @IBOutlet weak var unregisterTokenField: UITextField!
    @IBOutlet weak var testUnregisterDeviceButton: UIButton!

    // MARK: - Global Actions
    @IBOutlet weak var testAllButton: UIButton!
    @IBOutlet weak var notificationDebugButton: UIButton!

    // MARK: - Scroll View
    @IBOutlet weak var scrollView: UIScrollView!

    // Carregar configurações do Info.plist
    private let config = InfoPlistHelper.loadSampleAppConfig()
    private var fcmToken: String = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadDefaultValues()
        setupFcmToken()
        checkSDKStatus()
    }

    private func setupUI() {
        title = "Dito SDK Sample"

        // Configurar campos de texto multiline
        identifyCustomDataField.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        identifyCustomDataField.layer.borderColor = UIColor.systemGray4.cgColor
        identifyCustomDataField.layer.borderWidth = 1
        identifyCustomDataField.layer.cornerRadius = 8

        trackDataField.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        trackDataField.layer.borderColor = UIColor.systemGray4.cgColor
        trackDataField.layer.borderWidth = 1
        trackDataField.layer.cornerRadius = 8

        // Configurar botões
        testIdentifyButton.addTarget(self, action: #selector(testIdentifyTapped), for: .touchUpInside)
        testTrackButton.addTarget(self, action: #selector(testTrackTapped), for: .touchUpInside)
        testRegisterDeviceButton.addTarget(self, action: #selector(testRegisterDeviceTapped), for: .touchUpInside)
        testUnregisterDeviceButton.addTarget(self, action: #selector(testUnregisterDeviceTapped), for: .touchUpInside)
        testAllButton.addTarget(self, action: #selector(testAllTapped), for: .touchUpInside)
        notificationDebugButton.addTarget(self, action: #selector(notificationDebugTapped), for: .touchUpInside)
        getFcmTokenButton.addTarget(self, action: #selector(getFcmTokenTapped), for: .touchUpInside)

        // Configurar gesto para fechar teclado
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    private func loadDefaultValues() {
        // Preencher campos Identify
        if let id = config["IDENTIFY_ID"] {
            identifyIdField.text = id
        }
        if let name = config["IDENTIFY_NAME"] {
            identifyNameField.text = name
        }
        if let email = config["IDENTIFY_EMAIL"] {
            identifyEmailField.text = email
        }
        if let customData = config["IDENTIFY_CUSTOM_DATA"] {
            identifyCustomDataField.text = customData
        }

        // Preencher campos Track
        if let action = config["TRACK_ACTION"] {
            trackActionField.text = action
        }
        if let data = config["TRACK_DATA"] {
            trackDataField.text = data
        }
    }

    private func setupFcmToken() {
        Messaging.messaging().token { [weak self] token, error in
            guard let self = self else { return }
            if let error = error {
                DispatchQueue.main.async {
                    self.fcmTokenLabel.text = "Token FCM: Erro ao obter token"
                }
                print("Error fetching FCM registration token: \(error)")
            } else if let token = token {
                self.fcmToken = token
                DispatchQueue.main.async {
                    self.fcmTokenLabel.text = "Token FCM: \(token)"
                    if self.registerTokenField.text?.isEmpty ?? true {
                        self.registerTokenField.text = token
                    }
                    if self.unregisterTokenField.text?.isEmpty ?? true {
                        self.unregisterTokenField.text = token
                    }
                }
            }
        }
    }

    private func checkSDKStatus() {
        let apiKey = config["API_KEY"] ?? ""
        let apiSecret = config["API_SECRET"] ?? ""

        if !apiKey.isEmpty && !apiSecret.isEmpty {
            statusLabel.text = "Status: SDK Inicializado ✓"
            statusLabel.textColor = .systemGreen
        } else {
            statusLabel.text = "Status: SDK não inicializado ✗"
            statusLabel.textColor = .systemRed
        }
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: - Actions

    @objc private func testIdentifyTapped() {
        guard let id = identifyIdField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty else {
            showToast("ID é obrigatório para identify")
            return
        }

        let name = identifyNameField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = identifyEmailField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let customDataJson = identifyCustomDataField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "{}"

        var customData: [String: Any]?
        if !customDataJson.isEmpty && customDataJson != "{}" {
            customData = InfoPlistHelper.parseJSON(customDataJson)
            if customData == nil {
                showToast("customData JSON inválido")
                return
            }
        }

        Dito.identify(
            id: id,
            name: name?.isEmpty == false ? name : nil,
            email: email?.isEmpty == false ? email : nil,
            customData: customData
        )

        showToast("Identify executado com sucesso")
    }

    @objc private func testTrackTapped() {
        guard let action = trackActionField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !action.isEmpty else {
            showToast("Action é obrigatório para track")
            return
        }

        let dataJson = trackDataField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "{}"
        var data: [String: Any]?

        if !dataJson.isEmpty && dataJson != "{}" {
            data = InfoPlistHelper.parseJSON(dataJson)
            if data == nil {
                showToast("data JSON inválido")
                return
            }
        }

        Dito.track(action: action, data: data)
        showToast("Track executado com sucesso")
    }

    @objc private func testRegisterDeviceTapped() {
        guard let token = registerTokenField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else {
            showToast("Token é obrigatório para registerDevice")
            return
        }

        Dito.registerDevice(token: token)
        showToast("RegisterDevice executado com sucesso")
    }

    @objc private func testUnregisterDeviceTapped() {
        guard let token = unregisterTokenField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else {
            showToast("Token é obrigatório para unregisterDevice")
            return
        }

        Dito.unregisterDevice(token: token)
        showToast("UnregisterDevice executado com sucesso")
    }

    @objc private func testAllTapped() {
        var successCount = 0
        var errorCount = 0

        // Test Identify
        if let id = identifyIdField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty {
            let name = identifyNameField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
            let email = identifyEmailField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
            let customDataJson = identifyCustomDataField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "{}"
            var customData: [String: Any]?
            if !customDataJson.isEmpty && customDataJson != "{}" {
                customData = InfoPlistHelper.parseJSON(customDataJson)
            }

            Dito.identify(
                id: id,
                name: name?.isEmpty == false ? name : nil,
                email: email?.isEmpty == false ? email : nil,
                customData: customData
            )
            successCount += 1
        }

        // Test Track
        if let action = trackActionField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !action.isEmpty {
            let dataJson = trackDataField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "{}"
            var data: [String: Any]?
            if !dataJson.isEmpty && dataJson != "{}" {
                data = InfoPlistHelper.parseJSON(dataJson)
            }
            Dito.track(action: action, data: data)
            successCount += 1
        }

        // Test Register Device
        if let token = registerTokenField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty {
            Dito.registerDevice(token: token)
            successCount += 1
        }

        // Test Unregister Device
        if let token = unregisterTokenField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty {
            Dito.unregisterDevice(token: token)
            successCount += 1
        }

        showToast("Testes executados: \(successCount) sucesso, \(errorCount) erros")
    }

    @objc private func notificationDebugTapped() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let debugVC = storyboard.instantiateViewController(withIdentifier: "NotificationDebugViewController") as? NotificationDebugViewController {
            let navController = UINavigationController(rootViewController: debugVC)
            present(navController, animated: true)
        } else {
            // Fallback: criar programaticamente
            let debugVC = NotificationDebugViewController()
            let navController = UINavigationController(rootViewController: debugVC)
            present(navController, animated: true)
        }
    }

    @objc private func getFcmTokenTapped() {
        Messaging.messaging().token { [weak self] token, error in
            guard let self = self else { return }
            if let error = error {
                DispatchQueue.main.async {
                    self.showToast("Erro ao obter token FCM: \(error.localizedDescription)")
                }
            } else if let token = token {
                self.fcmToken = token
                DispatchQueue.main.async {
                    self.fcmTokenLabel.text = "Token FCM: \(token)"
                    self.registerTokenField.text = token
                    self.unregisterTokenField.text = token
                    self.showToast("Token FCM obtido e preenchido")
                }
            }
        }
    }

    private func showToast(_ message: String) {
        let toastLabel = UILabel()
        toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        toastLabel.textColor = .white
        toastLabel.textAlignment = .center
        toastLabel.font = UIFont.systemFont(ofSize: 14)
        toastLabel.text = message
        toastLabel.numberOfLines = 0
        toastLabel.alpha = 0.0
        toastLabel.layer.cornerRadius = 10
        toastLabel.clipsToBounds = true

        let maxSize = CGSize(width: view.bounds.width - 40, height: view.bounds.height)
        let expectedSize = toastLabel.sizeThatFits(maxSize)
        toastLabel.frame = CGRect(
            x: (view.bounds.width - expectedSize.width - 20) / 2,
            y: view.bounds.height - 100,
            width: expectedSize.width + 20,
            height: expectedSize.height + 10
        )

        view.addSubview(toastLabel)

        UIView.animate(withDuration: 0.3, animations: {
            toastLabel.alpha = 1.0
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 2.0, options: .curveEaseOut, animations: {
                toastLabel.alpha = 0.0
            }) { _ in
                toastLabel.removeFromSuperview()
            }
        }
    }
}
