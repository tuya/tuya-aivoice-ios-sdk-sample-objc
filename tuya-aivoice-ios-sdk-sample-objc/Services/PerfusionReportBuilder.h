//
//  PerfusionReportBuilder.h
//  AIVoiceDemo
//
//  把一次灌流的结果与 WER 计算结果渲染成 HTML 测试报告。
//

#import <Foundation/Foundation.h>
#import "PerfusionWERCalculator.h"

NS_ASSUME_NONNULL_BEGIN

/// 报告所需的一次灌流上下文。
@interface PerfusionReportInput : NSObject

@property (nonatomic, copy, nullable) NSString *audioFileName;
@property (nonatomic, copy, nullable) NSString *referenceFileName;
/// 参考答案原文（未归一化）。
@property (nonatomic, copy, nullable) NSString *referenceText;
/// 识别分句（未归一化），按时间顺序。
@property (nonatomic, copy) NSArray<NSString *> *asrSentences;
/// 翻译分句（未归一化）。
@property (nonatomic, copy) NSArray<NSString *> *translateSentences;

@property (nonatomic, strong, nullable) NSDate *startDate;
@property (nonatomic, strong, nullable) NSDate *endDate;
@property (nonatomic, copy, nullable) NSString *recordId;
@property (nonatomic, copy, nullable) NSString *finishReason;

@property (nonatomic, assign) BOOL asrEnabled;
@property (nonatomic, assign) BOOL translateEnabled;
@property (nonatomic, assign) BOOL ttsEnabled;
@property (nonatomic, copy, nullable) NSString *originalLanguage;
@property (nonatomic, copy, nullable) NSString *targetLanguage;

@property (nonatomic, assign) NSUInteger configFetchCount;
@property (nonatomic, assign) NSUInteger ttsCallbackCount;

@end

@interface PerfusionReportBuilder : NSObject

/// 报告输出目录：Documents/voiceRecord/automaticTest/reports。
+ (NSString *)reportsDirectory;

/// 渲染 HTML 报告正文。
+ (NSString *)htmlReportWithInput:(PerfusionReportInput *)input
                        werResult:(nullable PerfusionWERResult *)result
                      lineResults:(nullable NSArray<PerfusionWERLineResult *> *)lineResults;

/// 生成报告并落盘，返回文件地址；失败返回 nil。
+ (nullable NSURL *)writeReportWithInput:(PerfusionReportInput *)input
                               werResult:(nullable PerfusionWERResult *)result
                             lineResults:(nullable NSArray<PerfusionWERLineResult *> *)lineResults
                                   error:(NSError **)error;

/// 纯文本摘要，用于页面展示与剪贴板复制。
+ (NSString *)textSummaryWithInput:(PerfusionReportInput *)input
                         werResult:(nullable PerfusionWERResult *)result;

@end

NS_ASSUME_NONNULL_END
