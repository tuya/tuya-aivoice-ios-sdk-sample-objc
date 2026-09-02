//
//  RegisterViewController.h
//  AIVoiceDemo
//
//  Created by Bacson on 2026/1/28.
//

#import <UIKit/UIKit.h>
#import "CountryModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface RegisterViewController : UIViewController

/** 从登录页带过来的国家/地区，为空时取上次选择或默认值 */
@property (nonatomic, strong, nullable) CountryModel *preselectedCountry;

@end

NS_ASSUME_NONNULL_END
