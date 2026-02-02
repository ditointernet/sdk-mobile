import SwiftUI

struct NotificationDebugView: View {
    @StateObject private var viewModel = NotificationDebugViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    notificationListCard
                    contentCard
                    actionsCard
                }
                .padding()
            }
            .navigationTitle("🔔 Debug de Notificações")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fechar") {
                        dismiss()
                    }
                }
            }
            .toast(isShowing: $viewModel.showToast, message: viewModel.toastMessage)
        }
    }

    private var notificationListCard: some View {
        CardView(title: "Notificações Salvas") {
            VStack(spacing: 12) {
                Text("Total de notificações salvas: \(viewModel.notificationCount)")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    Button(action: { viewModel.refresh() }) {
                        Text("Atualizar")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button(action: { viewModel.selectLatest() }) {
                        Text("Última")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                if viewModel.notifications.isEmpty {
                    Text("Nenhuma notificação salva")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 40)
                } else {
                    notificationsList
                }
            }
        }
    }

    private var notificationsList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(viewModel.notifications.enumerated()), id: \.offset) { index, notification in
                    let isSelected = areNotificationsEqual(notification, viewModel.selectedNotification)

                    Button(action: {
                        viewModel.selectNotification(notification)
                    }) {
                        HStack {
                            Text(notificationTitle(for: notification, index: index))
                                .font(.body.weight(isSelected ? .semibold : .regular))
                                .foregroundColor(isSelected ? .accentColor : .primary)
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.body)
                                    .foregroundColor(.accentColor)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 12)
                        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
                    }

                    if index < viewModel.notifications.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .background(Color(uiColor: .systemGray6))
        .cornerRadius(12)
    }

    private func areNotificationsEqual(_ notification1: [String: Any]?, _ notification2: [String: Any]?) -> Bool {
        guard let notif1 = notification1, let notif2 = notification2 else {
            return false
        }

        let timestamp1 = notif1["timestamp"] as? String
        let timestamp2 = notif2["timestamp"] as? String

        return timestamp1 == timestamp2 && timestamp1 != nil
    }

    private var contentCard: some View {
        CardView(title: "Conteúdo") {
            ScrollView {
                Text(viewModel.selectedJSON)
                    .font(.system(.footnote, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(8)
            }
            .background(Color(uiColor: .systemGray6))
            .cornerRadius(12)
        }
    }

    private var actionsCard: some View {
        CardView(title: "Ações") {
            VStack(spacing: 12) {
                Button(action: { viewModel.copyJSON() }) {
                    Text("Copiar JSON")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.selectedNotification == nil)

                Button(action: { viewModel.simulate() }) {
                    Text("Simular Esta Notificação")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.selectedNotification == nil)
            }
        }
    }

    private func notificationTitle(for notification: [String: Any], index: Int) -> String {
        if let timestamp = notification["timestamp"] as? String {
            return timestamp
        }
        return "Notificação \(index + 1)"
    }
}

#Preview {
    NotificationDebugView()
}
