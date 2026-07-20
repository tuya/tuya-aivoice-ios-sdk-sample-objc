---
alwaysApply: false
---
# 家庭管理

家庭是抽象于全屋智能场景的概念，指用户在以家或者场所为单位的范围内所有设备、账号、权限等信息的集合。

家庭管理主要包括以下能力：

查询家庭列表
获取家庭下所有设备、群组
添加、修改和移除单个家庭
管理家庭名称，地理位置、房间列表信息，成员信息等
家庭下，设备添加、信息修改、监听移除、设备状态变化的监听等

## 家庭信息管理

用户登录成功后需要通过 ThingSmartHomeManager 去查询整个家庭列表的信息，然后初始化其中的一个家庭 ThingSmartHome，查询家庭详情信息，就可以对家庭中的设备进行操作控制。

类名（协议名）	说明
ThingSmartHome	家庭管理类
ThingSmartHomeDelegate	家庭下信息变更回调

获取家庭下所有设备、群组前需先初始化 home 对象，并查询家庭的详情 getHomeDataWithSuccess:failure:，然后 home 实例对象中的属性 homeModel、roomList、deviceList、groupList、sharedDeviceList、sharedGroupList 才有数据。

## 查询家庭列表

本接口返回的数据只是家庭的简单信息。如果要查询具体家庭的详情，您需要去 ThingSmartHome 初始化一个 home，调用接口 getHomeDataWithSuccess:failure:。

``` objective-c
// 查询家庭的列表
- (void)getHomeListWithSuccess:(void(^)(NSArray <ThingSmartHomeModel *> *homes))success
                       failure:(ThingFailureError)failure;
```

### 查询家庭的详细信息

只有调用了此接口，home 实例对象中的属性 homeModel、roomList、deviceList、groupList、sharedDeviceList、sharedGroupList 等才有数据。

``` objective-c
- (void)getHomeDataWithSuccess:(void (^)(ThingSmartHomeModel *homeModel))success
                       failure:(ThingFailureError)failure;

```

### 家庭缓存数据

每次接口请求更新家庭数据后，家庭数据都会被缓存下来。App 下次启动时，会自动加载当前用户的家庭缓存数据。当缓存加载完成后，就可以获取缓存的 ThingSmartHome 数据并进行后续操作，ThingSmartHomeManager 提供等待缓存加载完成的方法。

```objectiv-c
- (void)waitLoadCacheComplete:(void (^)(BOOL complete))blcok;

- (void)getCacheHome {
    [self.homeManager waitLoadCacheComplete:^(BOOL complete) {
       NSLog(@"load home cache complete");
    }];
}
```