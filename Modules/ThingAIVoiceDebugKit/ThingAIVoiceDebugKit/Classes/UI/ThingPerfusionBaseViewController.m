//
//  ThingPerfusionBaseViewController.m
//  ThingPerfusionKit
//

#import "ThingPerfusionBaseViewController.h"

@implementation ThingPerfusionAlertAction

+ (instancetype)actionWithTitle:(NSString *)title handler:(nullable ThingPerfusionActionHandler)handler {
    return [self actionWithTitle:title destructive:NO handler:handler];
}

+ (instancetype)destructiveActionWithTitle:(NSString *)title handler:(nullable ThingPerfusionActionHandler)handler {
    return [self actionWithTitle:title destructive:YES handler:handler];
}

+ (instancetype)actionWithTitle:(NSString *)title
                    destructive:(BOOL)destructive
                        handler:(nullable ThingPerfusionActionHandler)handler {
    ThingPerfusionAlertAction *action = [[ThingPerfusionAlertAction alloc] init];
    action->_title = [title copy];
    action->_destructive = destructive;
    action->_handler = [handler copy];
    return action;
}

@end

@implementation ThingPerfusionBaseViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
}

- (UILayoutGuide *)contentGuide {
    return self.view.safeAreaLayoutGuide;
}

#pragma mark - 弹窗

- (void)showMessageWithTitle:(NSString *)title message:(nullable NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                  message:message
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showConfirmationWithTitle:(NSString *)title
                          message:(nullable NSString *)message
                     confirmTitle:(NSString *)confirmTitle
                      destructive:(BOOL)destructive
                          confirm:(nullable ThingPerfusionActionHandler)confirm {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                  message:message
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:confirmTitle
                                             style:destructive ? UIAlertActionStyleDestructive : UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *action) {
        if (confirm) confirm();
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showActionSheetWithTitle:(nullable NSString *)title
                         message:(nullable NSString *)message
                         actions:(NSArray<ThingPerfusionAlertAction *> *)actions {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:title
                                                                  message:message
                                                           preferredStyle:UIAlertControllerStyleActionSheet];
    for (ThingPerfusionAlertAction *item in actions) {
        [sheet addAction:[UIAlertAction actionWithTitle:item.title
                                                 style:item.isDestructive ? UIAlertActionStyleDestructive : UIAlertActionStyleDefault
                                               handler:^(UIAlertAction *action) {
            if (item.handler) item.handler();
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    // iPad 上 ActionSheet 必须有锚点，否则会崩。
    sheet.popoverPresentationController.sourceView = self.view;
    sheet.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds),
                                                                CGRectGetMidY(self.view.bounds), 1, 1);
    [self presentViewController:sheet animated:YES completion:nil];
}

@end
