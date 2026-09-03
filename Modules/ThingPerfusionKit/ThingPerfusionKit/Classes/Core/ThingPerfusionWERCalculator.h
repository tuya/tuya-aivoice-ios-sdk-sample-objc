//
//  ThingPerfusionWERCalculator.h
//  AIVoiceDemo
//
//  WER（词错误率）计算。口径对齐团队现有的 ASR_WER/WER.py：
//  文本先归一化（小写、标点转空格、中文逐字切分、剔除语气词、数词归一化），
//  再用编辑距离对齐求出 S/D/I，WER = (S + D + I) / N。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 对齐后每个位置的操作类型。
typedef NS_ENUM(NSInteger, ThingPerfusionWEROperation) {
    ThingPerfusionWEROperationEqual = 0,      ///< 命中
    ThingPerfusionWEROperationSubstitute,     ///< 替换（识别成了别的词）
    ThingPerfusionWEROperationDelete,         ///< 删除（参考里有，识别结果里没有）
    ThingPerfusionWEROperationInsert,         ///< 插入（识别结果里多出来的词）
};

/// 对齐序列中的一项，用于渲染逐词对比。
@interface ThingPerfusionWERToken : NSObject
@property (nonatomic, assign) ThingPerfusionWEROperation operation;
/// 参考词；插入时为 nil。
@property (nonatomic, copy, nullable) NSString *referenceToken;
/// 识别词；删除时为 nil。
@property (nonatomic, copy, nullable) NSString *hypothesisToken;
@end

/// 一次 WER 计算的结果。
@interface ThingPerfusionWERResult : NSObject

/// 参考词数 N。
@property (nonatomic, assign) NSUInteger referenceCount;
/// 识别词数。
@property (nonatomic, assign) NSUInteger hypothesisCount;
@property (nonatomic, assign) NSUInteger substitutions;   ///< S
@property (nonatomic, assign) NSUInteger deletions;       ///< D
@property (nonatomic, assign) NSUInteger insertions;      ///< I

/// 归一化之后的文本，报告里展示实际参与计算的内容。
@property (nonatomic, copy) NSString *normalizedReference;
@property (nonatomic, copy) NSString *normalizedHypothesis;

/// 逐词对齐序列。
@property (nonatomic, copy) NSArray<ThingPerfusionWERToken *> *alignment;

/// S + D + I。
@property (nonatomic, assign, readonly) NSUInteger errorCount;
/// WER = (S + D + I) / N；N 为 0 时返回 0。
@property (nonatomic, assign, readonly) double wer;
/// 准确率 = 1 − WER，下限截到 0。
@property (nonatomic, assign, readonly) double accuracy;
/// 命中词数 = N − S − D。
@property (nonatomic, assign, readonly) NSUInteger hits;

@end

/// 参考文本按行对比的结果。
@interface ThingPerfusionWERLineResult : NSObject
/// 行号，从 1 开始。
@property (nonatomic, assign) NSUInteger lineNumber;
/// 归一化后的参考行。
@property (nonatomic, copy) NSString *reference;
/// 对齐到该行的识别文本（可能由多段合并而成）。
@property (nonatomic, copy) NSString *hypothesis;
@property (nonatomic, strong) ThingPerfusionWERResult *result;
/// 该行几乎没有对应识别输出（行内 WER ≥ 0.85），视为漏识。
@property (nonatomic, assign) BOOL missed;
@end

@interface ThingPerfusionWERCalculator : NSObject

/// 文本归一化：小写、标点转空格、中文逐字切分、剔除语气词、千分位还原、数词归一化。
+ (NSString *)normalizeText:(nullable NSString *)text;

/// 按行归一化参考文本，自动剥离「1 xxx」「A-1 xxx」这类行首编号；空行丢弃。
+ (NSArray<NSString *> *)normalizedLinesFromReferenceText:(nullable NSString *)text;

/// 整体评估。传入原始文本，内部完成归一化。
+ (ThingPerfusionWERResult *)evaluateReference:(nullable NSString *)reference
                               hypothesis:(nullable NSString *)hypothesis;

/// 直接对已归一化的词序列求 S/D/I 与对齐序列。
+ (ThingPerfusionWERResult *)evaluateNormalizedReference:(NSString *)reference
                               normalizedHypothesis:(NSString *)hypothesis;

/// 把识别分段单调切分并对齐到参考行，逐行给出对比结果。
/// @param referenceLines 已归一化的参考行
/// @param segments 识别分段的原始文本，内部会归一化
+ (NSArray<ThingPerfusionWERLineResult *> *)evaluateReferenceLines:(NSArray<NSString *> *)referenceLines
                                          hypothesisSegments:(NSArray<NSString *> *)segments;

@end

NS_ASSUME_NONNULL_END
