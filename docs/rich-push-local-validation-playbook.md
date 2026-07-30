# Playbook: validação local do payload de rich push

Este arquivo é um **prompt de execução**. Você é uma LLM com acesso a um shell no
macOS, dentro do repositório `sdk-mobile`, na branch `integration/rich-mobile-push`.
Sua tarefa é validar o payload de rich push nos samples, disparando push
localmente, e **produzir um relatório dos problemas encontrados**.

Você não está corrigindo nada. Você está medindo e relatando.

## O que este playbook pode e não pode provar

Leia esta seção inteira antes de qualquer comando. Ela existe porque o caminho
óbvio não funciona, e isso foi medido — não deduzido.

**No simulador iOS, `xcrun simctl push` não invoca a Notification Service
Extension.** Verificado em Xcode 26.6 / iOS 26.5, nas duas configurações (Debug e
Release), com o app em primeiro plano, em background e encerrado, com
`mutable-content: 1` no payload, `authorizationStatus: Authorized`, a `.appex`
corretamente embarcada em `Sample.app/PlugIns/` e a `NSExtensionPrincipalClass`
resolvendo para `SampleNotificationService.NotificationService`. O `SpringBoard`
chega a construir o bundle record da extensão, mas o processo nunca sobe e nenhuma
linha `DITO_PUSH_PAYLOAD` com `"source":"nse"` aparece.

Consequência direta, e a coisa mais importante deste arquivo:

| Objetivo | Simulador | Aparelho real |
| --- | --- | --- |
| Push entregue, título + mensagem renderizados | ✅ valida | ✅ |
| Degradação graciosa sem rich (critério do E9) | ✅ valida | ✅ |
| **Imagem anexada** | ❌ **impossível** | obrigatório |
| **Botões de ação** | ❌ **impossível** | obrigatório |
| Clique em botão, `action_id` no evento | ❌ impossível | obrigatório |

No simulador, **os 4 casos renderizam idênticos**: título + mensagem. Isso é o
resultado correto, não um defeito. Evidência de referência: um push do caso 2
(com `image`) produziu o banner "Caso 2 / Com imagem" sem miniatura alguma.

Portanto: **não reporte "imagem não apareceu" como defeito na Parte A.** O que a
Parte A prova é entrega e degradação. Imagem e botões são a Parte D, em aparelho.

Se você tiver um aparelho iOS físico disponível, faça a Parte D — é a única que
fecha os critérios de aceitação pendentes. Se não tiver, registre a Parte D como
`NÃO EXECUTADO — sem aparelho` e **não tente substituí-la pelo simulador**.

## Regras de execução

1. **Um caso de teste por vez, em sequência.** Não dispare o próximo antes de
   registrar o resultado do anterior.
2. **Não improvise contornos.** Se um passo falhar, tente o *fallback* daquele
   passo. Se o fallback também falhar, **pare aquela plataforma**, registre
   `BLOQUEADO` com a saída de erro literal, e siga para a próxima. Inventar
   caminho alternativo invalida o teste.
3. **Não commite nada.** Você vai editar um `Info.plist` (passo A-3). Reverta no
   passo Z-1 e confirme `git status --short` limpo.
4. **Distinga "não renderizou" de "não chegou".** Se o marcador de payload
   apareceu, chegou. Se o banner apareceu, renderizou.
5. **Cite evidência literal** — linha de log ou mensagem de erro, sem paráfrase.
6. **Ausência de log não é conclusão** antes do passo de sanidade (A-5, B-4).

## Contexto que muda o resultado esperado

- **O sample Flutter não tem NSE.** Confirme:
  `grep -c NotificationService flutter/sample_application/ios/Runner.xcodeproj/project.pbxproj`
  retorna `0`. Em aparelho, o Flutter/iOS **deve** degradar para título +
  mensagem. Ali isso é sucesso.
- **O Android só processa o push se `channel=DITO`.** `DitoNotificationHandler.canHandle`
  exige a chave; sem ela o SDK ignora a mensagem silenciosamente.
- **O dump de payload vem desligado** e é ligado no passo A-3. No iOS a extensão
  lê a flag do próprio `Info.plist` — o processo da app não alcança a extensão.
- **Credenciais vazias não são defeito — mas mudam o que você mede.** O Android lê
  `android/example-app/src/main/assets/.env.development.local`, que não existe no
  repo. Renderização não depende de credencial: os quatro casos desenham sem ela, e
  `Failed to process notification received: É preciso configurar API_KEY` vai em "ruído
  esperado". O **clique**, porém, passa por um `Dito.init` que exige a chave; sem ela você
  mede o caminho degradado. Por isso B-6 pede uma chave falsa, e depois pede para tirá-la.
- **O Android também tem um simulador local, e é o único gatilho que funciona.** O serviço
  do FCM é `exported="false"` e o emulador não dá root, então `am start-service` é negado.
  Ver B-4.

## Os 4 payloads

Ordem fixa. Cada caso adiciona uma capacidade, então falha no caso N com N−1 verde
localiza o defeito na capacidade nova.

| # | Caso | O que isola |
| --- | --- | --- |
| 1 | título + mensagem | entrega e render base |
| 2 | + imagem | download do anexo e resolução de extensão |
| 3 | + botão | registro de categoria e clique no botão |
| 4 | + botão + imagem | as duas assíncronas concorrendo |

O caso 4 é o de maior risco no iOS: as duas operações assíncronas terminam em
ordem imprevisível sob um único `DispatchGroup`, e o registro de categoria depende
de uma barreira de round-trip para o daemon.

`actions` e `custom_data` são **strings JSON**, não objetos — é o formato que os
channel-senders produzem. O parser aceita objeto decodificado, mas testar com
objeto não testa produção.

```bash
mkdir -p /tmp/dito-push && cd /tmp/dito-push

cat > case1.apns <<'JSON'
{"aps":{"alert":{"title":"Caso 1","body":"Titulo e mensagem"},"sound":"default","mutable-content":1},
 "channel":"DITO","notification":"case1-notification","user_id":"playbook-user-001",
 "reference":"playbook-ref-001","title":"Caso 1","message":"Titulo e mensagem","link":"app://dito/case1"}
JSON

cat > case2.apns <<'JSON'
{"aps":{"alert":{"title":"Caso 2","body":"Com imagem"},"sound":"default","mutable-content":1},
 "channel":"DITO","notification":"case2-notification","user_id":"playbook-user-002",
 "reference":"playbook-ref-002","title":"Caso 2","message":"Com imagem","link":"app://dito/case2",
 "image":"https://picsum.photos/id/1015/800/400.jpg"}
JSON

cat > case3.apns <<'JSON'
{"aps":{"alert":{"title":"Caso 3","body":"Com botao"},"sound":"default","mutable-content":1},
 "channel":"DITO","notification":"case3-notification","user_id":"playbook-user-003",
 "reference":"playbook-ref-003","title":"Caso 3","message":"Com botao","link":"app://dito/case3",
 "actions":"[{\"id\":\"comprar_agora\",\"label\":\"Comprar agora\",\"link\":\"app://dito/comprar\"},{\"id\":\"ver_depois\",\"label\":\"Ver depois\",\"link\":\"app://dito/depois\"}]",
 "custom_data":"{\"nivel_programa\":\"ouro\",\"id_pedido\":\"12345\"}"}
JSON

cat > case4.apns <<'JSON'
{"aps":{"alert":{"title":"Caso 4","body":"Botao e imagem"},"sound":"default","mutable-content":1},
 "channel":"DITO","notification":"case4-notification","user_id":"playbook-user-004",
 "reference":"playbook-ref-004","title":"Caso 4","message":"Botao e imagem","link":"app://dito/case4",
 "image":"https://picsum.photos/id/1025/800/400.jpg",
 "actions":"[{\"id\":\"resgatar\",\"label\":\"Resgatar\",\"link\":\"app://dito/resgatar\"},{\"id\":\"nao_quero\",\"label\":\"Nao quero\",\"link\":\"app://dito/nao\"}]",
 "custom_data":"{\"campanha\":\"playbook\",\"id_pedido\":\"67890\"}"}
JSON

for f in case*.apns; do python3 -c "import json;json.load(open('$f'));print('$f ok')"; done
curl -sI https://picsum.photos/id/1015/800/400.jpg | head -1
```

Sem internet, os casos 2 e 4 falham por rede, não por código: `BLOQUEADO`.

---

# Parte A — iOS simulador (entrega e degradação)

> Todos os comandos desta parte foram executados e verificados.

### A-1. Simulador

```bash
xcrun simctl list devices available | grep -E "iPhone 1[5-9]" | head -3
SIM=<udid>
xcrun simctl boot "$SIM" 2>/dev/null || echo "já bootado"
open -a Simulator
xcrun simctl bootstatus "$SIM" -b
```

### A-2. Gerar o projeto

```bash
cd ios && xcodegen generate && cd ..
```

### A-3. Ligar o dump de payload (temporário)

```bash
/usr/libexec/PlistBuddy -c "Set :DitoPushDebugLog true" \
  ios/SampleApplication/NotificationServiceExtension/Info.plist
/usr/libexec/PlistBuddy -c "Print :DitoPushDebugLog" \
  ios/SampleApplication/NotificationServiceExtension/Info.plist   # true
```

### A-4. Build, instalar, confirmar embarque

```bash
cd ios
xcodebuild -project DitoSDK.xcodeproj -scheme Sample -configuration Debug \
  -destination "id=$SIM" -derivedDataPath /tmp/dito-push/dd \
  build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -3
cd ..
APP=$(find /tmp/dito-push/dd/Build/Products -name "Sample.app" -maxdepth 3 | head -1)
ls "$APP/PlugIns/"                                        # SampleNotificationService.appex
ls "$APP/Frameworks/" | grep DitoSDKNotificationService    # framework embarcado
xcrun simctl install "$SIM" "$APP"
xcrun simctl launch "$SIM" br.com.dito.samplesdk EnabledDebug
```

Os dois `ls` importam: sem a `.appex` e sem o framework embarcado, nada de rich
funcionaria **nem em aparelho**, e a causa não seria o payload. Se faltar algum,
pare e reporte — é defeito de configuração de build.

> `CODE_SIGNING_ALLOWED=NO` produz um bundle **sem entitlements**. Isso desativa o
> caminho de notificação em background (`didReceiveRemoteNotification`), então não
> espere marcador `"source":"app"` de recebimento aqui. Não é defeito.

### A-5. Permissão de notificação

Não existe comando `simctl` para conceder: `xcrun simctl privacy` não expõe o
serviço de notificações (a lista vai de `calendar` a `siri`). O diálogo tem de ser
respondido na interface. Use a CLI de computer-use do Orca — verificada:

```bash
pgrep -f "Simulator.app/Contents/MacOS/Simulator"     # guarde o PID
orca computer get-app-state --app pid:<PID> --json \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['result']['snapshot']['treeText'])" \
  | grep -E "Permitir|Allow|deseja"
```

O Simulator **não aparece** em `orca computer list-apps`; endereçar por `pid:` é
obrigatório. Clique no índice do botão `Permitir`:

```bash
orca computer click --app pid:<PID> --element-index <indice-do-Permitir> --json
```

Confirme que foi concedida:

```bash
xcrun simctl spawn "$SIM" log show --last 2m \
  --predicate 'eventMessage CONTAINS[c] "authorizationStatus"' --style compact \
  2>/dev/null | grep -o "authorizationStatus: [A-Za-z]*" | tail -1
```

Deve dizer `Authorized`. Se disser `NotDetermined` ou `Denied`, **pare a Parte A**:
sem autorização o sistema descarta o push e todo resultado seria falso negativo.
Reinstalar o app reseta a permissão — se você reinstalar, repita este passo.

### A-6. Rodar os 4 casos

Para cada `N` de 1 a 4, um por vez:

```bash
N=1
xcrun simctl spawn "$SIM" log stream --level debug \
  --predicate 'subsystem == "br.com.dito.sdk" OR process CONTAINS "SampleNotification"' \
  > /tmp/dito-push/ios-case$N.log 2>&1 &
MON=$!
sleep 3
xcrun simctl push "$SIM" br.com.dito.samplesdk /tmp/dito-push/case$N.apns
sleep 10
kill $MON 2>/dev/null
grep -c DITO_PUSH /tmp/dito-push/ios-case$N.log
xcrun simctl io "$SIM" screenshot /tmp/dito-push/ios-case$N.png
```

O banner só aparece com o app **fora** do primeiro plano. Encerre antes de cada
push: `xcrun simctl terminate "$SIM" br.com.dito.samplesdk`.

**Critério para os 4 casos, no simulador:**

- ✅ `PASSA` — banner com o título e o corpo do caso, app não travou.
- ❌ `FALHA` — nenhum banner, ou título/corpo errados, ou o app travou.
- Ausência de imagem e de botões: **esperado**, não registre como falha.
- `grep -c DITO_PUSH` retornando `0`: **esperado** no simulador, porque a NSE não
  roda e o caminho de background está sem entitlements. Registre o número, sem
  classificar como defeito.

Uma verificação que vale a pena aqui: se **aparecer** algum
`DITO_PUSH_PAYLOAD` com `"source":"nse"`, a premissa deste playbook mudou (a
limitação do `simctl push` foi corrigida em alguma versão). Reporte isso em
destaque — passa a ser possível validar rich push no simulador, e os critérios de
aparelho da Parte D valem aqui também.

---

# Parte B — Android nativo (example-app)

> **Executada e verificada** em 2026-07-30, emulador `Medium_Phone` API 37, no commit
> `656b8f6`. Os quatro casos renderizaram. As formas de comando abaixo são as que
> funcionaram, não hipóteses — mas o emulador é instável sob automação, então leia as
> ressalvas antes de culpar o payload.

Diferente do iOS, o Android **renderiza rich push no emulador**: imagem e botões são
desenhados pelo próprio SDK no processo do app, sem extensão separada. Esta parte é a única
que valida rich push sem aparelho físico, e é onde está o maior valor deste playbook.

### B-1. Pré-requisitos

`java` e `emulator` provavelmente **não estão no PATH**, e isso não é ausência de
ferramenta — foi o que me fez registrar esta parte como bloqueada na primeira execução.
Procure antes de desistir:

```bash
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"

java -version || echo "BLOQUEADO: sem Java, pare a Parte B"
emulator -list-avds
```

Sem AVD: `BLOQUEADO`. Não crie um — isso muda o ambiente do teste.

```bash
emulator -avd <avd> -no-snapshot -no-boot-anim -memory 4096 -cores 4 &
adb wait-for-device
adb shell 'while [[ -z $(getprop sys.boot_completed) ]]; do sleep 2; done'
sleep 30   # o launcher ainda está assentando; começar antes disso provoca ANR
```

`-memory 4096 -cores 4` não é capricho: com o default, o SystemUI e o Pixel Launcher dão
ANR no meio da automação, e o diálogo "isn't responding" **engole todos os taps seguintes**.
Se aparecer, dispense-o (tap em "Wait") antes de continuar; se voltar sempre, reinicie o
emulador em vez de insistir.

### B-2. Instalar e abrir

```bash
cd android && ./gradlew :example-app:installDebug 2>&1 | tail -5 && cd ..
adb shell monkey -p br.com.dito.example_app -c android.intent.category.LAUNCHER 1
adb shell pm grant br.com.dito.example_app android.permission.POST_NOTIFICATIONS
```

A permissão é obrigatória no Android 13+; sem ela nada aparece e parece bug de payload.

### B-3. Monitor

Mesmo prefixo `DITO_PUSH_PAYLOAD` do iOS, mas **formato diferente**: `key=value` com
`data={...}`, não JSON. Não tente parsear como JSON. `DITO_PUSH_DISPLAY` separa "processei o
payload" de "consegui desenhar".

```bash
adb logcat -c
adb logcat -v time > /tmp/dito-push/and-caseN.log 2>&1 &
```

Filtre depois, no arquivo. Filtrar no pipe do `logcat` esconde o crash e o ANR, que é
exatamente o que você precisa ver quando algo falha:

```bash
grep -E "DITO_PUSH_PAYLOAD|DITO_PUSH_DISPLAY|DitoNotificationHandler|DitoRichPushParser|NotificationDisplayHelper|NotificationOpenedActivity|DitoNotificationActionReceiver|AndroidRuntime" /tmp/dito-push/and-caseN.log
```

**`DITO_PUSH_PAYLOAD` só sai com `Dito.options.debug == true`**, que o
`DitoExampleApplication` já configura. Se a linha desaparecer no meio da bateria, não
conclua "o payload não chegou": confirme com `DITO_PUSH_DISPLAY` e com o registro do
NotificationManager (B-5).

### B-4. Disparar

**O `am start-service` do FCM não funciona**, e não é questão de forma do comando:

```
Error: Requires permission not exported from uid 10232
```

O `DitoMessagingService` é `exported="false"`, e a imagem do emulador é de produção
(`adb root` responde `adbd cannot run as root`), então não há como contornar. O caminho é o
simulador embutido do sample, que lê arquivos de `files/dito_notifications_debug` e é
acionado pela `NotificationDebugActivity` — também `exported="false"`, portanto alcançável
só pela UI, pelo botão "Debug de Notificações" na MainActivity.

O nome do arquivo importa: o sample só lista arquivos que começam com `notification_` e
terminam em `.json`. Um `and-case1.json` não aparece na lista.

```bash
cat > /tmp/dito-push/notification_case1.json <<'JSON'
{"data":{"channel":"DITO","notification":"case1-notification","user_id":"playbook-user-001","reference":"playbook-ref-001","title":"Caso 1","message":"Titulo e mensagem","link":"app://dito/case1"}}
JSON

# Um payload por rodada: o botão "Última" escolhe por data de modificação, e o próprio app
# salva uma cópia do payload a cada simulação — sem limpar, você simula o caso anterior.
adb shell run-as br.com.dito.example_app sh -c 'rm -f files/dito_notifications_debug/*.json'
adb push /tmp/dito-push/notification_case1.json /data/local/tmp/
adb shell run-as br.com.dito.example_app mkdir -p files/dito_notifications_debug
adb shell run-as br.com.dito.example_app \
  cp /data/local/tmp/notification_case1.json files/dito_notifications_debug/notification_case1.json
```

Depois, na UI, em sequência: **Debug de Notificações** → **Última** → **Simular Esta
Notificação**. Localize cada botão por `resource-id` em vez de coordenada fixa, porque a
posição muda com o scroll:

```bash
adb shell uiautomator dump /sdcard/ui.xml && adb shell cat /sdcard/ui.xml
# procure br.com.dito.example_app:id/buttonNotificationDebug, :id/buttonLatest, :id/buttonSimulate
adb shell input tap <x> <y>
```

Não use `pm clear` entre casos para limpar a gaveta: ele força um cold start com
re-registro de FCM, e essa carga é o que dispara o ANR do SystemUI. Cada caso tem título
próprio (`Caso 1`..`Caso 4`), então acumular notificações não confunde a evidência.

### B-5. Critérios

A evidência **autoritativa** do que o SDK construiu é o registro do NotificationManager, não
a árvore de UI:

```bash
adb shell dumpsys notification --noredact > /tmp/dito-push/and-caseN.dumpsys
# no bloco pkg=br.com.dito.example_app: android.title, android.text, android.template,
# android.pictureIcon, e a lista actions={...}
```

| Caso | Log | Registro | Render |
| --- | --- | --- | --- |
| 1 | `DITO_PUSH_PAYLOAD` com `data_keys=[...]` | `template=BigTextStyle` | título + corpo |
| 2 | idem, com `image` nas chaves | `template=BigPictureStyle`, `android.pictureIcon` presente | miniatura colapsada, imagem expandida |
| 3 | `data_keys` com `actions` | `actions=2`, com os labels exatos | dois botões |
| 4 | `data_keys` com `actions` e `image` | `BigPictureStyle` **e** `actions=2` | imagem **e** botões |

Atenção a duas leituras que enganam: `android.picture=null` é normal — a imagem grande fica
em `android.pictureIcon` — e `android.largeIcon` aparece reduzido (algo como 126x63) porque
o sistema redimensiona ícone grande. Nenhum dos dois é defeito.

Print por caso, com a gaveta aberta pelo comando do systemui e a notificação **expandida** —
colapsada, a notificação não mostra imagem nem botões:

```bash
adb shell input keyevent 3 && adb shell cmd statusbar expand-notifications && sleep 3
adb exec-out screencap -p > /tmp/dito-push/and-caseN.png
# expandir: ache o nó com content-desc="Expand" no uiautomator dump e toque nele
adb exec-out screencap -p > /tmp/dito-push/and-caseN-expanded.png
adb shell cmd statusbar collapse
```

O gesto de arrastar do topo é pior: dependendo da carga abre as configurações rápidas em vez
da lista, e a metade direita do topo abre sempre as configurações rápidas.

### B-6. Clique — o caminho de maior valor

**Exige credencial no manifest.** Sem `br.com.dito.API_KEY`, o toque na notificação é
inconclusivo: o SDK não inicializa e você mede o caminho degradado, não o normal. Crie o
arquivo (é gitignored, e uma chave falsa serve — só o envio ao ingest depende de ela ser
real):

```bash
printf 'API_KEY=playbook-fake-api-key\n' > android/example-app/src/main/assets/.env.development.local
cd android && ./gradlew :example-app:installDebug && cd ..
```

Dispare o caso 3, expanda a notificação e toque em **Comprar agora**. Espere:

```
D/NotificationOpenedActivity: Deep Link: app://dito/comprar
D/NotificationOpenedActivity: ✅ Broadcasting notification action click: comprar_agora
D/DitoNotificationActionReceiver: Notification action clicked: id=comprar_agora, notification=case3-notification
```

Três coisas para conferir, nessa ordem: o deeplink é o **do botão** (`app://dito/comprar`),
não o do push (`app://dito/case3`); o `action_id` é o `id` do botão tocado; e o receiver
registrou o clique.

**A linha do receiver chega atrasada.** O `broadcastActionClick` é um broadcast de background,
e a fila do sistema entregou com **~57 segundos** de atraso na medição de 2026-07-30
(`✅ Broadcasting` às 10:00:05, `Notification action clicked` às 10:01:03). Não conclua
"o receiver não rodou" depois de 10 segundos — espere pela linha:

```bash
until grep -q DitoNotificationActionReceiver /tmp/dito-push/and-click.log; do sleep 3; done
```

Depois repita com o **mesmo payload sem a chave `reference`**. O resultado esperado hoje é
idêntico ao de cima. Se aparecer

```
W/NotificationOpenedActivity: ❌ Cannot call notificationClick: reference=, notificationId=...
```

você encontrou uma **regressão** do commit `840f8f3`: `reference` está em retirada dos
payloads da Dito e voltou a ser obrigatório em algum gate. Reporte como Alto, com a linha
literal. Confira também que o clique sem `reference` gera evento de entrega — o mesmo gate
existia em `DitoNotificationHandler` e zerava a entrega de campanhas sem o campo.

Por fim, **remova a credencial de teste** e confirme que o toque na notificação apenas
degrada, sem derrubar o app:

```bash
rm android/example-app/src/main/assets/.env.development.local
cd android && ./gradlew :example-app:installDebug && cd ..
# esperado no logcat, e o app abrindo normalmente:
# W/NotificationOpenedActivity: Could not initialize Dito on click: É preciso configurar API_KEY...
```

Um `E/AndroidRuntime ... RuntimeException` com `Dito.init` no topo da pilha é regressão do
commit `bd77c28` — e é o cenário de Flutter e React Native, que passam credencial por
código e não têm chave no manifest.

---

# Parte C — Flutter (sample_application)

### C-1. Android — o build precisa da SDK nativa local

O plugin consome a SDK Android como **artefato publicado**, não como módulo do repo, então
recurso novo em `android/dito-sdk` só compila aqui depois de publicado. Use o escape hatch,
com a versão que está em `android/dito-sdk/build.gradle.kts`:

```bash
cd android && VERSION_NAME=4.0.0 ./gradlew :dito-sdk:publishReleasePublicationToMavenLocal -x test -x lint && cd ..
touch flutter/android/.use_local_dito_android_sdk
cd flutter/sample_application && flutter build apk --debug && cd ../..
```

Se `flutter build apk` reclamar `Could not find br.com.dito:ditosdk:<versão>`, o pin do
plugin não bate com a SDK do repositório. Rode `./scripts/check-version-pins.sh`: é
exatamente esse desalinhamento que ele reprova.

**Não há gatilho de push local neste sample** — ele não tem a tela de Debug de Notificações
do example-app nativo, e o serviço do FCM continua `exported="false"`. Portanto os 4 casos de
renderização **não são executáveis aqui**; registre `NÃO EXECUTADO` e diga por quê. O
comportamento de render é o mesmo código já medido na Parte B.

O que **é** executável, e é o que importa nesta parte, é o **clique**: a
`NotificationOpenedActivity` é `exported="true"` com a ação
`br.com.dito.ditosdk.notification.NOTIFICATION_CLICK`, então dá para entregar um clique
direto pelo `adb`:

```bash
adb shell 'am start -a br.com.dito.ditosdk.notification.NOTIFICATION_CLICK \
  -n br.com.dito.example.sample_application/br.com.dito.ditosdk.notification.NotificationOpenedActivity \
  --es br.com.dito.ditosdk.DITO_NOTIFICATION_ID case3-notification \
  --es br.com.dito.ditosdk.DITO_DEEP_LINK app://dito/comprar \
  --es action_id comprar_agora --es action_label "Comprar agora" \
  --es custom_data "{\"nivel_programa\":\"ouro\",\"id_pedido\":\"12345\"}"'
```

Espere: nenhum `E/AndroidRuntime`, a `MainActivity` abrindo com os extras, e a linha do
`DitoNotificationActionReceiver` — que chega com dezenas de segundos de atraso, ver B-6.

> **Atenção antes de disparar:** o sample Flutter inicializa com **credenciais reais** de um
> `.env` — a tela mostra "SDK initialized at startup (API Key/Secret from .env)". Um clique
> sintético aqui é enviado ao ingest **de verdade**, com o `notification` que você inventou.
> Se isso não for aceitável, apague o `.env` antes, ou pare nesta linha e registre
> `NÃO EXECUTADO — evita escrever no ambiente real`.

Se o app já tiver uma instância da `NotificationOpenedActivity` viva, o `am start` cai em
`onNewIntent` — que a Activity **não implementa** — e o clique é engolido sem log. Um
`am force-stop` antes de cada disparo evita medir isso por acidente.

`reference` no mapa do Dart vem vazio nas duas plataformas: o iOS parou de lê-lo e o Android
parou de exigi-lo. Registre o que observou, **não reporte como defeito novo**.

### C-2. iOS — degradação

No simulador esta combinação é **duplamente degradada**: o sample Flutter não tem
NSE, e o `simctl push` não invocaria a NSE mesmo se tivesse. Portanto o resultado
esperado é idêntico ao da Parte A, e o teste **não distingue** as duas causas.
Rode para confirmar que a entrega funciona, e registre-o como tal:

```bash
flutter run -d "$SIM" 2>&1 | tee /tmp/dito-push/flu-ios-run.log
xcrun simctl push "$SIM" br.com.dito.example.sampleApplication /tmp/dito-push/case2.apns
```

- Título + mensagem, sem travar → `PASSA`.
- Nada apareceu, ou travou → `FALHA`. Ausência de extensão nunca deve impedir a
  entrega.

---

# Parte D — Aparelho iOS físico (imagem e botões)

Só esta parte fecha os critérios de aceitação pendentes do E9. Sem aparelho:
`NÃO EXECUTADO — sem aparelho`, e **não substitua pelo simulador**.

### D-1. Requisitos

- iPhone físico conectado, com perfil de provisionamento válido (a Parte A usa
  `CODE_SIGNING_ALLOWED=NO`; aqui **não dá** — push real exige entitlement
  `aps-environment`).
- Um caminho de envio: chave APNs `.p8` do time, ou o token FCM do aparelho. O
  sample mostra o token na tela e o registra no log
  (`✅ AppDelegate: FCM registration token obtido`). No simulador ele exibe
  "Token FCM: Não disponível no simulador", que é outra confirmação de que rich
  push não se valida ali.
- `DitoPushDebugLog` = `true` no `Info.plist` da extensão (passo A-3).

### D-2. Instalar e monitorar

```bash
xcrun devicectl list devices
cd ios && xcodebuild -project DitoSDK.xcodeproj -scheme Sample -configuration Debug \
  -destination "platform=iOS,id=<device-udid>" build install
```

Monitore os **dois processos** — app e extensão rodam separados:

```bash
xcrun devicectl device console --device <device-udid> 2>&1 \
  | grep -E "DITO_PUSH_PAYLOAD|DITO_PUSH_RAW" | tee /tmp/dito-push/dev-case$N.log
```

### D-3. Enviar os 4 casos

Converta cada `.apns` para o formato do seu canal de envio, preservando
`mutable-content: 1` e as chaves de dados no nível superior. Um caso por vez, com
o app **em background** (é o cenário em que a NSE roda e o banner aparece).

### D-4. Critérios em aparelho

| Caso | Log esperado | Render esperado |
| --- | --- | --- |
| 1 | `"event":"received"`, `"source":"nse"`, `has_image:false`, `action_ids:[]` | título + corpo |
| 2 | `has_image:true` e campo `image` | miniatura; imagem grande ao expandir |
| 3 | `action_ids:["comprar_agora","ver_depois"]`, `custom_data_keys:["id_pedido","nivel_programa"]` | dois botões com os labels exatos |
| 4 | `has_image:true` **e** os dois `action_ids` | imagem **e** botões juntos |

Três verificações que valem mais que as óbvias:

- **Duas linhas por push.** Uma com `"source":"nse"` e uma com `"source":"app"`.
  Só a do app significa que a extensão não rodou — aí a causa é embarque ou
  linkagem, não payload.
- **`DITO_PUSH_RAW` tem de sair redigido.**
  `grep -c "playbook-user-00" /tmp/dito-push/dev-case*.log` deve dar `0` e
  `grep -c "<redacted>"` deve dar diferente de `0`. User id em claro no log do
  aparelho é vazamento de identidade: **Alto**.
- **Caso 3 e 4, clique no primeiro botão.** Espere `"event":"clicked"` com
  `action_id` igual ao `id` do botão (`comprar_agora`, `resgatar`) — não o
  `custom_data` da campanha. Se vier `"event":"clicked"` sem `action_id`, o
  mapeamento de `actionIdentifier` falhou. Se o app abrir o deeplink do push em
  vez do do botão, reporte também.
- **Caso 4 rodado 3 vezes.** É o caso com corrida entre download e registro de
  categoria; um resultado verde uma única vez não é evidência. Se os botões
  aparecerem em 2 de 3, reporte como intermitente com a contagem.

---

# Z. Encerramento

### Z-1. Reverter (obrigatório)

```bash
cd /Users/igor.duarte/workspace/projects/sdk-mobile
git checkout ios/SampleApplication/NotificationServiceExtension/Info.plist
git status --short
```

Deve estar limpo. Se algo aparecer, liste no relatório.

### Z-2. Capturar evidência visual durante a execução

O relatório final é uma **página HTML publicada como artifact**, com o payload e o
print de tela de cada caso lado a lado. Isso muda o que você precisa coletar
enquanto roda, então prepare desde o caso 1:

- **Um screenshot por caso, por plataforma.** iOS:
  `xcrun simctl io "$SIM" screenshot /tmp/dito-push/ios-case$N.png`.
  Android: `adb exec-out screencap -p > /tmp/dito-push/and-case$N.png`.
  Tire o print com a notificação **visível** — no iOS o banner só aparece com o
  app fora do primeiro plano, e dura poucos segundos.
- **A linha de log literal** de cada caso, guardada em `/tmp/dito-push/*.log`.

### Z-3. Montar o relatório HTML

Recorte e reduza os prints antes de embutir. Um screenshot de iPhone tem ~1200x2600
e a página fica impossível de carregar com quatro deles em tamanho cheio. O recorte
da faixa do banner é o que interessa. Rode um script Python que, para cada
`*case*.png` em `/tmp/dito-push`:

1. recorta a faixa superior onde o banner aparece (algo como `crop((0, 60, largura, 620))`,
   ajustando se o print for de outra tela);
2. reduz com `thumbnail((900, 900))`;
3. salva como PNG otimizado em memória e converte para `data:image/png;base64,...`;
4. grava o mapa `nome -> data URI` num JSON em `/tmp/dito-push/shots.json`, e
   imprime o tamanho em KB de cada um para você notar se algum ficou grande demais.

Sem `PIL` disponível: `pip install pillow`, ou reduza com `sips -Z 900 arquivo.png`
e converta com `base64 -i arquivo.png`.

Escreva a página num arquivo e publique com a ferramenta de Artifact. Restrições
que **quebram a página** se ignoradas:

- **Nada externo.** Uma CSP estrita bloqueia CDN, fontes e imagens remotas. Todo
  CSS e JS inline, toda imagem como `data:` URI. É por isso que os prints são
  convertidos para base64 acima.
- **Sem `<!DOCTYPE>`, `<html>`, `<head>` ou `<body>`** no arquivo — o conteúdo é
  embrulhado na publicação. Comece pelo `<title>` e siga com o conteúdo.
- **Os dois temas.** A página é renderizada no tema de quem abre. Defina a paleta
  em custom properties no `:root`, redefina sob
  `@media (prefers-color-scheme: dark)` e também sob `:root[data-theme="dark"]` e
  `:root[data-theme="light"]`, que é o que o botão de tema aplica.
- **Passe um `favicon`** (um emoji) e uma `description` de uma linha.
- **Tabelas e blocos de código** dentro de um contêiner com `overflow-x: auto`,
  para o corpo da página nunca rolar na horizontal.

Estrutura obrigatória da página:

1. **Cabeçalho** — branch, commit, data, e o ambiente medido (macOS, Xcode,
   simulador/iOS, AVD/API, Flutter, aparelho ou "nenhum").
2. **Aviso de escopo, em destaque** — o que este ambiente pode e não pode provar,
   com a limitação do `simctl push` nomeada. Sem isso o leitor interpreta a
   ausência de imagem como defeito.
3. **Matriz de resultados** — a mesma da tabela abaixo, com o estado codificado em
   cor *e* em texto (nunca só em cor).
4. **Um cartão por caso**, e este é o miolo do relatório: o payload JSON à esquerda
   (ou acima, no mobile) e o print correspondente à direita, com o veredito e a
   linha de log literal embaixo. É o pareamento payload↔tela que torna o relatório
   útil para quem não rodou.
5. **Problemas encontrados** — mais severo primeiro, cada um com severidade,
   plataforma/caso, reprodução, esperado/observado, evidência literal e se é
   determinístico.
6. **Bloqueios** — com a saída de erro literal.
7. **Ruído esperado** — o que parece defeito e não é.
8. **Higiene** — `git status --short` limpo após Z-1, onde estão os artefatos.

Matriz, com os mesmos estados de sempre:

| Caso | A: iOS sim (entrega) | B: Android | C1: Flutter/Android | C2: Flutter/iOS | D: aparelho (rich) |
| --- | --- | --- | --- | --- | --- |
| 1 título + mensagem | | | | | |
| 2 + imagem | | | | | |
| 3 + botão | | | | | |
| 4 + botão + imagem | | | | | |

`PASSA` · `FALHA` · `BLOQUEADO` · `NÃO EXECUTADO` · `N/A`

Lembrete que pertence ao relatório, não só a este playbook: ausência de imagem e
de botões nas colunas A e C2 é `PASSA`.

**Não invente evidência.** Se um print não saiu, o cartão daquele caso diz
"screenshot não capturado" — nunca reutilize o print de outro caso. Se uma
plataforma não rodou, o cartão dela não existe; ela aparece só na matriz e em
Bloqueios.

Ao final, relate ao usuário a URL do artifact publicado e as conclusões em uma ou
duas frases. O artifact é o entregável; o texto é o resumo.


### Z-4. Checagem final

- Toda linha `FALHA` tem evidência literal, não paráfrase?
- Algum `FALHA` é na verdade bloqueio de ambiente (rede, permissão, log
  desligado, limitação do simulador) reportado como defeito de código?
- A sanidade passou nas plataformas em que você concluiu "não chegou"? Se não,
  reclassifique para `BLOQUEADO`.
- Você rodou os casos em sequência, um por vez?
- A coluna D está preenchida ou marcada `NÃO EXECUTADO` com motivo? Sem ela,
  imagem e botões continuam sem validação — diga isso explicitamente na conclusão
  em vez de deixar implícito.
