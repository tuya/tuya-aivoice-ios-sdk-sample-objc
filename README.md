
## 项目介绍

AI 音频 UI 业务包是针对普通蓝牙耳机、眼镜、音箱等音频类产品直接升级为 AI 产品，即可使用 AI 记录和翻译功能，专业录音算法配合先进的语言模型，覆盖全球 100+ 种语言的实时精准转写和实时翻译。

在接入该业务包之前请先完成 [准备工作](https://developer.tuya.com/cn/docs/app-development/preparation?id=Ka8j28bikfqkf) 和 [框架接入](https://developer.tuya.com/cn/docs/app-development/framework?id=Ka8j2895qdvtj)。

AI 音频业务包 Demo 地址: [tuya-aivoice-ios-sdk-sample-objc](https://github.com/tuya/tuya-aivoice-ios-sdk-sample-objc)。


## 开发者必读：MARK: AIVoice 注释

项目中与接入、配置、业务逻辑强相关的**注意事项**已在源码中用 **`MARK: AIVoice`** 标出。  
**请务必在集成时，在工程内搜索 `MARK: AIVoice`，逐条阅读对应注释**，避免漏配或误用。

下面是对这些注意点的简要归纳与说明，便于你快速建立整体认知；具体实现细节和链接以代码内注释为准。

---

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

### 6. 跳转设备详情页（MainViewController.m）

- **说明**：点击设备列表中的设备时，若需跳转到涂鸦标准设备面板，可调用 `gotoDeviceDetailDetailViewControllerWithDevice` 等接口。  
- **注意**：**必须先集成包含设备详情的 UI 业务包，并完成小程序/业务包初始化**，否则跳转可能失败或不可用。Demo 中此处仅作示例，实际需按你集成的业务包文档配置。

### 7. 加载家庭（MainViewController.m - loadHomeList）

- **说明**：涂鸦 SDK 以「家庭」为维度管理设备与权限，因此**至少需要有一个家庭**才能正常使用设备相关能力。  
- **注意**：可在注册或首次进入时默认创建一个家庭（Demo 中有示例）；若支持多家庭，需实现家庭列表与切换逻辑。  
- **文档**：[家庭管理](https://developer.tuya.com/cn/docs/app-development/home?id=Ka5d52ey6e58h)

### 8. 设置当前家庭（MainViewController.m - initCurrentHome）

- **说明**：创建或选择家庭后，必须**设置当前家庭**（如通过 `updateCurrentFamilyId`），SDK 才会按该家庭拉取设备列表与权限。  
- **注意**：若仅有一个家庭，建议在首页或设备列表初始化时调用更新当前家庭，避免设备列表为空或权限异常。

