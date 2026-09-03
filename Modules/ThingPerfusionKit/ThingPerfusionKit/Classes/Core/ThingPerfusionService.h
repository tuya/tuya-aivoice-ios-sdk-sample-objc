//
//  ThingPerfusionService.h
//  AIVoiceDemo
//
//  灌流（Perfusion）能力封装层。
//
//  灌流是把本地音频文件替换麦克风采集数据喂给录音链路的调试手段，用于在不出声的前提下
//  复现 ASR / 翻译 / TTS 全流程。底层通过 ThingAIBudsDebuggerProtocol 向 App 侧索取配置，
//  本服务提供该协议实现，并负责灌流音频目录的管理。
//

#import <Foundation/Foundation.h>
#import "ThingPerfusionAudioFileInfo.h"

NS_ASSUME_NONNULL_BEGIN

/// 灌流结束回调。fileName 为底层回传的灌流文件名，回调固定在主线程触发。
typedef void (^ThingPerfusionDidEndHandler)(NSString *_Nullable fileName);

/// 上行流格式：录音数据发往云端时的编码。
typedef NS_ENUM(NSInteger, ThingPerfusionUpstreamFormat) {
    ThingPerfusionUpstreamFormatPCM  = 0,
    ThingPerfusionUpstreamFormatOpus = 1,
};

/// 3A（降噪 / 增益 / 回声消除）预设。
typedef NS_ENUM(NSInteger, ThingPerfusionAudio3APreset) {
    /// 全部关闭。灌流素材通常已是处理好的音频，原样进链路最能复现问题。
    ThingPerfusionAudio3APresetOff = 0,
    /// 仅开自动增益，与常规手机录音的配置一致。
    ThingPerfusionAudio3APresetAGCOnly,
    /// 降噪 + 增益 + 回声消除全开。
    ThingPerfusionAudio3APresetFull,
};

/// 灌流文件读取完成通知。没有页面接管（例如小程序内录音）时可通过它感知。
/// userInfo["fileName"] 为灌流文件名。主线程发出。
FOUNDATION_EXPORT NSNotificationName const ThingPerfusionDidEndNotification;

@interface ThingPerfusionService : NSObject

+ (instancetype)sharedInstance;

#pragma mark - 配置提供者

/// 向底层注册灌流配置提供者。重复调用安全；返回 NO 表示注册后底层仍取不到实现，灌流不会生效。
- (BOOL)registerProvider;

/// 底层当前能否取到本服务提供的配置。
- (BOOL)isProviderReady;

/// 底层当前实际使用的调试配置实现类名，用于排查注册是否被别的实现顶掉。
- (nullable NSString *)currentProviderClassName;

/// 底层回读灌流配置的次数。开始灌流后该值仍为 0，说明注册没有生效。
@property (nonatomic, assign, readonly) NSUInteger configFetchCount;

/// 把回读计数清零，便于按单次灌流统计。
- (void)resetConfigFetchCount;

#pragma mark - 灌流参数（写入后对下一次开始录音生效）

/// 灌流总开关。
@property (nonatomic, assign) BOOL perfusionEnabled;

/// 灌流音频文件名（不含路径），需位于 `audioFilesDirectory` 目录下。
@property (nonatomic, copy, nullable) NSString *perfusionFileName;

/// 灌流文件读完后是否自动结束录音任务。
@property (nonatomic, assign) BOOL autoCloseFileWhenPerfusionEnd;

#pragma mark - 链路参数
//
// 注意：底层 ThingAudioRecordManager._updateTaskConfig: 只要拿到非空的调试配置，
// 就会用其中的值**整体覆盖**调用方传入的 3A 与上行流格式。也就是说这两项一旦
// 本服务注册成功就必须完整提供，否则会被当成「全部关闭 / PCM」，
// 连带影响其它调用方（例如小程序内发起的录音）。

/// 上行流格式。默认 Opus，与底层未接入调试工具时的默认值保持一致。
@property (nonatomic, assign) ThingPerfusionUpstreamFormat upstreamFormat;

/// 3A 预设。默认全部关闭，保证灌流素材原样进入链路。
@property (nonatomic, assign) ThingPerfusionAudio3APreset audio3APreset;

/// 灌流输入文件本身**只支持整型 PCM 的 WAV**（底层 replaceCaptureData 的限制），
/// 与上行流格式无关：上行流格式决定的是采集之后发往云端的编码。
+ (NSString *)inputFileFormatRequirement;

/// 灌流结束回调。
@property (nonatomic, copy, nullable) ThingPerfusionDidEndHandler didEndHandler;

/// 关闭灌流并清空回调，避免影响后续正常录音；全局模式开启时不会关闭灌流。
- (void)reset;

#pragma mark - 全局灌流模式

/// 全局灌流模式。
///
/// 灌流是在底层音频输入层生效的，只看本服务回答的配置，与谁发起录音无关 ——
/// 因此开启后，**任何**走手机麦克风链路的录音都会被替换成灌流文件，
/// 包括小程序（AI 笔记 / AI 翻译）内发起的录音，无需 hook 任何调用方。
///
/// 该开关会持久化并在下次启动时自动恢复，因此：
/// - 开启期间正常麦克风录音一律失效（录到的是灌流文件内容）；
/// - 调试结束后务必关闭。
///
/// 开启要求 `perfusionFileName` 指向一个有效文件，否则设置无效并返回 NO。
- (BOOL)setGlobalModeEnabled:(BOOL)enabled withFileName:(nullable NSString *)fileName;

/// 全局灌流模式当前是否开启。
@property (nonatomic, assign, readonly) BOOL globalModeEnabled;

#pragma mark - 灌流音频文件管理

/// 底层约定的灌流音频目录：Documents/voiceRecord/automaticTest/audioFiles。
+ (NSString *)audioFilesDirectory;

/// 确保灌流目录存在。
+ (BOOL)ensureAudioFilesDirectory;

/// 灌流目录内可用的音频文件名（.wav / .mp3，按名称升序）。
+ (NSArray<NSString *> *)availableAudioFileNames;

/// 把外部音频拷贝进灌流目录，返回落地后的文件名；同名文件会自动追加序号。
+ (nullable NSString *)importAudioFileFromURL:(NSURL *)url error:(NSError **)error;

/// 删除灌流目录内的指定文件。
+ (BOOL)removeAudioFileNamed:(NSString *)fileName error:(NSError **)error;

/// 灌流目录内指定文件的字节大小；文件不存在返回 0。
+ (unsigned long long)fileSizeOfAudioFileNamed:(NSString *)fileName;

/// 解析灌流目录内指定音频的格式；无法解析时 parsed 为 NO。
+ (ThingPerfusionAudioFileInfo *)audioFileInfoWithFileName:(NSString *)fileName;

#pragma mark - 参考答案文本管理

/// 参考答案目录：Documents/voiceRecord/automaticTest/references。
+ (NSString *)referencesDirectory;

/// 参考答案目录内可用的文本文件名（.txt，按名称升序）。
+ (NSArray<NSString *> *)availableReferenceFileNames;

/// 把外部文本拷贝进参考答案目录，返回落地后的文件名；内容相同的同名文件会直接复用。
+ (nullable NSString *)importReferenceFileFromURL:(NSURL *)url error:(NSError **)error;

/// 读取参考答案文本内容；失败返回 nil。
+ (nullable NSString *)referenceTextWithFileName:(NSString *)fileName;

/// 删除参考答案目录内的指定文件。
+ (BOOL)removeReferenceFileNamed:(NSString *)fileName error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
