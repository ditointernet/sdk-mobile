# Playbook: integração assistida da SDK Dito

Este arquivo é operado por um LLM com acesso a shell e edição de arquivos, dentro do
projeto que vai receber a SDK. Ele não é um tutorial para humano ler de cima a baixo:
é um roteiro de execução com fases, gates e critérios de parada.

O objetivo é uma integração que **funciona no caminho difícil** — push tocado com o app
encerrado, imagem e botões renderizando, evento chegando ao painel — e não apenas uma
que compila.

---

## Dois atores

| Ator | Faz |
| --- | --- |
| **LLM** (você) | reconhece o terreno, entrevista, propõe o plano, aplica as mudanças aprovadas, verifica, relata |
| **Pessoa** | fornece credenciais, aprova o plano, opera o aparelho, dispara campanha no painel, decide escopo |

Você **nunca** obtém credenciais Dito sozinho, nunca decide o escopo sozinho, e nunca
edita arquivo antes do gate da Fase 2.

---

## O que este playbook prova, e o que não prova

**Prova:** que a dependência está resolvida na versão certa; que as credenciais estão
onde a SDK realmente as lê, inclusive no processo que sobe a partir de um push;
que a inicialização acontece; que `identify`/`track` saem; que o app compila e roda.

**Não prova:** que a campanha chega. Entrega e clique reais dependem de painel,
Firebase/APNs e modo de entrega do brand — coisas fora do app. Para isso, encerre
apontando para:

- [`playbook/run-local-test.md`](run-local-test.md) — push simulado, sem painel
- [`playbook/run-prod-test.md`](run-prod-test.md) — push real disparado do painel de produção

---

## Regras de execução

1. **Nada de escrita antes da Fase 2 aprovada.** Fases 0 e 1 são leitura, shell
   read-only e conversa. Se você editar um arquivo antes do gate, o playbook falhou.
2. **Não invente API.** Toda assinatura de método, nome de chave e coordenada de
   dependência tem que ser confirmada contra o README da plataforma na versão que
   você está instalando (links no fim). Se não achou, diga que não achou — não
   deduza pelo nome.
3. **Credencial nunca entra em commit.** Nem em código, nem em manifest hardcoded,
   nem no relatório, nem no chat em texto integral. O caminho é placeholder +
   `local.properties` / `.env` / variável de ambiente, tudo em `.gitignore`.
   Ao registrar evidência, mascare: `abc1…f9`.
4. **Versão não se chuta.** As quatro plataformas versionam separado e as versões
   não coincidem. Resolva a mais recente no registry na hora (Fase 3-A). Nunca
   copie um número deste arquivo.
5. **Uma fase, um gate.** Ao fim de cada fase aplique, verifique, e diga em uma
   linha o que ficou provado. Se a verificação falhou, pare ali — não empilhe fase
   sobre fundação quebrada.
6. **Diff mínimo.** Toque só nos arquivos do plano. Não formate, não atualize
   dependência alheia, não "melhora enquanto está aqui". Se algo fora do plano
   precisa mudar, volte ao gate.
7. **Toda suposição é declarada.** Se você seguiu sem resposta da pessoa, diga qual
   suposição usou e onde ela é reversível.

---

# Fase 0 — Reconhecimento do terreno

Só leitura. Ao fim desta fase você entrega uma **ficha do terreno** e passa para a
entrevista — mas a entrevista só pergunta o que aqui não ficou respondido. Perguntar o
que está escrito no `pubspec.yaml` queima a paciência de quem está te ajudando.

## 0-A · Que tipo de projeto é este

A ordem importa. Um projeto Flutter e um React Native **também** têm `android/` e
`ios/` dentro — quem checa "existe `build.gradle`?" primeiro classifica errado.

```bash
# 1) Flutter — pubspec.yaml com dependência em flutter
test -f pubspec.yaml && grep -qE '^\s{2}flutter:' pubspec.yaml && echo "FLUTTER"

# 2) React Native — package.json com react-native
test -f package.json && grep -q '"react-native"' package.json && echo "REACT_NATIVE"

# 3) É o monorepo da própria SDK?
test -f DitoSDK.podspec && test -d flutter && test -d react-native && echo "SDK_MONOREPO"

# 4) Nativo Android
ls settings.gradle settings.gradle.kts 2>/dev/null

# 5) Nativo iOS
ls -d *.xcodeproj *.xcworkspace 2>/dev/null; test -f Podfile && echo "tem Podfile"
```

Resolva o veredito por esta tabela:

| Sinal | Veredito | SDK a instalar |
| --- | --- | --- |
| `pubspec.yaml` com `flutter:` | Flutter | `dito_sdk` (pub.dev) + config nativa nos dois lados |
| `package.json` com `react-native` | React Native | `@ditointernet/dito-sdk` (npm) + config nativa nos dois lados |
| `DitoSDK.podspec` na raiz + `flutter/` + `react-native/` | monorepo da SDK | **nenhuma** — veja 0-A.1 |
| só Gradle/Kotlin | Android nativo | `br.com.dito:ditosdk` (Maven Central) |
| só Xcode/Podfile/`Package.swift` | iOS nativo | `DitoSDK` (CocoaPods ou SPM) |
| `app.json`/`app.config.*` com `expo`, **sem** `ios/`+`android/` | Expo managed | veja 0-A.2 |
| Cordova, Capacitor, Unity, KMP, .NET MAUI | **fora de escopo** | pare e diga (veja 0-A.3) |

> Um projeto Flutter ou RN é **sempre dois projetos nativos também**. A SDK que você
> instala pelo `pubspec`/`package.json` é uma casca: quem faz o trabalho é a SDK
> Android e a SDK iOS embaixo. Todo passo nativo deste playbook continua valendo, e é
> exatamente onde as integrações híbridas falham.

### 0-A.1 · Se você está dentro do monorepo da SDK

Você não está integrando: está validando. Diga isso e ofereça o que faz sentido —
rodar um sample app existente (`flutter/sample_application`, `android/example-app`,
`ios/SampleApplication`), ou os playbooks de teste. Não instale a SDK sobre ela mesma.

### 0-A.2 · Expo managed

Sem `ios/` e `android/` no repo não há onde pôr credencial nativa, `AppDelegate` ou
Notification Service Extension — e a SDK Dito precisa dos três. Diga à pessoa que o
caminho é `npx expo prebuild` (sai do managed) ou um config plugin que escreva essas
mudanças. Não tente integrar por cima do managed workflow: a próxima build regenera
as pastas nativas e apaga tudo que você fez.

### 0-A.3 · Fora de escopo

A SDK Dito publica para Android, iOS, Flutter e React Native. Para qualquer outro
runtime, pare e diga: não há pacote oficial, e improvisar um wrapper não é o que a
pessoa pediu. Ofereça a alternativa honesta (API HTTP da Dito, ou pedir suporte ao
time da SDK).

## 0-B · O que já existe de Dito aqui

Muita "integração nova" é, na verdade, uma integração meia-feita. Descubra antes de
propor:

```bash
# dependência declarada em qualquer lugar
grep -rniE "dito_sdk|ditosdk|br\.com\.dito|@ditointernet" \
  --include=pubspec.yaml --include=package.json --include=Podfile \
  --include=*.gradle --include=*.gradle.kts --include=*.podspec . 2>/dev/null

# credenciais Android (fonte — o manifest mesclado vem na Fase 4-E)
grep -rn "br.com.dito.API_KEY\|br.com.dito.API_SECRET\|HIBRID_MODE" \
  --include=AndroidManifest.xml . 2>/dev/null

# credenciais iOS
grep -rn "AppKey\|AppSecret\|ApiKey\|ApiSecret" --include=Info.plist . 2>/dev/null

# chamadas de init/identify/track já no código
grep -rniE "Dito\.(init|configure|shared)|DitoSdk\(\)|ditoSdk\.initialize|DitoSdk\.initialize" \
  --include=*.kt --include=*.java --include=*.swift \
  --include=*.dart --include=*.ts --include=*.tsx --include=*.js . 2>/dev/null

# NSE já criada?
find . -name "*.appex" -o -name "NotificationService.swift" 2>/dev/null | grep -v build
```

Se achou `ApiKey`/`ApiSecret` no `Info.plist`: **está quebrado hoje**, mesmo que
alguém jure que funciona. A SDK iOS lê `AppKey`/`AppSecret`. Os nomes antigos
estiveram neste README até a 3.5.0 e a SDK nunca os leu — e a inicialização com chave
vazia desiste **em silêncio**. Registre como achado da Fase 0, não como detalhe.

## 0-C · Firebase, permissão e o resto do terreno

```bash
# Firebase presente?
find . \( -name "google-services.json" -o -name "GoogleService-Info.plist" \) \
  -not -path "*/build/*" 2>/dev/null
grep -rn "com.google.gms.google-services" --include=*.gradle --include=*.gradle.kts . 2>/dev/null

# concorrência por FirebaseMessagingService (só um por app no Android)
grep -rn "FirebaseMessagingService" --include=AndroidManifest.xml --include=*.kt --include=*.java . 2>/dev/null
grep -rniE "onesignal|braze|appboy|clevertap|urbanairship|airship|firebase_messaging|@react-native-firebase" \
  --include=pubspec.yaml --include=package.json --include=*.gradle* . 2>/dev/null

# pisos de versão
grep -rn "minSdk\|compileSdk" --include=*.gradle --include=*.gradle.kts . 2>/dev/null | grep -v build/
grep -rn "IPHONEOS_DEPLOYMENT_TARGET\|platform :ios" --include=Podfile --include=project.pbxproj . 2>/dev/null | head
swift --version 2>/dev/null; xcodebuild -version 2>/dev/null | head -2
flutter --version 2>/dev/null | head -1
node --version 2>/dev/null

# estado do repo — você vai mexer nele
git status --short | head -30
git rev-parse --abbrev-ref HEAD
```

Pisos que a SDK exige, e que reprovam **build**, não só funcionalidade:

| Plataforma | Piso | O que acontece abaixo dele |
| --- | --- | --- |
| Android | API 25 (26 via Flutter) | `minSdk` menor não resolve a dependência |
| iOS | iOS 16, Xcode 15.3, Swift 5.10 | a SDK usa `nonisolated(unsafe)`; em Xcode 14 **não compila** |
| Flutter | Flutter 3.24, Dart 3.10.7 | falha no `pub get`/análise |
| React Native | RN 0.72, React 18, Node 16 | falha no autolinking |

Se um piso não bate, isso é um item de plano ("subir `minSdk` de 23 para 25"), com
o custo dito em voz alta — e é decisão da pessoa, não sua.

## 0-D · Ficha do terreno

Devolva assim, curto:

```
FICHA DO TERRENO
Projeto:        Flutter 3.27.1 (Dart 3.6.0) — android/ e ios/ presentes
Já tem Dito?    não
Firebase:       google-services.json ✓ | GoogleService-Info.plist ✗
Push hoje:      firebase_messaging 15.1.3 declarado, sem FirebaseMessagingService custom
Pisos:          minSdk 24 ❌ (precisa 26) | iOS deployment 13.0 ❌ (precisa 16.0) | Xcode 16.2 ✓
Repo:           branch feature/dito, 3 arquivos modificados não commitados
Fora do padrão: —
```

E liste separado o que você **não** conseguiu determinar. Isso é a pauta da entrevista.

---

# Fase 1 — Entrevista

Só o que a Fase 0 não respondeu. Pergunte em bloco, não uma a uma.

### Q1 · Plataformas desta rodada
Em Flutter/RN, Android e iOS podem entrar em rodadas separadas — e é comum, porque
iOS exige aparelho físico e conta de developer. Uma só é resposta válida.

### Q2 · Até onde vai o escopo
Cada nível inclui o anterior. Fases não escolhidas são **puladas explicitamente** no
relatório, nunca silenciosamente.

| Nível | Entrega | Fases |
| --- | --- | --- |
| **1 — Base** | dependência, credenciais, init, `identify`, `track` | 3, 4 |
| **2 — Push simples** | recebe push, evento de entrega sai | + 5 |
| **3 — Push rico** | imagem e botões (iOS: NSE obrigatória) | + 6 |
| **4 — Clique e deeplink** | toque no corpo e no botão navegam, e registram | + 6 completa |

### Q3 · Credenciais Dito
Precisa de `API_KEY`, e `API_SECRET` **se** o brand usa o modelo legado. Sem secret a
SDK autentica por `X-Api-Key` + package name / bundle id — é um modo suportado, não um
erro. Pergunte: qual ambiente (produção/staging), e **como** a credencial deve entrar
neste repo:

| Caminho | Quando |
| --- | --- |
| `local.properties` + `manifestPlaceholders` (Android) / `.xcconfig` (iOS) | padrão, e o que a Fase 4 assume |
| variável de ambiente lida no build | CI |
| hardcoded no manifest | só app de teste descartável — diga que é dívida |

Se a pessoa não tem a credencial em mãos: **pare antes da Fase 4**. Faça a Fase 3
(dependência), que não depende de segredo, e diga que o resto está bloqueado.

### Q4 · Onde inicializar
Você precisa do ponto de entrada real do app, não do que a documentação supõe:
`Application` custom? `AppDelegate` ou `@main` SwiftUI? `main()` do Dart? `index.js`?
Já existe outro SDK inicializando ali, e em que ordem?

### Q5 · Push que já existe
Se o app já usa `firebase_messaging`, `@react-native-firebase/messaging`, OneSignal,
Braze ou CleverTap, isso é **o** ponto de atrito da integração, não um detalhe: o
Android aceita **um** `FirebaseMessagingService` por app. Ou a Dito recebe o
`MESSAGING_EVENT`, ou o outro recebe. Coexistir exige um serviço delegador.

### Q6 · Identidade do usuário
`identify(id, …)` precisa de um id estável do seu lado. Qual campo é? Existe usuário
anônimo? Em que momento do fluxo (login? splash?) o id fica disponível? Chamar
`track` antes de `identify` produz evento sem dono.

### Q7 · Aparelho para verificar
Emulador/simulador prova build, init e evento. **Não** prova push real: iOS exige
aparelho físico e `aps-environment`, e um bundle assinado com
`CODE_SIGNING_ALLOWED=NO` não tem entitlement nenhum. Escopo ≥ 2 sem aparelho iOS
físico = a verificação do iOS fica parcial, e isso vai no relatório.

### Q8 · Autonomia
Padrão deste playbook: **você aplica as mudanças depois do plano aprovado**, fase por
fase, com gate. Alternativa: você só produz os diffs e a pessoa aplica. Em repo de
cliente com regra de code review, confirme qual dos dois.

---

# Fase 2 — O plano · GATE

Devolva **um** plano e **espere confirmação explícita**. Sem "posso começar?" enquanto
já edita. Formato:

```
PLANO DE INTEGRAÇÃO — Dito SDK
Projeto:   Flutter 3.27.1 · Android + iOS
Escopo:    nível 3 (push rico) — clique/deeplink FICA FORA por escolha
Versões:   dito_sdk <resolvida na 3-A> · nativas vêm transitivas
Bloqueios: nenhum   (ou: API_SECRET pendente → Fase 4 para)

FASE 3 · Dependência e pisos
  pubspec.yaml                              + dito_sdk: ^X.Y.Z
  android/app/build.gradle.kts              minSdk 24 → 26      ⚠️ derruba Android 7
  ios/Podfile                               platform :ios, '16.0' ⚠️ derruba iOS 13-15
  verifica: flutter pub get · pod install · build dos dois lados

FASE 4 · Credenciais
  android/local.properties                  DITO_API_KEY (gitignored)
  android/app/build.gradle.kts              manifestPlaceholders
  android/app/src/main/AndroidManifest.xml  meta-data com ${DITO_API_KEY}
  ios/Runner/Info.plist                     AppKey / AppSecret
  verifica: manifest MESCLADO do APK, não o fonte

FASE 5 · Init e identidade      lib/main.dart
FASE 6 · Push                   ios/NotificationServiceExtension/ (target novo, Xcode)
FASE 7 · Verificação            build + run + evento no painel
FASE 8 · Relatório              artifact HTML

RISCOS
  · subir minSdk/deployment target derruba aparelhos antigos — decisão de produto
  · firebase_messaging já presente: a Dito assume o MESSAGING_EVENT; se o app
    depende de onMessage hoje, precisa de delegador (fora deste plano)
  · o target da NSE exige um passo manual no Xcode — eu não crio target por CLI

REVERSÃO
  git diff antes de cada fase; branch dedicada; Xcode target removido pela UI
```

Regras do plano: todo arquivo tocado aparece nele; todo passo que você **não** pode
fazer sozinho está marcado como manual; todo risco de produto (piso de OS, push
concorrente) está explícito. Se a pessoa cortar escopo, replaneje e volte ao gate.

---

# Fase 3 — Dependência e pisos

## 3-A · Resolver a versão publicada, agora

Não copie número deste arquivo. Cada plataforma tem seu ciclo e elas divergem.

```bash
# Flutter
curl -s https://pub.dev/api/packages/dito_sdk | python3 -c \
  'import json,sys; print(json.load(sys.stdin)["latest"]["version"])'

# React Native
npm view @ditointernet/dito-sdk version

# Android
curl -s "https://search.maven.org/solrsearch/select?q=g:br.com.dito+AND+a:ditosdk&core=gav&rows=5&wt=json" \
  | python3 -c 'import json,sys; [print(d["v"]) for d in json.load(sys.stdin)["response"]["docs"]]'

# iOS
pod search DitoSDK 2>/dev/null | head -20
# ou, mais confiável:
curl -s https://api.github.com/repos/ditointernet/sdk-mobile/tags \
  | grep '"name"' | grep ios-v | head -5
```

Se o registry não responder, **pergunte a versão** — não invente e não caia num
número de exemplo.

## 3-B · Instalar

**Flutter** — `pubspec.yaml`:
```yaml
dependencies:
  dito_sdk: ^X.Y.Z
```
```bash
flutter pub get
```

**React Native**:
```bash
npm install @ditointernet/dito-sdk    # ou yarn add
cd ios && pod install && cd ..        # autolinking traz a SDK iOS
```

**Android nativo** — `settings.gradle.kts` precisa de `mavenCentral()`, e o
`build.gradle.kts` do módulo `app`:
```kotlin
dependencies {
    implementation("br.com.dito:ditosdk:X.Y.Z")
}
```

**iOS nativo** — CocoaPods:
```ruby
pod 'DitoSDK', '~> 3.6'
```
> **Um pin fechado no patch mata o push rico.** `~> 3.0.1` resolve para `< 3.1.0` e
> instala uma SDK **sem Notification Service Extension nenhuma** — o push chega só com
> texto e não há erro. Rich push exige `3.6.0+`. Se você vai fazer a Fase 6, o pin
> mínimo é `~> 3.6`.

SPM: `https://github.com/ditointernet/sdk-mobile`, *Up to Next Major* a partir de
`3.6.0`.

## 3-C · Pisos, se o plano previu

`minSdk` no `build.gradle.kts`; `platform :ios, '16.0'` no `Podfile` **e**
`IPHONEOS_DEPLOYMENT_TARGET` no projeto. Subir piso derruba aparelhos — isso já foi
aprovado no plano, não decida agora.

## 3-D · Gate da Fase 3

Compila com a dependência dentro, e ela está de fato lá:

```bash
# Flutter
flutter pub deps | grep dito_sdk
flutter build apk --debug            # e/ou: flutter build ios --no-codesign

# RN
npm ls @ditointernet/dito-sdk
grep -i dito ios/Podfile.lock

# Android
./gradlew :app:dependencies --configuration debugRuntimeClasspath | grep -i dito

# iOS
grep -A2 -i "DitoSDK" Podfile.lock
```

Prova: *a dependência resolve e o projeto compila com ela*. Nada mais — a SDK ainda
não roda.

---

# Fase 4 — Credenciais

A fase que mais falha, e que falha **em silêncio**. Leia esta seção inteira antes de
editar.

## 4-A · O mapa: onde a SDK realmente lê

| Plataforma | Onde | Chaves |
| --- | --- | --- |
| Android | `AndroidManifest.xml` (`<application>`) | `br.com.dito.API_KEY`, `br.com.dito.API_SECRET` |
| iOS | `Info.plist` **do app** | `AppKey`, `AppSecret` |

São esses nomes exatos. No iOS, `ApiKey`/`ApiSecret` **não** são lidos — se o projeto
tem os nomes antigos, ele roda sem credencial e sem erro visível.

`API_SECRET`/`AppSecret` fora → autenticação `X-Api-Key` com a key + package
name/bundle id. Os dois presentes → modelo legado (`platform_api_key` + assinatura
SHA1). Ambos são modos válidos; escolha combinada na Q3.

## 4-B · Flutter e React Native: a chave no manifest **não é opcional**

Este é o item que mais quebra integração híbrida, e o sintoma engana.

Seu app chama `initialize(appKey:, appSecret:)` no Dart/JS, e você conclui que a
credencial está resolvida. Não está — para o caminho que importa.

Quando o app está **encerrado** e a pessoa toca na notificação, o Android sobe a
`NotificationOpenedActivity` num **processo novo**, onde o Dart/JS que chamaria
`initialize(...)` ainda não rodou. Ela então usa a variante que lê o manifest. Sem a
chave lá, essa chamada lança:

| Toque | Sem a chave no manifest |
| --- | --- |
| **num botão** de ação | funciona — o broadcast não passa pelo tracker |
| **no corpo** da notificação | o clique **não é registrado** |

Quem testa só o botão conclui que está tudo bem. O mesmo vale no iOS: credencial
passada por código só existe no processo que rodou aquele código; num cold start por
push a única fonte é o `Info.plist`.

**Regra: em Flutter, RN ou qualquer híbrido, ponha as chaves no manifest e no
`Info.plist`, mesmo inicializando por código.** Não é redundância — são processos
diferentes.

## 4-C · Android, com a credencial fora do commit

`local.properties` (já em `.gitignore`):
```properties
DITO_API_KEY=...
DITO_API_SECRET=...
```

`app/build.gradle.kts`:
```kotlin
android {
    defaultConfig {
        val ditoApiKey = System.getenv("DITO_API_KEY")
            ?: (localProperties.getProperty("DITO_API_KEY") ?: "")
        val ditoApiSecret = System.getenv("DITO_API_SECRET")
            ?: (localProperties.getProperty("DITO_API_SECRET") ?: "")

        manifestPlaceholders["DITO_API_KEY"] = ditoApiKey
        manifestPlaceholders["DITO_API_SECRET"] = ditoApiSecret
    }
}
```
> Se `localProperties` ainda não existe no arquivo, você precisa criar o bloco que o
> carrega. Confira como o projeto já lê `local.properties` (Flutter costuma ter isso
> pronto para `flutter.sdk`) e siga o padrão dele em vez de inventar outro.

`AndroidManifest.xml`, dentro de `<application>`:
```xml
<meta-data android:name="br.com.dito.API_KEY"    android:value="${DITO_API_KEY}" />
<meta-data android:name="br.com.dito.API_SECRET" android:value="${DITO_API_SECRET}" />
```

## 4-D · iOS

`Info.plist` do target do **app**:
```xml
<key>AppKey</key>
<string>$(DITO_API_KEY)</string>
<key>AppSecret</key>
<string>$(DITO_API_SECRET)</string>
```
com as duas definidas num `.xcconfig` fora do commit. Se o projeto não usa `.xcconfig`
e a pessoa aceitou hardcode para app de teste, escreva o valor — e registre como
dívida no relatório.

A NSE **não** precisa das credenciais: ela renderiza conteúdo, não envia evento.

## 4-E · Gate da Fase 4 — o manifest **mesclado**

Nunca valide no fonte. Um `${DITO_API_KEY}` cujo placeholder não resolve chega como
string **vazia**, e a SDK trata vazio igual a ausente. O fonte parece perfeito.

```bash
# Android — o manifest que vale é o do APK
adb shell pm path <seu.package>            # pegue o caminho do base.apk
adb pull <caminho> /tmp/app.apk
apkanalyzer manifest print /tmp/app.apk | grep -A2 -i "br.com.dito"

# fallback sem apkanalyzer
unzip -o /tmp/app.apk AndroidManifest.xml -d /tmp/mf >/dev/null && \
  strings /tmp/mf/AndroidManifest.xml | grep -i dito
```

```bash
# iOS — o Info.plist do bundle construído
plutil -p "<caminho>/SeuApp.app/Info.plist" | grep -iE "AppKey|AppSecret"
```

Passa se: as chaves aparecem **com valor não vazio**. Valor vazio = reprovado, mesmo
compilando. Mascare no relatório.

---

# Fase 5 — Inicialização e identidade

## 5-A · Inicializar

**Flutter** — `main()`, depois de `ensureInitialized()`:
```dart
final ditoSdk = DitoSdk();
await ditoSdk.initialize(appKey: ..., appSecret: ...);
```
Guarde e reutilize a instância. O único membro estático é `DitoSdk.onNotificationClick`.

**React Native**:
```typescript
await DitoSdk.initialize({ apiKey: ..., apiSecret: ... });
```

**Android nativo** — `Application.onCreate()`:
```kotlin
Dito.init(this, Options(retry = 5))
```

**iOS nativo** — `AppDelegate`, e **a ordem importa no iOS 18+**:
```swift
FirebaseApp.configure()                    // 1º, sempre
Messaging.messaging().delegate = self      // 2º
Dito.shared.configure()                    // 3º
```
Inverter isso produz falhas intermitentes de token que parecem problema de rede.

## 5-B · Identidade e evento

`identify(id, name?, email?, customData?)` antes de qualquer `track` — evento sem
identify é evento sem dono. Chame no momento em que o id existe de verdade (Q6), não
no splash "porque é cedo".

> `reference` está sendo removido da Dito em favor de `user_id`. Se você encontrar
> código do app ou payload de push girando em volta de `reference`, sinalize —
> não construa integração nova em cima dele.

## 5-C · Gate da Fase 5

Rode o app e prove nos logs que a SDK inicializou e o evento saiu:

```bash
# Android (o print do Dart/JS também cai aqui)
adb logcat -c && adb logcat | grep -iE "dito|Dito"

# iOS aparelho
log stream --predicate 'eventMessage CONTAINS "Dito"'
```

Prova: *inicializa sem lançar, e `identify`/`track` produzem chamada*. Confirmação de
que o evento **chegou** é no painel Dito — abra e confira; sem isso, o gate é parcial.

---

# Fase 6 — Push

Só se o escopo for ≥ 2. Faça em três degraus e não pule para o rico antes de o simples
funcionar.

## 6-A · Firebase e permissão

`google-services.json` em `app/` + plugin `com.google.gms.google-services`.
`GoogleService-Info.plist` no target do app, e APNs configurado no Firebase (chave ou
certificado). No iOS, `Info.plist` do app:

```xml
<key>UIBackgroundModes</key>
<array><string>remote-notification</string></array>
```
Sem isso o app não é acordado pelo push e **o evento de entrega não sai com o app
encerrado**. E confirme o entitlement:
```bash
codesign -d --entitlements - SeuApp.app 2>/dev/null | grep -A1 aps-environment
```
Nada aqui = não há push real. Um bundle com `CODE_SIGNING_ALLOWED=NO` não tem
entitlements: serve para teste local, não para validar push.

No Android 13+, `POST_NOTIFICATIONS` é permissão de runtime — o app tem que pedir.

## 6-B · O conflito do `FirebaseMessagingService` (Android)

**Um por app.** Se a Q5 revelou OneSignal, Braze, CleverTap ou um serviço próprio, as
opções são: a Dito recebe o `MESSAGING_EVENT` (e o outro para de receber), ou você
escreve um serviço delegador que repassa para os dois. Delegador é trabalho real e
tem que estar no plano — se não estava, volte ao gate da Fase 2.

Se o app implementa o seu próprio serviço, repasse a entrega para a Dito:
```kotlin
class MyFirebaseMessagingService : FirebaseMessagingService() {
    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        val d = remoteMessage.data
        Dito.notificationRead(mapOf(
            "notification"      to (d["notification"] ?: ""),
            "reference"         to (d["reference"] ?: ""),
            "log_id"            to (d["log_id"] ?: ""),
            "notification_name" to (d["notification_name"] ?: ""),
            "user_id"           to (d["user_id"] ?: "")
        ))
        // ... siga processando normalmente
    }
}
```
e registre o serviço no manifest com o `intent-filter` de
`com.google.firebase.MESSAGING_EVENT`.

## 6-C · Push rico no iOS: a NSE não é opcional

Escopo ≥ 3. **Imagem e botões só aparecem no iOS se o app tiver uma Notification
Service Extension.** Sem ela o push degrada para título e corpo — sem erro, sem log,
só não renderiza. O sintoma clássico é: no Android o push rico aparece completo, no
iOS o mesmo push chega só com texto.

O motivo é *onde* o conteúdo rico é montado. No Android, é o processo do app. No iOS,
quem baixa a imagem e registra a `UNNotificationCategory` com os botões é uma app
extension, em processo próprio, antes de a notificação ser exibida. **Não existe
caminho por Dart nem por JS** — o Flutter engine e a bridge não participam disso.

Três passos:

1. **Xcode → File → New → Target → Notification Service Extension.** Isto é manual:
   você não cria target por CLI de forma confiável. Peça à pessoa e diga o nome a usar.

2. **`Podfile`** — target **no topo do arquivo, irmão do target do app**, nunca
   aninhado:
   ```ruby
   target 'NotificationServiceExtension' do
     use_frameworks!
     pod 'DitoSDKNotificationService'
   end
   ```
   Três coisas que este bloco **não** faz, todas de propósito:
   - **não declara `DitoSDK`.** O SDK completo usa `UIApplication` e CoreData, API
     exclusivas de app — declarar aqui não compila. É por isso que existe um pod
     separado;
   - **não chama `flutter_install_all_ios_pods`.** Uma app extension não pode linkar
     o Flutter, e a NSE não precisa dele;
   - **não fica aninhado no target do app.** Aninhar herdaria os pods do app,
     incluindo o Flutter, caindo no item anterior.

3. **A classe herda, e é só isso:**
   ```swift
   import DitoSDKNotificationService

   class NotificationService: DitoNotificationService {}
   ```
   Nada para chamar, registrar ou inicializar. A classe base baixa `data.image` e
   anexa como `UNNotificationAttachment`, registra as `UNNotificationAction` com o
   `id` de cada botão, e entrega o conteúdo original se algo falhar ou o tempo
   esgotar (`imageDownloadTimeout`, 15s por padrão).

> **Quem embebe o framework é o app, não a extension.** O `DitoSDK` do app já arrasta
> o `DitoSDKNotificationService`, e o CocoaPods põe `@executable_path/../../Frameworks`
> no `LD_RUNPATH_SEARCH_PATHS` da extension — que é onde ele acaba. Se você declarar o
> pod só na extension e o app não linkar o SDK, o dyld falha no arranque do processo
> da extensão e o push volta a chegar sem imagem, agora por outro motivo.

Confirme que o target entrou no build — o erro silencioso aqui é criar a extension e
ela não ir dentro do `.app`:
```bash
find build/ios -name '*.appex'                                  # tem de existir
ls build/ios/iphoneos/*.app/Frameworks | grep DitoSDKNotificationService
```

## 6-D · Clique e deeplink

Escopo 4. **A SDK não abre link nenhum** — ela te entrega o link e a navegação é sua.

**iOS nativo:**
```swift
Dito.notificationClick(response: response) { link in
    self.navigate(to: link)   // link do botão tocado, ou o deeplink do push
}
```
O objeto devolvido expõe `image`, `actions` (`id`/`label`/`link`), `customData`,
`actionId` (`""` se o toque foi no corpo) e `resolvedLink`.

**Flutter:** ouça `DitoSdk.onNotificationClick`.
**React Native / Android:** siga o README da plataforma — não deduza o nome do
callback.

O clique num botão **reutiliza o evento de clique existente**, acrescentando
`action_id` e `action_label` ao custom data. Não é evento novo, e é `action_id` que
separa corpo de botão nos relatórios.

## 6-E · Duas coisas que parecem bug seu e não são

**Botão não aparece no Android.** A renderização depende do modo de entrega do brand
(`firebase_notification_type`) — configuração de backend:

| Modo | Imagem | Botões | Custom data |
| --- | --- | --- | --- |
| `DATA` | ✅ | ✅ | ✅ |
| default | ✅ | ⚠️ só com o app em foreground | ✅ |
| `NOTIFICATION` | ✅ (nativa) | ❌ | ❌ |

Se o payload está correto e os botões não aparecem, o modo do brand é o primeiro lugar
a olhar. **Não há nada a corrigir no app.**

**`custom_data` "não chegou" no iOS.** Ele não depende da NSE — viaja no payload e é
lido no processo do app. O que engana é *quando* cada stream entrega:

| App recebeu | `FirebaseMessaging.onMessage` | `onNotificationClick` |
| --- | --- | --- |
| foreground | ✅ payload completo | no toque |
| background ou fechado | ❌ **não dispara no iOS** | ✅ no toque, com `customData` |

Teste de push rico é feito, por natureza, com o app em background. Então um painel de
debug alimentado só por `onMessage` aparece vazio — e é fácil ler isso como "o
`custom_data` não chegou". Chegou; está no clique.

## 6-F · Gate da Fase 6

Payload que chegou de fato ao aparelho:
```bash
# Android — no bloco do seu package: android.title, android.text, android.template,
# android.pictureIcon, e a lista actions={...}
adb shell dumpsys notification --noredact | less

# iOS — com DitoPushDebugLog = true (Boolean) no Info.plist da NSE
log stream --predicate 'eventMessage CONTAINS "DITO_PUSH_PAYLOAD"'
```
Zero linhas de `DITO_PUSH_PAYLOAD` = a extensão **não foi acordada**. Aí o problema
está no payload (falta `mutable-content: 1`) ou no target — não na SDK. Desligue a
flag depois: o dump vai para o log unificado do aparelho, que é persistido.

Na gaveta, avalie a notificação **expandida**. Colapsada não mostra imagem nem botões,
e é o falso negativo mais comum.

---

# Fase 7 — Verificação

Não é "compilou". É a integração exercitada no aparelho:

| # | Prova | Como |
| --- | --- | --- |
| 1 | compila nas plataformas do escopo | build limpo, sem warning novo de Dito |
| 2 | dependência dentro do artefato | `Podfile.lock` / `pub deps` / `:app:dependencies` |
| 3 | credencial no manifest **mesclado**, não vazia | Fase 4-E |
| 4 | inicializa sem lançar | log no arranque |
| 5 | `identify` + `track` chegam ao painel | painel Dito aberto e conferido |
| 6 | push renderiza (escopo ≥ 2) | notificação na gaveta |
| 7 | imagem e botões (escopo ≥ 3) | notificação **expandida** |
| 8 | clique navega e registra (escopo 4) | corpo **e** botão, app aberto/background/**morto** |

O estado **morto** é obrigatório no escopo 4 — é o único que exerce o processo novo, e
é exatamente o que 4-B descreve. Use HOME para background, não force-stop.

Se algum item reprovou, o veredito é **integração parcial**, com a lista do que falta.
Nunca "pronto, só falta testar".

---

# Fase 8 — Relatório

Um artifact HTML autocontido, no mesmo padrão dos playbooks de teste:

- **Cabeçalho:** projeto, tipo detectado, plataformas, escopo escolhido, versões da
  SDK instaladas por plataforma, data.
- **Ficha do terreno** (Fase 0) e o que a entrevista decidiu.
- **Tabela por fase:** aplicada / pulada por escolha / bloqueada — e por quê. Fase
  pulada aparece como pulada, sempre.
- **Arquivos tocados**, com o diff resumido.
- **Os 8 itens da Fase 7**, cada um ✅/❌/⏭ com a evidência (linha de log, saída de
  comando, screenshot da gaveta).
- **Dívidas e riscos:** credencial hardcoded, delegador de FCM pendente, piso de OS
  subido, NSE ausente, item verificado só em simulador.
- **Próximo passo:** `run-local-test.md` ou `run-prod-test.md`.

Credencial mascarada. Sempre.

---

# Z — Encerramento

**Z-1 · Desligue o que era temporário.** `DitoPushDebugLog` no `Info.plist` da NSE,
`options.debug = true`, `setDebugMode`, dumps de payload, prints de diagnóstico. Deixar
ligado envia o dump para o log unificado do aparelho, que é persistido.

**Z-2 · Confirme que nenhum segredo entrou.**
```bash
git diff --cached -U0 | grep -iE "api[_-]?key|api[_-]?secret|appkey|appsecret"
git status --short
```
`local.properties`, `.env` e `.xcconfig` com valor têm que estar em `.gitignore`.

**Z-3 · Checagem final.** Todas as fases do plano têm veredito; os 8 itens da Fase 7
estão respondidos ou explicitamente pulados; as suposições que você tomou sem resposta
estão nomeadas; o relatório existe. Se não, diga o que ficou faltando — não arredonde.

---

## Fonte de verdade

Quando este arquivo e o README da plataforma divergirem, **o README ganha** — ele
acompanha a versão da SDK, este playbook não.

- Android — https://github.com/ditointernet/sdk-mobile/blob/main/android/README.md
- iOS — https://github.com/ditointernet/sdk-mobile/blob/main/ios/README.md
- Flutter — https://github.com/ditointernet/sdk-mobile/blob/main/flutter/README.md
- React Native — https://github.com/ditointernet/sdk-mobile/blob/main/react-native/README.md
- Push (guia unificado) — https://github.com/ditointernet/sdk-mobile/blob/main/docs/push-notifications.md
- NSE de referência, funcionando — `flutter/sample_application/ios/NotificationServiceExtension/`
  e o bloco correspondente no `Podfile` ao lado

## Anti-padrões — o que reprova esta execução

| Não faça | Por quê |
| --- | --- |
| editar arquivo antes do gate da Fase 2 | o plano deixa de ser plano |
| copiar número de versão deste arquivo | as 4 plataformas versionam separado e divergem |
| deduzir nome de método pelo padrão da linguagem | `AppKey` vs `ApiKey` já custou integrações inteiras |
| validar credencial no manifest fonte | placeholder vazio passa e a SDK trata vazio como ausente |
| dizer "pronto" com push testado só no botão | o toque no corpo é o caminho que quebra sem a chave no manifest |
| avaliar push rico na notificação colapsada | colapsada não mostra imagem nem botão |
| validar push em simulador | sem `aps-environment` não há push real |
| commitar credencial "só para testar" | vaza, e ninguém volta para tirar |
| tratar Flutter/RN como "não preciso mexer no nativo" | a casca não faz o trabalho; a SDK nativa faz |
| pular a NSE e reportar push rico ✅ no iOS | degrada em silêncio: texto puro, sem erro |
| aninhar o target da NSE dentro do target do app no Podfile | herda os pods do app e não compila |
| culpar a SDK quando o botão não aparece no Android | pode ser `firebase_notification_type` do brand |
