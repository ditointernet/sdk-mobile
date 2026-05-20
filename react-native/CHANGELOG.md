# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2026-05-06

### Added

- Interface `DitoNotificationOptions` para customização de notificações push, com os campos:
  - `smallIconResId?: number` — resource ID do ícone pequeno (Android)
  - `largeIconResId?: number` — resource ID do ícone grande (Android)
  - `soundResourceName?: string` — nome do recurso de som personalizado (Android/iOS)
  - `accentColor?: number` — cor de destaque ARGB da notificação (Android)
  - `badgeEnabled?: boolean` — habilita/desabilita badge no ícone do app (Android/iOS)
- Método `setNotificationOptions(options: DitoNotificationOptions): Promise<void>` para configurar as opções de exibição de notificações push antes de recebê-las.
- Suporte completo em **Android** e **iOS** para personalização via camada nativa.

### Breaking Changes

- Versão major incrementada (D-05): API limpa sem métodos deprecated em paralelo.
- O tipo `DitoNotificationOptions` é agora exportado diretamente do pacote; projetos que importavam tipos internos devem migrar para o export público.

## [1.1.0] - Initial release

- Métodos `initialize`, `identify`, `track`, `registerDeviceToken`, `unregisterDeviceToken`.
