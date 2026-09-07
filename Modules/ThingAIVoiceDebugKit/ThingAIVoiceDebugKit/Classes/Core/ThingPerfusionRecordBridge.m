//
//  ThingPerfusionRecordBridge.m
//  ThingPerfusionKit
//

#import "ThingPerfusionRecordBridge.h"
#import <ThingModuleManager/ThingModule.h>

@implementation ThingPerfusionRecordBridge

+ (instancetype)sharedInstance {
    static ThingPerfusionRecordBridge *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[ThingPerfusionRecordBridge alloc] init];
    });
    return instance;
}

/// 每次按需取，避免持有过期实例。
- (nullable id<ThingAudioRecordManagerInterface>)manager {
    return [ThingModule serviceOfOptionalProtocol:@protocol(ThingAudioRecordManagerInterface)];
}

- (BOOL)isAvailable {
    return [self manager] != nil;
}

static void thing_perfusion_on_main(void (^block)(void)) {
    if (!block) return;
    if (NSThread.isMainThread) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

- (NSError *)unavailableError {
    return [NSError errorWithDomain:@"ThingPerfusionKit"
                              code:-100
                          userInfo:@{NSLocalizedDescriptionKey: @"录音能力不可用，请确认已集成 AI 语音录音模块"}];
}

- (void)startWithDeviceId:(NSString *)deviceId
                   config:(ThingAudioRecordConfig *)config
                  success:(nullable void (^)(ThingAudioRecordObject *task))success
                  failure:(nullable void (^)(NSError *error))failure {
    id<ThingAudioRecordManagerInterface> manager = [self manager];
    if (!manager) {
        NSError *error = [self unavailableError];
        thing_perfusion_on_main(^{ if (failure) failure(error); });
        return;
    }
    [manager startWithDeviceId:deviceId config:config success:^(ThingAudioRecordObject *task) {
        thing_perfusion_on_main(^{ if (success) success(task); });
    } failure:^(NSError *error) {
        thing_perfusion_on_main(^{ if (failure) failure(error); });
    }];
}

- (void)stopWithDeviceId:(NSString *)deviceId
                 success:(nullable void (^)(void))success
                 failure:(nullable void (^)(NSError *error))failure {
    id<ThingAudioRecordManagerInterface> manager = [self manager];
    if (!manager) {
        NSError *error = [self unavailableError];
        thing_perfusion_on_main(^{ if (failure) failure(error); });
        return;
    }
    [manager stopWithDeviceId:deviceId success:^{
        thing_perfusion_on_main(^{ if (success) success(); });
    } failure:^(NSError *error) {
        thing_perfusion_on_main(^{ if (failure) failure(error); });
    }];
}

- (void)addListener:(id<ThingAudioRecordManagerDelegate>)listener deviceId:(NSString *)deviceId {
    [[self manager] addListener:listener forDeviceId:deviceId];
}

- (void)removeListener:(id<ThingAudioRecordManagerDelegate>)listener deviceId:(NSString *)deviceId {
    [[self manager] removeListener:listener forDeviceId:deviceId];
}

@end
