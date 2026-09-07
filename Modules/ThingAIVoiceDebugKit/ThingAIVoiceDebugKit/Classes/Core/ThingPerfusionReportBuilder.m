//
//  ThingPerfusionReportBuilder.m
//  AIVoiceDemo
//

#import "ThingPerfusionReportBuilder.h"

@implementation ThingPerfusionRoundSummary
@end

@implementation ThingPerfusionReportInput
@end

@implementation ThingPerfusionReportBuilder

#pragma mark - 路径

+ (NSString *)reportsDirectory {
    NSString *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    return [documents stringByAppendingPathComponent:@"voiceRecord/automaticTest/reports"];
}

#pragma mark - 工具

+ (NSString *)escape:(nullable NSString *)text {
    if (text.length == 0) return @"";
    NSMutableString *escaped = [text mutableCopy];
    [escaped replaceOccurrencesOfString:@"&" withString:@"&amp;" options:0 range:NSMakeRange(0, escaped.length)];
    [escaped replaceOccurrencesOfString:@"<" withString:@"&lt;" options:0 range:NSMakeRange(0, escaped.length)];
    [escaped replaceOccurrencesOfString:@">" withString:@"&gt;" options:0 range:NSMakeRange(0, escaped.length)];
    [escaped replaceOccurrencesOfString:@"\"" withString:@"&quot;" options:0 range:NSMakeRange(0, escaped.length)];
    return escaped;
}

+ (NSString *)formatDate:(nullable NSDate *)date {
    if (!date) return @"-";
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    return [formatter stringFromDate:date];
}

+ (NSString *)percent:(double)value {
    return [NSString stringWithFormat:@"%.2f%%", value * 100];
}

/// 逐词对比：替换标红、插入标黄并加 +、删除标绿并加 −。
+ (NSString *)diffHTMLWithAlignment:(NSArray<ThingPerfusionWERToken *> *)alignment {
    if (alignment.count == 0) return @"<span class='mut'>(无内容)</span>";
    NSMutableString *html = [NSMutableString string];
    for (ThingPerfusionWERToken *token in alignment) {
        switch (token.operation) {
            case ThingPerfusionWEROperationEqual:
                [html appendFormat:@"%@ ", [self escape:token.hypothesisToken]];
                break;
            case ThingPerfusionWEROperationSubstitute:
                [html appendFormat:@"<span class='sub' title='应为 %@'>%@</span> ",
                 [self escape:token.referenceToken], [self escape:token.hypothesisToken]];
                break;
            case ThingPerfusionWEROperationInsert:
                [html appendFormat:@"<span class='ins'>+%@</span> ", [self escape:token.hypothesisToken]];
                break;
            case ThingPerfusionWEROperationDelete:
                [html appendFormat:@"<span class='del'>&minus;%@</span> ", [self escape:token.referenceToken]];
                break;
        }
    }
    return html;
}

+ (NSString *)css {
    return @""
    ":root{--bg:#fff;--fg:#1a1a1a;--mut:#6b7280;--line:#e5e7eb;--card:#f7f8fa;--zebra:#fafbfc;"
    "--acc:#2563eb;--good:#059669;--warn:#d97706;--bad:#dc2626;--sub:#dc2626;--ins:#b45309;--del:#059669}"
    "@media(prefers-color-scheme:dark){:root{--bg:#15171c;--fg:#e8e8ea;--mut:#9ba1a9;--line:#2c2f36;"
    "--card:#1d2026;--zebra:#1a1d22;--acc:#60a5fa;--good:#34d399;--warn:#fbbf24;--bad:#f87171;"
    "--sub:#f87171;--ins:#fbbf24;--del:#34d399}}"
    "*{box-sizing:border-box}"
    "body{background:var(--bg);color:var(--fg);margin:0 auto;padding:28px 20px 60px;max-width:1100px;"
    "font:14px/1.65 -apple-system,BlinkMacSystemFont,'PingFang SC','Segoe UI',sans-serif}"
    "h1{font-size:22px;margin:0 0 4px;letter-spacing:-.01em}"
    ".subtitle{color:var(--mut);font-size:13px;margin-bottom:22px}"
    "h2{font-size:15px;margin:34px 0 12px;padding-bottom:8px;border-bottom:1px solid var(--line);"
    "letter-spacing:.02em;text-transform:uppercase;color:var(--mut);font-weight:600}"
    ".kpis{display:grid;grid-template-columns:repeat(auto-fit,minmax(140px,1fr));gap:12px}"
    ".kpi{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:14px 16px}"
    ".kpi .lb{color:var(--mut);font-size:12px;margin-bottom:4px}"
    ".kpi .v{font-size:24px;font-weight:700;letter-spacing:-.02em;font-variant-numeric:tabular-nums}"
    ".kpi .ex{color:var(--mut);font-size:11.5px;margin-top:2px}"
    ".v.good{color:var(--good)}.v.bad{color:var(--bad)}.v.warn{color:var(--warn)}"
    "table{border-collapse:collapse;width:100%;font-size:13px}"
    "th,td{border-bottom:1px solid var(--line);padding:9px 10px;text-align:left;vertical-align:top}"
    "th{color:var(--mut);font-weight:600;font-size:11.5px;text-transform:uppercase;letter-spacing:.03em;"
    "white-space:nowrap;background:var(--card)}"
    "td.n{text-align:right;font-variant-numeric:tabular-nums;white-space:nowrap}"
    "tbody tr:nth-child(even){background:var(--zebra)}"
    "tr.missed td{background:rgba(220,38,38,.08)}"
    ".seg{display:flex;height:8px;border-radius:4px;overflow:hidden;background:var(--line);margin-top:10px}"
    ".seg i{display:block;height:100%}"
    ".lg{display:flex;flex-wrap:wrap;gap:14px;font-size:11.5px;color:var(--mut);margin:8px 0 0}"
    ".lg b{display:inline-block;width:9px;height:9px;border-radius:2px;margin-right:4px;vertical-align:-1px}"
    ".txt{font-size:12.5px;line-height:2;word-break:break-word;background:var(--card);"
    "border:1px solid var(--line);border-radius:8px;padding:12px 14px}"
    ".sub{color:var(--sub);font-weight:600}.ins{color:var(--ins);font-weight:600}"
    ".del{color:var(--del);font-weight:600}.mut{color:var(--mut)}"
    ".lead{color:var(--mut);font-size:13px;margin:-4px 0 12px}"
    "code{background:var(--card);border:1px solid var(--line);border-radius:4px;padding:1px 5px;font-size:12px}"
    "ol,ul{padding-left:20px}li{margin-bottom:6px}"
    ".formula{background:var(--card);border:1px solid var(--line);border-radius:8px;padding:14px 16px;"
    "font-size:13px;margin:12px 0}"
    ".foot{color:var(--mut);font-size:12px;margin-top:36px;padding-top:12px;border-top:1px solid var(--line)}";
}

#pragma mark - 报告

+ (NSString *)htmlReportWithInput:(ThingPerfusionReportInput *)input
                        werResult:(nullable ThingPerfusionWERResult *)result
                      lineResults:(nullable NSArray<ThingPerfusionWERLineResult *> *)lineResults {
    NSMutableString *html = [NSMutableString string];
    NSTimeInterval elapsed = (input.startDate && input.endDate)
        ? [input.endDate timeIntervalSinceDate:input.startDate] : 0;

    [html appendString:@"<!doctype html><html lang='zh'><head><meta charset='utf-8'>"];
    [html appendString:@"<meta name='viewport' content='width=device-width,initial-scale=1'>"];
    [html appendFormat:@"<title>灌流测试报告 %@</title>", [self escape:input.audioFileName ?: @""]];
    [html appendFormat:@"<style>%@</style></head><body>", [self css]];

    [html appendString:@"<h1>灌流测试报告</h1>"];
    [html appendFormat:@"<div class='subtitle'>生成时间 %@ ｜ 灌流音频 %@ ｜ 参考答案 %@</div>",
     [self formatDate:NSDate.date],
     [self escape:input.audioFileName ?: @"-"],
     [self escape:input.referenceFileName ?: @"-"]];

    // —— KPI ——
    [html appendString:@"<div class='kpis'>"];
    if (result && result.referenceCount > 0) {
        NSString *accuracyClass = result.accuracy >= 0.9 ? @"good" : (result.accuracy >= 0.7 ? @"warn" : @"bad");
        [html appendFormat:@"<div class='kpi'><div class='lb'>准确率</div><div class='v %@'>%@</div>"
         "<div class='ex'>1 − WER</div></div>", accuracyClass, [self percent:result.accuracy]];
        [html appendFormat:@"<div class='kpi'><div class='lb'>WER</div><div class='v'>%@</div>"
         "<div class='ex'>(S+D+I)/N</div></div>", [self percent:result.wer]];
        [html appendFormat:@"<div class='kpi'><div class='lb'>参考词数 N</div><div class='v'>%lu</div>"
         "<div class='ex'>识别 %lu 词</div></div>",
         (unsigned long)result.referenceCount, (unsigned long)result.hypothesisCount];
        [html appendFormat:@"<div class='kpi'><div class='lb'>错误合计</div><div class='v'>%lu</div>"
         "<div class='ex'>S%lu / D%lu / I%lu</div></div>",
         (unsigned long)result.errorCount, (unsigned long)result.substitutions,
         (unsigned long)result.deletions, (unsigned long)result.insertions];
        [html appendFormat:@"<div class='kpi'><div class='lb'>命中词数</div><div class='v'>%lu</div>"
         "<div class='ex'>N − S − D</div></div>", (unsigned long)result.hits];
    } else {
        [html appendString:@"<div class='kpi'><div class='lb'>WER</div><div class='v mut'>未计算</div>"
         "<div class='ex'>未选择参考答案</div></div>"];
    }
    [html appendFormat:@"<div class='kpi'><div class='lb'>灌流耗时</div><div class='v'>%.1fs</div>"
     "<div class='ex'>%@</div></div>", elapsed, [self escape:input.finishReason ?: @"-"]];
    [html appendString:@"</div>"];

    // 错误构成条
    if (result && result.errorCount > 0) {
        double total = (double)result.errorCount;
        [html appendString:@"<div class='seg'>"];
        [html appendFormat:@"<i style='width:%.1f%%;background:var(--sub)'></i>", result.substitutions / total * 100];
        [html appendFormat:@"<i style='width:%.1f%%;background:var(--del)'></i>", result.deletions / total * 100];
        [html appendFormat:@"<i style='width:%.1f%%;background:var(--ins)'></i>", result.insertions / total * 100];
        [html appendString:@"</div>"];
        [html appendString:@"<div class='lg'><span><b style='background:var(--sub)'></b>替换 S</span>"
         "<span><b style='background:var(--del)'></b>删除 D</span>"
         "<span><b style='background:var(--ins)'></b>插入 I</span>"
         "<span>按错误总数占比</span></div>"];
    }

    // —— 测试条件 ——
    [html appendString:@"<h2>测试条件</h2><table><tbody>"];
    [html appendFormat:@"<tr><th>灌流音频</th><td>%@</td></tr>", [self escape:input.audioFileName ?: @"-"]];
    [html appendFormat:@"<tr><th>参考答案</th><td>%@</td></tr>", [self escape:input.referenceFileName ?: @"-"]];
    [html appendFormat:@"<tr><th>开始时间</th><td>%@</td></tr>", [self formatDate:input.startDate]];
    [html appendFormat:@"<tr><th>结束时间</th><td>%@</td></tr>", [self formatDate:input.endDate]];
    [html appendFormat:@"<tr><th>耗时</th><td>%.2f 秒</td></tr>", elapsed];
    [html appendFormat:@"<tr><th>结束原因</th><td>%@</td></tr>", [self escape:input.finishReason ?: @"-"]];
    [html appendFormat:@"<tr><th>能力开关</th><td>ASR %@ ｜ 翻译 %@ ｜ TTS %@</td></tr>",
     input.asrEnabled ? @"开" : @"关", input.translateEnabled ? @"开" : @"关", input.ttsEnabled ? @"开" : @"关"];
    [html appendFormat:@"<tr><th>语言</th><td>%@ → %@</td></tr>",
     [self escape:input.originalLanguage ?: @"-"], [self escape:input.targetLanguage ?: @"-"]];
    [html appendFormat:@"<tr><th>recordId</th><td>%@</td></tr>", [self escape:input.recordId ?: @"-"]];
    [html appendFormat:@"<tr><th>识别分句</th><td>%lu 句</td></tr>", (unsigned long)input.asrSentences.count];
    [html appendFormat:@"<tr><th>翻译分句</th><td>%lu 句</td></tr>", (unsigned long)input.translateSentences.count];
    [html appendFormat:@"<tr><th>底层回读灌流配置</th><td>%lu 次%@</td></tr>",
     (unsigned long)input.configFetchCount,
     input.configFetchCount == 0 ? @"（灌流未生效，录制的是真实麦克风）" : @""];
    [html appendFormat:@"<tr><th>TTS 回调</th><td>%lu 次</td></tr>", (unsigned long)input.ttsCallbackCount];
    [html appendString:@"</tbody></table>"];

    // —— 多轮汇总 ——
    if (input.roundSummaries.count > 1) {
        NSArray<ThingPerfusionRoundSummary *> *rounds = input.roundSummaries;
        NSMutableArray<NSNumber *> *accuracies = [NSMutableArray array];
        for (ThingPerfusionRoundSummary *round in rounds) {
            if (round.werResult.referenceCount > 0) [accuracies addObject:@(round.werResult.accuracy)];
        }

        [html appendString:@"<h2>多轮汇总</h2>"];
        if (accuracies.count > 0) {
            double sum = 0, best = 0, worst = 1;
            for (NSNumber *item in accuracies) {
                double value = item.doubleValue;
                sum += value;
                best = MAX(best, value);
                worst = MIN(worst, value);
            }
            double mean = sum / accuracies.count;
            // 样本标准差，反映多轮之间的波动
            double variance = 0;
            for (NSNumber *item in accuracies) {
                variance += pow(item.doubleValue - mean, 2);
            }
            variance = accuracies.count > 1 ? variance / (accuracies.count - 1) : 0;

            [html appendString:@"<div class='kpis'>"];
            [html appendFormat:@"<div class='kpi'><div class='lb'>平均准确率</div><div class='v'>%@</div>"
             "<div class='ex'>%lu 轮</div></div>", [self percent:mean], (unsigned long)accuracies.count];
            [html appendFormat:@"<div class='kpi'><div class='lb'>最好</div><div class='v good'>%@</div></div>",
             [self percent:best]];
            [html appendFormat:@"<div class='kpi'><div class='lb'>最差</div><div class='v bad'>%@</div></div>",
             [self percent:worst]];
            [html appendFormat:@"<div class='kpi'><div class='lb'>波动</div><div class='v'>%.2fpp</div>"
             "<div class='ex'>标准差</div></div>", sqrt(variance) * 100];
            [html appendString:@"</div>"];
        }

        [html appendString:@"<table><thead><tr><th class='n'>轮次</th><th class='n'>准确率</th>"
         "<th class='n'>WER</th><th class='n'>N</th><th class='n'>S</th><th class='n'>D</th>"
         "<th class='n'>I</th><th class='n'>分句</th><th class='n'>耗时</th><th>结束原因</th>"
         "</tr></thead><tbody>"];
        for (ThingPerfusionRoundSummary *round in rounds) {
            ThingPerfusionWERResult *r = round.werResult;
            [html appendFormat:@"<tr><td class='n'>%lu</td>", (unsigned long)round.roundIndex];
            if (r.referenceCount > 0) {
                [html appendFormat:@"<td class='n'>%@</td><td class='n'>%@</td><td class='n'>%lu</td>"
                 "<td class='n'>%lu</td><td class='n'>%lu</td><td class='n'>%lu</td>",
                 [self percent:r.accuracy], [self percent:r.wer],
                 (unsigned long)r.referenceCount, (unsigned long)r.substitutions,
                 (unsigned long)r.deletions, (unsigned long)r.insertions];
            } else {
                [html appendString:@"<td class='n mut'>—</td><td class='n mut'>—</td><td class='n mut'>—</td>"
                 "<td class='n mut'>—</td><td class='n mut'>—</td><td class='n mut'>—</td>"];
            }
            [html appendFormat:@"<td class='n'>%lu</td><td class='n'>%.1fs</td><td>%@</td></tr>",
             (unsigned long)round.asrSentenceCount, round.elapsed,
             [self escape:round.finishReason ?: @"-"]];
        }
        [html appendString:@"</tbody></table>"];
        [html appendString:@"<div class='lead'>下面的逐句对比与全文对比对应<b>最后一轮</b>的识别结果。</div>"];
    }

    // —— 逐行对比 ——
    if (lineResults.count > 0) {
        NSUInteger missedCount = 0;
        for (ThingPerfusionWERLineResult *line in lineResults) {
            if (line.missed) missedCount++;
        }
        [html appendString:@"<h2>逐句对比</h2>"];
        [html appendFormat:@"<div class='lead'>把识别分段单调对齐到参考答案的每一行（动态规划取总编辑距离最小），"
         "逐行给出错误构成。行内 WER ≥ 85%% 视为<b>漏识</b>，共 %lu 行。</div>", (unsigned long)missedCount];
        // 一个识别分段不能拆开分给多行，段数少于行数时必然有行分不到内容，此时漏识数会虚高。
        if (input.asrSentences.count > 0 && input.asrSentences.count < lineResults.count) {
            [html appendFormat:@"<div class='lead' style='color:var(--warn)'><b>⚠️ 逐句对比仅供参考：</b>"
             "本次识别只有 %lu 段输出，而参考答案有 %lu 行，说明 ASR 把多行内容合并成了一段。"
             "对齐时一个识别分段无法拆开分配给多行，必然有参考行分不到内容，"
             "上表的「漏识」并不代表内容真的丢失 —— 请以<b>全文 WER %@</b> 为准。"
             "若需要准确的逐句结果，请让参考答案的分行与音频中的自然停顿一致。</div>",
             (unsigned long)input.asrSentences.count, (unsigned long)lineResults.count,
             result ? [self percent:result.wer] : @"-"];
        }
        [html appendString:@"<table><thead><tr><th class='n'>行</th><th>参考答案</th><th>识别结果（差异高亮）</th>"
         "<th class='n'>N</th><th class='n'>S</th><th class='n'>D</th><th class='n'>I</th>"
         "<th class='n'>WER</th></tr></thead><tbody>"];
        for (ThingPerfusionWERLineResult *line in lineResults) {
            ThingPerfusionWERResult *r = line.result;
            [html appendFormat:@"<tr class='%@'>", line.missed ? @"missed" : @""];
            [html appendFormat:@"<td class='n'>%lu</td>", (unsigned long)line.lineNumber];
            [html appendFormat:@"<td>%@</td>", [self escape:line.reference]];
            [html appendFormat:@"<td>%@%@</td>",
             line.missed ? @"<b class='sub'>[漏识] </b>" : @"",
             [self diffHTMLWithAlignment:r.alignment]];
            [html appendFormat:@"<td class='n'>%lu</td>", (unsigned long)r.referenceCount];
            [html appendFormat:@"<td class='n'>%lu</td>", (unsigned long)r.substitutions];
            [html appendFormat:@"<td class='n'>%lu</td>", (unsigned long)r.deletions];
            [html appendFormat:@"<td class='n'>%lu</td>", (unsigned long)r.insertions];
            [html appendFormat:@"<td class='n'>%@</td>", [self percent:r.wer]];
            [html appendString:@"</tr>"];
        }
        [html appendString:@"</tbody></table>"];
    }

    // —— 全文逐词对比 ——
    if (result) {
        [html appendString:@"<h2>全文逐词对比</h2>"];
        [html appendString:@"<div class='lead'>以下为归一化之后、实际参与计算的文本。"
         "<span class='sub'>红色</span>为替换（悬停可看应为何词），"
         "<span class='ins'>+黄色</span>为多识别出的词，"
         "<span class='del'>−绿色</span>为漏掉的词。</div>"];
        [html appendFormat:@"<div class='txt'>%@</div>", [self diffHTMLWithAlignment:result.alignment]];

        [html appendString:@"<h2>归一化文本</h2>"];
        [html appendString:@"<div class='lead'>参考答案（归一化后）</div>"];
        [html appendFormat:@"<div class='txt mut'>%@</div>",
         [self escape:result.normalizedReference.length > 0 ? result.normalizedReference : @"(空)"]];
        [html appendString:@"<div class='lead' style='margin-top:12px'>识别结果（归一化后）</div>"];
        [html appendFormat:@"<div class='txt mut'>%@</div>",
         [self escape:result.normalizedHypothesis.length > 0 ? result.normalizedHypothesis : @"(空)"]];
    }

    // —— 识别与翻译原文 ——
    [html appendString:@"<h2>识别原文</h2>"];
    [html appendFormat:@"<div class='txt'>%@</div>",
     input.asrSentences.count > 0
        ? [self escape:[input.asrSentences componentsJoinedByString:@"\n"]]
        : @"<span class='mut'>(空)</span>"];
    if (input.translateSentences.count > 0) {
        [html appendString:@"<h2>翻译原文</h2>"];
        [html appendFormat:@"<div class='txt'>%@</div>",
         [self escape:[input.translateSentences componentsJoinedByString:@"\n"]]];
    }

    // —— 计算方式 ——
    [html appendString:@"<h2>计算方式</h2>"];
    [html appendString:
     @"<div class='formula'><b>WER（词错误率）= (S + D + I) / N</b><br>"
     "<span class='mut'>S = 替换数，D = 删除数（参考里有但没识别出来），I = 插入数（识别多出来的），"
     "N = 参考答案词数。准确率 = 1 − WER（下限截到 0）。</span></div>"];
    [html appendString:@"<p>计算分两步：</p><ol>"];
    [html appendString:@"<li><b>文本归一化</b>——参考答案与识别结果套用同一套规则，消除与识别能力无关的差异："
     "<ul>"
     "<li>统一转小写、去首尾空白；</li>"
     "<li>标点<b>替换为空格</b>而非直接删除（直接删会把 <code>starkes.Kulturellen</code> 粘成一个词，凭空制造错误）；</li>"
     "<li>中文<b>逐字切分</b>（每个汉字之间补空格），英文等仍按词切分；</li>"
     "<li>剔除语气词 <code>啊额呃嗯唉哎哦喔呵哈儿</code>，不计入错误；</li>"
     "<li>千分位还原：<code>40 000</code> → <code>40000</code>；</li>"
     "<li>数词归一化：<code>two</code>/<code>zwei</code> → <code>2</code>，避免与 ASR 输出的阿拉伯数字互判为错。</li>"
     "</ul></li>"];
    [html appendString:@"<li><b>编辑距离对齐</b>——对归一化后的两个词序列做 Levenshtein 动态规划，"
     "回溯得到每个位置的操作（命中/替换/删除/插入）；代价相同时优先判为替换，其次删除，"
     "与团队现有 Python 口径保持一致。</li></ol>"];
    [html appendString:@"<p><b>逐句对比的对齐方式</b>：ASR 常把一句话切成多段输出，"
     "报告用动态规划把识别分段<b>单调切分</b>后分配给参考行，使各行编辑距离之和最小；"
     "一行可合并的段数上限按「识别段数 ÷ 参考行数」自适应，搜索限制在对角线附近的带状区域内以控制耗时。"
     "参考答案只有一行时不做对齐，全部识别内容归属该行。</p>"];
    [html appendString:@"<p class='mut'><b>该对齐方式的固有限制</b>：一个识别分段不会被拆开分配给多个参考行。"
     "因此当 ASR 把多行参考合并成一段输出（识别段数少于参考行数）时，必然有参考行分不到内容而被判为漏识，"
     "这属于对齐口径造成的虚高，不代表内容真的没被识别出来。<b>全文 WER 不受此影响</b>，"
     "任何情况下都以全文口径为准。</p>"];
    [html appendString:@"<p class='mut'>注意：本报告统计的是 ASR 识别质量。翻译与 TTS 仅记录是否开启及输出情况，"
     "不参与 WER 计算。</p>"];

    [html appendFormat:@"<div class='foot'>由 AIVoice Demo 灌流调试页生成 ｜ %@</div>",
     [self formatDate:NSDate.date]];
    [html appendString:@"</body></html>"];
    return html;
}

+ (nullable NSURL *)writeReportWithInput:(ThingPerfusionReportInput *)input
                               werResult:(nullable ThingPerfusionWERResult *)result
                             lineResults:(nullable NSArray<ThingPerfusionWERLineResult *> *)lineResults
                                   error:(NSError **)error {
    NSString *directory = [self reportsDirectory];
    NSFileManager *manager = NSFileManager.defaultManager;
    if (![manager fileExistsAtPath:directory] &&
        ![manager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:error]) {
        return nil;
    }

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyyMMdd_HHmmss";
    NSString *audioName = (input.audioFileName.stringByDeletingPathExtension.length > 0)
        ? input.audioFileName.stringByDeletingPathExtension : @"perfusion";
    // 文件名里不能带路径分隔符等字符。
    NSCharacterSet *illegal = [NSCharacterSet characterSetWithCharactersInString:@"/\\:*?\"<>|"];
    audioName = [[audioName componentsSeparatedByCharactersInSet:illegal] componentsJoinedByString:@"_"];
    NSString *fileName = [NSString stringWithFormat:@"灌流报告_%@_%@.html",
                          audioName, [formatter stringFromDate:NSDate.date]];
    NSString *path = [directory stringByAppendingPathComponent:fileName];

    NSString *html = [self htmlReportWithInput:input werResult:result lineResults:lineResults];
    if (![html writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:error]) return nil;
    return [NSURL fileURLWithPath:path];
}

+ (NSString *)textSummaryWithInput:(ThingPerfusionReportInput *)input
                         werResult:(nullable ThingPerfusionWERResult *)result {
    NSMutableString *text = [NSMutableString string];
    NSTimeInterval elapsed = (input.startDate && input.endDate)
        ? [input.endDate timeIntervalSinceDate:input.startDate] : 0;

    [text appendFormat:@"结束原因：%@\n", input.finishReason ?: @"-"];
    [text appendFormat:@"灌流文件：%@\n", input.audioFileName ?: @"-"];
    [text appendFormat:@"参考答案：%@\n", input.referenceFileName ?: @"未选择"];
    [text appendFormat:@"recordId：%@\n", input.recordId ?: @"-"];
    [text appendFormat:@"开始时间：%@\n", [self formatDate:input.startDate]];
    [text appendFormat:@"耗时：%.2f s\n", elapsed];
    [text appendFormat:@"能力开关：ASR=%@ 翻译=%@ TTS=%@\n",
     input.asrEnabled ? @"开" : @"关", input.translateEnabled ? @"开" : @"关", input.ttsEnabled ? @"开" : @"关"];
    [text appendFormat:@"语言：%@ -> %@\n", input.originalLanguage ?: @"-", input.targetLanguage ?: @"-"];
    [text appendFormat:@"ASR 分句 %lu 句，翻译分句 %lu 句\n",
     (unsigned long)input.asrSentences.count, (unsigned long)input.translateSentences.count];
    [text appendFormat:@"TTS 回调 %lu 次\n", (unsigned long)input.ttsCallbackCount];
    [text appendFormat:@"底层回读灌流配置 %lu 次%@\n", (unsigned long)input.configFetchCount,
     input.configFetchCount == 0 ? @"（灌流未生效，录的是真实麦克风）" : @""];

    if (result && result.referenceCount > 0) {
        [text appendString:@"\n=== WER 评估 ===\n"];
        [text appendFormat:@"准确率：%@\n", [self percent:result.accuracy]];
        [text appendFormat:@"WER：%@\n", [self percent:result.wer]];
        [text appendFormat:@"参考词数 N=%lu，识别词数=%lu，命中=%lu\n",
         (unsigned long)result.referenceCount, (unsigned long)result.hypothesisCount,
         (unsigned long)result.hits];
        [text appendFormat:@"替换 S=%lu，删除 D=%lu，插入 I=%lu，合计错误=%lu\n",
         (unsigned long)result.substitutions, (unsigned long)result.deletions,
         (unsigned long)result.insertions, (unsigned long)result.errorCount];
        [text appendString:@"计算式：WER = (S + D + I) / N，准确率 = 1 − WER\n"];
    } else {
        [text appendString:@"\n=== WER 评估 ===\n未选择参考答案，未计算\n"];
    }

    NSString *asr = [input.asrSentences componentsJoinedByString:@"\n"];
    NSString *translate = [input.translateSentences componentsJoinedByString:@"\n"];
    [text appendFormat:@"\n=== ASR 全文 ===\n%@\n", asr.length > 0 ? asr : @"(空)"];
    [text appendFormat:@"\n=== 翻译全文 ===\n%@", translate.length > 0 ? translate : @"(空)"];
    return text;
}

@end
