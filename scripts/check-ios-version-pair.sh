#!/bin/bash
#
# O plugin Flutter pede uma versão do DitoSDK nativo. Se essa versão não existir, nenhum
# `pod install` no app integrador resolve — e o erro aparece só na máquina de quem tenta
# instalar, não em CI, porque nada no repositório compara os dois números.
#
# Foi o que aconteceu: `flutter/ios/dito_sdk.podspec` pedia `DitoSDK (~> 3.6.0)` enquanto o
# `DitoSDK.podspec` estava em 3.5.0 e o trunk do CocoaPods, em 3.2.1. Este script existe
# para que isso falhe aqui, em segundos, em vez de na mão de quem integra.

set -euo pipefail

cd "$(dirname "$0")/.."

read_field() {
  sed -nE "s/.*$2[[:space:]]*=[[:space:]]*'([^']+)'.*/\1/p" "$1" | head -n 1
}

ios_version="$(read_field DitoSDK.podspec 's\.version')"
nse_version="$(read_field DitoSDKNotificationService.podspec 's\.version')"
constraint="$(sed -nE "s/.*s\.dependency 'DitoSDK', '~> ([^']+)'.*/\1/p" flutter/ios/dito_sdk.podspec | head -n 1)"

fail() {
  echo "❌ $1" >&2
  exit 1
}

[ -n "$ios_version" ] || fail "não achei s.version em DitoSDK.podspec"
[ -n "$nse_version" ] || fail "não achei s.version em DitoSDKNotificationService.podspec"
[ -n "$constraint" ] || fail "não achei a dependência DitoSDK em flutter/ios/dito_sdk.podspec"

# DitoSDK depende de DitoSDKNotificationService numa versão exata; se os dois divergirem, o
# pod publicado aponta para uma versão que nunca existiu.
if [ "$ios_version" != "$nse_version" ]; then
  fail "DitoSDK está em $ios_version e DitoSDKNotificationService em $nse_version; os dois têm de andar juntos"
fi

# `~> X.Y` aceita >= X.Y e < X+1.0. `~> X.Y.Z` aceita >= X.Y.Z e < X.Y+1.0.
IFS='.' read -r c_major c_minor c_patch <<< "$constraint"
IFS='.' read -r i_major i_minor i_patch <<< "$ios_version"

satisfied=true
[ "$i_major" = "$c_major" ] || satisfied=false
if [ -n "${c_patch:-}" ]; then
  [ "$i_minor" = "$c_minor" ] || satisfied=false
  [ "${i_patch:-0}" -ge "$c_patch" ] || satisfied=false
else
  [ "${i_minor:-0}" -ge "${c_minor:-0}" ] || satisfied=false
fi

if [ "$satisfied" != true ]; then
  fail "flutter/ios/dito_sdk.podspec pede DitoSDK '~> $constraint', que a versão $ios_version do repositório não satisfaz"
fi

echo "✅ DitoSDK $ios_version satisfaz o '~> $constraint' pedido pelo plugin Flutter"
