//
//  LoginViewController.m
//  AIVoiceDemo
//
//  Created by Bacson on 2026/1/28.
//

#import "LoginViewController.h"
#import "RegisterViewController.h"
#import "MainTabBarController.h"
#import "CountryPickerViewController.h"
#import "CountryModel.h"
#import "AuthService.h"
#import "UIHelper.h"
#import <ThingSmartBaseKit/ThingSmartBaseKit.h>
#import <ThingSmartDeviceKit/ThingSmartDeviceKit.h>

/** 账号类型：手机号 / 邮箱 */
typedef NS_ENUM(NSInteger, LoginAccountType) {
    LoginAccountTypePhone = 0,
    LoginAccountTypeEmail = 1,
};

@interface LoginViewController ()

@property (nonatomic, strong) UISegmentedControl *accountTypeSegment;
@property (nonatomic, strong) UIButton *countryButton;
@property (nonatomic, strong) UITextField *accountTextField;
@property (nonatomic, strong) UITextField *passwordTextField;
@property (nonatomic, strong) UIButton *loginButton;
@property (nonatomic, strong) UIButton *registerButton;

@property (nonatomic, strong) CountryModel *selectedCountry;
@property (nonatomic, assign) LoginAccountType accountType;

@end

@implementation LoginViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.selectedCountry = [CountryModel lastSelectedCountry];
    self.accountType = LoginAccountTypePhone;

    [self setupUI];
    [self setupDismissKeyboardGesture];
    [self updateCountryButtonTitle];
    [self updateAccountFieldForAccountType];
}

- (void)setupUI {
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    // 标题
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"登录";
    titleLabel.font = [UIFont boldSystemFontOfSize:32];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:titleLabel];

    // 账号类型切换：手机号 / 邮箱
    self.accountTypeSegment = [[UISegmentedControl alloc] initWithItems:@[@"手机号", @"邮箱"]];
    self.accountTypeSegment.selectedSegmentIndex = LoginAccountTypePhone;
    self.accountTypeSegment.translatesAutoresizingMaskIntoConstraints = NO;
    [self.accountTypeSegment addTarget:self action:@selector(accountTypeChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.accountTypeSegment];

    // 国家/地区选择（点击弹出列表，无需手动输入国家码）
    self.countryButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.countryButton.titleLabel.font = [UIFont systemFontOfSize:16];
    self.countryButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    self.countryButton.contentEdgeInsets = UIEdgeInsetsMake(0, 12, 0, 12);
    self.countryButton.backgroundColor = [UIColor secondarySystemBackgroundColor];
    [self.countryButton setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
    self.countryButton.layer.cornerRadius = 8;
    self.countryButton.layer.borderWidth = 1;
    self.countryButton.layer.borderColor = [UIColor separatorColor].CGColor;
    self.countryButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.countryButton addTarget:self action:@selector(countryButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.countryButton];

    // 账号输入框（手机号或邮箱）
    self.accountTextField = [[UITextField alloc] init];
    self.accountTextField.borderStyle = UITextBorderStyleRoundedRect;
    self.accountTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.accountTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.accountTextField.text = @"";
    self.accountTextField.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.accountTextField];
    
    // 密码输入框
    self.passwordTextField = [[UITextField alloc] init];
    self.passwordTextField.placeholder = @"请输入密码";
    self.passwordTextField.borderStyle = UITextBorderStyleRoundedRect;
    self.passwordTextField.secureTextEntry = YES;
    self.passwordTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.passwordTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.passwordTextField.text = @"";
    self.passwordTextField.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.passwordTextField];
    
    // 登录按钮
    self.loginButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.loginButton setTitle:@"登录" forState:UIControlStateNormal];
    self.loginButton.titleLabel.font = [UIFont systemFontOfSize:18];
    self.loginButton.backgroundColor = [UIColor systemBlueColor];
    [self.loginButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.loginButton.layer.cornerRadius = 8;
    self.loginButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.loginButton addTarget:self action:@selector(loginButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.loginButton];
    
    // 注册按钮
    self.registerButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.registerButton setTitle:@"去注册" forState:UIControlStateNormal];
    self.registerButton.titleLabel.font = [UIFont systemFontOfSize:16];
    [self.registerButton setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
    self.registerButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.registerButton addTarget:self action:@selector(registerButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.registerButton];
    
    // 布局约束
    [NSLayoutConstraint activateConstraints:@[
        // 标题
        [titleLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:80],
        [titleLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],

        // 账号类型切换
        [self.accountTypeSegment.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:30],
        [self.accountTypeSegment.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:40],
        [self.accountTypeSegment.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-40],
        [self.accountTypeSegment.heightAnchor constraintEqualToConstant:36],

        // 国家/地区选择
        [self.countryButton.topAnchor constraintEqualToAnchor:self.accountTypeSegment.bottomAnchor constant:20],
        [self.countryButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:40],
        [self.countryButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-40],
        [self.countryButton.heightAnchor constraintEqualToConstant:50],

        // 账号输入框
        [self.accountTextField.topAnchor constraintEqualToAnchor:self.countryButton.bottomAnchor constant:20],
        [self.accountTextField.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:40],
        [self.accountTextField.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-40],
        [self.accountTextField.heightAnchor constraintEqualToConstant:50],
        
        // 密码输入框
        [self.passwordTextField.topAnchor constraintEqualToAnchor:self.accountTextField.bottomAnchor constant:20],
        [self.passwordTextField.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:40],
        [self.passwordTextField.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-40],
        [self.passwordTextField.heightAnchor constraintEqualToConstant:50],
        
        // 登录按钮
        [self.loginButton.topAnchor constraintEqualToAnchor:self.passwordTextField.bottomAnchor constant:30],
        [self.loginButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:40],
        [self.loginButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-40],
        [self.loginButton.heightAnchor constraintEqualToConstant:50],
        
        // 注册按钮
        [self.registerButton.topAnchor constraintEqualToAnchor:self.loginButton.bottomAnchor constant:20],
        [self.registerButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
    ]];
}

#pragma mark - 键盘

/** 点击空白处收起键盘 */
- (void)setupDismissKeyboardGesture {
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                          action:@selector(dismissKeyboard)];
    // 不拦截按钮等控件的点击事件
    tap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tap];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillChangeFrame:)
                                                 name:UIKeyboardWillChangeFrameNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
}

- (void)dismissKeyboard {
    [self.view endEditing:YES];
}

/** 键盘弹出时，若遮挡了主按钮则整体上移 */
- (void)keyboardWillChangeFrame:(NSNotification *)notification {
    CGRect keyboardFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    // 根视图铺满整个窗口，按钮 frame 与屏幕坐标一致，直接比较即可（避免受当前 transform 影响）
    // 主按钮底部再留 20pt 间距
    CGFloat contentBottom = CGRectGetMaxY(self.registerButton.frame) + 20;
    CGFloat overlap = contentBottom - CGRectGetMinY(keyboardFrame);

    CGAffineTransform target = overlap > 0 ? CGAffineTransformMakeTranslation(0, -overlap) : CGAffineTransformIdentity;
    [self animateViewTransform:target withNotification:notification];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    [self animateViewTransform:CGAffineTransformIdentity withNotification:notification];
}

- (void)animateViewTransform:(CGAffineTransform)transform withNotification:(NSNotification *)notification {
    if (CGAffineTransformEqualToTransform(self.view.transform, transform)) {
        return;
    }
    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    [UIView animateWithDuration:duration > 0 ? duration : 0.25 animations:^{
        self.view.transform = transform;
    }];
}

#pragma mark - 账号类型 / 国家

- (void)accountTypeChanged:(UISegmentedControl *)sender {
    self.accountType = (LoginAccountType)sender.selectedSegmentIndex;
    [self updateAccountFieldForAccountType];
}

- (void)updateAccountFieldForAccountType {
    if (self.accountType == LoginAccountTypeEmail) {
        self.accountTextField.placeholder = @"请输入邮箱";
        self.accountTextField.keyboardType = UIKeyboardTypeEmailAddress;
        self.accountTextField.textContentType = UITextContentTypeEmailAddress;
    } else {
        self.accountTextField.placeholder = @"请输入手机号";
        self.accountTextField.keyboardType = UIKeyboardTypePhonePad;
        self.accountTextField.textContentType = UITextContentTypeTelephoneNumber;
    }
    // 切换键盘类型后需要 reload 才能立即生效
    if (self.accountTextField.isFirstResponder) {
        [self.accountTextField reloadInputViews];
    }
}

- (void)updateCountryButtonTitle {
    NSString *title = [NSString stringWithFormat:@"%@  ▾", self.selectedCountry.displayText];
    [self.countryButton setTitle:title forState:UIControlStateNormal];
}

- (void)countryButtonTapped:(UIButton *)sender {
    CountryPickerViewController *pickerVC = [[CountryPickerViewController alloc] init];
    pickerVC.selectedCountry = self.selectedCountry;
    __weak typeof(self) weakSelf = self;
    pickerVC.didSelectCountry = ^(CountryModel *country) {
        weakSelf.selectedCountry = country;
        [weakSelf updateCountryButtonTitle];
    };
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:pickerVC];
    [self presentViewController:navController animated:YES completion:nil];
}

#pragma mark - 登录

- (void)loginButtonTapped:(UIButton *)sender {
    NSString *countryCode = self.selectedCountry.countryCode;
    NSString *account = [self.accountTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString *password = [self.passwordTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    BOOL isEmail = (self.accountType == LoginAccountTypeEmail);

    // 输入验证
    if (countryCode.length == 0) {
        [UIHelper showAlertInViewController:self title:@"提示" message:@"请选择国家/地区"];
        return;
    }
    
    if (account.length == 0) {
        [UIHelper showAlertInViewController:self title:@"提示" message:isEmail ? @"请输入邮箱" : @"请输入手机号"];
        return;
    }

    if (isEmail && ![self isValidEmail:account]) {
        [UIHelper showAlertInViewController:self title:@"提示" message:@"邮箱格式不正确"];
        return;
    }
    
    if (password.length == 0) {
        [UIHelper showAlertInViewController:self title:@"提示" message:@"请输入密码"];
        return;
    }
    
    // 禁用按钮，防止重复点击
    self.loginButton.enabled = NO;
    [self.loginButton setTitle:@"登录中..." forState:UIControlStateNormal];

    __weak typeof(self) weakSelf = self;
    void (^successBlock)(void) = ^{
        // 登录成功
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            strongSelf.loginButton.enabled = YES;
            [strongSelf.loginButton setTitle:@"登录" forState:UIControlStateNormal];
            // 跳转到主页面
            [strongSelf navigateToMainPage];
        });
    };
    void (^failureBlock)(NSError *) = ^(NSError *error) {
        // 登录失败
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            strongSelf.loginButton.enabled = YES;
            [strongSelf.loginButton setTitle:@"登录" forState:UIControlStateNormal];
            NSString *errorMessage = error.localizedDescription ?: @"登录失败，请重试";
            [UIHelper showAlertInViewController:strongSelf title:@"登录失败" message:errorMessage];
        });
    };

    // 调用登录服务
    if (isEmail) {
        [[AuthService sharedInstance] loginByEmail:countryCode
                                             email:account
                                          password:password
                                           success:successBlock
                                           failure:failureBlock];
    } else {
        [[AuthService sharedInstance] loginByPhone:countryCode
                                       phoneNumber:account
                                          password:password
                                           success:successBlock
                                           failure:failureBlock];
    }
}

- (BOOL)isValidEmail:(NSString *)email {
    NSString *pattern = @"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$";
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", pattern];
    return [predicate evaluateWithObject:email];
}

- (void)registerButtonTapped:(UIButton *)sender {
    // 跳转到注册页面，带上当前选择的国家
    RegisterViewController *registerVC = [[RegisterViewController alloc] init];
    registerVC.preselectedCountry = self.selectedCountry;
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:registerVC];
    navController.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:navController animated:YES completion:nil];
}

- (void)navigateToMainPage {
    NSLog(@"navigateToMainPage 被调用，当前线程: %@", [NSThread isMainThread] ? @"主线程" : @"后台线程");
    
    // 确保在主线程执行
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self navigateToMainPage];
        });
        return;
    }
    
    // 跳转到首页（带底部 Tab：首页 / 我的）
    MainTabBarController *tabBar = [[MainTabBarController alloc] init];
    
    // 获取 window - 优先使用当前视图的 window
    UIWindow *window = self.view.window;
    
    if (!window) {
        // 如果当前视图的 window 为 nil，尝试其他方式获取
        if (@available(iOS 13.0, *)) {
            // iOS 13+ 使用 SceneDelegate
            for (UIWindowScene *windowScene in [UIApplication sharedApplication].connectedScenes) {
                if (windowScene.activationState == UISceneActivationStateForegroundActive) {
                    for (UIWindow *w in windowScene.windows) {
                        if (w.isKeyWindow) {
                            window = w;
                            break;
                        }
                    }
                    // 如果没有找到 keyWindow，使用第一个 window
                    if (!window && windowScene.windows.count > 0) {
                        window = windowScene.windows.firstObject;
                    }
                }
            }
        } else {
            // iOS 13 以下使用 AppDelegate
            window = [UIApplication sharedApplication].keyWindow;
            if (!window && [UIApplication sharedApplication].windows.count > 0) {
                window = [UIApplication sharedApplication].windows.firstObject;
            }
        }
    }
    
    if (window) {
        NSLog(@"找到 window: %@，准备切换 rootViewController", window);
        // 使用动画切换 rootViewController
        [UIView transitionWithView:window
                          duration:0.3
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^{
            window.rootViewController = tabBar;
        } completion:^(BOOL finished) {
            NSLog(@"切换 rootViewController 完成: %@", finished ? @"成功" : @"失败");
        }];
    } else {
        NSLog(@"未找到 window，使用 present 方式");
        tabBar.modalPresentationStyle = UIModalPresentationFullScreen;
        [self presentViewController:tabBar animated:YES completion:^{
            NSLog(@"present 完成");
            // present 后，将登录页面从父视图控制器中移除
            [self dismissViewControllerAnimated:NO completion:nil];
        }];
    }
}

@end
