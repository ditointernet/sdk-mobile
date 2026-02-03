
Pod::Spec.new do |s|
  s.name             = 'DitoSDK'
  s.version          = '3.0.1'
  s.summary          = 'SDK iOS para rastrear eventos, identificar usuários e sincronizar dados com o Dito CRM'
  s.homepage         = 'https://github.com/ditointernet/sdk-mobile'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'igorduarte' => 'igor.duarte@dito.com.br' }
  s.source           = { :git => 'https://github.com/ditointernet/sdk-mobile.git', :tag => 'v' + s.version.to_s }

  s.swift_version = "5.10"
  s.ios.deployment_target = '16.0'
  s.pod_target_xcconfig = { 'SWIFT_STRICT_CONCURRENCY' => 'minimal' }
  s.source_files = 'ios/DitoSDK/Sources/**/*', 'ios/DitoSDK/Persistence/*.{swift}'
  s.resources = 'ios/DitoSDK/Persistence/*.{xcdatamodeld}'
  s.exclude_files = "ios/DitoSDK/Sources/Info.plist"
end
