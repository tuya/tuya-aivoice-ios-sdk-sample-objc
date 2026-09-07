//
//  ThingPerfusionReportBuilder.h
//  AIVoiceDemo
//
//  把一次灌流的结果与 WER 计算结果渲染成 HTML 测试报告。
//

#import <Foundation/Foundation.h>
#import "ThingPerfusionWERCalculator.h"

NS_ASSUME_NONNULL_BEGIN

/// 单轮灌流的评估摘要，用于多轮汇总。
@interface ThingPerfusionRoundSummary : NSObject
/// 第几轮，从 1 开始。
@property (nonatomic, assign) NSUInteger roundIndex;
/// 该轮的 WER 结果；未选参考答案时为 nil。
@property (nonatomic, strong, nullable) ThingPerfusionWERResult *werResult;
/// 该轮耗时（秒）。
@property (nonatomic, assign) NSTimeInterval elapsed;
/// 该轮识别到的分句数。
@property (nonatomic, assign) NSUInteger asrSentenceCount;
/// 该轮结束原因。
@property (nonatomic, copy, nullable) NSString *finishReason;
@property (nonatomic, copy, nullable) NSString *recordId;
@end

/// 报告所需的一次灌流上下文。
@interface ThingPerfusionReportInput : NSObject

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

/// 多轮灌流的逐轮摘要。仅一轮时可留空；多于一轮时报告会输出「多轮汇总」章节。
@property (nonatomic, copy, nullable) NSArray<ThingPerfusionRoundSummary *> *roundSummaries;

@end

@interface ThingPerfusionReportBuilder : NSObject

/// 报告输出目录：Documents/voiceRecord/automaticTest/reports。
+ (NSString *)reportsDirectory;

/// 渲染 HTML 报告正文。
+ (NSString *)htmlReportWithInput:(ThingPerfusionReportInput *)input
                        werResult:(nullable ThingPerfusionWERResult *)result
                      lineResults:(nullable NSArray<ThingPerfusionWERLineResult *> *)lineResults;

/// 生成报告并落盘，返回文件地址；失败返回 nil。
+ (nullable NSURL *)writeReportWithInput:(ThingPerfusionReportInput *)input
                               werResult:(nullable ThingPerfusionWERResult *)result
                             lineResults:(nullable NSArray<ThingPerfusionWERLineResult *> *)lineResults
                                   error:(NSError **)error;

/// 纯文本摘要，用于页面展示与剪贴板复制。
+ (NSString *)textSummaryWithInput:(ThingPerfusionReportInput *)input
                         werResult:(nullable ThingPerfusionWERResult *)result;

@end

NS_ASSUME_NONNULL_END
