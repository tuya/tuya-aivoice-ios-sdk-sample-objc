---
name: tuya-aivoice-ios-integration
description: >-
  涂鸦 AIVoice iOS SDK 接入指南。当用户需要在 iOS 项目中集成涂鸦 AI 音频业务包
  （AI 笔记、AI 翻译小程序面板，或用 Native SDK 自绘录音/转写/翻译界面，
  以及蓝牙音频设备配网、设备面板、灌流调试与 WER 评估）时使用此 Skill。
---

AI 音频 UI 业务包可将普通蓝牙耳机、眼镜、音箱等音频类产品升级为 AI 产品，支持 AI 录音、实时转写和实时翻译，覆盖全球 100+ 种语言。

Demo 工程：[tuya-aivoice-ios-sdk-sample-objc](https://github.com/tuya/tuya-aivoice-ios-sdk-sample-objc)

**当前对齐版本：涂鸦业务包 7.8.x，iOS 13.0+，Xcode 15+。**

## 先选接入形态

两种形态可以单选，也可以组合。基础集成（Step 1~7）两者都要做。

| 形态 | 说明 | 额外工作 | 适用 |
| --- | --- | --- | --- |
| **UI 业务包（小程序面板）** | 直接复用涂鸦的 AI 笔记 / AI 翻译小程序，UI 与业务逻辑由涂鸦维护 | 只需路由跳转（见「AI 功能路由」） | 想最快上线、不需要自定义界面 |
| **Native SDK（自绘 UI）** | 用 `ThingAudioRecordInterface` 原生接口自己实现录音、转写、总结、翻译界面 | Step 8 | 需要完全自定义 UI 与交互 |

## 快速决策树

```
用户咨询 AIVoice iOS 接入
        |
        +-- 还没开始接入？
        |       +-- 用涂鸦现成面板 --> Step 1~7，再看「AI 功能路由」
        |       +-- 要自绘录音界面 --> Step 1~7，再看 Step 8
        |
        +-- 已有涂鸦 SDK，想加 AI 能力？
        |       +-- AI 笔记（录音/转写/传译）--> 功能路由：AI 笔记
        |       +-- AI 翻译（传译/对话翻译）--> 功能路由：AI 翻译
        |       +-- 自己做录音界面 --> Step 8: Native SDK 录音链路
        |
        +-- 要做 ASR 效果回归 / 算 WER？--> Step 9: 灌流调试
        |
        +-- 某个环节有问题？
                +-- CocoaPods / 依赖 --> Step 1
                +-- 配置文件 --> Step 2
                +-- 权限 / 后台录音 --> Step 3
                +-- SDK 初始化 --> Step 4
                +-- 登录注册 --> Step 5
                +-- 家庭管理 / 设备列表为空 --> Step 6
                +-- 设备配网 --> Step 7
                +-- 录音没回调 / ASR 没结果 --> Step 8 + 常见问题
                +-- 设备面板 / 小程序 --> 功能路由：设备面板
```

## 场景关键词匹配

| 关键词 | 路由目标 |
| --- | --- |
| CocoaPods、Podfile、依赖、pod install、版本 | Step 1: 依赖配置 |
| AppKey、SecretKey、appId、thing_custom_config、配置 | Step 2: 配置文件 |
| 权限、麦克风、蓝牙权限、后台录音、Info.plist | Step 3: 权限声明 |
| 初始化、startWithAppKey、AppDelegate、ThingSmartSDK | Step 4: SDK 初始化 |
| 登录、注册、验证码、重置密码、国家码、ThingSmartUser | Step 5: 用户登录 |
| 家庭、homeId、ThingSmartHome、设备列表为空 | Step 6: 家庭管理 |
| 配网、蓝牙、BLE、耳机、眼镜、音箱、扫码配网 | Step 7: 设备配网 |
| Native SDK、自绘 UI、自定义录音界面、ThingAudioRecordInterface、ASR 回调、振幅、录音列表、录音详情、转写、总结 | Step 8: Native SDK 录音链路 |
| 灌流、Perfusion、WER、词错误率、测试报告、ASR 回归、效果评测 | Step 9: 灌流调试 |
| AI笔记、录音、实时转写、同声传译、liveRecording | 功能路由：AI 笔记 |
| AI翻译、对话翻译、FaceToFace、翻译 | 功能路由：AI 翻译 |
| 面板、小程序、MiniApp、设备详情 | 功能路由：设备面板 |

---

## 基础集成步骤

### Step 1: CocoaPods 依赖配置

在 Podfile 中添加涂鸦 pod 源和业务包依赖：

```ruby
source 'https://github.com/CocoaPods/Specs.git'
# 涂鸦公有源
source 'https://github.com/tuya/tuya-pod-specs.git'

use_modular_headers!
platform :ios, '13.0'
inhibit_all_warnings!
use_frameworks! :linkage => :static

target 'YourApp' do

  # [必选] 安全组件（本地引用，不提交到 Git）
  pod 'ThingSmartCryption', :path => './ios_core_sdk'

  # [必选] AI 音频 UI 业务包（同时带来 ThingAudioRecordInterface 原生接口）
  pod 'ThingSmartAIVoiceBizBundle', '~> 7.8.0'

  # [必选] 小程序 UI 业务包
  pod 'ThingSmartMiniAppBizBundle', '~> 7.8.0'
  pod 'ThingSmartBaseKitBizBundle', '~> 7.8.0'
  pod 'ThingSmartBizKitBizBundle', '~> 7.8.0'

  # [必选] 家庭、设备、用户基础能力
  pod 'ThingSmartHomeKit', '~> 7.8.0'

  # [可选] 家庭管理 UI 业务包
  pod 'ThingSmartFamilyBizBundle', '~> 7.8.0'

  # [可选] 设备配网 UI 业务包 — 无配网需求可不加
  pod 'ThingSmartActivatorBizBundle', '~> 7.8.0'

  # [可选] BLE 单点设备自定义配网（显式声明，避免依赖 UI 业务包的传递依赖）
  pod 'ThingSmartBusinessExtensionKit', '~> 7.8.0'
  pod 'ThingSmartBusinessExtensionKitBLEExtra', '~> 7.8.0'

  # [可选] 设备面板 UI 业务包 — 无设备控制需求可不加
  pod 'ThingSmartPanelBizBundle', '~> 7.8.0'

  # [可选] 设备详情 UI 业务包
  pod 'ThingSmartDeviceDetailBizBundle', '~> 7.8.0'

  # [可选] 设备 OTA 升级 UI 业务包
  # pod 'ThingSmartOTABizBundle', '~> 7.8.0'

  # [可选] 灌流调试组件（本地路径，见 Step 9）
  # pod 'ThingPerfusionKit', :path => '../Modules/ThingPerfusionKit'

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
```

执行 `pod install` 后用 `.xcworkspace` 打开工程。

**版本一致性**：所有涂鸦业务包保持同一大版本（这里是 7.8.x）。混用不同大版本会出现符号冲突或运行时找不到服务。

**关于 `EXCLUDED_ARCHS`**：该设置让模拟器只编 x86_64。Apple Silicon 上运行模拟器需要 Rosetta；若遇到模拟器架构问题，可去掉这一行改用 arm64 模拟器。真机不受影响。

### Step 2: 配置文件

需要准备两个配置文件和一个安全组件，均从 [涂鸦 IoT 开发平台](https://platform.tuya.com/) 获取。

#### AppKey.h

```objc
#define APP_KEY        @"<你的 AppKey>"
#define APP_SECRET_KEY @"<你的 SecretKey>"
```

真实凭据只用于本地开发环境。不要将填写后的 `AppKey.h`、appId、AppKey、SecretKey 或渠道标识提交到 Git。

#### thing_custom_config.json

将此文件添加到 Xcode 工程的 Bundle Resources 中：

```json
{
    "config": {
        "appId": "<你的 AppId>",
        "thingAppKey": "<你的 AppKey>",
        "appScheme": "<你的渠道标识符>",
        "needBle": true,
        "is_support_home_manager": true,
        "need_backgroud_audio": true,
        "needQRCode": true,
        "device_detail_mini_program": true,
        "hotspotPrefixs": ["SmartLife"],
        "support_ble_gpt": true
    },
    "colors": {
        "themeColor": "#FF5A28"
    },
    "blackColors": {
        "themeColor": "#FF5A28",
        "backgroundColor": "#000000",
        "navigationBarColor": "#1A1A1A",
        "tabBarSelectedColor": "#FF5A28"
    }
}
```

**参数说明**

| 参数 | 说明 | 类型 | 必选 | 默认值 |
| --- | --- | --- | --- | --- |
| appId | 应用 ID（平台 URL 中的 id 参数） | Number | 是 | 无 |
| thingAppKey | 涂鸦开发者平台对应 SDK 的 AppKey | String | 是 | 无 |
| appScheme | 涂鸦开发者平台对应 SDK 的渠道标识符 | String | 是 | 无 |
| needBle | 是否支持蓝牙设备配网 | Boolean | 否 | true |
| need_backgroud_audio | 是否支持后台录音（需配合 `UIBackgroundModes: audio`） | Boolean | 否 | true |
| support_ble_gpt | 是否支持 BLE GPT（AI 语音能力） | Boolean | 否 | true |
| hotspotPrefixs | 配网设备热点前缀 | Array | 否 | ["SmartLife"] |
| themeColor | UI 主题色 | String | 否 | #FF5A28 |
| blackColors | 深色模式配色，键与 `colors` 同名 | Object | 否 | 无 |

Bundle Identifier 和 `appScheme` 必须与平台上申请 AppKey 时填写的一致，否则 SDK 初始化失败。

#### ThingSmartCryption.xcframework

确保从涂鸦平台下载的 `ThingSmartCryption` 安全组件已放在本地 `ios_core_sdk/` 目录，并与 Podfile 中 `:path => './ios_core_sdk'` 对应。该目录包含应用专属安全材料，应由 `.gitignore` 忽略，不提交到仓库。

- 文档：[准备工作](https://developer.tuya.com/cn/docs/app-development/preparation?id=Ka69nt983bhh5)

### Step 3: 权限声明

录音、配网、扫码等能力都需要权限声明，缺失会在运行时直接崩溃。可写在 `Info.plist`，也可写在 Target Build Settings 的 `INFOPLIST_KEY_*`（Demo 用的是后者）。

| 键 | 用途 | 何时必需 |
| --- | --- | --- |
| `NSMicrophoneUsageDescription` | 录音 | 小程序面板与 Native SDK **都需要** |
| `NSBluetoothAlwaysUsageDescription` | 蓝牙设备发现与配网 | 有蓝牙配网时 |
| `NSBluetoothPeripheralUsageDescription` | 兼容 iOS 12 及以下的蓝牙权限 | 有蓝牙配网时 |
| `NSCameraUsageDescription` | 扫码添加设备 | 有扫码配网时 |
| `NSLocationWhenInUseUsageDescription` | 创建家庭时获取位置 | 创建家庭时 |
| `NSPhotoLibraryUsageDescription` | 相册访问 | 需要选图时 |

后台录音还需要在 `Info.plist` 中声明：

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

并与 `thing_custom_config.json` 的 `need_backgroud_audio: true` 配合使用。

> 排查提示：如果权限写在 Build Settings 里，检查 `Info.plist` 时会看不到，容易误判为缺失。两处都要看。

### Step 4: SDK 初始化

在 `AppDelegate.m` 的 `application:didFinishLaunchingWithOptions:` 中完成初始化：

```objc
#import "AppKey.h"
#import <ThingSmartBizCore/ThingSmartBizCore.h>
#import <ThingSmartBaseKit/ThingSmartBaseKit.h>
#import <ThingSmartMiniAppBizBundle/ThingSmartMiniAppBizBundle.h>
#import <ThingModuleManager/ThingModuleManager.h>

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    // 1. 启动涂鸦 SDK
    [[ThingSmartSDK sharedInstance] startWithAppKey:APP_KEY secretKey:APP_SECRET_KEY];
#if DEBUG
    [[ThingSmartSDK sharedInstance] setDebugMode:YES];
#endif

    // 2. 初始化小程序 SDK
    [[ThingMiniAppClient initialClient] initialize];

    // 3.（可选）开启 vConsole 调试，仅 DEBUG 使用
    [[ThingMiniAppClient debugClient] vConsoleDebugEnable:YES];

    // 4. 将启动事件转发给模块管理器 —— 缺这一步业务包无法注册服务
    return [[ThingModuleManager sharedInstance] application:application
                             didFinishLaunchingWithOptions:launchOptions];
}
```

第 4 步是最容易漏的：不转发给 `ThingModuleManager`，后续所有 `serviceOfProtocol:` 都会拿到 nil。

- 文档：[集成 SDK](https://developer.tuya.com/cn/docs/app-development/integrate-sdk?id=Ka5d52ewngdoi)

### Step 5: 用户登录

通过 `ThingSmartUser` 实现登录注册，手机号与邮箱两条链路对称，各自支持密码登录、验证码登录、注册和重置密码。建议像 Demo 一样封装成 `AuthService` 统一收口。

```objc
#import <ThingSmartBaseKit/ThingSmartBaseKit.h>

// —— 手机号 ——
// 密码登录
[[ThingSmartUser sharedInstance] loginByPhone:@"86" phoneNumber:phone password:pwd
                                      success:^{ } failure:^(NSError *e) { }];
// 验证码登录
[[ThingSmartUser sharedInstance] loginWithMobile:phone countryCode:@"86" code:code
                                         success:^{ } failure:^(NSError *e) { }];

// —— 邮箱 ——
[[ThingSmartUser sharedInstance] loginByEmail:@"86" email:email password:pwd
                                      success:^{ } failure:^(NSError *e) { }];

// —— 验证码 ——
// 发送（type: 1 注册 / 2 登录 / 3 重置密码）
[[ThingSmartUser sharedInstance] sendVerifyCodeWithUserName:account
                                                     region:region
                                                countryCode:@"86"
                                                       type:1
                                                    success:^{ } failure:^(NSError *e) { }];
// 校验
[[ThingSmartUser sharedInstance] checkCodeWithUserName:account region:region
                                           countryCode:@"86" code:code type:1
                                               success:^(BOOL valid) { }
                                               failure:^(NSError *e) { }];

// 登录态
BOOL isLoggedIn = [ThingSmartUser sharedInstance].isLogin;
```

**要点**

- 发送验证码的 `region` 与 `countryCode` 要配套；手机号可用 `getDefaultRegionWithCountryCode:` 取默认 region，邮箱可传 nil。
- 校验验证码时的 `type` 必须与发送时一致，否则校验失败。
- 通用注册可以先判断账号是邮箱还是手机号，再分派到 `registerByEmail:` / `registerByPhone:`，避免上层写两套。
- **国家/地区选择**：不要让用户手输国家码。Demo 用 `CountryModel` 内置按大区分组的国家表（含国旗 emoji、中英文名、ISO 码），配 `CountryPickerViewController` 提供带搜索的选择页，并记住上次选择。
- 登出后要清理本地缓存的家庭 ID 等状态，避免下次登录串号。

- 文档：[用户与账号](https://developer.tuya.com/cn/docs/app-development/user?id=Ka5cgmm97jlt2)

### Step 6: 家庭管理

涂鸦 SDK 以「家庭」为维度管理设备和权限，**必须先有家庭且设为当前家庭后，设备列表才有数据**。

```objc
#import <ThingSmartDeviceKit/ThingSmartDeviceKit.h>
#import <ThingSmartBizCore/ThingSmartBizCore.h>
#import <ThingModuleServices/ThingModuleServices.h>

// 1. 查询家庭列表
ThingSmartHomeManager *homeManager = [ThingSmartHomeManager new];
[homeManager getHomeListWithSuccess:^(NSArray<ThingSmartHomeModel *> *homes) {
    if (homes.count == 0) {
        // 无家庭，创建默认家庭
        [homeManager addHomeWithName:@"我的家庭"
                             geoName:@"杭州"
                               rooms:@[@"客厅"]
                            latitude:30.27
                           longitude:120.15
                             success:^(long long homeId) {
            [self setupCurrentHomeWithId:homeId];
        } failure:^(NSError *error) { }];
    } else {
        [self setupCurrentHomeWithId:homes.firstObject.homeId];
    }
} failure:^(NSError *error) { }];

// 2. 获取家庭详情并设置当前家庭
- (void)setupCurrentHomeWithId:(long long)homeId {
    self.home = [ThingSmartHome homeWithHomeId:homeId];
    [self.home getHomeDataWithSuccess:^(ThingSmartHomeModel *homeModel) {
        // 注册 ThingFamilyProtocol 并更新当前家庭 ID
        [[ThingSmartBizCore sharedInstance] registerService:@protocol(ThingFamilyProtocol)
                                              withInstance:self];
        id<ThingFamilyProtocol> impl = [[ThingSmartBizCore sharedInstance]
                                         serviceOfProtocol:@protocol(ThingFamilyProtocol)];
        if ([impl respondsToSelector:@selector(updateCurrentFamilyId:)]) {
            [impl updateCurrentFamilyId:homeId];
        }
    } failure:^(NSError *error) { }];
}
```

调用 `updateCurrentFamilyId:` 的类需要遵循 `<ThingFamilyProtocol>` 协议，并实现 `currentFamilyId` 返回当前家庭 ID。

- 文档：[家庭管理](https://developer.tuya.com/cn/docs/app-development/home?id=Ka5d52ey6e58h)

### Step 7: 设备配网

Demo 提供标准配网和 BLE 单点设备自定义配网两种入口。

#### 标准配网

通过 `ThingActivatorProtocol` 调起配网页面，支持 Wi-Fi、蓝牙等多种配网方式。

```objc
#import <ThingSmartBizCore/ThingSmartBizCore.h>
#import <ThingModuleServices/ThingActivatorProtocol.h>

id<ThingActivatorProtocol> impl = [[ThingSmartBizCore sharedInstance]
                                    serviceOfProtocol:@protocol(ThingActivatorProtocol)];
if (impl) {
    [impl gotoCategoryViewController];

    [impl activatorCompletion:ThingActivatorCompletionNodeNormal
                   customJump:NO
              completionBlock:^(NSArray *deviceList) {
        NSLog(@"配网完成，设备: %@", deviceList);
    }];
}

// 或进入扫码配网页面
if ([impl respondsToSelector:@selector(gotoQRCodeViewControllerWithUserInfo:)]) {
    [impl gotoQRCodeViewControllerWithUserInfo:nil];
}
```

#### BLE 单点设备自定义配网

`CustomBLEPairingSession` 封装 BLE 搜索、Token 获取、激活、取消清理和错误映射，`CustomBLEPairingViewController` 负责扫描列表、设备选择和结果展示。

调用顺序：

1. 确认用户已登录，并取得有效的当前 `homeId`。
2. 调用 `startWithHomeID:eventHandler:` 开始扫描。
3. 从回调的设备列表中选择一台设备。
4. 调用 `activateDeviceWithIdentifier:`；Session 会停止扫描、获取新 Token 并开始激活。
5. 成功后刷新当前家庭的设备列表；取消或离开页面时调用 `cancel`。

```objc
CustomBLEPairingSession *session = [CustomBLEPairingSession new];
[session startWithHomeID:homeId eventHandler:^(CustomBLEPairingSnapshot *snapshot) {
    if (snapshot.state == CustomBLEPairingStateScanning) {
        // 使用 snapshot.devices 更新扫描列表
    } else if (snapshot.state == CustomBLEPairingStateSucceeded) {
        NSLog(@"配网成功: %@", snapshot.resultDevice.deviceID);
    } else if (snapshot.state == CustomBLEPairingStateFailed) {
        NSLog(@"配网失败 [%ld]: %@",
              (long)snapshot.failure.code, snapshot.failure.message);
    }
}];
```

该示例只处理 BLE 单点设备，每次激活一台，不用于 BLE-Wi-Fi 双模、EZ/AP、Mesh、Beacon、Matter 或子设备。Token 在用户选择设备后重新获取，不应跨配网会话复用。配网只在页面前台执行，离开页面即停止扫描和激活。

- 文档：[设备配网](https://developer.tuya.com/cn/docs/app-development/activator?id=Ka5cgmlzpfig4)

---

### Step 8: Native SDK 录音链路（自绘 UI 时才需要）

不使用小程序面板、要自己实现录音界面时，用 `ThingAudioRecordInterface`（随 `ThingSmartAIVoiceBizBundle` 一起引入，**不需要额外加 pod**）。

底层入口是 `[ThingAudioDetectManagerNative sharedInstance]`，遵循 `ThingAudioDetectManagerNativeProtocol`。**回调不保证在主线程**，建议像 Demo 的 `NativeAudioService` 一样做一层封装，统一切回主线程再抛给 UI。

#### 开始录音

```objc
#import <ThingAudioRecordInterface/ThingAudioRecordInterface.h>
#import <TUniAudioDetectManager/ThingAudioDetectManagerNative.h>

ThingAudioRecordConfig *config = [[ThingAudioRecordConfig alloc] init];
config.recordType       = ThingAudioRecordTypeMeet;
config.businessType     = ThingAudioBusinessTypeNote;
config.transferType     = ThingAudioRecordTransferTypeRealTime;

// 录音来源：手机麦克风用 ThingSystemMic16KMono；设备录音用设备对应的 source
config.audioSource      = ThingSystemMic16KMono;
config.audioSourceList  = @[@(ThingSystemMic16KMono)];

// 处理能力开关
config.needAsr          = YES;   // 实时语音识别
config.needTranslate    = YES;   // 实时翻译
config.needTTS          = NO;    // TTS 播报
config.needAmplitude    = YES;   // 振幅回调（画波形用）
config.needAutoRecognize = NO;

// 语言（源语言 / 目标语言，如 zh / en）
config.originalLanguage = @"zh";
config.targetLanguage   = @"en";
config.startLivingStatus = 0;
config.audio3AConfig = [[ThingAudio3AConfig alloc] initWithEnableRnAns:NO ans:NO level:0 agc:YES aec:NO];

// deviceId：手机麦克风自定义一个固定值（Demo 用 @"PHONE"）；设备录音传 devId
[[ThingAudioDetectManagerNative sharedInstance] startAudioRecordingWithDeviceId:deviceId
                                                                        config:config
                                                                       success:^(ThingAudioRecordObject *task) { }
                                                                       failure:^(NSError *error) { }];
```

录音控制的其余接口：

```objc
- pauseRecordTransferWithDeviceId:success:failure:
- resumeRecordTransferWithDeviceId:success:failure:
- stopRecordTransferWithDeviceId:success:failure:
- recordTransferTaskWithDeviceId:            // 同步查询是否有进行中的任务
```

#### 监听回调

```objc
[[ThingAudioDetectManagerNative sharedInstance] addRecordListener:self deviceId:deviceId];
// 页面销毁时务必移除，且必须是同一实例 + 同一 deviceId
[[ThingAudioDetectManagerNative sharedInstance] removeRecordListener:self deviceId:deviceId];
```

`ThingAudioRecordManagerDelegate` 主要方法：

| 方法 | 用途 |
| --- | --- |
| `record:didUpdateStatus:` | 录音状态与时长变化 |
| `record:didUpdateAmplitude:channel:` | 振幅回调，用于绘制波形 |
| `record:onProcessResult:` | ASR / 翻译 / TTS 过程结果 |
| `record:didFinishWithError:` | 录音结束或出错 |

#### 解析 onProcessResult（重点，容易写错）

`ThingAudioRecordProcessResult` 的 `phase` 有 Task / ReceiveAudio / SendAudio / ReceiveData / **Asr** / **Text** / Skill / Tts；`status` 有 Start / Update / End / Cancel。

- **识别原文**在 `phase == Asr` 或 `phase == Text` 时由 `result.text` 承载。
- **翻译结果没有独立 phase**：译文在 `result.translateText`，并带独立的 `result.translateStatus`。只判断 `phase` 会永远拿不到翻译。
- **按句聚合**：同一句会多次回调（Update 覆盖中间结果，End 定稿）。聚合 key 建议用 `asrId + channel`，`asrId` 为 0 时回落到 `requestId`。`Cancel` 不要覆盖已有译文。

```objc
- (void)record:(NSString *)deviceId onProcessResult:(ThingAudioRecordProcessResult *)result {
    NSString *key = result.asrId != 0
        ? [NSString stringWithFormat:@"%lld-%d", result.asrId, result.channel]
        : result.requestId;

    if ((result.phase == ThingAudioRecordProcessPhaseAsr ||
         result.phase == ThingAudioRecordProcessPhaseText)
        && key.length > 0 && result.text.length > 0) {
        self.asrTexts[key] = result.text;      // 识别原文
    }

    if (key.length > 0 &&
        (result.translateText.length > 0 ||
         result.translateStatus == ThingAudioRecordProcessStatusEnd)) {
        if (result.translateStatus != ThingAudioRecordProcessStatusCancel ||
            self.translateTexts[key] == nil) {
            self.translateTexts[key] = result.translateText ?: @"";
        }
    }
}
```

#### 录音列表与详情

```objc
// 列表（orderBy=1 按 recordTime，asc=0 降序）
ThingAudioRecordFilesParams *p = [ThingAudioRecordFilesParams new];
p.orderBy = @(1); p.asc = @(0);
[manager getRecordTransferResultList:p success:^(NSArray<ThingAudioRecordFile *> *list) { } failure:^(NSError *e) { }];

// 混合搜索（标题 / 标签 / 转写内容）
ThingAudioRecordSearchMixParams *sp = [ThingAudioRecordSearchMixParams new];
sp.content = keyword;
[manager searchRecordTransferResult:sp success:^(NSArray<ThingAudioRecordSearchMixResultItem *> *list) { } failure:^(NSError *e) { }];

// 详情
[manager getRecordTransferResultDetail:recordId amplitudeMaxCount:200 success:^(ThingAudioRecordFile *file) { } failure:^(NSError *e) { }];

// 内容
[manager getRecordTransferRecognizeResult:fileId success:^(NSString *text) { } failure:^(NSError *e) { }];  // 转写全文
[manager getRecordTransferSummaryResult:fileId   success:^(NSString *text) { } failure:^(NSError *e) { }];  // 总结

// 分句（带时间戳，可按句定位播放）
ThingAudioRecordAsrsParams *ap = [ThingAudioRecordAsrsParams new];
ap.fileId = @(fileId);
[manager getRecordTransferRealTimeResult:ap success:^(NSArray<ThingAudioRecordAsrResult *> *list) { } failure:^(NSError *e) { }];
```

#### 离线转写 / 总结 / 翻译

```objc
ThingAudioRecordUploadFileParams *params = [ThingAudioRecordUploadFileParams new];
params.fileId   = fileId;
params.recordId = recordId;
params.transLang = @"en";   // 仅翻译任务需要

// taskType: 0 转写、1 总结、2 翻译
// 注意：转写任务同步返回 taskId，总结和翻译没有任务 ID
NSString *taskId = [manager processRecordTransferResult:params
                                               taskType:0
                                               progress:^(double value, int status) { }
                                                success:^{ }
                                                failure:^(NSError *e) { }];
```

跨页面监听转写/总结/翻译的完成状态，用全局同步监听：

```objc
[manager addSyncListener:self];      // ThingAudioRecordSyncManagerDelegate
[manager removeSyncListener:self];
```

---

### Step 9: 灌流调试与 WER 评估（可选）

灌流（Perfusion）是把**本地音频文件替换麦克风采集数据**喂给录音链路的调试手段，用于在不出声的前提下复现并回归 ASR / 翻译 / TTS 全流程，并计算 WER、导出测试报告。

能力已封装为独立组件 `ThingPerfusionKit`，以本地路径依赖：

```ruby
pod 'ThingPerfusionKit', :path => '../Modules/ThingPerfusionKit'
# 只要能力不要页面：
# pod 'ThingPerfusionKit/Core', :path => '../Modules/ThingPerfusionKit'
```

| 子模块 | 内容 | 依赖 |
| --- | --- | --- |
| `Core` | 灌流配置提供者、WAV 格式校验、WER 计算、报告生成（无 UI） | `ThingAudioRecordInterface`、`ThingModuleManager`、`ThingAnnotationFoundation` |
| `UI` | 开箱可用的灌流调试页 | `Core` + UIKit / AVFAudio |

三个依赖都是 AI 语音业务包的既有传递依赖，不需要新增 pod。

#### 直接用现成页面

```objc
#import <ThingPerfusionKit/ThingPerfusionViewController.h>

ThingPerfusionViewController *vc = [[ThingPerfusionViewController alloc] init];
vc.hidesBottomBarWhenPushed = YES;
[self.navigationController pushViewController:vc animated:YES];
```

#### 只用能力，自己写界面

```objc
#import <ThingPerfusionKit/ThingPerfusionService.h>
#import <ThingPerfusionKit/ThingPerfusionAudioFileInfo.h>

// 1. 先校验格式，避免白跑一次
ThingPerfusionAudioFileInfo *info = [ThingPerfusionService audioFileInfoWithFileName:@"sample.wav"];
if (!info.isDecodable) { NSLog(@"%@", info.warning); return; }

// 2. 配置灌流（必须在 startRecording 之前写入）
ThingPerfusionService *service = [ThingPerfusionService sharedInstance];
service.perfusionEnabled = YES;
service.perfusionFileName = @"sample.wav";
service.autoCloseFileWhenPerfusionEnd = YES;
service.didEndHandler = ^(NSString *fileName) { /* 收集结果 */ };

// 3. 照常开始录音（deviceId 用手机麦克风，audioSource = ThingSystemMic16KMono）

// 4. 用完必须关闭，否则影响后续正常录音
[service reset];
```

#### 单独做 WER 评估（不依赖灌流）

```objc
#import <ThingPerfusionKit/ThingPerfusionWERCalculator.h>

ThingPerfusionWERResult *r = [ThingPerfusionWERCalculator evaluateReference:refText
                                                                hypothesis:hypText];
// r.accuracy / r.wer / r.referenceCount / r.substitutions / r.deletions / r.insertions
```

`WER = (S + D + I) / N`，准确率 = 1 − WER。文本先归一化（小写、标点转空格而非删除、中文逐字切分、剔除语气词、千分位还原、数词归一化）再用编辑距离对齐。

#### ⚠️ 音频格式要求（最容易踩的坑）

底层把文件内容当作 **16kHz / 16bit / 单声道整型 PCM** 直接替换采集流，**只支持整型 PCM 的 WAV**（WAV `audioFormat` 字段 1；3 是 IEEE float，不支持）。格式不符的典型表现是「灌流在跑，但一条 ASR 都没有」。

```bash
afconvert -f WAVE -d LEI16@16000 -c 1 输入.wav 输出.wav
```

#### 工作原理

底层 `ThingMicrophoneAudioInput` 启动音频输入时，通过 `ThingAIBudsDebuggerProtocol` 向 App 侧回读灌流开关、文件名、自动收尾三项配置。组件用 `ThingRegisterAPIAnnotation` 在编译期把配置提供者写入 Mach-O 的 `_ThingMOV3_` 段，App 启动后由 `ThingMachRegister` 自动收集，**不需要在 `AppDelegate` 里写注册代码**。`registerProvider` / `isProviderReady` / `configFetchCount` 仅用于自检：开始灌流后 `configFetchCount` 仍为 0，说明配置没被回读，灌流没有生效。

工作目录（组件已封装，位于 App 沙盒 Documents 下）：

```
voiceRecord/automaticTest/audioFiles/    灌流音频
voiceRecord/automaticTest/references/    参考答案（txt）
voiceRecord/automaticTest/reports/       导出的 HTML 报告
```

---

## Demo 页面与服务

| 页面 / 服务 | 说明 |
| --- | --- |
| `MainViewController` | 首页：AI 笔记 / AI 翻译小程序卡片与快捷入口、当前家庭设备列表、右上角添加设备 |
| `MainTabBarController` | 首页 / SDK / 我的 三 Tab |
| `NativeSDKViewController` | Native SDK 录音页（Step 8 的完整示例） |
| `NativeRecordListViewController` | 录音列表，支持混合搜索 |
| `NativeRecordDetailViewController` | 录音详情：转写、总结、翻译、播放与振幅，可发起离线任务 |
| `DeviceManagementViewController` + `DeviceService` | 设备列表刷新、在线状态、重命名、移除。需先完成 Step 6 |
| `MineViewController` | 用户信息、修改昵称、设备管理、诊断日志、灌流调试、退出登录 |
| `CustomBLEPairingViewController` + `CustomBLEPairingSession` | BLE 单点设备自定义配网 |
| `AuthService` / `CountryModel` / `CountryPickerViewController` | 登录注册、国家地区选择 |
| `FamilyBaseViewController` | Demo 自绘页面的通用导航、卡片与弹窗基类 |

诊断日志通过 `ThingFeedBackProtocol` 打开涂鸦反馈页。调用前检查协议服务是否响应目标方法，服务不可用时给出提示，不在仓库中写日志文件。

---

## AI 功能路由

### 小程序路由表

| 功能 | 小程序 AppID | 入口常量 | 说明 |
| --- | --- | --- | --- |
| AI 笔记 - 录音 | `tyylldwlb8411tg8u2` | `kMiniAppURLAINoteLiveRecording` | 专业录音 + AI 笔记 |
| AI 笔记 - 同声传译 | 同上 | `kMiniAppURLAINoteSimultaneousInterpretation` | 100+ 语言实时传译 |
| AI 笔记 - 实时转写 | 同上 | `kMiniAppURLAINoteRealTimeRecording` | 语音实时转文字 |
| AI 翻译 - 同声传译 | `ty0u9m1s5ea1k71m2h` | `kMiniAppURLAITranslateSimultaneous` | 翻译场景传译 |
| AI 翻译 - 对话翻译 | 同上 | `kMiniAppURLAITranslateFaceToFace` | 面对面双向对话翻译 |

上表是 Demo 首页透出的**快捷入口**，不等于小程序的全部能力。小程序内部还有导入音频、电话录音、通话翻译、文本翻译等功能，通过 AppID 打开首页即可看到。

### 路由常量定义（MiniAppRoutes.h）

```objc
// AI笔记 小程序 App ID
#define kMiniAppIdAINote       @"tyylldwlb8411tg8u2"
// AI翻译 小程序 App ID
#define kMiniAppIdAITranslate  @"ty0u9m1s5ea1k71m2h"

// AI笔记快捷入口
#define kMiniAppURLAINoteLiveRecording             @"thingSmart://miniApp?url=godzilla%3A%2F%2Ftyylldwlb8411tg8u2%2Fpages%2Fhome%2Findex%3FmodeKey%3DliveRecording"
#define kMiniAppURLAINoteSimultaneousInterpretation @"thingSmart://miniApp?url=godzilla%3A%2F%2Ftyylldwlb8411tg8u2%2Fpages%2Fhome%2Findex%3FmodeKey%3DsimultaneousInterpretation"
#define kMiniAppURLAINoteRealTimeRecording         @"thingSmart://miniApp?url=godzilla%3A%2F%2Ftyylldwlb8411tg8u2%2Fpages%2Fhome%2Findex%3FmodeKey%3DrealTimeRecording"

// AI翻译快捷入口
#define kMiniAppURLAITranslateSimultaneous         @"thingSmart://miniApp?url=godzilla%3A%2F%2Fty0u9m1s5ea1k71m2h%2Fpages%2Fsimultaneous%2Findex"
#define kMiniAppURLAITranslateFaceToFace           @"thingSmart://miniApp?url=godzilla%3A%2F%2Fty0u9m1s5ea1k71m2h%2Fpages%2FFaceToFace%2Findex"
```

### 打开小程序

```objc
#import <ThingSmartMiniAppBizBundle/ThingSmartMiniAppBizBundle.h>

// 方式一：通过 AppID 打开小程序首页
[[ThingMiniAppClient coreClient] openMiniAppByAppId:kMiniAppIdAINote];

// 方式二：通过 URL 打开小程序指定页面
NSURLComponents *components = [NSURLComponents componentsWithString:kMiniAppURLAINoteLiveRecording];
for (NSURLQueryItem *item in components.queryItems) {
    if ([item.name isEqualToString:@"url"]) {
        [[ThingMiniAppClient coreClient] openMiniAppByUrl:item.value];
        break;
    }
}
```

### 设备面板跳转

```objc
#import <ThingSmartBizCore/ThingSmartBizCore.h>
#import <ThingModuleServices/ThingModuleServices.h>

ThingSmartDevice *device = [ThingSmartDevice deviceWithDeviceId:devId];
id<ThingPanelProtocol> impl = [[ThingSmartBizCore sharedInstance]
                                serviceOfProtocol:@protocol(ThingPanelProtocol)];
if (impl) {
    [impl gotoPanelViewControllerWithDevice:device.deviceModel
                                     group:nil
                              initialProps:nil
                              contextProps:nil
                                completion:nil];
}
```

- 文档：[打开面板](https://developer.tuya.com/cn/docs/app-development/devicecontrol?id=Ka8qf8lnahsf8)

---

## 常见问题排查

| 现象 | 排查方向 |
| --- | --- |
| `serviceOfProtocol:` 全部返回 nil | Step 4 没把 `didFinishLaunchingWithOptions` 转发给 `ThingModuleManager` |
| SDK 初始化失败 | Bundle Identifier / `appScheme` 与平台申请信息不一致；`ios_core_sdk/` 缺 `ThingSmartCryption`；缺 `thing_custom_config.json` |
| 设备列表一直为空 | 没创建家庭 / 没调 `getHomeDataWithSuccess:` / 没调 `updateCurrentFamilyId:`（三者缺一不可） |
| 一开始录音就崩 | 缺 `NSMicrophoneUsageDescription`；注意它可能写在 Build Settings 而非 `Info.plist` |
| 录音有状态回调但没有 ASR 文本 | `config.needAsr` 没开；或只判断了 `phase`，漏了 Text 阶段 |
| 有识别原文但没有翻译 | 翻译没有独立 phase，译文在 `result.translateText` / `translateStatus`，见 Step 8 |
| 回调里更新 UI 崩溃或不刷新 | 底层回调不保证主线程，需自行切主线程 |
| 离开页面后仍收到回调 | `removeRecordListener:deviceId:` 没有用同一实例 + 同一 deviceId 成对调用 |
| 后台录音被系统中断 | 缺 `UIBackgroundModes: audio`，或 `need_backgroud_audio` 未开 |
| 灌流在跑但一条 ASR 都没有 | 音频不是整型 PCM 的 16kHz/16bit/单声道 WAV，用 `afconvert` 转换 |
| 灌流没生效，`configFetchCount` 为 0 | 配置提供者没被底层取到，检查是否被别的 `ThingAIBudsDebuggerProtocol` 实现顶掉 |
| 小程序跳转失败 | `MiniAppRoutes.h` 中的 AppID / 路径与平台配置不一致 |
| pod install 报找不到 ThingPerfusionKit | 该组件在仓库外的 `../Modules/ThingPerfusionKit`，未获取时注释掉这一行 |

---

## 参考文档

| 主题 | 在线文档 |
| --- | --- |
| 准备工作 | https://developer.tuya.com/cn/docs/app-development/preparation?id=Ka69nt983bhh5 |
| 框架接入 | https://developer.tuya.com/cn/docs/app-development/framework?id=Ka8j2895qdvtj |
| 集成 SDK | https://developer.tuya.com/cn/docs/app-development/integrate-sdk?id=Ka5d52ewngdoi |
| 用户与账号 | https://developer.tuya.com/cn/docs/app-development/user?id=Ka5cgmm97jlt2 |
| 家庭管理 | https://developer.tuya.com/cn/docs/app-development/home?id=Ka5d52ey6e58h |
| 家庭信息管理 | https://developer.tuya.com/cn/docs/app-development/iOS_family?id=Kaixeor409hck |
| 设备配网 | https://developer.tuya.com/cn/docs/app-development/activator?id=Ka5cgmlzpfig4 |
| 设备管理 | https://developer.tuya.com/cn/docs/app-development/device?id=Ka5cgmmjr46cp |
| 打开面板 | https://developer.tuya.com/cn/docs/app-development/devicecontrol?id=Ka8qf8lnahsf8 |

编写代码前务必阅读对应在线文档获取最新接口参数和注意事项。

## 注意事项

- Demo 源码中用 `MARK: AIVoice` 标注了关键集成点（`AppDelegate.m` 初始化、`MiniAppRoutes.h` 路由、`AuthService.m` 登录注册、`ActivatorService.m` 配网、`MainViewController.m` 设备详情跳转与设置当前家庭），集成时请在工程内搜索 `MARK: AIVoice` 逐条阅读。
- 本地 `ios_core_sdk/` 中必须包含 `ThingSmartCryption` 安全组件，工程 Bundle Resources 中必须包含 `thing_custom_config.json`；缺少任一项 SDK 都无法正常工作。
- 所有涂鸦业务包保持同一大版本（当前 7.8.x）。
- 小程序路由常量中的 AppID 和 URL 需与涂鸦平台上的小程序配置一致，否则跳转失败。
- Native SDK 的录音监听器必须用同一实例 + 同一 `deviceId` 成对注册与移除；回调不保证主线程。
- 灌流用完必须 `reset`，否则后续正常录音会继续读本地文件。
