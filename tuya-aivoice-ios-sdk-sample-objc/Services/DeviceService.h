//
//  DeviceService.h
//  AIVoiceDemo
//
//  Created by Bacson on 2026/1/29.
//

#import <Foundation/Foundation.h>
#import <ThingSmartDeviceKit/ThingSmartDeviceKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^DeviceSuccessBlock)(NSArray<ThingSmartDeviceModel *> * _Nullable deviceList);
typedef void(^DeviceFailureBlock)(NSError *error);

@interface DeviceService : NSObject

+ (instancetype)sharedInstance;

/**
 * 获取当前家庭下的设备列表
 * @param success 成功回调，返回设备列表
 * @param failure 失败回调
 */
- (void)getDeviceListWithSuccess:(DeviceSuccessBlock)success
                          failure:(DeviceFailureBlock)failure;


@end

NS_ASSUME_NONNULL_END
