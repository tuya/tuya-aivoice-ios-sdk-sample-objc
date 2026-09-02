//
//  CountryPickerViewController.h
//  AIVoiceDemo
//
//  国家/地区选择器：按大区分组展示，支持搜索。
//

#import <UIKit/UIKit.h>
#import "CountryModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface CountryPickerViewController : UIViewController

/** 当前选中的国家，用于列表回显勾选状态 */
@property (nonatomic, strong, nullable) CountryModel *selectedCountry;

/** 选中回调，在主线程调用 */
@property (nonatomic, copy, nullable) void (^didSelectCountry)(CountryModel *country);

@end

NS_ASSUME_NONNULL_END
