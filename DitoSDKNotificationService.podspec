
# Extension-safe half of the Dito iOS SDK.
#
# Published as its own pod, not as a subspec of DitoSDK, for two reasons:
#
#   1. CocoaPods compiles every subspec of a pod into a single module, so a
#      subspec could not be imported as `DitoSDKNotificationService` — the module
#      name would differ from the Swift Package Manager one and the SDK's own
#      `import DitoSDKNotificationService` would not resolve.
#   2. `pod_target_xcconfig` is merged across all activated subspecs of a target,
#      so APPLICATION_EXTENSION_API_ONLY set on a subspec would also apply to the
#      full SDK in the host app and break it on `UIApplication`.
#
# Keep `s.version` in lockstep with DitoSDK.podspec.
Pod::Spec.new do |s|
  s.name             = 'DitoSDKNotificationService'
  s.version          = '3.7.0'
  s.summary          = 'Extensão de notificação do SDK iOS da Dito: imagem, botões e custom data em push'
  s.homepage         = 'https://github.com/ditointernet/sdk-mobile'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'igorduarte' => 'igor.duarte@dito.com.br' }
  s.source           = { :git => 'https://github.com/ditointernet/sdk-mobile.git', :tag => 'ios-v' + s.version.to_s }

  s.swift_version = "5.10"
  s.ios.deployment_target = '16.0'
  s.frameworks = 'Foundation', 'UserNotifications', 'UniformTypeIdentifiers'

  # Enforced, not cosmetic: the pod fails to build if this code ever reaches for
  # API that is unavailable in an app extension.
  s.pod_target_xcconfig = {
    'APPLICATION_EXTENSION_API_ONLY' => 'YES',
    'SWIFT_STRICT_CONCURRENCY' => 'minimal',
  }

  s.source_files = 'ios/DitoNotificationService/**/*.swift'
end
