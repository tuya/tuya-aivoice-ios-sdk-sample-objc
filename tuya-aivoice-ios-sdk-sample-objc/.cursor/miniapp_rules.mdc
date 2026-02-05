MiniApp SDK 是提供开发、部署、产品体验分析、上线全流程各种需求的解决方案。接入此 SDK，您就可以只关注于代码开发本身，剩余的所有事情都可以交由 SDK 及其依赖方解决。另外，能够有效降低多端开发的技术门槛和研发成本，提升开发效率和开发体验。

- 基于该框架运行的小程序，可快速迭代开发，实现发布即上线，拥有持续部署、持续交付的能力。
- 基于该框架运行的小程序，可实现接近 iOS 和 Android 原生界面的交互体验，为用户提供高性能、UI 一致性的体验。
- 该框架采用双线程架构，分为逻辑层和视图层。
- 逻辑层采用 QuickJS、JavaScriptCore 和 V8 JavaScript Engine 运行 JavaScript 脚本，用来处理业务逻辑。
- 视图层采用 WebView 渲染 HTML，进行页面展示。双线程分离和通信机制让小程序具有更高效安全的环境。


## 头文件依赖

```
#import <ThingSmartMiniAppBizBundle/ThingSmartMiniAppBizBundle.h>
```

## 打开小程序

``` objective-c
// 通过小程序 ID 打开小程序
[[ThingMiniAppClient coreClient] openMiniAppByAppId:@"tydhopggfziofo1h9h"];

// 通过 URL 打开小程序
[[ThingMiniAppClient coreClient] openMiniAppByUrl:@"godzilla://tydhopggfziofo1h9h/" params:@{}];

// 通过二维码打开小程序
[[ThingMiniAppClient coreClient] openMiniAppByQrcode:@"qrcodeString" params:@{}];

```

## SDK 初始化、

在使用小程序的 API 之前，您需要先初始化 MiniApp SDK，在 App 启动时调用初始化 API，用以保证小程序框架的正常运行。

``` objective-c
/// 初始化 SDK
- (void)initialize;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // App 启动时初始化
    [[ThingMiniAppClient initialClient] initialize];
    return [[ThingModuleManager sharedInstance] application:application didFinishLaunchingWithOptions:launchOptions];
}

```

## 打开小程序

小程序管理主要介绍操作小程序的 API，包括但不限于：

打开小程序
预加载小程序
清理小程序缓存等
针对不同的业务场景，打开小程序所需的 API 也不尽相同。所以涂鸦提供了不同 API 以应对不同的场景。

打开线上小程序：线上小程序的打开一般只需要小程序 ID 即可。
二维码打开小程序：适用于扫码涂鸦开发者平台二维码，传入二维码数据打开小程序。这种方式可以打开正式版、开发版、体验版、IDE 调试版小程序。
URL 形式打开小程序：适用于打开小程序时，需要指定具体页面路径时，仅支持线上版本小程序。

### 方式一：通过 AppID

在打开小程序时，会优先判断本地是否存在缓存：

如果存在缓存，则直接加载缓存在本地的小程序，同时后台线程更新小程序版本。
如果小程序没有缓存，则会先触发小程序下载，下载成功后再打开小程序。

``` objective-c
/// 通过小程序 ID 打开小程序
/// - Parameter appId：小程序 ID，可在涂鸦开发者平台查看
- (void)openMiniAppByAppId:(nonnull NSString *)appId;

/// 通过小程序 ID 打开小程序
/// - Parameters：
///   - appId：小程序 ID，可在涂鸦开发者平台查看
///   - params：额外传入的业务参数，小程序可在 Page.onLoad 中获取
- (void)openMiniAppByAppId:(nonnull NSString *)appId params:(nullable NSDictionary *)params;

/// 通过小程序 ID 打开小程序
/// - Parameters：
///   - appId：小程序 ID，可在涂鸦开发者平台查看
///   - appVersion：小程序版本号，需要指定具体版本时可传
///   - params：额外传入的业务参数，小程序可在 Page.onLoad 中获取
- (void)openMiniAppByAppId:(nonnull NSString *)appId appVersion:(nullable NSString *)appVersion params:(nullable NSDictionary *)params;

```

### 通过URL
URL 方式能更有针对性地打开小程序的指定页面。


AI笔记(appID: tyylldwlb8411tg8u2)
主页：thingSmart://miniApp?url=godzilla%3A%2F%2Ftyylldwlb8411tg8u2%2Fpages%2Fhome%2Findex
录音：thingSmart://miniApp?url=godzilla%3A%2F%2Ftyylldwlb8411tg8u2%2Fpages%2Fhome%2Findex%3FmodeKey%3DliveRecording
同声传译：thingSmart://miniApp?url=godzilla%3A%2F%2Ftyylldwlb8411tg8u2%2Fpages%2Fhome%2Findex%3FmodeKey%3DsimultaneousInterpretation
实时转写：thingSmart://miniApp?url=godzilla%3A%2F%2Ftyylldwlb8411tg8u2%2Fpages%2Fhome%2Findex%3FmodeKey%3DrealTimeRecording

AI翻译(appID: ty0u9m1s5ea1k71m2h)
主页：thingSmart://miniApp?url=godzilla%3A%2F%2Fty0u9m1s5ea1k71m2h%2Fpages%2Fhome%2Findex
同声传译：thingSmart://miniApp?url=godzilla%3A%2F%2Fty0u9m1s5ea1k71m2h%2Fpages%2Fsimultaneous%2Findex
对话翻译：thingSmart://miniApp?url=godzilla%3A%2F%2Fty0u9m1s5ea1k71m2h%2Fpages%2FFaceToFace%2Findex


``` objective-c
/// 通过 URL 形式打开小程序
/// - Parameter url：小程序对应的具体 URL 链接
- (void)openMiniAppByUrl:(nonnull NSString *)url;

/// 通过 URL 形式打开小程序
/// - Parameters：
///   - url：小程序对应的具体 URL 链接
///   - params：额外传入的业务参数，小程序可在 Page.onLoad 中获取
- (void)openMiniAppByUrl:(nonnull NSString *)url params:(nullable NSDictionary *)params;

// 打开指定页面
[[ThingMiniAppClient coreClient] openMiniAppByUrl:@"godzilla://tydhopggfziofo1h9h/pages/home/index"];

// 携带业务参数
[[ThingMiniAppClient coreClient] openMiniAppByUrl:@"godzilla://tydhopggfziofo1h9h/" params:@{@"key":@"value"}];

```
## 删除小程序

小程序在使用后，SDK 会将小程序包和其对应信息存储到本地。存储到本地的信息会占用设备空间，如果想要清理小程序及其缓存，则需要调用以下 API。

``` objective-c
/// 清理所有小程序缓存
- (void)clearCache;

[[ThingMiniAppClient coreClient] clearCache];
```

## 预下载小程序

提前把小程序下载到本地，可以加快小程序的启动时间。

```
/// 预下载小程序，仅支持正式版本小程序
/// - Parameter appId：小程序 ID，可在涂鸦开发者平台查看
- (void)preloadMiniApp:(nonnull NSString *)appId;

[[ThingMiniAppClient coreClient] preloadMiniApp:@"tydhopggfziofo1h9h"];
```

## vConsole 调试

小程序在运行过程中，可能会遇到各种问题，为了更好地定位问题，涂鸦提供了调试开关，开启调试开关后，可以在 vConsole 看到小程序运行中的日志。

调试开关最好仅在开发阶段打开，线上环境请关闭调试开关。

```
/// vConsole 调试开关
/// - Parameter enable：是否打开调试开关
- (void)vConsoleDebugEnable:(BOOL)enable;

// 开启 vConsole 调试开关
[[ThingMiniAppClient debugClient] vConsoleDebugEnable:YES];
```

