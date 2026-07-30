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
- **Credenciais vazias não são defeito.** O Android lê
  `android/example-app/src/main/assets/.env.development.local`, que não existe no
  repo. Renderização não depende de credencial; só o envio ao ingest. Falha de
  ingest vai em "ruído esperado".

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

> **Não verificado.** O ambiente onde este playbook foi escrito não tinha Java
> (`Unable to locate a Java Runtime`), então nenhum comando desta parte foi
> executado. Trate as formas exatas como hipótese: se um comando falhar, use o
> fallback e **reporte o comando que falhou** — isso é resultado útil.

Diferente do iOS, o Android **renderiza rich push no emulador**: imagem e botões
são desenhados pelo próprio SDK no processo do app, sem extensão separada. Esta
parte é a única que valida rich push sem aparelho físico.

### B-1. Pré-requisitos

```bash
java -version || echo "BLOQUEADO: sem Java, pare a Parte B"
emulator -list-avds
```

Sem AVD: `BLOQUEADO`. Não crie um — isso muda o ambiente do teste.

```bash
emulator -avd <avd> -no-snapshot-load &
adb wait-for-device
adb shell 'while [[ -z $(getprop sys.boot_completed) ]]; do sleep 1; done'
```

### B-2. Instalar e abrir

```bash
cd android && ./gradlew :example-app:installDebug 2>&1 | tail -5 && cd ..
adb shell monkey -p br.com.dito.example_app -c android.intent.category.LAUNCHER 1
adb shell pm grant br.com.dito.example_app android.permission.POST_NOTIFICATIONS
```

A permissão é obrigatória no Android 13+; sem ela nada aparece e parece bug de
payload.

### B-3. Monitor

Mesmo prefixo `DITO_PUSH_PAYLOAD` do iOS, mas **formato diferente**: `key=value`
com `data={...}`, não JSON. Não tente parsear como JSON. `DITO_PUSH_DISPLAY`
separa "processei o payload" de "consegui desenhar".

```bash
adb logcat -c
adb logcat | grep -E "DITO_PUSH_PAYLOAD|DITO_PUSH_DISPLAY|DitoNotificationHandler|DitoRichPushParser|NotificationDisplayHelper|NotificationOpenedActivity|DitoNotificationActionReceiver" \
  > /tmp/dito-push/and-case$N.log 2>&1 &
```

### B-4. Disparar e sanidade

**Método primário** — entregar direto ao serviço que o manifest registra
(`DitoMessagingService`), com as chaves como extras. Caso 1:

```bash
adb shell am start-service \
  -a com.google.firebase.MESSAGING_EVENT \
  -n br.com.dito.example_app/br.com.dito.ditosdk.notification.DitoMessagingService \
  --es channel DITO --es notification case1-notification \
  --es user_id playbook-user-001 --es reference playbook-ref-001 \
  --es title "Caso 1" --es message "Titulo e mensagem" --es link "app://dito/case1"
```

Casos 2 a 4: acrescente `--es image "<url>"`, `--es actions '<json>'`,
`--es custom_data '<json>'` com os mesmos valores dos `.apns`. As strings JSON têm
aspas duplas — envolva em aspas simples.

**Sanidade:** se o primeiro caso não produzir nenhuma linha `DITO_PUSH_PAYLOAD` no
logcat, o gatilho não funcionou. Não conclua "entrega quebrada" — vá ao fallback.
`Permission Denial` ou `Service not found` significam o mesmo.

**Fallback** — o sample tem simulador embutido
(`NotificationDebugHelper.simulateNotification`), acionado pela
`NotificationDebugActivity`, que lê arquivos de `files/dito_notifications_debug`:

```bash
cat > /tmp/dito-push/and-case1.json <<'JSON'
{"data":{"channel":"DITO","notification":"case1-notification","user_id":"playbook-user-001","reference":"playbook-ref-001","title":"Caso 1","message":"Titulo e mensagem","link":"app://dito/case1"}}
JSON
adb push /tmp/dito-push/and-case1.json /data/local/tmp/
adb shell run-as br.com.dito.example_app mkdir -p files/dito_notifications_debug
adb shell run-as br.com.dito.example_app \
  cp /data/local/tmp/and-case1.json files/dito_notifications_debug/and-case1.json
adb shell am start -n br.com.dito.example_app/.NotificationDebugActivity
```

A activity é `exported="false"`; se o `am start` for negado, registre
`BLOQUEADO — sem gatilho local de push no Android` com as duas saídas de erro.
Esse é um resultado legítimo e importante: significa que o Android não tem caminho
de validação local sem alterar o app.

### B-5. Critérios

| Caso | Log | Render |
| --- | --- | --- |
| 1 | `DITO_PUSH_PAYLOAD` com `data_keys=[...]` + `DITO_PUSH_DISPLAY` | título + corpo |
| 2 | `DITO_PUSH_DISPLAY` indicando imagem | miniatura colapsada, imagem expandida |
| 3 | `DitoRichPushParser` com as duas actions | dois botões, labels exatos |
| 4 | imagem e actions na mesma linha | imagem **e** botões |

`adb exec-out screencap -p > /tmp/dito-push/and-case$N.png` por caso.

### B-6. Clique — o gate de `reference`

Este é o ponto de maior valor no Android. `NotificationOpenedActivity` **só reporta
o clique quando `reference` não está vazio**; caso contrário descarta o evento com
uma linha começando por `❌ Cannot call notificationClick`. O campo `reference`
está em retirada dos payloads da Dito e o iOS já parou de lê-lo, então teste os
dois lados:

1. Caso 3 **com** `reference` → o clique deve ser reportado.
2. Caso 3 **sem** a chave `reference` → se aparecer `❌ Cannot call notificationClick`,
   você reproduziu a perda silenciosa de cliques. **Reporte como Alto**, com a
   linha literal.

Confirme também que o `action_id` no evento é o `id` do botão tocado
(`comprar_agora`), e que o app abre o link **do botão** (`app://dito/comprar`), não
o do push.

---

# Parte C — Flutter (sample_application)

### C-1. Android — deve renderizar rich push

```bash
cd flutter/sample_application && flutter pub get && flutter devices
flutter run -d <emulator-id> 2>&1 | tee /tmp/dito-push/flu-android-run.log
```

Dispare os 4 casos pelo método de B-4, trocando o pacote para
`br.com.dito.example.sample_application` e o componente do serviço conforme
`grep -n "MESSAGING_EVENT" -B3 flutter/sample_application/android/app/src/main/AndroidManifest.xml`.

Critérios de B-5, **mais** a ponte: o evento tem de chegar ao Dart. No log do
`flutter run`, confirme que o mapa entregue traz `image`, `customData` e, no
clique de botão, `actionId`.

`reference` no mapa do Dart vem **vazio** no iOS e preenchido no Android. Essa
divergência é conhecida e documentada — registre o que observou, **não reporte
como defeito novo**.

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

### Z-2. Relatório

Produza exatamente esta estrutura. **Não preencha o que não observou**: escreva
`NÃO EXECUTADO` com o motivo.

```markdown
# Relatório — validação local do payload de rich push

Data: <data> · Branch: integration/rich-mobile-push · Commit: <git rev-parse --short HEAD>
Ambiente: macOS <versão> · Xcode <versão> · simulador <modelo/iOS> · AVD <nome/API> · Flutter <versão> · aparelho <modelo/iOS ou nenhum>

## Matriz de resultados

| Caso | A: iOS sim (entrega) | B: Android | C1: Flutter/Android | C2: Flutter/iOS | D: aparelho (rich) |
| --- | --- | --- | --- | --- | --- |
| 1 título + mensagem | | | | | |
| 2 + imagem | | | | | |
| 3 + botão | | | | | |
| 4 + botão + imagem | | | | | |

PASSA · FALHA · BLOQUEADO · NÃO EXECUTADO · N/A

Lembrete: ausência de imagem/botões na coluna A e em C2 é `PASSA`, não `FALHA`.

## Problemas encontrados

Um bloco por problema, mais severo primeiro.

### P1 — <título de uma linha>
- **Severidade:** Alto / Médio / Baixo
- **Plataforma e caso:** <ex.: aparelho, caso 4>
- **Reprodução:** <comandos exatos>
- **Esperado / Observado:** <critério previsto / o que aconteceu>
- **Evidência:** <linha de log literal, arquivo, screenshot>
- **Determinístico?** <repetiu N de N vezes>

## Bloqueios

O que não deu para testar e por quê, com a saída de erro literal.

## Ruído esperado (não é defeito)

Falha de ingest por credencial vazia no Android · ausência de imagem/botões no
simulador iOS e no Flutter/iOS · `grep -c DITO_PUSH` = 0 na Parte A · divergência
de `reference` entre plataformas.

## Higiene

- `git status --short` limpo após Z-1: sim / não
- Artefatos: /tmp/dito-push/
```

### Z-3. Checagem final

- Toda linha `FALHA` tem evidência literal, não paráfrase?
- Algum `FALHA` é na verdade bloqueio de ambiente (rede, permissão, log
  desligado, limitação do simulador) reportado como defeito de código?
- A sanidade passou nas plataformas em que você concluiu "não chegou"? Se não,
  reclassifique para `BLOQUEADO`.
- Você rodou os casos em sequência, um por vez?
- A coluna D está preenchida ou marcada `NÃO EXECUTADO` com motivo? Sem ela,
  imagem e botões continuam sem validação — diga isso explicitamente na conclusão
  em vez de deixar implícito.
