
Pod::Spec.new do |s|
  s.name             = 'DitoSDK'
  s.version          = '3.3.0'
  s.summary          = 'SDK iOS para rastrear eventos, identificar usuários e sincronizar dados com o Dito CRM'
  s.homepage         = 'https://github.com/ditointernet/sdk-mobile'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'igorduarte' => 'igor.duarte@dito.com.br' }
  s.source           = { :git => 'https://github.com/ditointernet/sdk-mobile.git', :tag => 'ios-v' + s.version.to_s, :subdirectory => 'ios' }

  s.swift_version = "5.10"
  s.ios.deployment_target = '16.0'
  s.pod_target_xcconfig = { 'SWIFT_STRICT_CONCURRENCY' => 'minimal' }
  s.dependency 'Connect-Swift', '~> 0.14.0'
  s.source_files = 'DitoSDK/Sources/**/*', 'DitoSDK/Persistence/*.{swift}'
  s.resources = 'DitoSDK/Persistence/*.{xcdatamodeld}'
  s.exclude_files = 'DitoSDK/Sources/Info.plist'
end
