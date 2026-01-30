# Uncomment the next line to define a global platform for your project
platform :ios, '16.0'
use_frameworks!

install! 'cocoapods', :integrate_targets => false

target 'Sample' do
  pod 'FirebaseCore'
  pod 'FirebaseCoreInternal'
  pod 'FirebaseMessaging'
  pod 'FirebaseInstallations'
  pod 'FirebaseAnalytics'

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
    end
  end
end
