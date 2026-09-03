//
//  ThingPerfusionService.m
//  AIVoiceDemo
//

#import "ThingPerfusionService.h"
#import <ThingAudioRecordInterface/ThingAudioRecordInterface.h>
// 底层通过 ThingModule 服务表按协议查找灌流配置提供者，注册入口仅此一条。
#import <ThingModuleManager/ThingModule.h>
// 涂鸦模块框架的编译期服务注册：把实现类写进 Mach-O 段，启动时由 ThingMachRegister 收集。
#import <ThingAnnotationFoundation/ThingAPIAnnotation.h>

/// 灌流音频目录，需与底层 ThingMicrophoneAudioInput 约定的路径保持一致。
static NSString *const kThingPerfusionAudioDirectoryRelativePath = @"voiceRecord/automaticTest/audioFiles";
/// 参考答案目录，仅本地评测使用，底层不感知。
static NSString *const kThingPerfusionReferenceDirectoryRelativePath = @"voiceRecord/automaticTest/references";
/// 底层回调 perfusionDataEndWith: 时携带的文件名字段。
static NSString *const kThingPerfusionEndFileNameKey = @"fileName";
/// 全局灌流模式的持久化键。
static NSString *const kThingPerfusionGlobalModeKey = @"ThingPerfusionKit.globalMode";
static NSString *const kThingPerfusionGlobalFileNameKey = @"ThingPerfusionKit.globalFileName";
/// 链路参数的持久化键。全局模式跨启动保留，这两项也要跟着保留，否则重启后配置不一致。
static NSString *const kThingPerfusionUpstreamFormatKey = @"ThingPerfusionKit.upstreamFormat";
static NSString *const kThingPerfusionAudio3APresetKey = @"ThingPerfusionKit.audio3APreset";

NSNotificationName const ThingPerfusionDidEndNotification = @"ThingPerfusionDidEndNotification";

#pragma mark - 配置提供者

/// 底层通过协议获取的实现类。实例可能由框架反复创建，故所有状态都存放在 ThingPerfusionService 单例中。
@interface ThingPerfusionConfigProvider : NSObject <ThingAIBudsDebuggerProtocol>
@end

@interface ThingPerfusionService (ProviderCallback)
/// 供 provider 回报「底层来读过配置」，用于判断注册是否真的生效。
- (void)noteConfigFetched;
@end

// 编译期注册，App 启动即可被底层查到，不依赖页面是否打开。
ThingRegisterAPIAnnotation(ThingAIBudsDebuggerProtocol, ThingPerfusionConfigProvider)

@implementation ThingPerfusionConfigProvider

- (NSDictionary *)getAppSettingConfigFromTools {
    ThingPerfusionService *service = [ThingPerfusionService sharedInstance];
    [service noteConfigFetched];
    NSString *fileName = service.perfusionFileName ?: @"";

    // 3A 与上行流格式必须完整提供：底层 _updateTaskConfig: 拿到非空字典后会用其中的值
    // 整体覆盖调用方传入的配置，缺键会被当成 NO / 0（即 3A 全关、上行流降级为 PCM），
    // 并连带影响其它调用方（例如小程序内发起的录音）。
    BOOL rnAns = NO, ans = NO, agc = NO, aec = NO;
    NSInteger ansLevel = 0;
    switch (service.audio3APreset) {
        case ThingPerfusionAudio3APresetOff:
            break;
        case ThingPerfusionAudio3APresetAGCOnly:
            agc = YES;
            break;
        case ThingPerfusionAudio3APresetFull:
            rnAns = YES; ans = YES; agc = YES; aec = YES; ansLevel = 1;
            break;
    }

    return @{
        // 灌流
        ThingAIBudsSimulateConfigKey_PerfusionData: @(service.perfusionEnabled),
        ThingAIBudsSimulateConfigKey_PerfusionFileName: fileName,
        ThingAIBudsSimulateConfigKey_PerfusionAutoCloseFile: @(service.autoCloseFileWhenPerfusionEnd),
        // 上行流格式
        ThingAIBudsSimulateConfigKey_UpstreamFormatter: @(service.upstreamFormat),
        // 3A
        ThingAIBudsSimulateConfigKey_RNNoise: @(rnAns),
        ThingAIBudsSimulateConfigKey_ANC: @(ans),
        ThingAIBudsSimulateConfigKey_ANCLevel: @(ansLevel),
        ThingAIBudsSimulateConfigKey_AGC: @(agc),
        ThingAIBudsSimulateConfigKey_AEC: @(aec),
    };
}

- (void)perfusionDataEndWith:(NSDictionary *)params {
    NSString *raw = [params isKindOfClass:NSDictionary.class] ? params[kThingPerfusionEndFileNameKey] : nil;
    NSString *fileName = [raw isKindOfClass:NSString.class] ? raw : nil;
    ThingPerfusionDidEndHandler handler = [ThingPerfusionService sharedInstance].didEndHandler;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (handler) handler(fileName);
        // 全局模式下往往没有页面接管（例如小程序内录音），用通知兜底。
        [NSNotificationCenter.defaultCenter postNotificationName:ThingPerfusionDidEndNotification
                                                          object:nil
                                                        userInfo:fileName ? @{kThingPerfusionEndFileNameKey: fileName} : @{}];
    });
}

@end

#pragma mark - 服务

@interface ThingPerfusionService ()
@property (nonatomic, assign) BOOL providerRegistered;
@property (nonatomic, assign) NSUInteger configFetchCount;
@property (nonatomic, assign) BOOL globalModeEnabled;
@end

@implementation ThingPerfusionService

+ (instancetype)sharedInstance {
    static ThingPerfusionService *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[ThingPerfusionService alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _autoCloseFileWhenPerfusionEnd = YES;
        // 与底层未接入调试工具时的默认值一致，避免悄悄改变链路行为。
        _upstreamFormat = ThingPerfusionUpstreamFormatOpus;
        _audio3APreset = ThingPerfusionAudio3APresetOff;
        [self restoreLinkParameters];
        [self restoreGlobalModeIfNeeded];
    }
    return self;
}

/// 恢复上次的链路参数；没存过则保持默认（Opus / 3A 全关）。
- (void)restoreLinkParameters {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if ([defaults objectForKey:kThingPerfusionUpstreamFormatKey]) {
        NSInteger value = [defaults integerForKey:kThingPerfusionUpstreamFormatKey];
        _upstreamFormat = (value == ThingPerfusionUpstreamFormatPCM)
            ? ThingPerfusionUpstreamFormatPCM
            : ThingPerfusionUpstreamFormatOpus;
    }
    if ([defaults objectForKey:kThingPerfusionAudio3APresetKey]) {
        NSInteger value = [defaults integerForKey:kThingPerfusionAudio3APresetKey];
        if (value >= ThingPerfusionAudio3APresetOff && value <= ThingPerfusionAudio3APresetFull) {
            _audio3APreset = (ThingPerfusionAudio3APreset)value;
        }
    }
}

- (void)setUpstreamFormat:(ThingPerfusionUpstreamFormat)upstreamFormat {
    _upstreamFormat = upstreamFormat;
    [NSUserDefaults.standardUserDefaults setInteger:upstreamFormat forKey:kThingPerfusionUpstreamFormatKey];
}

- (void)setAudio3APreset:(ThingPerfusionAudio3APreset)audio3APreset {
    _audio3APreset = audio3APreset;
    [NSUserDefaults.standardUserDefaults setInteger:audio3APreset forKey:kThingPerfusionAudio3APresetKey];
}

/// 恢复上次的全局灌流模式。文件已被删除时自动关闭，避免开着一个无效开关。
- (void)restoreGlobalModeIfNeeded {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if (![defaults boolForKey:kThingPerfusionGlobalModeKey]) return;

    NSString *fileName = [defaults stringForKey:kThingPerfusionGlobalFileNameKey];
    if (fileName.length == 0 || ![[ThingPerfusionService availableAudioFileNames] containsObject:fileName]) {
        [defaults setBool:NO forKey:kThingPerfusionGlobalModeKey];
        [defaults removeObjectForKey:kThingPerfusionGlobalFileNameKey];
        return;
    }
    _globalModeEnabled = YES;
    _perfusionFileName = fileName;
    _perfusionEnabled = YES;
}

#pragma mark - 配置提供者

- (BOOL)registerProvider {
    // 正常情况下注解注册已在启动时生效；这里再补一次运行时注册，覆盖注解未被收集的情况。
    if (!self.providerRegistered && ![self isProviderReady]) {
        [ThingModule registService:ThingPerfusionConfigProvider.class
                      withProtocol:@protocol(ThingAIBudsDebuggerProtocol)];
        self.providerRegistered = YES;
    }
    return [self isProviderReady];
}

- (BOOL)isProviderReady {
    id impl = [ThingModule serviceOfOptionalProtocol:@protocol(ThingAIBudsDebuggerProtocol)];
    // 若服务表里是别的实现，本服务的配置同样不会被读到，此时视为未就绪。
    return [impl isKindOfClass:ThingPerfusionConfigProvider.class];
}

- (nullable NSString *)currentProviderClassName {
    id impl = [ThingModule serviceOfOptionalProtocol:@protocol(ThingAIBudsDebuggerProtocol)];
    return impl ? NSStringFromClass([impl class]) : nil;
}

- (void)noteConfigFetched {
    @synchronized (self) {
        self.configFetchCount = self.configFetchCount + 1;
    }
}

- (void)resetConfigFetchCount {
    @synchronized (self) {
        self.configFetchCount = 0;
    }
}

- (void)reset {
    self.didEndHandler = nil;
    // 全局模式是显式开启的长期状态，不能被单次灌流的收尾关掉。
    if (self.globalModeEnabled) return;
    self.perfusionEnabled = NO;
    self.perfusionFileName = nil;
}

+ (NSString *)inputFileFormatRequirement {
    return @"灌流输入文件必须是整型 PCM 的 WAV（16kHz / 16bit / 单声道）。"
            "底层 replaceCaptureData 只解整型 PCM，不支持 Opus / mp3 / IEEE float。"
            "上行流格式（PCM / Opus）是另一件事，指采集之后发往云端的编码，可单独设置。";
}

#pragma mark - 全局灌流模式

- (BOOL)setGlobalModeEnabled:(BOOL)enabled withFileName:(nullable NSString *)fileName {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;

    if (!enabled) {
        self.globalModeEnabled = NO;
        self.perfusionEnabled = NO;
        [defaults setBool:NO forKey:kThingPerfusionGlobalModeKey];
        [defaults removeObjectForKey:kThingPerfusionGlobalFileNameKey];
        return YES;
    }

    // 开启必须有有效文件，否则底层读不到文件名，灌流不会生效。
    if (fileName.length == 0 || ![[ThingPerfusionService availableAudioFileNames] containsObject:fileName]) {
        return NO;
    }
    self.globalModeEnabled = YES;
    self.perfusionFileName = fileName;
    self.perfusionEnabled = YES;
    [defaults setBool:YES forKey:kThingPerfusionGlobalModeKey];
    [defaults setObject:fileName forKey:kThingPerfusionGlobalFileNameKey];
    return YES;
}

#pragma mark - 灌流音频文件管理

+ (NSString *)audioFilesDirectory {
    NSString *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    return [documents stringByAppendingPathComponent:kThingPerfusionAudioDirectoryRelativePath];
}

+ (BOOL)ensureAudioFilesDirectory {
    NSString *directory = [self audioFilesDirectory];
    NSFileManager *manager = NSFileManager.defaultManager;
    if ([manager fileExistsAtPath:directory]) return YES;
    return [manager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
}

+ (NSArray<NSString *> *)availableAudioFileNames {
    [self ensureAudioFilesDirectory];
    NSArray<NSString *> *contents = [NSFileManager.defaultManager contentsOfDirectoryAtPath:[self audioFilesDirectory]
                                                                                     error:nil];
    NSMutableArray<NSString *> *files = [NSMutableArray array];
    for (NSString *name in contents) {
        NSString *lowercase = name.lowercaseString;
        // 底层灌流仅支持 wav / mp3。
        if ([lowercase hasSuffix:@".wav"] || [lowercase hasSuffix:@".mp3"]) [files addObject:name];
    }
    [files sortUsingSelector:@selector(compare:)];
    return files;
}

+ (nullable NSString *)importAudioFileFromURL:(NSURL *)url error:(NSError **)error {
    if (!url) {
        if (error) *error = [NSError errorWithDomain:@"ThingPerfusionKit" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"文件地址为空"}];
        return nil;
    }
    if (![self ensureAudioFilesDirectory]) {
        if (error) *error = [NSError errorWithDomain:@"ThingPerfusionKit" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"灌流目录创建失败"}];
        return nil;
    }

    // 文件 App 返回的 URL 需要先获取安全访问权限。
    BOOL scoped = [url startAccessingSecurityScopedResource];
    NSData *data = [NSData dataWithContentsOfURL:url options:NSDataReadingMappedIfSafe error:error];
    if (scoped) [url stopAccessingSecurityScopedResource];
    if (!data) return nil;

    NSString *fileName = url.lastPathComponent ?: @"perfusion.wav";
    NSString *base = fileName.stringByDeletingPathExtension;
    NSString *extension = fileName.pathExtension.length > 0 ? fileName.pathExtension : @"wav";
    NSString *directory = [self audioFilesDirectory];

    // 反复选择同一个文件时直接复用已落地的副本，避免目录里堆出一串同名序号文件。
    if ([self fileSizeOfAudioFileNamed:fileName] == data.length) {
        return fileName;
    }

    NSString *candidate = fileName;
    NSUInteger index = 1;
    // 同名但内容不同则追加序号，避免覆盖既有灌流素材。
    while ([NSFileManager.defaultManager fileExistsAtPath:[directory stringByAppendingPathComponent:candidate]]) {
        candidate = [NSString stringWithFormat:@"%@_%lu.%@", base, (unsigned long)index++, extension];
    }

    NSString *destination = [directory stringByAppendingPathComponent:candidate];
    if (![data writeToFile:destination options:NSDataWritingAtomic error:error]) return nil;
    return candidate;
}

+ (BOOL)removeAudioFileNamed:(NSString *)fileName error:(NSError **)error {
    if (fileName.length == 0) return NO;
    NSString *path = [[self audioFilesDirectory] stringByAppendingPathComponent:fileName];
    return [NSFileManager.defaultManager removeItemAtPath:path error:error];
}

+ (unsigned long long)fileSizeOfAudioFileNamed:(NSString *)fileName {
    if (fileName.length == 0) return 0;
    NSString *path = [[self audioFilesDirectory] stringByAppendingPathComponent:fileName];
    NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
    return attributes ? [attributes fileSize] : 0;
}

+ (ThingPerfusionAudioFileInfo *)audioFileInfoWithFileName:(NSString *)fileName {
    if (fileName.length == 0) return [ThingPerfusionAudioFileInfo infoAtPath:nil];
    NSString *path = [[self audioFilesDirectory] stringByAppendingPathComponent:fileName];
    return [ThingPerfusionAudioFileInfo infoAtPath:path];
}

#pragma mark - 参考答案文本管理

+ (NSString *)referencesDirectory {
    NSString *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    return [documents stringByAppendingPathComponent:kThingPerfusionReferenceDirectoryRelativePath];
}

+ (BOOL)ensureReferencesDirectory {
    NSString *directory = [self referencesDirectory];
    NSFileManager *manager = NSFileManager.defaultManager;
    if ([manager fileExistsAtPath:directory]) return YES;
    return [manager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
}

+ (NSArray<NSString *> *)availableReferenceFileNames {
    [self ensureReferencesDirectory];
    NSArray<NSString *> *contents = [NSFileManager.defaultManager contentsOfDirectoryAtPath:[self referencesDirectory]
                                                                                     error:nil];
    NSMutableArray<NSString *> *files = [NSMutableArray array];
    for (NSString *name in contents) {
        if ([name.lowercaseString hasSuffix:@".txt"]) [files addObject:name];
    }
    [files sortUsingSelector:@selector(compare:)];
    return files;
}

+ (nullable NSString *)importReferenceFileFromURL:(NSURL *)url error:(NSError **)error {
    if (!url) {
        if (error) *error = [NSError errorWithDomain:@"ThingPerfusionKit" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"文件地址为空"}];
        return nil;
    }
    if (![self ensureReferencesDirectory]) {
        if (error) *error = [NSError errorWithDomain:@"ThingPerfusionKit" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"参考答案目录创建失败"}];
        return nil;
    }

    BOOL scoped = [url startAccessingSecurityScopedResource];
    NSData *data = [NSData dataWithContentsOfURL:url options:NSDataReadingMappedIfSafe error:error];
    if (scoped) [url stopAccessingSecurityScopedResource];
    if (!data) return nil;

    NSString *fileName = url.lastPathComponent ?: @"reference.txt";
    NSString *base = fileName.stringByDeletingPathExtension;
    NSString *extension = fileName.pathExtension.length > 0 ? fileName.pathExtension : @"txt";
    NSString *directory = [self referencesDirectory];

    // 与灌流音频一致：内容相同的同名文件直接复用，避免目录里堆副本。
    NSString *existing = [directory stringByAppendingPathComponent:fileName];
    NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:existing error:nil];
    if (attributes && [attributes fileSize] == data.length) return fileName;

    NSString *candidate = fileName;
    NSUInteger index = 1;
    while ([NSFileManager.defaultManager fileExistsAtPath:[directory stringByAppendingPathComponent:candidate]]) {
        candidate = [NSString stringWithFormat:@"%@_%lu.%@", base, (unsigned long)index++, extension];
    }

    NSString *destination = [directory stringByAppendingPathComponent:candidate];
    if (![data writeToFile:destination options:NSDataWritingAtomic error:error]) return nil;
    return candidate;
}

+ (nullable NSString *)referenceTextWithFileName:(NSString *)fileName {
    if (fileName.length == 0) return nil;
    NSString *path = [[self referencesDirectory] stringByAppendingPathComponent:fileName];
    NSError *error = nil;
    NSString *text = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    if (text) return text;
    // 参考答案常来自不同来源，UTF-8 读失败时按系统猜测编码兜底。
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) return nil;
    NSString *fallback = nil;
    [NSString stringEncodingForData:data encodingOptions:nil convertedString:&fallback usedLossyConversion:nil];
    return fallback;
}

+ (BOOL)removeReferenceFileNamed:(NSString *)fileName error:(NSError **)error {
    if (fileName.length == 0) return NO;
    NSString *path = [[self referencesDirectory] stringByAppendingPathComponent:fileName];
    return [NSFileManager.defaultManager removeItemAtPath:path error:error];
}

@end
