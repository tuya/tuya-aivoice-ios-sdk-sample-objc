//
//  MineViewController.m
//  AIVoiceDemo
//

#import "MineViewController.h"
#import "LoginViewController.h"
#import <ThingSmartBaseKit/ThingSmartUser.h>

@interface MineViewController ()

@property (nonatomic, strong) UIView *profileCard;
@property (nonatomic, strong) UIImageView *avatarImageView;
@property (nonatomic, strong) UILabel *nicknameLabel;
@property (nonatomic, strong) UILabel *accountLabel;
@property (nonatomic, strong) UILabel *countryLabel;
@property (nonatomic, strong) UIButton *logoutButton;

@end

@implementation MineViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"我的";
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
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
    _profileCard.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    _profileCard.layer.cornerRadius = 16;
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

    _logoutButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _logoutButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_logoutButton setTitle:@"退出登录" forState:UIControlStateNormal];
    _logoutButton.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightMedium];
    [_logoutButton setTitleColor:[UIColor systemRedColor] forState:UIControlStateNormal];
    _logoutButton.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    _logoutButton.layer.cornerRadius = 12;
    [_logoutButton addTarget:self action:@selector(logoutTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_logoutButton];

    [NSLayoutConstraint activateConstraints:@[
        [_profileCard.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:24],
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

        [_logoutButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [_logoutButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [_logoutButton.heightAnchor constraintEqualToConstant:52],
        [_logoutButton.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-32],
    ]];
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
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"退出登录"
                                                                   message:@"确定要退出当前账号吗？"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"退出" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [weakSelf doLogout];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
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
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:msg preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    });
}

@end
