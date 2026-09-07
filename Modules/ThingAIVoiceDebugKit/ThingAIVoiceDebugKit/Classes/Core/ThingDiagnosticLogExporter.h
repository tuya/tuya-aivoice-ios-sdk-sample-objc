//
//  ThingDiagnosticLogExporter.h
//  ThingAIVoiceDebugKit
//
//  诊断日志导出器：把 ThingLogSDK 的多份加密日志打包成一个 zip，
//  通过系统分享面板导出，导出成功后清理原始日志文件。
//  日志为加密文件，无法拼接，只做原样压缩归档。
//  纯逻辑，无自定义 UI 依赖，可直接集成到客户工程。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 导出结果
typedef NS_ENUM(NSInteger, ThingDiagnosticLogExportResult) {
    ThingDiagnosticLogExportResultNoLogs,     ///< 没有可导出的日志
    ThingDiagnosticLogExportResultFailed,     ///< 合并/写入日志文件失败
    ThingDiagnosticLogExportResultCancelled,  ///< 用户取消了分享
    ThingDiagnosticLogExportResultSuccess,    ///< 导出成功，已删除原始日志文件
};

typedef void (^ThingDiagnosticLogExportCompletion)(ThingDiagnosticLogExportResult result, NSError * _Nullable error);

@interface ThingDiagnosticLogExporter : NSObject

/**
 * 一步导出：收集 -> 合并 -> 弹出系统分享面板 -> 成功后删除原始日志。
 * 这是集成方最常用的入口。
 *
 * @param viewController 用于 present 分享面板的控制器
 * @param sourceView     iPad 上 popover 的锚点视图（iPhone 可传 nil）
 * @param completion     导出结果回调，在主线程执行
 */
+ (void)presentExportFromViewController:(UIViewController *)viewController
                             sourceView:(nullable UIView *)sourceView
                             completion:(nullable ThingDiagnosticLogExportCompletion)completion;

/**
 * 收集 ThingLogSDK 的所有日志文件路径。目录会被展开为其中的文件，
 * 返回结果按文件名升序排列。
 */
+ (NSArray<NSString *> *)collectLogFilePaths;

/**
 * 将给定的日志文件打包成临时目录下的一个 zip。
 * 日志为加密文件，不能拼接文本，只做原样压缩归档。
 *
 * @param paths 待打包的日志文件路径
 * @param error 出参，打包失败时返回错误
 * @return 打包后 zip 文件的 URL；失败或 paths 为空时返回 nil
 */
+ (nullable NSURL *)archiveLogFilePaths:(NSArray<NSString *> *)paths
                                  error:(NSError * _Nullable * _Nullable)error;

/**
 * 删除给定的原始日志文件。
 */
+ (void)removeLogFilePaths:(NSArray<NSString *> *)paths;

@end

NS_ASSUME_NONNULL_END
