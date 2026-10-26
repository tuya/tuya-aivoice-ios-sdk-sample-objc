#import "FamilyBaseViewController.h"

NS_ASSUME_NONNULL_BEGIN

/// 后续接入智能体时由宿主填入；当前仅保留配置，不建立云端会话。
@interface EmotionAgentConfiguration : NSObject
@property (nonatomic, copy, nullable) NSString *deviceId;
@property (nonatomic, copy, nullable) NSString *solutionCode;
/// 本地角色键（autumn / ocean / sunshine）到云端角色 ID 的映射。
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *roleIds;
@end

@interface EmotionChatViewController : FamilyBaseViewController
@property (nonatomic, strong) EmotionAgentConfiguration *agentConfiguration;
@end

NS_ASSUME_NONNULL_END
