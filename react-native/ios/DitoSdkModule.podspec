Pod::Spec.new do |s|
  s.name             = 'DitoSdkModule'
  s.version          = '1.0.0'
  s.summary          = 'Plugin React Native para integração com o CRM Dito'
  s.description      = 'Plugin React Native que fornece APIs unificadas para integração com o CRM Dito em iOS e Android'
  s.homepage         = 'https://github.com/ditointernet/dito_sdk_flutter'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'Dito Internet' => 'dev@dito.com.br' }
  s.source           = { :path => '.' }
  s.source_files = '*.{h,m,swift}'
  s.public_header_files = '*.h'
  s.dependency 'React-Core'
  s.dependency 'DitoSDK', :path => '../../ios'
  s.platform = :ios, '16.0'
  s.swift_version = '6.1'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'VALID_ARCHS[sdk=iphonesimulator*]' => 'x86_64' }
  s.static_framework = true
end
