//
//  FamilyBaseViewController.h
//  tuya-aivoice-ios-sdk-sample-objc
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^FamilyUIActionHandler)(void);
typedef void (^FamilyUIInputHandler)(NSArray<NSString *> *values);

@interface FamilyUIAction : NSObject
@property (nonatomic, copy, readonly) NSString *title;
@property (nonatomic, assign, readonly, getter=isDestructive) BOOL destructive;
@property (nonatomic, copy, readonly, nullable) FamilyUIActionHandler handler;
+ (instancetype)actionWithTitle:(NSString *)title handler:(nullable FamilyUIActionHandler)handler;
+ (instancetype)destructiveActionWithTitle:(NSString *)title handler:(nullable FamilyUIActionHandler)handler;
@end

/// Shared, app-owned navigation and overlays for custom feature pages.
@interface FamilyBaseViewController : UIViewController

@property (nonatomic, strong, readonly) UILayoutGuide *familyContentGuide;
@property (nonatomic, strong, readonly) UIButton *familyNavigationRightButton;

- (void)configureFamilyNavigationWithTitle:(NSString *)title
                                  leftTitle:(nullable NSString *)leftTitle
                                 leftAction:(nullable FamilyUIActionHandler)leftAction
                                 rightTitle:(nullable NSString *)rightTitle
                                rightAction:(nullable FamilyUIActionHandler)rightAction;
- (void)setFamilyNavigationRightEnabled:(BOOL)enabled;

- (void)styleFamilyTableView:(UITableView *)tableView;
- (void)styleFamilyCell:(UITableViewCell *)cell;
- (UITableViewCell *)dequeueFamilyCardCellFromTableView:(UITableView *)tableView
                                                 style:(UITableViewCellStyle)style
                                            identifier:(NSString *)identifier;
- (void)styleFamilyPrimaryButton:(UIButton *)button;

- (void)showFamilyMessageWithTitle:(NSString *)title message:(nullable NSString *)message;
- (void)showFamilyMessageWithTitle:(NSString *)title message:(nullable NSString *)message completion:(nullable FamilyUIActionHandler)completion;
- (void)showFamilyConfirmationWithTitle:(NSString *)title
                                 message:(nullable NSString *)message
                            confirmTitle:(NSString *)confirmTitle
                             destructive:(BOOL)destructive
                                 confirm:(nullable FamilyUIActionHandler)confirm;
- (void)showFamilyActionSheetWithTitle:(NSString *)title
                                message:(nullable NSString *)message
                                actions:(NSArray<FamilyUIAction *> *)actions;
- (void)showFamilyInputDialogWithTitle:(NSString *)title
                                message:(nullable NSString *)message
                           placeholders:(NSArray<NSString *> *)placeholders
                          initialValues:(nullable NSArray<NSString *> *)initialValues
                          keyboardTypes:(nullable NSArray<NSNumber *> *)keyboardTypes
                           confirmTitle:(NSString *)confirmTitle
                                confirm:(nullable FamilyUIInputHandler)confirm;

- (UIColor *)familyBackgroundColor;
- (UIColor *)familyCardColor;
- (UIColor *)familyPrimaryTextColor;
- (UIColor *)familySecondaryTextColor;
- (UIColor *)familyAccentColor;
- (UIColor *)familyDestructiveColor;
- (UIColor *)familyHairlineColor;

@end

NS_ASSUME_NONNULL_END
