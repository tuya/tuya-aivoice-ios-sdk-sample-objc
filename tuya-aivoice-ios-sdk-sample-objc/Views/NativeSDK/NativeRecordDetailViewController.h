//
//  NativeRecordDetailViewController.h
//  AIVoiceDemo
//

#import <UIKit/UIKit.h>
#import "FamilyBaseViewController.h"

NS_ASSUME_NONNULL_BEGIN

/// 录音详情页：展示转写、总结、音频播放、振幅，支持发起转写/总结/翻译。
@interface NativeRecordDetailViewController : FamilyBaseViewController

- (instancetype)initWithRecordId:(NSString *)recordId NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
