#import "FamilyBaseViewController.h"

NS_ASSUME_NONNULL_BEGIN

/// 情绪树洞的设备、Agent 和小程序配置。
@interface EmotionAgentConfiguration : NSObject
@property (nonatomic, copy, nullable) NSString *deviceId;
@property (nonatomic, copy, nullable) NSString *productId;
@property (nonatomic, copy, nullable) NSString *ownerId;
@property (nonatomic, copy, nullable) NSString *solutionCode;
@property (nonatomic, copy, nullable) NSString *miniProgramId;
@property (nonatomic, assign) BOOL useDeviceIdentity;
/// 本地角色键（autumn / ocean / sunshine）到云端角色 ID 的映射。
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *roleIds;
@end

@interface EmotionChatViewController : FamilyBaseViewController
@property (nonatomic, strong) EmotionAgentConfiguration *agentConfiguration;
@end

NS_ASSUME_NONNULL_END
