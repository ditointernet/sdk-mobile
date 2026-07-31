## 📚 API Reference

### Dito.shared.configure()

Inicializa o DitoSDK. **Deve ser chamado no AppDelegate**.

```swift
// No AppDelegate, após FirebaseApp.configure()
Dito.shared.configure()
```

- ✅ Carrega credenciais do Info.plist
- ✅ Inicializa gerenciador de persistência offline
- ✅ Inicia monitor de conectividade

**Erro comum**: Chamar `Dito.shared.configure()` ANTES de `FirebaseApp.configure()` causará erro

---

### Dito.identify(id:data:)

**Identifica um usuário na plataforma Dito.**

Deve ser chamado assim que você sabe quem é o usuário (após login, por exemplo).

#### Parâmetros

- `id` (String): ID único do usuário SHA1 (normalmente hash do email)
- `data` (DitoUser): Dados completos do usuário

#### Exemplo

```swift
import DitoSDK

// Crie um usuário com dados completos
let customData = [
    "tipo_cliente": "premium",
    "pontos": 1500
]

let user = DitoUser(
    name: "João Silva",
    gender: .masculino,
    email: "joao@example.com",
    birthday: Date(timeIntervalSince1970: 0), // Data de nascimento
    location: "São Paulo",
    createdAt: Date(),
    customData: customData
)

// Identifique o usuário
let userId = Dito.sha1(for: "joao@example.com") // Converte email para SHA1
Dito.identify(id: userId, data: user)

print("✅ Usuário identificado")
```

#### Dados disponíveis

```swift
let user = DitoUser(
    name: String,              // Nome completo
    gender: DitoGender,        // .masculino, .feminino ou .outro
    email: String,             // Email
    birthday: Date?,           // Data de nascimento
    location: String?,         // Localização
    createdAt: Date?,          // Data de criação
    customData: [String: Any]? // Dados customizados (JSON)
)
```

#### ⚠️ Importante

- Sempre identifique o usuário antes de rastrear eventos
- Use SHA1 do email como ID (veja `Dito.sha1(for:)`)
- Os dados são sincronizados automaticamente com a plataforma

**Documentação Dito**: [User Identification](https://docs.dito.com.br/sdk-ios/identificacao)

---

### Dito.track(event:)

**Rastreia eventos e comportamentos do usuário.**

Use para registrar qualquer ação importante no seu app.

#### Parâmetros

- `event` (DitoEvent): O evento a ser rastreado

#### Exemplo

```swift
import DitoSDK

// Evento simples
let event = DitoEvent(action: "tela_visualizada")
Dito.track(event: event)

// Evento com dados customizados
let purchaseEvent = DitoEvent(
    action: "compra_realizada",
    customData: [
        "produto_id": "123",
        "produto_nome": "Tênis Nike",
        "preco": 299.90,
        "categoria": "Esportes",
        "quantidade": 1
    ]
)
Dito.track(event: purchaseEvent)

// Exemplo de eventos comuns
let viewEvent = DitoEvent(action: "produto_visualizado", customData: ["id": "456"])
let addToCartEvent = DitoEvent(action: "item_adicionado_carrinho", customData: ["valor": 50.00])
let checkoutEvent = DitoEvent(action: "checkout_iniciado", customData: ["itens": 3])

Dito.track(event: viewEvent)
Dito.track(event: addToCartEvent)
Dito.track(event: checkoutEvent)
```

#### Dados de Evento

```swift
let event = DitoEvent(
    action: String,            // Nome da ação (obrigatório)
    customData: [String: Any]? // Dados adicionais em JSON
)
```

#### Exemplos de ações comuns

```
// E-commerce
"produto_visualizado"
"adicionar_carrinho"
"remover_carrinho"
"checkout_iniciado"
"compra_realizada"
"compra_cancelada"

// App
"tela_visualizada"
"botao_clicado"
"formulario_enviado"
"login"
"logout"
"compartilhamento"

// Notificações
"receive-ios-notification" (automático)
```

#### ⚠️ Importante

- Sempre identifique o usuário antes de rastrear eventos
- Os dados são sincronizados automaticamente
- Em offline, os eventos são salvos e sincronizados quando online

**Documentação Dito**: [Event Tracking](https://docs.dito.com.br/sdk-ios/rastreamento-eventos)

---

### Dito.sha1(for:)

**Converte uma string (normalmente email) para SHA1.**

O SHA1 é usado como ID único do usuário para identificação.

#### Parâmetros

- `email` (String): String a ser convertida (normalmente email)

#### Retorno

- (String): Hash SHA1 da string

#### Exemplo

```swift
import DitoSDK

let email = "joao@example.com"
let sha1Hash = Dito.sha1(for: email)

print("Email: \(email)")
print("SHA1: \(sha1Hash)") // Exemplo: "a1b2c3d4e5f6..."

// Use o SHA1 para identificar
Dito.identify(id: sha1Hash, data: userData)
```

#### ⚠️ Importante

- O SHA1 é determinístico: o mesmo email sempre gera o mesmo SHA1
- Use sempre o mesmo email para manter consistência
- O SHA1 não pode ser revertido (é hash criptográfico)

---

### Dito.registerDevice(token:)

**Registra o token FCM do dispositivo para receber notificações push.**

Normalmente é chamado automaticamente quando o Firebase atualiza o token.

#### Parâmetros

- `token` (String): Token FCM obtido do Firebase

#### Exemplo

```swift
import FirebaseMessaging
import DitoSDK

// No MessagingDelegate
extension AppDelegate: MessagingDelegate {
    func messaging(
        _ messaging: Messaging,
        didReceiveRegistrationToken fcmToken: String?
    ) {
        guard let fcmToken = fcmToken else { return }

        print("🔑 Novo token FCM: \(fcmToken)")

        // Registra o token no Dito
        Dito.registerDevice(token: fcmToken)
    }
}
```

#### ⚠️ Importante

- Chamada automaticamente via `MessagingDelegate`
- Você pode chamar manualmente se necessário
- Para `Dito.notificationReceived` em **background** ou cold start, recomenda-se **persistir** o token FCM (por exemplo em `UserDefaults`) na primeira obtenção e quando o Firebase o alterar, e reutilizar esse valor quando `fcmToken` em memória ainda for `nil`
- O token é persistido automaticamente

**Documentação Firebase**: [Get Registration Token](https://firebase.google.com/docs/cloud-messaging/ios/client#retrieve_the_current_registration_token)

---

### Dito.unregisterDevice(token:)

**Cancela o registro do token FCM.**

Use quando o usuário faz logout ou desinstal o app.

#### Parâmetros

- `token` (String): Token FCM a ser desregistrado

#### Exemplo

```swift
import DitoSDK

// Ao fazer logout
func handleLogout() {
    Messaging.messaging().token { fcmToken, error in
        if let fcmToken = fcmToken {
            Dito.unregisterDevice(token: fcmToken)
        }
    }
}
```

---

## 🔔 Push Notifications

O DitoSDK oferece suporte completo para notificações push via Firebase Cloud Messaging (FCM).

> **Imagem e botões (rich push) não estão nesta página.** Eles são produzidos por uma
> Notification Service Extension, que é um target do app e não uma chamada de API —
> nada aqui os habilita. O roteiro está em
> [README — Rich Push](README.md#-rich-push-imagem-botões-e-custom-data).

### Fluxo de Notificações

Existem 4 cenários diferentes quando uma notificação é recebida:

#### 1️⃣ App em Foreground (Visível)

```
Notificação Chega
    ↓
willPresent() chamado
    ↓
Banner mostrado (iOS 14+)
    ↓
Usuário clica
    ↓
didReceive() chamado
```

#### 2️⃣ App em Background

```
Notificação Chega
    ↓
(armazenada na bandeja do sistema)
    ↓
Usuário clica no banner
    ↓
didReceive() chamado
    ↓
didReceiveRemoteNotification() chamado
```

#### 3️⃣ App Encerrado (push só com alert, sem content-available)

```
Notificação Chega
    ↓
(armazenada na bandeja do sistema)
    ↓
Usuário clica no banner
    ↓
App inicia
    ↓
didReceive() chamado → receive-ios-notification (no toque)
```

#### 4️⃣ App encerrado/background com content-available (recomendado)

```
Notificação Chega (aps.content-available: 1)
    ↓
didReceiveRemoteNotification() chamado
    ↓
Dito.notificationReceived → receive-ios-notification (sem abrir o app)
```

#### 5️⃣ Silent Notification (sem UI)

```
Notificação Chega (sem alert)
    ↓
didReceiveRemoteNotification() chamado
    ↓
SDK envia receive-ios-notification
```

### Métodos de Notificação do Dito

#### Dito.notificationReceived(userInfo:token:completion:)

**Registra quando uma notificação é RECEBIDA (não clicada).**

Deve ser chamado quando a notificação chega, ANTES do clique do usuário.

O envio do track automático `receive-ios-notification` ao ingest **requer** `user_id` ou `userId` no `userInfo` (topo, `data` ou `gcm`; string ou número). Sem isso, o SDK persiste na inbox local (`Dito.shared.getNotifications()`). Em background, use o parâmetro `completion` para chamar `fetchCompletionHandler` somente após o ingest (ou persistência offline) terminar.

> `notificationRead(with:token:)` permanece disponível, mas está **deprecated** — use `notificationReceived`.

#### Parâmetros

- `userInfo` ([AnyHashable: Any]): Dados da notificação
- `token` (String): Token FCM do dispositivo
- `completion` ((Result<Void, Error>) -> Void)?, opcional): Callback ao final do processamento

#### Exemplos

```swift
// Quando notificação chega em foreground
func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler:
        @escaping (UNNotificationPresentationOptions) -> Void
) {
    let userInfo = notification.request.content.userInfo

    let token = fcmToken ?? UserDefaults.standard.string(forKey: "FCMToken") ?? ""
    if !token.isEmpty {
        Dito.notificationReceived(userInfo: userInfo, token: token)
    } else {
        Messaging.messaging().token { fcmToken, _ in
            if let fcmToken = fcmToken {
                Dito.notificationReceived(userInfo: userInfo, token: fcmToken)
            }
        }
    }

    completionHandler([[.banner, .list, .sound, .badge]])
}

// Quando notificação chega em background (content-available)
func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
) {
    let token = fcmToken ?? UserDefaults.standard.string(forKey: "FCMToken") ?? ""
    guard !token.isEmpty else {
        completionHandler(.noData)
        return
    }
    Dito.notificationReceived(userInfo: userInfo, token: token) { result in
        switch result {
        case .success:
            completionHandler(.newData)
        case .failure:
            completionHandler(.failed)
        }
    }
}

// Quando usuário clica no banner
func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
) {
    let userInfo = response.notification.request.content.userInfo

    Messaging.messaging().token { fcmToken, _ in
        if let fcmToken = fcmToken {
            Dito.notificationReceived(userInfo: userInfo, token: fcmToken)
        }
    }

    Dito.notificationClick(response: response) { deeplink in
        // processe o deeplink
    }

    completionHandler()
}
```

#### Dados capturados

```swift
// O Dito automaticamente registra:
[
    "titulo": "Seu Título",
    "mensagem": "Sua Mensagem",
    "notificacao_id": "01K9D3247BYF6ME8X1RPNT2VRN",
    "usuario_id": "a24696993af35a5190a0f7f41a7e508bf87a11eb",
    "referencia": "19302a24696993af35a5190a0f7f41a7e508bf87a11eb",
    "link": "app://deeplink",
    "canal": "DITO",
    "dispositivo": "APPLE IPHONE"
]
```

---

#### Dito.notificationClick(response:callback:)

**Registra quando uma notificação é CLICADA.**

Chamado quando o usuário toca no banner **ou num botão de rich push**.

> **Passe a `response`, não o `userInfo`.** É o `response.actionIdentifier` que a SDK
> mapeia de volta para o botão declarado no payload. As sobrecargas
> `notificationClick(userInfo:)` e `notificationClick(with:)` — esta última
> **deprecated** — registram um clique simples: os botões aparecem na notificação, mas
> `action_id` e `action_label` chegam vazios ao painel. Use `userInfo:` só quando não
> houver `response`, e nesse caso passe também o `actionIdentifier`.

#### Parâmetros

- `response` (UNNotificationResponse): A resposta entregue pelo `UNUserNotificationCenterDelegate`
- `callback` ((String) -> Void)?: Closure com o link do botão tocado, ou o deeplink do push quando o toque foi no corpo (opcional)

#### Retorno

- (DitoNotificationReceived): Dados da notificação processados

#### Exemplo

```swift
// Quando usuário CLICA na notificação
func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
) {
    // Registra o clique. A `response` carrega qual botão foi tocado.
    let notificationData = Dito.notificationClick(response: response) { deeplink in
        // Callback com o deeplink
        print("🔗 Deeplink: \(deeplink)")

        // Processe o deeplink para navegar
        if !deeplink.isEmpty {
            self.handleDeeplink(deeplink)
        }
    }

    // Acesse os dados da notificação
    print("📱 Notificação: \(notificationData.notification)")
    print("👤 Usuário: \(notificationData.identifier)")

    completionHandler()
}

// Função para processar deeplink
func handleDeeplink(_ deeplink: String) {
    // Exemplo: app://produtos/123
    if let url = URL(string: deeplink) {
        // Navegue para a tela apropriada
    }
}
```

#### Dados retornados

> `reference` deixou de ser lido do payload: o campo está em retirada e a
> atribuição ancora em `user_id`. `DitoNotificationInfo.reference` continua a
> existir marcado como deprecated e devolve sempre `""`.

```swift
let notification: DitoNotificationReceived = [
    "notification": "ID da notificação",
    "identifier": "ID do usuário",
    "title": "Título",
    "message": "Mensagem",
    "deeplink": "app://link",
    "deviceType": "APPLE IPHONE",
    "channel": "DITO",
    "notificationName": "Nome da campanha"
]
```

---

### Exemplo Completo: Tratamento de Notificações

```swift
import UIKit
import Firebase
import FirebaseMessaging
import DitoSDK
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate, MessagingDelegate {
    var fcmToken: String?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // 1. Firebase
        FirebaseApp.configure()

        // 2. Messaging
        Messaging.messaging().delegate = self

        // 3. Dito
        Dito.shared.configure()

        // 4. Notificações
        UNUserNotificationCenter.current().delegate = self
        registerForPushNotifications(application: application)

        return true
    }

    private func registerForPushNotifications(application: UIApplication) {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, error in
            guard granted else {
                print("⚠️ Notificações não autorizadas")
                return
            }
            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
            }
        }
    }

    // MARK: - Remote Notifications

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        let token = fcmToken ?? UserDefaults.standard.string(forKey: "FCMToken") ?? ""
        guard !token.isEmpty else {
            completionHandler(.noData)
            return
        }
        Dito.notificationReceived(userInfo: userInfo, token: token) { result in
            switch result {
            case .success:
                completionHandler(.newData)
            case .failure:
                completionHandler(.failed)
            }
        }
    }
}

// MARK: - Notification Delegate

extension AppDelegate: UNUserNotificationCenterDelegate {

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler:
            @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        print("🔔 Notificação em foreground: \(userInfo)")

        completionHandler([[.banner, .list, .sound, .badge]])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        // Notificação foi clicada
        Messaging.messaging().token { [weak self] fcmToken, error in
            if let fcmToken = fcmToken {
                Dito.notificationReceived(userInfo: userInfo, token: fcmToken)

                let notification = Dito.notificationClick(
                    userInfo: userInfo
                ) { deeplink in
                    print("🔗 Deeplink: \(deeplink)")
                }

                print("✅ Notificação processada: \(notification.notification)")
            }
        }

        completionHandler()
    }
}

// MARK: - Messaging Delegate

extension AppDelegate: MessagingDelegate {

    func messaging(
        _ messaging: Messaging,
        didReceiveRegistrationToken fcmToken: String?
    ) {
        guard let fcmToken = fcmToken else { return }

        print("🔑 FCM Token: \(fcmToken)")
        self.fcmToken = fcmToken

        // Registra no Dito
        Dito.registerDevice(token: fcmToken)
    }
}
```
