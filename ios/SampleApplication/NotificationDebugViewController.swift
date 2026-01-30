import UIKit
import DitoSDK

class NotificationDebugViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
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

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeTapped)
        )

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 16

        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])

        countLabel.font = .boldSystemFont(ofSize: 16)
        countLabel.translatesAutoresizingMaskIntoConstraints = false

        refreshButton.setTitle("Atualizar", for: .normal)
        refreshButton.addTarget(self, action: #selector(refreshTapped), for: .touchUpInside)
        refreshButton.translatesAutoresizingMaskIntoConstraints = false

        latestButton.setTitle("Última", for: .normal)
        latestButton.addTarget(self, action: #selector(latestTapped), for: .touchUpInside)
        latestButton.translatesAutoresizingMaskIntoConstraints = false

        let buttonStack = UIStackView(arrangedSubviews: [refreshButton, latestButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 8
        buttonStack.distribution = .fillEqually
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "NotificationCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.layer.cornerRadius = 8
        tableView.heightAnchor.constraint(equalToConstant: 200).isActive = true

        let listContainer = UIStackView(arrangedSubviews: [countLabel, buttonStack, tableView])
        listContainer.axis = .vertical
        listContainer.spacing = 12
        listContainer.translatesAutoresizingMaskIntoConstraints = false

        contentTextView.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        contentTextView.backgroundColor = UIColor.systemGray6
        contentTextView.layer.cornerRadius = 8
        contentTextView.text = "Selecione uma notificação para ver o conteúdo"
        contentTextView.isEditable = false
        contentTextView.translatesAutoresizingMaskIntoConstraints = false
        contentTextView.heightAnchor.constraint(equalToConstant: 200).isActive = true

        copyButton.setTitle("Copiar JSON", for: .normal)
        copyButton.addTarget(self, action: #selector(copyTapped), for: .touchUpInside)
        copyButton.isEnabled = false
        copyButton.translatesAutoresizingMaskIntoConstraints = false

        simulateButton.setTitle("Simular Esta Notificação", for: .normal)
        simulateButton.addTarget(self, action: #selector(simulateTapped), for: .touchUpInside)
        simulateButton.isEnabled = false
        simulateButton.translatesAutoresizingMaskIntoConstraints = false

        let actionsContainer = UIStackView(arrangedSubviews: [copyButton, simulateButton])
        actionsContainer.axis = .vertical
        actionsContainer.spacing = 12
        actionsContainer.translatesAutoresizingMaskIntoConstraints = false

        contentStack.addArrangedSubview(createCard(title: "Notificações Salvas", contentView: listContainer))
        contentStack.addArrangedSubview(createCard(title: "Conteúdo", contentView: contentTextView))
        contentStack.addArrangedSubview(createCard(title: "Ações", contentView: actionsContainer))
    }

    private func createCard(title: String, contentView: UIView) -> UIView {
        let cardView = UIView()
        cardView.backgroundColor = .secondarySystemBackground
        cardView.layer.cornerRadius = 8
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.1
        cardView.layer.shadowOffset = CGSize(width: 0, height: 2)
        cardView.layer.shadowRadius = 4
        cardView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .boldSystemFont(ofSize: 18)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let cardStack = UIStackView(arrangedSubviews: [titleLabel, contentView])
        cardStack.axis = .vertical
        cardStack.spacing = 12
        cardStack.translatesAutoresizingMaskIntoConstraints = false

        cardView.addSubview(cardStack)

        NSLayoutConstraint.activate([
            cardStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            cardStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            cardStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            cardStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16)
        ])

        return cardView
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
