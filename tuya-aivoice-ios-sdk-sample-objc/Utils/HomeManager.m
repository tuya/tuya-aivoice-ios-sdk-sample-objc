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

@implementation HomeManager

+ (ThingSmartHomeModel *)getCurrentHome {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (![defaults valueForKey:kCurrentHomeKey]) {
        return nil;
    }
    
    long long homeId = [[defaults valueForKey:kCurrentHomeKey] longLongValue];
    
    ThingSmartHome *home = [ThingSmartHome homeWithHomeId:homeId];
    if (!home) {
        return nil;
    }
    
    return home.homeModel;
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
    
    return [ThingSmartHome homeWithHomeId:homeId];
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
    ThingSmartHome *home = [ThingSmartHome homeWithHomeId:homeId];
    if (!home) {
        return nil;
    }
    
    // 返回 home 实例中的 homeModel（如果已加载详细信息）
    return home.homeModel;
}

@end
