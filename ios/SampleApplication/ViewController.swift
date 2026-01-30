import CoreData
import DitoSDK
import FirebaseMessaging
import UIKit

/// Helper para acessar valores do Info.plist
class InfoPlistHelper {
    static func getValue(forKey key: String) -> String? {
        return Bundle.main.object(forInfoDictionaryKey: key) as? String
    }

    static func loadSampleAppConfig() -> [String: String] {
        var config = PlistLoader.loadSampleAppConfig()

        if let apiKey = getValue(forKey: "ApiKey") {
            config["API_KEY"] = apiKey
        }
        if let apiSecret = getValue(forKey: "ApiSecret") {
            config["API_SECRET"] = apiSecret
        }

        return config
    }

    static func parseJSON(_ jsonString: String) -> [String: Any]? {
        guard let data = jsonString.data(using: .utf8) else {
            return nil
        }

        do {
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            return json as? [String: Any]
        } catch {
            print("Erro ao parsear JSON: \(error)")
            return nil
        }
    }
}

class ViewController: UIViewController {

    // MARK: - Properties
    private let config = InfoPlistHelper.loadSampleAppConfig()
    private var fcmToken: String = ""
    private let scrollView = UIScrollView()
    private let contentView = UIStackView()

    // Status
    private let statusLabel = UILabel()

    // FCM Token
    private let fcmTokenLabel = UILabel()
    private let getFcmTokenButton = UIButton(type: .system)

    // Identify
    private let identifyIdField = UITextField()
    private let identifyNameField = UITextField()
    private let identifyEmailField = UITextField()
    private let identifyCustomDataField = UITextView()
    private let testIdentifyButton = UIButton(type: .system)

    // Track
    private let trackActionField = UITextField()
    private let trackDataField = UITextView()
    private let testTrackButton = UIButton(type: .system)

    // Register Device
    private let registerTokenField = UITextField()
    private let testRegisterDeviceButton = UIButton(type: .system)

    // Unregister Device
    private let unregisterTokenField = UITextField()
    private let testUnregisterDeviceButton = UIButton(type: .system)

    // Global Actions
    private let testAllButton = UIButton(type: .system)
    private let notificationDebugButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        print("🔵 ViewController: viewDidLoad called")
        title = "Dito SDK Sample"
        view.backgroundColor = .systemBackground

        print("🔵 ViewController: Setting up scroll view...")
        setupScrollView()
        print("🔵 ViewController: Setting up UI...")
        setupUI()
        print("🔵 ViewController: Loading default values...")
        loadDefaultValues()
        print("🔵 ViewController: Setting up FCM token...")
        setupFcmToken()
        print("🔵 ViewController: Checking SDK status...")
        checkSDKStatus()
        print("✅ ViewController: viewDidLoad completed successfully")
    }

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.axis = .vertical
        contentView.spacing = 16

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])
    }

    private func setupUI() {
        // Status Card
        addCard(title: "Status do SDK", views: [statusLabel])

        // FCM Token Card
        fcmTokenLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        fcmTokenLabel.numberOfLines = 0
        getFcmTokenButton.setTitle("Obter Token FCM", for: .normal)
        getFcmTokenButton.addTarget(self, action: #selector(getFcmTokenTapped), for: .touchUpInside)
        addCard(title: "Firebase Cloud Messaging", views: [fcmTokenLabel, getFcmTokenButton])

        // Identify Card
        setupTextField(identifyIdField, placeholder: "ID *")
        setupTextField(identifyNameField, placeholder: "Name")
        setupTextField(identifyEmailField, placeholder: "Email", keyboardType: .emailAddress)
        setupTextView(identifyCustomDataField, placeholder: "Custom Data (JSON)")
        testIdentifyButton.setTitle("Testar Identify", for: .normal)
        testIdentifyButton.addTarget(self, action: #selector(testIdentifyTapped), for: .touchUpInside)
        addCard(title: "Identify", views: [
            createLabeledField("ID *", identifyIdField),
            createLabeledField("Name", identifyNameField),
            createLabeledField("Email", identifyEmailField),
            createLabeledField("Custom Data (JSON)", identifyCustomDataField),
            testIdentifyButton
        ])

        // Track Card
        setupTextField(trackActionField, placeholder: "Action *")
        setupTextView(trackDataField, placeholder: "Data (JSON)")
        testTrackButton.setTitle("Testar Track", for: .normal)
        testTrackButton.addTarget(self, action: #selector(testTrackTapped), for: .touchUpInside)
        addCard(title: "Track", views: [
            createLabeledField("Action *", trackActionField),
            createLabeledField("Data (JSON)", trackDataField),
            testTrackButton
        ])

        // Register Device Card
        setupTextField(registerTokenField, placeholder: "Token *")
        testRegisterDeviceButton.setTitle("Testar Register Device", for: .normal)
        testRegisterDeviceButton.addTarget(self, action: #selector(testRegisterDeviceTapped), for: .touchUpInside)
        addCard(title: "Register Device", views: [
            createLabeledField("Token *", registerTokenField),
            testRegisterDeviceButton
        ])

        // Unregister Device Card
        setupTextField(unregisterTokenField, placeholder: "Token *")
        testUnregisterDeviceButton.setTitle("Testar Unregister Device", for: .normal)
        testUnregisterDeviceButton.addTarget(self, action: #selector(testUnregisterDeviceTapped), for: .touchUpInside)
        addCard(title: "Unregister Device", views: [
            createLabeledField("Token *", unregisterTokenField),
            testUnregisterDeviceButton
        ])

        // Global Actions
        testAllButton.setTitle("Testar Todos os Métodos", for: .normal)
        testAllButton.addTarget(self, action: #selector(testAllTapped), for: .touchUpInside)
        contentView.addArrangedSubview(testAllButton)

        notificationDebugButton.setTitle("🔔 Debug de Notificações", for: .normal)
        notificationDebugButton.addTarget(self, action: #selector(notificationDebugTapped), for: .touchUpInside)
        contentView.addArrangedSubview(notificationDebugButton)

        // Keyboard dismiss
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    private func addCard(title: String, views: [UIView]) {
        let cardView = UIView()
        cardView.backgroundColor = .secondarySystemBackground
        cardView.layer.cornerRadius = 8
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.1
        cardView.layer.shadowOffset = CGSize(width: 0, height: 2)
        cardView.layer.shadowRadius = 4

        let cardStack = UIStackView()
        cardStack.axis = .vertical
        cardStack.spacing = 12
        cardStack.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .boldSystemFont(ofSize: 20)
        cardStack.addArrangedSubview(titleLabel)

        for view in views {
            cardStack.addArrangedSubview(view)
        }

        cardView.addSubview(cardStack)
        NSLayoutConstraint.activate([
            cardStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            cardStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            cardStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            cardStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16)
        ])

        contentView.addArrangedSubview(cardView)
    }

    private func createLabeledField(_ labelText: String, _ field: UIView) -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 4

        let label = UILabel()
        label.text = labelText
        label.font = .systemFont(ofSize: 14, weight: .medium)
        container.addArrangedSubview(label)
        container.addArrangedSubview(field)

        return container
    }

    private func setupTextField(_ textField: UITextField, placeholder: String, keyboardType: UIKeyboardType = .default) {
        textField.borderStyle = .roundedRect
        textField.placeholder = placeholder
        textField.keyboardType = keyboardType
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.heightAnchor.constraint(equalToConstant: 44).isActive = true
    }

    private func setupTextView(_ textView: UITextView, placeholder: String) {
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.layer.borderColor = UIColor.systemGray4.cgColor
        textView.layer.borderWidth = 1
        textView.layer.cornerRadius = 8
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.heightAnchor.constraint(equalToConstant: 80).isActive = true
    }

    private func loadDefaultValues() {
        if let email = config["IDENTIFY_EMAIL"], !email.isEmpty {
            identifyIdField.text = email.sha1()
        } else {
            identifyIdField.text = config["IDENTIFY_ID"]
        }

        identifyNameField.text = config["IDENTIFY_NAME"]
        identifyEmailField.text = config["IDENTIFY_EMAIL"]
        identifyCustomDataField.text = config["IDENTIFY_CUSTOM_DATA"]
        trackActionField.text = config["TRACK_ACTION"]
        trackDataField.text = config["TRACK_DATA"]
    }

    private func setupFcmToken() {
        // Tentar obter token FCM
        requestFcmToken()

        // Observar quando o token for recebido
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(fcmTokenReceived(_:)),
            name: NSNotification.Name("FCMTokenReceived"),
            object: nil
        )
    }

    private func requestFcmToken() {
        Messaging.messaging().token { [weak self] token, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let error = error {
                    let errorMsg = error.localizedDescription
                    self.fcmTokenLabel.text = "Token FCM: Erro - \(errorMsg)"
                    self.fcmTokenLabel.textColor = .systemRed

                    #if targetEnvironment(simulator)
                    self.fcmTokenLabel.text = "Token FCM: Não disponível no simulador\n(Use dispositivo físico para push notifications)"
                    #endif

                    print("⚠️ ViewController: Erro ao obter FCM token: \(errorMsg)")
                } else if let token = token {
                    self.fcmToken = token
                    self.fcmTokenLabel.text = "Token FCM: \(token)"
                    self.fcmTokenLabel.textColor = .systemGreen

                    if self.registerTokenField.text?.isEmpty ?? true {
                        self.registerTokenField.text = token
                    }
                    if self.unregisterTokenField.text?.isEmpty ?? true {
                        self.unregisterTokenField.text = token
                    }

                    print("✅ ViewController: FCM token obtido: \(token)")
                } else {
                    self.fcmTokenLabel.text = "Token FCM: Aguardando..."
                    self.fcmTokenLabel.textColor = .systemOrange
                }
            }
        }
    }

    @objc private func fcmTokenReceived(_ notification: Notification) {
        if let token = notification.userInfo?["token"] as? String {
            fcmToken = token
            fcmTokenLabel.text = "Token FCM: \(token)"
            fcmTokenLabel.textColor = .systemGreen

            if registerTokenField.text?.isEmpty ?? true {
                registerTokenField.text = token
            }
            if unregisterTokenField.text?.isEmpty ?? true {
                unregisterTokenField.text = token
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

        // Test Identify
        if let id = identifyIdField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty {
            let name = identifyNameField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
            let email = identifyEmailField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
            let customDataJson = identifyCustomDataField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "{}"
            var customData: [String: Any]?
            if !customDataJson.isEmpty && customDataJson != "{}" {
                customData = InfoPlistHelper.parseJSON(customDataJson)
            }
            Dito.identify(id: id, name: name?.isEmpty == false ? name : nil, email: email?.isEmpty == false ? email : nil, customData: customData)
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

        showToast("Testes executados: \(successCount) sucesso")
    }

    @objc private func notificationDebugTapped() {
        let debugVC = NotificationDebugViewController()
        let navController = UINavigationController(rootViewController: debugVC)
        present(navController, animated: true)
    }

    @objc private func getFcmTokenTapped() {
        fcmTokenLabel.text = "Token FCM: Solicitando..."
        fcmTokenLabel.textColor = .systemOrange

        // Tentar novamente obter o token
        requestFcmToken()

        // Se ainda não tiver APNS token, tentar registrar novamente
        UIApplication.shared.registerForRemoteNotifications()

        showToast("Solicitando token FCM...")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
