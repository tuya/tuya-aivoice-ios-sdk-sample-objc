//
//  ThingPerfusionRecordBridge.h
//  ThingPerfusionKit
//
//  录音链路桥接。灌流页只需要「开始 / 结束 / 监听」，这里做最小封装，
//  并保证所有回调都在主线程触发。
//

#import <Foundation/Foundation.h>
#import <ThingAudioRecordInterface/ThingAudioRecordInterface.h>

NS_ASSUME_NONNULL_BEGIN

@interface ThingPerfusionRecordBridge : NSObject

+ (instancetype)sharedInstance;

/// 底层录音能力是否可用。
- (BOOL)isAvailable;

- (void)startWithDeviceId:(NSString *)deviceId
                   config:(ThingAudioRecordConfig *)config
                  success:(nullable void (^)(ThingAudioRecordObject *task))success
                  failure:(nullable void (^)(NSError *error))failure;

- (void)stopWithDeviceId:(NSString *)deviceId
                 success:(nullable void (^)(void))success
                 failure:(nullable void (^)(NSError *error))failure;

- (void)addListener:(id<ThingAudioRecordManagerDelegate>)listener deviceId:(NSString *)deviceId;
- (void)removeListener:(id<ThingAudioRecordManagerDelegate>)listener deviceId:(NSString *)deviceId;

@end

NS_ASSUME_NONNULL_END
