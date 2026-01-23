# Análise de Nomenclatura - iOS SDK

**Data**: 2025-01-27
**SDK**: iOS DitoSDK
**Localização**: `ios/DitoSDK/Sources/Controllers/Dito.swift`

## API Pública Atual

### Classe Principal

**Classe**: `Dito`
**Tipo**: `public class` com singleton pattern
**Instância**: `Dito.shared`

### Métodos Públicos Estáticos

#### 1. Inicialização

```swift
public func configure()
```
- **Descrição**: Configura o SDK, inicializa monitoramento de rede e retry
- **Parâmetros**: Nenhum
- **Retorno**: `Void`
- **Nota**: Usa `Dito.shared.configure()` ou pode ser configurado via Info.plist (DitoApiKey, DitoApiSecret)

#### 2. Identificação de Usuário

```swift
nonisolated public static func identify(id: String, data: DitoUser)
```
- **Descrição**: Identifica um usuário no CRM Dito
- **Parâmetros**:
  - `id`: String - Identificador único do usuário
  - `data`: DitoUser - Dados do usuário (name, email, gender, birthday, location, customData)
- **Retorno**: `Void`
- **Modelo**: `DitoUser` (struct com propriedades opcionais)

#### 3. Tracking de Eventos

```swift
nonisolated public static func track(event: DitoEvent)
```
- **Descrição**: Registra um evento no CRM Dito
- **Parâmetros**:
  - `event`: DitoEvent - Evento a ser registrado
- **Retorno**: `Void`
- **Modelo**: `DitoEvent` (struct com action, revenue, createdAt, customData)

#### 4. Registro de Token de Dispositivo

```swift
nonisolated public static func registerDevice(token: String)
```
- **Descrição**: Registra um token FCM para push notifications
- **Parâmetros**:
  - `token`: String - Token FCM do Firebase Messaging
- **Retorno**: `Void`

#### 5. Desregistro de Token de Dispositivo

```swift
nonisolated public static func unregisterDevice(token: String)
```
- **Descrição**: Remove registro de um token FCM
- **Parâmetros**:
  - `token`: String - Token FCM a ser removido
- **Retorno**: `Void`

#### 6. Leitura de Notificação

```swift
nonisolated public static func notificationRead(
    with userInfo: [AnyHashable: Any],
    token: String
)
```
- **Descrição**: Chamado quando uma notificação chega (antes do clique)
- **Parâmetros**:
  - `userInfo`: Dictionary com dados da notificação
  - `token`: String - Token FCM
- **Retorno**: `Void`
- **Comportamento**: Identifica usuário automaticamente e registra evento "receive-ios-notification"

#### 7. Clique em Notificação

```swift
nonisolated public static func notificationClick(
    with userInfo: [AnyHashable: Any],
    callback: ((String) -> Void)? = nil
) -> DitoNotificationReceived
```
- **Descrição**: Chamado quando usuário interage com notificação
- **Parâmetros**:
  - `userInfo`: Dictionary com dados da notificação
  - `callback`: Closure opcional que recebe deeplink
- **Retorno**: `DitoNotificationReceived` - Objeto com dados da notificação processada

#### 8. Utilitário SHA1

```swift
nonisolated public static func sha1(for email: String) -> String
```
- **Descrição**: Calcula hash SHA1 de um email
- **Parâmetros**:
  - `email`: String - Email a ser hasheado
- **Retorno**: `String` - Hash SHA1 do email

### Modelos de Dados

#### DitoUser
```swift
public struct DitoUser: Codable, Sendable {
    let name: String?
    let gender: String?
    let email: String?
    let birthday: String?
    let location: String?
    let createdAt: String?
    let data: String?
}
```

#### DitoEvent
```swift
public struct DitoEvent: Codable, Sendable {
    let action: String?
    let revenue: Double?
    let createdAt: String?
    let data: String?
}
```

### Padrões de Nomenclatura Observados

1. **Métodos**: camelCase (Swift convention)
2. **Parâmetros nomeados**: Usa labels explícitos (`id:`, `data:`, `with:`, `token:`)
3. **Métodos estáticos**: `nonisolated public static func`
4. **Singleton**: `Dito.shared` para acesso à instância
5. **Modelos**: Prefixo `Dito` (DitoUser, DitoEvent)
6. **Notificações**: Métodos específicos (`notificationRead`, `notificationClick`)

### Observações

- iOS usa objetos estruturados (DitoUser, DitoEvent) em vez de parâmetros individuais
- `configure()` é método de instância, não estático
- Métodos de notificação têm assinaturas diferentes do Android
- `notificationClick` retorna objeto e aceita callback opcional
