//
//  MineViewController.m
//  AIVoiceDemo
//

#import "MineViewController.h"
#import "LoginViewController.h"
#import "DeviceManagementViewController.h"
#import <ThingSmartBaseKit/ThingSmartUser.h>
#import <ThingModuleManager/ThingModuleManager.h>
#import <ThingModuleServices/ThingFeedBackProtocol.h>
//#import <ThingPerfusionKit/ThingPerfusionViewController.h>

@interface MineViewController ()

@property (nonatomic, strong) UIView *profileCard;
@property (nonatomic, strong) UIImageView *avatarImageView;
@property (nonatomic, strong) UILabel *nicknameLabel;
@property (nonatomic, strong) UILabel *accountLabel;
@property (nonatomic, strong) UILabel *countryLabel;
@property (nonatomic, strong) UIButton *logoutButton;
@property (nonatomic, strong) UIView *menuCard;

@end

@implementation MineViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self configureFamilyNavigationWithTitle:@"我的" leftTitle:@"" leftAction:nil rightTitle:nil rightAction:nil];
    self.view.backgroundColor = [self familyBackgroundColor];
    [self setupUI];
    [self refreshUserInfo];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshUserInfo];
}

- (void)setupUI {
    // 个人信息卡片
    _profileCard = [[UIView alloc] init];
    _profileCard.translatesAutoresizingMaskIntoConstraints = NO;
    _profileCard.backgroundColor = [self familyCardColor];
    _profileCard.layer.cornerRadius = 20;
    [self.view addSubview:_profileCard];

    _avatarImageView = [[UIImageView alloc] init];
    _avatarImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _avatarImageView.backgroundColor = [UIColor tertiarySystemFillColor];
    _avatarImageView.layer.cornerRadius = 36;
    _avatarImageView.clipsToBounds = YES;
    _avatarImageView.contentMode = UIViewContentModeCenter;
    UIImage *personImage = [UIImage systemImageNamed:@"person.fill"];
    if (personImage) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:32 weight:UIImageSymbolWeightLight];
        _avatarImageView.image = [UIImage systemImageNamed:@"person.fill" withConfiguration:config];
        _avatarImageView.tintColor = [UIColor tertiaryLabelColor];
    }
    [_profileCard addSubview:_avatarImageView];

    _nicknameLabel = [[UILabel alloc] init];
    _nicknameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _nicknameLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightSemibold];
    _nicknameLabel.textColor = [UIColor labelColor];
    _nicknameLabel.text = [ThingSmartUser sharedInstance].userName;
    [_profileCard addSubview:_nicknameLabel];

    _accountLabel = [[UILabel alloc] init];
    _accountLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _accountLabel.font = [UIFont systemFontOfSize:14];
    _accountLabel.textColor = [UIColor secondaryLabelColor];
    _accountLabel.text = @"";
    [_profileCard addSubview:_accountLabel];

    _countryLabel = [[UILabel alloc] init];
    _countryLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _countryLabel.font = [UIFont systemFontOfSize:13];
    _countryLabel.textColor = [UIColor tertiaryLabelColor];
    _countryLabel.text = @"";
    [_profileCard addSubview:_countryLabel];

    self.menuCard = [[UIView alloc] init];
    self.menuCard.translatesAutoresizingMaskIntoConstraints = NO;
    self.menuCard.backgroundColor = [self familyCardColor];
    self.menuCard.layer.cornerRadius = 20;
    [self.view addSubview:self.menuCard];
    UIButton *deviceButton = [self menuButtonWithTitle:@"设备管理" detail:@"名称、状态与解绑" action:@selector(openDeviceManagement)];
    UIButton *nicknameButton = [self menuButtonWithTitle:@"修改昵称" detail:@"展示在家庭成员列表中" action:@selector(editNickname)];
    UIButton *logButton = [self menuButtonWithTitle:@"上传诊断日志" detail:@"通过涂鸦反馈服务提交" action:@selector(uploadDiagnosticLog)];
    UIButton *debugButton = [self menuButtonWithTitle:@"灌流调试" detail:@"本地音频灌流，导出 ASR/翻译结果" action:@selector(openDebugTool)];
    UIStackView *menuStack = [[UIStackView alloc] initWithArrangedSubviews:@[deviceButton, nicknameButton, logButton, debugButton]];
    menuStack.axis = UILayoutConstraintAxisVertical; menuStack.spacing = 1; menuStack.backgroundColor = [self familyHairlineColor]; menuStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.menuCard addSubview:menuStack];

    _logoutButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _logoutButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_logoutButton setTitle:@"退出登录" forState:UIControlStateNormal];
    _logoutButton.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightMedium];
    [_logoutButton setTitleColor:[self familyDestructiveColor] forState:UIControlStateNormal];
    _logoutButton.backgroundColor = [self familyCardColor];
    _logoutButton.layer.cornerRadius = 20;
    [_logoutButton addTarget:self action:@selector(logoutTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_logoutButton];

    [NSLayoutConstraint activateConstraints:@[
        [_profileCard.topAnchor constraintEqualToAnchor:self.familyContentGuide.topAnchor constant:16],
        [_profileCard.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [_profileCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [_profileCard.heightAnchor constraintEqualToConstant:140],

        [_avatarImageView.leadingAnchor constraintEqualToAnchor:_profileCard.leadingAnchor constant:20],
        [_avatarImageView.centerYAnchor constraintEqualToAnchor:_profileCard.centerYAnchor],
        [_avatarImageView.widthAnchor constraintEqualToConstant:72],
        [_avatarImageView.heightAnchor constraintEqualToConstant:72],

        [_nicknameLabel.leadingAnchor constraintEqualToAnchor:_avatarImageView.trailingAnchor constant:16],
        [_nicknameLabel.trailingAnchor constraintEqualToAnchor:_profileCard.trailingAnchor constant:-20],
        [_nicknameLabel.topAnchor constraintEqualToAnchor:_profileCard.topAnchor constant:32],

        [_accountLabel.leadingAnchor constraintEqualToAnchor:_nicknameLabel.leadingAnchor],
        [_accountLabel.trailingAnchor constraintEqualToAnchor:_nicknameLabel.trailingAnchor],
        [_accountLabel.topAnchor constraintEqualToAnchor:_nicknameLabel.bottomAnchor constant:6],

        [_countryLabel.leadingAnchor constraintEqualToAnchor:_nicknameLabel.leadingAnchor],
        [_countryLabel.trailingAnchor constraintEqualToAnchor:_nicknameLabel.trailingAnchor],
        [_countryLabel.topAnchor constraintEqualToAnchor:_accountLabel.bottomAnchor constant:4],

        [self.menuCard.topAnchor constraintEqualToAnchor:self.profileCard.bottomAnchor constant:18],
        [self.menuCard.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.menuCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.menuCard.heightAnchor constraintEqualToConstant:263],
        [menuStack.topAnchor constraintEqualToAnchor:self.menuCard.topAnchor],
        [menuStack.leadingAnchor constraintEqualToAnchor:self.menuCard.leadingAnchor],
        [menuStack.trailingAnchor constraintEqualToAnchor:self.menuCard.trailingAnchor],
        [menuStack.bottomAnchor constraintEqualToAnchor:self.menuCard.bottomAnchor],
        [_logoutButton.topAnchor constraintEqualToAnchor:self.menuCard.bottomAnchor constant:18],
        [_logoutButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [_logoutButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [_logoutButton.heightAnchor constraintEqualToConstant:52],
        [_logoutButton.bottomAnchor constraintLessThanOrEqualToAnchor:self.familyContentGuide.bottomAnchor constant:-18],
    ]];
}

- (UIButton *)menuButtonWithTitle:(NSString *)title detail:(NSString *)detail action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.backgroundColor = [self familyCardColor];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    UILabel *titleLabel = [UILabel new]; titleLabel.text = title; titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold]; titleLabel.textColor = [self familyPrimaryTextColor]; titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    UILabel *detailLabel = [UILabel new]; detailLabel.text = detail; detailLabel.font = [UIFont systemFontOfSize:13]; detailLabel.textColor = [self familySecondaryTextColor]; detailLabel.translatesAutoresizingMaskIntoConstraints = NO;
    UILabel *chevron = [UILabel new]; chevron.text = @"›"; chevron.font = [UIFont systemFontOfSize:30]; chevron.textColor = [self familySecondaryTextColor]; chevron.translatesAutoresizingMaskIntoConstraints = NO;
    [button addSubview:titleLabel]; [button addSubview:detailLabel]; [button addSubview:chevron];
    [NSLayoutConstraint activateConstraints:@[[button.heightAnchor constraintEqualToConstant:65], [titleLabel.leadingAnchor constraintEqualToAnchor:button.leadingAnchor constant:18], [titleLabel.topAnchor constraintEqualToAnchor:button.topAnchor constant:12], [detailLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor], [detailLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:3], [chevron.trailingAnchor constraintEqualToAnchor:button.trailingAnchor constant:-18], [chevron.centerYAnchor constraintEqualToAnchor:button.centerYAnchor]]];
    return button;
}

- (void)openDeviceManagement { [self.navigationController pushViewController:[DeviceManagementViewController new] animated:YES]; }

- (void)openDebugTool {
//    ThingPerfusionViewController *debugVC = [[ThingPerfusionViewController alloc] init];
//    debugVC.hidesBottomBarWhenPushed = YES;
//    [self.navigationController pushViewController:debugVC animated:YES];
}

- (void)editNickname {
    __weak typeof(self) weakSelf = self;
    [self showFamilyInputDialogWithTitle:@"修改昵称" message:nil placeholders:@[@"请输入昵称"] initialValues:@[self.nicknameLabel.text ?: @""] keyboardTypes:nil confirmTitle:@"保存" confirm:^(NSArray<NSString *> *values) {
        [[ThingSmartUser sharedInstance] updateNickname:values.firstObject success:^{ [weakSelf refreshUserInfo]; } failure:^(NSError *error) { [weakSelf showFamilyMessageWithTitle:@"保存失败" message:error.localizedDescription ?: @""]; }];
    }];
}

- (void)uploadDiagnosticLog {
    [self showFamilyConfirmationWithTitle:@"上传诊断日志" message:@"将进入涂鸦反馈服务，由您确认需要提交的日志和问题说明。" confirmTitle:@"继续" destructive:NO confirm:^{
        id<ThingFeedBackProtocol> service = [ThingModule serviceOfRequiredProtocol:@protocol(ThingFeedBackProtocol)];
        if ([service respondsToSelector:@selector(gotFeedBackViewControllerWithHdType:deviceName:hdId:uuid:region:withoutRefresh:)]) {
            [service gotFeedBackViewControllerWithHdType:8 deviceName:nil hdId:nil uuid:nil region:nil withoutRefresh:YES];
        } else {
            [self showFamilyMessageWithTitle:@"日志服务不可用" message:@"当前构建未加载涂鸦反馈模块。"];
        }
    }];
}

- (NSString *)countryNameForCountryCode:(NSString *)countryCode {
    if (!countryCode || countryCode.length == 0) return nil;
    NSDictionary *map = @{
        @"86": @"中国",
        @"1": @"美国",
        @"44": @"英国",
        @"81": @"日本",
        @"82": @"韩国",
        @"33": @"法国",
        @"49": @"德国",
        @"91": @"印度",
        @"61": @"澳大利亚",
        @"65": @"新加坡",
        @"852": @"中国香港",
        @"886": @"中国台湾",
    };
    NSString *name = map[countryCode];
    return name ?: [NSString stringWithFormat:@"%@", countryCode];
}

- (void)refreshUserInfo {
    ThingSmartUser *user = [ThingSmartUser sharedInstance];
    NSString *nickname = nil;
    NSString *account = nil;
    NSString *countryCode = nil;
    if ([user respondsToSelector:@selector(nickname)] && [user valueForKey:@"nickname"]) {
        nickname = [user valueForKey:@"nickname"];
    }
    if ([user respondsToSelector:@selector(userName)] && [user valueForKey:@"userName"]) {
        account = [user valueForKey:@"userName"];
    }
    if ([user respondsToSelector:@selector(countryCode)] && [user valueForKey:@"countryCode"]) {
        countryCode = [user valueForKey:@"countryCode"];
    }
    _nicknameLabel.text = (nickname.length > 0) ? nickname : @"用户";
    _accountLabel.text = (account.length > 0) ? account : @"";
    _countryLabel.text = (countryCode.length > 0) ? [self countryNameForCountryCode:countryCode] : @"";
}

- (void)logoutTapped:(UIButton *)sender {
    __weak typeof(self) weakSelf = self;
    [self showFamilyConfirmationWithTitle:@"退出登录" message:@"确定要退出当前账号吗？" confirmTitle:@"退出" destructive:YES confirm:^{
        [weakSelf doLogout];
    }];
}

- (void)doLogout {
    ThingSmartUser *user = [ThingSmartUser sharedInstance];
    if ([user respondsToSelector:@selector(loginOut:failure:)]) {
        [user loginOut:^{ [self onLogoutSuccess]; } failure:^(NSError *e) { [self onLogoutFailure:e]; }];
    } else {
        [self onLogoutFailure:[NSError errorWithDomain:@"Auth" code:-1 userInfo:@{ NSLocalizedDescriptionKey: @"当前 SDK 不支持退出登录" }]];
    }
}

- (void)onLogoutSuccess {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = nil;
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive) {
                    for (UIWindow *w in scene.windows) {
                        if (w.isKeyWindow) { window = w; break; }
                    }
                    if (!window && scene.windows.count > 0) window = scene.windows.firstObject;
                    break;
                }
            }
        } else {
            window = [UIApplication sharedApplication].keyWindow;
        }
        if (window) {
            LoginViewController *loginVC = [[LoginViewController alloc] init];
            [UIView transitionWithView:window duration:0.25 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
                window.rootViewController = loginVC;
            } completion:nil];
        }
    });
}

- (void)onLogoutFailure:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *msg = error.localizedDescription ?: @"退出失败";
        [self showFamilyMessageWithTitle:@"提示" message:msg];
    });
}

@end
