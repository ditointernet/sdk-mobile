# Guia de Migração - DitoSDK 2.0.0+

## 📌 Visão Geral

Este guia ajudará você a migrar seu projeto para a versão 2.0.0 (ou superior) do DitoSDK, que inclui:

- ✅ Suporte completo para iOS 16, 17 e 18
- ✅ Correções de concorrência do CoreData
- ✅ API simplificada para Firebase Cloud Messaging
- ✅ Melhorias de performance e estabilidade

---

## 🚀 Mudanças Principais

### 1. API Firebase-Only (Breaking Change)

**ANTES:**
```swift
Dito.registerDevice(token: fcmToken, tokenType: .firebase)
Dito.unregisterDevice(token: fcmToken, tokenType: .firebase)
```

**AGORA:**
```swift
Dito.registerDevice(token: fcmToken)
Dito.unregisterDevice(token: fcmToken)
```

### 2. CoreData - Thread Safety (iOS 16+)

Todas as operações CoreData agora são thread-safe e executadas em background contexts.

### 3. Firebase Messaging - iOS 18

Ordem correta de inicialização e obtenção de tokens implementada.

### 4. Clique em notificações e deeplink

O deeplink é extraído do campo `link` do `userInfo` e pode ser tratado via callback em `Dito.notificationClick(userInfo:callback:)`.

### 5. Recebimento de notificações (padronização de API)

Para consistência com Android, o método recomendado para rastrear o recebimento de push passou a ser `notificationReceived(userInfo:token:)`.

**Antes (Deprecated):**
```swift
Dito.notificationRead(userInfo: userInfo, token: fcmToken)
```

**Agora (Recomendado):**
```swift
Dito.notificationReceived(userInfo: userInfo, token: fcmToken)
```

**Compatibilidade (Deprecated):** para facilitar a migração de código antigo, ainda existem overloads marcados como deprecated, por exemplo:

- `Dito.notificationReceived(with:token:)`
- `Dito.notificationRead(userInfo:token:)` e `Dito.notificationRead(with:token:)`
- `Dito.notificationClick(with:callback:)`

---

## 📋 Checklist de Migração

### Passo 1: Atualizar o Podfile

```ruby
# Atualize para a versão mais recente
pod 'DitoSDK', '~> 3.0.1'
```

Execute:
```bash
pod update DitoSDK
```

---

### Passo 2: Atualizar AppDelegate

#### 2.1 Ordem de Inicialização

```swift
import UIKit
import DitoSDK
import FirebaseCore
import FirebaseMessaging
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // ✅ 1. Configure Firebase PRIMEIRO
        FirebaseApp.configure()

        // ✅ 2. Configure Messaging delegate
        Messaging.messaging().delegate = self

        // ✅ 3. Configure Dito SDK
        Dito.shared.configure()

        // ✅ 4. Setup notifications
        UNUserNotificationCenter.current().delegate = self
        registerForPushNotifications(application: application)

        return true
    }
}
```

#### 2.2 Configuração APNS → FCM

```swift
func application(_ application: UIApplication,
                 didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {

    // ✅ CRÍTICO: Configure APNS token no Firebase ANTES de solicitar FCM token
    Messaging.messaging().apnsToken = deviceToken

    // ✅ Agora solicite o FCM token
    Messaging.messaging().token { [weak self] fcmToken, error in
        if let error = error {
            print("Error fetching FCM token: \(error)")
        } else if let fcmToken = fcmToken {
            print("FCM token: \(fcmToken)")

            // ✅ API SIMPLIFICADA - sem tokenType
            Dito.registerDevice(token: fcmToken)
        }
    }
}
```

#### 2.3 Implementar MessagingDelegate

```swift
extension AppDelegate: MessagingDelegate {
    /// Chamado quando o token FCM é renovado
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("FCM token atualizado: \(fcmToken ?? "nil")")

        if let fcmToken = fcmToken {
            // ✅ Atualizar token no Dito SDK
            Dito.registerDevice(token: fcmToken)
        }
    }
}
```

---

### Passo 3: Remover Parâmetro `tokenType`

#### Encontre e Substitua

**Buscar por:**
```swift
Dito.registerDevice(token:.*tokenType:
Dito.unregisterDevice(token:.*tokenType:
```

**Exemplos de Substituição:**

```swift
// ❌ ANTES
Dito.registerDevice(token: token, tokenType: .firebase)
Dito.registerDevice(token: token, tokenType: .apple)
Dito.unregisterDevice(token: token, tokenType: .firebase)

// ✅ DEPOIS
Dito.registerDevice(token: token)
Dito.registerDevice(token: token)
Dito.unregisterDevice(token: token)
```

---

### Passo 4: Atualizar Info.plist

Certifique-se de que seu `Info.plist` contém:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Suas chaves Dito -->
    <key>ApiKey</key>
    <string>SUA_API_KEY_AQUI</string>
    <key>ApiSecret</key>
    <string>SEU_API_SECRET_AQUI</string>

    <!-- Bundle Version - OBRIGATÓRIO -->
    <key>CFBundleVersion</key>
    <string>1</string>

    <!-- Background Modes para notificações -->
    <key>UIBackgroundModes</key>
    <array>
        <string>remote-notification</string>
    </array>
</dict>
</plist>
```

---

### Passo 5: Configurar Firebase

#### 5.1 GoogleService-Info.plist

Certifique-se de ter o arquivo `GoogleService-Info.plist` no projeto.

#### 5.2 Firebase Console

1. Acesse [Firebase Console](https://console.firebase.google.com)
2. Vá para **Project Settings** > **Cloud Messaging**
3. Configure o certificado APNS:
   - Upload do certificado `.p8` (recomendado)
   - Ou certificado `.p12`

---

## 🔧 Problemas Comuns e Soluções

### Problema 1: "APNS device token not set before retrieving FCM Token"

**Causa:** Tentando obter FCM token antes do APNS token estar configurado.

**Solução:**
```swift
// ✅ Configure APNS token PRIMEIRO
Messaging.messaging().apnsToken = deviceToken

// ✅ DEPOIS solicite FCM token
Messaging.messaging().token { token, error in
    // ...
}
```

---

### Problema 2: Warnings de Deprecation

**Mensagem:**
```
'registerDevice(token:tokenType:)' is deprecated: Use registerDevice(token:) instead
```

**Solução:**
```swift
// ❌ Código antigo
Dito.registerDevice(token: fcmToken, tokenType: .firebase)

// ✅ Código novo
Dito.registerDevice(token: fcmToken)
```

---

### Problema 3: CoreData Thread-Safety Crash (iOS 16+)

**Erro:**
```
NSManagedObjectContext concurrency violation
```

**Solução:** Atualizar para DitoSDK 2.0.0+ (já corrigido internamente)

---

### Problema 4: Notificações não Recebidas

**Checklist:**
- [ ] `GoogleService-Info.plist` está no projeto?
- [ ] Bundle ID corresponde ao Firebase Console?
- [ ] Certificado APNS está configurado no Firebase?
- [ ] Permissões de notificação foram concedidas?
- [ ] Token FCM foi registrado com sucesso?

**Debug:**
```swift
// Verificar configuração de notificações
UNUserNotificationCenter.current().getNotificationSettings { settings in
    print("Authorization Status: \(settings.authorizationStatus.rawValue)")
    // 0 = notDetermined, 1 = denied, 2 = authorized
}
```

---

## 📱 Implementação Completa de Referência

### AppDelegate.swift Completo

```swift
import UIKit
import DitoSDK
import FirebaseCore
import FirebaseMessaging
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var fcmToken: String?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Configure Firebase
        FirebaseApp.configure()
        Messaging.messaging().delegate = self

        // Configure Dito SDK
        Dito.shared.configure()

        // Setup notifications
        UNUserNotificationCenter.current().delegate = self
        requestNotificationPermissions(application: application)

        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {

        // Configure APNS token no Firebase
        Messaging.messaging().apnsToken = deviceToken

        // Obter FCM token
        Messaging.messaging().token { [weak self] fcmToken, error in
            if let error = error {
                print("❌ Error fetching FCM token: \(error)")
            } else if let fcmToken = fcmToken {
                self?.fcmToken = fcmToken
                print("✅ FCM token: \(fcmToken)")

                // Registrar no Dito SDK
                Dito.registerDevice(token: fcmToken)
            }
        }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error)")
    }

    private func requestNotificationPermissions(application: UIApplication) {
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]

        UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, error in
            if let error = error {
                print("❌ Notification authorization error: \(error)")
                return
            }

            guard granted else {
                print("⚠️ Notification authorization denied")
                return
            }

            print("✅ Notification authorization granted")

            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension AppDelegate: UNUserNotificationCenterDelegate {

    // Notificação recebida com app em foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo

        // Rastrear recebimento no Dito
        if let token = fcmToken {
            Dito.notificationReceived(userInfo: userInfo, token: token)
        }

        // Notificar Firebase
        Messaging.messaging().appDidReceiveMessage(userInfo)

        // Mostrar notificação
        completionHandler([[.banner, .list, .sound, .badge]])
    }

    // Notificação tocada pelo usuário
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo

        // Rastrear clique no Dito e extrair deeplink
        let notification = Dito.notificationClick(userInfo: userInfo)

        // Processar deeplink se houver
        if !notification.deeplink.isEmpty {
            print("📱 Deeplink: \(notification.deeplink)")
            // Navegar para a tela apropriada
        }

        // Notificar Firebase
        Messaging.messaging().appDidReceiveMessage(userInfo)

        completionHandler()
    }
}

// MARK: - MessagingDelegate
extension AppDelegate: MessagingDelegate {

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("🔄 FCM token atualizado: \(fcmToken ?? "nil")")

        if let fcmToken = fcmToken {
            self.fcmToken = fcmToken
            Dito.registerDevice(token: fcmToken)
        }
    }
}
```

---

## 🧪 Testes Pós-Migração

### Teste 1: Compilação

```bash
# Limpar build
rm -rf ~/Library/Developer/Xcode/DerivedData

# Build
xcodebuild clean build -workspace SeuProjeto.xcworkspace -scheme SeuScheme
```

### Teste 2: Tokens

Execute o app e verifique os logs:

```
✅ Esperado:
APNS Device Token: <hex-token>
FCM registration token: <fcm-token>
```

❌ **NÃO deve aparecer:**
```
APNS device token not set before retrieving FCM Token
```

### Teste 3: Notificações

1. **Enviar notificação de teste via Firebase Console**
2. **Verificar que notificação é recebida:**
   - [ ] App em foreground
   - [ ] App em background
   - [ ] App fechado
3. **Verificar que Dito registra a leitura**

### Teste 4: Identificação e Tracking

```swift
// Identificar usuário
let user = DitoUser(name: "Teste", email: "teste@example.com")
Dito.identify(id: "USER_ID", data: user)

// Track evento
let event = DitoEvent(action: "app-opened")
Dito.track(event: event)
```

---

## 📊 Compatibilidade

### Versões iOS Suportadas

| iOS Version | Status | Notas |
|------------|--------|-------|
| iOS 16.0+ | ✅ Suportado | Deployment target mínimo |
| iOS 16.x | ✅ Suportado | CoreData thread-safety corrigido |
| iOS 17.x | ✅ Suportado | Otimizado |
| iOS 18.x | ✅ Suportado | Firebase integration corrigida |

### Dependências

```ruby
# Podfile
platform :ios, '16.0'

target 'SeuApp' do
  use_frameworks!

  pod 'DitoSDK', '~> 3.0.1'
  pod 'Firebase/Messaging'  # Obrigatório
  pod 'Firebase/Analytics'  # Recomendado
end
```

---

## 🔄 Rollback (Se Necessário)

Se encontrar problemas e precisar reverter:

### Opção 1: Versão Anterior

```ruby
# Podfile
pod 'DitoSDK', '~> 1.1.1'  # Versão anterior
```

```bash
pod update DitoSDK
```

---

## 📞 Suporte

### Problemas Conhecidos

Consulte os documentos:
- `IOS18_MIGRATION_NOTES.md` - Detalhes iOS 18
- `COREDATA_IOS16_FIXES.md` - Detalhes CoreData
- `MIGRATION_FIREBASE_ONLY.md` - Detalhes API Firebase

### Relatar Problemas

1. **GitHub Issues**: https://github.com/ditointernet/sdk-mobile/issues
2. **Incluir:**
   - Versão do iOS
   - Versão do DitoSDK
   - Logs completos
   - Código relevante

---

## ✅ Checklist Final

- [ ] Podfile atualizado para DitoSDK 3.0.1+
- [ ] `pod update DitoSDK` executado
- [ ] Ordem de inicialização corrigida (Firebase → Messaging → Dito)
- [ ] APNS token configurado antes de FCM token
- [ ] `tokenType` removido de todas as chamadas
- [ ] `MessagingDelegate` implementado
- [ ] Info.plist com `CFBundleVersion`
- [ ] Firebase configurado corretamente
- [ ] Testes de compilação passando
- [ ] Testes de notificação funcionando
- [ ] Sem warnings de deprecation
- [ ] Sem erros de thread-safety

---

## 🎯 Resumo

### O Que Mudou

1. **API Simplificada**: `registerDevice(token:)` sem `tokenType`
2. **CoreData Thread-Safe**: iOS 16+ compatível
3. **Firebase iOS 18**: Ordem correta de tokens

### Tempo Estimado de Migração

- **Projeto Simples**: 15-30 minutos
- **Projeto Médio**: 30-60 minutos
- **Projeto Complexo**: 1-2 horas

### Principais Benefícios

- ✅ Estabilidade em iOS 16+
- ✅ Compatibilidade com iOS 18
- ✅ API mais limpa e simples
- ✅ Melhor performance
- ✅ Thread-safety garantida

---

**Data de Lançamento:** Novembro 2025
**Versão:** DitoSDK 2.0.0
**Suporte:** iOS 16.0+

**🚀 Boa migração!**
