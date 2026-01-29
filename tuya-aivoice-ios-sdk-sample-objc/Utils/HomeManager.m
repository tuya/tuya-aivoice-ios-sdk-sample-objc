//
//  HomeManager.m
//  AIVoiceDemo
//
//  Created by Bacson on 2026/1/28.
//

#import "HomeManager.h"
#import <ThingSmartDeviceKit/ThingSmartDeviceKit.h>

static NSString * const kCurrentHomeKey = @"CurrentHome";
static NSString * const kCachedHomeDetailKey = @"CachedHomeDetail";

// 共享的 SDK 操作串行队列，确保所有 SDK 操作在同一线程执行
static dispatch_queue_t sSDKQueue = nil;
static dispatch_once_t sSDKQueueOnceToken;

static dispatch_queue_t getSDKQueue() {
    dispatch_once(&sSDKQueueOnceToken, ^{
        sSDKQueue = dispatch_queue_create("com.tuya.sdk.operations", DISPATCH_QUEUE_SERIAL);
    });
    return sSDKQueue;
}

@implementation HomeManager

+ (ThingSmartHomeModel *)getCurrentHome {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (![defaults valueForKey:kCurrentHomeKey]) {
        return nil;
    }
    
    long long homeId = [[defaults valueForKey:kCurrentHomeKey] longLongValue];
    
    // 在串行队列中执行 SDK 操作
    __block ThingSmartHomeModel *result = nil;
    dispatch_sync(getSDKQueue(), ^{
        ThingSmartHome *home = [ThingSmartHome homeWithHomeId:homeId];
        if (home) {
            result = home.homeModel;
        }
    });
    
    return result;
}

+ (void)setCurrentHome:(ThingSmartHomeModel *)homeModel {
    if (!homeModel) {
        [self clearCurrentHome];
        return;
    }
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setValue:[NSString stringWithFormat:@"%lld", homeModel.homeId] forKey:kCurrentHomeKey];
    [defaults synchronize];
}

+ (long long)getCurrentHomeId {
    ThingSmartHomeModel *homeModel = [self getCurrentHome];
    return homeModel ? homeModel.homeId : 0;
}

+ (void)clearCurrentHome {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:kCurrentHomeKey];
    [defaults removeObjectForKey:kCachedHomeDetailKey];
    [defaults synchronize];
}

+ (ThingSmartHome *)getCurrentHomeInstance {
    long long homeId = [self getCurrentHomeId];
    if (homeId == 0) {
        return nil;
    }
    
    // 在串行队列中执行 SDK 操作
    __block ThingSmartHome *result = nil;
    dispatch_sync(getSDKQueue(), ^{
        result = [ThingSmartHome homeWithHomeId:homeId];
    });
    
    return result;
}

+ (void)cacheHomeDetail:(ThingSmartHomeModel *)homeModel {
    if (!homeModel) {
        return;
    }
    
    // 由于 ThingSmartHomeModel 可能不支持 NSCoding，我们只缓存 homeId
    // 详细信息可以通过 ThingSmartHome 实例获取
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setValue:[NSString stringWithFormat:@"%lld", homeModel.homeId] forKey:kCachedHomeDetailKey];
    [defaults synchronize];
    
    NSLog(@"家庭详细信息已缓存 - ID: %lld", homeModel.homeId);
}

+ (ThingSmartHomeModel *)getCachedHomeDetail {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *homeIdString = [defaults valueForKey:kCachedHomeDetailKey];
    if (!homeIdString) {
        return nil;
    }
    
    long long homeId = [homeIdString longLongValue];
    
    // 在串行队列中执行 SDK 操作
    __block ThingSmartHomeModel *result = nil;
    dispatch_sync(getSDKQueue(), ^{
        ThingSmartHome *home = [ThingSmartHome homeWithHomeId:homeId];
        if (home) {
            // 返回 home 实例中的 homeModel（如果已加载详细信息）
            result = home.homeModel;
        }
    });
    
    return result;
}

@end
