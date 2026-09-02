//
//  PerfusionAudioFileInfo.m
//  AIVoiceDemo
//

#import "PerfusionAudioFileInfo.h"

/// 底层音频链路的期望参数。
static const NSUInteger kPerfusionExpectedSampleRate = 16000;
static const NSUInteger kPerfusionExpectedChannels = 1;
static const NSUInteger kPerfusionExpectedBits = 16;
/// WAV audioFormat：1 = 整型 PCM（底层唯一支持的），3 = IEEE float。
static const NSUInteger kPerfusionWaveFormatPCM = 1;
/// fmt chunk 通常在文件头部，读一小段即可，避免把大文件整个载入内存。
static const NSUInteger kPerfusionHeaderProbeLength = 4096;

@implementation PerfusionAudioFileInfo

+ (PerfusionAudioFileInfo *)infoAtPath:(nullable NSString *)path {
    PerfusionAudioFileInfo *info = [[PerfusionAudioFileInfo alloc] init];
    if (path.length == 0) return info;

    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
    if (!handle) return info;
    NSData *header = [handle readDataOfLength:kPerfusionHeaderProbeLength];
    [handle closeFile];
    if (header.length < 44) return info;

    const uint8_t *bytes = header.bytes;
    if (memcmp(bytes, "RIFF", 4) != 0 || memcmp(bytes + 8, "WAVE", 4) != 0) return info;

    // 逐个 chunk 查找 "fmt "，不能假定它紧跟在文件头后面（可能先有 JUNK/LIST 等）。
    NSUInteger offset = 12;
    while (offset + 8 <= header.length) {
        uint32_t chunkSize = 0;
        memcpy(&chunkSize, bytes + offset + 4, 4);
        chunkSize = CFSwapInt32LittleToHost(chunkSize);

        if (memcmp(bytes + offset, "fmt ", 4) == 0) {
            if (offset + 8 + 16 > header.length) return info;
            const uint8_t *fmt = bytes + offset + 8;
            uint16_t audioFormat = 0, channels = 0, bits = 0;
            uint32_t sampleRate = 0;
            memcpy(&audioFormat, fmt, 2);
            memcpy(&channels, fmt + 2, 2);
            memcpy(&sampleRate, fmt + 4, 4);
            memcpy(&bits, fmt + 14, 2);

            info.parsed = YES;
            info.audioFormat = CFSwapInt16LittleToHost(audioFormat);
            info.channels = CFSwapInt16LittleToHost(channels);
            info.sampleRate = CFSwapInt32LittleToHost(sampleRate);
            info.bitsPerSample = CFSwapInt16LittleToHost(bits);

            // WAVE_FORMAT_EXTENSIBLE 把真实格式放在扩展块的 SubFormat 里，
            // 其前两字节即等价的 format tag。
            if (info.audioFormat == 0xFFFE && offset + 8 + 40 <= header.length) {
                uint16_t subFormat = 0;
                memcpy(&subFormat, fmt + 24, 2);
                info.audioFormat = CFSwapInt16LittleToHost(subFormat);
            }
            return info;
        }
        // chunk 按偶数字节对齐
        offset += 8 + chunkSize + (chunkSize % 2);
    }
    return info;
}

- (BOOL)isDecodable {
    // 底层日志明确：only PCM supported。非 PCM 一定解不出音频。
    return self.parsed && self.audioFormat == kPerfusionWaveFormatPCM;
}

- (BOOL)isRecommended {
    return self.isDecodable
        && self.sampleRate == kPerfusionExpectedSampleRate
        && self.channels == kPerfusionExpectedChannels
        && self.bitsPerSample == kPerfusionExpectedBits;
}

- (NSString *)formatName {
    switch (self.audioFormat) {
        case 1: return @"PCM";
        case 3: return @"IEEE float";
        case 6: return @"A-law";
        case 7: return @"μ-law";
        case 0xFFFE: return @"Extensible";
        default: return [NSString stringWithFormat:@"格式 %lu", (unsigned long)self.audioFormat];
    }
}

- (NSString *)summary {
    if (!self.parsed) return @"无法解析音频头（不是标准 WAV？）";
    return [NSString stringWithFormat:@"%@ %.1fkHz %@ %lubit",
            [self formatName],
            self.sampleRate / 1000.0,
            self.channels == 1 ? @"单声道" : [NSString stringWithFormat:@"%lu 声道", (unsigned long)self.channels],
            (unsigned long)self.bitsPerSample];
}

- (nullable NSString *)warning {
    if (!self.parsed) {
        return @"无法解析为 WAV。底层只支持整型 PCM 的 WAV，其它容器（mp3 等）不会有任何 ASR 输出。";
    }
    if (!self.isDecodable) {
        return [NSString stringWithFormat:@"底层只支持整型 PCM，当前是 %@，灌流不会有任何 ASR 输出。", [self formatName]];
    }
    NSMutableArray<NSString *> *issues = [NSMutableArray array];
    if (self.sampleRate != kPerfusionExpectedSampleRate) {
        [issues addObject:[NSString stringWithFormat:@"采样率 %luHz（应为 %luHz）",
                           (unsigned long)self.sampleRate, (unsigned long)kPerfusionExpectedSampleRate]];
    }
    if (self.channels != kPerfusionExpectedChannels) {
        [issues addObject:[NSString stringWithFormat:@"%lu 声道（应为单声道）", (unsigned long)self.channels]];
    }
    if (self.bitsPerSample != kPerfusionExpectedBits) {
        [issues addObject:[NSString stringWithFormat:@"%lubit（应为 %lubit）",
                           (unsigned long)self.bitsPerSample, (unsigned long)kPerfusionExpectedBits]];
    }
    if (issues.count == 0) return nil;
    return [NSString stringWithFormat:@"%@，识别结果可能异常（语速、音调不对或直接无输出）。",
            [issues componentsJoinedByString:@"、"]];
}

@end
