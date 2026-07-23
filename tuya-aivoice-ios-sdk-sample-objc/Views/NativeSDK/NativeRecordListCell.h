//
//  NativeRecordListCell.h
//  AIVoiceDemo
//

#import <UIKit/UIKit.h>

@class ThingAudioRecordFile;
@class ThingAudioRecordSearchMixResultItem;

NS_ASSUME_NONNULL_BEGIN

/// 录音列表项 cell，展示录音名称、时间、时长和转写状态。
@interface NativeRecordListCell : UITableViewCell

+ (NSString *)reuseIdentifier;

/// 用录音文件模型配置 cell。
- (void)configureWithRecordFile:(ThingAudioRecordFile *)file;

/// 用搜索结果项配置 cell。
- (void)configureWithSearchItem:(ThingAudioRecordSearchMixResultItem *)item;

@end

NS_ASSUME_NONNULL_END
