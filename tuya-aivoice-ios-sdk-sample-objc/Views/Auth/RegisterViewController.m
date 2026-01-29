//
//  RegisterViewController.m
//  AIVoiceDemo
//
//  Created by Bacson on 2026/1/28.
//

#import "RegisterViewController.h"
#import "AuthService.h"
#import "UIHelper.h"
#import <ThingSmartBaseKit/ThingSmartBaseKit.h>

@interface RegisterViewController ()

@property (nonatomic, strong) UITextField *countryCodeTextField;
@property (nonatomic, strong) UITextField *phoneNumberTextField;
@property (nonatomic, strong) UITextField *passwordTextField;
@property (nonatomic, strong) UITextField *verifyCodeTextField;
@property (nonatomic, strong) UIButton *getVerifyCodeButton;
@property (nonatomic, strong) UIButton *registerButton;
@property (nonatomic, strong) NSTimer *countdownTimer;
@property (nonatomic, assign) NSInteger countdownSeconds;

@end

@implementation RegisterViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    // 添加关闭按钮
    UIBarButtonItem *closeButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose
                                                                                  target:self
                                                                                  action:@selector(closeButtonTapped:)];
    self.navigationItem.leftBarButtonItem = closeButton;
    
    [self setupUI];
}

- (void)setupUI {
    // 标题
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"注册";
    titleLabel.font = [UIFont boldSystemFontOfSize:32];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:titleLabel];
    
    // 国家码输入框
    self.countryCodeTextField = [[UITextField alloc] init];
    self.countryCodeTextField.placeholder = @"国家码(如:86)";
    self.countryCodeTextField.borderStyle = UITextBorderStyleRoundedRect;
    self.countryCodeTextField.keyboardType = UIKeyboardTypeNumberPad;
    self.countryCodeTextField.text = @"86"; // 默认中国
    self.countryCodeTextField.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.countryCodeTextField];
    
    // 手机号输入框
    self.phoneNumberTextField = [[UITextField alloc] init];
    self.phoneNumberTextField.placeholder = @"请输入手机号";
    self.phoneNumberTextField.borderStyle = UITextBorderStyleRoundedRect;
    self.phoneNumberTextField.keyboardType = UIKeyboardTypePhonePad;
    self.phoneNumberTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.phoneNumberTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.phoneNumberTextField.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.phoneNumberTextField];
    
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
        
        // 国家码输入框
        [self.countryCodeTextField.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:50],
        [self.countryCodeTextField.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:40],
        [self.countryCodeTextField.widthAnchor constraintEqualToConstant:100],
        [self.countryCodeTextField.heightAnchor constraintEqualToConstant:50],
        
        // 手机号输入框
        [self.phoneNumberTextField.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:50],
        [self.phoneNumberTextField.leadingAnchor constraintEqualToAnchor:self.countryCodeTextField.trailingAnchor constant:10],
        [self.phoneNumberTextField.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-40],
        [self.phoneNumberTextField.heightAnchor constraintEqualToConstant:50],
        
        // 验证码容器
        [verifyCodeContainer.topAnchor constraintEqualToAnchor:self.countryCodeTextField.bottomAnchor constant:20],
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

- (void)getVerifyCodeButtonTapped:(UIButton *)sender {
    NSString *countryCode = [self.countryCodeTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString *phoneNumber = [self.phoneNumberTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    
    // 输入验证
    if (countryCode.length == 0) {
        [UIHelper showAlertInViewController:self title:@"提示" message:@"请输入国家码"];
        return;
    }
    
    if (phoneNumber.length == 0) {
        [UIHelper showAlertInViewController:self title:@"提示" message:@"请输入手机号"];
        return;
    }
    
    // 获取region
    NSString *region = [[ThingSmartUser sharedInstance] getDefaultRegionWithCountryCode:countryCode];
    
    // 禁用按钮，开始倒计时
    self.getVerifyCodeButton.enabled = NO;
    self.countdownSeconds = 60;
    [self updateGetVerifyCodeButtonTitle];
    
    // 调用获取验证码服务
    [[AuthService sharedInstance] sendVerifyCodeWithUserName:phoneNumber
                                                      region:region
                                                 countryCode:countryCode
                                                        type:1
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

- (void)registerButtonTapped:(UIButton *)sender {
    NSString *countryCode = [self.countryCodeTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString *phoneNumber = [self.phoneNumberTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString *password = [self.passwordTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString *code = [self.verifyCodeTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    
    // 输入验证
    if (countryCode.length == 0) {
        [UIHelper showAlertInViewController:self title:@"提示" message:@"请输入国家码"];
        return;
    }
    
    if (phoneNumber.length == 0) {
        [UIHelper showAlertInViewController:self title:@"提示" message:@"请输入手机号"];
        return;
    }
    
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
    
    // 调用注册服务
    [[AuthService sharedInstance] registerByPhone:countryCode
                                      phoneNumber:phoneNumber
                                         password:password
                                             code:code
                                          success:^{
        // 注册成功
        dispatch_async(dispatch_get_main_queue(), ^{
            self.registerButton.enabled = YES;
            [self.registerButton setTitle:@"注册" forState:UIControlStateNormal];
            [UIHelper showAlertInViewController:self title:@"成功" message:@"注册成功" completion:^{
                [self dismissViewControllerAnimated:YES completion:nil];
            }];
        });
    } failure:^(NSError *error) {
        // 注册失败
        dispatch_async(dispatch_get_main_queue(), ^{
            self.registerButton.enabled = YES;
            [self.registerButton setTitle:@"注册" forState:UIControlStateNormal];
            NSString *errorMessage = error.localizedDescription ?: @"注册失败，请重试";
            [UIHelper showAlertInViewController:self title:@"注册失败" message:errorMessage];
        });
    }];
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
