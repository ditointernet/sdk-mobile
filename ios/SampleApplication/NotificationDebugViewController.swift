import UIKit
import DitoSDK

class NotificationDebugViewController: UIViewController {

    private let countLabel = UILabel()
    private let refreshButton = UIButton(type: .system)
    private let latestButton = UIButton(type: .system)
    private let tableView = UITableView()
    private let contentTextView = UITextView()
    private let copyButton = UIButton(type: .system)
    private let simulateButton = UIButton(type: .system)

    private var notifications: [[String: Any]] = []
    private var selectedNotification: [String: Any]?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadNotifications()
    }

    private func setupUI() {
        title = "🔔 Debug de Notificações"
        view.backgroundColor = .systemBackground

        // Configurar botão de fechar
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeTapped)
        )

        // Count Label
        countLabel.font = .boldSystemFont(ofSize: 16)
        countLabel.translatesAutoresizingMaskIntoConstraints = false

        // Buttons
        refreshButton.setTitle("Atualizar", for: .normal)
        refreshButton.addTarget(self, action: #selector(refreshTapped), for: .touchUpInside)
        refreshButton.translatesAutoresizingMaskIntoConstraints = false

        latestButton.setTitle("Última", for: .normal)
        latestButton.addTarget(self, action: #selector(latestTapped), for: .touchUpInside)
        latestButton.translatesAutoresizingMaskIntoConstraints = false

        // TableView
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "NotificationCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false

        // TextView
        contentTextView.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        contentTextView.backgroundColor = UIColor.systemGray6
        contentTextView.layer.cornerRadius = 8
        contentTextView.text = "Selecione uma notificação para ver o conteúdo"
        contentTextView.isEditable = false
        contentTextView.translatesAutoresizingMaskIntoConstraints = false

        // Action Buttons
        copyButton.setTitle("Copiar JSON", for: .normal)
        copyButton.addTarget(self, action: #selector(copyTapped), for: .touchUpInside)
        copyButton.isEnabled = false
        copyButton.translatesAutoresizingMaskIntoConstraints = false

        simulateButton.setTitle("Simular Esta Notificação", for: .normal)
        simulateButton.addTarget(self, action: #selector(simulateTapped), for: .touchUpInside)
        simulateButton.isEnabled = false
        simulateButton.translatesAutoresizingMaskIntoConstraints = false

        // Layout
        view.addSubview(countLabel)
        view.addSubview(refreshButton)
        view.addSubview(latestButton)
        view.addSubview(tableView)
        view.addSubview(contentTextView)
        view.addSubview(copyButton)
        view.addSubview(simulateButton)

        NSLayoutConstraint.activate([
            countLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            countLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            countLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            refreshButton.topAnchor.constraint(equalTo: countLabel.bottomAnchor, constant: 16),
            refreshButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            refreshButton.widthAnchor.constraint(equalTo: latestButton.widthAnchor),

            latestButton.topAnchor.constraint(equalTo: countLabel.bottomAnchor, constant: 16),
            latestButton.leadingAnchor.constraint(equalTo: refreshButton.trailingAnchor, constant: 8),
            latestButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            tableView.topAnchor.constraint(equalTo: refreshButton.bottomAnchor, constant: 16),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            tableView.heightAnchor.constraint(equalToConstant: 200),

            contentTextView.topAnchor.constraint(equalTo: tableView.bottomAnchor, constant: 16),
            contentTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            contentTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            contentTextView.heightAnchor.constraint(equalToConstant: 200),

            copyButton.topAnchor.constraint(equalTo: contentTextView.bottomAnchor, constant: 16),
            copyButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            copyButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            simulateButton.topAnchor.constraint(equalTo: copyButton.bottomAnchor, constant: 16),
            simulateButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            simulateButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            simulateButton.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }

    private func loadNotifications() {
        notifications = NotificationDebugHelper.getAllNotifications()
        countLabel.text = "Total de notificações salvas: \(notifications.count)"
        tableView.reloadData()
    }

    @objc private func refreshTapped() {
        loadNotifications()
        showToast("Lista atualizada")
    }

    @objc private func latestTapped() {
        if let latest = NotificationDebugHelper.getLatestNotification() {
            selectedNotification = latest
            showNotificationDetails(latest)
        } else {
            showToast("Nenhuma notificação salva")
        }
    }

    @objc private func copyTapped() {
        guard let notification = selectedNotification else { return }

        let jsonString = NotificationDebugHelper.readNotificationJSON(notification)
        UIPasteboard.general.string = jsonString
        showToast("JSON copiado para área de transferência")
    }

    @objc private func simulateTapped() {
        guard let notification = selectedNotification else { return }

        // Obter token FCM do AppDelegate
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate,
           let token = appDelegate.fcmToken {
            NotificationDebugHelper.simulateNotification(notification, token: token)
            showToast("Notificação simulada com sucesso!")
        } else {
            showToast("Token FCM não disponível")
        }
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    private func showNotificationDetails(_ notification: [String: Any]) {
        let jsonString = NotificationDebugHelper.readNotificationJSON(notification)
        contentTextView.text = jsonString

        copyButton.isEnabled = true
        simulateButton.isEnabled = true

        // Scroll para o topo
        contentTextView.setContentOffset(.zero, animated: false)
    }

}

// MARK: - UITableViewDataSource
extension NotificationDebugViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return notifications.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "NotificationCell", for: indexPath)
        let notification = notifications[indexPath.row]

        // Formatar título da célula
        if let timestamp = notification["timestamp"] as? String {
            cell.textLabel?.text = timestamp
        } else {
            cell.textLabel?.text = "Notificação \(indexPath.row + 1)"
        }

        cell.textLabel?.font = UIFont.systemFont(ofSize: 14)
        cell.accessoryType = .disclosureIndicator

        return cell
    }
}

// MARK: - UITableViewDelegate
extension NotificationDebugViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let notification = notifications[indexPath.row]
        selectedNotification = notification
        showNotificationDetails(notification)
    }
}
