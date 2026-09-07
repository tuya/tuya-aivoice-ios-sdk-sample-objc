//
//  ThingPerfusionLogStore.m
//  ThingPerfusionKit
//

#import "ThingPerfusionLogStore.h"

NSNotificationName const ThingPerfusionLogDidAppendNotification = @"ThingPerfusionLogDidAppendNotification";

/// 日志上限。需要导出完整过程，所以比页面展示需要的量放宽不少。
static const NSUInteger kThingPerfusionMaxLogCount = 5000;

@interface ThingPerfusionLogStore ()
@property (nonatomic, strong) NSMutableArray<NSString *> *storage;
/// 串行队列保护数组，回调可能来自任意线程。
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) NSDateFormatter *formatter;
@end

@implementation ThingPerfusionLogStore

+ (instancetype)sharedInstance {
    static ThingPerfusionLogStore *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[ThingPerfusionLogStore alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _storage = [NSMutableArray array];
        _queue = dispatch_queue_create("com.thing.perfusion.log", DISPATCH_QUEUE_SERIAL);
        _formatter = [[NSDateFormatter alloc] init];
        _formatter.dateFormat = @"HH:mm:ss.SSS";
    }
    return self;
}

- (NSArray<NSString *> *)entries {
    __block NSArray *result = nil;
    dispatch_sync(self.queue, ^{
        result = [self.storage copy];
    });
    return result;
}

- (void)append:(NSString *)message {
    if (message.length == 0) return;
    NSString *entry = [NSString stringWithFormat:@"[%@] %@",
                       [self.formatter stringFromDate:NSDate.date], message];
    dispatch_async(self.queue, ^{
        [self.storage addObject:entry];
        if (self.storage.count > kThingPerfusionMaxLogCount) {
            [self.storage removeObjectsInRange:NSMakeRange(0, self.storage.count - kThingPerfusionMaxLogCount)];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSNotificationCenter.defaultCenter postNotificationName:ThingPerfusionLogDidAppendNotification
                                                              object:entry];
        });
    });
}

- (void)appendFormat:(NSString *)format, ... {
    if (format.length == 0) return;
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    [self append:message];
}

- (void)clear {
    dispatch_async(self.queue, ^{
        [self.storage removeAllObjects];
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSNotificationCenter.defaultCenter postNotificationName:ThingPerfusionLogDidAppendNotification
                                                              object:nil];
        });
    });
}

- (NSString *)exportText {
    return [self.entries componentsJoinedByString:@"\n"];
}

+ (NSString *)logsDirectory {
    NSString *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    return [documents stringByAppendingPathComponent:@"voiceRecord/automaticTest/logs"];
}

- (nullable NSURL *)writeToFileWithError:(NSError **)error {
    NSString *directory = [ThingPerfusionLogStore logsDirectory];
    NSFileManager *manager = NSFileManager.defaultManager;
    if (![manager fileExistsAtPath:directory] &&
        ![manager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:error]) {
        return nil;
    }

    NSDateFormatter *nameFormatter = [[NSDateFormatter alloc] init];
    nameFormatter.dateFormat = @"yyyyMMdd_HHmmss";
    NSString *fileName = [NSString stringWithFormat:@"灌流日志_%@.txt", [nameFormatter stringFromDate:NSDate.date]];
    NSString *path = [directory stringByAppendingPathComponent:fileName];

    NSMutableString *content = [NSMutableString string];
    [content appendString:@"灌流事件日志\n"];
    [content appendFormat:@"导出时间：%@\n", NSDate.date];
    [content appendFormat:@"共 %lu 条\n", (unsigned long)self.entries.count];
    [content appendString:@"记录内容：SDK 调用与回调事件（start/stop、录音状态、实时识别结果、灌流配置回读、WER 结果）\n"];
    [content appendString:@"------------------------------------------------------------\n"];
    [content appendString:[self exportText]];

    if (![content writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:error]) return nil;
    return [NSURL fileURLWithPath:path];
}

@end
