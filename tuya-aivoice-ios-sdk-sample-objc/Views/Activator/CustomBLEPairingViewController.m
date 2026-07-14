//
//  CustomBLEPairingViewController.m
//  tuya-aivoice-ios-sdk-sample-objc
//

#import "CustomBLEPairingViewController.h"
#import "CustomBLEPairingSession.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import <QuartzCore/QuartzCore.h>

@interface CustomBLEPairingViewController () <UITableViewDataSource, UITableViewDelegate, CBCentralManagerDelegate>
@property (nonatomic, assign) long long homeID;
@property (nonatomic, copy, nullable) CustomBLEPairingViewCompletion completion;
@property (nonatomic, strong) CustomBLEPairingSession *session;
@property (nonatomic, assign) CustomBLEPairingState state;
@property (nonatomic, copy) NSArray<CustomBLEPairingDevice *> *devices;
@property (nonatomic, strong) NSMutableArray<NSString *> *logLines;
@property (nonatomic, strong) NSDate *startedAt;
@property (nonatomic, strong) NSTimer *elapsedTimer;
@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) UILabel *homeLabel;
@property (nonatomic, strong) UILabel *bluetoothLabel;
@property (nonatomic, strong) UILabel *stateLabel;
@property (nonatomic, strong) UILabel *elapsedLabel;
@property (nonatomic, strong) UIButton *scanButton;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UITextView *logTextView;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIView *heroCard;
@property (nonatomic, strong) UIView *deviceCard;
@property (nonatomic, strong) UILabel *deviceCountLabel;
@property (nonatomic, strong) UILabel *emptyDeviceLabel;
@property (nonatomic, strong) CAGradientLayer *heroGradientLayer;
@property (nonatomic, copy, nullable) NSString *presentedFailureKey;
@property (nonatomic, copy, nullable) NSString *presentedBluetoothIssueKey;
@property (nonatomic, assign) BOOL pendingScanStart;
@end

@implementation CustomBLEPairingViewController

- (instancetype)initWithHomeID:(long long)homeID completion:(CustomBLEPairingViewCompletion)completion {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _homeID = homeID;
        _completion = [completion copy];
        _session = [CustomBLEPairingSession new];
        _state = CustomBLEPairingStateIdle;
        _devices = @[];
        _logLines = [NSMutableArray array];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self configureFamilyNavigationWithTitle:@"添加 BLE 设备" leftTitle:nil leftAction:nil rightTitle:nil rightAction:nil];
    self.view.backgroundColor = [self familyBackgroundColor];
    [self setupViews];
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue() options:@{CBCentralManagerOptionShowPowerAlertKey: @NO}];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.state == CustomBLEPairingStateIdle) {
        [self requestScanStart];
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.heroGradientLayer.frame = self.heroCard.bounds;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if ([self isMovingFromParentViewController] || self.navigationController.isBeingDismissed) {
        self.pendingScanStart = NO;
        [self.session cancel];
        [self stopElapsedTimer];
    }
}

- (void)dealloc {
    [self.elapsedTimer invalidate];
    [_session cancel];
}

- (void)setupViews {
    self.scrollView = [UIScrollView new];
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.scrollView];

    self.contentView = [UIView new];
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.contentView];

    self.heroCard = [self cardView];
    self.heroCard.backgroundColor = [UIColor clearColor];
    self.heroGradientLayer = [CAGradientLayer layer];
    self.heroGradientLayer.colors = @[
        (__bridge id)[UIColor colorWithRed:1.0 green:0.32 blue:0.17 alpha:1.0].CGColor,
        (__bridge id)[UIColor colorWithRed:1.0 green:0.55 blue:0.25 alpha:1.0].CGColor
    ];
    self.heroGradientLayer.startPoint = CGPointMake(0, 0);
    self.heroGradientLayer.endPoint = CGPointMake(1, 1);
    self.heroGradientLayer.cornerRadius = 20;
    [self.heroCard.layer insertSublayer:self.heroGradientLayer atIndex:0];

    UIView *heroIconContainer = [UIView new];
    heroIconContainer.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.2];
    heroIconContainer.layer.cornerRadius = 26;
    heroIconContainer.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageView *heroIcon = [[UIImageView alloc] initWithImage:[self symbolImageNamed:@"dot.radiowaves.left.and.right"]];
    heroIcon.tintColor = UIColor.whiteColor;
    heroIcon.contentMode = UIViewContentModeScaleAspectFit;
    heroIcon.translatesAutoresizingMaskIntoConstraints = NO;
    [heroIconContainer addSubview:heroIcon];

    UILabel *heroTitle = [UILabel new];
    heroTitle.text = @"添加 BLE 设备";
    heroTitle.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    heroTitle.textColor = UIColor.whiteColor;
    heroTitle.translatesAutoresizingMaskIntoConstraints = NO;
    UILabel *heroSubtitle = [UILabel new];
    heroSubtitle.text = @"请让设备处于配网状态并靠近手机";
    heroSubtitle.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
    heroSubtitle.textColor = [UIColor colorWithWhite:1.0 alpha:0.9];
    heroSubtitle.translatesAutoresizingMaskIntoConstraints = NO;
    UILabel *heroBadge = [UILabel new];
    heroBadge.text = @"BLE 单点配网";
    heroBadge.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    heroBadge.textColor = UIColor.whiteColor;
    heroBadge.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.18];
    heroBadge.textAlignment = NSTextAlignmentCenter;
    heroBadge.layer.cornerRadius = 10;
    heroBadge.layer.masksToBounds = YES;
    heroBadge.translatesAutoresizingMaskIntoConstraints = NO;
    [self.heroCard addSubview:heroIconContainer];
    [self.heroCard addSubview:heroTitle];
    [self.heroCard addSubview:heroSubtitle];
    [self.heroCard addSubview:heroBadge];

    self.homeLabel = [self infoLabel];
    self.homeLabel.text = [NSString stringWithFormat:@"家庭 #%lld", self.homeID];
    self.bluetoothLabel = [self infoLabel];
    self.bluetoothLabel.text = @"正在检测蓝牙";
    self.stateLabel = [self infoLabel];
    self.stateLabel.text = @"准备开始";
    self.elapsedLabel = [self infoLabel];
    self.elapsedLabel.text = @"0.0 秒";
    UIView *statusCard = [self cardView];
    UIView *homeItem = [self statusItemWithTitle:@"当前家庭" valueLabel:self.homeLabel];
    UIView *bluetoothItem = [self statusItemWithTitle:@"蓝牙状态" valueLabel:self.bluetoothLabel];
    UIView *stateItem = [self statusItemWithTitle:@"当前阶段" valueLabel:self.stateLabel];
    UIView *elapsedItem = [self statusItemWithTitle:@"已用时间" valueLabel:self.elapsedLabel];
    UIStackView *statusTopRow = [[UIStackView alloc] initWithArrangedSubviews:@[homeItem, bluetoothItem]];
    statusTopRow.axis = UILayoutConstraintAxisHorizontal;
    statusTopRow.distribution = UIStackViewDistributionFillEqually;
    statusTopRow.spacing = 12;
    UIStackView *statusBottomRow = [[UIStackView alloc] initWithArrangedSubviews:@[stateItem, elapsedItem]];
    statusBottomRow.axis = UILayoutConstraintAxisHorizontal;
    statusBottomRow.distribution = UIStackViewDistributionFillEqually;
    statusBottomRow.spacing = 12;
    UIStackView *statusStack = [[UIStackView alloc] initWithArrangedSubviews:@[statusTopRow, statusBottomRow]];
    statusStack.axis = UILayoutConstraintAxisVertical;
    statusStack.distribution = UIStackViewDistributionFillEqually;
    statusStack.spacing = 12;
    statusStack.translatesAutoresizingMaskIntoConstraints = NO;
    [statusCard addSubview:statusStack];

    self.scanButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.scanButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    self.scanButton.layer.cornerRadius = 14;
    self.scanButton.layer.masksToBounds = YES;
    [self.scanButton setImage:[self symbolImageNamed:@"dot.radiowaves.left.and.right"] forState:UIControlStateNormal];
    self.scanButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
    [self.scanButton addTarget:self action:@selector(scanButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    self.scanButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self updateScanButtonAppearance];

    self.deviceCard = [self cardView];
    UILabel *deviceTitle = [self sectionLabelWithText:@"附近设备"];
    self.deviceCountLabel = [UILabel new];
    self.deviceCountLabel.text = @"正在搜索";
    self.deviceCountLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    self.deviceCountLabel.textColor = [self accentColor];
    self.deviceCountLabel.textAlignment = NSTextAlignmentRight;
    self.deviceCountLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 86;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.tableFooterView = [UIView new];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyDeviceLabel = [UILabel new];
    self.emptyDeviceLabel.text = @"正在搜索附近的 BLE 设备…\n找到后点击设备开始配对";
    self.emptyDeviceLabel.font = [UIFont systemFontOfSize:14];
    self.emptyDeviceLabel.textColor = [self secondaryTextColor];
    self.emptyDeviceLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyDeviceLabel.numberOfLines = 0;
    UIView *emptyView = [UIView new];
    [emptyView addSubview:self.emptyDeviceLabel];
    self.emptyDeviceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [self.emptyDeviceLabel.centerXAnchor constraintEqualToAnchor:emptyView.centerXAnchor],
        [self.emptyDeviceLabel.centerYAnchor constraintEqualToAnchor:emptyView.centerYAnchor],
        [self.emptyDeviceLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:emptyView.leadingAnchor constant:24],
        [self.emptyDeviceLabel.trailingAnchor constraintLessThanOrEqualToAnchor:emptyView.trailingAnchor constant:-24],
    ]];
    self.tableView.backgroundView = emptyView;
    [self.deviceCard addSubview:deviceTitle];
    [self.deviceCard addSubview:self.deviceCountLabel];
    [self.deviceCard addSubview:self.tableView];

    UIView *logCard = [self cardView];
    UILabel *logTitle = [self sectionLabelWithText:@"配网日志"];
    UILabel *logHint = [UILabel new];
    logHint.text = @"仅保存在本次会话中";
    logHint.font = [UIFont systemFontOfSize:12];
    logHint.textColor = [self secondaryTextColor];
    logHint.translatesAutoresizingMaskIntoConstraints = NO;
    self.logTextView = [UITextView new];
    self.logTextView.editable = NO;
    self.logTextView.selectable = YES;
    self.logTextView.font = [self logFont];
    self.logTextView.textColor = [self secondaryTextColor];
    self.logTextView.backgroundColor = [self logBackgroundColor];
    self.logTextView.layer.cornerRadius = 12;
    self.logTextView.textContainerInset = UIEdgeInsetsMake(10, 12, 10, 12);
    self.logTextView.translatesAutoresizingMaskIntoConstraints = NO;
    [logCard addSubview:logTitle];
    [logCard addSubview:logHint];
    [logCard addSubview:self.logTextView];

    [self.contentView addSubview:self.heroCard];
    [self.contentView addSubview:statusCard];
    [self.contentView addSubview:self.scanButton];
    [self.contentView addSubview:self.deviceCard];
    [self.contentView addSubview:logCard];
    self.heroCard.translatesAutoresizingMaskIntoConstraints = NO;
    statusCard.translatesAutoresizingMaskIntoConstraints = NO;
    self.deviceCard.translatesAutoresizingMaskIntoConstraints = NO;
    logCard.translatesAutoresizingMaskIntoConstraints = NO;

    UILayoutGuide *guide = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.familyContentGuide.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:guide.bottomAnchor],
        [self.contentView.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor],
        [self.contentView.leadingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor],
        [self.contentView.trailingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor],
        [self.contentView.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor],
        [self.contentView.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor],
        [self.heroCard.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12],
        [self.heroCard.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.heroCard.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        [self.heroCard.heightAnchor constraintEqualToConstant:142],
        [heroIconContainer.leadingAnchor constraintEqualToAnchor:self.heroCard.leadingAnchor constant:20],
        [heroIconContainer.centerYAnchor constraintEqualToAnchor:self.heroCard.centerYAnchor],
        [heroIconContainer.widthAnchor constraintEqualToConstant:52],
        [heroIconContainer.heightAnchor constraintEqualToConstant:52],
        [heroIcon.centerXAnchor constraintEqualToAnchor:heroIconContainer.centerXAnchor],
        [heroIcon.centerYAnchor constraintEqualToAnchor:heroIconContainer.centerYAnchor],
        [heroIcon.widthAnchor constraintEqualToConstant:28],
        [heroIcon.heightAnchor constraintEqualToConstant:28],
        [heroTitle.leadingAnchor constraintEqualToAnchor:heroIconContainer.trailingAnchor constant:16],
        [heroTitle.topAnchor constraintEqualToAnchor:heroIconContainer.topAnchor constant:2],
        [heroTitle.trailingAnchor constraintEqualToAnchor:self.heroCard.trailingAnchor constant:-20],
        [heroSubtitle.leadingAnchor constraintEqualToAnchor:heroTitle.leadingAnchor],
        [heroSubtitle.topAnchor constraintEqualToAnchor:heroTitle.bottomAnchor constant:6],
        [heroSubtitle.trailingAnchor constraintEqualToAnchor:self.heroCard.trailingAnchor constant:-20],
        [heroBadge.leadingAnchor constraintEqualToAnchor:heroTitle.leadingAnchor],
        [heroBadge.topAnchor constraintEqualToAnchor:heroSubtitle.bottomAnchor constant:10],
        [heroBadge.widthAnchor constraintEqualToConstant:92],
        [heroBadge.heightAnchor constraintEqualToConstant:20],
        [statusCard.topAnchor constraintEqualToAnchor:self.heroCard.bottomAnchor constant:16],
        [statusCard.leadingAnchor constraintEqualToAnchor:self.heroCard.leadingAnchor],
        [statusCard.trailingAnchor constraintEqualToAnchor:self.heroCard.trailingAnchor],
        [statusCard.heightAnchor constraintEqualToConstant:112],
        [statusStack.topAnchor constraintEqualToAnchor:statusCard.topAnchor constant:16],
        [statusStack.leadingAnchor constraintEqualToAnchor:statusCard.leadingAnchor constant:16],
        [statusStack.trailingAnchor constraintEqualToAnchor:statusCard.trailingAnchor constant:-16],
        [statusStack.bottomAnchor constraintEqualToAnchor:statusCard.bottomAnchor constant:-16],
        [self.scanButton.topAnchor constraintEqualToAnchor:statusCard.bottomAnchor constant:16],
        [self.scanButton.leadingAnchor constraintEqualToAnchor:self.heroCard.leadingAnchor],
        [self.scanButton.trailingAnchor constraintEqualToAnchor:self.heroCard.trailingAnchor],
        [self.scanButton.heightAnchor constraintEqualToConstant:52],
        [self.deviceCard.topAnchor constraintEqualToAnchor:self.scanButton.bottomAnchor constant:20],
        [self.deviceCard.leadingAnchor constraintEqualToAnchor:self.heroCard.leadingAnchor],
        [self.deviceCard.trailingAnchor constraintEqualToAnchor:self.heroCard.trailingAnchor],
        [deviceTitle.topAnchor constraintEqualToAnchor:self.deviceCard.topAnchor constant:18],
        [deviceTitle.leadingAnchor constraintEqualToAnchor:self.deviceCard.leadingAnchor constant:16],
        [self.deviceCountLabel.centerYAnchor constraintEqualToAnchor:deviceTitle.centerYAnchor],
        [self.deviceCountLabel.trailingAnchor constraintEqualToAnchor:self.deviceCard.trailingAnchor constant:-16],
        [self.tableView.topAnchor constraintEqualToAnchor:deviceTitle.bottomAnchor constant:10],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.deviceCard.leadingAnchor constant:4],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.deviceCard.trailingAnchor constant:-4],
        [self.tableView.heightAnchor constraintEqualToConstant:248],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.deviceCard.bottomAnchor constant:-8],
        [logCard.topAnchor constraintEqualToAnchor:self.deviceCard.bottomAnchor constant:16],
        [logCard.leadingAnchor constraintEqualToAnchor:self.heroCard.leadingAnchor],
        [logCard.trailingAnchor constraintEqualToAnchor:self.heroCard.trailingAnchor],
        [logTitle.topAnchor constraintEqualToAnchor:logCard.topAnchor constant:18],
        [logTitle.leadingAnchor constraintEqualToAnchor:logCard.leadingAnchor constant:16],
        [logHint.centerYAnchor constraintEqualToAnchor:logTitle.centerYAnchor],
        [logHint.trailingAnchor constraintEqualToAnchor:logCard.trailingAnchor constant:-16],
        [self.logTextView.topAnchor constraintEqualToAnchor:logTitle.bottomAnchor constant:10],
        [self.logTextView.leadingAnchor constraintEqualToAnchor:logCard.leadingAnchor constant:16],
        [self.logTextView.trailingAnchor constraintEqualToAnchor:logCard.trailingAnchor constant:-16],
        [self.logTextView.heightAnchor constraintEqualToConstant:160],
        [self.logTextView.bottomAnchor constraintEqualToAnchor:logCard.bottomAnchor constant:-16],
        [logCard.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-24],
    ]];
}

- (UILabel *)infoLabel {
    UILabel *label = [UILabel new];
    label.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    label.textColor = [self primaryTextColor];
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.8;
    return label;
}

- (UILabel *)sectionLabelWithText:(NSString *)text {
    UILabel *label = [UILabel new];
    label.text = text;
    label.font = [UIFont boldSystemFontOfSize:14];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    return label;
}

- (UIView *)cardView {
    UIView *card = [UIView new];
    card.backgroundColor = [self cardBackgroundColor];
    card.layer.cornerRadius = 20;
    card.layer.borderWidth = 1.0;
    card.layer.borderColor = [self cardBorderColor].CGColor;
    card.layer.shadowColor = UIColor.blackColor.CGColor;
    card.layer.shadowOffset = CGSizeMake(0, 4);
    card.layer.shadowRadius = 12;
    card.layer.shadowOpacity = 0.06;
    return card;
}

- (UIView *)statusItemWithTitle:(NSString *)title valueLabel:(UILabel *)valueLabel {
    UIView *item = [UIView new];
    UILabel *caption = [UILabel new];
    caption.text = title;
    caption.font = [UIFont systemFontOfSize:12];
    caption.textColor = [self secondaryTextColor];
    caption.translatesAutoresizingMaskIntoConstraints = NO;
    valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [item addSubview:caption];
    [item addSubview:valueLabel];
    [NSLayoutConstraint activateConstraints:@[
        [caption.topAnchor constraintEqualToAnchor:item.topAnchor],
        [caption.leadingAnchor constraintEqualToAnchor:item.leadingAnchor],
        [caption.trailingAnchor constraintEqualToAnchor:item.trailingAnchor],
        [valueLabel.topAnchor constraintEqualToAnchor:caption.bottomAnchor constant:3],
        [valueLabel.leadingAnchor constraintEqualToAnchor:item.leadingAnchor],
        [valueLabel.trailingAnchor constraintEqualToAnchor:item.trailingAnchor],
        [valueLabel.bottomAnchor constraintEqualToAnchor:item.bottomAnchor],
    ]];
    return item;
}

- (void)scanButtonTapped:(UIButton *)sender {
    if ([self isBusy]) {
        [self.session cancel];
    } else {
        [self requestScanStart];
    }
}

- (void)requestScanStart {
    self.pendingScanStart = YES;
    self.presentedBluetoothIssueKey = nil;
    switch (self.centralManager.state) {
        case CBManagerStatePoweredOn:
            [self startScanningWhenBluetoothReady];
            return;
        case CBManagerStateUnknown:
        case CBManagerStateResetting:
            [self appendLog:@"正在等待蓝牙服务就绪"];
            return;
        case CBManagerStatePoweredOff:
        case CBManagerStateUnauthorized:
        case CBManagerStateUnsupported:
            [self presentBluetoothIssueForState:self.centralManager.state];
            return;
    }
}

- (void)startScanningWhenBluetoothReady {
    if (self.centralManager.state != CBManagerStatePoweredOn || !self.pendingScanStart) {
        return;
    }
    self.pendingScanStart = NO;
    self.presentedFailureKey = nil;
    self.startedAt = [NSDate date];
    [self startElapsedTimer];
    __weak typeof(self) weakSelf = self;
    [self.session startWithHomeID:self.homeID eventHandler:^(CustomBLEPairingSnapshot *snapshot) {
        [weakSelf consumeSnapshot:snapshot];
    }];
}

- (void)consumeSnapshot:(CustomBLEPairingSnapshot *)snapshot {
    self.state = snapshot.state;
    self.devices = snapshot.devices;
    self.stateLabel.text = CustomBLEPairingStateDescription(snapshot.state);
    [self updateScanButtonAppearance];
    if (snapshot.devices.count > 0) {
        self.deviceCountLabel.text = [NSString stringWithFormat:@"已发现 %lu 台", (unsigned long)snapshot.devices.count];
        self.emptyDeviceLabel.text = @"";
    } else if (snapshot.state == CustomBLEPairingStateScanning) {
        self.deviceCountLabel.text = @"正在搜索";
        self.emptyDeviceLabel.text = @"正在搜索附近的 BLE 设备…\n找到后点击设备开始配对";
    } else {
        self.deviceCountLabel.text = @"暂无设备";
        self.emptyDeviceLabel.text = @"还没有发现可配对设备\n确认设备处于配网状态后重新扫描";
    }
    [self appendLog:snapshot.logLine];
    [self.tableView reloadData];

    if (snapshot.state == CustomBLEPairingStateSucceeded && snapshot.resultDevice) {
        [self stopElapsedTimer];
        [self presentSuccess:snapshot.resultDevice];
    } else if (snapshot.state == CustomBLEPairingStateFailed && snapshot.failure) {
        [self stopElapsedTimer];
        [self presentFailure:snapshot.failure];
    } else if (snapshot.state == CustomBLEPairingStateCancelled) {
        [self stopElapsedTimer];
    }
}

- (void)updateScanButtonAppearance {
    BOOL busy = [self isBusy];
    NSString *title = busy ? @"停止扫描" : (self.state == CustomBLEPairingStateIdle ? @"开始扫描" : @"重新扫描");
    NSString *iconName = busy ? @"xmark" : @"dot.radiowaves.left.and.right";
    [self.scanButton setTitle:title forState:UIControlStateNormal];
    [self.scanButton setImage:[self symbolImageNamed:iconName] forState:UIControlStateNormal];
    [self.scanButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.scanButton.tintColor = UIColor.whiteColor;
    self.scanButton.backgroundColor = busy ? [self stopButtonColor] : [self accentColor];
}

- (BOOL)isBusy {
    return self.state == CustomBLEPairingStateScanning ||
           self.state == CustomBLEPairingStateAcquiringToken ||
           self.state == CustomBLEPairingStateActivating;
}

- (void)appendLog:(NSString *)line {
    if (line.length == 0) {
        return;
    }
    NSString *timestamp = [NSDateFormatter localizedStringFromDate:[NSDate date] dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterMediumStyle];
    NSString *formatted = [NSString stringWithFormat:@"[%@] %@", timestamp, line];
    NSLog(@"CustomBLEPairing: %@", line);
    [self.logLines addObject:formatted];
    if (self.logLines.count > 200) {
        [self.logLines removeObjectsInRange:NSMakeRange(0, self.logLines.count - 200)];
    }
    self.logTextView.text = [self.logLines componentsJoinedByString:@"\n"];
    NSRange bottom = NSMakeRange(self.logTextView.text.length, 0);
    [self.logTextView scrollRangeToVisible:bottom];
}

- (void)presentFailure:(CustomBLEPairingFailure *)failure {
    NSString *key = [NSString stringWithFormat:@"%@:%ld", failure.stage, (long)failure.code];
    if ([self.presentedFailureKey isEqualToString:key] || self.presentedViewController) {
        return;
    }
    self.presentedFailureKey = key;
    NSString *message = [NSString stringWithFormat:@"阶段：%@\n错误码：%ld\n%@", failure.stage, (long)failure.code, failure.message];
    [self showFamilyMessageWithTitle:@"自定义配网失败" message:message completion:^{
        if (failure.isRetryable) {
            [self requestScanStart];
        }
    }];
}

- (void)presentSuccess:(CustomBLEPairingDevice *)device {
    if (self.presentedViewController) {
        return;
    }
    NSString *message = [NSString stringWithFormat:@"设备：%@\ndevId：%@", device.name, device.deviceID ?: @"-"];
    __weak typeof(self) weakSelf = self;
    [self showFamilyMessageWithTitle:@"设备添加成功" message:message completion:^{
        if (weakSelf.completion) {
            weakSelf.completion(device);
        }
        [weakSelf.navigationController popViewControllerAnimated:YES];
    }];
}

#pragma mark - UITableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.devices.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"BLEDeviceCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
        cell.backgroundColor = UIColor.clearColor;
        cell.contentView.backgroundColor = UIColor.clearColor;

        UIView *card = [UIView new];
        card.tag = 100;
        card.backgroundColor = [self listItemBackgroundColor];
        card.layer.cornerRadius = 14;
        card.layer.borderWidth = 1.0;
        card.layer.borderColor = [self cardBorderColor].CGColor;
        card.translatesAutoresizingMaskIntoConstraints = NO;
        [cell.contentView addSubview:card];

        UIView *iconContainer = [UIView new];
        iconContainer.backgroundColor = [self softAccentColor];
        iconContainer.layer.cornerRadius = 21;
        iconContainer.translatesAutoresizingMaskIntoConstraints = NO;
        UIImageView *icon = [[UIImageView alloc] initWithImage:[self symbolImageNamed:@"wave.3.right"]];
        icon.tintColor = [self accentColor];
        icon.contentMode = UIViewContentModeScaleAspectFit;
        icon.translatesAutoresizingMaskIntoConstraints = NO;
        [iconContainer addSubview:icon];

        UILabel *nameLabel = [UILabel new];
        nameLabel.tag = 102;
        nameLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
        nameLabel.textColor = [self primaryTextColor];
        nameLabel.numberOfLines = 1;
        nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        UILabel *detailLabel = [UILabel new];
        detailLabel.tag = 103;
        detailLabel.font = [UIFont systemFontOfSize:12];
        detailLabel.textColor = [self secondaryTextColor];
        detailLabel.numberOfLines = 2;
        detailLabel.translatesAutoresizingMaskIntoConstraints = NO;
        UILabel *badgeLabel = [UILabel new];
        badgeLabel.tag = 104;
        badgeLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
        badgeLabel.textAlignment = NSTextAlignmentCenter;
        badgeLabel.layer.cornerRadius = 8;
        badgeLabel.layer.masksToBounds = YES;
        badgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
        UIImageView *arrow = [[UIImageView alloc] initWithImage:[self symbolImageNamed:@"chevron.right"]];
        arrow.tag = 105;
        arrow.tintColor = [self secondaryTextColor];
        arrow.contentMode = UIViewContentModeScaleAspectFit;
        arrow.translatesAutoresizingMaskIntoConstraints = NO;

        [card addSubview:iconContainer];
        [card addSubview:nameLabel];
        [card addSubview:detailLabel];
        [card addSubview:badgeLabel];
        [card addSubview:arrow];
        [NSLayoutConstraint activateConstraints:@[
            [card.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:4],
            [card.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:8],
            [card.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-8],
            [card.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-4],
            [iconContainer.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:14],
            [iconContainer.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
            [iconContainer.widthAnchor constraintEqualToConstant:42],
            [iconContainer.heightAnchor constraintEqualToConstant:42],
            [icon.centerXAnchor constraintEqualToAnchor:iconContainer.centerXAnchor],
            [icon.centerYAnchor constraintEqualToAnchor:iconContainer.centerYAnchor],
            [icon.widthAnchor constraintEqualToConstant:21],
            [icon.heightAnchor constraintEqualToConstant:21],
            [nameLabel.leadingAnchor constraintEqualToAnchor:iconContainer.trailingAnchor constant:12],
            [nameLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:13],
            [nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:badgeLabel.leadingAnchor constant:-8],
            [detailLabel.leadingAnchor constraintEqualToAnchor:nameLabel.leadingAnchor],
            [detailLabel.topAnchor constraintEqualToAnchor:nameLabel.bottomAnchor constant:4],
            [detailLabel.trailingAnchor constraintEqualToAnchor:arrow.leadingAnchor constant:-10],
            [badgeLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:13],
            [badgeLabel.trailingAnchor constraintEqualToAnchor:arrow.leadingAnchor constant:-8],
            [badgeLabel.widthAnchor constraintGreaterThanOrEqualToConstant:48],
            [badgeLabel.heightAnchor constraintEqualToConstant:18],
            [arrow.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-14],
            [arrow.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
            [arrow.widthAnchor constraintEqualToConstant:10],
            [arrow.heightAnchor constraintEqualToConstant:16],
        ]];
    }
    CustomBLEPairingDevice *device = self.devices[indexPath.row];
    UILabel *nameLabel = [cell.contentView viewWithTag:102];
    UILabel *detailLabel = [cell.contentView viewWithTag:103];
    UILabel *badgeLabel = [cell.contentView viewWithTag:104];
    UIImageView *arrow = [cell.contentView viewWithTag:105];
    nameLabel.text = device.name;
    detailLabel.text = [NSString stringWithFormat:@"PID %@  ·  %@\n%@", device.productID, device.identifier, device.typeDescription];
    badgeLabel.text = device.statusDescription;
    badgeLabel.textColor = [self statusBadgeTextColorForDevice:device];
    badgeLabel.backgroundColor = [self statusBadgeBackgroundColorForDevice:device];
    arrow.hidden = self.state != CustomBLEPairingStateScanning;
    cell.selectionStyle = self.state == CustomBLEPairingStateScanning ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (self.state != CustomBLEPairingStateScanning) {
        return;
    }
    CustomBLEPairingDevice *device = self.devices[indexPath.row];
    NSString *message = [NSString stringWithFormat:@"名称：%@\nPID：%@\nID：%@", device.name, device.productID, device.identifier];
    [self showFamilyConfirmationWithTitle:@"确认激活这台设备？" message:message confirmTitle:@"开始激活" destructive:NO confirm:^{
        [self.session activateDeviceWithIdentifier:device.identifier];
    }];
}

#pragma mark - Bluetooth and elapsed time

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    NSString *description = @"未知";
    switch (central.state) {
        case CBManagerStatePoweredOn: description = @"已开启"; break;
        case CBManagerStatePoweredOff: description = @"已关闭"; break;
        case CBManagerStateUnauthorized: description = @"未授权"; break;
        case CBManagerStateUnsupported: description = @"设备不支持"; break;
        case CBManagerStateResetting: description = @"重置中"; break;
        case CBManagerStateUnknown: description = @"检测中"; break;
    }
    self.bluetoothLabel.text = description;
    self.bluetoothLabel.textColor = central.state == CBManagerStatePoweredOn ? [self successColor] : [self secondaryTextColor];

    if (central.state == CBManagerStatePoweredOn) {
        self.presentedBluetoothIssueKey = nil;
        if (self.pendingScanStart && ![self isBusy]) {
            [self startScanningWhenBluetoothReady];
        }
        return;
    }

    if (central.state == CBManagerStateUnknown || central.state == CBManagerStateResetting) {
        return;
    }

    if ([self isBusy]) {
        [self.session cancel];
        [self stopElapsedTimer];
    }
    if (self.pendingScanStart || self.view.window) {
        [self presentBluetoothIssueForState:central.state];
    }
}

- (void)presentBluetoothIssueForState:(CBManagerState)state {
    NSString *key = [NSString stringWithFormat:@"%ld", (long)state];
    if ([self.presentedBluetoothIssueKey isEqualToString:key] || self.presentedViewController || !self.view.window) {
        return;
    }
    self.presentedBluetoothIssueKey = key;

    NSString *title = @"蓝牙不可用";
    NSString *message = @"请检查蓝牙状态后重试。";
    BOOL canOpenSettings = NO;
    switch (state) {
        case CBManagerStatePoweredOff:
            message = @"蓝牙已关闭。请在系统控制中心或“设置”中打开蓝牙，然后重新扫描。";
            break;
        case CBManagerStateUnauthorized:
            title = @"蓝牙权限未授权";
            message = @"请在系统设置中允许此 App 使用蓝牙，然后返回此页面重新扫描。";
            canOpenSettings = YES;
            break;
        case CBManagerStateUnsupported:
            title = @"设备不支持蓝牙";
            message = @"当前设备不支持 BLE 配网。";
            self.pendingScanStart = NO;
            break;
        default:
            return;
    }

    if (canOpenSettings) {
        [self showFamilyConfirmationWithTitle:title message:message confirmTitle:@"打开设置" destructive:NO confirm:^{
            NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
            if ([[UIApplication sharedApplication] canOpenURL:url]) {
                [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
            }
        }];
    } else {
        [self showFamilyMessageWithTitle:title message:message];
    }
}

- (void)startElapsedTimer {
    [self.elapsedTimer invalidate];
    self.elapsedTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(updateElapsedLabel) userInfo:nil repeats:YES];
    [self updateElapsedLabel];
}

- (void)stopElapsedTimer {
    [self.elapsedTimer invalidate];
    self.elapsedTimer = nil;
    [self updateElapsedLabel];
}

- (void)updateElapsedLabel {
    NSTimeInterval elapsed = self.startedAt ? -[self.startedAt timeIntervalSinceNow] : 0;
    self.elapsedLabel.text = [NSString stringWithFormat:@"%.1f 秒", elapsed];
}

- (UIColor *)pageBackgroundColor { return [self familyBackgroundColor]; }

- (UIColor *)cardBackgroundColor {
    if (@available(iOS 13.0, *)) { return UIColor.secondarySystemBackgroundColor; }
    return UIColor.whiteColor;
}

- (UIColor *)listItemBackgroundColor {
    if (@available(iOS 13.0, *)) { return UIColor.tertiarySystemBackgroundColor; }
    return [UIColor colorWithWhite:0.98 alpha:1.0];
}

- (UIColor *)cardBorderColor {
    if (@available(iOS 13.0, *)) { return [UIColor.separatorColor colorWithAlphaComponent:0.45]; }
    return [UIColor colorWithWhite:0.88 alpha:1.0];
}

- (UIColor *)primaryTextColor {
    if (@available(iOS 13.0, *)) { return UIColor.labelColor; }
    return UIColor.blackColor;
}

- (UIColor *)accentColor { return [self familyAccentColor]; }

- (UIColor *)softAccentColor { return [[self familyAccentColor] colorWithAlphaComponent:0.12]; }

- (UIColor *)successColor {
    return [UIColor colorWithRed:0.12 green:0.62 blue:0.34 alpha:1.0];
}

- (UIColor *)stopButtonColor {
    return [UIColor colorWithRed:0.90 green:0.27 blue:0.24 alpha:1.0];
}

- (UIColor *)statusBadgeTextColorForDevice:(CustomBLEPairingDevice *)device {
    if ([device.statusDescription containsString:@"失败"]) {
        return [self stopButtonColor];
    }
    if ([device.statusDescription containsString:@"已联网"]) {
        return [self successColor];
    }
    return [self accentColor];
}

- (UIColor *)statusBadgeBackgroundColorForDevice:(CustomBLEPairingDevice *)device {
    UIColor *textColor = [self statusBadgeTextColorForDevice:device];
    return [textColor colorWithAlphaComponent:0.12];
}

- (UIFont *)logFont {
    if (@available(iOS 13.0, *)) {
        return [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    }
    return [UIFont fontWithName:@"Menlo-Regular" size:12] ?: [UIFont systemFontOfSize:12];
}

- (UIImage *)symbolImageNamed:(NSString *)name {
    if (@available(iOS 13.0, *)) {
        return [UIImage systemImageNamed:name];
    }
    return nil;
}

- (UIColor *)secondaryTextColor {
    if (@available(iOS 13.0, *)) { return UIColor.secondaryLabelColor; }
    return UIColor.darkGrayColor;
}

- (UIColor *)logBackgroundColor {
    if (@available(iOS 13.0, *)) { return UIColor.secondarySystemBackgroundColor; }
    return [UIColor colorWithWhite:0.95 alpha:1];
}

@end
