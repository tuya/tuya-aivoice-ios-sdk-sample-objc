//
//  UIHelper.h
//  AIVoiceDemo
//
//  Created by Bacson on 2026/1/28.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIHelper : NSObject

+ (void)showAlertInViewController:(UIViewController *)viewController
                            title:(NSString *)title
                          message:(NSString *)message;

+ (void)showAlertInViewController:(UIViewController *)viewController
                            title:(NSString *)title
                          message:(NSString *)message
                       completion:(void(^_Nullable)(void))completion;

@end

NS_ASSUME_NONNULL_END
