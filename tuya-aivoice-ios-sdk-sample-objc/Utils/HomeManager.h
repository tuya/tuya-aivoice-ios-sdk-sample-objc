//
//  HomeManager.h
//  AIVoiceDemo
//
//  Created by Bacson on 2026/1/28.
//

#import <Foundation/Foundation.h>
#import <ThingSmartDeviceKit/ThingSmartDeviceKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface HomeManager : NSObject

/**
 * 获取当前家庭
 * @return 当前家庭模型，如果不存在返回nil
 */
+ (ThingSmartHomeModel * _Nullable)getCurrentHome;

/**
 * 设置当前家庭
 * @param homeModel 家庭模型
 */
+ (void)setCurrentHome:(ThingSmartHomeModel *)homeModel;

/**
 * 获取当前家庭ID
 * @return 当前家庭ID，如果不存在返回0
 */
+ (long long)getCurrentHomeId;

/**
 * 清除当前家庭
 */
+ (void)clearCurrentHome;

/**
 * 获取当前家庭实例（ThingSmartHome）
 * @return 当前家庭实例，如果不存在返回nil
 */
+ (ThingSmartHome * _Nullable)getCurrentHomeInstance;

/**
 * 缓存家庭详细信息
 * @param homeModel 家庭详细信息模型
 */
+ (void)cacheHomeDetail:(ThingSmartHomeModel *)homeModel;

/**
 * 获取缓存的家庭详细信息
 * @return 缓存的家庭详细信息，如果不存在返回nil
 */
+ (ThingSmartHomeModel * _Nullable)getCachedHomeDetail;

@end

NS_ASSUME_NONNULL_END
