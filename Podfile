source 'https://github.com/CocoaPods/Specs.git'
# tuya公有源
source 'https://github.com/tuya/tuya-pod-specs.git'

use_modular_headers!
platform :ios, '13.0'
inhibit_all_warnings!
use_frameworks! :linkage => :static

target 'tuya-aivoice-ios-sdk-sample-objc' do
  
  # 安全文件
  pod 'ThingSmartCryption', :path => './ios_core_sdk'
  
  # AI 音频UI业务包
  pod 'ThingSmartAIVoiceBizBundle', '~> 7.8.0'


  # 小程序UI业务包
  pod "ThingSmartMiniAppBizBundle", '~> 7.8.0'
  pod 'ThingSmartBaseKitBizBundle', '~> 7.8.0'
  pod 'ThingSmartBizKitBizBundle', '~> 7.8.0'
  
  # 设备配网UI业务包-无配网需求可以不加
  pod 'ThingSmartActivatorBizBundle', '~> 7.8.0'

  # 自定义 BLE 单点设备配网（显式依赖，避免依赖 UI 业务包的传递依赖）
  pod 'ThingSmartBusinessExtensionKit', '~> 7.8.0'
  pod 'ThingSmartBusinessExtensionKitBLEExtra', '~> 7.8.0'
  
  # 设备面板UI业务包-无设备控制的需求可以不加
  pod 'ThingSmartPanelBizBundle','~> 7.8.0'
  
  # 设备详情UI业务包
  pod 'ThingSmartDeviceDetailBizBundle', '~> 7.8.0'
  # Optional
  # 设备OTA升级UI业务包
  # pod 'ThingSmartOTABizBundle', '~> 7.8.0'

  pod 'ThingSmartHomeKit', '~> 7.8.0'
  pod 'ThingSmartFamilyBizBundle', '~> 7.8.0'
  
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|

      config.build_settings['CLANG_WARN_DOCUMENTATION_COMMENTS'] = 'NO'
      config.build_settings["IPHONEOS_DEPLOYMENT_TARGET"] = "13.0"
      config.build_settings['SWIFT_VERSION'] = '5.0'
      config.build_settings["EXCLUDED_ARCHS[sdk=iphonesimulator*]"] = "arm64"
      
    end
  end
end
