source 'https://github.com/CocoaPods/Specs.git'
# tuya公有源
source 'https://github.com/tuya/tuya-pod-specs.git'

use_modular_headers!
platform :ios, '12.0'
inhibit_all_warnings!
use_frameworks! :linkage => :static

target 'tuya-aivoice-ios-sdk-sample-objc' do
  
  # 安全文件
  pod 'ThingSmartCryption', :path => './'
  
  # AI 音频UI业务包
  pod 'ThingSmartAIVoiceBizBundle', '~> 6.11.0'


  # 小程序UI业务包
  pod "ThingSmartMiniAppBizBundle", '~> 6.11.0'
  pod 'ThingSmartBaseKitBizBundle', '~> 6.11.0'
  pod 'ThingSmartBizKitBizBundle', '~> 6.11.0'
  
  # 设备配网UI业务包-无配网需求可以不加
  pod 'ThingSmartActivatorBizBundle', '~> 6.11.0'
  
  # 设备面板UI业务包-无设备控制的需求可以不加
  pod 'ThingSmartPanelBizBundle','~> 6.11.0'
  
  # 设备详情UI业务包
  pod 'ThingSmartDeviceDetailBizBundle', '~> 6.11.0'
  # 家庭UI业务包
  pod 'ThingSmartFamilyBizBundle', '~> 6.11.0'
   
  # Optional
  # 设备OTA升级UI业务包
  # pod 'ThingSmartOTABizBundle', '~> 6.11.0'

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

