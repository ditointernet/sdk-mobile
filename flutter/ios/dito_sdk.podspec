#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint dito_sdk.podspec` to validate before publishing.
#
# SDK iOS local: configurar no Podfile do app (CocoaPods não permite :path no podspec).
# Ver flutter/sample_application/ios/Podfile.
#
Pod::Spec.new do |s|
  s.name             = 'dito_sdk'
  s.version          = '3.3.0'
  s.summary          = 'Dito iOS SDK Plugin for Flutter'
  s.description      = <<-DESC
Dito iOS SDK Plugin for Flutter
                       DESC
  s.homepage         = 'https://github.com/ditointernet/sdk-mobile'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Dito Internet' => 'igor.duarte@dito.com.br' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  # O push rico (E4) entra na 3.5.0, que é a versão do DitoSDK.podspec na raiz. A restrição
  # fica em `~> 3.5` — major.minor, não major.minor.patch — para que um patch do SDK nativo
  # não exija uma release do plugin para ser instalável. Quem mexer aqui: a versão pedida
  # tem que existir no repositório, senão nem o modo local resolve. Isso é verificado em CI
  # por scripts/check-version-pins.sh, e `bump-version.sh` move esta linha junto com o iOS.
  #
  # A NSE do app integrador linka o pod separado `DitoSDKNotificationService`, no target da
  # extension. Ele não entra aqui: uma app extension não pode linkar o Flutter.
  s.dependency 'DitoSDK', '~> 3.5'
  s.dependency 'Firebase/Messaging'
  s.platform = :ios, '16.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'dito_sdk_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
