# 涂鸦 AI 音频 iOS Demo

**English:** [README.md](README.md)

## 项目介绍

AI 音频 UI 业务包是针对普通蓝牙耳机、眼镜、音箱等音频类产品直接升级为 AI 产品，即可使用 AI 记录和翻译功能，专业录音算法配合先进的语言模型，覆盖全球 100+ 种语言的实时精准转写和实时翻译。

本 Demo 同时演示两种接入形态，开发者可按需选择其一或组合使用：

| 接入形态 | 说明 | Demo 入口 |
|---------|------|----------|
| **UI 业务包（小程序面板）** | 直接复用涂鸦提供的 AI 笔记 / AI 翻译小程序面板，UI 与业务逻辑由涂鸦维护，接入成本最低 | 底部「首页」Tab |
| **Native SDK（自绘 UI）** | 通过 `ThingAudioRecordInterface` 原生接口自行实现录音、转写、总结、翻译界面，UI 完全自定义 | 底部「SDK」Tab |

在接入该业务包之前请先完成 [准备工作](https://developer.tuya.com/cn/docs/app-development/preparation?id=Ka8j28bikfqkf) 和 [框架接入](https://developer.tuya.com/cn/docs/app-development/framework?id=Ka8j2895qdvtj)。

AI 音频业务包 Demo 地址：[tuya-aivoice-ios-sdk-sample-objc](https://github.com/tuya/tuya-aivoice-ios-sdk-sample-objc)。

## 功能总览

| Tab / 入口 | 页面 | 能力 | 关键实现 |
|-----------|------|------|---------|
| 首页 | 首页 | AI 笔记 / AI 翻译小程序卡片与快捷入口（录音、同声传译、实时转写、对话翻译）、我的设备列表、点击设备跳转面板 | `MainViewController`、`MiniAppRoutes.h`、`DeviceListView` |
| 首页 → 右上角 + | 添加设备 | 正常添加（涂鸦配网 UI）、自定义添加（BLE 单点配网调试） | `ActivatorService`、`CustomBLEPairingViewController`、`CustomBLEPairingSession` |
| SDK | 录音 | 录音来源选择（手机麦克风 / 已配网设备）、ASR / NLG 翻译 / TTS 开关、源语言与目标语言选择（14 种）、实时振幅波形、录音开始/暂停/继续/结束、实时 ASR 与翻译文本、SDK 事件日志 | `NativeSDKViewController`、`NativeAudioService` |
| SDK → 录音列表 | 录音列表 | 全部已入库录音，支持按标题 / 标签 / 转写内容混合搜索 | `NativeRecordListViewController` |
| SDK → 录音详情 | 录音详情 | 转写、总结、翻译内容展示，音频播放与振幅，支持发起离线转写 / 总结 / 翻译任务 | `NativeRecordDetailViewController` |
| 我的 | 个人设置 | 展示用户信息、修改昵称、设备管理、上传诊断日志、灌流调试、退出登录 | `MineViewController` |
| 我的 → 设备管理 | 设备管理 | 刷新当前家庭设备、在线状态、重命名、移除设备 | `DeviceManagementViewController`、`DeviceService` |
| 我的 → 灌流调试 | 灌流调试 | 用本地音频文件替代麦克风采集跑通 ASR / 翻译 / TTS 链路，计算 WER 并导出 HTML 测试报告 | 独立组件 `ThingPerfusionKit` |
| 启动页 | 登录 / 注册 | 登录页：手机号 / 邮箱 + 密码；注册页：手机号 / 邮箱 + 验证码（带倒计时）+ 密码；带搜索的国家/地区选择器 | `LoginViewController`、`RegisterViewController`、`AuthService`、`CountryPickerViewController` |

## 页面截图

![Demo 页面截图](Screenshot/Demo-Screenshot.jpg)

单页原图：

| # | 页面 | 原图 | 说明 |
|---|------|------|------|
| 1 | 首页 | [01-home.png](Screenshot/01-home.png) | AI 笔记 / AI 翻译卡片与快捷入口、当前家庭设备列表 |
| 2 | AI 笔记小程序 | [02-ainote-miniapp.png](Screenshot/02-ainote-miniapp.png) | 小程序首页：录音、实时转写、同声传译、导入音频、电话录音与文件列表 |
| 3 | AI 笔记 · 录音 | [03-ainote-recording.png](Screenshot/03-ainote-recording.png) | 小程序录音页，可切换到 AI 转写 |
| 4 | AI 笔记 · 同声传译 | [04-ainote-interpretation.png](Screenshot/04-ainote-interpretation.png) | 录音进行中的同声传译，底部可切换源语言与目标语言 |
| 5 | AI 翻译小程序 | [05-aitranslate-miniapp.png](Screenshot/05-aitranslate-miniapp.png) | 文本翻译、同声传译、对话翻译、通话翻译与历史记录 |
| 6 | Native SDK · 录音 | [06-native-sdk-record.png](Screenshot/06-native-sdk-record.png) | 自绘录音页：录音采源、ASR / NLG / TTS 开关、语言设置、录音状态与实时振幅 |
| 7 | 我的 | [07-mine.png](Screenshot/07-mine.png) | 用户信息、设备管理、修改昵称、上传诊断日志、灌流调试、退出登录 |

> 第 2~5 张为涂鸦小程序面板（UI 业务包形态），第 6 张为 Native SDK 自绘界面形态。

## AI 接入

在通过 **Cursor**、**Claude Code** 等 AI 助手接入涂鸦 AI 音频 iOS 业务包时，请使用本仓库内的配套 Skill：[**`aivoice-integration/SKILL.md`**](aivoice-integration/SKILL.md)（Skill 标识：`tuya-aivoice-ios-integration`）。其中包含快速决策树、依赖与配置文件分步说明、SDK 初始化、登录、家庭与设备、配网及小程序/面板路由等，与本 README 及 Demo 工程一致。

**如何使用**

- **Cursor**：将 Skill 配置到用户级或项目级 skills 后在本仓库中提问，或在集成相关对话中附带/打开 [`aivoice-integration/SKILL.md`](aivoice-integration/SKILL.md)。
- **建议**：深度接入前请先让助手阅读该文件，并与源码中 `MARK: AIVoice` 注释对照。

## 开发者必读：MARK: AIVoice 注释

1. 项目中与接入、配置、业务逻辑强相关的**注意事项**已在源码中用 **`MARK: AIVoice`** 标出。
**请务必在集成时，在工程内搜索 `MARK: AIVoice`，逐条阅读对应注释**，避免漏配或误用。

2. 请确保 `ios_core_sdk/` 中包含本地 `ThingSmartCryption` 安全组件，并且工程包含 `thing_custom_config.json`。`ios_core_sdk/` 已被 Git 忽略，需要开发者从涂鸦开发者平台获取后放入本地目录。

## 环境与依赖

| 项目 | 要求 |
|------|------|
| Xcode | 15 及以上 |
| iOS 部署版本 | iOS 13.0+ |
| 依赖管理 | CocoaPods（`use_frameworks! :linkage => :static`、`use_modular_headers!`） |
| 涂鸦业务包版本 | 7.8.x |

Demo 直接声明的涂鸦依赖（详见 [Podfile](Podfile)）：

| Pod | 用途 | 是否必需 |
|-----|------|---------|
| `ThingSmartCryption` | 本地安全组件，从开发者平台获取后放入 `ios_core_sdk/` | 必需 |
| `ThingSmartAIVoiceBizBundle` | AI 音频 UI 业务包（同时提供 `ThingAudioRecordInterface` 原生接口） | 必需 |
| `ThingSmartHomeKit` | 家庭、设备、用户等基础能力 | 必需 |
| `ThingSmartMiniAppBizBundle` / `ThingSmartBaseKitBizBundle` / `ThingSmartBizKitBizBundle` | 小程序容器与基础业务包 | 必需 |
| `ThingSmartFamilyBizBundle` | 家庭管理 UI 业务包 | 可选 |
| `ThingSmartActivatorBizBundle` | 设备配网 UI 业务包 | 无配网需求可不加 |
| `ThingSmartBusinessExtensionKit` / `ThingSmartBusinessExtensionKitBLEExtra` | 自定义 BLE 单点配网所需（显式声明，避免依赖 UI 业务包的传递依赖） | 仅自定义配网需要 |
| `ThingSmartPanelBizBundle` | 设备面板 UI 业务包 | 无设备控制需求可不加 |
| `ThingSmartDeviceDetailBizBundle` | 设备详情 UI 业务包 | 可选 |
| `ThingSmartOTABizBundle` | 设备 OTA 升级 UI 业务包（Podfile 中默认注释） | 可选 |
| `ThingPerfusionKit` | 灌流调试组件，本地路径依赖 `../Modules/ThingPerfusionKit`（**不在本仓库内**） | 仅灌流调试需要 |

## 快速开始

1. 克隆本仓库。
2. 从涂鸦开发者平台下载安全组件，将 `ThingSmartCryption` 相关文件放入 `ios_core_sdk/` 目录（该目录已被 Git 忽略）。
3. 在 [`tuya-aivoice-ios-sdk-sample-objc/AppKey.h`](tuya-aivoice-ios-sdk-sample-objc/AppKey.h) 中填入 `APP_KEY` 与 `APP_SECRET_KEY`。
4. 在 [`tuya-aivoice-ios-sdk-sample-objc/thing_custom_config.json`](tuya-aivoice-ios-sdk-sample-objc/thing_custom_config.json) 中填入 `appId` 与 `thingAppKey`。
5. 执行 `pod install`，然后打开 `tuya-aivoice-ios-sdk-sample-objc.xcworkspace` 运行。

> Bundle Identifier、`appScheme` 需要与涂鸦开发者平台上申请 AppKey 时填写的信息保持一致，否则 SDK 初始化会失败。

### 关于 thing_custom_config 的简介

```json
{
    "config":
    {
        "appId":"",
        "thingAppKey":"",
        "appScheme":"AIVoiceDemo",
        "needBle":true,
        "is_support_home_manager":true,
        "need_backgroud_audio":true,
        "needQRCode": true,
        "device_detail_mini_program": true,
        "hotspotPrefixs": ["AAA", "BBB"],
        "support_ble_gpt": true
    },
    "colors": {
        "themeColor": "#FFA228"
    },
    "blackColors": {
        "themeColor": "#FF5A28",
        "backgroundColor": "#000000",
        "warningColor": "#FF4444",
        "tipsColor": "#2DDA86",
        "guideColor": "#1989FA",
        "navigationBarColor": "#1A1A1A",
        "tabBarSelectedColor": "#FF5A28",
        "alertMaskAlpha": 0.7
    }
}
```

**参数简介**

| 参数 | 说明 | 类型 | 必选 | 默认值 |
|------|------|------|------|--------|
| appId | 应用 ID，在涂鸦开发者平台进入您的应用/SDK管理页面。应用页面 URL 中的 ID 参数即为 appId，例如链接为 https://platform.tuya.com/oem/app?id=888888，则 appId 为 888888 | Number | 是 | 无 |
| thingAppKey | 涂鸦开发者平台 中对应 SDK 中的 AppKey | String | 是 | 无 |
| appScheme | 涂鸦开发者平台 中对应 SDK 中的 渠道标识符 | String | 是 | 无 |
| hotspotPrefixs | 配网设备热点前缀 | Array | 否 | ["SmartLife"] |
| needBle | 是否需要支持蓝牙设备配网 | Boolean | 否 | true |
| support_ble_gpt | 是否启用 BLE GPT 相关能力 | Boolean | 否 | true |
| themeColor | UI 主题色设置 | String | 否 | #FF5A28 |

### 权限与后台模式

Demo 已在工程 Build Settings（`INFOPLIST_KEY_*`）与 [`Info.plist`](tuya-aivoice-ios-sdk-sample-objc/Info.plist) 中声明以下内容，集成时请按自身业务保留：

| 键 | 用途 |
|----|------|
| `NSMicrophoneUsageDescription` | 录音（Native SDK 与小程序面板均需要） |
| `NSBluetoothAlwaysUsageDescription` | 蓝牙设备发现与配网 |
| `NSBluetoothPeripheralUsageDescription` | 兼容 iOS 12 及以下的蓝牙权限 |
| `NSCameraUsageDescription` | 扫码添加设备 |
| `NSLocationWhenInUseUsageDescription` | 创建家庭时获取位置 |
| `NSPhotoLibraryUsageDescription` | 相册访问 |
| `UIBackgroundModes: audio` | 后台录音，需与 `need_backgroud_audio` 配置一起使用 |

---

## Tuya 架构介绍

涂鸦 iOS 业务包以服务化的方式开放，一切功能接入皆以协议（Protocol）的方式提供。
![IOS架构](https://images.tuyacn.com/fe-static/docs/img/e228361e-71a3-4bd2-a123-e597a0d287d1.png)

在接入 Tuya SDK 之前，你必须先要理解的一些概念。

### 家庭

家庭是全屋智能场景的抽象概念，表示以「家/场所」为单位的设备、账号、权限等信息的集合。
主要能力：查询家庭列表、获取家庭下设备/群组、添加/修改/删除家庭、房间与成员管理等。

| 类/协议 | 说明 |
|--------|------|
| `ThingSmartHomeManager` | 查询家庭列表、家庭排序、添加家庭 |
| `ThingSmartHome` | 单个家庭管理（需用 `homeId` 初始化） |
| `ThingSmartHomeDelegate` | 家庭下信息变更（设备增删、房间、dps 等） |

获取家庭下设备/群组前，必须先初始化 `ThingSmartHome` 并调用 **查询家庭详情**，`homeModel`、`roomList`、`deviceList`、`groupList` 等才会有数据, 最后再设置一下当前的家庭，在当前类中实现需要实现 `<ThingFamilyProtocol>`。

```objc
// 1. 查询家庭列表（仅简单信息）
[self.homeManager getHomeListWithSuccess:^(NSArray<ThingSmartHomeModel *> *homes) {
    // 若无家庭，需先 addHomeWithName:geoName:rooms:latitude:longitude:success:failure: 创建
} failure:^(NSError *error) { }];

// 2. 初始化当前家庭并拉取详情（必须调用后才有 deviceList）
self.home = [ThingSmartHome homeWithHomeId:homeId];
[self.home getHomeDataWithSuccess:^(ThingSmartHomeModel *homeModel) {
    // 此后 self.home.deviceList / groupList / roomList 等才有数据

    // 3. 设置一下当前家庭
    [[ThingSmartBizCore sharedInstance] registerService:@protocol(ThingFamilyProtocol) withInstance:self];
    id<ThingFamilyProtocol> impl = [[ThingSmartBizCore sharedInstance] serviceOfProtocol:@protocol(ThingFamilyProtocol)];
    if ([impl respondsToSelector:@selector(updateCurrentFamilyId:)]) {
        [impl updateCurrentFamilyId:homeId];
    }
} failure:^(NSError *error) { }];

```

- 文档：[家庭管理](https://developer.tuya.com/cn/docs/app-development/home?id=Ka5d52ey6e58h)、[家庭信息管理](https://developer.tuya.com/cn/docs/app-development/iOS_family?id=Kaixeor409hck)

### 设备

设备完成配网后，挂在某个家庭下。进行设备操作前，需确保已通过该家庭拉取过家庭详情（见上文），才能正确拿到设备列表并初始化设备实例。

| 类 | 说明 |
|----|------|
| `ThingSmartDevice` | 设备控制与管理（重命名、移除、下发 DP 等） |
| `ThingSmartDeviceModel` | 设备数据模型（devId、name、dps、在线状态等） |

```objc
// 设备列表来自已拉取详情的 home（先 getHomeDataWithSuccess 再使用）
NSArray *deviceList = [self.home.deviceList copy];

// 按 devId 初始化设备控制类（当前用户须拥有该设备，且已同步家庭详情）
ThingSmartDevice *device = [ThingSmartDevice deviceWithDeviceId:devId];
device.delegate = self;  // 监听 dps 变更、设备信息更新、移除等

// 跳转设备面板页,这样就可以跳转到小程序面板了
ThingSmartDevice *smartDevice = [ThingSmartDevice deviceWithDeviceId:device.devId];
id<ThingPanelProtocol> impl = [[ThingSmartBizCore sharedInstance] serviceOfProtocol:@protocol(ThingPanelProtocol)];
if (impl) {
    [impl gotoPanelViewControllerWithDevice:smartDevice.deviceModel group:nil initialProps:nil contextProps:nil completion:nil];
}
```

- 文档：[设备管理](https://developer.tuya.com/cn/docs/app-development/device?id=Ka5cgmmjr46cp)

### 家庭与设备的关系

**设备是基于家庭的**：所有设备都归属于某个家庭。用户在使用设备相关能力（查看设备列表、控制设备等）前，**必须先拥有至少一个家庭**；若当前没有家庭，需要先创建家庭，**设置当前家庭**并**获取家庭详情信息**后，才能正常拉取和操作设备。

---

## 注意事项简要说明

### 1. 准备工作

- **位置**：`thing_custom_config.json` &  `AppKey.h`
- **说明**: 请确保在Tuya IOT平台申请了AppKey、APPSecretKEY、APPID 并写入配置文件中
- **文档**：[集成APP SDK准备工作](https://developer.tuya.com/cn/docs/app-development/preparation?id=Ka69nt983bhh5)

### 2. SDK 初始化（AppDelegate.m）

- **位置**：`application:didFinishLaunchingWithOptions:`
- **说明**：涂鸦 SDK 需在应用启动时完成初始化（`startWithAppKey:secretKey:`）。除此之外还需要初始化小程序容器（`[[ThingMiniAppClient initialClient] initialize]`），并把 `application:didFinishLaunchingWithOptions:` 转交给 `ThingModuleManager`，业务包才能正常注册服务。
- **文档**：[集成 SDK](https://developer.tuya.com/cn/docs/app-development/integrate-sdk?id=Ka5d52ewngdoi)

### 3. 小程序路由（MiniAppRoutes.h）

- **说明**：Demo 中小程序快捷入口的 URL 和 AppID 集中在 `MiniAppRoutes.h` 中以常量形式定义（如 AI 笔记的录音、同声传译、实时转写，AI 翻译的同声传译、对话翻译）。
- **注意**：若你使用不同小程序或不同路径，请在此文件中修改对应常量，保证与涂鸦平台上的小程序配置一致，避免跳转失败。

### 4. 登录注册服务（AuthService.m）

- **说明**：登录、注册、验证码、重置密码等示例均在此服务类中，同时覆盖手机号与邮箱两条链路：
  - 验证码：`getWhiteListWhoCanSendMobileCodeSuccess:failure:` 查询可用地区、`sendVerifyCodeWithUserName:...` 发送、`checkCodeWithUserName:...` 校验，类型区分注册 / 登录 / 重置密码。
  - 手机号：密码登录 `loginByPhone:...`、验证码登录 `loginByPhoneWithCode:...`、注册 `registerByPhone:...`、重置密码 `resetPasswordByPhone:...`。
  - 邮箱：对应 `loginByEmail:...`、`loginByEmailWithCode:...`、`registerByEmail:...`、`resetPasswordByEmail:...`。
  - 通用注册 `registerWithCountryCode:account:password:code:...` 会自动识别账号是邮箱还是手机号。
- **国家/地区选择**：`CountryModel` 内置按大区分组的国家列表（中国 / 亚太 / 美洲 / 欧洲 / 中东与非洲），`CountryPickerViewController` 提供带搜索的选择页，并记住上次选择，避免手动输入国家码。
- **Demo 已接入的页面**：登录页只接了密码登录（`loginByPhone:` / `loginByEmail:`），注册页接了验证码 + 密码注册；验证码登录与重置密码接口在 `AuthService` 中已提供，可按需接入 UI。
- **注意**：集成时需按自身业务选择登录方式，并正确处理 token、用户信息与登出逻辑。
- **文档**：[用户与账号](https://developer.tuya.com/cn/docs/app-development/user?id=Ka5cgmm97jlt2)

### 5. 配网服务（ActivatorService.m）

- **说明**：设备配网（Wi-Fi、蓝牙等）的调用示例。
- **注意**：不同设备/品类可能对应不同配网方式，需根据产品选择合适接口并处理超时与错误。
- **文档**：[设备配网](https://developer.tuya.com/cn/docs/app-development/activator?id=Ka5cgmlzpfig4)

#### BLE 单点设备自定义配网

首页右上角的添加入口提供两种配网方式：

- **正常添加**：使用 `ActivatorService` 打开涂鸦配网 UI。
- **自定义添加**：进入 `CustomBLEPairingViewController`，通过 `CustomBLEPairingSession` 调用 BLE 搜索、Token 获取和设备激活接口。

自定义流程为：检查登录状态和当前 `homeId` → 扫描 BLE 设备 → 用户选择设备 → 获取新 Token → 激活设备 → 刷新家庭设备列表。该流程仅面向 BLE 单点设备，每次激活一台设备，不包含 BLE-Wi-Fi 双模、EZ/AP、Mesh、Beacon、Matter 或子设备配网。

相关实现：

- `Services/Pairing/CustomBLEPairingSession.h/.m`：状态机、SDK Adapter、错误映射和取消清理。
- `Views/Activator/CustomBLEPairingViewController.h/.m`：扫描、选择、激活结果和页面日志 UI。
- `tuya-aivoice-ios-sdk-sample-objcTests/CustomBLEPairingSessionTests.m`：使用模拟 Adapter 验证状态迁移和错误处理。

自定义 BLE 配网显式依赖 `ThingSmartBusinessExtensionKit` 和 `ThingSmartBusinessExtensionKitBLEExtra`。真机运行前需要配置 `NSBluetoothAlwaysUsageDescription` 和兼容 iOS 12 的 `NSBluetoothPeripheralUsageDescription`，并准备处于待配网状态且可绑定到当前应用的 BLE 单点设备。配网仅在页面前台执行，离开页面后停止扫描和激活。

### 6. 跳转小程序面板页（MainViewController.m）

- **说明**：点击设备列表中的设备时，若需跳转到涂鸦标准设备面板，可调用 `gotoPanelViewControllerWithDevice` 接口。
- **注意**：如果是需要自定义的面板，在podfile中需要增加 `ThingSmartPanelBizBundle` 的UI业务包
- **文档**：[打开小程序面板](https://developer.tuya.com/cn/docs/app-development/devicecontrol?id=Ka8qf8lnahsf8#title-9-%E6%89%93%E5%BC%80%E9%9D%A2%E6%9D%BF)

### 7. 加载家庭（MainViewController.m - loadHomeList）

- **说明**：涂鸦 SDK 以「家庭」为维度管理设备与权限，因此**至少需要有一个家庭**才能正常使用设备相关能力。
- **注意**：可在注册或首次进入时默认创建一个家庭（Demo 中有示例）；若支持多家庭，需实现家庭列表与切换逻辑。
- **文档**：[家庭管理](https://developer.tuya.com/cn/docs/app-development/home?id=Ka5d52ey6e58h)

### 8. 设置当前家庭（MainViewController.m - initCurrentHome）

- **说明**：创建或选择家庭后，必须**设置当前家庭**（如通过 `updateCurrentFamilyId`），SDK 才会按该家庭拉取设备列表与权限。
- **注意**：若仅有一个家庭，建议在首页或设备列表初始化时调用更新当前家庭，避免设备列表为空或权限异常。

### 9. Native SDK 录音链路（NativeSDKViewController.m / NativeAudioService.m）

- **入口**：底部「SDK」Tab。
- **说明**：不使用小程序面板时，可通过 `ThingAudioRecordInterface`（随 `ThingSmartAIVoiceBizBundle` 一起引入）自行实现录音界面。Demo 用 `NativeAudioService` 统一封装了 `ThingAudioDetectManagerNative`，并保证所有回调切回主线程。
- **能力**：
  - 录音来源：手机麦克风（`ThingSystemMic16KMono`）或当前家庭下已配网的音频设备。
  - 处理能力开关：ASR 识别、NLG 翻译、TTS 播报。
  - 语种：源语言与目标语言各支持 14 种常用语种（中/英/日/韩/法/德/西/俄/意/葡/泰/越/阿/印地）。
  - 录音控制：开始、暂停、恢复、结束，配合实时振幅波形、录音状态与时长展示。
  - 实时结果：实时 ASR 文本、实时翻译文本、SDK 事件日志。
- **注意**：录音监听器 `addRecordListener:deviceId:` 与 `removeRecordListener:deviceId:` 必须使用同一实例和同一 `deviceId` 成对调用，否则会造成回调泄漏。

### 10. 录音列表与详情（NativeRecordListViewController.m / NativeRecordDetailViewController.m）

- **入口**：SDK Tab 顶部「录音列表」卡片。
- **列表页**：展示全部已入库录音（按 `recordTime` 降序），支持标题、标签、转写内容的混合搜索。
- **详情页**：展示转写、总结、翻译内容与音频播放、振幅曲线，并可对该条录音重新发起离线任务（`taskType`：0 转写、1 总结、2 翻译）。
- **说明**：详情内容通过 `fetchTranscriptionWithFileId:`、`fetchSummaryWithFileId:`、`fetchTranscriptionSentencesWithFileId:` 获取，其中分句接口带时间戳，便于按句展示与定位播放。

### 11. 灌流调试与测试报告（ThingPerfusionKit）

- **入口**：我的 → 灌流调试。
- **组件化**：灌流能力已从 Demo 主工程抽成独立本地组件 `ThingPerfusionKit`，在 Podfile 中以本地路径引入：

  ```ruby
  pod 'ThingPerfusionKit', :path => '../Modules/ThingPerfusionKit'
  ```

  | 子模块 | 内容 | 依赖 |
  |--------|------|------|
  | `Core` | 灌流配置提供者、WAV 格式校验、WER 计算、报告生成（无 UI 依赖） | `ThingAudioRecordInterface`、`ThingModuleManager`、`ThingAnnotationFoundation` |
  | `UI` | 开箱可用的灌流调试页（自带页面基类） | `Core` + UIKit / AVFAudio |

  三个依赖都是 AI 语音业务包的既有传递依赖，不需要新增任何 pod。只要能力、不要页面时可以只集成 `ThingPerfusionKit/Core`。

  > ⚠️ `../Modules/ThingPerfusionKit` 位于本仓库之外。只克隆本仓库时该路径不存在，`pod install` 会失败——需要一并获取该模块，或先注释掉这一行（灌流入口随之不可用）。

- **原理**：灌流是把**本地音频文件替换麦克风采集数据**喂给录音链路的调试手段，用于在不出声的前提下复现并回归 ASR / 翻译 / TTS 全流程。底层 `ThingMicrophoneAudioInput` 启动音频输入时，通过 `ThingAIBudsDebuggerProtocol` 向 App 侧回读灌流开关、文件名和自动收尾三项配置。
- **无需启动注册**：组件通过 `ThingRegisterAPIAnnotation` 在编译期把配置提供者写入 Mach-O 的 `_ThingMOV3_` 段，App 启动后由 `ThingMachRegister` 收集，不必在 `AppDelegate` 里写注册代码。`registerProvider` / `isProviderReady` / `configFetchCount` 仅用于自检和排查。
- **主要接口**：
  - `ThingPerfusionViewController`：现成的灌流调试页，直接 push 即可。
  - `ThingPerfusionService`：灌流开关、文件名、自动收尾、结束回调与灌流/参考答案文件管理。
  - `ThingPerfusionWERCalculator`：独立可用的 WER 评估，不依赖灌流。
  - `ThingPerfusionReportBuilder`：HTML 测试报告生成。
  - `ThingPerfusionAudioFileInfo`：WAV 格式解析与校验。
- **目录约定**（均位于 App 沙盒 Documents 下，组件已封装）：
  - 灌流音频：`voiceRecord/automaticTest/audioFiles`
  - 参考答案：`voiceRecord/automaticTest/references`（`.txt`）
  - 测试报告：`voiceRecord/automaticTest/reports`（`.html`）
- **音频格式要求（最容易踩的坑）**：底层把文件内容当作 **16kHz / 16bit / 单声道的整型 PCM** 直接替换采集流，**只支持整型 PCM 的 WAV**（WAV 的 `audioFormat` 字段为 1；3 是 IEEE float，不支持）。格式不符的典型表现是「灌流在跑，但一条 ASR 都没有」。转换命令：

  ```bash
  afconvert -f WAVE -d LEI16@16000 -c 1 输入.wav 输出.wav
  ```

  组件内建校验，页面按三级处理：完全符合直接开始；PCM 但采样率/声道/位深不符时警告并可强行开始；非 PCM 或非 WAV 时直接拦截并给出转换命令。
- **WER 口径**：`WER = (S + D + I) / N`，准确率 = 1 − WER。文本先归一化（小写、标点转空格而非删除、中文逐字切分、剔除语气词、千分位还原、数词归一化），再用编辑距离对齐求 S/D/I。与团队现有 `ASR_WER/WER.py` 已用真实数据逐项对拍验证一致。
- **报告内容**：概览 KPI（准确率 / WER / 参考词数 / 错误合计 / 耗时）、错误构成、测试条件、逐句对比、全文逐词对比（替换标红、插入标黄、删除标绿）、归一化后文本、计算方式说明。单文件 HTML，支持深色模式。
- **注意**：逐句对比不会把一个识别分段拆给多个参考行，当 ASR 把多行参考合并成一段输出时会有参考行被判为漏识，报告会给出告警；**全文 WER 不受影响，以全文口径为准**。用完调用 `reset` 关闭灌流，避免影响后续正常录音。

### 12. 设备管理

- **入口**：我的 → 设备管理。
- **实现**：`DeviceManagementViewController` 与 `DeviceService`。
- **能力**：刷新当前家庭的设备列表、展示在线状态、修改设备名称、将设备从当前家庭移除。

### 13. 个人设置

- **入口**：底部「我的」页面。
- **能力**：展示当前用户信息、修改昵称、进入设备管理、打开诊断日志入口、进入灌流调试和退出登录。
- **说明**：页面使用 Demo 自定义 UI 组件（`FamilyBaseViewController` 提供统一导航、卡片与弹窗样式）实现，交互结果仍以涂鸦 SDK 返回为准。

### 14. 诊断日志入口

- **入口**：我的 → 上传诊断日志。
- **实现**：通过 `ThingFeedBackProtocol` 打开涂鸦反馈页面，由用户确认问题描述和需要提交的信息。
- **注意**：当前构建未加载反馈模块或协议服务不可用时，Demo 会显示"日志服务不可用"，不会在仓库中生成日志文件。

---

## 工程目录结构

```
tuya-aivoice-ios-sdk-sample-objc/
├── AppDelegate.m/.h           # SDK 初始化（MARK: AIVoice）
├── SceneDelegate.m/.h         # 根视图切换（登录页 / 主 TabBar）
├── AppKey.h                   # AppKey / SecretKey
├── thing_custom_config.json   # 业务包配置
├── MiniAppRoutes.h            # 小程序 AppID 与快捷入口 URL（MARK: AIVoice）
├── LoginViewController.m/.h   # 登录页
├── Models/
│   └── CountryModel.m/.h      # 国家/地区数据
├── Services/
│   ├── AuthService.m/.h       # 登录注册（MARK: AIVoice）
│   ├── ActivatorService.m/.h  # 配网（MARK: AIVoice）
│   ├── DeviceService.m/.h     # 设备管理
│   ├── NativeAudioService.m/.h        # Native 录音 SDK 封装
│   └── Pairing/
│       └── CustomBLEPairingSession.m/.h  # 自定义 BLE 配网状态机
├── Views/
│   ├── Main/                  # 首页与 TabBar
│   ├── Auth/                  # 注册页、国家选择器
│   ├── NativeSDK/             # 录音、录音列表、录音详情
│   ├── Device/                # 设备列表与设备管理
│   ├── Activator/             # 自定义 BLE 配网页
│   ├── Mine/                  # 我的
│   └── Common/                # FamilyBaseViewController 通用 UI 基类
└── Utils/
    └── UIHelper.m/.h
```

灌流调试相关代码不在本仓库内，位于同级目录的独立组件：

```
../Modules/ThingPerfusionKit/
├── ThingPerfusionKit.podspec
├── README.md
└── ThingPerfusionKit/Classes/
    ├── Core/    # ThingPerfusionService / WERCalculator / ReportBuilder / AudioFileInfo / RecordBridge
    └── UI/      # ThingPerfusionViewController / ThingPerfusionBaseViewController
```
