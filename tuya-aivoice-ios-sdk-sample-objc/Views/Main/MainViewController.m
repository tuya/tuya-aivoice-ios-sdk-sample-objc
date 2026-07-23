//
//  MainViewController.m
//  AIVoiceDemo
//
//  Created by Bacson on 2026/1/28.
//

#import "MainViewController.h"
#import "MiniAppRoutes.h"
#import "UIHelper.h"
#import "ActivatorService.h"
#import "CustomBLEPairingViewController.h"
#import "CustomBLEPairingSession.h"
#import "DeviceService.h"
#import "DeviceListView.h"
#import <ThingSmartDeviceKit/ThingSmartDeviceKit.h>
#import <ThingModuleServices/ThingModuleServices.h>
#import <ThingModuleServices/ThingFamilyProtocol.h>
#import <ThingModuleServices/ThingSmartHomeDataProtocol.h>
#import <ThingSmartBizCore/ThingSmartBizCore.h>
#import <ThingSmartMiniAppBizBundle/ThingSmartMiniAppBizBundle.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

@interface MainViewController () <DeviceListViewDelegate, ThingFamilyProtocol, ThingSmartHomeDataProtocol>

@property (nonatomic, strong) ThingSmartHomeModel *currentHome;
@property (nonatomic, strong) ThingSmartHome *home;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIView *aiNoteCard;
@property (nonatomic, strong) UIView *aiNoteQuickActionsView;
@property (nonatomic, strong) UIView *aiTranslateCard;
@property (nonatomic, strong) UIView *aiTranslateQuickActionsView;
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
    
    // 每次页面显示时刷新家庭列表；成功后会刷新当前家庭下的设备。
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
                                         gradientColors:@[[UIColor colorWithRed:0.15 green:0.35 blue:0.95 alpha:1.0],
                                                          [UIColor colorWithRed:0.35 green:0.55 blue:1.0 alpha:1.0]]
                                                 target:self
                                                 action:@selector(aiNoteButtonTapped:)];
    [self.contentView addSubview:self.aiNoteCard];
    
    // AI笔记快捷功能区域（卡片内部底部）
    self.aiNoteQuickActionsView = [self createQuickActionsViewWithActions:@[
        @{@"title": @"录音", @"icon": @"mic.fill", @"url": kMiniAppURLAINoteLiveRecording},
        @{@"title": @"同声传译", @"icon": @"waveform.path", @"url": kMiniAppURLAINoteSimultaneousInterpretation},
        @{@"title": @"实时转写", @"icon": @"text.bubble.fill", @"url": kMiniAppURLAINoteRealTimeRecording}
    ]];
    [self.aiNoteCard addSubview:self.aiNoteQuickActionsView];
    
    // AI翻译卡片容器
    self.aiTranslateCard = [self createMiniAppCardWithTitle:@"AI翻译"
                                                    subtitle:@"多语言翻译工具"
                                                        icon:@"🌐"
                                              gradientColors:@[[UIColor colorWithRed:0.15 green:0.75 blue:0.35 alpha:1.0],
                                                               [UIColor colorWithRed:0.35 green:0.85 blue:0.55 alpha:1.0]]
                                                     target:self
                                                     action:@selector(aiTranslateButtonTapped:)];
    [self.contentView addSubview:self.aiTranslateCard];
    
    // AI翻译快捷功能区域（卡片内部底部）
    self.aiTranslateQuickActionsView = [self createQuickActionsViewWithActions:@[
        @{@"title": @"同声传译", @"icon": @"waveform.path", @"url": kMiniAppURLAITranslateSimultaneous},
        @{@"title": @"对话翻译", @"icon": @"message.fill", @"url": kMiniAppURLAITranslateFaceToFace}
    ]];
    [self.aiTranslateCard addSubview:self.aiTranslateQuickActionsView];
    
    // 布局约束
    [NSLayoutConstraint activateConstraints:@[
        // AI笔记卡片
        [self.aiNoteCard.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
        [self.aiNoteCard.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:40],
        [self.aiNoteCard.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.aiNoteCard.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        [self.aiNoteCard.heightAnchor constraintEqualToConstant:200],
        
        // AI笔记快捷功能区域（卡片内部底部）
        [self.aiNoteQuickActionsView.leadingAnchor constraintEqualToAnchor:self.aiNoteCard.leadingAnchor constant:16],
        [self.aiNoteQuickActionsView.trailingAnchor constraintEqualToAnchor:self.aiNoteCard.trailingAnchor constant:-16],
        [self.aiNoteQuickActionsView.bottomAnchor constraintEqualToAnchor:self.aiNoteCard.bottomAnchor constant:-16],
        [self.aiNoteQuickActionsView.heightAnchor constraintEqualToConstant:80],
        
        // AI翻译卡片
        [self.aiTranslateCard.topAnchor constraintEqualToAnchor:self.aiNoteCard.bottomAnchor constant:20],
        [self.aiTranslateCard.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.aiTranslateCard.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        [self.aiTranslateCard.heightAnchor constraintEqualToConstant:200],
        
        // AI翻译快捷功能区域（卡片内部底部）
        [self.aiTranslateQuickActionsView.leadingAnchor constraintEqualToAnchor:self.aiTranslateCard.leadingAnchor constant:16],
        [self.aiTranslateQuickActionsView.trailingAnchor constraintEqualToAnchor:self.aiTranslateCard.trailingAnchor constant:-16],
        [self.aiTranslateQuickActionsView.bottomAnchor constraintEqualToAnchor:self.aiTranslateCard.bottomAnchor constant:-16],
        [self.aiTranslateQuickActionsView.heightAnchor constraintEqualToConstant:80],
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
        [self.deviceListView.heightAnchor constraintEqualToConstant:400],
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
    cardView.layer.cornerRadius = 20;
    cardView.backgroundColor = [UIColor clearColor];
    
    // 添加渐变背景
    CAGradientLayer *gradientLayer = [CAGradientLayer layer];
    gradientLayer.colors = @[(__bridge id)colors[0].CGColor, (__bridge id)colors[1].CGColor];
    gradientLayer.startPoint = CGPointMake(0, 0);
    gradientLayer.endPoint = CGPointMake(1, 1);
    gradientLayer.cornerRadius = 20;
    [cardView.layer insertSublayer:gradientLayer atIndex:0];
    
    // 保存渐变层引用以便在viewDidLayoutSubviews中更新frame
    objc_setAssociatedObject(cardView, "gradientLayer", gradientLayer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 添加阴影（注意：masksToBounds需要为NO才能显示阴影）
    cardView.layer.shadowColor = [UIColor blackColor].CGColor;
    cardView.layer.shadowOffset = CGSizeMake(0, 4);
    cardView.layer.shadowRadius = 16;
    cardView.layer.shadowOpacity = 0.25;
    cardView.layer.masksToBounds = NO;
    
    // 图标标签
    UILabel *iconLabel = [[UILabel alloc] init];
    iconLabel.text = icon;
    iconLabel.font = [UIFont systemFontOfSize:56];
    iconLabel.textAlignment = NSTextAlignmentCenter;
    iconLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [cardView addSubview:iconLabel];
    
    // 标题标签
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = title;
    titleLabel.font = [UIFont boldSystemFontOfSize:24];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [cardView addSubview:titleLabel];
    
    // 副标题标签
    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.text = subtitle;
    subtitleLabel.font = [UIFont systemFontOfSize:15];
    subtitleLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.95];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [cardView addSubview:subtitleLabel];
    
    // 布局约束
    [NSLayoutConstraint activateConstraints:@[
        // 图标放在卡片上半部分偏上位置
        [iconLabel.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:24],
        [iconLabel.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:24],
        [iconLabel.widthAnchor constraintEqualToConstant:70],
        [iconLabel.heightAnchor constraintEqualToConstant:70],
        
        // 标题
        [titleLabel.leadingAnchor constraintEqualToAnchor:iconLabel.trailingAnchor constant:18],
        [titleLabel.topAnchor constraintEqualToAnchor:iconLabel.topAnchor constant:4],
        [titleLabel.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-24],
        
        // 副标题
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:iconLabel.trailingAnchor constant:18],
        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:6],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-24],
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

- (UIView *)createQuickActionsContainerWithActions:(NSArray<NSDictionary *> *)actions parentView:(UIView *)parentView {
    UIView *containerView = [[UIView alloc] init];
    containerView.translatesAutoresizingMaskIntoConstraints = NO;
    containerView.backgroundColor = [UIColor clearColor];
    
    // 创建横向滚动视图
    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.showsHorizontalScrollIndicator = NO;
    scrollView.showsVerticalScrollIndicator = NO;
    scrollView.backgroundColor = [UIColor clearColor];
    [containerView addSubview:scrollView];
    
    // 创建内容视图
    UIView *contentView = [[UIView alloc] init];
    contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [scrollView addSubview:contentView];
    
    NSMutableArray<UIView *> *actionButtons = [NSMutableArray array];
    
    // 创建快捷功能按钮
    for (NSInteger i = 0; i < actions.count; i++) {
        NSDictionary *action = actions[i];
        NSString *title = action[@"title"];
        NSString *iconName = action[@"icon"];
        NSString *url = action[@"url"];
        
        // 创建按钮容器（半透明白色背景）
        UIView *buttonContainer = [[UIView alloc] init];
        buttonContainer.translatesAutoresizingMaskIntoConstraints = NO;
        buttonContainer.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.25];
        buttonContainer.layer.cornerRadius = 12;
        buttonContainer.layer.borderWidth = 1.0;
        buttonContainer.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.3].CGColor;
        [contentView addSubview:buttonContainer];
        
        // 图标
        UIImageView *iconView = [[UIImageView alloc] init];
        iconView.image = [UIImage systemImageNamed:iconName];
        iconView.tintColor = [UIColor whiteColor];
        iconView.contentMode = UIViewContentModeScaleAspectFit;
        iconView.translatesAutoresizingMaskIntoConstraints = NO;
        [buttonContainer addSubview:iconView];
        
        // 标题
        UILabel *titleLabel = [[UILabel alloc] init];
        titleLabel.text = title;
        titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
        titleLabel.textColor = [UIColor whiteColor];
        titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel.numberOfLines = 1;
        titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [buttonContainer addSubview:titleLabel];
        
        // 布局约束
        [NSLayoutConstraint activateConstraints:@[
            [iconView.topAnchor constraintEqualToAnchor:buttonContainer.topAnchor constant:10],
            [iconView.centerXAnchor constraintEqualToAnchor:buttonContainer.centerXAnchor],
            [iconView.widthAnchor constraintEqualToConstant:22],
            [iconView.heightAnchor constraintEqualToConstant:22],
            
            [titleLabel.topAnchor constraintEqualToAnchor:iconView.bottomAnchor constant:6],
            [titleLabel.leadingAnchor constraintEqualToAnchor:buttonContainer.leadingAnchor constant:6],
            [titleLabel.trailingAnchor constraintEqualToAnchor:buttonContainer.trailingAnchor constant:-6],
            [titleLabel.bottomAnchor constraintEqualToAnchor:buttonContainer.bottomAnchor constant:-10],
        ]];
        
        // 添加点击手势
        UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(quickActionTapped:)];
        tapGesture.cancelsTouchesInView = YES;
        buttonContainer.userInteractionEnabled = YES;
        [buttonContainer addGestureRecognizer:tapGesture];
        
        // 保存URL到关联对象
        objc_setAssociatedObject(buttonContainer, "actionURL", url, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        [actionButtons addObject:buttonContainer];
    }
    
    // 布局按钮
    if (actionButtons.count > 0) {
        UIView *firstButton = actionButtons[0];
        [NSLayoutConstraint activateConstraints:@[
            [firstButton.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
            [firstButton.topAnchor constraintEqualToAnchor:contentView.topAnchor],
            [firstButton.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor],
            [firstButton.widthAnchor constraintEqualToConstant:70],
        ]];
        
        for (NSInteger i = 1; i < actionButtons.count; i++) {
            UIView *prevButton = actionButtons[i - 1];
            UIView *currentButton = actionButtons[i];
            
            [NSLayoutConstraint activateConstraints:@[
                [currentButton.leadingAnchor constraintEqualToAnchor:prevButton.trailingAnchor constant:10],
                [currentButton.topAnchor constraintEqualToAnchor:contentView.topAnchor],
                [currentButton.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor],
                [currentButton.widthAnchor constraintEqualToConstant:70],
            ]];
        }
        
        UIView *lastButton = actionButtons.lastObject;
        [NSLayoutConstraint activateConstraints:@[
            [lastButton.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        ]];
    }
    
    // 布局滚动视图和内容视图
    [NSLayoutConstraint activateConstraints:@[
        [scrollView.topAnchor constraintEqualToAnchor:containerView.topAnchor],
        [scrollView.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:containerView.bottomAnchor],
        
        [contentView.topAnchor constraintEqualToAnchor:scrollView.topAnchor],
        [contentView.leadingAnchor constraintEqualToAnchor:scrollView.leadingAnchor],
        [contentView.trailingAnchor constraintEqualToAnchor:scrollView.trailingAnchor],
        [contentView.bottomAnchor constraintEqualToAnchor:scrollView.bottomAnchor],
        [contentView.heightAnchor constraintEqualToAnchor:scrollView.heightAnchor],
    ]];
    
    return containerView;
}

- (UIView *)createQuickActionsViewWithActions:(NSArray<NSDictionary *> *)actions {
    UIView *containerView = [[UIView alloc] init];
    containerView.translatesAutoresizingMaskIntoConstraints = NO;
    containerView.backgroundColor = [UIColor clearColor];
    
    // 创建横向滚动视图
    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.showsHorizontalScrollIndicator = NO;
    scrollView.showsVerticalScrollIndicator = NO;
    scrollView.backgroundColor = [UIColor clearColor];
    [containerView addSubview:scrollView];
    
    // 创建内容视图
    UIView *contentView = [[UIView alloc] init];
    contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [scrollView addSubview:contentView];
    
    NSMutableArray<UIView *> *actionButtons = [NSMutableArray array];
    
    // 创建快捷功能按钮
    for (NSInteger i = 0; i < actions.count; i++) {
        NSDictionary *action = actions[i];
        NSString *title = action[@"title"];
        NSString *iconName = action[@"icon"];
        NSString *url = action[@"url"];
        
        // 创建按钮容器（浅色背景，与卡片形成对比）
        UIView *buttonContainer = [[UIView alloc] init];
        buttonContainer.translatesAutoresizingMaskIntoConstraints = NO;
        buttonContainer.backgroundColor = [UIColor secondarySystemBackgroundColor];
        buttonContainer.layer.cornerRadius = 14;
        buttonContainer.layer.shadowColor = [UIColor blackColor].CGColor;
        buttonContainer.layer.shadowOffset = CGSizeMake(0, 2);
        buttonContainer.layer.shadowRadius = 6;
        buttonContainer.layer.shadowOpacity = 0.08;
        [contentView addSubview:buttonContainer];
        
        // 图标
        UIImageView *iconView = [[UIImageView alloc] init];
        iconView.image = [UIImage systemImageNamed:iconName];
        iconView.tintColor = [UIColor systemBlueColor];
        iconView.contentMode = UIViewContentModeScaleAspectFit;
        iconView.translatesAutoresizingMaskIntoConstraints = NO;
        [buttonContainer addSubview:iconView];
        
        // 标题
        UILabel *titleLabel = [[UILabel alloc] init];
        titleLabel.text = title;
        titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        titleLabel.textColor = [UIColor labelColor];
        titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel.numberOfLines = 1;
        titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [buttonContainer addSubview:titleLabel];
        
        // 布局约束
        [NSLayoutConstraint activateConstraints:@[
            [iconView.topAnchor constraintEqualToAnchor:buttonContainer.topAnchor constant:12],
            [iconView.centerXAnchor constraintEqualToAnchor:buttonContainer.centerXAnchor],
            [iconView.widthAnchor constraintEqualToConstant:24],
            [iconView.heightAnchor constraintEqualToConstant:24],
            
            [titleLabel.topAnchor constraintEqualToAnchor:iconView.bottomAnchor constant:6],
            [titleLabel.leadingAnchor constraintEqualToAnchor:buttonContainer.leadingAnchor constant:8],
            [titleLabel.trailingAnchor constraintEqualToAnchor:buttonContainer.trailingAnchor constant:-8],
            [titleLabel.bottomAnchor constraintEqualToAnchor:buttonContainer.bottomAnchor constant:-12],
        ]];
        
        // 添加点击手势
        UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(quickActionTapped:)];
        tapGesture.cancelsTouchesInView = YES;
        buttonContainer.userInteractionEnabled = YES;
        [buttonContainer addGestureRecognizer:tapGesture];
        
        // 保存URL到关联对象
        objc_setAssociatedObject(buttonContainer, "actionURL", url, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        [actionButtons addObject:buttonContainer];
    }
    
    // 布局按钮
    if (actionButtons.count > 0) {
        UIView *firstButton = actionButtons[0];
        [NSLayoutConstraint activateConstraints:@[
            [firstButton.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
            [firstButton.topAnchor constraintEqualToAnchor:contentView.topAnchor],
            [firstButton.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor],
            [firstButton.widthAnchor constraintEqualToConstant:80],
        ]];
        
        for (NSInteger i = 1; i < actionButtons.count; i++) {
            UIView *prevButton = actionButtons[i - 1];
            UIView *currentButton = actionButtons[i];
            
            [NSLayoutConstraint activateConstraints:@[
                [currentButton.leadingAnchor constraintEqualToAnchor:prevButton.trailingAnchor constant:12],
                [currentButton.topAnchor constraintEqualToAnchor:contentView.topAnchor],
                [currentButton.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor],
                [currentButton.widthAnchor constraintEqualToConstant:80],
            ]];
        }
        
        UIView *lastButton = actionButtons.lastObject;
        [NSLayoutConstraint activateConstraints:@[
            [lastButton.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        ]];
    }
    
    // 布局滚动视图和内容视图
    [NSLayoutConstraint activateConstraints:@[
        [scrollView.topAnchor constraintEqualToAnchor:containerView.topAnchor],
        [scrollView.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:containerView.bottomAnchor],
        
        [contentView.topAnchor constraintEqualToAnchor:scrollView.topAnchor],
        [contentView.leadingAnchor constraintEqualToAnchor:scrollView.leadingAnchor],
        [contentView.trailingAnchor constraintEqualToAnchor:scrollView.trailingAnchor],
        [contentView.bottomAnchor constraintEqualToAnchor:scrollView.bottomAnchor],
        [contentView.heightAnchor constraintEqualToAnchor:scrollView.heightAnchor],
    ]];
    
    return containerView;
}

- (void)quickActionTapped:(UITapGestureRecognizer *)gesture {
    UIView *buttonView = gesture.view;
    NSString *url = objc_getAssociatedObject(buttonView, "actionURL");
    
    if (url && url.length > 0) {
        NSLog(@"点击快捷功能，URL: %@", url);
        // URL格式: thingSmart://miniApp?url=godzilla%3A%2F%2F...
        // 需要提取url参数的值并解码
        NSURLComponents *components = [NSURLComponents componentsWithString:url];
        if (components) {
            for (NSURLQueryItem *item in components.queryItems) {
                if ([item.name isEqualToString:@"url"]) {
                    NSString *miniAppUrl = item.value;
                    if (miniAppUrl) {
                        NSLog(@"打开小程序，URL: %@", miniAppUrl);
                        [[ThingMiniAppClient coreClient] openMiniAppByUrl:miniAppUrl];
                        return;
                    }
                }
            }
        }
        // 如果解析失败，尝试直接使用URL
        NSLog(@"无法解析URL参数，尝试直接打开: %@", url);
        [[ThingMiniAppClient coreClient] openMiniAppByUrl:url];
    }
}

- (void)aiNoteButtonTapped:(id)sender {
    
    // 获取卡片视图（可能是手势识别器的 view）
    UIView *cardView = nil;
    if ([sender isKindOfClass:[UITapGestureRecognizer class]]) {
        cardView = ((UITapGestureRecognizer *)sender).view;
    } else if ([sender isKindOfClass:[UIView class]]) {
        cardView = (UIView *)sender;
    }
    
    [[ThingMiniAppClient coreClient] openMiniAppByAppId:kMiniAppIdAINote];
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
    
    [[ThingMiniAppClient coreClient] openMiniAppByAppId:kMiniAppIdAITranslate];
}

- (void)addDeviceButtonTapped:(UIBarButtonItem *)sender {
    NSLog(@"点击 添加设备 按钮");

    if (![ThingSmartUser sharedInstance].isLogin) {
        [UIHelper showAlertInViewController:self title:@"提示" message:@"请先登录后再添加设备"];
        return;
    }

    ThingSmartHomeModel *currentHome = self.currentHome;
    if (!currentHome || currentHome.homeId <= 0) {
        [UIHelper showAlertInViewController:self title:@"请先选择家庭" message:@"请从首页顶部的家庭名称进入家庭管理，创建或加入一个家庭后再添加设备。"];
        return;
    }

    [self initCurrentHome];

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"添加设备"
                                                                    message:@"请选择配网方式"
                                                             preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf = self;
    [sheet addAction:[UIAlertAction actionWithTitle:@"正常添加" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [weakSelf startNormalDevicePairing];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"自定义添加（BLE 调试）" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [weakSelf startCustomBLEPairing];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];

    UIPopoverPresentationController *popover = sheet.popoverPresentationController;
    if (popover) {
        popover.barButtonItem = sender;
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)startNormalDevicePairing {
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
    [[ActivatorService sharedInstance] gotoDeviceConfig];
}

- (void)startCustomBLEPairing {
    long long homeID = self.currentHome.homeId;
    __weak typeof(self) weakSelf = self;
    CustomBLEPairingViewController *controller = [[CustomBLEPairingViewController alloc] initWithHomeID:homeID completion:^(CustomBLEPairingDevice *device) {
        NSLog(@"自定义 BLE 配网成功，devId: %@", device.deviceID);
        [weakSelf refreshDeviceList];
    }];
    [self.navigationController pushViewController:controller animated:YES];
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

#pragma mark - 设备相关

/*
 MARK: AIVoice 跳转设备详情页
 如果需要跳转到tuya的设备面板，可以调用 gotoDeviceDetailDetailViewControllerWithDevice 进行跳转，
 需要保证有包含设备详情的UI业务包同时初始化了小程序
*/
- (void)deviceListView:(UIView *)view didSelectDevice:(ThingSmartDeviceModel *)device {
    NSLog(@"点击设备: %@", device.name);
    
    // 跳转设备面板页
    ThingSmartDevice *smartDevice = [ThingSmartDevice deviceWithDeviceId:device.devId];
    id<ThingPanelProtocol> impl = [[ThingSmartBizCore sharedInstance] serviceOfProtocol:@protocol(ThingPanelProtocol)];
    if (impl) {
        [impl gotoPanelViewControllerWithDevice:smartDevice.deviceModel group:nil initialProps:nil contextProps:nil completion:nil];
    }
}

#pragma mark - 当前设备空间

- (void)loadHomeList {
    ThingSmartHomeManager *manager = [ThingSmartHomeManager new];
    [manager getHomeListWithSuccess:^(NSArray<ThingSmartHomeModel *> *homes) {
        ThingSmartHomeModel *homeModel = homes.firstObject;
        if (!homeModel || homeModel.homeId <= 0) {
            // 新用户无家庭，自动创建默认家庭。
            self.currentHome = nil;
            self.home = nil;
            [self createDefaultHome];
            return;
        }
        self.currentHome = homeModel;
        self.home = [ThingSmartHome homeWithHomeId:homeModel.homeId];
        [self.home getHomeDataWithSuccess:^(ThingSmartHomeModel *homeDetail) {
            self.currentHome = homeDetail;
            [self initCurrentHome];
            [self refreshDeviceList];
        } failure:^(NSError *error) {
            [self initCurrentHome];
            [self refreshDeviceList];
        }];
    } failure:^(NSError *error) {
        NSLog(@"获取家庭列表失败: %@", error.localizedDescription);
        [self.deviceListView reloadDevices:@[]];
    }];
}

/// 新用户首次登录后自动创建默认家庭。
- (void)createDefaultHome {
    ThingSmartHomeManager *manager = [ThingSmartHomeManager new];
    [manager addHomeWithName:@"我的家庭"
                     geoName:@"杭州"
                       rooms:@[@"客厅"]
                    latitude:30.27
                   longitude:120.15
                     success:^(long long homeId) {
        NSLog(@"默认家庭创建成功，homeId: %lld", homeId);
        // 创建成功后重新加载家庭列表。
        [self loadHomeList];
    } failure:^(NSError *error) {
        NSLog(@"默认家庭创建失败: %@", error.localizedDescription);
        [self.deviceListView reloadDevices:@[]];
    }];
}

/*
 MARK: AIVoice 设置当前家庭
 在创建完家庭后，需要设置当前家庭才能获取到家庭下的设备信息，
 如果只有一个家庭，请保证界面初始化时调用 updateCurrentFamilyId 更新当前家庭
*/
- (void)initCurrentHome {
    if (!self.currentHome) {
        NSLog(@"initCurrentHome: 当前家庭不存在，无法初始化");
        return;
    }

    long long homeId = self.currentHome.homeId;
    if (homeId <= 0) {
        NSLog(@"initCurrentHome: 当前家庭 ID 无效");
        return;
    }

    if (!self.home) {
        self.home = [ThingSmartHome homeWithHomeId:homeId];
    }

    // 7.5 使用 ThingFamilyProtocol；同时保留旧协议供仍依赖它的业务包调用。
    [[ThingSmartBizCore sharedInstance] registerService:@protocol(ThingFamilyProtocol) withInstance:self];
    [[ThingSmartBizCore sharedInstance] registerService:@protocol(ThingSmartHomeDataProtocol) withInstance:self];
    NSLog(@"initCurrentHome: 已注册当前家庭服务，homeId: %lld", homeId);
}

#pragma mark - ThingFamilyProtocol / ThingSmartHomeDataProtocol

- (long long)currentFamilyId {
    return self.currentHome.homeId;
}

- (ThingSmartHome *)getCurrentHome {
    long long homeId = [self currentFamilyId];
    if (homeId <= 0) {
        return nil;
    }

    if (!self.home) {
        self.home = [ThingSmartHome homeWithHomeId:homeId];
    }
    return self.home;
}

@end
