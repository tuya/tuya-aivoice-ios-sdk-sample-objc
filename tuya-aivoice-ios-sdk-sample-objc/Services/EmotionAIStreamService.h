#import <Foundation/Foundation.h>
#import <ThingSmartStreamChannelKit/ThingSmartStreamChannelKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^EmotionAIStreamTextHandler)(NSString *text, ThingStreamPacketStreamFlag streamFlag);
typedef void (^EmotionAIStreamEventHandler)(ThingStreamPacketEventType eventType);
typedef void (^EmotionAIStreamStateHandler)(NSString *state, NSError * _Nullable error);

/// 原生 AI Stream 文字会话封装，支持 App 云端身份和设备代理身份。
@interface EmotionAIStreamService : NSObject <ThingSmartStreamClientDelegate>

@property (nonatomic, copy, nullable) EmotionAIStreamTextHandler textHandler;
@property (nonatomic, copy, nullable) EmotionAIStreamEventHandler eventHandler;
@property (nonatomic, copy, nullable) EmotionAIStreamStateHandler stateHandler;
@property (nonatomic, assign, readonly, getter=isReady) BOOL ready;

- (instancetype)initWithSolutionCode:(NSString *)solutionCode
                        miniProgramId:(nullable NSString *)miniProgramId
                              homeId:(long long)homeId
                           deviceId:(nullable NSString *)deviceId
                   useDeviceIdentity:(BOOL)useDeviceIdentity NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

- (void)startWithCompletion:(void (^)(NSError * _Nullable error))completion;
- (void)sendText:(NSString *)text completion:(void (^)(NSError * _Nullable error))completion;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
