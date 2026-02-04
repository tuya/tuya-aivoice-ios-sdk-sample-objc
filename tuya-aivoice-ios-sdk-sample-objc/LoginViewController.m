//
//  LoginViewController.m
//  AIVoiceDemo
//
//  Created by Bacson on 2026/1/28.
//

#import "LoginViewController.h"
#import "RegisterViewController.h"
#import "MainTabBarController.h"
#import "AuthService.h"
#import "UIHelper.h"
#import <ThingSmartBaseKit/ThingSmartBaseKit.h>
#import <ThingSmartDeviceKit/ThingSmartDeviceKit.h>

@interface LoginViewController ()

@property (nonatomic, strong) UITextField *countryCodeTextField;
@property (nonatomic, strong) UITextField *phoneNumberTextField;
@property (nonatomic, strong) UITextField *passwordTextField;
@property (nonatomic, strong) UIButton *loginButton;
@property (nonatomic, strong) UIButton *registerButton;

@end

@implementation LoginViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupUI];
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
    // 调试阶段设置默认值
    self.phoneNumberTextField.text = @"15005961707";
    self.phoneNumberTextField.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.phoneNumberTextField];
    
    // 密码输入框
    self.passwordTextField = [[UITextField alloc] init];
    self.passwordTextField.placeholder = @"请输入密码";
    self.passwordTextField.borderStyle = UITextBorderStyleRoundedRect;
    self.passwordTextField.secureTextEntry = YES;
    self.passwordTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.passwordTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    // 调试阶段设置默认值
    self.passwordTextField.text = @"Tuya1234";
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
        
        // 密码输入框
        [self.passwordTextField.topAnchor constraintEqualToAnchor:self.countryCodeTextField.bottomAnchor constant:20],
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

- (void)loginButtonTapped:(UIButton *)sender {
    NSString *countryCode = [self.countryCodeTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString *phoneNumber = [self.phoneNumberTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString *password = [self.passwordTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    
    // 输入验证
    if (countryCode.length == 0) {
        [UIHelper showAlertInViewController:self title:@"提示" message:@"请输入国家码"];
        return;
    }
    
    if (phoneNumber.length == 0) {
        [UIHelper showAlertInViewController:self title:@"提示" message:@"请输入手机号"];
        return;
    }
    
    if (password.length == 0) {
        [UIHelper showAlertInViewController:self title:@"提示" message:@"请输入密码"];
        return;
    }
    
    // 禁用按钮，防止重复点击
    self.loginButton.enabled = NO;
    [self.loginButton setTitle:@"登录中..." forState:UIControlStateNormal];
    
    // 调用登录服务
    [[AuthService sharedInstance] loginByPhone:countryCode
                                    phoneNumber:phoneNumber
                                       password:password
                                        success:^{
        // 登录成功
        dispatch_async(dispatch_get_main_queue(), ^{
            self.loginButton.enabled = YES;
            [self.loginButton setTitle:@"登录" forState:UIControlStateNormal];
        });
    } failure:^(NSError *error) {
        // 登录失败
        dispatch_async(dispatch_get_main_queue(), ^{
            self.loginButton.enabled = YES;
            [self.loginButton setTitle:@"登录" forState:UIControlStateNormal];
            NSString *errorMessage = error.localizedDescription ?: @"登录失败，请重试";
            [UIHelper showAlertInViewController:self title:@"登录失败" message:errorMessage];
        });
    }];
}

- (void)registerButtonTapped:(UIButton *)sender {
    // 跳转到注册页面
    RegisterViewController *registerVC = [[RegisterViewController alloc] init];
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
