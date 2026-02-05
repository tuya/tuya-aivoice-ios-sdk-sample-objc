//
//  UIHelper.m
//  AIVoiceDemo
//
//  Created by Bacson on 2026/1/28.
//

#import "UIHelper.h"

@implementation UIHelper

+ (void)showAlertInViewController:(UIViewController *)viewController
                            title:(NSString *)title
                          message:(NSString *)message {
    [self showAlertInViewController:viewController title:title message:message completion:nil];
}

+ (void)showAlertInViewController:(UIViewController *)viewController
                            title:(NSString *)title
                          message:(NSString *)message
                       completion:(void(^_Nullable)(void))completion {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        if (completion) {
            completion();
        }
    }];
    [alert addAction:okAction];
    [viewController presentViewController:alert animated:YES completion:nil];
}

@end
