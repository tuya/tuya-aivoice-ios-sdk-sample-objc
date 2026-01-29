//
//  MainViewController.m
//  AIVoiceDemo
//
//  Created by Bacson on 2026/1/28.
//

#import "MainViewController.h"
#import "HomeService.h"
#import "HomeManager.h"
#import "CreateHomeViewController.h"
#import "UIHelper.h"
#import <ThingSmartDeviceKit/ThingSmartDeviceKit.h>
#import <ThingModuleServices/ThingModuleServices.h>
#import <ThingSmartBizCore/ThingSmartBizCore.h>
#import <ThingSmartMiniAppBizBundle/ThingSmartMiniAppBizBundle.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

@interface MainViewController () <CreateHomeViewControllerDelegate>

@property (nonatomic, strong) UIButton *homeSelectButton;
@property (nonatomic, strong) NSArray<ThingSmartHomeModel *> *homeList;
@property (nonatomic, strong) ThingSmartHomeModel *selectedHome;
@property (nonatomic, strong) ThingSmartHome *home;

@end

@implementation MainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 设置背景为渐变或纯色
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    // 不设置 title，使用自定义的 titleView
    
    // 设置导航栏外观
    [self setupNavigationBarAppearance];
    
    [self setupUI];
    [self loadHomeList];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    // 更新渐变层frame
    for (UIView *subview in self.view.subviews) {
        CAGradientLayer *gradientLayer = objc_getAssociatedObject(subview, "gradientLayer");
        if (gradientLayer) {
            gradientLayer.frame = subview.bounds;
        }
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // 恢复导航栏外观（防止从其他页面返回后导航栏变黑）
    [self setupNavigationBarAppearance];
    
    // 每次页面显示时刷新家庭列表
    [self loadHomeList];
}

- (void)setupNavigationBarAppearance {
    // 设置导航栏为透明
    if (@available(iOS 13.0, *)) {
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        [appearance configureWithTransparentBackground];
        
        // 透明背景
        appearance.backgroundColor = [UIColor clearColor];
        appearance.shadowColor = [UIColor clearColor];
        
        // 设置标题样式
        appearance.titleTextAttributes = @{NSForegroundColorAttributeName: [UIColor labelColor]};
        
        // 设置大标题样式
        appearance.largeTitleTextAttributes = @{NSForegroundColorAttributeName: [UIColor labelColor]};
        
        self.navigationController.navigationBar.standardAppearance = appearance;
        self.navigationController.navigationBar.scrollEdgeAppearance = appearance;
        if (@available(iOS 15.0, *)) {
            self.navigationController.navigationBar.compactAppearance = appearance;
            self.navigationController.navigationBar.compactScrollEdgeAppearance = appearance;
        }
        
        // 导航栏透明
        self.navigationController.navigationBar.translucent = YES;
    } else {
        // iOS 12 及以下
        self.navigationController.navigationBar.barTintColor = [UIColor clearColor];
        self.navigationController.navigationBar.tintColor = [UIColor systemBlueColor];
        self.navigationController.navigationBar.titleTextAttributes = @{NSForegroundColorAttributeName: [UIColor labelColor]};
        self.navigationController.navigationBar.translucent = YES;
        [self.navigationController.navigationBar setBackgroundImage:[UIImage new] forBarMetrics:UIBarMetricsDefault];
        self.navigationController.navigationBar.shadowImage = [UIImage new];
    }
}

- (void)setupUI {
    // 家庭选择下拉框 - 放在导航栏中间（titleView）
    self.homeSelectButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.homeSelectButton setTitle:@"选择家庭 ▼" forState:UIControlStateNormal];
    self.homeSelectButton.titleLabel.font = [UIFont systemFontOfSize:17];
    [self.homeSelectButton setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
    [self.homeSelectButton addTarget:self action:@selector(homeSelectButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.homeSelectButton sizeToFit];
    
    // 设置为导航栏的 titleView
    self.navigationItem.titleView = self.homeSelectButton;
    
    // 家庭管理按钮 - 放在导航栏右侧
    UIButton *familyManageButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [familyManageButton setTitle:@"家庭管理" forState:UIControlStateNormal];
    familyManageButton.titleLabel.font = [UIFont systemFontOfSize:16];
    [familyManageButton setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
    [familyManageButton addTarget:self action:@selector(familyManageButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [familyManageButton sizeToFit];
    
    UIBarButtonItem *familyManageButtonItem = [[UIBarButtonItem alloc] initWithCustomView:familyManageButton];
    self.navigationItem.rightBarButtonItem = familyManageButtonItem;
    
    // 添加小程序入口
    [self setupMiniAppButtons];
}

- (void)setupMiniAppButtons {
    // AI笔记卡片容器
    UIView *aiNoteCard = [self createMiniAppCardWithTitle:@"AI笔记"
                                                subtitle:@"智能笔记助手"
                                                  icon:@"📝"
                                            gradientColors:@[[UIColor colorWithRed:0.2 green:0.4 blue:1.0 alpha:1.0],
                                                             [UIColor colorWithRed:0.4 green:0.6 blue:1.0 alpha:1.0]]
                                                 target:self
                                                 action:@selector(aiNoteButtonTapped:)];
    [self.view addSubview:aiNoteCard];
    
    // AI翻译卡片容器
    UIView *aiTranslateCard = [self createMiniAppCardWithTitle:@"AI翻译"
                                                     subtitle:@"多语言翻译工具"
                                                       icon:@"🌐"
                                                 gradientColors:@[[UIColor colorWithRed:0.2 green:0.8 blue:0.4 alpha:1.0],
                                                                  [UIColor colorWithRed:0.4 green:0.9 blue:0.6 alpha:1.0]]
                                                      target:self
                                                      action:@selector(aiTranslateButtonTapped:)];
    [self.view addSubview:aiTranslateCard];
    
    // 布局约束
    [NSLayoutConstraint activateConstraints:@[
        // AI笔记卡片
        [aiNoteCard.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [aiNoteCard.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:40],
        [aiNoteCard.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [aiNoteCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [aiNoteCard.heightAnchor constraintEqualToConstant:120],
        
        // AI翻译卡片
        [aiTranslateCard.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [aiTranslateCard.topAnchor constraintEqualToAnchor:aiNoteCard.bottomAnchor constant:16],
        [aiTranslateCard.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [aiTranslateCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [aiTranslateCard.heightAnchor constraintEqualToConstant:120],
    ]];
}

- (UIView *)createMiniAppCardWithTitle:(NSString *)title
                              subtitle:(NSString *)subtitle
                                  icon:(NSString *)icon
                        gradientColors:(NSArray<UIColor *> *)colors
                                target:(id)target
                                action:(SEL)action {
    // 创建卡片容器
    UIView *cardView = [[UIView alloc] init];
    cardView.translatesAutoresizingMaskIntoConstraints = NO;
    cardView.layer.cornerRadius = 16;
    cardView.backgroundColor = [UIColor clearColor];
    
    // 添加渐变背景
    CAGradientLayer *gradientLayer = [CAGradientLayer layer];
    gradientLayer.colors = @[(__bridge id)colors[0].CGColor, (__bridge id)colors[1].CGColor];
    gradientLayer.startPoint = CGPointMake(0, 0);
    gradientLayer.endPoint = CGPointMake(1, 1);
    gradientLayer.cornerRadius = 16;
    [cardView.layer insertSublayer:gradientLayer atIndex:0];
    
    // 保存渐变层引用以便在viewDidLayoutSubviews中更新frame
    objc_setAssociatedObject(cardView, "gradientLayer", gradientLayer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 添加阴影（注意：masksToBounds需要为NO才能显示阴影）
    cardView.layer.shadowColor = [UIColor blackColor].CGColor;
    cardView.layer.shadowOffset = CGSizeMake(0, 4);
    cardView.layer.shadowRadius = 12;
    cardView.layer.shadowOpacity = 0.2;
    cardView.layer.masksToBounds = NO;
    
    // 图标标签
    UILabel *iconLabel = [[UILabel alloc] init];
    iconLabel.text = icon;
    iconLabel.font = [UIFont systemFontOfSize:48];
    iconLabel.textAlignment = NSTextAlignmentCenter;
    iconLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [cardView addSubview:iconLabel];
    
    // 标题标签
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = title;
    titleLabel.font = [UIFont boldSystemFontOfSize:22];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [cardView addSubview:titleLabel];
    
    // 副标题标签
    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.text = subtitle;
    subtitleLabel.font = [UIFont systemFontOfSize:14];
    subtitleLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.9];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [cardView addSubview:subtitleLabel];
    
    // 右箭头图标
    UIImageView *arrowImageView = [[UIImageView alloc] init];
    arrowImageView.image = [UIImage systemImageNamed:@"chevron.right"];
    arrowImageView.tintColor = [UIColor whiteColor];
    arrowImageView.translatesAutoresizingMaskIntoConstraints = NO;
    [cardView addSubview:arrowImageView];
    
    // 布局约束
    [NSLayoutConstraint activateConstraints:@[
        // 图标
        [iconLabel.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:20],
        [iconLabel.centerYAnchor constraintEqualToAnchor:cardView.centerYAnchor],
        [iconLabel.widthAnchor constraintEqualToConstant:60],
        [iconLabel.heightAnchor constraintEqualToConstant:60],
        
        // 标题
        [titleLabel.leadingAnchor constraintEqualToAnchor:iconLabel.trailingAnchor constant:16],
        [titleLabel.topAnchor constraintEqualToAnchor:cardView.centerYAnchor constant:-20],
        [titleLabel.trailingAnchor constraintEqualToAnchor:arrowImageView.leadingAnchor constant:-16],
        
        // 副标题
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:iconLabel.trailingAnchor constant:16],
        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:arrowImageView.leadingAnchor constant:-16],
        
        // 箭头
        [arrowImageView.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-20],
        [arrowImageView.centerYAnchor constraintEqualToAnchor:cardView.centerYAnchor],
        [arrowImageView.widthAnchor constraintEqualToConstant:20],
        [arrowImageView.heightAnchor constraintEqualToConstant:20],
    ]];
    
    // 添加点击手势
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:target action:action];
    tapGesture.numberOfTapsRequired = 1;
    tapGesture.numberOfTouchesRequired = 1;
    [cardView addGestureRecognizer:tapGesture];
    
    // 启用用户交互
    cardView.userInteractionEnabled = YES;
    
    return cardView;
}

- (void)cardLongPress:(UILongPressGestureRecognizer *)gesture {
    // 此方法已移除，不再使用
}

- (void)aiNoteButtonTapped:(id)sender {
    NSLog(@"点击 AI笔记 按钮，sender: %@", sender);
    
    // 获取卡片视图（可能是手势识别器的 view）
    UIView *cardView = nil;
    if ([sender isKindOfClass:[UITapGestureRecognizer class]]) {
        cardView = ((UITapGestureRecognizer *)sender).view;
    } else if ([sender isKindOfClass:[UIView class]]) {
        cardView = (UIView *)sender;
    }
    
    // 添加点击动画效果
    if (cardView) {
        [UIView animateWithDuration:0.1 animations:^{
            cardView.transform = CGAffineTransformMakeScale(0.95, 0.95);
            cardView.alpha = 0.8;
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.1 animations:^{
                cardView.transform = CGAffineTransformIdentity;
                cardView.alpha = 1.0;
            }];
        }];
    }
    
    // AI笔记小程序 appID: tyylldwlb8411tg8u2
    NSString *appId = @"tyylldwlb8411tg8u2";
    
    [[ThingMiniAppClient coreClient] openMiniAppByAppId:appId];
}

- (void)aiTranslateButtonTapped:(id)sender {
    NSLog(@"点击 AI翻译 按钮，sender: %@", sender);
    
    // 获取卡片视图（可能是手势识别器的 view）
    UIView *cardView = nil;
    if ([sender isKindOfClass:[UITapGestureRecognizer class]]) {
        cardView = ((UITapGestureRecognizer *)sender).view;
    } else if ([sender isKindOfClass:[UIView class]]) {
        cardView = (UIView *)sender;
    }
    
    // 添加点击动画效果
    if (cardView) {
        [UIView animateWithDuration:0.1 animations:^{
            cardView.transform = CGAffineTransformMakeScale(0.95, 0.95);
            cardView.alpha = 0.8;
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.1 animations:^{
                cardView.transform = CGAffineTransformIdentity;
                cardView.alpha = 1.0;
            }];
        }];
    }
    
    // AI翻译小程序 appID: ty0u9m1s5ea1k71m2h
    NSString *appId = @"ty0u9m1s5ea1k71m2h";
    [[ThingMiniAppClient coreClient] openMiniAppByAppId:appId];
}

- (void)homeSelectButtonTapped:(UIButton *)sender {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"家庭管理"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    // 如果有家庭列表，显示切换选项
    if (self.homeList.count > 0) {
        for (ThingSmartHomeModel *home in self.homeList) {
            NSString *title = home.name;
            if (self.selectedHome && self.selectedHome.homeId == home.homeId) {
                title = [NSString stringWithFormat:@"%@ ✓", home.name];
            }
            
            UIAlertAction *action = [UIAlertAction actionWithTitle:title
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * _Nonnull action) {
                [self selectHome:home];
            }];
            [alert addAction:action];
        }
    }
    
    // 创建家庭选项
    UIAlertAction *createAction = [UIAlertAction actionWithTitle:@"创建新家庭"
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * _Nonnull action) {
        [self showCreateHome];
    }];
    [alert addAction:createAction];
    
    // 取消选项
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [alert addAction:cancelAction];
    
    // iPad支持
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        alert.popoverPresentationController.sourceView = sender;
        alert.popoverPresentationController.sourceRect = sender.bounds;
    }
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)selectHome:(ThingSmartHomeModel *)home {
    self.selectedHome = home;
    [HomeManager setCurrentHome:home];
    [self updateHomeSelectButtonTitle];
    
    // 查询并缓存家庭详细信息
    [[HomeService sharedInstance] getHomeDataWithHomeId:home.homeId
                                                success:^(id result) {
        ThingSmartHomeModel *homeDetail = (ThingSmartHomeModel *)result;
        if (homeDetail) {
            [HomeManager cacheHomeDetail:homeDetail];
            NSLog(@"家庭详细信息已更新缓存 - 名称: %@, ID: %lld", homeDetail.name, homeDetail.homeId);
        }
    } failure:^(NSError *error) {
        NSLog(@"查询家庭详细信息失败: %@", error.localizedDescription);
    }];
}

- (void)updateHomeSelectButtonTitle {
    if (self.selectedHome) {
        [self.homeSelectButton setTitle:[NSString stringWithFormat:@"%@ ▼", self.selectedHome.name] forState:UIControlStateNormal];
    } else {
        [self.homeSelectButton setTitle:@"选择家庭 ▼" forState:UIControlStateNormal];
    }
    [self.homeSelectButton sizeToFit];
    // 更新 titleView
    self.navigationItem.titleView = self.homeSelectButton;
}

- (void)familyManageButtonTapped:(UIButton *)sender {
    // 跳转到家庭管理页面
    id<ThingFamilyProtocol> impl = [[ThingSmartBizCore sharedInstance] serviceOfProtocol:@protocol(ThingFamilyProtocol)];
    if ([impl respondsToSelector:@selector(gotoFamilyManagement)]) {
        [impl gotoFamilyManagement];
    } else {
        [UIHelper showAlertInViewController:self title:@"提示" message:@"家庭管理功能暂不可用"];
    }
}

- (void)showCreateHome {
    CreateHomeViewController *createHomeVC = [[CreateHomeViewController alloc] init];
    createHomeVC.delegate = self;
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:createHomeVC];
    [self presentViewController:navController animated:YES completion:nil];
}

- (void)loadHomeList {
    [[HomeService sharedInstance] getHomeListWithSuccess:^(id result) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.homeList = (NSArray<ThingSmartHomeModel *> *)result;
            
            if (self.homeList.count == 0) {
                
                [[[ThingSmartHomeManager alloc] init] addHomeWithName:@"home" geoName:@"hangzhou" rooms:@[] latitude:0.0 longitude:0.0 success:^(long long result) {
                    NSLog(@"创建家庭成功，homeId: %lld", result);
                    self.home = [ThingSmartHome homeWithHomeId:result];
                    [self.home getHomeDataWithSuccess:^(ThingSmartHomeModel * _Nonnull homeModel) {
                        NSLog(@"获取家庭详情成功，homeId: %lld", homeModel.homeId);
                    } failure:^(NSError *error) {
                        
                    }];
                } failure:^(NSError * _Nonnull error) {
                    NSLog(@"创建家庭失败: %@", error.localizedDescription);
                }];
            } else {
                ThingSmartHomeModel *homeModel = [self.homeList firstObject];
                self.home = [ThingSmartHome homeWithHomeId:homeModel.homeId];
                [self.home getHomeDataWithSuccess:^(ThingSmartHomeModel * _Nonnull homeModel) {
                    NSLog(@"获取家庭详情成功，homeId: %lld", homeModel.homeId);
                } failure:^(NSError *error) {
                    
                }];
            }
        });
    } failure:^(NSError *error) {
        NSLog(@"获取家庭列表失败: %@", error.localizedDescription);
    }];
}

#pragma mark - CreateHomeViewControllerDelegate

- (void)createHomeViewController:(CreateHomeViewController *)controller didCreateHomeSuccess:(BOOL)success {
    if (success) {
        // 刷新家庭列表
        [self loadHomeList];
    }
}

@end
