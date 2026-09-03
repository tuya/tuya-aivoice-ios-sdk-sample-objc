Pod::Spec.new do |s|
  s.name             = 'ThingPerfusionKit'
  s.version          = '1.0.2'
  s.summary          = 'AI 语音灌流调试能力：本地音频灌流、WER 评估与测试报告导出。'

  s.description      = <<-DESC
  用本地音频文件替换麦克风采集数据，跑通 ASR / 翻译 / TTS 全链路，
  计算 WER（词错误率）并导出 HTML 测试报告。

  - Core：灌流配置提供者、WAV 格式校验、WER 计算、报告生成（无 UI 依赖）
  - UI：开箱可用的灌流调试页
                       DESC

  s.homepage         = 'https://github.com/tuya'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Tuya' => 'https://developer.tuya.com/' }
  s.source           = { :git => '', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'
  s.requires_arc     = true

  # 灌流核心：纯逻辑，可单独集成
  s.subspec 'Core' do |core|
    core.source_files = 'ThingPerfusionKit/Classes/Core/**/*.{h,m}'
    core.frameworks   = 'Foundation'
    # 灌流协议与配置常量
    core.dependency 'ThingAudioRecordInterface'
    # 按协议查找/注册服务
    core.dependency 'ThingModuleManager'
    # 编译期服务注册宏 ThingRegisterAPIAnnotation
    core.dependency 'ThingAnnotationFoundation'
  end

  # 灌流调试页：自带页面基类，不依赖宿主 UI
  s.subspec 'UI' do |ui|
    ui.source_files = 'ThingPerfusionKit/Classes/UI/**/*.{h,m}'
    ui.frameworks   = 'UIKit', 'AVFAudio', 'WebKit'
    ui.dependency 'ThingPerfusionKit/Core'
  end

  s.default_subspecs = 'Core', 'UI'
end
