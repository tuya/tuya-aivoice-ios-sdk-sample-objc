//
//  HomeService.h
//  AIVoiceDemo
//
//  Created by Bacson on 2026/1/28.
//

#import <Foundation/Foundation.h>
#import <ThingSmartDeviceKit/ThingSmartDeviceKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^HomeSuccessBlock)(id _Nullable result);
typedef void(^HomeFailureBlock)(NSError *error);

@interface HomeService : NSObject

@property (nonatomic, strong) ThingSmartHomeManager *homeManager;

+ (instancetype)sharedInstance;

/**
 * 创建家庭
 * @param name 家庭名称
 * @param city 城市名称
 * @param latitude 纬度
 * @param longitude 经度
 * @param success 成功回调，返回homeId
 * @param failure 失败回调
 */
- (void)addHomeWithName:(NSString *)name
                geoName:(NSString *)city
                 rooms:(NSArray<NSString *> *)rooms
              latitude:(double)latitude
             longitude:(double)longitude
               success:(HomeSuccessBlock)success
               failure:(HomeFailureBlock)failure;

/**
 * 获取家庭列表
 * @param success 成功回调，返回家庭列表
 * @param failure 失败回调
 */
- (void)getHomeListWithSuccess:(HomeSuccessBlock)success
                       failure:(HomeFailureBlock)failure;

/**
 * 查询家庭详细信息
 * @param homeId 家庭ID
 * @param success 成功回调，返回家庭详细信息
 * @param failure 失败回调
 */
- (void)getHomeDataWithHomeId:(long long)homeId
                       success:(HomeSuccessBlock)success
                       failure:(HomeFailureBlock)failure;

/**
 * 等待缓存加载完成
 * @param block 完成回调
 */
- (void)waitLoadCacheComplete:(void(^)(BOOL complete))block;

@end

NS_ASSUME_NONNULL_END
