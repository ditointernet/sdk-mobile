# Research: Documentação Completa dos SDKs

**Feature**: 004-documentation
**Date**: 2025-01-27

## Decisões de Design

### Decisão 1: Estrutura de Documentação

**Decisão**: Usar estrutura hierárquica com README principal na raiz e READMEs específicos por plataforma.

**Rationale**:
- Facilita navegação e descoberta
- Mantém documentação próxima ao código
- Permite atualizações independentes por plataforma
- Segue padrão comum em monorepos

**Alternativas Consideradas**:
- Documentação única centralizada: Rejeitada por ser muito grande e difícil de navegar
- Wiki separado: Rejeitada por dificultar manutenção e versionamento

### Decisão 2: Formato de Documentação

**Decisão**: Usar Markdown com estrutura consistente entre plataformas.

**Rationale**:
- Markdown é universalmente suportado
- Renderiza bem no GitHub/GitLab
- Fácil de editar e manter
- Suporta código, links e formatação

**Alternativas Consideradas**:
- HTML: Rejeitada por ser mais difícil de manter
- AsciiDoc: Rejeitada por menor adoção

### Decisão 3: Nível de Detalhamento

**Decisão**: Documentação detalhada mas simples, adequada para desenvolvedores júnior.

**Rationale**:
- Reduz barreira de entrada
- Aumenta adoção do SDK
- Reduz suporte necessário
- Melhora experiência do desenvolvedor

**Alternativas Consideradas**:
- Documentação mínima: Rejeitada por não atender necessidades de desenvolvedores júnior
- Documentação técnica avançada: Rejeitada por excluir desenvolvedores júnior

### Decisão 4: Organização de Push Notifications

**Decisão**: Criar guia unificado em `docs/push-notifications.md` e referências específicas em cada README.

**Rationale**:
- Evita duplicação de conteúdo comum
- Mantém informações específicas de plataforma nos READMEs
- Facilita manutenção de conteúdo compartilhado

**Alternativas Consideradas**:
- Push Notifications apenas nos READMEs: Rejeitada por criar duplicação excessiva
- Push Notifications apenas no guia unificado: Rejeitada por perder contexto de plataforma

### Decisão 5: Lista de TODOs/FIXMEs

**Decisão**: Coletar TODOs/FIXMEs do código e listar na documentação principal.

**Rationale**:
- Transparência sobre estado do projeto
- Ajuda desenvolvedores a entender limitações
- Facilita contribuições
- Documenta trabalho futuro

**Alternativas Consideradas**:
- Não documentar TODOs: Rejeitada por falta de transparência
- Documentar apenas em issues: Rejeitada por não estar visível na documentação

### Decisão 6: Tipo de Licença

**Decisão**: Usar licença proprietária que permite uso das SDKs mas proíbe modificação e cópia do conteúdo.

**Rationale**:
- Protege propriedade intelectual da Dito
- Permite uso comercial das SDKs
- Impede modificação não autorizada do código
- Impede cópia e redistribuição não autorizada
- Mantém controle sobre qualidade e segurança do código

**Alternativas Consideradas**:
- MIT License: Rejeitada por permitir modificação e redistribuição livre
- Apache 2.0: Rejeitada por permitir modificação e redistribuição
- GPL: Rejeitada por ser copyleft e exigir código aberto
- Licença proprietária padrão: Escolhida por atender requisitos de proteção de IP

**Tipo de Licença Escolhido**: Licença proprietária com termos:
- ✅ Permite uso das SDKs em aplicações comerciais
- ❌ Proíbe modificação do código fonte
- ❌ Proíbe cópia e redistribuição do código
- ✅ Requer manutenção de avisos de copyright
- ✅ Permite uso em aplicações próprias dos clientes

## Melhores Práticas Identificadas

### Documentação de Instalação
- Passo a passo numerado
- Screenshots quando necessário
- Troubleshooting comum
- Links para documentação oficial

### Documentação de Métodos
- Assinatura completa
- Descrição clara do propósito
- Parâmetros documentados (tipo, obrigatório/opcional, descrição)
- Tipo de retorno documentado
- Exemplos de código práticos
- Possíveis erros e tratamento

### Documentação de Push Notifications
- Configuração Firebase detalhada
- Fluxo completo de implementação
- Exemplos de payload
- Troubleshooting específico
- Links para documentação Firebase

## Referências Externas

- [Flutter Plugin Documentation](https://docs.flutter.dev/development/packages-and-plugins/developing-packages)
- [React Native Native Modules](https://reactnative.dev/docs/native-modules-intro)
- [Firebase Cloud Messaging iOS](https://firebase.google.com/docs/cloud-messaging/ios/client)
- [Firebase Cloud Messaging Android](https://firebase.google.com/docs/cloud-messaging/android/client)
- [CocoaPods Documentation](https://guides.cocoapods.org/)
- [Gradle Documentation](https://docs.gradle.org/)

## Tecnologias e Ferramentas

- **Markdown**: Formato de documentação
- **GitHub/GitLab**: Plataforma de hospedagem e renderização
- **Firebase**: Serviço de Push Notifications
- **CocoaPods**: Gerenciador de dependências iOS
- **Gradle**: Build system Android
- **pub.dev**: Repositório Flutter
- **npm**: Repositório React Native

## Padrões de Documentação Identificados

### Estrutura Padrão de README
1. Título e descrição
2. Visão geral
3. Requisitos
4. Instalação
5. Configuração inicial
6. Uso básico
7. Métodos disponíveis
8. Push Notifications
9. Tratamento de erros
10. Troubleshooting
11. Exemplos
12. Links úteis

### Padrão de Documentação de Método
1. Nome do método
2. Assinatura completa
3. Descrição
4. Parâmetros (tabela)
5. Retorno
6. Possíveis erros
7. Exemplo de código
8. Notas adicionais

## Conclusões

A documentação deve seguir estrutura consistente, ser detalhada mas simples, e incluir exemplos práticos. Push Notifications requer atenção especial devido à complexidade de configuração. TODOs/FIXMEs devem ser documentados para transparência.
