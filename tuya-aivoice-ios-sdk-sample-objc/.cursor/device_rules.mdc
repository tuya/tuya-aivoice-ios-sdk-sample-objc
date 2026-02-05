---
alwaysApply: false
---

# 设备控制

本章节主要操作对象包含 ThingSmartDeviceModel 和 ThingSmartDevice。


## 查询设备列表

设备成功配网后，您可以在对应的家庭下查看对应的设备列表。

```
self.home = [ThingSmartHome homeWithHomeId:#your homeId];
self.deviceList = [self.home.deviceList copy];
```

您必须先调用 获取家庭详细信息 接口。否则即使配网成功也无法成功获取。

## 查看设备信息

设备的功能点信息存放在 deviceModel 的 schemaArray 中。

```
ThingSmartDevice *device = self.device;
NSArray *schemas = device.deviceModel.schemaArray;
```

## 设备详情

https://developer.tuya.com/cn/docs/app-development/devicedetail?id=Ka8qf8llmk83u

设备详情 UI 业务包涉及到设备图标上传时，需要使用系统相册和相机权限。因此，会涉及到部分苹果隐私权限的声明。

您需要在工程的 info.plist 中添加如下权限声明：
<!-- 相册 -->
<key>NSPhotoLibraryUsageDescription</key>
<string>App 需要您的同意，才能访问相册</string>
<!-- 相机 -->
<key>NSCameraUsageDescription</key>
<string>App 需要您的同意，才能访问相机</string>

如果接入了蓝牙设备，使用创建群组或者移除设备等依赖蓝牙能力的业务，需要在info.plist 中添加如下权限声明：
<!-- 蓝牙 -->
<key>NSBluetoothAlwaysUsageDescription</key>
<string>这将允许应用程序找到并连接蓝牙配件。这个应用程序也可以使用蓝牙定位蓝牙设备。</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>如果需要添加或使用蓝牙设备，请开启手机蓝牙功能。</string>

如果需要 小程序版 设备详情，则在 thing_custom_config.json 文件中配置 device_detail_mini_program 为 true。

```
{
    "config": {
       ...
        "device_detail_mini_program": true
    },
    ...
}
```


### 跳转到设备详情

```
#import <ThingSmartBizCore/ThingSmartBizCore.h>
#import <ThingModuleServices/ThingDeviceDetailProtocol.h>

id<ThingDeviceDetailProtocol> impl = [[ThingSmartBizCore sharedInstance] serviceOfProtocol:@protocol(ThingDeviceDetailProtocol)];

// 跳转到设备网络检测页
[impl gotoDeviceDetailNetworkViewControllerWithDeviceId:@"设备 ID"];

    // 跳转到设备详情页，以 push 方式

    // 如果是设备，new ThingSmartDevice
ThingSmartDevice * device = [ThingSmartDevice deviceWithDeviceId:@"设备 ID"]
    [impl gotoDeviceDetailDetailViewControllerWithDevice: device.deviceModel group: nil];
    // 如果是群组，new ThingSmartGroup
ThingSmartGroup * group = [ThingSmartDevice groupWithGroupId:@"群组 ID"]
    [impl gotoDeviceDetailDetailViewControllerWithDevice: nil group: group.deviceModel];
```