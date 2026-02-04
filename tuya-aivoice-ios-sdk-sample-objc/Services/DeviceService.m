//
//  DeviceService.m
//  AIVoiceDemo
//
//  Created by Bacson on 2026/1/29.
//

#import "DeviceService.h"
#import <ThingSmartDeviceKit/ThingSmartDeviceKit.h>
#import <ThingModuleManager/ThingModuleManager.h>
#import <ThingModuleServices/ThingFamilyProtocol.h>

// 共享的 SDK 操作串行队列
static dispatch_queue_t getSDKQueue(void) {
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
    
    id<ThingFamilyProtocol> familyImpl = [ThingModule serviceOfRequiredProtocol:@protocol(ThingFamilyProtocol)];
    ThingSmartHome *home = [ThingSmartHome homeWithHomeId:[familyImpl currentFamilyId]];
    if (!home) {
        if (failure) {
            NSError *error = [NSError errorWithDomain:@"DeviceService"
                                                 code:-1
                                             userInfo:@{NSLocalizedDescriptionKey: @"当前家庭不存在"}];
            failure(error);
        }
        return;
    }
    
    if (success) {
        success([home.deviceList copy]);
    }
}


@end
