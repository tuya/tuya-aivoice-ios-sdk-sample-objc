//
//  HomeService.m
//  AIVoiceDemo
//
//  Created by Bacson on 2026/1/28.
//

#import "HomeService.h"

// 共享的 SDK 操作串行队列
static dispatch_queue_t getSDKQueue() {
    static dispatch_queue_t sSDKQueue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sSDKQueue = dispatch_queue_create("com.tuya.sdk.operations", DISPATCH_QUEUE_SERIAL);
    });
    return sSDKQueue;
}

@interface HomeService ()

@end

@implementation HomeService

+ (instancetype)sharedInstance {
    static HomeService *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[HomeService alloc] init];
        instance.homeManager = [ThingSmartHomeManager new];
    });
    return instance;
}

- (void)addHomeWithName:(NSString *)name
                geoName:(NSString *)city
                 rooms:(NSArray<NSString *> *)rooms
              latitude:(double)latitude
             longitude:(double)longitude
               success:(HomeSuccessBlock)success
               failure:(HomeFailureBlock)failure {
    // 在串行队列中执行 SDK 操作
    dispatch_async(getSDKQueue(), ^{
        [self.homeManager addHomeWithName:name
                                   geoName:city
                                     rooms:rooms
                                  latitude:latitude
                                 longitude:longitude
                                   success:^(long long result) {
            if (success) {
                success(@(result));
            }
        } failure:^(NSError *error) {
            if (failure) {
                failure(error);
            }
        }];
    });
}

- (void)getHomeListWithSuccess:(HomeSuccessBlock)success
                       failure:(HomeFailureBlock)failure {
    // 在串行队列中执行 SDK 操作
    dispatch_async(getSDKQueue(), ^{
        [self.homeManager getHomeListWithSuccess:^(NSArray<ThingSmartHomeModel *> *homes) {
            if (success) {
                success(homes);
            }
        } failure:^(NSError *error) {
            if (failure) {
                failure(error);
            }
        }];
    });
}

- (void)getHomeDataWithHomeId:(long long)homeId
                       success:(HomeSuccessBlock)success
                       failure:(HomeFailureBlock)failure {
    // 在串行队列中执行 SDK 操作
    dispatch_async(getSDKQueue(), ^{
        NSLog(@"HomeService: 开始查询家庭详细信息，homeId: %lld", homeId);
        ThingSmartHome *home = [ThingSmartHome homeWithHomeId:homeId];
        if (!home) {
            NSLog(@"HomeService: home 为 nil");
            if (failure) {
                NSError *error = [NSError errorWithDomain:@"HomeService" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"家庭不存在"}];
                failure(error);
            }
            return;
        }
        
        NSLog(@"HomeService: home 对象创建成功，开始调用 getHomeDataWithSuccess");
        [home getHomeDataWithSuccess:^(ThingSmartHomeModel *homeModel) {
            NSLog(@"HomeService: getHomeDataWithSuccess 回调执行，homeModel: %@", homeModel ? @"存在" : @"nil");
            if (success) {
                success(homeModel);
            }
        } failure:^(NSError *error) {
            NSLog(@"HomeService: getHomeDataWithSuccess 失败: %@", error.localizedDescription);
            if (failure) {
                failure(error);
            }
        }];
    });
}

- (void)waitLoadCacheComplete:(void(^)(BOOL complete))block {
    [self.homeManager waitLoadCacheComplete:block];
}

@end
