
Pod::Spec.new do |s|
  s.name             = 'DitoSDK'
  s.version          = '2.0.0'
  s.summary          = 'Dito CRM SDK for iOS'
  s.homepage         = 'https://github.com/ditointernet/sdk-mobile'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'igorduarte' => 'igor.duarte@dito.com.br' }
  s.source           = { :git => 'https://github.com/ditointernet/sdk-mobile.git', :tag => 'v' + s.version.to_s }

  s.swift_version = "6.1"
  s.ios.deployment_target = '16.0'
  s.source_files = 'DitoSDK/Sources/**/*', 'DitoSDK/Persistence/*.{swift}'
  s.resources = 'DitoSDK/Persistence/*.{xcdatamodeld}'
  s.exclude_files = "DitoSDK/Sources/Info.plist"
end
