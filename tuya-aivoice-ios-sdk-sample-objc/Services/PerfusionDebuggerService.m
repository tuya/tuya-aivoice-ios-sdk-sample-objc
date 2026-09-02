//
//  PerfusionDebuggerService.m
//  AIVoiceDemo
//

#import "PerfusionDebuggerService.h"
#import <ThingAudioRecordInterface/ThingAudioRecordInterface.h>
// 底层通过 ThingModule 服务表按协议查找灌流配置提供者，注册入口仅此一条。
#import <ThingModuleManager/ThingModule.h>
// 涂鸦模块框架的编译期服务注册：把实现类写进 Mach-O 段，启动时由 ThingMachRegister 收集。
#import <ThingAnnotationFoundation/ThingAPIAnnotation.h>

/// 灌流音频目录，需与底层 ThingMicrophoneAudioInput 约定的路径保持一致。
static NSString *const kPerfusionAudioDirectoryRelativePath = @"voiceRecord/automaticTest/audioFiles";
/// 参考答案目录，仅本地评测使用，底层不感知。
static NSString *const kPerfusionReferenceDirectoryRelativePath = @"voiceRecord/automaticTest/references";
/// 底层回调 perfusionDataEndWith: 时携带的文件名字段。
static NSString *const kPerfusionEndFileNameKey = @"fileName";

#pragma mark - 配置提供者

/// 底层通过协议获取的实现类。实例可能由框架反复创建，故所有状态都存放在 PerfusionDebuggerService 单例中。
@interface PerfusionDebuggerProvider : NSObject <ThingAIBudsDebuggerProtocol>
@end

@interface PerfusionDebuggerService (ProviderCallback)
/// 供 provider 回报「底层来读过配置」，用于判断注册是否真的生效。
- (void)noteConfigFetched;
@end

// 编译期注册，App 启动即可被底层查到，不依赖页面是否打开。
ThingRegisterAPIAnnotation(ThingAIBudsDebuggerProtocol, PerfusionDebuggerProvider)

@implementation PerfusionDebuggerProvider

- (NSDictionary *)getAppSettingConfigFromTools {
    PerfusionDebuggerService *service = [PerfusionDebuggerService sharedInstance];
    [service noteConfigFetched];
    NSString *fileName = service.perfusionFileName ?: @"";
    // 只提供灌流相关配置，其余调试项交由底层默认值，避免耦合调试工具的完整配置面。
    return @{
        ThingAIBudsSimulateConfigKey_PerfusionData: @(service.perfusionEnabled),
        ThingAIBudsSimulateConfigKey_PerfusionFileName: fileName,
        ThingAIBudsSimulateConfigKey_PerfusionAutoCloseFile: @(service.autoCloseFileWhenPerfusionEnd),
    };
}

- (void)perfusionDataEndWith:(NSDictionary *)params {
    NSString *fileName = [params isKindOfClass:NSDictionary.class] ? params[kPerfusionEndFileNameKey] : nil;
    PerfusionDidEndHandler handler = [PerfusionDebuggerService sharedInstance].didEndHandler;
    if (!handler) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        handler([fileName isKindOfClass:NSString.class] ? fileName : nil);
    });
}

@end

#pragma mark - 服务

@interface PerfusionDebuggerService ()
@property (nonatomic, assign) BOOL providerRegistered;
@property (nonatomic, assign) NSUInteger configFetchCount;
@end

@implementation PerfusionDebuggerService

+ (instancetype)sharedInstance {
    static PerfusionDebuggerService *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[PerfusionDebuggerService alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _autoCloseFileWhenPerfusionEnd = YES;
    }
    return self;
}

#pragma mark - 配置提供者

- (BOOL)registerProvider {
    // 正常情况下注解注册已在启动时生效；这里再补一次运行时注册，覆盖注解未被收集的情况。
    if (!self.providerRegistered && ![self isProviderReady]) {
        [ThingModule registService:PerfusionDebuggerProvider.class
                      withProtocol:@protocol(ThingAIBudsDebuggerProtocol)];
        self.providerRegistered = YES;
    }
    return [self isProviderReady];
}

- (BOOL)isProviderReady {
    id impl = [ThingModule serviceOfOptionalProtocol:@protocol(ThingAIBudsDebuggerProtocol)];
    // 若服务表里是别的实现，本服务的配置同样不会被读到，此时视为未就绪。
    return [impl isKindOfClass:PerfusionDebuggerProvider.class];
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
    self.perfusionEnabled = NO;
    self.perfusionFileName = nil;
    self.didEndHandler = nil;
}

#pragma mark - 灌流音频文件管理

+ (NSString *)audioFilesDirectory {
    NSString *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    return [documents stringByAppendingPathComponent:kPerfusionAudioDirectoryRelativePath];
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
        if (error) *error = [NSError errorWithDomain:@"Perfusion" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"文件地址为空"}];
        return nil;
    }
    if (![self ensureAudioFilesDirectory]) {
        if (error) *error = [NSError errorWithDomain:@"Perfusion" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"灌流目录创建失败"}];
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

+ (PerfusionAudioFileInfo *)audioFileInfoWithFileName:(NSString *)fileName {
    if (fileName.length == 0) return [PerfusionAudioFileInfo infoAtPath:nil];
    NSString *path = [[self audioFilesDirectory] stringByAppendingPathComponent:fileName];
    return [PerfusionAudioFileInfo infoAtPath:path];
}

#pragma mark - 参考答案文本管理

+ (NSString *)referencesDirectory {
    NSString *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    return [documents stringByAppendingPathComponent:kPerfusionReferenceDirectoryRelativePath];
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
        if (error) *error = [NSError errorWithDomain:@"Perfusion" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"文件地址为空"}];
        return nil;
    }
    if (![self ensureReferencesDirectory]) {
        if (error) *error = [NSError errorWithDomain:@"Perfusion" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"参考答案目录创建失败"}];
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
