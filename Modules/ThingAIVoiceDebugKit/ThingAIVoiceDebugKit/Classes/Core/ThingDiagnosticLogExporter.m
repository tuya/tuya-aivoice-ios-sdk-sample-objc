//
//  ThingDiagnosticLogExporter.m
//  ThingAIVoiceDebugKit
//

#import "ThingDiagnosticLogExporter.h"
#import <ThingSmartLogger/ThingLogSDK.h>
#import <SSZipArchive/SSZipArchive.h>

static NSString *const kThingDiagnosticLogErrorDomain = @"ThingDiagnosticLogExporter";

@implementation ThingDiagnosticLogExporter

#pragma mark - Public

+ (void)presentExportFromViewController:(UIViewController *)viewController
                             sourceView:(UIView *)sourceView
                             completion:(ThingDiagnosticLogExportCompletion)completion {
    NSArray<NSString *> *sourcePaths = [self collectLogFilePaths];
    if (sourcePaths.count == 0) {
        [self finishWithResult:ThingDiagnosticLogExportResultNoLogs error:nil completion:completion];
        return;
    }

    NSError *archiveError = nil;
    NSURL *archiveURL = [self archiveLogFilePaths:sourcePaths error:&archiveError];
    if (!archiveURL) {
        [self finishWithResult:ThingDiagnosticLogExportResultFailed error:archiveError completion:completion];
        return;
    }

    UIActivityViewController *activity =
        [[UIActivityViewController alloc] initWithActivityItems:@[archiveURL] applicationActivities:nil];
    // iPad 上必须给出弹出锚点，否则会崩
    activity.popoverPresentationController.sourceView = sourceView;
    activity.popoverPresentationController.sourceRect = sourceView.bounds;

    NSString *archivePath = archiveURL.path;
    activity.completionWithItemsHandler =
        ^(UIActivityType activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
        // 打包的临时 zip 无论成功与否都清理
        [[NSFileManager defaultManager] removeItemAtPath:archivePath error:nil];
        if (completed) {
            // 导出成功后删除原始日志文件
            [self removeLogFilePaths:sourcePaths];
            [self finishWithResult:ThingDiagnosticLogExportResultSuccess error:nil completion:completion];
        } else {
            [self finishWithResult:ThingDiagnosticLogExportResultCancelled error:activityError completion:completion];
        }
    };
    [viewController presentViewController:activity animated:YES completion:nil];
}

+ (NSArray<NSString *> *)collectLogFilePaths {
    NSArray *logPaths = [ThingLogSDK logPath];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSMutableArray<NSString *> *sourcePaths = [NSMutableArray array];

    for (id item in logPaths) {
        if (![item isKindOfClass:[NSString class]]) continue;
        NSString *path = (NSString *)item;
        BOOL isDirectory = NO;
        if (![fileManager fileExistsAtPath:path isDirectory:&isDirectory]) continue;
        if (isDirectory) {
            // 目录则展开其中的文件，逐个加入导出列表
            NSArray<NSString *> *contents = [fileManager contentsOfDirectoryAtPath:path error:nil];
            for (NSString *name in contents) {
                NSString *subPath = [path stringByAppendingPathComponent:name];
                BOOL subIsDir = NO;
                if ([fileManager fileExistsAtPath:subPath isDirectory:&subIsDir] && !subIsDir) {
                    [sourcePaths addObject:subPath];
                }
            }
        } else {
            [sourcePaths addObject:path];
        }
    }

    // 按文件名排序，保证合并顺序稳定
    [sourcePaths sortUsingSelector:@selector(compare:)];
    return sourcePaths;
}

+ (NSURL *)archiveLogFilePaths:(NSArray<NSString *> *)paths error:(NSError **)error {
    if (paths.count == 0) {
        if (error) {
            *error = [NSError errorWithDomain:kThingDiagnosticLogErrorDomain
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: @"没有可打包的日志文件"}];
        }
        return nil;
    }

    NSString *fileName = [NSString stringWithFormat:@"diagnostic_log_%@.zip",
                          @((long)[NSDate date].timeIntervalSince1970)];
    NSString *zipPath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];

    // 日志为加密文件，无法拼接，只把原始文件原样压缩进一个 zip
    BOOL ok = [SSZipArchive createZipFileAtPath:zipPath withFilesAtPaths:paths];
    if (!ok) {
        if (error) {
            *error = [NSError errorWithDomain:kThingDiagnosticLogErrorDomain
                                         code:-2
                                     userInfo:@{NSLocalizedDescriptionKey: @"日志压缩打包失败"}];
        }
        return nil;
    }

    return [NSURL fileURLWithPath:zipPath];
}

+ (void)removeLogFilePaths:(NSArray<NSString *> *)paths {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    for (NSString *path in paths) {
        [fileManager removeItemAtPath:path error:nil];
    }
}

#pragma mark - Private

+ (void)finishWithResult:(ThingDiagnosticLogExportResult)result
                   error:(NSError *)error
              completion:(ThingDiagnosticLogExportCompletion)completion {
    if (!completion) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        completion(result, error);
    });
}

@end
