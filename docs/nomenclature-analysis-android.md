# Análise de Nomenclatura - Android SDK

**Data**: 2025-01-27
**SDK**: Android Dito SDK
**Localização**: `android/dito-sdk/src/main/java/br/com/dito/ditosdk/Dito.kt`

## API Pública Atual

### Classe Principal

**Classe**: `Dito`
**Tipo**: `object` (singleton em Kotlin)
**Acesso**: Direto via `Dito.method()`

### Métodos Públicos

#### 1. Inicialização

```kotlin
fun init(context: Context?, options: Options?)
```
- **Descrição**: Inicializa o SDK com contexto e opções
- **Parâmetros**:
  - `context`: Context? - Contexto da aplicação Android
  - `options`: Options? - Opções de configuração (retry, contentIntent, iconNotification, debug)
- **Retorno**: `Unit`
- **Nota**: Lê API_KEY e API_SECRET do AndroidManifest.xml

#### 2. Identificação de Usuário

```kotlin
fun identify(identify: Identify?, callback: (() -> Unit)?)
```
- **Descrição**: Identifica um usuário no CRM Dito
- **Parâmetros**:
  - `identify`: Identify? - Objeto com dados do usuário (id obrigatório, name, email, gender, location, birthday, customData opcionais)
  - `callback`: Closure opcional executado após identificação
- **Retorno**: `Unit`
- **Modelo**: `Identify` (data class com id obrigatório)

#### 3. Tracking de Eventos

```kotlin
fun track(event: Event?)
```
- **Descrição**: Registra um evento no CRM Dito
- **Parâmetros**:
  - `event`: Event? - Evento a ser registrado (action obrigatório, revenue, createdAt, customData opcionais)
- **Retorno**: `Unit`
- **Modelo**: `Event` (data class com action obrigatório)

#### 4. Registro de Token de Dispositivo

```kotlin
fun registerDevice(token: String?)
```
- **Descrição**: Registra um token FCM para push notifications
- **Parâmetros**:
  - `token`: String? - Token FCM do Firebase Messaging
- **Retorno**: `Unit`

#### 5. Desregistro de Token de Dispositivo

```kotlin
fun unregisterDevice(token: String?)
```
- **Descrição**: Remove registro de um token FCM
- **Parâmetros**:
  - `token`: String? - Token FCM a ser removido
- **Retorno**: `Unit`

#### 6. Leitura de Notificação

```kotlin
fun notificationRead(notification: String?, reference: String?)
```
- **Descrição**: Registra leitura de uma notificação
- **Parâmetros**:
  - `notification`: String? - ID da notificação
  - `reference`: String? - Referência do usuário
- **Retorno**: `Unit`
- **Nota**: Retorna early se reference estiver vazio

#### 7. Modo Híbrido

```kotlin
fun getHibridMode(): String
```
- **Descrição**: Retorna modo híbrido configurado
- **Parâmetros**: Nenhum
- **Retorno**: `String` - "ON" ou "OFF"

### Constantes Públicas

```kotlin
const val DITO_NOTIFICATION_ID = "br.com.dito.ditosdk.DITO_NOTIFICATION_ID"
const val DITO_NOTIFICATION_REFERENCE = "br.com.dito.ditosdk.DITO_NOTIFICATION_REFERENCE"
const val DITO_DEEP_LINK = "br.com.dito.ditosdk.DITO_DEEP_LINK"
```

### Propriedades Públicas

```kotlin
var options: Options? = null
```

### Modelos de Dados

#### Options
```kotlin
data class Options(val retry: Int = 5) {
    var contentIntent: Intent? = null
    @IdRes var iconNotification: Int? = null
    var debug: Boolean = false
}
```

#### Identify
```kotlin
data class Identify(@Expose(serialize = false) val id: String) {
    var name: String? = null
    var email: String? = null
    var gender: String? = null
    var location: String? = null
    var birthday: String? = null
    @SerializedName("created_at")
    var createdAt: String? = Date().formatToISO()
    @Expose(serialize = false)
    var data: CustomData? = null
}
```

#### Event
```kotlin
data class Event(val action: String, val revenue: Double? = null) {
    @SerializedName("created_at")
    var createdAt: String? = Date().formatToISO()
    @Expose(serialize = false)
    var data: CustomData? = null
}
```

### Padrões de Nomenclatura Observados

1. **Métodos**: camelCase (Kotlin convention)
2. **Parâmetros**: Sem labels explícitos (Kotlin convention)
3. **Métodos**: Funções diretas no object (sem static)
4. **Singleton**: `object` em Kotlin (acesso direto)
5. **Modelos**: Sem prefixo (Identify, Event, Options)
6. **Nullable**: Uso extensivo de tipos nullable (`String?`, `Identify?`)
7. **Callbacks**: Suporte a closures opcionais

### Observações

- Android usa parâmetros diretos em vez de objetos estruturados para alguns métodos
- `init()` requer Context e Options, diferente do iOS
- `identify()` aceita callback opcional, iOS não tem callback
- `track()` não tem callback, iOS também não
- `notificationRead()` tem assinatura diferente do iOS (recebe String, String em vez de Dictionary)
- Não há método equivalente ao `notificationClick` do iOS na API pública
- Modo híbrido é específico do Android
