# Mapeamento de Nomenclatura Padrão

**Data**: 2025-01-27
**Objetivo**: Definir nomenclatura consistente entre iOS e Android SDKs após refatoração

## Princípios de Padronização

1. **Consistência Conceitual**: Mesmos conceitos devem ter mesmos nomes
2. **Convenções de Plataforma**: Respeitar convenções de cada linguagem (Swift/Kotlin)
3. **Backward Compatibility**: Manter compatibilidade durante transição
4. **Clareza**: Nomes devem ser auto-explicativos

## Mapeamento de Métodos Principais

### 1. Inicialização

| Conceito | iOS Atual | Android Atual | Padrão Proposto |
|----------|-----------|---------------|-----------------|
| Inicialização | `Dito.shared.configure()` | `Dito.init(context, options)` | **Manter diferenças de plataforma** |

**Decisão**: Manter diferenças porque:
- iOS usa singleton pattern (`shared`) e pode configurar via Info.plist
- Android requer Context e Options explicitamente
- Ambos são idiomas nativos de suas plataformas

**Padrão Final**:
- **iOS**: `Dito.shared.configure()` (sem parâmetros, lê de Info.plist)
- **Android**: `Dito.init(context: Context?, options: Options?)`

### 2. Identificação de Usuário

| Conceito | iOS Atual | Android Atual | Padrão Proposto |
|----------|-----------|---------------|-----------------|
| Identificação | `Dito.identify(id:data:)` | `Dito.identify(identify, callback)` | **Padronizar assinatura** |

**Decisão**: Padronizar para aceitar parâmetros individuais em ambas plataformas

**Padrão Final**:
- **iOS**: `Dito.identify(id: String, name: String?, email: String?, customData: [String: Any]?)`
- **Android**: `Dito.identify(id: String, name: String?, email: String?, customData: Map<String, Any>?)`

**Nota**: Manter objetos DitoUser/Identify como alternativas para compatibilidade

### 3. Tracking de Eventos

| Conceito | iOS Atual | Android Atual | Padrão Proposto |
|----------|-----------|---------------|-----------------|
| Tracking | `Dito.track(event:)` | `Dito.track(event)` | **Padronizar assinatura** |

**Decisão**: Padronizar para aceitar action e data diretamente

**Padrão Final**:
- **iOS**: `Dito.track(action: String, data: [String: Any]?)`
- **Android**: `Dito.track(action: String, data: Map<String, Any>?)`

**Nota**: Manter objetos DitoEvent/Event como alternativas para compatibilidade

### 4. Registro de Token

| Conceito | iOS Atual | Android Atual | Padrão Proposto |
|----------|-----------|---------------|-----------------|
| Registro | `Dito.registerDevice(token:)` | `Dito.registerDevice(token)` | ✅ **Já consistente** |

**Padrão Final**: Manter como está
- **iOS**: `Dito.registerDevice(token: String)`
- **Android**: `Dito.registerDevice(token: String?)`

### 5. Desregistro de Token

| Conceito | iOS Atual | Android Atual | Padrão Proposto |
|----------|-----------|---------------|-----------------|
| Desregistro | `Dito.unregisterDevice(token:)` | `Dito.unregisterDevice(token)` | ✅ **Já consistente** |

**Padrão Final**: Manter como está
- **iOS**: `Dito.unregisterDevice(token: String)`
- **Android**: `Dito.unregisterDevice(token: String?)`

### 6. Leitura de Notificação

| Conceito | iOS Atual | Android Atual | Padrão Proposto |
|----------|-----------|---------------|-----------------|
| Leitura | `Dito.notificationRead(with:token:)` | `Dito.notificationRead(notification, reference)` | **Padronizar assinatura** |

**Decisão**: Padronizar para receber userInfo/dictionary em ambas

**Padrão Final**:
- **iOS**: `Dito.notificationRead(userInfo: [AnyHashable: Any], token: String)` (manter token separado)
- **Android**: `Dito.notificationRead(userInfo: Map<String, String>)` (extrair notification e reference de userInfo)

**Nota**: Android precisa adaptar para aceitar Map em vez de parâmetros separados

### 7. Clique em Notificação

| Conceito | iOS Atual | Android Atual | Padrão Proposto |
|----------|-----------|---------------|-----------------|
| Clique | `Dito.notificationClick(with:callback:)` | ❌ Não existe | **Adicionar no Android** |

**Decisão**: Adicionar método equivalente no Android

**Padrão Final**:
- **iOS**: `Dito.notificationClick(userInfo: [AnyHashable: Any], callback: ((String) -> Void)?) -> DitoNotificationReceived`
- **Android**: `Dito.notificationClick(userInfo: Map<String, String>, callback: ((String) -> Unit)?) -> NotificationResult`

## Mapeamento de Modelos de Dados

### Identify / DitoUser

| Propriedade | iOS (DitoUser) | Android (Identify) | Padrão |
|-------------|-----------------|-------------------|--------|
| ID | Parâmetro separado | Propriedade obrigatória | **Manter diferença** |
| Name | `name: String?` | `name: String?` | ✅ Consistente |
| Email | `email: String?` | `email: String?` | ✅ Consistente |
| Gender | `gender: String?` | `gender: String?` | ✅ Consistente |
| Birthday | `birthday: String?` | `birthday: String?` | ✅ Consistente |
| Location | `location: String?` | `location: String?` | ✅ Consistente |
| Custom Data | `data: String?` (JSON) | `data: CustomData?` | **Padronizar para Map/Dictionary** |
| Created At | `createdAt: String?` | `createdAt: String?` | ✅ Consistente |

### Event / DitoEvent

| Propriedade | iOS (DitoEvent) | Android (Event) | Padrão |
|-------------|-----------------|-----------------|--------|
| Action | `action: String?` | `action: String` (obrigatório) | **Padronizar como obrigatório** |
| Revenue | `revenue: Double?` | `revenue: Double?` | ✅ Consistente |
| Custom Data | `data: String?` (JSON) | `data: CustomData?` | **Padronizar para Map/Dictionary** |
| Created At | `createdAt: String?` | `createdAt: String?` | ✅ Consistente |

## Estratégia de Refatoração

### Fase 1: Adicionar Novos Métodos (Não Breaking)

1. **iOS**: Adicionar sobrecargas que aceitam parâmetros individuais
   - `Dito.identify(id:name:email:customData:)` (nova)
   - `Dito.track(action:data:)` (nova)
   - Manter métodos antigos funcionando

2. **Android**: Adicionar sobrecargas que aceitam parâmetros individuais
   - `Dito.identify(id: String, name: String?, email: String?, customData: Map<String, Any>?)` (nova)
   - `Dito.track(action: String, data: Map<String, Any>?)` (nova)
   - Adicionar `Dito.notificationClick(userInfo: Map<String, String>, callback: ((String) -> Unit)?)`
   - Manter métodos antigos funcionando

### Fase 2: Deprecar Métodos Antigos

1. Marcar métodos antigos como `@available(*, deprecated)` (iOS) ou `@Deprecated` (Android)
2. Adicionar mensagens de migração apontando para novos métodos
3. Manter funcionalidade por pelo menos 2 versões major

### Fase 3: Remover Métodos Antigos (Futuro)

1. Após período de depreciação adequado
2. Remover métodos antigos
3. Atualizar documentação

## Resumo de Mudanças Necessárias

### iOS SDK

**Adicionar**:
- `Dito.identify(id:name:email:customData:)` - Nova assinatura com parâmetros individuais
- `Dito.track(action:data:)` - Nova assinatura com parâmetros diretos

**Manter (deprecated)**:
- `Dito.identify(id:data:)` - Marcar como deprecated
- `Dito.track(event:)` - Marcar como deprecated

**Atualizar**:
- `Dito.notificationRead(with:token:)` - Renomear parâmetro `with` para `userInfo`

### Android SDK

**Adicionar**:
- `Dito.identify(id: String, name: String?, email: String?, customData: Map<String, Any>?)` - Nova assinatura
- `Dito.track(action: String, data: Map<String, Any>?)` - Nova assinatura
- `Dito.notificationClick(userInfo: Map<String, String>, callback: ((String) -> Unit)?)` - Novo método
- `Dito.notificationRead(userInfo: Map<String, String>)` - Nova assinatura

**Manter (deprecated)**:
- `Dito.identify(identify: Identify?, callback: (() -> Unit)?)` - Marcar como deprecated
- `Dito.track(event: Event?)` - Marcar como deprecated
- `Dito.notificationRead(notification: String?, reference: String?)` - Marcar como deprecated

## Compatibilidade com Wrappers

Os wrappers Flutter e React Native devem usar as **novas assinaturas padronizadas**:
- Parâmetros individuais em vez de objetos
- Nomes consistentes entre plataformas
- Tratamento de erros uniforme

## Notas de Implementação

1. **Backward Compatibility**: Manter métodos antigos funcionando durante período de transição
2. **Documentação**: Atualizar todos os READMEs e exemplos
3. **Testes**: Garantir que testes antigos continuem passando
4. **Migração**: Criar guia de migração para desenvolvedores usando APIs antigas
