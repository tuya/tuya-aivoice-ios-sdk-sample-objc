//
//  DeviceService.m
//  AIVoiceDemo
//
//  Created by Bacson on 2026/1/29.
//

#import "DeviceService.h"
#import "HomeManager.h"
#import "HomeService.h"
#import <ThingSmartDeviceKit/ThingSmartDeviceKit.h>

// 共享的 SDK 操作串行队列
static dispatch_queue_t getSDKQueue() {
    static dispatch_queue_t sSDKQueue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sSDKQueue = dispatch_queue_create("com.tuya.sdk.operations", DISPATCH_QUEUE_SERIAL);
    });
    return sSDKQueue;
}

@interface DeviceService ()

@end

@implementation DeviceService

+ (instancetype)sharedInstance {
    static DeviceService *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[DeviceService alloc] init];
    });
    return instance;
}

- (void)getDeviceListWithSuccess:(DeviceSuccessBlock)success
                          failure:(DeviceFailureBlock)failure {
    // 在串行队列中执行 SDK 操作
    dispatch_async(getSDKQueue(), ^{
        ThingSmartHome *home = [HomeManager getCurrentHomeInstance];
        if (!home) {
            if (failure) {
                NSError *error = [NSError errorWithDomain:@"DeviceService" 
                                                     code:-1 
                                                 userInfo:@{NSLocalizedDescriptionKey: @"当前家庭不存在"}];
                failure(error);
            }
            return;
        }
        
        // 检查家庭详细信息是否已加载
        if (!home.homeModel || home.deviceList == nil) {
            // 需要先加载家庭详细信息
            ThingSmartHomeModel *homeModel = [HomeManager getCurrentHome];
            if (!homeModel) {
                if (failure) {
                    NSError *error = [NSError errorWithDomain:@"DeviceService" 
                                                         code:-2 
                                                     userInfo:@{NSLocalizedDescriptionKey: @"当前家庭信息不存在"}];
                    failure(error);
                }
                return;
            }
            
            // 加载家庭详细信息
            [[HomeService sharedInstance] getHomeDataWithHomeId:homeModel.homeId
                                                        success:^(id result) {
                // 重新获取 home 实例
                ThingSmartHome *updatedHome = [HomeManager getCurrentHomeInstance];
                if (updatedHome && updatedHome.deviceList) {
                    if (success) {
                        success([updatedHome.deviceList copy]);
                    }
                } else {
                    if (success) {
                        success(@[]);
                    }
                }
            } failure:^(NSError *error) {
                if (failure) {
                    failure(error);
                }
            }];
        } else {
            // 直接返回设备列表
            if (success) {
                success([home.deviceList copy]);
            }
        }
    });
}

- (void)refreshDeviceListWithSuccess:(DeviceSuccessBlock)success
                             failure:(DeviceFailureBlock)failure {
    // 在串行队列中执行 SDK 操作
    dispatch_async(getSDKQueue(), ^{
        ThingSmartHomeModel *homeModel = [HomeManager getCurrentHome];
        if (!homeModel) {
            if (failure) {
                NSError *error = [NSError errorWithDomain:@"DeviceService" 
                                                     code:-1 
                                                 userInfo:@{NSLocalizedDescriptionKey: @"当前家庭不存在"}];
                failure(error);
            }
            return;
        }
        
        // 强制刷新家庭详细信息
        [[HomeService sharedInstance] getHomeDataWithHomeId:homeModel.homeId
                                                    success:^(id result) {
            // 重新获取 home 实例
            ThingSmartHome *home = [HomeManager getCurrentHomeInstance];
            if (home && home.deviceList) {
                if (success) {
                    success([home.deviceList copy]);
                }
            } else {
                if (success) {
                    success(@[]);
                }
            }
        } failure:^(NSError *error) {
            if (failure) {
                failure(error);
            }
        }];
    });
}

@end
