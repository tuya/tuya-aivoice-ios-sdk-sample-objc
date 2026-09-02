//
//  RegisterViewController.m
//  AIVoiceDemo
//
//  Created by Bacson on 2026/1/28.
//

#import "RegisterViewController.h"
#import "CountryPickerViewController.h"
#import "AuthService.h"
#import "UIHelper.h"
#import <ThingSmartBaseKit/ThingSmartBaseKit.h>

/** 账号类型：手机号 / 邮箱 */
typedef NS_ENUM(NSInteger, RegisterAccountType) {
    RegisterAccountTypePhone = 0,
    RegisterAccountTypeEmail = 1,
};

@interface RegisterViewController ()

@property (nonatomic, strong) UISegmentedControl *accountTypeSegment;
@property (nonatomic, strong) UIButton *countryButton;
@property (nonatomic, strong) UITextField *accountTextField;
@property (nonatomic, strong) UITextField *passwordTextField;
@property (nonatomic, strong) UITextField *verifyCodeTextField;
@property (nonatomic, strong) UIButton *getVerifyCodeButton;
@property (nonatomic, strong) UIButton *registerButton;
@property (nonatomic, strong) NSTimer *countdownTimer;
@property (nonatomic, assign) NSInteger countdownSeconds;

@property (nonatomic, strong) CountryModel *selectedCountry;
@property (nonatomic, assign) RegisterAccountType accountType;

@end

@implementation RegisterViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    self.selectedCountry = self.preselectedCountry ?: [CountryModel lastSelectedCountry];
    self.accountType = RegisterAccountTypePhone;
    
    // 添加关闭按钮
    UIBarButtonItem *closeButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose
                                                                                  target:self
                                                                                  action:@selector(closeButtonTapped:)];
    self.navigationItem.leftBarButtonItem = closeButton;
    
    [self setupUI];
    [self setupDismissKeyboardGesture];
    [self updateCountryButtonTitle];
    [self updateAccountFieldForAccountType];
}

- (void)setupUI {
    // 标题
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"注册";
    titleLabel.font = [UIFont boldSystemFontOfSize:32];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:titleLabel];

    // 账号类型切换：手机号 / 邮箱
    self.accountTypeSegment = [[UISegmentedControl alloc] initWithItems:@[@"手机号", @"邮箱"]];
    self.accountTypeSegment.selectedSegmentIndex = RegisterAccountTypePhone;
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
    self.accountTextField.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.accountTextField];
    
    // 验证码输入框容器
    UIView *verifyCodeContainer = [[UIView alloc] init];
    verifyCodeContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:verifyCodeContainer];
    
    // 验证码输入框
    self.verifyCodeTextField = [[UITextField alloc] init];
    self.verifyCodeTextField.placeholder = @"请输入验证码";
    self.verifyCodeTextField.borderStyle = UITextBorderStyleRoundedRect;
    self.verifyCodeTextField.keyboardType = UIKeyboardTypeNumberPad;
    self.verifyCodeTextField.translatesAutoresizingMaskIntoConstraints = NO;
    [verifyCodeContainer addSubview:self.verifyCodeTextField];
    
    // 获取验证码按钮
    self.getVerifyCodeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.getVerifyCodeButton setTitle:@"获取验证码" forState:UIControlStateNormal];
    self.getVerifyCodeButton.titleLabel.font = [UIFont systemFontOfSize:14];
    self.getVerifyCodeButton.backgroundColor = [UIColor systemBlueColor];
    [self.getVerifyCodeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.getVerifyCodeButton.layer.cornerRadius = 6;
    self.getVerifyCodeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.getVerifyCodeButton addTarget:self action:@selector(getVerifyCodeButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [verifyCodeContainer addSubview:self.getVerifyCodeButton];
    
    // 密码输入框
    self.passwordTextField = [[UITextField alloc] init];
    self.passwordTextField.placeholder = @"请输入密码";
    self.passwordTextField.borderStyle = UITextBorderStyleRoundedRect;
    self.passwordTextField.secureTextEntry = YES;
    self.passwordTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.passwordTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.passwordTextField.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.passwordTextField];
    
    // 注册按钮
    self.registerButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.registerButton setTitle:@"注册" forState:UIControlStateNormal];
    self.registerButton.titleLabel.font = [UIFont systemFontOfSize:18];
    self.registerButton.backgroundColor = [UIColor systemBlueColor];
    [self.registerButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.registerButton.layer.cornerRadius = 8;
    self.registerButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.registerButton addTarget:self action:@selector(registerButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.registerButton];
    
    // 布局约束
    [NSLayoutConstraint activateConstraints:@[
        // 标题
        [titleLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:40],
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
        
        // 验证码容器
        [verifyCodeContainer.topAnchor constraintEqualToAnchor:self.accountTextField.bottomAnchor constant:20],
        [verifyCodeContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:40],
        [verifyCodeContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-40],
        [verifyCodeContainer.heightAnchor constraintEqualToConstant:50],
        
        // 验证码输入框
        [self.verifyCodeTextField.topAnchor constraintEqualToAnchor:verifyCodeContainer.topAnchor],
        [self.verifyCodeTextField.leadingAnchor constraintEqualToAnchor:verifyCodeContainer.leadingAnchor],
        [self.verifyCodeTextField.trailingAnchor constraintEqualToAnchor:self.getVerifyCodeButton.leadingAnchor constant:-10],
        [self.verifyCodeTextField.bottomAnchor constraintEqualToAnchor:verifyCodeContainer.bottomAnchor],
        
        // 获取验证码按钮
        [self.getVerifyCodeButton.topAnchor constraintEqualToAnchor:verifyCodeContainer.topAnchor],
        [self.getVerifyCodeButton.trailingAnchor constraintEqualToAnchor:verifyCodeContainer.trailingAnchor],
        [self.getVerifyCodeButton.bottomAnchor constraintEqualToAnchor:verifyCodeContainer.bottomAnchor],
        [self.getVerifyCodeButton.widthAnchor constraintEqualToConstant:110],
        
        // 密码输入框
        [self.passwordTextField.topAnchor constraintEqualToAnchor:verifyCodeContainer.bottomAnchor constant:20],
        [self.passwordTextField.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:40],
        [self.passwordTextField.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-40],
        [self.passwordTextField.heightAnchor constraintEqualToConstant:50],
        
        // 注册按钮
        [self.registerButton.topAnchor constraintEqualToAnchor:self.passwordTextField.bottomAnchor constant:30],
        [self.registerButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:40],
        [self.registerButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-40],
        [self.registerButton.heightAnchor constraintEqualToConstant:50],
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
    self.accountType = (RegisterAccountType)sender.selectedSegmentIndex;
    [self updateAccountFieldForAccountType];
}

- (void)updateAccountFieldForAccountType {
    if (self.accountType == RegisterAccountTypeEmail) {
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

- (BOOL)isValidEmail:(NSString *)email {
    NSString *pattern = @"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$";
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", pattern];
    return [predicate evaluateWithObject:email];
}

/** 校验国家与账号输入，通过返回 YES */
- (BOOL)validateAccountInput {
    if (self.selectedCountry.countryCode.length == 0) {
        [UIHelper showAlertInViewController:self title:@"提示" message:@"请选择国家/地区"];
        return NO;
    }

    NSString *account = [self.accountTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    BOOL isEmail = (self.accountType == RegisterAccountTypeEmail);
    if (account.length == 0) {
        [UIHelper showAlertInViewController:self title:@"提示" message:isEmail ? @"请输入邮箱" : @"请输入手机号"];
        return NO;
    }
    if (isEmail && ![self isValidEmail:account]) {
        [UIHelper showAlertInViewController:self title:@"提示" message:@"邮箱格式不正确"];
        return NO;
    }
    return YES;
}

#pragma mark - 验证码

- (void)getVerifyCodeButtonTapped:(UIButton *)sender {
    if (![self validateAccountInput]) {
        return;
    }

    NSString *countryCode = self.selectedCountry.countryCode;
    NSString *account = [self.accountTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    BOOL isEmail = (self.accountType == RegisterAccountTypeEmail);

    // 邮箱不需要 region，手机号取国家码对应的默认 region
    NSString *region = isEmail ? nil : [[AuthService sharedInstance] getDefaultRegionWithCountryCode:countryCode];
    
    // 禁用按钮，开始倒计时
    self.getVerifyCodeButton.enabled = NO;
    self.countdownSeconds = 60;
    [self updateGetVerifyCodeButtonTitle];
    
    // 调用获取验证码服务
    [[AuthService sharedInstance] sendVerifyCodeWithUserName:account
                                                      region:region
                                                 countryCode:countryCode
                                                        type:AuthVerifyCodeTypeRegister
                                                     success:^{
        // 获取验证码成功
        dispatch_async(dispatch_get_main_queue(), ^{
            [UIHelper showAlertInViewController:self title:@"提示" message:@"验证码已发送"];
            // 开始倒计时
            self.countdownTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                                    target:self
                                                                  selector:@selector(countdownTimerFired:)
                                                                  userInfo:nil
                                                                   repeats:YES];
        });
    } failure:^(NSError *error) {
        // 获取验证码失败
        dispatch_async(dispatch_get_main_queue(), ^{
            self.getVerifyCodeButton.enabled = YES;
            [self.getVerifyCodeButton setTitle:@"获取验证码" forState:UIControlStateNormal];
            NSString *errorMessage = error.localizedDescription ?: @"获取验证码失败，请重试";
            [UIHelper showAlertInViewController:self title:@"获取验证码失败" message:errorMessage];
        });
    }];
}

- (void)countdownTimerFired:(NSTimer *)timer {
    self.countdownSeconds--;
    [self updateGetVerifyCodeButtonTitle];
    
    if (self.countdownSeconds <= 0) {
        [self.countdownTimer invalidate];
        self.countdownTimer = nil;
        self.getVerifyCodeButton.enabled = YES;
        [self.getVerifyCodeButton setTitle:@"获取验证码" forState:UIControlStateNormal];
    }
}

- (void)updateGetVerifyCodeButtonTitle {
    NSString *title = [NSString stringWithFormat:@"%ld秒后重试", (long)self.countdownSeconds];
    [self.getVerifyCodeButton setTitle:title forState:UIControlStateNormal];
}

#pragma mark - 注册

- (void)registerButtonTapped:(UIButton *)sender {
    if (![self validateAccountInput]) {
        return;
    }

    NSString *countryCode = self.selectedCountry.countryCode;
    NSString *account = [self.accountTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString *password = [self.passwordTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString *code = [self.verifyCodeTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    BOOL isEmail = (self.accountType == RegisterAccountTypeEmail);
    
    if (code.length == 0) {
        [UIHelper showAlertInViewController:self title:@"提示" message:@"请输入验证码"];
        return;
    }
    
    if (password.length == 0) {
        [UIHelper showAlertInViewController:self title:@"提示" message:@"请输入密码"];
        return;
    }
    
    // 禁用按钮，防止重复点击
    self.registerButton.enabled = NO;
    [self.registerButton setTitle:@"注册中..." forState:UIControlStateNormal];

    __weak typeof(self) weakSelf = self;
    void (^successBlock)(void) = ^{
        // 注册成功
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            strongSelf.registerButton.enabled = YES;
            [strongSelf.registerButton setTitle:@"注册" forState:UIControlStateNormal];
            [UIHelper showAlertInViewController:strongSelf title:@"成功" message:@"注册成功" completion:^{
                [strongSelf dismissViewControllerAnimated:YES completion:nil];
            }];
        });
    };
    void (^failureBlock)(NSError *) = ^(NSError *error) {
        // 注册失败
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            strongSelf.registerButton.enabled = YES;
            [strongSelf.registerButton setTitle:@"注册" forState:UIControlStateNormal];
            NSString *errorMessage = error.localizedDescription ?: @"注册失败，请重试";
            [UIHelper showAlertInViewController:strongSelf title:@"注册失败" message:errorMessage];
        });
    };
    
    // 调用注册服务
    if (isEmail) {
        [[AuthService sharedInstance] registerByEmail:countryCode
                                                email:account
                                             password:password
                                                 code:code
                                              success:successBlock
                                              failure:failureBlock];
    } else {
        [[AuthService sharedInstance] registerByPhone:countryCode
                                          phoneNumber:account
                                             password:password
                                                 code:code
                                              success:successBlock
                                              failure:failureBlock];
    }
}

- (void)closeButtonTapped:(UIBarButtonItem *)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (self.countdownTimer) {
        [self.countdownTimer invalidate];
        self.countdownTimer = nil;
    }
}

- (void)dealloc {
    if (self.countdownTimer) {
        [self.countdownTimer invalidate];
        self.countdownTimer = nil;
    }
}

@end
