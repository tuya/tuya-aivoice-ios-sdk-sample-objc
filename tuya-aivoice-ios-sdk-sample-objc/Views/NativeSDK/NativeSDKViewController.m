//
//  NativeSDKViewController.m
//  AIVoiceDemo
//

#import "NativeSDKViewController.h"
#import "DeviceService.h"
#import <AVFAudio/AVFAudio.h>
#import <ThingAudioRecordInterface/ThingAudioRecordInterface.h>
#import <TUniAudioDetectManager/ThingAudioDetectManagerNative.h>
#import <math.h>

/// 振幅立柱最大数量；与立柱宽度配合填满屏幕宽度，参考 Apple 语音备忘录密度。
static const NSUInteger kNativeSDKMaxAmplitudeCount = 240;
static const NSUInteger kNativeSDKMaxLogCount = 100;
/// 单根振幅立柱之间的水平间距。
static const CGFloat kNativeSDKWaveformBarSpacing = 2.0;
/// 振幅立柱最小宽度。
static const CGFloat kNativeSDKWaveformBarMinWidth = 3.0;
/// 振幅归一化下限，静音时也保留最小可见高度。
static const CGFloat kNativeSDKWaveformFloor = 0.06;
/// 振幅立柱占视图高度的比例（接近满高）。
static const CGFloat kNativeSDKWaveformHeightRatio = 1.0;

/// 手机麦克风的 deviceId 约定，设备列表中每台设备的 deviceId 为其 devId。
static NSString * const kNativeSDKPhoneMicDeviceId = @"PHONE";

@interface NativeSDKViewController () <ThingAudioRecordManagerDelegate>

@property (nonatomic, strong) id<ThingAudioDetectManagerNativeProtocol> audioManager;
@property (nonatomic, copy) NSArray<ThingSmartDeviceModel *> *devices;
/// 当前选中的录音来源 deviceId：手机麦克风为 `kNativeSDKPhoneMicDeviceId`，设备为 devId。
@property (nonatomic, copy) NSString *selectedSourceDeviceId;
@property (nonatomic, copy, nullable) NSString *listenerDeviceId;
@property (nonatomic, assign) ThingAudioSource selectedAudioSource;

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) UIButton *refreshButton;
@property (nonatomic, strong) UIButton *sourceButton;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) UISwitch *asrSwitch;
@property (nonatomic, strong) UISwitch *nlgSwitch;
@property (nonatomic, strong) UISwitch *ttsSwitch;
@property (nonatomic, strong) UILabel *stateLabel;
@property (nonatomic, strong) UILabel *durationLabel;
@property (nonatomic, strong) UILabel *taskLabel;
@property (nonatomic, strong) UIView *waveformView;
/// 振幅立柱图层（每根一根 CALayer），仿 Apple 语音备忘录风格。
@property (nonatomic, strong) NSMutableArray<CALayer *> *waveformBars;
/// 已创建立柱的累计宽度（含间距），用于 layout 时复算。
@property (nonatomic, assign) CGFloat waveformBarWidth;
@property (nonatomic, strong) UIButton *startButton;
@property (nonatomic, strong) UIButton *pauseButton;
@property (nonatomic, strong) UIButton *stopButton;
@property (nonatomic, strong) UITextView *asrTextView;
@property (nonatomic, strong) UITextView *nlgTextView;
@property (nonatomic, strong) UITextView *logTextView;

@property (nonatomic, assign) ThingAudioRecordState recordState;
@property (nonatomic, assign) BOOL operationPending;
@property (nonatomic, assign) long elapsedMilliseconds;
@property (nonatomic, strong, nullable) NSTimer *durationTimer;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *amplitudes;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *asrTexts;
@property (nonatomic, strong) NSMutableArray<NSString *> *asrOrder;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *translateTexts;
@property (nonatomic, strong) NSMutableArray<NSString *> *translateOrder;
@property (nonatomic, strong) NSMutableArray<NSString *> *eventLogs;

@end

@implementation NativeSDKViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Native SDK";
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.audioManager = [ThingAudioDetectManagerNative sharedInstance];
    self.selectedSourceDeviceId = kNativeSDKPhoneMicDeviceId;
    self.selectedAudioSource = ThingSystemMic16KMono;
    self.recordState = ThingAudioRecordStateUnknown;
    self.amplitudes = [NSMutableArray array];
    self.waveformBars = [NSMutableArray array];
    self.asrTexts = [NSMutableDictionary dictionary];
    self.asrOrder = [NSMutableArray array];
    self.translateTexts = [NSMutableDictionary dictionary];
    self.translateOrder = [NSMutableArray array];
    self.eventLogs = [NSMutableArray array];

    [self setupUI];
    [self updateControls];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self loadDevices];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self relayoutWaveformBars];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopDurationTimer];
    [self unbindRecordListener];
}

#pragma mark - UI

- (void)setupUI {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.alwaysBounceVertical = YES;
    [self.view addSubview:self.scrollView];

    self.contentStack = [[UIStackView alloc] init];
    self.contentStack.axis = UILayoutConstraintAxisVertical;
    self.contentStack.spacing = 16;
    self.contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.contentStack];

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.contentStack.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor constant:16],
        [self.contentStack.leadingAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.leadingAnchor constant:16],
        [self.contentStack.trailingAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.trailingAnchor constant:-16],
        [self.contentStack.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor constant:-24],
    ]];

    self.refreshButton = [self actionButtonWithTitle:@"刷新" action:@selector(refreshButtonTapped:)];
    [self.refreshButton.widthAnchor constraintEqualToConstant:72].active = YES;

    self.sourceButton = [self actionButtonWithTitle:@"手机麦克风" action:@selector(sourceButtonTapped:)];
    self.sourceButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;

    self.emptyLabel = [self bodyLabel];
    self.emptyLabel.textColor = UIColor.systemOrangeColor;
    self.emptyLabel.numberOfLines = 0;
    self.emptyLabel.hidden = YES;

    UIStackView *sourceRow = [self horizontalStackWithViews:@[self.sourceButton, self.refreshButton]];

    // 处理能力开关：ASR / NLG(翻译) / TTS，默认 ASR、NLG 开，TTS 关。
    self.asrSwitch = [[UISwitch alloc] init];
    self.asrSwitch.on = YES;
    [self.asrSwitch addTarget:self action:@selector(capabilitySwitchChanged:) forControlEvents:UIControlEventValueChanged];
    self.nlgSwitch = [[UISwitch alloc] init];
    self.nlgSwitch.on = YES;
    [self.nlgSwitch addTarget:self action:@selector(capabilitySwitchChanged:) forControlEvents:UIControlEventValueChanged];
    self.ttsSwitch = [[UISwitch alloc] init];
    self.ttsSwitch.on = NO;
    [self.ttsSwitch addTarget:self action:@selector(capabilitySwitchChanged:) forControlEvents:UIControlEventValueChanged];

    UIView *asrRow = [self toggleRowWithTitle:@"ASR 识别" switchControl:self.asrSwitch];
    UIView *nlgRow = [self toggleRowWithTitle:@"NLG 翻译" switchControl:self.nlgSwitch];
    UIView *ttsRow = [self toggleRowWithTitle:@"TTS 播报" switchControl:self.ttsSwitch];

    UIStackView *configStack = [self verticalStack];
    [configStack addArrangedSubview:[self fieldTitleLabel:@"录音来源"]];
    [configStack addArrangedSubview:sourceRow];
    [configStack addArrangedSubview:self.emptyLabel];
    [configStack addArrangedSubview:[self separatorLine]];
    [configStack addArrangedSubview:[self fieldTitleLabel:@"处理能力"]];
    [configStack addArrangedSubview:asrRow];
    [configStack addArrangedSubview:nlgRow];
    [configStack addArrangedSubview:ttsRow];
    [self.contentStack addArrangedSubview:[self cardWithTitle:@"录音配置" content:configStack]];

    self.stateLabel = [self valueLabel];
    self.durationLabel = [self valueLabel];
    self.durationLabel.font = [UIFont monospacedDigitSystemFontOfSize:28 weight:UIFontWeightSemibold];
    self.durationLabel.textAlignment = NSTextAlignmentCenter;
    self.taskLabel = [self bodyLabel];
    self.taskLabel.numberOfLines = 0;
    self.taskLabel.textColor = UIColor.secondaryLabelColor;

    UIStackView *stateStack = [self verticalStack];
    [stateStack addArrangedSubview:self.stateLabel];
    [stateStack addArrangedSubview:self.durationLabel];
    [stateStack addArrangedSubview:self.taskLabel];
    [self.contentStack addArrangedSubview:[self cardWithTitle:@"录音状态" content:stateStack]];

    self.waveformView = [[UIView alloc] init];
    self.waveformView.backgroundColor = [UIColor.secondarySystemBackgroundColor colorWithAlphaComponent:0.8];
    self.waveformView.layer.cornerRadius = 10;
    self.waveformView.clipsToBounds = YES;
    [self.waveformView.heightAnchor constraintEqualToConstant:140].active = YES;
    [self.contentStack addArrangedSubview:[self cardWithTitle:@"实时振幅" content:self.waveformView]];

    self.startButton = [self primaryButtonWithTitle:@"开始" action:@selector(startButtonTapped:)];
    self.pauseButton = [self actionButtonWithTitle:@"暂停" action:@selector(pauseButtonTapped:)];
    self.stopButton = [self destructiveButtonWithTitle:@"停止" action:@selector(stopButtonTapped:)];
    UIStackView *controlRow = [self horizontalStackWithViews:@[self.startButton, self.pauseButton, self.stopButton]];
    controlRow.distribution = UIStackViewDistributionFillEqually;
    [self.contentStack addArrangedSubview:[self cardWithTitle:@"录音控制" content:controlRow]];

    self.asrTextView = [self readonlyTextViewWithPlaceholder:@"等待 ASR 回调…" height:160];
    [self.contentStack addArrangedSubview:[self cardWithTitle:@"实时 ASR" content:self.asrTextView]];

    self.nlgTextView = [self readonlyTextViewWithPlaceholder:@"等待实时翻译回调…" height:110];
    [self.contentStack addArrangedSubview:[self cardWithTitle:@"实时翻译" content:self.nlgTextView]];

    self.logTextView = [self readonlyTextViewWithPlaceholder:@"SDK 事件日志" height:190];
    self.logTextView.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    [self.contentStack addArrangedSubview:[self cardWithTitle:@"事件日志" content:self.logTextView]];
}

- (UIView *)cardWithTitle:(NSString *)title content:(UIView *)content {
    UIView *card = [[UIView alloc] init];
    card.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    card.layer.cornerRadius = 14;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = title;
    titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    titleLabel.textColor = UIColor.labelColor;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[titleLabel, content]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:card.topAnchor constant:16],
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16],
    ]];
    return card;
}

- (UIStackView *)verticalStack {
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 8;
    return stack;
}

- (UIStackView *)horizontalStackWithViews:(NSArray<UIView *> *)views {
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:views];
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.spacing = 10;
    return stack;
}

- (UILabel *)fieldTitleLabel:(NSString *)title {
    UILabel *label = [[UILabel alloc] init];
    label.text = title;
    label.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    label.textColor = UIColor.secondaryLabelColor;
    return label;
}

- (UILabel *)bodyLabel {
    UILabel *label = [[UILabel alloc] init];
    label.font = [UIFont systemFontOfSize:14];
    label.textColor = UIColor.labelColor;
    return label;
}

- (UIView *)toggleRowWithTitle:(NSString *)title switchControl:(UISwitch *)switchControl {
    UILabel *label = [[UILabel alloc] init];
    label.text = title;
    label.font = [UIFont systemFontOfSize:15];
    label.textColor = UIColor.labelColor;
    // 让 label 在水平方向更愿意被拉伸，把 UISwitch 顶到行末。
    [label setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [label setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
    UIStackView *row = [self horizontalStackWithViews:@[label, switchControl]];
    return row;
}

- (UIView *)separatorLine {
    UIView *line = [[UIView alloc] init];
    line.backgroundColor = UIColor.separatorColor;
    [line.heightAnchor constraintEqualToConstant:0.5].active = YES;
    return line;
}

- (UILabel *)valueLabel {
    UILabel *label = [[UILabel alloc] init];
    label.font = [UIFont systemFontOfSize:17 weight:UIFontWeightMedium];
    label.textColor = UIColor.labelColor;
    label.textAlignment = NSTextAlignmentCenter;
    return label;
}

- (UIButton *)actionButtonWithTitle:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    button.backgroundColor = UIColor.tertiarySystemFillColor;
    button.layer.cornerRadius = 10;
    button.contentEdgeInsets = UIEdgeInsetsMake(12, 14, 12, 14);
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (UIButton *)primaryButtonWithTitle:(NSString *)title action:(SEL)action {
    UIButton *button = [self actionButtonWithTitle:title action:action];
    button.backgroundColor = UIColor.systemBlueColor;
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    return button;
}

- (UIButton *)destructiveButtonWithTitle:(NSString *)title action:(SEL)action {
    UIButton *button = [self actionButtonWithTitle:title action:action];
    button.backgroundColor = [UIColor.systemRedColor colorWithAlphaComponent:0.12];
    [button setTitleColor:UIColor.systemRedColor forState:UIControlStateNormal];
    return button;
}

- (UITextView *)readonlyTextViewWithPlaceholder:(NSString *)placeholder height:(CGFloat)height {
    UITextView *textView = [[UITextView alloc] init];
    textView.editable = NO;
    textView.selectable = YES;
    textView.scrollEnabled = YES;
    textView.backgroundColor = UIColor.secondarySystemBackgroundColor;
    textView.layer.cornerRadius = 10;
    textView.textContainerInset = UIEdgeInsetsMake(10, 10, 10, 10);
    textView.font = [UIFont systemFontOfSize:15];
    textView.textColor = UIColor.secondaryLabelColor;
    textView.text = placeholder;
    [textView.heightAnchor constraintEqualToConstant:height].active = YES;
    return textView;
}

#pragma mark - Device and source

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    [self loadDevices];
}

- (void)refreshButtonTapped:(UIButton *)sender {
    [self loadDevices];
}

- (void)capabilitySwitchChanged:(UISwitch *)sender {
    NSString *name = sender == self.asrSwitch ? @"ASR" : (sender == self.nlgSwitch ? @"NLG" : @"TTS");
    [self appendLog:[NSString stringWithFormat:@"%@ 切换为 %@", name, sender.isOn ? @"开" : @"关"]];
}

- (void)loadDevices {
    self.refreshButton.enabled = NO;
    __weak typeof(self) weakSelf = self;
    [[DeviceService sharedInstance] getDeviceListWithSuccess:^(NSArray<ThingSmartDeviceModel *> * _Nullable deviceList) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            self.refreshButton.enabled = YES;
            self.devices = deviceList ?: @[];
            [self applyLoadedDevices];
        });
    } failure:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            self.refreshButton.enabled = YES;
            if (![self isRecordingActive]) {
                self.devices = @[];
                [self bindSelectedSourceDeviceId:kNativeSDKPhoneMicDeviceId audioSource:ThingSystemMic16KMono];
            }
            self.emptyLabel.text = [NSString stringWithFormat:@"设备加载失败：%@", error.localizedDescription];
            self.emptyLabel.hidden = NO;
            [self appendLog:[NSString stringWithFormat:@"设备加载失败 code=%ld %@", (long)error.code, error.localizedDescription]];
            [self updateControls];
        });
    }];
}

- (void)applyLoadedDevices {
    if (self.devices.count == 0) {
        if (![self isRecordingActive]) {
            [self bindSelectedSourceDeviceId:kNativeSDKPhoneMicDeviceId audioSource:ThingSystemMic16KMono];
        }
        self.emptyLabel.text = @"当前家庭暂无设备，将使用手机麦克风录音。可在首页完成设备配网后再切换来源。";
        self.emptyLabel.hidden = NO;
        [self updateControls];
        return;
    }

    self.emptyLabel.hidden = YES;

    // 待检查的活动来源：当前所选 deviceId + 全部设备 devId，再补充 PHONE。
    NSMutableArray<NSString *> *candidateIds = [NSMutableArray array];
    if (self.selectedSourceDeviceId.length > 0 && ![candidateIds containsObject:self.selectedSourceDeviceId]) {
        [candidateIds addObject:self.selectedSourceDeviceId];
    }
    for (ThingSmartDeviceModel *device in self.devices) {
        if (device.devId.length > 0 && ![candidateIds containsObject:device.devId]) {
            [candidateIds addObject:device.devId];
        }
    }
    if (![candidateIds containsObject:kNativeSDKPhoneMicDeviceId]) {
        [candidateIds addObject:kNativeSDKPhoneMicDeviceId];
    }

    NSString *activeSourceId = nil;
    ThingAudioRecordObject *activeTask = nil;
    for (NSString *deviceId in candidateIds) {
        ThingAudioRecordObject *task = [self.audioManager recordTransferTaskWithDeviceId:deviceId];
        if (task && (task.state == ThingAudioRecordStateOngoing || task.state == ThingAudioRecordStatePaused)) {
            activeSourceId = deviceId;
            activeTask = task;
            break;
        }
    }

    if (activeTask) {
        [self bindSelectedSourceDeviceId:activeSourceId
                             audioSource:([activeSourceId isEqualToString:kNativeSDKPhoneMicDeviceId]
                                          ? ThingSystemMic16KMono : ThingEarPhonePro16KMono)];
        [self applyTask:activeTask];
        return;
    }

    // 无活动任务时，保持当前选择（PHONE 或仍在列表中的设备），否则回落到首个设备。
    if ([self.selectedSourceDeviceId isEqualToString:kNativeSDKPhoneMicDeviceId] ||
        [self deviceWithId:self.selectedSourceDeviceId]) {
        [self bindSelectedSourceDeviceId:self.selectedSourceDeviceId
                             audioSource:self.selectedAudioSource];
    } else {
        ThingSmartDeviceModel *first = self.devices.firstObject;
        [self bindSelectedSourceDeviceId:first.devId audioSource:ThingEarPhonePro16KMono];
    }
    [self restoreSelectedDeviceTask];
}

- (void)sourceButtonTapped:(UIButton *)sender {
    if (self.operationPending || [self isRecordingActive]) return;

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"选择录音来源"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf = self;
    [sheet addAction:[UIAlertAction actionWithTitle:@"手机麦克风" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [weakSelf bindSelectedSourceDeviceId:kNativeSDKPhoneMicDeviceId audioSource:ThingSystemMic16KMono];
        [weakSelf restoreSelectedDeviceTask];
    }]];
    for (ThingSmartDeviceModel *device in self.devices) {
        NSString *title = [NSString stringWithFormat:@"%@%@", device.name ?: @"未命名设备", device.isOnline ? @"" : @"（离线）"];
        NSString *deviceId = device.devId;
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [weakSelf bindSelectedSourceDeviceId:deviceId audioSource:ThingEarPhonePro16KMono];
            [weakSelf restoreSelectedDeviceTask];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self configurePopoverForAlert:sheet sourceView:sender];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)configurePopoverForAlert:(UIAlertController *)alert sourceView:(UIView *)sourceView {
    UIPopoverPresentationController *popover = alert.popoverPresentationController;
    if (popover) {
        popover.sourceView = sourceView;
        popover.sourceRect = sourceView.bounds;
    }
}

- (NSString *)titleForAudioSource:(ThingAudioSource)source {
    switch (source) {
        case ThingSystemMic16KMono: return @"手机麦克风";
        case ThingEarPhonePro16KMono: return @"AI 设备音源";
        case ThingSystemBlueTooth16KMono:
        default: return @"系统蓝牙";
    }
}

- (void)bindSelectedSourceDeviceId:(NSString *)deviceId audioSource:(ThingAudioSource)audioSource {
    if (deviceId.length == 0) return;

    self.selectedSourceDeviceId = deviceId;
    self.selectedAudioSource = audioSource;

    if (![self.listenerDeviceId isEqualToString:deviceId]) {
        [self unbindRecordListener];
        [self.audioManager addRecordListener:self deviceId:deviceId];
        self.listenerDeviceId = deviceId;
    }
    [self updateSourceButtonTitle];
}

- (void)unbindRecordListener {
    if (self.listenerDeviceId.length > 0) {
        [self.audioManager removeRecordListener:self deviceId:self.listenerDeviceId];
        self.listenerDeviceId = nil;
    }
}

- (void)updateSourceButtonTitle {
    NSString *title = [self titleForAudioSource:self.selectedAudioSource];
    if (![self.selectedSourceDeviceId isEqualToString:kNativeSDKPhoneMicDeviceId]) {
        ThingSmartDeviceModel *device = [self deviceWithId:self.selectedSourceDeviceId];
        if (device) {
            title = [NSString stringWithFormat:@"%@%@", device.name ?: @"未命名设备", device.isOnline ? @"" : @"（离线）"];
        }
    }
    [self.sourceButton setTitle:title forState:UIControlStateNormal];
}

- (nullable ThingSmartDeviceModel *)deviceWithId:(NSString *)deviceId {
    if (deviceId.length == 0) return nil;
    for (ThingSmartDeviceModel *device in self.devices) {
        if ([device.devId isEqualToString:deviceId]) return device;
    }
    return nil;
}

#pragma mark - Recording operations

- (void)startButtonTapped:(UIButton *)sender {
    if (!self.selectedSourceDeviceId.length || self.operationPending || [self isRecordingActive]) return;

    if ([self.selectedSourceDeviceId isEqualToString:kNativeSDKPhoneMicDeviceId]) {
        AVAudioSessionRecordPermission permission = AVAudioSession.sharedInstance.recordPermission;
        if (permission == AVAudioSessionRecordPermissionDenied) {
            [self showMessageWithTitle:@"无法使用麦克风" message:@"请在系统设置中允许此 App 访问麦克风后重试。"];
            return;
        }
        if (permission == AVAudioSessionRecordPermissionUndetermined) {
            __weak typeof(self) weakSelf = self;
            [AVAudioSession.sharedInstance requestRecordPermission:^(BOOL granted) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (granted) {
                        [weakSelf beginRecording];
                    } else {
                        [weakSelf showMessageWithTitle:@"麦克风权限未开启" message:@"手机麦克风录音需要麦克风权限。"];
                    }
                });
            }];
            return;
        }
    }
    [self beginRecording];
}

- (void)beginRecording {
    [self resetResultViews];
    self.operationPending = YES;
    [self appendLog:[NSString stringWithFormat:@"调用 start deviceId=%@ source=%lu", self.selectedSourceDeviceId, (unsigned long)self.selectedAudioSource]];
    [self updateControls];

    ThingAudioRecordConfig *config = [[ThingAudioRecordConfig alloc] init];
    // 业务类型固定为离线会议；小程序类型固定为 Note；实时传输。
    config.recordType = ThingAudioRecordTypeMeet;
    config.businessType = ThingAudioBusinessTypeNote;
    config.transferType = ThingAudioRecordTransferTypeRealTime;
    // audioSource 与 audioSourceList 保持一致，audioSourceList 为权威来源。
    config.audioSource = self.selectedAudioSource;
    config.audioSourceList = @[@(self.selectedAudioSource)];
    // 处理能力开关：ASR / NLG(翻译) / TTS 由 UI 开关决定；振幅默认开（波形显示必需）。
    config.needAsr = self.asrSwitch.isOn;
    config.needAmplitude = YES;
    config.needTranslate = self.nlgSwitch.isOn;
    config.needTTS = self.ttsSwitch.isOn;
    // 其余参数默认值。
    config.needAutoRecognize = NO;
    config.originalLanguage = @"zh";
    config.targetLanguage = @"en";
    config.startLivingStatus = 0;
    config.audio3AConfig = [[ThingAudio3AConfig alloc] initWithEnableRnAns:NO ans:NO level:0 agc:YES aec:NO];

    // deviceId 即录音来源：手机麦克风为 PHONE，其余为设备 devId。
    NSString *deviceId = self.selectedSourceDeviceId;
    __weak typeof(self) weakSelf = self;
    [self.audioManager startAudioRecordingWithDeviceId:deviceId config:config success:^(ThingAudioRecordObject *task) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            self.operationPending = NO;
            [self appendLog:[NSString stringWithFormat:@"start 成功 recordId=%@", task.recordId ?: @"-"]];
            [self applyTask:task];
        });
    } failure:^(NSError *error) {
        [weakSelf handleOperationFailure:@"开始录音失败" error:error];
    }];
}

- (void)pauseButtonTapped:(UIButton *)sender {
    if (!self.selectedSourceDeviceId.length || self.operationPending) return;
    self.operationPending = YES;
    [self updateControls];
    __weak typeof(self) weakSelf = self;
    if (self.recordState == ThingAudioRecordStatePaused) {
        [self appendLog:@"调用 resume"];
        [self.audioManager resumeRecordTransferWithDeviceId:self.selectedSourceDeviceId success:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                weakSelf.operationPending = NO;
                weakSelf.recordState = ThingAudioRecordStateOngoing;
                [weakSelf appendLog:@"resume 成功"];
                [weakSelf startDurationTimer];
                [weakSelf updateControls];
            });
        } failure:^(NSError *error) {
            [weakSelf handleOperationFailure:@"恢复录音失败" error:error];
        }];
    } else {
        [self appendLog:@"调用 pause"];
        [self.audioManager pauseRecordTransferWithDeviceId:self.selectedSourceDeviceId success:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                weakSelf.operationPending = NO;
                weakSelf.recordState = ThingAudioRecordStatePaused;
                [weakSelf appendLog:@"pause 成功"];
                [weakSelf stopDurationTimer];
                [weakSelf updateControls];
            });
        } failure:^(NSError *error) {
            [weakSelf handleOperationFailure:@"暂停录音失败" error:error];
        }];
    }
}

- (void)stopButtonTapped:(UIButton *)sender {
    if (!self.selectedSourceDeviceId.length || self.operationPending || ![self isRecordingActive]) return;
    self.operationPending = YES;
    [self stopDurationTimer];
    [self appendLog:@"调用 stop"];
    [self updateControls];
    __weak typeof(self) weakSelf = self;
    [self.audioManager stopRecordTransferWithDeviceId:self.selectedSourceDeviceId success:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf appendLog:@"stop 成功"];
            [weakSelf finishRecordingWithError:nil];
        });
    } failure:^(NSError *error) {
        [weakSelf handleOperationFailure:@"停止录音失败" error:error];
    }];
}

- (void)restoreSelectedDeviceTask {
    if (!self.selectedSourceDeviceId.length || self.operationPending) {
        [self updateControls];
        return;
    }
    ThingAudioRecordObject *task = [self.audioManager recordTransferTaskWithDeviceId:self.selectedSourceDeviceId];
    if (task && (task.state == ThingAudioRecordStateOngoing || task.state == ThingAudioRecordStatePaused)) {
        [self appendLog:[NSString stringWithFormat:@"恢复任务 recordId=%@ state=%lu", task.recordId ?: @"-", (unsigned long)task.state]];
        [self applyTask:task];
    } else if ([self isRecordingActive]) {
        [self finishRecordingWithError:nil];
    } else {
        [self updateControls];
    }
}

- (void)applyTask:(ThingAudioRecordObject *)task {
    self.recordState = task.state;
    if (self.recordState != ThingAudioRecordStateOngoing && self.recordState != ThingAudioRecordStatePaused) {
        self.recordState = ThingAudioRecordStateOngoing;
    }

    // 从任务 deviceId 反推录音来源：PHONE 走麦克风，其余视为设备。
    NSString *taskDeviceId = task.deviceId.length > 0 ? task.deviceId : self.selectedSourceDeviceId;
    ThingAudioSource source = [taskDeviceId isEqualToString:kNativeSDKPhoneMicDeviceId]
                              ? ThingSystemMic16KMono
                              : (task.audioSource == ThingSystemMic16KMono ? ThingEarPhonePro16KMono : task.audioSource);
    [self bindSelectedSourceDeviceId:taskDeviceId audioSource:source];

    self.elapsedMilliseconds = MAX(0, task.userRecordDuration);
    self.taskLabel.text = [NSString stringWithFormat:@"recordId: %@\ndeviceId: %@",
                           task.recordId.length > 0 ? task.recordId : @"-",
                           taskDeviceId ?: @"-"];
    if (self.recordState == ThingAudioRecordStateOngoing) {
        [self startDurationTimer];
    } else {
        [self stopDurationTimer];
    }
    [self updateControls];
}

- (void)handleOperationFailure:(NSString *)title error:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.operationPending = NO;
        [self appendLog:[NSString stringWithFormat:@"%@ code=%ld %@", title, (long)error.code, error.localizedDescription]];
        [self restoreSelectedDeviceTask];
        [self showMessageWithTitle:title message:error.localizedDescription ?: @"未知错误"];
    });
}

- (void)finishRecordingWithError:(nullable NSError *)error {
    self.operationPending = NO;
    self.recordState = ThingAudioRecordStateFinish;
    [self stopDurationTimer];
    [self updateControls];
    if (error) {
        [self showMessageWithTitle:@"录音异常结束" message:error.localizedDescription ?: @"未知错误"];
    }
}

- (BOOL)isRecordingActive {
    return self.recordState == ThingAudioRecordStateOngoing || self.recordState == ThingAudioRecordStatePaused;
}

- (void)updateControls {
    BOOL hasDevice = self.selectedSourceDeviceId.length > 0;
    BOOL active = [self isRecordingActive];
    self.sourceButton.enabled = hasDevice && !active && !self.operationPending;
    self.refreshButton.enabled = !active && !self.operationPending;
    self.asrSwitch.enabled = !active && !self.operationPending;
    self.nlgSwitch.enabled = !active && !self.operationPending;
    self.ttsSwitch.enabled = !active && !self.operationPending;
    self.startButton.enabled = hasDevice && !active && !self.operationPending;
    self.pauseButton.enabled = hasDevice && active && !self.operationPending;
    self.stopButton.enabled = hasDevice && active && !self.operationPending;
    [self.pauseButton setTitle:self.recordState == ThingAudioRecordStatePaused ? @"继续" : @"暂停" forState:UIControlStateNormal];

    NSString *stateText = @"未开始";
    if (self.operationPending) {
        stateText = @"操作处理中…";
    } else {
        switch (self.recordState) {
            case ThingAudioRecordStateOngoing: stateText = @"录音中"; break;
            case ThingAudioRecordStatePaused: stateText = @"已暂停"; break;
            case ThingAudioRecordStateFinish: stateText = @"已结束"; break;
            case ThingAudioRecordStateUnknown:
            default: stateText = @"未开始"; break;
        }
    }
    self.stateLabel.text = stateText;
    [self updateDurationLabel];
    if (!active && self.taskLabel.text.length == 0) self.taskLabel.text = @"recordId: -\ndeviceId: -";
}

#pragma mark - Duration and waveform

- (void)startDurationTimer {
    [self stopDurationTimer];
    self.durationTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                         target:self
                                                       selector:@selector(durationTimerFired:)
                                                       userInfo:nil
                                                        repeats:YES];
}

- (void)stopDurationTimer {
    [self.durationTimer invalidate];
    self.durationTimer = nil;
}

- (void)durationTimerFired:(NSTimer *)timer {
    if (self.recordState == ThingAudioRecordStateOngoing) {
        self.elapsedMilliseconds += 1000;
        [self updateDurationLabel];
    }
}

- (void)updateDurationLabel {
    long totalSeconds = MAX(0, self.elapsedMilliseconds / 1000);
    self.durationLabel.text = [NSString stringWithFormat:@"%02ld:%02ld:%02ld", totalSeconds / 3600, (totalSeconds / 60) % 60, totalSeconds % 60];
}

- (void)addAmplitude:(double)amplitude {
    // 归一化：过载值压缩到 1.0；极小值抬到最小可见高度，避免静音时柱子完全消失。
    double normalized = fabs(amplitude);
    if (normalized > 1.0) normalized = MIN(normalized / 100.0, 1.0);
    normalized = MAX(normalized, kNativeSDKWaveformFloor);

    [self.amplitudes addObject:@(normalized)];
    if (self.amplitudes.count > kNativeSDKMaxAmplitudeCount) {
        [self.amplitudes removeObjectAtIndex:0];
    }
    [self syncWaveformBarsToAmplitudes];
    [self relayoutWaveformBars];
}

#pragma mark - Waveform rendering (Apple 语音备忘录风格立柱)

/// 同步立柱图层数量与 amplitudes 一一对应；amplitudes 滚动截断时同步丢弃队首图层。
- (void)syncWaveformBarsToAmplitudes {
    while (self.waveformBars.count < self.amplitudes.count) {
        CALayer *bar = [CALayer layer];
        bar.backgroundColor = UIColor.systemBlueColor.CGColor;
        bar.cornerRadius = 1.5;
        bar.anchorPoint = CGPointMake(0.5, 0.5);
        [self.waveformView.layer addSublayer:bar];
        [self.waveformBars addObject:bar];
    }
    while (self.waveformBars.count > self.amplitudes.count) {
        CALayer *bar = self.waveformBars.firstObject;
        [bar removeFromSuperlayer];
        [self.waveformBars removeObjectAtIndex:0];
    }
}

/// 单次遍历：依据 amplitudes 重排所有立柱的 width / height / position。
/// 末根贴右边对齐，整组随新数据到来向左滚动；视图未布局完成时跳过，等 viewDidLayoutSubviews 触发。
- (void)relayoutWaveformBars {
    CGRect bounds = self.waveformView.bounds;
    if (CGRectIsEmpty(bounds) || self.waveformBars.count == 0) return;

    NSUInteger count = self.waveformBars.count;
    CGFloat available = CGRectGetWidth(bounds);
    // 总间距 = (count - 1) * spacing；柱宽 = 剩余空间均分，最小不低于 kNativeSDKWaveformBarMinWidth。
    CGFloat totalSpacing = MAX(0, (CGFloat)(count - 1)) * kNativeSDKWaveformBarSpacing;
    CGFloat barWidth = MAX(kNativeSDKWaveformBarMinWidth, (available - totalSpacing) / (CGFloat)count);
    self.waveformBarWidth = barWidth;

    CGFloat viewHeight = CGRectGetHeight(bounds);
    CGFloat centerY = CGRectGetMidY(bounds);
    // 整组右对齐：末根中心 x = width - barWidth/2，向前递减 (barWidth + spacing)。
    CGFloat stride = barWidth + kNativeSDKWaveformBarSpacing;
    CGFloat lastCenterX = CGRectGetMaxX(bounds) - barWidth / 2.0;

    [self.waveformBars enumerateObjectsUsingBlock:^(CALayer *bar, NSUInteger idx, BOOL *stop) {
        double value = idx < self.amplitudes.count ? self.amplitudes[idx].doubleValue : kNativeSDKWaveformFloor;
        // 中线镜像：高度按归一化值 × 视图高度 × 比例，最小不低于柱宽（保证最矮也呈方块）。
        CGFloat height = MAX(barWidth, round(value * viewHeight * kNativeSDKWaveformHeightRatio));
        CGFloat centerX = lastCenterX - ((CGFloat)(count - 1 - idx)) * stride;
        bar.bounds = CGRectMake(0, 0, barWidth, height);
        bar.position = CGPointMake(centerX, centerY);
    }];
}

- (void)redrawWaveform {
    // 清空或重建：同步图层到当前 amplitudes 后统一重排。
    [self syncWaveformBarsToAmplitudes];
    [self relayoutWaveformBars];
}

#pragma mark - Record listener

- (void)record:(NSString *)deviceId didFinishWithError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self appendLog:[NSString stringWithFormat:@"finish deviceId=%@ error=%@", deviceId, error.localizedDescription ?: @"none"]];
        [self finishRecordingWithError:error];
    });
}

- (void)record:(NSString *)deviceId didUpdateAmplitude:(double)amplitude channel:(NSInteger)channel {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self addAmplitude:amplitude];
    });
}

- (void)record:(NSString *)deviceId didUpdateStatus:(ThingAudioRecordStatus *)status {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.recordState = status.state;
        self.operationPending = status.isStarting || status.isPausing || status.isResuming || status.isStoping;
        [self appendLog:[NSString stringWithFormat:@"status state=%lu starting=%d pausing=%d resuming=%d stopping=%d",
                         (unsigned long)status.state, status.isStarting, status.isPausing, status.isResuming, status.isStoping]];
        if (status.state == ThingAudioRecordStateFinish) {
            [self finishRecordingWithError:nil];
            return;
        }
        if (status.state == ThingAudioRecordStateOngoing && !self.durationTimer) [self startDurationTimer];
        if (status.state == ThingAudioRecordStatePaused) [self stopDurationTimer];
        [self updateControls];
    });
}

- (void)record:(NSString *)deviceId onProcessResult:(ThingAudioRecordProcessResult *)result {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *phase = [self titleForProcessPhase:result.phase];
        NSString *status = [self titleForProcessStatus:result.status];
        NSString *translateStatus = [self titleForProcessStatus:result.translateStatus];
        [self appendLog:[NSString stringWithFormat:@"process %@/%@ asrId=%lld text=%@ translate=%@(%@) error=%@",
                         phase, status, result.asrId, result.text ?: @"-",
                         result.translateText ?: @"-", translateStatus,
                         result.error.localizedDescription ?: @"none"]];

        // 句子聚合 key：优先 asrId+channel，回落 requestId。
        NSString *key = result.asrId != 0 ? [NSString stringWithFormat:@"%lld-%d", result.asrId, result.channel] : result.requestId;

        // ASR / Text 阶段承载识别原文。
        if ((result.phase == ThingAudioRecordProcessPhaseAsr || result.phase == ThingAudioRecordProcessPhaseText)
            && key.length > 0 && result.text.length > 0) {
            if (!self.asrTexts[key]) [self.asrOrder addObject:key];
            self.asrTexts[key] = result.text;
            [self refreshASRText];
        }

        // 翻译结果没有独立 phase：原文在 text，译文在 translateText，伴随独立的 translateStatus。
        // 只要 translateText 有内容或 translateStatus 进入 End，就按句子 key 累积到翻译区。
        if (key.length > 0 &&
            (result.translateText.length > 0 || result.translateStatus == ThingAudioRecordProcessStatusEnd)) {
            NSString *translation = result.translateText.length > 0 ? result.translateText : @"";
            if (self.translateTexts[key] == nil) {
                [self.translateOrder addObject:key];
            }
            // Start/Update 持续覆盖同句的中间结果，End 时定稿；Cancel 不覆盖已有译文。
            if (result.translateStatus != ThingAudioRecordProcessStatusCancel || self.translateTexts[key] == nil) {
                self.translateTexts[key] = translation;
            }
            [self refreshTranslateText];
        }
    });
}

- (NSString *)titleForProcessPhase:(ThingAudioRecordProcessPhase)phase {
    switch (phase) {
        case ThingAudioRecordProcessPhaseTask: return @"Task";
        case ThingAudioRecordProcessPhaseReceiveAudio: return @"ReceiveAudio";
        case ThingAudioRecordProcessPhaseSendAudio: return @"SendAudio";
        case ThingAudioRecordProcessPhaseReceiveData: return @"ReceiveData";
        case ThingAudioRecordProcessPhaseAsr: return @"ASR";
        case ThingAudioRecordProcessPhaseText: return @"Text";
        case ThingAudioRecordProcessPhaseSkill: return @"Skill";
        case ThingAudioRecordProcessPhaseTts: return @"TTS";
    }
    return @"Unknown";
}

- (NSString *)titleForProcessStatus:(ThingAudioRecordProcessStatus)status {
    switch (status) {
        case ThingAudioRecordProcessStatusStart: return @"Start";
        case ThingAudioRecordProcessStatusUpdate: return @"Update";
        case ThingAudioRecordProcessStatusEnd: return @"End";
        case ThingAudioRecordProcessStatusCancel: return @"Cancel";
    }
    return @"Unknown";
}

- (void)refreshASRText {
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    for (NSString *key in self.asrOrder) {
        NSString *text = self.asrTexts[key];
        if (text.length > 0) [lines addObject:text];
    }
    self.asrTextView.textColor = UIColor.labelColor;
    self.asrTextView.text = lines.count > 0 ? [lines componentsJoinedByString:@"\n"] : @"等待 ASR 回调…";
    [self.asrTextView scrollRangeToVisible:NSMakeRange(self.asrTextView.text.length, 0)];
}

- (void)refreshTranslateText {
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    for (NSString *key in self.translateOrder) {
        NSString *text = self.translateTexts[key];
        if (text.length > 0) [lines addObject:text];
    }
    self.nlgTextView.textColor = UIColor.labelColor;
    self.nlgTextView.text = lines.count > 0 ? [lines componentsJoinedByString:@"\n"] : @"等待实时翻译回调…";
    [self.nlgTextView scrollRangeToVisible:NSMakeRange(self.nlgTextView.text.length, 0)];
}

#pragma mark - Messages and logs

- (void)resetResultViews {
    [self.amplitudes removeAllObjects];
    [self.asrTexts removeAllObjects];
    [self.asrOrder removeAllObjects];
    [self.translateTexts removeAllObjects];
    [self.translateOrder removeAllObjects];
    self.elapsedMilliseconds = 0;
    self.taskLabel.text = @"recordId: -\ndeviceId: -";
    self.asrTextView.textColor = UIColor.secondaryLabelColor;
    self.asrTextView.text = @"等待 ASR 回调…";
    self.nlgTextView.textColor = UIColor.secondaryLabelColor;
    self.nlgTextView.text = @"等待实时翻译回调…";
    [self redrawWaveform];
}

- (void)appendLog:(NSString *)message {
    if (message.length == 0) return;
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"HH:mm:ss.SSS";
    [self.eventLogs addObject:[NSString stringWithFormat:@"[%@] %@", [formatter stringFromDate:NSDate.date], message]];
    if (self.eventLogs.count > kNativeSDKMaxLogCount) [self.eventLogs removeObjectAtIndex:0];
    self.logTextView.textColor = UIColor.labelColor;
    self.logTextView.text = [self.eventLogs componentsJoinedByString:@"\n"];
    [self.logTextView scrollRangeToVisible:NSMakeRange(self.logTextView.text.length, 0)];
}

- (void)showMessageWithTitle:(NSString *)title message:(NSString *)message {
    if (!self.view.window || self.presentedViewController) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
