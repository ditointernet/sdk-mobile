# Documentation Structure Contract

**Feature**: 004-documentation
**Date**: 2025-01-27

## Estrutura de Documentação

### README Principal (`README.md`)

**Seções Obrigatórias**:
1. Título e descrição
2. Visão geral do monorepo
3. Estrutura do repositório
4. Navegação rápida (links para cada plataforma)
5. Início rápido (exemplos básicos)
6. Desenvolvimento (pré-requisitos, build, release)
7. Funcionalidades (implementado, em desenvolvimento)
8. Troubleshooting geral
9. Lista de TODOs/FIXMEs (link para docs/todos.md)
10. Licença (link para LICENSE, resumo dos termos: permite uso, proíbe modificação e cópia)
11. Suporte

### README iOS (`ios/README.md`)

**Seções Obrigatórias**:
1. Título e descrição
2. Visão geral iOS SDK
3. Requisitos (iOS, Xcode, Swift, Firebase)
4. Instalação (CocoaPods, SPM)
5. Configuração inicial (Info.plist, credenciais)
6. Métodos disponíveis (todos os métodos públicos)
7. Push Notifications iOS
8. Tratamento de erros
9. Troubleshooting
10. Exemplos completos
11. Licença (referência ao LICENSE)
12. Links úteis

### README Android (`android/README.md`)

**Seções Obrigatórias**:
1. Título e descrição
2. Visão geral Android SDK
3. Requisitos (Android API, Kotlin, Gradle, Firebase)
4. Instalação (Gradle)
5. Configuração inicial (AndroidManifest.xml, credenciais)
6. Métodos disponíveis (todos os métodos públicos)
7. Push Notifications Android
8. Tratamento de erros
9. Troubleshooting
10. Exemplos completos
11. Licença (referência ao LICENSE)
12. Links úteis

### README Flutter (`flutter/README.md`)

**Seções Obrigatórias**:
1. Título e descrição
2. Visão geral Flutter Plugin
3. Requisitos (Flutter, Dart)
4. Instalação (pubspec.yaml)
5. Configuração inicial (credenciais, inicialização)
6. Métodos disponíveis (todos os métodos públicos)
7. Push Notifications Flutter
8. Tratamento de erros
9. Troubleshooting
10. Exemplos completos
11. Licença (referência ao LICENSE)
12. Links úteis

### README React Native (`react-native/README.md`)

**Seções Obrigatórias**:
1. Título e descrição
2. Visão geral React Native Plugin
3. Requisitos (React Native, TypeScript, Node.js)
4. Instalação (npm/yarn, linking)
5. Configuração inicial (credenciais, inicialização)
6. Métodos disponíveis (todos os métodos públicos)
7. Push Notifications React Native
8. Tratamento de erros
9. Troubleshooting
10. Exemplos completos
11. Licença (referência ao LICENSE)
12. Links úteis

### Guia Push Notifications (`docs/push-notifications.md`)

**Seções Obrigatórias**:
1. Visão geral Push Notifications
2. Configuração Firebase (geral)
3. Configuração por plataforma
4. Interceptação de notificações
5. Tracking automático
6. Handling de clicks
7. Deeplinks
8. Troubleshooting unificado

### Lista de TODOs (`docs/todos.md`)

**Seções Obrigatórias**:
1. Visão geral
2. TODOs por plataforma
3. FIXMEs encontrados
4. Melhorias planejadas
5. Issues conhecidas

### Arquivo LICENSE (`LICENSE`)

**Seções Obrigatórias**:
1. Cabeçalho com copyright (Dito Internet, ano)
2. Permissões:
   - Uso das SDKs em aplicações comerciais
   - Uso em aplicações próprias dos clientes
3. Restrições:
   - Proibição de modificação do código fonte
   - Proibição de cópia e redistribuição do código
   - Proibição de engenharia reversa
4. Avisos legais:
   - Software fornecido "AS IS"
   - Sem garantias
   - Limitação de responsabilidade
5. Informações de contato para questões de licenciamento

## Formato de Documentação de Método

### Template Padrão

```markdown
### métodoNome

**Descrição**: [Descrição clara do que o método faz]

**Assinatura**:
```[linguagem]
assinatura completa do método
```

**Parâmetros**:
| Nome | Tipo | Obrigatório | Descrição |
|------|------|-------------|-----------|
| param1 | Tipo | Sim/Não | Descrição do parâmetro |

**Retorno**:
- **Tipo**: Descrição do retorno

**Possíveis Erros**:
- `ERROR_CODE`: Descrição do erro e quando ocorre

**Exemplo**:
```[linguagem]
exemplo de código completo e funcional
```

**Notas**:
- Informações adicionais importantes
- Comportamentos especiais
- Limitações conhecidas
```

## Padrões de Formatação

### Código
- Usar blocos de código com syntax highlighting
- Exemplos devem ser completos e testáveis
- Incluir comentários explicativos quando necessário

### Links
- Links internos: usar caminhos relativos
- Links externos: usar URLs completas
- Validar todos os links antes de publicar

### Tabelas
- Usar tabelas Markdown para parâmetros
- Manter formatação consistente
- Incluir todas as colunas necessárias

### Seções
- Usar níveis de cabeçalho consistentes
- Manter hierarquia lógica
- Usar emojis para melhorar visualização (opcional)

## Validação

### Checklist de Qualidade por README

- [ ] Todas as seções obrigatórias presentes
- [ ] Instalação passo a passo completa
- [ ] Configuração inicial documentada
- [ ] Todos os métodos públicos documentados
- [ ] Tipagens corretas
- [ ] Exemplos de código funcionais
- [ ] Tratamento de erros documentado
- [ ] Troubleshooting incluído
- [ ] Licença referenciada (link para LICENSE)
- [ ] Links funcionais
- [ ] Formatação consistente
- [ ] Linguagem clara e simples

### Checklist de Qualidade para LICENSE

- [ ] Arquivo LICENSE existe na raiz do repositório
- [ ] Cabeçalho com copyright correto
- [ ] Permissões claramente definidas (uso permitido)
- [ ] Restrições claramente definidas (modificação e cópia proibidas)
- [ ] Avisos legais incluídos
- [ ] Informações de contato para questões de licenciamento
- [ ] LICENSE em subdiretórios (se existirem) referenciam ou são consistentes com LICENSE raiz
