---
name: tuya-aivoice-ios-integration
description: >-
  涂鸦 AIVoice iOS SDK 接入指南。当用户需要在 iOS 项目中集成涂鸦 AI 音频业务包
  （AI 笔记、AI 翻译、蓝牙音频设备配网与面板）时使用此 Skill。
---

AI 音频 UI 业务包可将普通蓝牙耳机、眼镜、音箱等音频类产品升级为 AI 产品，支持 AI 录音、实时转写和实时翻译，覆盖全球 100+ 种语言。

Demo 工程：[tuya-aivoice-ios-sdk-sample-objc](https://github.com/tuya/tuya-aivoice-ios-sdk-sample-objc)

## 快速决策树

```
用户咨询 AIVoice iOS 接入
        |
        +-- 还没开始接入？
        |       +-- 从零开始 --> 基础集成（Step 1~6 顺序执行）
        |
        +-- 已有涂鸦 SDK，想加 AI 能力？
        |       +-- AI 笔记（录音/转写/传译）--> 功能路由：AI 笔记
        |       +-- AI 翻译（传译/对话翻译）--> 功能路由：AI 翻译
        |
        +-- 某个环节有问题？
                +-- CocoaPods / 依赖 --> Step 1
                +-- 配置文件 --> Step 2
                +-- SDK 初始化 --> Step 3
                +-- 登录注册 --> Step 4
                +-- 家庭管理 --> Step 5
                +-- 设备配网 --> Step 6
                +-- 设备面板 / 小程序 --> 功能路由：设备面板
```

## 场景关键词匹配

| 关键词 | 路由目标 |
| --- | --- |
| CocoaPods、Podfile、依赖、pod install | Step 1: 依赖配置 |
| AppKey、SecretKey、appId、thing_custom_config、配置 | Step 2: 配置文件 |
| 初始化、startWithAppKey、AppDelegate、ThingSmartSDK | Step 3: SDK 初始化 |
| 登录、注册、验证码、ThingSmartUser | Step 4: 用户登录 |
| 家庭、homeId、ThingSmartHome、设备列表为空 | Step 5: 家庭管理 |
| 配网、蓝牙、BLE、耳机、眼镜、音箱、扫码配网 | Step 6: 设备配网 |
| AI笔记、录音、实时转写、同声传译、liveRecording | 功能路由：AI 笔记 |
| AI翻译、对话翻译、FaceToFace、翻译 | 功能路由：AI 翻译 |
| 面板、小程序、MiniApp、设备详情 | 功能路由：设备面板 |

---

## 基础集成步骤

### Step 1: CocoaPods 依赖配置

在 Podfile 中添加涂鸦 pod 源和业务包依赖：

```ruby
source 'https://cdn.cocoapods.org/'
source 'https://github.com/tuya/tuya-pod-specs.git'

use_modular_headers!
platform :ios, '12.0'
inhibit_all_warnings!
use_frameworks! :linkage => :static

target 'YourApp' do

  # [必选] 安全组件（本地引用，不提交到 Git）
  pod 'ThingSmartCryption', :path => './ios_core_sdk'

  # [必选] AI 音频 UI 业务包
  pod 'ThingSmartAIVoiceBizBundle', '~> 7.5.0'

  # [必选] 小程序 UI 业务包
  pod 'ThingSmartMiniAppBizBundle', '~> 7.5.0'
  pod 'ThingSmartBaseKitBizBundle', '~> 7.5.0'
  pod 'ThingSmartBizKitBizBundle', '~> 7.5.0'

  # [可选] 设备配网 UI 业务包 — 无配网需求可不加
  pod 'ThingSmartActivatorBizBundle', '~> 7.5.0'

  # [可选] BLE 单点设备自定义配网
  pod 'ThingSmartBusinessExtensionKit', '~> 7.5.0'
  pod 'ThingSmartBusinessExtensionKitBLEExtra', '~> 7.5.0'

  # [可选] 设备面板 UI 业务包 — 无设备控制需求可不加
  pod 'ThingSmartPanelBizBundle', '~> 7.5.0'

  # [可选] 设备详情 UI 业务包
  pod 'ThingSmartDeviceDetailBizBundle', '~> 7.5.0'

  # [可选] 设备 OTA 升级 UI 业务包
  # pod 'ThingSmartOTABizBundle', '~> 7.5.0'

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
```

执行 `pod install` 后用 `.xcworkspace` 打开工程。

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
| support_ble_gpt | 是否支持 BLE GPT（AI 语音能力） | Boolean | 否 | true |
| hotspotPrefixs | 配网设备热点前缀 | Array | 否 | ["SmartLife"] |
| themeColor | UI 主题色 | String | 否 | #FF5A28 |

#### ThingSmartCryption.xcframework

确保从涂鸦平台下载的 `ThingSmartCryption` 安全组件已放在本地 `ios_core_sdk/` 目录，并与 Podfile 中 `:path => './ios_core_sdk'` 对应。该目录包含应用专属安全材料，已由 `.gitignore` 忽略，不应提交到仓库。

- 文档：[准备工作](https://developer.tuya.com/cn/docs/app-development/preparation?id=Ka69nt983bhh5)

### Step 3: SDK 初始化

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

    // 4. 将启动事件转发给模块管理器
    return [[ThingModuleManager sharedInstance] application:application
                             didFinishLaunchingWithOptions:launchOptions];
}
```

- 文档：[集成 SDK](https://developer.tuya.com/cn/docs/app-development/integrate-sdk?id=Ka5d52ewngdoi)

### Step 4: 用户登录

通过 `ThingSmartUser` 实现登录注册。支持手机号、邮箱、验证码等多种方式。

```objc
#import <ThingSmartBaseKit/ThingSmartBaseKit.h>

// 手机号 + 密码登录
[[ThingSmartUser sharedInstance] loginByPhone:@"86"
                                 phoneNumber:@"13800138000"
                                    password:@"yourPassword"
                                     success:^{
    NSLog(@"登录成功");
} failure:^(NSError *error) {
    NSLog(@"登录失败: %@", error.localizedDescription);
}];

// 手机号 + 验证码登录
[[ThingSmartUser sharedInstance] loginWithMobile:@"13800138000"
                                    countryCode:@"86"
                                           code:@"123456"
                                        success:^{
    NSLog(@"登录成功");
} failure:^(NSError *error) {
    NSLog(@"登录失败: %@", error.localizedDescription);
}];

// 判断用户是否已登录
BOOL isLoggedIn = [ThingSmartUser sharedInstance].isLogin;
```

- 文档：[用户与账号](https://developer.tuya.com/cn/docs/app-development/user?id=Ka5cgmm97jlt2)

### Step 5: 家庭管理

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
                               rooms:@[@""]
                            latitude:30.27
                           longitude:120.15
                             success:^(long long homeId) {
            // 创建成功后获取详情并设置为当前家庭
            [self setupCurrentHomeWithId:homeId];
        } failure:^(NSError *error) {
            NSLog(@"创建家庭失败: %@", error.localizedDescription);
        }];
    } else {
        // 使用第一个家庭
        [self setupCurrentHomeWithId:homes.firstObject.homeId];
    }
} failure:^(NSError *error) {
    NSLog(@"获取家庭列表失败: %@", error.localizedDescription);
}];

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
    } failure:^(NSError *error) {
        NSLog(@"获取家庭详情失败: %@", error.localizedDescription);
    }];
}
```

调用 `updateCurrentFamilyId:` 的类需要遵循 `<ThingFamilyProtocol>` 协议。

- 文档：[家庭管理](https://developer.tuya.com/cn/docs/app-development/home?id=Ka5d52ey6e58h)

### Step 6: 设备配网

Demo 提供标准配网和 BLE 单点设备自定义配网两种入口。

#### 标准配网

通过 `ThingActivatorProtocol` 调起配网页面，支持 Wi-Fi、蓝牙等多种配网方式。

```objc
#import <ThingSmartBizCore/ThingSmartBizCore.h>
#import <ThingModuleServices/ThingActivatorProtocol.h>

// 进入品类选择配网页面
id<ThingActivatorProtocol> impl = [[ThingSmartBizCore sharedInstance]
                                    serviceOfProtocol:@protocol(ThingActivatorProtocol)];
if (impl) {
    [impl gotoCategoryViewController];

    // 设置配网完成回调
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
              (long)snapshot.failure.code,
              snapshot.failure.message);
    }
}];
```

该接口示例只处理 BLE 单点设备，每次激活一台设备，不用于 BLE-Wi-Fi 双模、EZ/AP、Mesh、Beacon、Matter 或子设备。Token 在用户选择设备后重新获取，不应跨配网会话复用。

- 文档：[设备配网](https://developer.tuya.com/cn/docs/app-development/activator?id=Ka5cgmlzpfig4)

---

## Demo 页面与服务

### 设备管理

`DeviceManagementViewController` 通过 `DeviceService` 获取当前家庭的设备列表，并提供刷新、在线状态展示、重命名和移除设备操作。使用前需要完成 Step 5 的家庭详情加载和当前家庭设置。

### 个人设置

`MineViewController` 展示当前用户信息，并调用 `ThingSmartUser` 完成昵称修改和退出登录。页面同时提供设备管理和诊断日志入口。

### 诊断日志入口

`MineViewController` 通过 `ThingFeedBackProtocol` 打开涂鸦反馈页面。调用前检查协议服务是否响应目标方法；服务不可用时向用户显示提示。该入口不在仓库中写入日志文件。

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
NSString *routeURL = kMiniAppURLAINoteLiveRecording;
NSURLComponents *components = [NSURLComponents componentsWithString:routeURL];
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

## 参考文档

| 主题 | 在线文档 |
| --- | --- |
| 准备工作 | https://developer.tuya.com/cn/docs/app-development/preparation?id=Ka69nt983bhh5 |
| 框架接入 | https://developer.tuya.com/cn/docs/app-development/framework?id=Ka8j2895qdvtj |
| 集成 SDK | https://developer.tuya.com/cn/docs/app-development/integrate-sdk?id=Ka5d52ewngdoi |
| 用户与账号 | https://developer.tuya.com/cn/docs/app-development/user?id=Ka5cgmm97jlt2 |
| 家庭管理 | https://developer.tuya.com/cn/docs/app-development/home?id=Ka5d52ey6e58h |
| 设备配网 | https://developer.tuya.com/cn/docs/app-development/activator?id=Ka5cgmlzpfig4 |
| 设备管理 | https://developer.tuya.com/cn/docs/app-development/device?id=Ka5cgmmjr46cp |
| 打开面板 | https://developer.tuya.com/cn/docs/app-development/devicecontrol?id=Ka8qf8lnahsf8 |

编写代码前务必阅读对应在线文档获取最新接口参数和注意事项。

## 注意事项

- Demo 源码中用 `MARK: AIVoice` 标注了所有关键集成点，集成时请在工程内搜索 `MARK: AIVoice` 逐条阅读。
- 本地 `ios_core_sdk/` 中必须包含 `ThingSmartCryption` 安全组件，工程 Bundle Resources 中必须包含 `thing_custom_config.json`；缺少任一项都会导致 SDK 无法正常工作。
- 小程序路由常量（`MiniAppRoutes.h`）中的 AppID 和 URL 需与涂鸦平台上的小程序配置一致，否则跳转会失败。
- 设备列表为空的常见原因：未创建家庭、未调用 `getHomeDataWithSuccess:` 获取家庭详情、未调用 `updateCurrentFamilyId:` 设置当前家庭。
