//
//  ThingPerfusionWERCalculator.m
//  AIVoiceDemo
//

#import "ThingPerfusionWERCalculator.h"

/// 语气词（填充词），归一化时剔除，不参与 WER。
static NSString *const kThingPerfusionFillerChars = @"啊额呃嗯唉哎哦喔呵哈儿";
/// 行内 WER 达到该阈值即认为这一行没有被识别出来。
static const double kThingPerfusionMissedLineWER = 0.85;
/// 一个参考行最多允许由多少个识别分段合并而成（下限；实际值按识别段数与参考行数的比例上调）。
static const NSInteger kThingPerfusionMinMaxSpan = 8;

#pragma mark - 模型

@implementation ThingPerfusionWERToken
@end

@implementation ThingPerfusionWERResult

- (NSUInteger)errorCount {
    return self.substitutions + self.deletions + self.insertions;
}

- (double)wer {
    if (self.referenceCount == 0) return 0;
    return (double)self.errorCount / (double)self.referenceCount;
}

- (double)accuracy {
    double value = 1.0 - self.wer;
    return value < 0 ? 0 : value;
}

- (NSUInteger)hits {
    NSUInteger wrong = self.substitutions + self.deletions;
    return self.referenceCount > wrong ? self.referenceCount - wrong : 0;
}

@end

@implementation ThingPerfusionWERLineResult
@end

#pragma mark - 计算

@implementation ThingPerfusionWERCalculator

#pragma mark 归一化

/// 数词归一化表：参考文本写 "two"，ASR 常输出 "2"，不归一会被判成替换错误。
+ (NSDictionary<NSString *, NSString *> *)numberMap {
    static NSDictionary *map = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        map = @{
            @"null": @"0", @"eins": @"1", @"zwei": @"2", @"drei": @"3", @"vier": @"4",
            @"fünf": @"5", @"sechs": @"6", @"sieben": @"7", @"acht": @"8", @"neun": @"9",
            @"zehn": @"10",
            @"zero": @"0", @"one": @"1", @"two": @"2", @"three": @"3", @"four": @"4",
            @"five": @"5", @"six": @"6", @"seven": @"7", @"eight": @"8", @"nine": @"9",
            @"ten": @"10",
        };
    });
    return map;
}

+ (NSCharacterSet *)fillerCharacterSet {
    static NSCharacterSet *set = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        set = [NSCharacterSet characterSetWithCharactersInString:kThingPerfusionFillerChars];
    });
    return set;
}

/// 归一化保留的字符：字母、数字、下划线、空白，其余一律转空格。
/// 标点必须转成空格而不是直接删除，否则 "starkes.Kulturellen" 会被粘成一个词，凭空制造错误。
+ (NSCharacterSet *)keepCharacterSet {
    static NSCharacterSet *set = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableCharacterSet *mutable = [NSMutableCharacterSet alphanumericCharacterSet];
        [mutable addCharactersInString:@"_"];
        [mutable formUnionWithCharacterSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        set = [mutable copy];
    });
    return set;
}

+ (BOOL)isCJKCharacter:(unichar)character {
    return character >= 0x4E00 && character <= 0x9FFF;
}

+ (NSString *)normalizeText:(nullable NSString *)text {
    if (text.length == 0) return @"";

    NSString *lowercase = [[text lowercaseString] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSCharacterSet *keep = [self keepCharacterSet];
    NSCharacterSet *filler = [self fillerCharacterSet];
    NSMutableString *buffer = [NSMutableString stringWithCapacity:lowercase.length + 16];

    // 按字素簇遍历，带变音符号的字母（ö、ü 的分解形式）不会被拆坏。
    [lowercase enumerateSubstringsInRange:NSMakeRange(0, lowercase.length)
                                  options:NSStringEnumerationByComposedCharacterSequences
                               usingBlock:^(NSString *substring, NSRange r1, NSRange r2, BOOL *stop) {
        if (substring.length == 0) return;
        unichar first = [substring characterAtIndex:0];

        // 语气词直接丢弃，不参与 WER。
        if (substring.length == 1 && [filler characterIsMember:first]) return;

        if ([self isCJKCharacter:first]) {
            // 中文逐字比较：字与字之间补空格。
            [buffer appendFormat:@" %@ ", substring];
            return;
        }
        if ([substring rangeOfCharacterFromSet:keep].location == NSNotFound) {
            [buffer appendString:@" "];   // 标点等 → 空格
            return;
        }
        [buffer appendString:substring];
    }];

    // 压缩连续空白
    NSArray<NSString *> *pieces = [buffer componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSMutableArray<NSString *> *tokens = [NSMutableArray arrayWithCapacity:pieces.count];
    for (NSString *piece in pieces) {
        if (piece.length > 0) [tokens addObject:piece];
    }

    // 千分位/小数点在上一步变成了空格，这里把 "40 000" 还原成 "40000"。
    NSMutableArray<NSString *> *merged = [NSMutableArray arrayWithCapacity:tokens.count];
    for (NSString *token in tokens) {
        NSString *previous = merged.lastObject;
        if (previous.length > 0 && token.length == 3 &&
            [self isAllDigits:previous] && [self isAllDigits:token]) {
            merged[merged.count - 1] = [previous stringByAppendingString:token];
            continue;
        }
        [merged addObject:token];
    }

    // 数词归一化
    NSDictionary<NSString *, NSString *> *numberMap = [self numberMap];
    NSMutableArray<NSString *> *normalized = [NSMutableArray arrayWithCapacity:merged.count];
    for (NSString *token in merged) {
        NSString *mapped = numberMap[token];
        [normalized addObject:mapped ?: token];
    }
    return [normalized componentsJoinedByString:@" "];
}

+ (BOOL)isAllDigits:(NSString *)text {
    if (text.length == 0) return NO;
    NSCharacterSet *nonDigits = NSCharacterSet.decimalDigitCharacterSet.invertedSet;
    return [text rangeOfCharacterFromSet:nonDigits].location == NSNotFound;
}

+ (NSArray<NSString *> *)normalizedLinesFromReferenceText:(nullable NSString *)text {
    if (text.length == 0) return @[];
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    // 只有「编号 + 空格」形式的行首才剥离，避免把正文首词当成编号删掉。
    NSRegularExpression *indexPattern =
        [NSRegularExpression regularExpressionWithPattern:@"^(?:\\d+|[A-Za-z]+[-_]?\\d+)$"
                                                  options:0
                                                    error:nil];

    for (NSString *rawLine in [text componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]) {
        NSString *line = [rawLine stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if (line.length == 0) continue;

        NSRange space = [line rangeOfString:@" "];
        if (space.location != NSNotFound) {
            NSString *head = [line substringToIndex:space.location];
            NSUInteger matches = [indexPattern numberOfMatchesInString:head
                                                              options:0
                                                                range:NSMakeRange(0, head.length)];
            if (matches > 0) line = [line substringFromIndex:space.location + 1];
        }

        NSString *normalized = [self normalizeText:line];
        if (normalized.length > 0) [lines addObject:normalized];
    }
    return lines;
}

#pragma mark 编辑距离

+ (ThingPerfusionWERResult *)evaluateReference:(nullable NSString *)reference
                               hypothesis:(nullable NSString *)hypothesis {
    return [self evaluateNormalizedReference:[self normalizeText:reference]
                        normalizedHypothesis:[self normalizeText:hypothesis]];
}

+ (ThingPerfusionWERResult *)evaluateNormalizedReference:(NSString *)reference
                               normalizedHypothesis:(NSString *)hypothesis {
    NSArray<NSString *> *refTokens = [self tokensOf:reference];
    NSArray<NSString *> *hypTokens = [self tokensOf:hypothesis];

    ThingPerfusionWERResult *result = [[ThingPerfusionWERResult alloc] init];
    result.normalizedReference = reference ?: @"";
    result.normalizedHypothesis = hypothesis ?: @"";
    result.referenceCount = refTokens.count;
    result.hypothesisCount = hypTokens.count;

    NSUInteger n = refTokens.count;
    NSUInteger m = hypTokens.count;

    if (n == 0 && m == 0) {
        result.alignment = @[];
        return result;
    }
    // 一侧为空时无需 DP：要么全是删除，要么全是插入。
    if (n == 0 || m == 0) {
        NSMutableArray<ThingPerfusionWERToken *> *alignment = [NSMutableArray array];
        for (NSString *token in refTokens) {
            ThingPerfusionWERToken *item = [[ThingPerfusionWERToken alloc] init];
            item.operation = ThingPerfusionWEROperationDelete;
            item.referenceToken = token;
            [alignment addObject:item];
        }
        for (NSString *token in hypTokens) {
            ThingPerfusionWERToken *item = [[ThingPerfusionWERToken alloc] init];
            item.operation = ThingPerfusionWEROperationInsert;
            item.hypothesisToken = token;
            [alignment addObject:item];
        }
        result.deletions = n;
        result.insertions = m;
        result.alignment = alignment;
        return result;
    }

    // DP：d[i][j] 为前 i 个参考词与前 j 个识别词的编辑距离，bt 记录回溯方向。
    size_t width = m + 1;
    NSUInteger *distance = calloc((n + 1) * width, sizeof(NSUInteger));
    uint8_t *backtrace = calloc((n + 1) * width, sizeof(uint8_t));
    if (!distance || !backtrace) {
        free(distance);
        free(backtrace);
        result.alignment = @[];
        return result;
    }

    // 操作编码：0 命中 1 替换 2 删除 3 插入
    for (NSUInteger i = 0; i <= n; i++) {
        distance[i * width] = i;
        backtrace[i * width] = 2;
    }
    for (NSUInteger j = 0; j <= m; j++) {
        distance[j] = j;
        backtrace[j] = 3;
    }
    backtrace[0] = 0;

    for (NSUInteger i = 1; i <= n; i++) {
        NSString *refToken = refTokens[i - 1];
        for (NSUInteger j = 1; j <= m; j++) {
            if ([refToken isEqualToString:hypTokens[j - 1]]) {
                distance[i * width + j] = distance[(i - 1) * width + (j - 1)];
                backtrace[i * width + j] = 0;
                continue;
            }
            NSUInteger substitute = distance[(i - 1) * width + (j - 1)] + 1;
            NSUInteger delete = distance[(i - 1) * width + j] + 1;
            NSUInteger insert = distance[i * width + (j - 1)] + 1;
            NSUInteger best = MIN(substitute, MIN(delete, insert));
            distance[i * width + j] = best;
            // 相等时优先替换，其次删除，与参考实现保持一致。
            backtrace[i * width + j] = (best == substitute) ? 1 : ((best == delete) ? 2 : 3);
        }
    }

    NSMutableArray<ThingPerfusionWERToken *> *reversed = [NSMutableArray array];
    NSUInteger i = n, j = m;
    NSUInteger S = 0, D = 0, I = 0;
    while (i > 0 || j > 0) {
        uint8_t op = backtrace[i * width + j];
        ThingPerfusionWERToken *item = [[ThingPerfusionWERToken alloc] init];
        if (i > 0 && j > 0 && op == 0) {
            item.operation = ThingPerfusionWEROperationEqual;
            item.referenceToken = refTokens[i - 1];
            item.hypothesisToken = hypTokens[j - 1];
            i--; j--;
        } else if (i > 0 && j > 0 && op == 1) {
            item.operation = ThingPerfusionWEROperationSubstitute;
            item.referenceToken = refTokens[i - 1];
            item.hypothesisToken = hypTokens[j - 1];
            S++; i--; j--;
        } else if (i > 0 && (op == 2 || j == 0)) {
            item.operation = ThingPerfusionWEROperationDelete;
            item.referenceToken = refTokens[i - 1];
            D++; i--;
        } else {
            item.operation = ThingPerfusionWEROperationInsert;
            item.hypothesisToken = hypTokens[j - 1];
            I++; j--;
        }
        [reversed addObject:item];
    }
    free(distance);
    free(backtrace);

    result.substitutions = S;
    result.deletions = D;
    result.insertions = I;
    result.alignment = [[reversed reverseObjectEnumerator] allObjects];
    return result;
}

+ (NSArray<NSString *> *)tokensOf:(nullable NSString *)text {
    if (text.length == 0) return @[];
    NSMutableArray<NSString *> *tokens = [NSMutableArray array];
    for (NSString *piece in [text componentsSeparatedByString:@" "]) {
        if (piece.length > 0) [tokens addObject:piece];
    }
    return tokens;
}

#pragma mark 按行对齐

+ (NSArray<ThingPerfusionWERLineResult *> *)evaluateReferenceLines:(NSArray<NSString *> *)referenceLines
                                          hypothesisSegments:(NSArray<NSString *> *)segments {
    if (referenceLines.count == 0) return @[];

    NSMutableArray<NSString *> *normalizedSegments = [NSMutableArray array];
    for (NSString *segment in segments) {
        NSString *normalized = [self normalizeText:segment];
        if (normalized.length > 0) [normalizedSegments addObject:normalized];
    }

    NSArray<NSArray<NSNumber *> *> *assignment = [self alignSegments:normalizedSegments
                                                    toReferenceLines:referenceLines];

    NSMutableArray<ThingPerfusionWERLineResult *> *results = [NSMutableArray array];
    [referenceLines enumerateObjectsUsingBlock:^(NSString *refLine, NSUInteger idx, BOOL *stop) {
        NSMutableArray<NSString *> *pieces = [NSMutableArray array];
        for (NSNumber *segIndex in assignment[idx]) {
            NSUInteger index = segIndex.unsignedIntegerValue;
            if (index < normalizedSegments.count) [pieces addObject:normalizedSegments[index]];
        }
        NSString *hypothesis = [pieces componentsJoinedByString:@" "];

        ThingPerfusionWERLineResult *line = [[ThingPerfusionWERLineResult alloc] init];
        line.lineNumber = idx + 1;
        line.reference = refLine;
        line.hypothesis = hypothesis;
        line.result = [self evaluateNormalizedReference:refLine normalizedHypothesis:hypothesis];
        line.missed = line.result.wer >= kThingPerfusionMissedLineWER;
        [results addObject:line];
    }];
    return results;
}

/// 把识别分段单调切分并对齐到参考行：动态规划，使总编辑距离最小。
/// 只在对角线附近搜索（band），避免长文本上退化成 O(n·m·span)。
+ (NSArray<NSArray<NSNumber *> *> *)alignSegments:(NSArray<NSString *> *)segments
                                 toReferenceLines:(NSArray<NSString *> *)referenceLines {
    NSUInteger nR = referenceLines.count;
    NSUInteger nH = segments.count;

    NSMutableArray<NSArray<NSString *> *> *refTokens = [NSMutableArray arrayWithCapacity:nR];
    for (NSString *line in referenceLines) [refTokens addObject:[self tokensOf:line]];
    NSMutableArray<NSArray<NSString *> *> *hypTokens = [NSMutableArray arrayWithCapacity:nH];
    for (NSString *segment in segments) [hypTokens addObject:[self tokensOf:segment]];

    if (nH == 0) {
        NSMutableArray<NSArray<NSNumber *> *> *empty = [NSMutableArray arrayWithCapacity:nR];
        for (NSUInteger i = 0; i < nR; i++) [empty addObject:@[]];
        return empty;
    }

    // 参考答案只有一行（整段文本）时无需对齐：所有识别分段都属于它。
    // 走 DP 反而会被单行合并段数的上限截断，把多余的识别内容丢掉。
    if (nR == 1) {
        NSMutableArray<NSNumber *> *all = [NSMutableArray arrayWithCapacity:nH];
        for (NSUInteger t = 0; t < nH; t++) [all addObject:@(t)];
        return @[all];
    }

    const double INF = DBL_MAX / 4;
    size_t width = nH + 1;
    double *dp = malloc((nR + 1) * width * sizeof(double));
    NSInteger *back = calloc((nR + 1) * width, sizeof(NSInteger));
    if (!dp || !back) {
        free(dp);
        free(back);
        NSMutableArray<NSArray<NSNumber *> *> *empty = [NSMutableArray arrayWithCapacity:nR];
        for (NSUInteger i = 0; i < nR; i++) [empty addObject:@[]];
        return empty;
    }
    for (size_t idx = 0; idx < (nR + 1) * width; idx++) dp[idx] = INF;
    dp[0] = 0;

    double ratio = nR > 0 ? (double)nH / (double)nR : 1.0;
    NSInteger band = MAX(20, (NSInteger)(ratio * 6));
    // 识别分段数远多于参考行数时（ASR 把一句切得很碎），上限要跟着放大，
    // 否则尾部分段会分不到任何参考行而被丢弃，凭空判成漏识。
    NSInteger maxSpan = MAX(kThingPerfusionMinMaxSpan, (NSInteger)ceil(ratio) + 4);

    for (NSUInteger i = 1; i <= nR; i++) {
        NSInteger lo = MAX(0, (NSInteger)(i * ratio) - band);
        NSInteger hi = MIN((NSInteger)nH, (NSInteger)(i * ratio) + band);
        NSArray<NSString *> *reference = refTokens[i - 1];
        for (NSInteger j = lo; j <= hi; j++) {
            double best = INF;
            NSInteger bestSpan = 0;
            for (NSInteger span = 0; span <= maxSpan; span++) {
                NSInteger k = j - span;
                if (k < 0) break;
                double previous = dp[(i - 1) * width + (NSUInteger)k];
                if (previous >= INF) continue;
                NSMutableArray<NSString *> *merged = [NSMutableArray array];
                for (NSInteger t = k; t < j; t++) [merged addObjectsFromArray:hypTokens[(NSUInteger)t]];
                double cost = previous + (double)[self editDistanceBetween:reference and:merged];
                if (cost < best) {
                    best = cost;
                    bestSpan = span;
                }
            }
            dp[i * width + (NSUInteger)j] = best;
            back[i * width + (NSUInteger)j] = bestSpan;
        }
    }

    NSMutableArray<NSArray<NSNumber *> *> *assignment = [NSMutableArray arrayWithCapacity:nR];
    for (NSUInteger i = 0; i < nR; i++) [assignment addObject:@[]];
    NSInteger j = (NSInteger)nH;
    for (NSUInteger i = nR; i >= 1; i--) {
        NSInteger span = back[i * width + (NSUInteger)j];
        NSMutableArray<NSNumber *> *ids = [NSMutableArray array];
        for (NSInteger t = j - span; t < j; t++) {
            if (t >= 0) [ids addObject:@((NSUInteger)t)];
        }
        assignment[i - 1] = ids;
        j -= span;
        if (j < 0) j = 0;
    }
    free(dp);
    free(back);
    return assignment;
}

/// 只求编辑距离数值，用于对齐打分。
+ (NSUInteger)editDistanceBetween:(NSArray<NSString *> *)left and:(NSArray<NSString *> *)right {
    NSUInteger n = left.count;
    NSUInteger m = right.count;
    if (n == 0) return m;
    if (m == 0) return n;

    NSUInteger *previous = malloc((m + 1) * sizeof(NSUInteger));
    NSUInteger *current = malloc((m + 1) * sizeof(NSUInteger));
    if (!previous || !current) {
        free(previous);
        free(current);
        return MAX(n, m);
    }
    for (NSUInteger j = 0; j <= m; j++) previous[j] = j;

    for (NSUInteger i = 1; i <= n; i++) {
        current[0] = i;
        NSString *token = left[i - 1];
        for (NSUInteger j = 1; j <= m; j++) {
            if ([token isEqualToString:right[j - 1]]) {
                current[j] = previous[j - 1];
            } else {
                current[j] = MIN(previous[j - 1], MIN(previous[j], current[j - 1])) + 1;
            }
        }
        memcpy(previous, current, (m + 1) * sizeof(NSUInteger));
    }
    NSUInteger result = previous[m];
    free(previous);
    free(current);
    return result;
}

@end
