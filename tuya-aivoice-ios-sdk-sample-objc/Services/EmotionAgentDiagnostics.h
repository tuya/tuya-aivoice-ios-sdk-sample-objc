#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@class ThingSmartRequest;

/// 查询设备当前可访问的智能体配置；使用云端 ATOP 角色接口，不调用角色切换或聊天会话接口。
@interface EmotionAgentDiagnostics : NSObject
@property (nonatomic, assign, readonly, getter=isRunning) BOOL running;
- (instancetype)initWithRequest:(ThingSmartRequest *)request;
- (void)fetchDeviceId:(NSString *)deviceId
           productId:(NSString *)productId
          completion:(void (^)(NSDictionary<NSString *, NSDictionary *> *report))completion;
@end

NS_ASSUME_NONNULL_END
