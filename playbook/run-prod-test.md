# Playbook: teste de push real disparado pelo painel de produção

Este arquivo é um **prompt de execução**. Você é uma LLM com acesso a um shell e a
um aparelho conectado. Sua tarefa é conduzir uma pessoa através da validação de
push **real**, disparado do painel de produção da Dito, e produzir um relatório
visual dos problemas encontrados.

Você não está corrigindo nada. Você está medindo, relatando, e conduzindo.

## Dois atores, e você não é o que dispara

Esta é a diferença estrutural em relação ao [`run-local-test.md`](./run-local-test.md):

| Ator | Faz |
| --- | --- |
| **Você (LLM)** | prepara a captura, coloca o app no estado alvo, lê o log, tira o print, classifica |
| **A pessoa** | dispara a campanha no painel, toca na notificação quando pedido, lê os contadores do painel |

Você **nunca** dispara a campanha. Você não tem acesso ao painel, e mesmo que
tivesse, disparar sem a pessoa confirmando o alvo grava evento em produção no
histórico de alguém. Prepare, peça, espere, leia.

E o passo que dá sentido a tudo — **conferir os contadores de entrega e clique no
painel** — só a pessoa pode dar. Um relatório deste playbook sem os números do
painel não produziu nada que o playbook local já não produzisse. Ver Z-4.

## O que só este playbook prova

O playbook local injeta payload sintético direto no processo do app. É rápido,
determinístico, e roda sem aparelho físico no Android. Mas ele pula tudo que está
entre o painel e a tela:

```
  painel  →  ingest  →  FCM/APNs  →  SO  →  processo do app  →  render
  └────────── só aqui ──────────┘      └── é só isto que o playbook local cobre ──┘
```

Cinco coisas que **só** um disparo real mede:

1. **O token está registrado para o usuário certo.** Se o `register` não chegou, a
   campanha simplesmente não encontra o aparelho — e no painel isso aparece como
   entrega zero, indistinguível de perda no envio do evento.
2. **Entrega com o app morto.** É o cenário de maior risco e o único que o local não
   consegue simular: o processo sobe do zero por conta do push e pode ser congelado
   antes de terminar o HTTP do evento de entrega.
3. **Os contadores do painel.** É a métrica que o time olha, e é a que está zerando.
4. **Cold start pelo toque.** Toque em notificação com o processo morto passa por
   `Dito.init` num app que talvez não tenha credencial no manifest.
5. **A campanha real.** Payload montado pelo channel-sender, não por você — inclusive
   os campos que ele decide não mandar.

### Hipótese aberta que este playbook existe para testar

A entrega e o clique zeram de forma intermitente no painel. No Android há uma
assimetria medida no código (`android/dito-sdk/.../tracking/Tracker.kt`):

```kotlin
notificationReceived(...)  →  try { client.activity(request) } catch (_: Exception) { }
//                                                            └─ engole e NÃO enfileira
notificationClick(...)     →  try { client.activity(request) }
                              catch (_: Exception) { trackerOffline.notificationRead(...) }
//                                                   └─ tem fila offline
```

A entrega é o único dos dois sem fallback offline, e o envio é um `scope.launch` sem
âncora de ciclo de vida. **Previsão a testar:** a perda de entrega concentra-se no
estado *app morto*, e o clique — que tem fila — sobrevive. Se a matriz mostrar isso,
a causa está localizada. Se a perda aparecer também com app aberto, a causa é outra
e está antes disso.

Não trate isso como conclusão. É a hipótese que a matriz confirma ou derruba.

## Regras de execução

1. **Um disparo por vez.** Nunca peça dois antes de registrar o resultado do primeiro.
   Duas campanhas em voo tornam impossível dizer qual notificação é de qual.
2. **Marque `T0` antes de pedir o disparo.** Sem a âncora de tempo você não sabe
   separar a linha deste disparo da do anterior.
3. **Não improvise contorno.** Se um passo falhar, tente o fallback dele. Se o
   fallback falhar, registre `BLOQUEADO` com a saída literal e siga para a próxima
   célula.
4. **Ausência de log não é conclusão** antes do passo de sanidade da plataforma.
5. **Distinga quatro coisas** que se confundem e têm causas diferentes: *não
   disparou* (painel), *não chegou* (FCM/APNs ou token), *chegou e não renderizou*
   (SDK), *renderizou e não contou* (envio do evento). Toda `FALHA` tem de dizer
   qual das quatro.
6. **Cite evidência literal.** Linha de log, número do painel, sem paráfrase.
7. **Eventos reais são irreversíveis.** Antes do primeiro disparo, confirme com a
   pessoa qual usuário a campanha vai atingir e que gravar no histórico dele é
   aceitável.
8. **Não invente navegação de painel.** Você não conhece a UI. Pergunte onde está o
   relatório da campanha e registre o que a pessoa relatar.

---

# Fase 0 — Entrevista (obrigatória, antes de qualquer comando)

Este playbook roda em ambientes que você não conhece: pode ser um app deste repo,
pode ser um app de cliente usando a SDK publicada, pode ser um aparelho físico ou
um emulador. **O que é mensurável muda completamente com essas respostas.** Não
rode um comando antes de ter todas.

Use uma ferramenta de pergunta estruturada, agrupando o que couber. Perguntas:

### Q1 · Plataformas a testar
`Android nativo` · `iOS nativo` · `Flutter Android` · `Flutter iOS` · `React Native`
(múltipla escolha)

### Q2 · De onde vem o app — a pergunta que mais muda o resto

| Resposta | Consequência |
| --- | --- |
| **(a)** sample deste repo, build local | acesso total: pode ligar flag de debug, rebuildar, ler tudo |
| **(b)** app externo com a SDK publicada | **não pode rebuildar nem ligar flag.** Evidência só de nível de SO: `dumpsys notification`, logcat do que o app já emite, e o print da tela. Ver Fase 1-D |
| **(c)** app externo com override para SDK local | pode rebuildar; confirme qual versão está de fato linkada antes de concluir qualquer coisa |

Se **(b)**, diga isso à pessoa explicitamente antes de começar: as linhas
`DITO_PUSH_PAYLOAD`/`DITO_PUSH_DISPLAY` só saem com `Dito.options.debug == true`, e
num app de produção elas provavelmente não vão aparecer. **A ausência delas não é
defeito** — e o relatório precisa dizer isso, senão o leitor lê "o payload não
chegou".

### Q3 · Versão da SDK em uso
Pergunte, e **confirme no aparelho** — a resposta de memória erra com frequência:

```bash
# Android: versão do app (não da SDK), útil para amarrar o build
adb shell dumpsys package <pkg> | grep -E "versionName|versionCode"

# Android: a SDK está mesmo embarcada, e em que versão?
adb shell pm path <pkg>                       # pegue o caminho do base.apk
adb pull <caminho-do-base.apk> /tmp/dito-prod/app.apk
unzip -l /tmp/dito-prod/app.apk | grep -i dito | head
```

Se a versão linkada não for a que a pessoa espera, **pare e diga**. Testar a SDK
errada é pior que não testar.

### Q4 · Estados do app a cobrir
`aberto (primeiro plano)` · `background` · `morto` — múltipla escolha, padrão os três.

Os três medem coisas diferentes, e o playbook precisa dizer qual:

| Estado | O que mede | Risco conhecido |
| --- | --- | --- |
| aberto | o callback de recebimento no processo vivo | no iOS **não há banner** em primeiro plano sem `willPresent` — ver Fase 1-B |
| background | render completo, é onde a NSE do iOS roda | fila de broadcast de botão atrasa (~57 s medidos) |
| morto | cold start pelo push, e o envio do evento de entrega | **o suspeito principal da entrega zerada** |

### Q5 · Aparelho
`físico` ou `emulador/simulador`.

**iOS com push real exige aparelho físico.** O `simctl push` não invoca a
Notification Service Extension — medido em Xcode 26.6 / iOS 26.5, nas duas
configurações, nos três estados de app. Se a resposta for "simulador iOS", registre
as células de iOS como `NÃO EXECUTADO — simulador não recebe push real` e não
tente substituir.

### Q6 · Usuário alvo e consentimento
Qual `user_id`/`reference` a campanha vai atingir, e gravar no histórico dele é
aceitável? Os eventos **não têm como ser apagados depois**. Se a pessoa hesitar,
ofereça um usuário de teste descartável antes de seguir.

### Q7 · A campanha
Push simples ou rico? Com imagem, com botões, com os dois? Quais `action_id` e
labels? Você vai precisar deles para conferir o mapeamento — sem saber o esperado,
não há como dizer que o observado está errado.

### Fecho da Fase 0 — devolva o plano e espere confirmação

Monte a matriz de células e diga, célula por célula, o que ela prova. Só comece
depois do "ok".

```
Plano (12 células = 4 plataformas × 3 estados)
  ✓ Android nativo   × aberto      → callback de recebimento no processo vivo
  ✓ Android nativo   × background  → render rico completo
  ✓ Android nativo   × morto       → cold start + envio da entrega  ← suspeito
  …
Alvo: user_id=<...>   Campanha: <...>   SDK: <...>   Aparelho: <...>
Cada disparo grava evento real em produção. Confirma?
```

Depois do "ok", **não vá para a Fase 1**: vá para a Fase 0.5. O diagnóstico de
integração roda antes de qualquer disparo, e pode mudar o plano que você acabou de
confirmar — uma plataforma reprovada no gate sai da matriz ou entra marcada.

---

# Fase 0.5 — Diagnóstico de integração (gate)

**Nada de disparo antes desta fase passar.** Não é burocracia: uma integração
incompleta produz **exatamente o sintoma que você veio investigar**, e sem checar
antes você vai reportar bug de SDK onde há chave no lugar errado.

| Sintoma no painel | Pode ser integração | Pode ser SDK |
| --- | --- | --- |
| entrega zero | token não registrado; credencial ausente no processo que envia | `notificationReceived` sem fila offline |
| clique zero | `API_KEY` fora do manifest num app Flutter/RN | envio do clique |
| clique derruba o app | `API_KEY` fora do manifest **e** clique no corpo | — |
| nada chega | permissão negada; `channel` diferente de `DITO` | — |

As três primeiras linhas são indistinguíveis das causas de SDK **do lado do painel**.
Só o diagnóstico separa.

## 0.5-A · O mapa: onde a credencial precisa estar

Verificado no código deste repo, não deduzido:

| Plataforma | Fontes aceitas | Quem lê | Processos que precisam |
| --- | --- | --- | --- |
| Android | manifest `br.com.dito.API_KEY` (+ `API_SECRET`, `HIBRID_MODE`) **ou** código: `Dito.init(context, apiKey, secret)` | `Dito.init` — `Dito.kt:108` e `Dito.kt:141` | o app **e** `NotificationOpenedActivity`, que roda em **processo novo** |
| iOS | `Info.plist` `AppKey`/`AppSecret` **ou** código: `Dito.configure(appKey:appSecret:)` / `configure(apiKey:bundleId:)` | `Dito.shared` no init — `Dito.swift:59-74`, fallback para `Bundle.main` **só se nada foi setado por código** | o app; a NSE **não** |

A coluna que importa é a última. **Credencial passada por código só existe no
processo que rodou aquele código.** Todo caminho que sobe num processo novo — clique
com app morto, cold start por push — não tem esse código executado ainda.

## 0.5-B · Android: a regra que pega Flutter e React Native

> **Um app Flutter ou RN precisa da chave no `AndroidManifest.xml` mesmo
> inicializando por código.** Não é redundância; são dois processos diferentes.

A cadeia, em `NotificationOpenedActivity.kt:34-46` e `Dito.kt:108-126`:

```
app morto  →  toque na notificação  →  processo novo, Dart/JS não rodou
           →  Dito.isInitialized() == false
           →  Dito.init(applicationContext, null)      ← a variante do MANIFEST
           →  manifest sem br.com.dito.API_KEY
           →  throw RuntimeException("É preciso configurar API_KEY no AndroidManifest.")
           →  catch  →  W/NotificationOpenedActivity: Could not initialize Dito on click
           →  `private lateinit var tracker` NUNCA foi atribuído  (Dito.kt:44, atribuído só em configureTracker)
```

E aí o caminho se bifurca, com consequências diferentes:

| Toque | Chama | Resultado sem a chave no manifest |
| --- | --- | --- |
| **no corpo** da notificação | `Dito.notificationClick(...)` → passa `tracker` | acessa `lateinit` não atribuído → **`UninitializedPropertyAccessException`** |
| **num botão** de ação | `broadcastActionClick(click)` | sobrevive — não toca em `tracker` |

Por isso o defeito se apresenta de forma enganosa: os botões funcionam, o corpo não.
Quem testa só botão conclui que está tudo bem.

### Checar o manifest **mesclado**, não o fonte

O fonte pode ter a chave e o valor chegar vazio — o sample Flutter deste repo usa
`android:value="${DITO_API_KEY}"`, um placeholder que o Gradle resolve de
`System.getenv("DITO_API_KEY")` ou de `local.properties`
(`flutter/sample_application/android/app/build.gradle.kts:43-49`). Sem a variável, o
placeholder resolve para **string vazia**, `resolvedApiKey.isEmpty()` é verdadeiro, e
`init` lança igual a não ter a chave. O fonte parece certo; o app está quebrado.

```bash
PKG=<package>
adb shell pm path "$PKG"                     # pegue o caminho do base.apk
adb pull <caminho-do-base.apk> /tmp/dito-prod/app.apk

# o manifest que vale é o do APK
"$ANDROID_HOME"/cmdline-tools/latest/bin/apkanalyzer manifest print /tmp/dito-prod/app.apk \
  | grep -B1 -A2 -i "br.com.dito"

# fallback sem apkanalyzer
"$ANDROID_HOME"/build-tools/*/aapt2 dump xmltree /tmp/dito-prod/app.apk \
  --file AndroidManifest.xml | grep -A3 -i "br.com.dito"
```

Verde: `br.com.dito.API_KEY` presente **e com valor não vazio**. Vermelho: ausente,
ou `android:value=""`, ou o placeholder literal `${DITO_API_KEY}` não substituído.

### A prova em tempo de execução, sem gastar campanha

`NotificationOpenedActivity` é `exported="true"` com action pública, então dá para
exercitar o caminho exato do clique-com-app-morto por `adb` — custa um evento
sintético em vez de uma campanha real:

```bash
adb logcat -c && nohup adb logcat -v time > /tmp/dito-prod/diag-click.log 2>&1 & disown
adb shell am force-stop "$PKG"        # processo novo, é o ponto do teste
adb shell "am start -a br.com.dito.ditosdk.notification.NOTIFICATION_CLICK \
  -n $PKG/br.com.dito.ditosdk.notification.NotificationOpenedActivity \
  --es br.com.dito.ditosdk.DITO_NOTIFICATION_ID diag-integration-check"
sleep 8
grep -E "Could not initialize Dito|UninitializedPropertyAccessException|E/AndroidRuntime|Calling Dito.notificationClick" /tmp/dito-prod/diag-click.log
```

Leia assim:

| Saída | Veredito |
| --- | --- |
| `✅ Calling Dito.notificationClick()` sem exceção | integração do clique **OK** |
| `Could not initialize Dito on click` | credencial não alcança este processo — **vermelho** |
| `UninitializedPropertyAccessException` / `E/AndroidRuntime` | **vermelho crítico**: o clique no corpo derruba o app |

> Este disparo usa `notification=diag-integration-check`. Se a integração estiver OK,
> ele **grava um evento real** com esse id. Use um id reconhecível como este para
> conseguir descartá-lo depois na leitura do painel.

## 0.5-C · iOS: `Info.plist` do app, e o que a extensão **não** precisa

```bash
APP_PLIST=<caminho>/Info.plist
/usr/libexec/PlistBuddy -c "Print :AppKey"          "$APP_PLIST"
/usr/libexec/PlistBuddy -c "Print :AppSecret"       "$APP_PLIST"
/usr/libexec/PlistBuddy -c "Print :UIBackgroundModes" "$APP_PLIST"
```

Três checagens, com o motivo de cada uma:

1. **`AppKey`/`AppSecret`** — mesma lógica do Android: num cold start por push, o
   Dart/JS que chamaria `Dito.configure(...)` ainda não rodou. O fallback para
   `Bundle.main` (`Dito.swift:61-63`) é a única fonte disponível, e ele desiste em
   silêncio se a chave estiver vazia (`guard !rawKey.isEmpty else { return }`).
2. **`UIBackgroundModes` contendo `remote-notification`** — sem isso o app não é
   acordado para o push e o evento de **entrega** não tem como sair com o app morto.
3. **Entitlement `aps-environment`** — sem ele não há push real nenhum. Um bundle
   compilado com `CODE_SIGNING_ALLOWED=NO` não tem entitlements: serve para o
   playbook local, **não** serve aqui.

```bash
codesign -d --entitlements - <caminho>/Sample.app 2>/dev/null | grep -A1 aps-environment
```

**A extensão não precisa de credencial.** Verificado: `ios/DitoNotificationService/`
não tem uma única referência a `Dito`, a `appKey` ou ao ingest — ela só renderiza. Do
`Info.plist` **dela** o que importa é apenas:

```bash
/usr/libexec/PlistBuddy -c "Print :DitoPushDebugLog" <caminho>/…​NotificationService/Info.plist
/usr/libexec/PlistBuddy -c "Print :NSExtension:NSExtensionPrincipalClass" <caminho>/…​/Info.plist
```

`Bundle.main` dentro de uma app extension resolve para o bundle **da extensão**, não
o do app — é por isso que a flag de debug mora lá. Pela mesma razão, **pôr `AppKey`
no `Info.plist` da extensão não resolve nada**: ninguém lê. Se encontrar isso numa
integração, é ruído a remover, não a causa.

Confirme também o embarque, porque sem ele nada de rico funciona e a causa não é
payload:

```bash
ls <caminho>/Sample.app/PlugIns/                                  # a .appex
ls <caminho>/Sample.app/Frameworks/ | grep DitoSDKNotificationService
```

## 0.5-D · Flutter e RN: as falhas que aparecem quase sempre

Encontradas neste repo, e são o retrato do problema:

| Onde | Estado | Consequência |
| --- | --- | --- |
| `flutter/sample_application/android/app/src/main/AndroidManifest.xml` | tem `API_KEY`, mas via `${DITO_API_KEY}` | resolve vazio sem a env/`local.properties` — quebra silenciosa |
| `flutter/sample_application/ios/Runner/Info.plist` | corrigido: tem `AppKey`/`AppSecret` via `$(DITO_APP_KEY)`, gerados por `ios/generate-dito-xcconfig.sh` a partir do mesmo `.env.development.local` que o Dart lê | sem rodar o script, o cold start por push fica sem credencial |
| **target de NSE no projeto iOS** | corrigido: `flutter/sample_application/ios/NotificationServiceExtension/` | sem o target, o push rico chega **só com título e corpo** — imagem e botões não renderizam, sem erro nenhum |

A terceira linha é a que mais engana num teste manual, porque não produz falha: no
Android o push rico aparece completo, no iOS o **mesmo** push chega só com texto, e o
relatório de envio/entrega/clique fica todo verde. Num app híbrido de cliente, é o
primeiro lugar a olhar antes de suspeitar do payload ou da SDK — e vale checar que o
target é irmão do target do app no `Podfile`, não aninhado nele.

Compare com `ios/SampleApplication/Info.plist`, que tem `AppKey`, e com
`android/example-app/src/main/AndroidManifest.xml`, que tem `API_KEY` e `API_SECRET`
literais: o sample **nativo** está completo, os de framework não. Num app de cliente
espere o mesmo padrão — quem integra por código presume que código basta.

Checagem extra do lado do framework: a credencial passada por código chegou mesmo?

```bash
# Flutter/RN: o init por código deixa rastro no logcat / console
grep -iE "Dito.*init|configure|apiKey" /tmp/dito-prod/and-init.log | head
```

E confirme `HIBRID_MODE` se a integração usa modo híbrido — ele vem **só** do
manifest (`Dito.kt:153-159`), inclusive no `init` por código, com default `"OFF"`.

## 0.5-E · Veredito do gate

Monte esta tabela e mostre à pessoa **antes** de pedir qualquer disparo:

| Checagem | Plataforma | Verde | Vermelho |
| --- | --- | --- | --- |
| `API_KEY` no manifest mesclado, valor não vazio | Android | | |
| clique sintético sem exceção | Android | | |
| `AppKey`/`AppSecret` no `Info.plist` do app | iOS | | |
| `remote-notification` em `UIBackgroundModes` | iOS | | |
| entitlement `aps-environment` | iOS | | |
| `.appex` e framework embarcados | iOS | | |
| `DitoPushDebugLog` no plist da extensão | iOS | | |
| permissão de notificação concedida | ambas | | |
| token registrado para o usuário alvo | ambas | | |

**Regra do gate:** qualquer vermelho nas linhas de manifest/plist/entitlement
**para antes do disparo**. Ou a pessoa corrige, ou vocês seguem com a célula marcada
`DEGRADADO POR INTEGRAÇÃO` — e nesse caso o relatório precisa dizer, em destaque,
que aquele resultado **não** mede a SDK. Um vermelho não declarado transforma o
relatório inteiro em falso negativo.

---

# Fase 1 — Preparar a captura

Faça a preparação da plataforma **inteira** antes do primeiro disparo. Pedir para a
pessoa disparar e só então descobrir que o log não estava capturando queima um
evento real de produção.

## 1-A · Android (vale para app deste repo e para app externo)

```bash
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$ANDROID_HOME/platform-tools:$PATH"
mkdir -p /tmp/dito-prod
adb devices                    # sem aparelho: BLOQUEADO
PKG=<package-do-app>
```

**Permissão de notificação** — sem ela nada aparece e parece defeito de payload:

```bash
adb shell dumpsys package "$PKG" | grep POST_NOTIFICATIONS
# granted=false → peça para a pessoa conceder na UI do app,
# ou (só em build de debug) adb shell pm grant "$PKG" android.permission.POST_NOTIFICATIONS
```

**O token, que é o que faz a campanha achar o aparelho.** Esta é a checagem que
mais evita falso negativo — sem token registrado, entrega zero é consequência, não
defeito de envio:

```bash
adb logcat -c
adb shell am force-stop "$PKG"
nohup adb logcat -v time > /tmp/dito-prod/and-init.log 2>&1 &
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null
sleep 10
grep -iE "token|register|identify" /tmp/dito-prod/and-init.log | grep -iv aconfig | head -20
```

Guarde o token que aparecer e **peça para a pessoa confirmar no painel** que ele
está associado ao usuário alvo. Se não estiver, pare a plataforma: `BLOQUEADO —
token não registrado para o alvo`.

**Captura do disparo.** Capture o logcat inteiro em arquivo e filtre depois. Filtrar
no pipe esconde crash e ANR, que é exatamente o que você precisa ver quando falha:

```bash
CELL=and-aberto            # nomeie por célula: and-aberto, and-bg, and-morto
adb logcat -c
nohup adb logcat -v time > /tmp/dito-prod/$CELL.log 2>&1 &
echo "MONITOR_PID=$!"
```

Filtro para depois:

```bash
grep -E "DITO_PUSH_PAYLOAD|DITO_PUSH_DISPLAY|DITO_INTENT_EXTRAS|DitoNotificationHandler|DitoRichPushParser|NotificationDisplayHelper|NotificationOpenedActivity|DitoNotificationActionReceiver|FirebaseMessaging|E/AndroidRuntime|ANR in" /tmp/dito-prod/$CELL.log
```

**Colocar o app em cada estado, e confirmar que ele está lá:**

```bash
# aberto
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null

# background — HOME, não force-stop
adb shell input keyevent KEYCODE_HOME

# morto
adb shell am force-stop "$PKG"

# confirme o estado real antes de pedir o disparo
adb shell dumpsys activity processes | grep -A2 "$PKG" | head -6
```

> `am force-stop` **não é idêntico** a arrastar o app do recents. Em aparelho
> físico, prefira pedir para a pessoa fechar pelo gerenciador de apps — é o gesto
> que o usuário real faz, e algumas fabricantes tratam os dois estados de forma
> diferente para FCM. Registre no relatório qual dos dois você usou.

## 1-B · iOS (aparelho físico obrigatório)

```bash
xcrun devicectl list devices
UDID=<udid>
nohup xcrun devicectl device console --device "$UDID" > /tmp/dito-prod/ios-$CELL.log 2>&1 &
```

O console traz todos os processos. **App e extensão rodam separados**, então espere
duas linhas por push:

| Linha | Significa |
| --- | --- |
| `"source":"nse"` | a Notification Service Extension rodou — é ela que baixa imagem e registra categoria |
| `"source":"app"` | o processo do app recebeu |
| **só `app`** | a NSE **não** rodou → a causa é embarque ou linkagem, não payload |

Se o app for externo (Q2=b), `DitoPushDebugLog` não pode ser ligado — o flag mora no
`Info.plist` da extensão. Então a evidência de iOS se reduz a: **o print da tela** e
os números do painel. Diga isso no relatório em vez de deixar implícito.

> **Em primeiro plano o iOS não mostra banner** a menos que o app implemente
> `willPresent` devolvendo `.banner`. Portanto a célula *iOS × aberto* valida o
> **callback de recebimento**, não o banner, e não valida render rico nenhum — em
> primeiro plano a NSE não entra no caminho. Ausência de banner ali é `PASSA`, não
> `FALHA`. Este é o falso positivo mais comum deste playbook.

Estados, no aparelho, feitos à mão pela pessoa: primeiro plano; botão home /
gesto para background; arrastar para cima no app switcher para matar.

## 1-C · Flutter e React Native — o que elas acrescentam

A camada nativa é a mesma das seções acima; o que muda é que existe **um salto a
mais para validar**: o payload precisa chegar ao Dart / ao JavaScript. Uma célula
Flutter só passa se o payload chegou à linguagem de cima.

```bash
# Flutter e RN: o print do Dart/JS cai no logcat, então a mesma captura serve
grep -iE "flutter|DitoSdk|notification" /tmp/dito-prod/$CELL.log | head -30

# iOS: idem no console do devicectl
```

Peça à pessoa para mostrar a tela do app depois do toque — se o app host desenha o
payload recebido, o print é a prova mais direta de que a ponte entregou.

> `reference` vem **vazio** no mapa do Dart nas duas plataformas: o iOS parou de
> lê-lo e o Android parou de exigi-lo. Registre o que observou e **não reporte como
> defeito novo**.

## 1-D · Quando o app é externo e o debug está desligado

Você não vai ter `DITO_PUSH_PAYLOAD`. Não conclua nada por ausência dela. Fontes que
funcionam de qualquer forma:

| Fonte | Prova |
| --- | --- |
| `adb shell dumpsys notification --noredact` | o que o SDK **construiu**: `android.title`, `android.text`, `android.template`, `android.pictureIcon`, `actions={...}` |
| `grep FirebaseMessaging` no logcat | a mensagem **chegou ao aparelho** pelo FCM, independente do que o app fez com ela |
| print de tela | render, do ponto de vista de quem usa |
| contadores do painel | o que o backend registrou |

A combinação "FCM entregou + `dumpsys` tem o registro + painel diz entrega zero"
é um resultado **conclusivo** sem log nenhum da SDK: chegou, renderizou, não contou.

---

# Fase 2 — O ciclo de disparo

Repita este ciclo **para cada célula**, uma por vez. Não pule o passo 1 nem o 9: são
eles que fazem o relatório significar algo para quem não estava aqui.

### 1. Diga o que esta célula prova

Uma frase, antes de qualquer comando. Exemplo:

> *Célula Android × morto. Vou provar se o evento de entrega chega ao painel quando o
> processo sobe do zero por causa do push — o cenário em que o `scope.launch` sem
> fila offline pode ser congelado antes de terminar o HTTP.*

### 2. Coloque o app no estado e confirme

Comandos da Fase 1. **Confirme com `dumpsys`**, não presuma.

### 3. Arme a captura e marque `T0`

```bash
adb logcat -c && nohup adb logcat -v time > /tmp/dito-prod/$CELL.log 2>&1 & disown
T0=$(date -u +%Y-%m-%dT%H:%M:%SZ); echo "T0=$T0"
```

### 4. Peça o disparo — e espere

Diga exatamente o que configurar, e **pare**. Não siga sem a confirmação.

> Está armado. Dispare agora a campanha `<nome>` para o usuário `<alvo>`, com
> `<imagem/botões>`. O app está `<estado>`. Me avise quando tiver disparado.

### 5. Espere a chegada, com prazo

Espera limitada, e o timeout **é um resultado**, não um travamento:

```bash
for i in $(seq 1 40); do
  grep -qE "DITO_PUSH_DISPLAY|FirebaseMessaging.*Message|dumpsys-check" /tmp/dito-prod/$CELL.log && { echo "chegou em ~$((i*3))s"; break; }
  sleep 3
done
adb shell dumpsys notification --noredact > /tmp/dito-prod/$CELL.dumpsys
grep -c "pkg=$PKG" /tmp/dito-prod/$CELL.dumpsys
```

Nada em 120 s → registre `não chegou ao aparelho em 120s` e siga. Não fique
esperando indefinidamente; e não classifique ainda: pode ser painel, token ou FCM.

### 6. Colha a evidência

```bash
# a gaveta, com a notificação EXPANDIDA — colapsada não mostra imagem nem botões
adb shell input keyevent 3 && adb shell cmd statusbar expand-notifications && sleep 3
adb exec-out screencap -p > /tmp/dito-prod/$CELL.png
# expandir: ache o nó com content-desc="Expand" no uiautomator dump e toque nele
adb exec-out screencap -p > /tmp/dito-prod/$CELL-expanded.png
adb shell cmd statusbar collapse
```

Duas leituras que enganam no `dumpsys` e **não** são defeito: `android.picture=null`
é normal (a imagem grande fica em `android.pictureIcon`), e `android.largeIcon`
aparece reduzido porque o sistema redimensiona.

### 7. Se houver botão, valide o clique

No Android o toque pode ser dado por você; no iOS, peça à pessoa. Confira **três
coisas, nesta ordem**:

1. o deeplink é o **do botão**, não o do push;
2. o `action_id` é o `id` do botão tocado;
3. o receiver registrou.

**A linha do receiver chega atrasada.** `broadcastActionClick` é broadcast de
background e a fila do sistema entregou com **~57 s** de atraso em medição de
2026-07-30. Não conclua "o receiver não rodou" depois de 10 s:

```bash
until grep -q DitoNotificationActionReceiver /tmp/dito-prod/$CELL.log; do sleep 3; done
```

Com o app morto, confira também que o cold start não derrubou nada:

```bash
grep -E "E/AndroidRuntime|DITO_INTENT_EXTRAS" /tmp/dito-prod/$CELL.log
```

`DITO_INTENT_EXTRAS` com os campos preenchidos é a prova de que o payload do toque
chegou ao app host. Vazio depois de um toque é defeito; vazio num launch normal não é.

### 8. Diga o que validou

Explícito, com a linha literal. Exemplo:

> Validado: chegou (`FirebaseMessaging` às 08:02:35), renderizou
> (`android.template=BigTextStyle`, `actions=2`), o clique mapeou o `action_id`
> certo (`comprar_agora`) e o app host recebeu o payload
> (`DITO_INTENT_EXTRAS ... actionId=comprar_agora`). **Não** validado ainda: se o
> painel contou.

### 9. Feche o ciclo no painel — o passo que não pode faltar

Espere o tempo de agregação (pergunte qual é; se ninguém souber, use 5 min e
registre a espera) e **peça os números**:

> Abra o relatório da campanha `<nome>` no painel e me diga: quantas **entregas** e
> quantos **cliques** ele mostra agora para esse disparo?

Registre os dois números junto com o que o aparelho disse. É esse par que é o
produto deste playbook.

---

# Fase 3 — Reconciliação aparelho ↔ painel

A tabela que o playbook local nunca consegue produzir:

| Célula | Aparelho: renderizou | Painel: entrega | Aparelho: clicou | Painel: clique | Veredito |
| --- | --- | --- | --- | --- | --- |
| Android × aberto | | | | | |
| Android × background | | | | | |
| Android × morto | | | | | |
| … | | | | | |

Classifique cada discrepância por **padrão**, porque cada padrão aponta para um
lugar diferente do código:

| Padrão observado | Onde a perda está | Suspeito nomeado |
| --- | --- | --- |
| renderizou, painel entrega **0** | envio do evento de entrega | `Tracker.notificationReceived` — `catch` vazio, sem fila offline. Mais provável com app **morto** |
| clicou, painel clique **0** | envio do evento de clique | `notificationClick` tem fila offline; se zerou, a perda é depois dela — ver os accessors de CoreData no iOS |
| painel entrega **>0**, não renderizou | caminho de render | `canHandle` (exige `channel=DITO`), parser, ou permissão de notificação |
| não chegou ao aparelho | token ou FCM/APNs | registro do token para o usuário alvo (Fase 1-A) |
| perda **só** com app morto | ciclo de vida do envio | confirma a hipótese da abertura |
| perda **também** com app aberto | antes do envio | derruba a hipótese; investigue ingest e painel |

Se a perda for intermitente, **repita a célula 3 vezes** e reporte a contagem
(`2 de 3`). Um verde único não é evidência num defeito que se apresenta como
intermitente — e este se apresenta assim.

---

# Fase 4 — Relatório: artifact HTML

O entregável é uma **página HTML publicada como artifact**, com payload e print de
cada disparo lado a lado. Isso muda o que você coleta durante a execução, então
prepare desde o primeiro disparo: um print por célula, e a linha de log literal.

Recorte e reduza os prints antes de embutir — um print de aparelho tem ~1200x2600 e
quatro deles em tamanho cheio tornam a página impossível de carregar. Recorte a
faixa da notificação, reduza para ~900px, converta para `data:` URI.

Restrições que **quebram a página** se ignoradas:

- **Nada externo.** CSP estrita bloqueia CDN, fontes e imagens remotas. Todo CSS e
  JS inline, toda imagem como `data:` URI.
- **Sem `<!DOCTYPE>`, `<html>`, `<head>`, `<body>`** — o conteúdo é embrulhado na
  publicação. Comece pelo `<title>`.
- **Os dois temas.** Paleta em custom properties no `:root`, redefinida sob
  `@media (prefers-color-scheme: dark)` **e** sob `:root[data-theme="dark"]` e
  `:root[data-theme="light"]`, que é o que o botão de tema aplica.
- **Passe `favicon` (emoji) e `description` de uma linha.**
- **Tabelas e blocos de código** dentro de contêiner com `overflow-x: auto`.
- Estado codificado em **cor e texto**, nunca só em cor.

Estrutura obrigatória:

1. **Cabeçalho** — plataformas, versão da SDK **confirmada no aparelho**, origem do
   app (repo ou externo), aparelho e SO, data, e quem disparou.
2. **Aviso de escopo** — o que um disparo real prova e o que ele não prova; se
   houver célula de simulador iOS, a limitação do `simctl push` nomeada; se o app
   for externo com debug desligado, dizer que a ausência de `DITO_PUSH_*` é
   esperada.
3. **Diagnóstico de integração** — a tabela da Fase 0.5-E, com o caminho de cada
   arquivo checado e o valor encontrado (chave presente/ausente/vazia; **nunca o
   valor da credencial**). Vem antes da matriz, porque é o que dá ou tira validade
   dela. Toda célula `DEGRADADO POR INTEGRAÇÃO` referenciada aqui.
4. **Matriz plataforma × estado**, com `PASSA` · `FALHA` · `BLOQUEADO` ·
   `NÃO EXECUTADO` · `DEGRADADO POR INTEGRAÇÃO` · `N/A`.
5. **Reconciliação aparelho ↔ painel** — a tabela da Fase 3. É o miolo do
   relatório; coloque antes dos cartões, não no fim.
6. **Um cartão por disparo** — payload como **recebido** (extraído do log, não o que
   você esperava) à esquerda, print à direita, veredito e linha de log literal
   embaixo, e os números do painel.
7. **Problemas encontrados** — mais severo primeiro: severidade, célula,
   reprodução, esperado/observado, evidência literal, e se é determinístico ou
   intermitente (com a contagem).
8. **Bloqueios** — com a saída de erro literal.
9. **Ruído esperado** — o que parece defeito e não é: banner ausente em primeiro
   plano no iOS, `reference` vazio, `android.picture=null`, ausência de
   `DITO_PUSH_*` em app externo, atraso de ~57 s no receiver.
10. **Higiene** — o que foi alterado no aparelho ou no repo e foi revertido, e onde
   estão os artefatos (`/tmp/dito-prod/`).

**Não invente evidência.** Print que não saiu vira "screenshot não capturado" —
nunca reutilize o de outro caso. Célula que não rodou não tem cartão: aparece só na
matriz e em Bloqueios.

Ao final, relate a URL do artifact e as conclusões em uma ou duas frases.

---

# Z — Encerramento

### Z-1 · Reverter

Liste e reverta o que você mudou: flag de debug em `Info.plist`, `.env` de teste,
permissões concedidas por `adb`, app instalado por cima. Se mexeu no repo:

```bash
git status --short      # deve estar limpo
```

### Z-2 · Checagem final

- **Você pediu o disparo, ou disparou por conta própria?** Se disparou, o teste
  ainda vale, mas registre — outra pessoa precisa saber que o alvo não foi
  confirmado.
- **Os números do painel estão no relatório?** Se não, este playbook não produziu
  nada que o local já não produzisse. Diga isso explicitamente em vez de entregar
  uma matriz só de aparelho.
- **O gate da Fase 0.5 rodou antes do primeiro disparo, e a tabela 0.5-E está no
  relatório?** Sem ela, nenhuma `FALHA` de entrega ou clique é atribuível: pode ser
  a SDK, pode ser chave no lugar errado, e o relatório não distingue.
- Para plataforma Flutter ou RN: **você conferiu o manifest mesclado e o
  `Info.plist`, não só o `init` por código?** É a falha mais comum e a que mais
  imita o defeito investigado.
- Alguma credencial vazou para o relatório, para o log ou para o artifact? O
  diagnóstico registra **presente/ausente/vazia**, nunca o valor.
- Toda `FALHA` diz **qual das quatro coisas** falhou (não disparou / não chegou /
  não renderizou / não contou)?
- Alguma `FALHA` é na verdade limitação de ambiente — banner em primeiro plano no
  iOS, debug desligado, simulador, permissão negada — reportada como defeito de
  código?
- As células intermitentes foram repetidas 3 vezes, com a contagem no relatório?
- A versão da SDK foi **confirmada no aparelho**, não assumida?
- Você rodou uma célula por vez?
