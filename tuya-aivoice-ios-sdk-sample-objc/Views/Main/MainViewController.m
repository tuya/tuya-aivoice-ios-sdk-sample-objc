//
//  MainViewController.m
//  AIVoiceDemo
//
//  Created by Bacson on 2026/1/28.
//

#import "MainViewController.h"
#import "HomeService.h"
#import "HomeManager.h"
#import "UIHelper.h"
#import "ActivatorService.h"
#import "DeviceService.h"
#import "DeviceListView.h"
#import <ThingSmartDeviceKit/ThingSmartDeviceKit.h>
#import <ThingModuleServices/ThingModuleServices.h>
#import <ThingSmartBizCore/ThingSmartBizCore.h>
#import <ThingSmartMiniAppBizBundle/ThingSmartMiniAppBizBundle.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import <ThingSmartFamilyBizKit/ThingSmartFamilyBizKit.h>

@interface MainViewController () <DeviceListViewDelegate, ThingFamilyProtocol>

@property (nonatomic, strong) ThingSmartHomeModel *currentHome;
@property (nonatomic, strong) ThingSmartHome *home;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIView *aiNoteCard;
@property (nonatomic, strong) UIView *aiTranslateCard;
@property (nonatomic, strong) UILabel *deviceListTitleLabel;
@property (nonatomic, strong) DeviceListView *deviceListView;

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
    
    // 更新渐变层frame（包括 contentView 中的卡片）
    [self updateGradientLayersInView:self.view];
}

- (void)updateGradientLayersInView:(UIView *)view {
    for (UIView *subview in view.subviews) {
        CAGradientLayer *gradientLayer = objc_getAssociatedObject(subview, "gradientLayer");
        if (gradientLayer) {
            gradientLayer.frame = subview.bounds;
        }
        // 递归检查子视图
        if (subview.subviews.count > 0) {
            [self updateGradientLayersInView:subview];
        }
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // 恢复导航栏外观（防止从其他页面返回后导航栏变黑）
    [self setupNavigationBarAppearance];
    
    // 每次页面显示时刷新家庭列表
    [self loadHomeList];
    
    // 刷新设备列表
    [self refreshDeviceList];
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
    // 设置标题
    self.title = @"首页";
    
    // 添加设备按钮 - 放在导航栏右侧
    UIBarButtonItem *addDeviceButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addDeviceButtonTapped:)];
    self.navigationItem.rightBarButtonItem = addDeviceButton;
    
    // 设置滚动视图
    [self setupScrollView];
    
    // 添加小程序入口
    [self setupMiniAppButtons];
    
    // 添加设备列表区域
    [self setupDeviceListSection];
}

- (void)setupScrollView {
    // 创建滚动视图
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.showsVerticalScrollIndicator = YES;
    [self.view addSubview:self.scrollView];
    
    // 创建内容视图
    self.contentView = [[UIView alloc] init];
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.contentView];
    
    // 布局约束
    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        
        [self.contentView.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor],
        [self.contentView.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor],
        [self.contentView.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor],
        [self.contentView.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor],
        [self.contentView.widthAnchor constraintEqualToAnchor:self.scrollView.widthAnchor],
    ]];
}

- (void)setupMiniAppButtons {
    // AI笔记卡片容器
    self.aiNoteCard = [self createMiniAppCardWithTitle:@"AI笔记"
                                                subtitle:@"智能笔记助手"
                                                  icon:@"📝"
                                            gradientColors:@[[UIColor colorWithRed:0.2 green:0.4 blue:1.0 alpha:1.0],
                                                             [UIColor colorWithRed:0.4 green:0.6 blue:1.0 alpha:1.0]]
                                                 target:self
                                                 action:@selector(aiNoteButtonTapped:)];
    [self.contentView addSubview:self.aiNoteCard];
    
    // AI翻译卡片容器
    self.aiTranslateCard = [self createMiniAppCardWithTitle:@"AI翻译"
                                                     subtitle:@"多语言翻译工具"
                                                       icon:@"🌐"
                                                 gradientColors:@[[UIColor colorWithRed:0.2 green:0.8 blue:0.4 alpha:1.0],
                                                                  [UIColor colorWithRed:0.4 green:0.9 blue:0.6 alpha:1.0]]
                                                      target:self
                                                      action:@selector(aiTranslateButtonTapped:)];
    [self.contentView addSubview:self.aiTranslateCard];
    
    // 布局约束
    [NSLayoutConstraint activateConstraints:@[
        // AI笔记卡片
        [self.aiNoteCard.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
        [self.aiNoteCard.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:40],
        [self.aiNoteCard.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.aiNoteCard.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        [self.aiNoteCard.heightAnchor constraintEqualToConstant:120],
        
        // AI翻译卡片
        [self.aiTranslateCard.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
        [self.aiTranslateCard.topAnchor constraintEqualToAnchor:self.aiNoteCard.bottomAnchor constant:16],
        [self.aiTranslateCard.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.aiTranslateCard.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        [self.aiTranslateCard.heightAnchor constraintEqualToConstant:120],
    ]];
}

- (void)setupDeviceListSection {
    // 设备列表标题
    self.deviceListTitleLabel = [[UILabel alloc] init];
    self.deviceListTitleLabel.text = @"我的设备";
    self.deviceListTitleLabel.font = [UIFont boldSystemFontOfSize:20];
    self.deviceListTitleLabel.textColor = [UIColor labelColor];
    self.deviceListTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.deviceListTitleLabel];
    
    // 设备列表视图
    self.deviceListView = [[DeviceListView alloc] init];
    self.deviceListView.delegate = self;
    self.deviceListView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.deviceListView];
    
    // 布局约束
    [NSLayoutConstraint activateConstraints:@[
        // 设备列表标题
        [self.deviceListTitleLabel.topAnchor constraintEqualToAnchor:self.aiTranslateCard.bottomAnchor constant:24],
        [self.deviceListTitleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.deviceListTitleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        
        // 设备列表视图
        [self.deviceListView.topAnchor constraintEqualToAnchor:self.deviceListTitleLabel.bottomAnchor constant:12],
        [self.deviceListView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.deviceListView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.deviceListView.heightAnchor constraintEqualToConstant:160],
        [self.deviceListView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-20],
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


- (void)loadHomeList {
    [[HomeService sharedInstance] getHomeListWithSuccess:^(id result) {
        NSArray<ThingSmartHomeModel *> *homeList = (NSArray<ThingSmartHomeModel *> *)result;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (homeList.count == 0) {
                // 没有家庭，创建默认家庭
                NSLog(@"没有家庭，开始创建默认家庭");
                NSString *defaultName = @"我的家庭";
                NSString *defaultCity = @"北京";
                
                [[HomeService sharedInstance] addHomeWithName:defaultName
                                                      geoName:defaultCity
                                                        rooms:@[@""]
                                                     latitude:39.9042
                                                    longitude:116.4074
                                                      success:^(id result) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        long long homeId = [result longLongValue];
                        NSLog(@"创建家庭成功，homeId: %lld", homeId);
                        
                        // 获取创建的家庭信息并设置为当前家庭
                        ThingSmartHome *home = [ThingSmartHome homeWithHomeId:homeId];
                        self.home = home;
                        [home getHomeDataWithSuccess:^(ThingSmartHomeModel * _Nonnull homeModel) {
                            NSLog(@"获取家庭详情成功，homeId: %lld", homeModel.homeId);
                            self.currentHome = homeModel;
                            [HomeManager setCurrentHome:homeModel];
                            [HomeManager cacheHomeDetail:homeModel];
                            
                            // 初始化当前家庭（注册协议并设置delegate）
                            [self initCurrentHome];
                            
                            // 刷新设备列表
                            [self refreshDeviceList];
                        } failure:^(NSError *error) {
                            NSLog(@"获取家庭详情失败: %@", error.localizedDescription);
                        }];
                    });
                } failure:^(NSError *error) {
                    NSLog(@"创建家庭失败: %@", error.localizedDescription);
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [UIHelper showAlertInViewController:self title:@"提示" message:@"创建家庭失败，请稍后重试"];
                    });
                }];
            } else {
                // 有家庭，使用第一个家庭
                ThingSmartHomeModel *homeModel = homeList.firstObject;
                NSLog(@"使用家庭: %@, ID: %lld", homeModel.name, homeModel.homeId);
                
                self.currentHome = homeModel;
                [HomeManager setCurrentHome:homeModel];
                
                // 获取家庭详细信息并缓存
                self.home = [ThingSmartHome homeWithHomeId:homeModel.homeId];
                [self.home getHomeDataWithSuccess:^(ThingSmartHomeModel * _Nonnull homeDetail) {
                    NSLog(@"获取家庭详情成功，homeId: %lld", homeDetail.homeId);
                    self.currentHome = homeDetail;
                    [HomeManager setCurrentHome:homeDetail];
                    [HomeManager cacheHomeDetail:homeDetail];
                    
                    // 初始化当前家庭（注册协议并设置delegate）
                    [self initCurrentHome];
                    
                    // 刷新设备列表
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self refreshDeviceList];
                    });
                } failure:^(NSError *error) {
                    NSLog(@"获取家庭详情失败: %@", error.localizedDescription);
                    // 即使获取详情失败，也刷新设备列表
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self refreshDeviceList];
                    });
                }];
            }
        });
    } failure:^(NSError *error) {
        NSLog(@"获取家庭列表失败: %@", error.localizedDescription);
        dispatch_async(dispatch_get_main_queue(), ^{
            [UIHelper showAlertInViewController:self title:@"提示" message:@"获取家庭列表失败，请稍后重试"];
        });
    }];
}

- (void)addDeviceButtonTapped:(UIBarButtonItem *)sender {
    NSLog(@"点击 添加设备 按钮");
    
    // 检查是否有当前家庭
    ThingSmartHomeModel *currentHome = self.currentHome ?: [HomeManager getCurrentHome];
    if (!currentHome) {
        [UIHelper showAlertInViewController:self title:@"提示" message:@"请稍候，正在加载家庭信息"];
        return;
    }
    
    // 设置配网完成回调
    __weak typeof(self) weakSelf = self;
    [[ActivatorService sharedInstance] setActivatorCompletion:^(NSArray * _Nullable deviceList) {
        NSLog(@"配网完成，设备列表: %@", deviceList);
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf refreshDeviceList];
            if (deviceList && deviceList.count > 0) {
                [UIHelper showAlertInViewController:weakSelf title:@"提示" message:[NSString stringWithFormat:@"成功添加 %lu 个设备", (unsigned long)deviceList.count]];
            }
        });
    }];
    
    // 进入配网页面
    [[ActivatorService sharedInstance] gotoDeviceConfig];
}

- (void)refreshDeviceList {
    [[DeviceService sharedInstance] getDeviceListWithSuccess:^(NSArray<ThingSmartDeviceModel *> * _Nullable deviceList) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.deviceListView reloadDevices:deviceList];
        });
    } failure:^(NSError *error) {
        NSLog(@"获取设备列表失败: %@", error.localizedDescription);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.deviceListView reloadDevices:@[]];
        });
    }];
}

#pragma mark - DeviceListViewDelegate

- (void)deviceListView:(UIView *)view didSelectDevice:(ThingSmartDeviceModel *)device {
    NSLog(@"点击设备: %@", device.name);
    // 可以在这里添加跳转到设备详情页面的逻辑
}

#pragma mark - ThingFamilyProtocol

- (void)initCurrentHome {
    if (!self.currentHome) {
        NSLog(@"initCurrentHome: 当前家庭不存在，无法初始化");
        return;
    }
    
    long long homeId = self.currentHome.homeId;
    // 注册要实现的协议
    [[ThingSmartBizCore sharedInstance] registerService:@protocol(ThingFamilyProtocol) withInstance:self];
    id<ThingFamilyProtocol> impl = [[ThingSmartBizCore sharedInstance] serviceOfProtocol:@protocol(ThingFamilyProtocol)];
    if ([impl respondsToSelector:@selector(updateCurrentFamilyId:)]) {
        [impl updateCurrentFamilyId:homeId];
        
        // 如果 home 还没有创建，则创建
        if (!self.home) {
            self.home = [ThingSmartHome homeWithHomeId:homeId];
        }
        
        NSLog(@"initCurrentHome: 已更新当前家庭ID为 %lld，并设置 delegate", homeId);
    }
}

@end
