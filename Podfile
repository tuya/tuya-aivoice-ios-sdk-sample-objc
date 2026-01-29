# source 'https://github.com/tuya/tuya-pod-specs.git'
source 'https://github.com/CocoaPods/Specs.git'
source 'https://github.com/tuya/AIBudsSpec.git'

use_modular_headers!
platform :ios, '12.0'
inhibit_all_warnings!
use_frameworks! :linkage => :static

target 'tuya-aivoice-ios-sdk-sample-objc' do

  pod 'ThingSmartCryption', :path => './'
  # AI耳机
  pod 'ThingSmartAIBudsBizBundle', '~> 6.11.0'
  
  # Family
  pod 'ThingSmartFamilyBizBundle', '~> 6.11.0'
  
  # Device pairing，
  pod 'ThingSmartActivatorBizBundle', '~> 6.11.0'

  # Device panel (Miniapp)
  pod "ThingSmartMiniAppBizBundle", '~> 6.11.0'
  pod 'ThingSmartBaseKitBizBundle', '~> 6.11.0'
  pod 'ThingSmartBizKitBizBundle', '~> 6.11.0'
  
  # Device details
  pod 'ThingSmartDeviceDetailBizBundle', '~> 6.11.0'
  
  # Device OTA updates
  pod 'ThingSmartOTABizBundle', '~> 6.11.0'
  
  # SDK [Required] Basic
  pod 'ThingSmartHomeKit', '~> 6.11.0'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|

      config.build_settings['CLANG_WARN_DOCUMENTATION_COMMENTS'] = 'NO'
      config.build_settings["IPHONEOS_DEPLOYMENT_TARGET"] = "12.0"
      config.build_settings["EXCLUDED_ARCHS[sdk=iphonesimulator*]"] = "arm64"
      
    end
  end
end

