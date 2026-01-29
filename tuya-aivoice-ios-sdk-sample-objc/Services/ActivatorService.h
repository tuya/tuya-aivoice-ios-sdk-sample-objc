//
//  ActivatorService.h
//  AIVoiceDemo
//
//  Created by Bacson on 2026/1/29.
//

#import <Foundation/Foundation.h>
#import <ThingModuleServices/ThingSmartHomeDataProtocol.h>
#import <ThingModuleServices/ThingActivatorProtocol.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^ActivatorCompletionBlock)(NSArray * _Nullable deviceList);

@interface ActivatorService : NSObject <ThingSmartHomeDataProtocol>

+ (instancetype)sharedInstance;

/**
 * 进入配网页面
 */
- (void)gotoDeviceConfig;

/**
 * 进入扫码配网页面
 */
- (void)gotoQRCodeConfig;

/**
 * 设置配网完成回调
 * @param completionBlock 配网完成回调
 */
- (void)setActivatorCompletion:(ActivatorCompletionBlock)completionBlock;

@end

NS_ASSUME_NONNULL_END
