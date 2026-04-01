## 项目介绍

AI 音频 UI 业务包是针对普通蓝牙耳机、眼镜、音箱等音频类产品直接升级为 AI 产品，即可使用 AI 记录和翻译功能，专业录音算法配合先进的语言模型，覆盖全球 100+ 种语言的实时精准转写和实时翻译。

在接入该业务包之前请先完成 [准备工作](https://developer.tuya.com/cn/docs/app-development/preparation?id=Ka8j28bikfqkf) 和 [框架接入](https://developer.tuya.com/cn/docs/app-development/framework?id=Ka8j2895qdvtj)。

AI 音频业务包 Demo 地址: [tuya-aivoice-ios-sdk-sample-objc](https://github.com/tuya/tuya-aivoice-ios-sdk-sample-objc)。


## AI接入
在通过 **Cursor**、**Claude Code** 等 AI 助手接入涂鸦 AI 音频 iOS 业务包时，请使用本仓库内的配套 Skill：[**`aivoice-integration/SKILL.md`**](aivoice-integration/SKILL.md)（Skill 标识：`tuya-aivoice-ios-integration`）。其中包含快速决策树、依赖与配置文件分步说明、SDK 初始化、登录、家庭与设备、配网及小程序/面板路由等，与本 README 及 Demo 工程一致。

**如何使用**

- **Cursor**：将 Skill 配置到用户级或项目级 skills 后在本仓库中提问，或在集成相关对话中附带/打开 [`aivoice-integration/SKILL.md`](aivoice-integration/SKILL.md)。
- **建议**：深度接入前请先让助手阅读该文件，并与源码中 `MARK: AIVoice` 注释对照。

**English:** [README.md](README.md)

## 开发者必读：MARK: AIVoice 注释

1. 项目中与接入、配置、业务逻辑强相关的**注意事项**已在源码中用 **`MARK: AIVoice`** 标出。  
**请务必在集成时，在工程内搜索 `MARK: AIVoice`，逐条阅读对应注释**，避免漏配或误用。

2. 请确保项目工程包含了 `ThingSmartCryption.xcframework` 和 `thing_custom_config.json`

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
        "support_ble_gpt": true,
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
| themeColor | UI 主题色设置 | String | 否 | #FF5A28 |

![Demo-Screenshot](https://github.com/tuya/tuya-aivoice-ios-sdk-sample-objc/blob/master/Screenshot/Demo-Screenshot.jpg)

下面是对这些注意点的简要归纳与说明，便于你快速建立整体认知；具体实现细节和链接以代码内注释为准。

---

## Tuya架构介绍

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


## 注意事项简要说明

### 1. 准备工作

- **位置**：`thing_custom_config.json` &  `AppKey.h`
- **说明**: 请确保在Tuya IOT平台申请了AppKey、APPSecretKEY、APPID 并写入配置文件中
- **文档**：[集成APP SDK准备工作](https://developer.tuya.com/cn/docs/app-development/preparation?id=Ka69nt983bhh5)


### 2. SDK 初始化（AppDelegate.m）

- **位置**：`application:didFinishLaunchingWithOptions:` 
- **说明**：涂鸦 SDK 需在应用启动时完成初始化（如 `startWithAppKey:secretKey:` 等）。密钥、环境、调试开关等应在此阶段按文档配置。  
- **文档**：[集成 SDK](https://developer.tuya.com/cn/docs/app-development/integrate-sdk?id=Ka5d52ewngdoi)

### 3. 小程序路由（MiniAppRoutes.h）

- **说明**：Demo 中小程序快捷入口的 URL 和 AppID 集中在 `MiniAppRoutes.h` 中以常量形式定义（如 AI 笔记、AI 翻译的录音、同声传译、实时转写、对话翻译等）。  
- **注意**：若你使用不同小程序或不同路径，请在此文件中修改对应常量，保证与涂鸦平台上的小程序配置一致，避免跳转失败。

### 4. 登录注册服务（AuthService.m）

- **说明**：登录、注册、验证码、第三方登录等示例均在此服务类中。  
- **注意**：集成时需按自身业务选择登录方式，并正确处理 token、用户信息与登出逻辑。  
- **文档**：[用户与账号](https://developer.tuya.com/cn/docs/app-development/user?id=Ka5cgmm97jlt2)

### 5. 配网服务（ActivatorService.m）

- **说明**：设备配网（Wi-Fi、蓝牙等）的调用示例。  
- **注意**：不同设备/品类可能对应不同配网方式，需根据产品选择合适接口并处理超时与错误。  
- **文档**：[设备配网](https://developer.tuya.com/cn/docs/app-development/activator?id=Ka5cgmlzpfig4)

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

