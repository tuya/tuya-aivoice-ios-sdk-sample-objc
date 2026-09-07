//
//  ThingPerfusionLogStore.h
//  ThingPerfusionKit
//
//  灌流事件日志的集中存储。记录 SDK 调用与回调事件（start/stop、录音状态、
//  实时识别结果、灌流配置回读、WER 结果等），供日志页面查看与导出。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 有新日志写入时发出，object 为新增的那一行。主线程发出。
FOUNDATION_EXPORT NSNotificationName const ThingPerfusionLogDidAppendNotification;

@interface ThingPerfusionLogStore : NSObject

+ (instancetype)sharedInstance;

/// 已记录的日志行（含时间戳），按时间正序。
@property (nonatomic, copy, readonly) NSArray<NSString *> *entries;

/// 追加一行日志。可在任意线程调用。
- (void)append:(NSString *)message;

/// 追加一行带格式的日志。
- (void)appendFormat:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);

/// 清空。
- (void)clear;

/// 全部日志拼成的文本。
- (NSString *)exportText;

/// 日志输出目录：Documents/voiceRecord/automaticTest/logs。
+ (NSString *)logsDirectory;

/// 把当前日志写成 txt 文件，返回文件地址；失败返回 nil。
- (nullable NSURL *)writeToFileWithError:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
