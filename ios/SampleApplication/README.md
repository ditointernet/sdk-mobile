# Sample Application - iOS

Este é o aplicativo de exemplo do Dito SDK para iOS.

## Configuração

### Dados Básicos no Info.plist

Assim como no Android (que usa `env_development_local.txt` em `res/raw/`), o sample app iOS utiliza o `Info.plist` para armazenar dados básicos de configuração para testes.

#### Dados Disponíveis

O `Info.plist` contém as seguintes chaves de configuração:

**API Credentials:**
- `ApiKey`: Chave de API do Dito
- `ApiSecret`: Secret da API do Dito

**Identify Data (dados para testar o método `identify`):**
- `IDENTIFY_ID`: ID do usuário (exemplo: "11111111111")
- `IDENTIFY_NAME`: Nome do usuário (exemplo: "John Doe")
- `IDENTIFY_EMAIL`: Email do usuário (exemplo: "john.doe@example.com")
- `IDENTIFY_CUSTOM_DATA`: Dados customizados em JSON (exemplo: `{"age": 30, "city": "São Paulo"}`)

**Track Data (dados para testar o método `track`):**
- `TRACK_ACTION`: Nome da ação (exemplo: "purchase")
- `TRACK_DATA`: Dados do evento em JSON (exemplo: `{"product_id": "123", "price": 99.99}`)

### Como Acessar os Dados

#### Usando InfoPlistHelper

O helper `InfoPlistHelper` (definido no `ViewController.swift`) facilita o acesso aos dados:

```swift
// Carregar todas as configurações
let config = InfoPlistHelper.loadSampleAppConfig()

// Acessar valores específicos
let identifyId = config["IDENTIFY_ID"]
let identifyName = config["IDENTIFY_NAME"]
let identifyEmail = config["IDENTIFY_EMAIL"]

// Parsear JSON
if let customDataJSON = config["IDENTIFY_CUSTOM_DATA"],
   let customData = InfoPlistHelper.parseJSON(customDataJSON) {
    print("Custom data: \(customData)")
}
```

#### Acesso Direto ao Bundle

Você também pode acessar diretamente via Bundle:

```swift
if let identifyId = Bundle.main.object(forInfoDictionaryKey: "IDENTIFY_ID") as? String {
    print("ID: \(identifyId)")
}
```

### Exemplo de Uso no ViewController

O `ViewController.swift` já está configurado para usar os dados do Info.plist:

```swift
class ViewController: UIViewController {
    // Carregar configurações do Info.plist
    private let config = InfoPlistHelper.loadSampleAppConfig()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Preencher campos com dados padrão do Info.plist
        loadDefaultValues()
    }

    private func loadDefaultValues() {
        // Preencher email padrão do Info.plist
        if let defaultEmail = config["IDENTIFY_EMAIL"] {
            fieldEmail?.text = defaultEmail
        }

        print("✓ Dados padrão carregados do Info.plist")
    }

    func handleIndentifyClick() {
        // Usar nome do Info.plist
        let userName = config["IDENTIFY_NAME"] ?? "Dito user teste"

        // Parse custom data do Info.plist
        var customData: [String: Any]?
        if let customDataJSON = config["IDENTIFY_CUSTOM_DATA"] {
            customData = InfoPlistHelper.parseJSON(customDataJSON)
        }

        // Identifica no Dito usando a nova API (consistente com Android)
        Dito.identify(
            id: userId,
            name: userName,
            email: email,
            customData: customData
        )
    }

    func handleNotificationClick() {
        // Usar dados do Info.plist para o track
        let action = config["TRACK_ACTION"] ?? "teste-behavior"

        var eventData: [String: Any] = ["id_loja": 123]
        if let trackDataJSON = config["TRACK_DATA"],
           let trackData = InfoPlistHelper.parseJSON(trackDataJSON) {
            eventData = trackData
        }

        // Dispara o evento usando a nova API (consistente com Android)
        Dito.track(action: action, data: eventData)
    }
}
```

## Comparação com Android

| Android | iOS |
|---------|-----|
| `res/raw/env_development_local.txt` | `Info.plist` |
| `EnvLoader.kt` carrega do arquivo | `InfoPlistHelper.swift` carrega do plist |
| Formato: `KEY=value` | Formato: XML plist |
| Acesso via `context.resources` | Acesso via `Bundle.main` |

## Estrutura de Arquivos

```
SampleApplication/
├── Info.plist                 # Configurações e dados básicos
├── ViewController.swift       # Controller principal (inclui InfoPlistHelper)
├── EnvLoader.swift            # (Legado) Carrega .env files
├── AppDelegate.swift          # Delegate do app
├── SceneDelegate.swift        # Delegate de cena
└── AnalyticsHelper.swift      # Helper de analytics
```

## Mudanças Recentes (2026-01-28)

### ✅ Implementado

1. **Info.plist atualizado** com dados básicos de teste (paridade com Android)
2. **InfoPlistHelper.swift criado** para facilitar acesso aos dados
3. **ViewController.swift atualizado** para:
   - Carregar dados do Info.plist automaticamente
   - Usar a nova API `identify(id:name:email:customData:)` (consistente com Android)
   - Usar a nova API `track(action:data:)` (consistente com Android)
   - Preencher campos automaticamente com dados padrão

### 🔧 APIs Atualizadas

**Antes (deprecated):**
```swift
let user = DitoUser(name: "...", email: "...")
Dito.identify(id: userId, data: user)
Dito.track(event: DitoEvent(action: "...", customData: [:]))
```

**Agora (recomendado):**
```swift
Dito.identify(id: userId, name: "...", email: "...", customData: [:])
Dito.track(action: "...", data: [:])
```

### 🎯 Benefícios

- ✅ Paridade total com Android
- ✅ APIs consistentes entre plataformas
- ✅ Dados de teste centralizados no Info.plist
- ✅ Sem warnings de deprecação
- ✅ Código mais limpo e direto

## Notas

- Os dados no `Info.plist` são apenas para desenvolvimento/testes
- Em produção, use variáveis de ambiente ou configuração segura
- O `EnvLoader.swift` ainda existe para compatibilidade com arquivos `.env.development.local` se você preferir usá-los
