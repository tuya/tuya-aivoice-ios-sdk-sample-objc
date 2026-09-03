//
//  ThingPerfusionAudioFileInfo.h
//  AIVoiceDemo
//
//  灌流音频的格式解析与校验。
//
//  底层把文件内容当作 16kHz / 16bit / 单声道的整型 PCM 直接替换采集流，
//  格式不符时表现为「灌流在跑但没有任何 ASR 输出」（底层日志：
//  ThingAbstractVAD::replaceCaptureData unsupported audio format），
//  所以选文件时就要把格式校验掉。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ThingPerfusionAudioFileInfo : NSObject

/// 是否成功解析出 WAV 头。
@property (nonatomic, assign) BOOL parsed;
/// WAV 的 audioFormat 字段：1 = 整型 PCM，3 = IEEE float，其余为各类压缩格式。
@property (nonatomic, assign) NSUInteger audioFormat;
@property (nonatomic, assign) NSUInteger channels;
@property (nonatomic, assign) NSUInteger sampleRate;
@property (nonatomic, assign) NSUInteger bitsPerSample;

/// 底层能否解出音频：必须是整型 PCM。非 PCM 一定没有 ASR 输出。
@property (nonatomic, assign, readonly) BOOL isDecodable;
/// 是否完全符合链路期望（PCM / 16000Hz / 单声道 / 16bit）。
@property (nonatomic, assign, readonly) BOOL isRecommended;
/// 供 UI 展示的一行摘要，如「PCM 16.0kHz 单声道 16bit」。
@property (nonatomic, copy, readonly) NSString *summary;
/// 不符合期望的原因；完全符合时为 nil。
@property (nonatomic, copy, readonly, nullable) NSString *warning;

/// 解析指定路径的音频格式；无法解析时 parsed 为 NO。
+ (ThingPerfusionAudioFileInfo *)infoAtPath:(nullable NSString *)path;

@end

NS_ASSUME_NONNULL_END
