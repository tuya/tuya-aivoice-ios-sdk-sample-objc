//
//  CreateHomeViewController.h
//  AIVoiceDemo
//
//  Created by Bacson on 2026/1/28.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class CreateHomeViewController;

@protocol CreateHomeViewControllerDelegate <NSObject>

- (void)createHomeViewController:(CreateHomeViewController *)controller didCreateHomeSuccess:(BOOL)success;

@end

@interface CreateHomeViewController : UIViewController

@property (nonatomic, weak) id<CreateHomeViewControllerDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
