Pod::Spec.new do |s|
  s.name             = 'ThingAIVoiceDebugKit'
  s.version          = '1.0.2'
  s.summary          = 'AI 语音 Debug 工具组件：灌流调试、WER 评估、测试报告与诊断日志导出。'

  s.description      = <<-DESC
  面向客户的 AI 语音 Debug 工具集：

  - 灌流调试：用本地音频文件替换麦克风采集数据，跑通 ASR / 翻译 / TTS 全链路，
    计算 WER（词错误率）并导出 HTML 测试报告。
  - 诊断日志导出：合并 ThingLogSDK 的多份日志为一份文件并导出，导出成功后清理本地日志。

  - Core：灌流配置提供者、WAV 格式校验、WER 计算、报告生成、日志导出（无自定义 UI 依赖）
  - UI：开箱可用的灌流调试页
                       DESC

  s.homepage         = 'https://github.com/tuya'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Tuya' => 'https://developer.tuya.com/' }
  s.source           = { :git => '', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'
  s.requires_arc     = true

  # Debug 核心能力：灌流逻辑 + 诊断日志导出，可单独集成
  s.subspec 'Core' do |core|
    core.source_files = 'ThingAIVoiceDebugKit/Classes/Core/**/*.{h,m}'
    core.frameworks   = 'Foundation', 'UIKit'
    # 灌流协议与配置常量
    core.dependency 'ThingAudioRecordInterface'
    # 按协议查找/注册服务
    core.dependency 'ThingModuleManager'
    # 编译期服务注册宏 ThingRegisterAPIAnnotation
    core.dependency 'ThingAnnotationFoundation'
    # 诊断日志导出：读取 ThingLogSDK 日志路径
    core.dependency 'ThingSmartLogger'
    # 加密日志无法拼接，多文件压缩成一个 zip 导出
    core.dependency 'SSZipArchive'
  end

  # 灌流调试页：自带页面基类，不依赖宿主 UI
  s.subspec 'UI' do |ui|
    ui.source_files = 'ThingAIVoiceDebugKit/Classes/UI/**/*.{h,m}'
    ui.frameworks   = 'UIKit', 'AVFAudio', 'WebKit'
    ui.dependency 'ThingAIVoiceDebugKit/Core'
  end

  s.default_subspecs = 'Core', 'UI'
end
