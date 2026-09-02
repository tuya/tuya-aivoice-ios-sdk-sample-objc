//
//  PerfusionDebuggerService.h
//  AIVoiceDemo
//
//  灌流（Perfusion）能力封装层。
//
//  灌流是把本地音频文件替换麦克风采集数据喂给录音链路的调试手段，用于在不出声的前提下
//  复现 ASR / 翻译 / TTS 全流程。底层通过 ThingAIBudsDebuggerProtocol 向 App 侧索取配置，
//  本服务提供该协议实现，并负责灌流音频目录的管理。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 灌流结束回调。fileName 为底层回传的灌流文件名，回调固定在主线程触发。
typedef void (^PerfusionDidEndHandler)(NSString *_Nullable fileName);

@interface PerfusionDebuggerService : NSObject

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

/// 灌流结束回调。
@property (nonatomic, copy, nullable) PerfusionDidEndHandler didEndHandler;

/// 关闭灌流并清空回调，避免影响后续正常录音。
- (void)reset;

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

@end

NS_ASSUME_NONNULL_END
