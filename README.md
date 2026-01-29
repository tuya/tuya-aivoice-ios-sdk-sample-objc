
## 简介
AI 音频UI业务包是针对普通蓝牙耳机、眼镜、音箱等音频类产品直接升级为AI产品，即可使用AI记录和翻译功能，专业录音算法配合先进的语言模型，覆盖全球100+种语言的实时精准转和实时翻译。

在接入该业务包之前请先完成[准备工作](https://developer.tuya.com/cn/docs/app-development/preparation?id=Ka8j28bikfqkf) 和 [框架接入](https://developer.tuya.com/cn/docs/app-development/framework?id=Ka8j2895qdvtj)。

AI音频业务包的Demo地址: [tuya-aivoice-ios-sdk-sample-objc](https://github.com/tuya/tuya-aivoice-ios-sdk-sample-objc)。

## 功能介绍
### AI 笔记
录音: 专业录音算法配合先进的语言模型，覆盖全球100+种语言的实时精准转写和实时翻译
![AI笔记-录音.png](https://images.tuyacn.com/content-platform/hestia/1769482216dcdab899f05.png)

转写: 自动识别语种并精准转写，支持区分说话人，支持翻译
![AI笔记-转写.png](https://images.tuyacn.com/content-platform/hestia/17694815203bc9e37ca17.png)

总结: 会议纪要、访谈精华、课堂笔记、待办清单一键生成，从杂乱到有序，支持多种场景

![AI笔记-总结.png](https://images.tuyacn.com/content-platform/hestia/17694820335b7c6802952.png)

分享导出: 内容随心存，分享更便携
![AI笔记-分享.png](https://images.tuyacn.com/content-platform/hestia/1769482344c746bf8b24b.png)

### AI 翻译
同声传译: 100+ 语言实时同传
![AI翻译-同声传译.png](https://images.tuyacn.com/content-platform/hestia/176948510540e496a8eed.png)

对话翻译: 面对面沟通，跨语言无障碍
![对话翻译.png](https://images.tuyacn.com/content-platform/hestia/1769485295241d0fa7140.png)


## 接入组件
在工程的 Podfile 文件中添加 AI 音频 业务包组件，并执行 pod update 命令：

```
source 'https://github.com/tuya/tuya-pod-specs.git'
source 'https://cdn.cocoapods.org/'
platform :ios, '12.0'

target 'your_target_name' do
    # 依赖 AI 音频业务包
    pod 'ThingSmartAIVoiceBizbundle'
    # HomeSDK版本
    pod 'ThingSmartHomeKit'
    
end
```

## 注意事项

### 蓝牙和麦克风权限
使用语音输入和蓝牙功能，需要在 info.plist 中设置 NSMicrophoneUsageDescription和NSBluetoothAlwaysUsageDescription。
```xml
<key>NSMicrophoneUsageDescription</key>
<string>开启麦克风权限</string>

<key>NSBluetoothAlwaysUsageDescription</key>
<string>用于连接蓝牙设备并进行音频/数据通信</string>
```
### 后台权限
为保障后台仍够正常使用音频输入功能，需要开启后台音频权限和后台蓝牙权限。
Target → Signing & Capabilities → + Capability → Background Modes 勾选：
> Audio, AirPlay, and Picture in Picture
> Uses Bluetooth LE accessories

等价于 Info.plist 中：
```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
    <string>bluetooth-central</string>
</array>
```

## 使用

### 入门版解决方案
入门版解决方案可以将现有传统耳机直接升级为具备AI功能的耳机产品。
在设置中连接蓝牙后，通过扫码激活或纯软件直接激活的方式，激活后即刻获得实时录音、实时转写、同声传译、对话翻译、AI 总结摘要等全量AI能力。
![软件激活.png](https://images.tuyacn.com/content-platform/hestia/1769494959a068586aaa2.png)


### 小程序

使用 Tuya Mini App SDK（iOS）请参考：[Mini App SDK - iOS](https://developer.tuya.com/cn/docs/app-development/mini-app-sdk-ios?id=Kcwzk061gny2i)。

如果只需要按 `AppID` 打开小程序，可直接调用：

```objective-c
[[ThingMiniAppClient coreClient] openMiniAppByAppId:@"xxx"];

AI 笔记（AppID: tyylldwlb8411tg8u2）

AI 翻译（AppID: ty0u9m1s5ea1k71m2h）
```

如果需要跳转到小程序内的指定页面（自定义路由），可使用如下路由：

```
AI 笔记
主页：thingSmart://miniApp?url=godzilla%3A%2F%2Ftyylldwlb8411tg8u2%2Fpages%2Fhome%2Findex
录音：thingSmart://miniApp?url=godzilla%3A%2F%2Ftyylldwlb8411tg8u2%2Fpages%2Fhome%2Findex%3FmodeKey%3DliveRecording
同声传译：thingSmart://miniApp?url=godzilla%3A%2F%2Ftyylldwlb8411tg8u2%2Fpages%2Fhome%2Findex%3FmodeKey%3DsimultaneousInterpretation
实时转写：thingSmart://miniApp?url=godzilla%3A%2F%2Ftyylldwlb8411tg8u2%2Fpages%2Fhome%2Findex%3FmodeKey%3DrealTimeRecording

AI 翻译
主页：thingSmart://miniApp?url=godzilla%3A%2F%2Fty0u9m1s5ea1k71m2h%2Fpages%2Fhome%2Findex
同声传译：thingSmart://miniApp?url=godzilla%3A%2F%2Fty0u9m1s5ea1k71m2h%2Fpages%2Fsimultaneous%2Findex
对话翻译：thingSmart://miniApp?url=godzilla%3A%2F%2Fty0u9m1s5ea1k71m2h%2Fpages%2FFaceToFace%2Findex
```


