# Research: Refatorar Aplicações de Exemplo

**Feature**: 002-refactor-example-apps
**Date**: 2025-01-27

## Decisões Técnicas

### 1. Carregamento de Arquivos .env por Plataforma

#### iOS

**Decision**: Usar `SwiftDotenv` ou implementação simples de leitura de arquivo `.env`

**Rationale**:
- iOS não tem suporte nativo para arquivos `.env`
- `SwiftDotenv` é uma biblioteca leve e bem mantida
- Alternativa: implementar parser simples se não quisermos dependência externa

**Alternatives Considered**:
- `SwiftDotenv`: Biblioteca popular, fácil de usar
- Parser customizado: Mais controle, mas mais trabalho
- Info.plist: Não adequado para valores de desenvolvimento que mudam frequentemente
- Build settings: Não permite mudanças em runtime

**Implementation**:
```swift
// Usando SwiftDotenv
import SwiftDotenv

// Carregar .env.development.local
if let envPath = Bundle.main.path(forResource: ".env.development.local", ofType: nil) {
    try? Dotenv.load(path: envPath)
}
let apiKey = Dotenv.get("API_KEY") ?? ""
```

#### Android

**Decision**: Usar `gradle.properties` ou `BuildConfig` para valores de build, ou implementar leitura de arquivo `.env` em runtime

**Rationale**:
- Android tem suporte limitado para `.env` em runtime
- `gradle.properties` é padrão para configurações de build
- Para runtime, podemos ler arquivo `.env` do assets ou implementar parser simples

**Alternatives Considered**:
- `gradle.properties`: Padrão Android, mas valores são em build time
- `BuildConfig`: Similar ao gradle.properties
- Leitura de arquivo de assets: Permite runtime, mas arquivo precisa estar em assets/
- `react-native-config` (se usando React Native): Já resolve para RN

**Implementation**:
```kotlin
// Opção 1: Ler de assets (runtime)
fun loadEnvFromAssets(context: Context): Map<String, String> {
    val envMap = mutableMapOf<String, String>()
    try {
        context.assets.open(".env.development.local").bufferedReader().useLines { lines ->
            lines.forEach { line ->
                if (line.contains("=") && !line.startsWith("#")) {
                    val (key, value) = line.split("=", limit = 2)
                    envMap[key.trim()] = value.trim().removeSurrounding("\"")
                }
            }
        }
    } catch (e: Exception) {
        // Fallback para valores padrão
    }
    return envMap
}

// Opção 2: gradle.properties (build time)
// No build.gradle:
android {
    defaultConfig {
        buildConfigField "String", "API_KEY", "\"${project.findProperty("API_KEY") ?: ""}\""
    }
}
```

#### Flutter

**Decision**: Usar `flutter_dotenv` package

**Rationale**:
- `flutter_dotenv` é o pacote padrão da comunidade Flutter
- Suporta arquivos `.env` facilmente
- Integração simples com `pubspec.yaml`

**Alternatives Considered**:
- `flutter_dotenv`: Padrão da comunidade, bem mantido
- Parser customizado: Desnecessário quando há solução pronta
- Variáveis de ambiente do sistema: Não adequado para desenvolvimento local

**Implementation**:
```dart
// pubspec.yaml
dependencies:
  flutter_dotenv: ^5.1.0

flutter:
  assets:
    - .env.development.local

// main.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  await dotenv.load(fileName: ".env.development.local");
  runApp(MyApp());
}

// Uso
final apiKey = dotenv.env['API_KEY'] ?? '';
```

#### React Native

**Decision**: Usar `react-native-config` ou `react-native-dotenv`

**Rationale**:
- `react-native-config` é amplamente usado e bem mantido
- Suporta tanto iOS quanto Android
- Integração simples

**Alternatives Considered**:
- `react-native-config`: Padrão da comunidade, funciona em iOS e Android
- `react-native-dotenv`: Alternativa mais leve, mas menos popular
- Variáveis de ambiente nativas: Complexo de configurar

**Implementation**:
```typescript
// package.json
{
  "dependencies": {
    "react-native-config": "^1.5.1"
  }
}

// .env.development.local
API_KEY=your-api-key
API_SECRET=your-api-secret

// App.tsx
import Config from 'react-native-config';

const apiKey = Config.API_KEY || '';
```

### 2. Estrutura de Interface Consistente

**Decision**: Usar componentes nativos de cada plataforma, mas manter estrutura e comportamento idênticos

**Rationale**:
- Cada plataforma tem seus próprios componentes UI nativos
- Tentar usar componentes idênticos visualmente seria contra as guidelines de cada plataforma
- Foco em comportamento e estrutura, não em aparência visual idêntica

**Alternatives Considered**:
- Componentes visuais idênticos: Contra as guidelines de cada plataforma
- Componentes nativos com estrutura similar: Melhor abordagem
- Framework cross-platform único: Não demonstra uso real do plugin em cada plataforma

**Implementation Strategy**:
- Mesma ordem de campos em todas as plataformas
- Mesma validação de campos obrigatórios
- Mesmas ações disponíveis (identify, track, registerDeviceToken, unregisterDeviceToken)
- Mensagens de erro consistentes

### 3. Validação de Campos

**Decision**: Validação client-side antes de chamar SDK, com mensagens de erro consistentes

**Rationale**:
- Melhor UX: feedback imediato ao usuário
- Reduz chamadas desnecessárias ao SDK
- Mensagens de erro consistentes facilitam debugging

**Validation Rules**:
- API Key: Não vazio
- API Secret: Não vazio
- User ID: Não vazio
- User Email: Formato de email válido (se fornecido)
- User Phone: Formato de telefone válido (se fornecido, opcional)
- Outros campos: Opcionais, sem validação específica

### 4. Método unregisterDeviceToken

**Decision**: SDKs nativos suportam `unregisterDevice` - implementar nos plugins Flutter e React Native se ainda não estiver disponível

**Rationale**:
- iOS SDK: `Dito.unregisterDevice(token: String)` - ✅ Existe
- Android SDK: `Dito.unregisterDevice(token: String?)` - ✅ Existe
- Flutter Plugin: Verificar se já implementado
- React Native Plugin: Verificar se já implementado

**Status**: VERIFIED - SDKs nativos suportam. Verificar se plugins já têm implementação, caso contrário adicionar.

### 5. Estrutura de Arquivos .env

**Decision**: Usar formato padrão `.env` com `KEY=VALUE`

**Rationale**:
- Formato padrão e amplamente suportado
- Fácil de editar manualmente
- Suportado por todas as bibliotecas escolhidas

**Template**:
```env
# Dito SDK Configuration
API_KEY=your-api-key-here
API_SECRET=your-api-secret-here

# User Defaults
USER_ID=user123
USER_NAME=John Doe
USER_EMAIL=john@example.com
USER_PHONE=+5511999999999
USER_ADDRESS=123 Main St
USER_CITY=São Paulo
USER_STATE=SP
USER_ZIP=01234-567
USER_COUNTRY=Brazil
```

## Questões Resolvidas

1. **unregisterDeviceToken**: ✅ Confirmado - existe nos SDKs nativos iOS e Android
   - iOS: `Dito.unregisterDevice(token: String)`
   - Android: `Dito.unregisterDevice(token: String?)`
   - Próximo passo: Verificar se plugins Flutter e React Native já têm implementação

2. **Localização do arquivo .env**: ✅ Decidido - cada exemplo terá seu próprio `.env.development.local` na raiz
   - iOS: `ios/SampleApplication/.env.development.local`
   - Android: `android/example-app/.env.development.local`
   - Flutter: `flutter/example/.env.development.local`
   - React Native: `react-native/example/.env.development.local`

3. **Fallback values**: ✅ Decidido - valores padrão vazios quando .env não existe ou campo não está presente

## Próximos Passos

1. Verificar se plugins Flutter e React Native têm `unregisterDeviceToken` implementado
2. Se não tiverem, implementar nos plugins
3. Criar templates `.env.development.local.example` para cada plataforma
4. Implementar leitura de .env em cada plataforma
5. Criar interfaces consistentes em cada plataforma
