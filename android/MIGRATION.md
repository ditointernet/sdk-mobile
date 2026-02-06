# Migração de uso — `sdk_mobile_android` → SDK novo (`/android`)

Este guia explica como migrar do SDK Android antigo (repositório `sdk_mobile_android`) para o SDK Android novo presente neste repositório, no diretório `android/`.

## Escopo

- Migração de **dependência/instalação**
- Configuração de **API_KEY/API_SECRET**
- **Inicialização** do SDK
- Migração de chamadas de **Identify/Track**
- Integração de **Push Notifications (FCM)**:
  - opção simples (somente Dito)
  - opção avançada (múltiplos SDKs) via `DitoNotificationHandler`

## Fontes de referência

- SDK antigo (README): `https://github.com/ditointernet/sdk_mobile_android/blob/main/README.md`
- SDK novo (README): `android/README.md`
- Push + serviço pronto: `android/example-app/FIREBASE_MESSAGING_SETUP.md`
- Múltiplos serviços: `android/docs/MULTIPLE_NOTIFICATION_SERVICES.md`

---

## 1) Dependência / Repositórios

### Antes (SDK antigo)

O SDK antigo era consumido via JitPack:

```gradle
dependencies {
  implementation "com.github.ditointernet:sdk_mobile_android:<VERSAO>"
}
```

### Depois (SDK novo)

O SDK novo é distribuído via **GitHub Packages** (repositório Maven):

1. Configure o repositório do GitHub Packages no `settings.gradle.kts` (nível do projeto), conforme `android/README.md`.
2. Configure credenciais com permissão `read:packages` (via `~/.gradle/gradle.properties` ou variáveis de ambiente).

#### Coordinate da dependência (importante)

O `android/README.md` mostra:

```kotlin
implementation("io.github.ditointernet:ditosdk:1.0.0")
```

Porém, a publicação do módulo `dito-sdk` neste repositório está configurada com:

- `groupId`: `br.com.dito`
- `artifactId`: `ditosdk`

Portanto, **o coordinate mais compatível com o que o projeto publica é**:

```kotlin
implementation("br.com.dito:ditosdk:<VERSAO>")
```

Se você receber erro do tipo “Could not find …”, valide:

- se o repositório do GitHub Packages está configurado;
- se o token tem `read:packages`;
- qual coordinate foi publicado para a versão que você está usando.

---

## 2) Requisitos mínimos

O SDK novo exige:

- `minSdk` **>= 25**
- Java/Kotlin target **17** (conforme build do SDK)

Se seu app ainda usa `minSdk=24`, será necessário **subir o minSdk** para concluir a migração.

---

## 3) AndroidManifest — credenciais (mantém o padrão)

Assim como no SDK antigo, você deve configurar as credenciais no `AndroidManifest.xml` do app:

```xml
<application>
    <meta-data
        android:name="br.com.dito.API_KEY"
        android:value="SUA_API_KEY" />
    <meta-data
        android:name="br.com.dito.API_SECRET"
        android:value="SEU_API_SECRET" />
</application>
```

---

## 4) Inicialização do SDK

No `Application.onCreate()`:

```kotlin
val options = Options(retry = 5)
options.debug = true
options.iconNotification = R.drawable.ic_notification

Dito.init(this, options)
```

Mudanças relevantes:

- `retry`, `debug`, `iconNotification` continuam existindo.
- `contentIntent` continua existindo para controlar o que abre ao tocar na notificação.
- **Novo**: `notificationClickListener` permite receber o deeplink (`link`) ao tocar na notificação, sem precisar criar uma Activity dedicada.

---

## 5) Migração de API — Identify / Track

### Antes (documentado no SDK antigo)

```kotlin
val identify = Identify("85496430259")
Dito.identify(identify)

Dito.track(Event("comprou", 2.5))
```

### Depois (recomendado pelo README do SDK novo)

#### Identify (API direta)

```kotlin
Dito.identify(
    id = "user123",
    name = "João Silva",
    email = "joao@example.com",
    customData = mapOf(
        "tipo_cliente" to "premium",
        "pontos" to 1500
    )
)
```

#### Track (API direta)

```kotlin
Dito.track(
    action = "purchase",
    data = mapOf(
        "product_id" to "123",
        "price" to 99.99,
        "currency" to "BRL"
    )
)
```

### Compatibilidade para migração gradual

O SDK novo ainda possui overloads para uso com objetos (`Identify`, `Event`), então você pode:

- migrar primeiro a **instalação/configuração**;
- manter chamadas antigas funcionando;
- trocar gradualmente para a API direta (`identify(id, ...)` / `track(action, ...)`).

Observação: o modelo `Event` do SDK novo ainda inclui `revenue`. Se seu app depende explicitamente disso, você pode manter `Event(action, revenue)` durante a migração.

---

## 6) Push Notifications (FCM)

O SDK novo suporta dois modelos. Escolha **apenas um** (o Android permite **um** `FirebaseMessagingService` efetivo).

### Modelo A — Simples (somente Dito, recomendado)

Declare o serviço fornecido pelo SDK no `AndroidManifest.xml` do app:

```xml
<service
    android:name="br.com.dito.ditosdk.notification.DitoMessagingService"
    android:exported="false">
    <intent-filter>
        <action android:name="com.google.firebase.MESSAGING_EVENT" />
    </intent-filter>
</service>
```

O `DitoMessagingService` do SDK gerencia automaticamente:

- registro do token FCM no Dito;
- chamada de `Dito.notificationRead(...)` ao receber push;
- exibição de notificação;
- tracking de abertura e deeplink.

Se você vem do `sdk_mobile_android`, remova do seu `AndroidManifest.xml` qualquer referência ao `NotificationOpenedReceiver`. No SDK novo, o tracking de abertura é feito internamente via `NotificationOpenedActivity` e o deeplink pode ser capturado via `Options.notificationClickListener`.

Se você precisa executar navegação/abertura de navegador quando o usuário tocar no push, configure o callback global:

```kotlin
val options = Options(retry = 5).apply {
  notificationClickListener = { deeplink ->
    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(deeplink))
    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    startActivity(intent)
  }
}

Dito.init(this, options)
```

Guia: `android/example-app/FIREBASE_MESSAGING_SETUP.md`

### Modelo B — Avançado (múltiplos SDKs / lógica customizada)

Se você usa OneSignal, Braze, ou tem lógica própria, mantenha **um único** `FirebaseMessagingService` do app e delegue para o Dito via `DitoNotificationHandler`.

Guia: `android/docs/MULTIPLE_NOTIFICATION_SERVICES.md`

Pontos críticos:

- declare **apenas um** `<service ... com.google.firebase.MESSAGING_EVENT />`;
- remova o `DitoMessagingService` do manifest se estiver usando serviço customizado;
- no seu serviço customizado, use `ditoHandler.canHandle(remoteMessage)` e `ditoHandler.handleNotification(remoteMessage)`.

---

## 7) Permissão de notificação (Android 13+)

No Android 13+ é necessário:

- declarar `POST_NOTIFICATIONS` no manifest (quando aplicável);
- solicitar permissão em runtime na UI do app.

Se “push não aparece”, isso costuma ser o primeiro item a validar.

---

## 8) Checklist final

- [ ] Dependência antiga removida
- [ ] Repositório GitHub Packages configurado e token com `read:packages`
- [ ] Dependência do SDK novo adicionada
- [ ] `minSdk` >= 25
- [ ] `API_KEY` e `API_SECRET` no `AndroidManifest.xml`
- [ ] `Dito.init(...)` no `Application.onCreate()`
- [ ] Identify chamado antes de Track
- [ ] Push: apenas um modelo escolhido (serviço pronto **ou** serviço delegador)
- [ ] Permissão de notificação tratada no Android 13+

