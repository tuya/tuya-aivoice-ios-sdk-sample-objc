//
//  ThingPerfusionBaseViewController.h
//  ThingPerfusionKit
//
//  组件页面基类。只提供灌流页需要的最小能力：内容布局参考线与三种弹窗。
//  使用宿主的系统导航栏（设置 self.title 即可），不干预宿主的导航栏风格。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^ThingPerfusionActionHandler)(void);

/// ActionSheet 的一个选项。
@interface ThingPerfusionAlertAction : NSObject

@property (nonatomic, copy, readonly) NSString *title;
@property (nonatomic, assign, readonly, getter=isDestructive) BOOL destructive;
@property (nonatomic, copy, readonly, nullable) ThingPerfusionActionHandler handler;

+ (instancetype)actionWithTitle:(NSString *)title handler:(nullable ThingPerfusionActionHandler)handler;
+ (instancetype)destructiveActionWithTitle:(NSString *)title handler:(nullable ThingPerfusionActionHandler)handler;

@end

@interface ThingPerfusionBaseViewController : UIViewController

/// 内容区域布局参考线（安全区）。
@property (nonatomic, strong, readonly) UILayoutGuide *contentGuide;

/// 单按钮提示。
- (void)showMessageWithTitle:(NSString *)title message:(nullable NSString *)message;

/// 二次确认。
- (void)showConfirmationWithTitle:(NSString *)title
                          message:(nullable NSString *)message
                     confirmTitle:(NSString *)confirmTitle
                      destructive:(BOOL)destructive
                          confirm:(nullable ThingPerfusionActionHandler)confirm;

/// 选项列表。iPad 上会以来源视图为锚点弹出。
- (void)showActionSheetWithTitle:(nullable NSString *)title
                         message:(nullable NSString *)message
                         actions:(NSArray<ThingPerfusionAlertAction *> *)actions;

@end

NS_ASSUME_NONNULL_END
