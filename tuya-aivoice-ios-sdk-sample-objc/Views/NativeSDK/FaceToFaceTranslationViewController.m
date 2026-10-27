//
//  FaceToFaceTranslationViewController.m
//  AIVoiceDemo
//

#import "FaceToFaceTranslationViewController.h"
#import "NativeAudioService.h"
#import "DeviceService.h"
#import <AVFAudio/AVFAudio.h>
#import <ThingAudioRecordInterface/ThingAudioRecordInterface.h>

static NSString * const kFaceToFacePhoneDeviceId = @"PHONE";

@interface FaceToFaceSideAudioConfig : NSObject

@property (nonatomic, copy) NSString *inputDeviceId;
@property (nonatomic, assign) ThingAudioSource audioSource;
@property (nonatomic, assign) ThingAudioTTSOutput ttsOutput;
@property (nonatomic, assign) ThingAudioTTSEncode ttsEncode;
@property (nonatomic, copy) NSString *ttsDeviceId;
@property (nonatomic, assign) BOOL ttsEnabled;
@property (nonatomic, assign) ThingAudioTtsPlaybackMode ttsPlaybackMode;

@end

@implementation FaceToFaceSideAudioConfig
@end

static NSArray<NSDictionary<NSString *, NSString *> *> *FaceToFaceLanguages(void) {
    static NSArray *languages = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        languages = @[
            @{@"code": @"zh", @"name": @"中文"},
            @{@"code": @"en", @"name": @"英语"},
            @{@"code": @"ja", @"name": @"日语"},
            @{@"code": @"ko", @"name": @"韩语"},
            @{@"code": @"fr", @"name": @"法语"},
            @{@"code": @"de", @"name": @"德语"},
            @{@"code": @"es", @"name": @"西班牙语"},
            @{@"code": @"ru", @"name": @"俄语"},
            @{@"code": @"it", @"name": @"意大利语"},
            @{@"code": @"pt", @"name": @"葡萄牙语"},
            @{@"code": @"th", @"name": @"泰语"},
            @{@"code": @"vi", @"name": @"越南语"},
            @{@"code": @"ar", @"name": @"阿拉伯语"},
            @{@"code": @"hi", @"name": @"印地语"},
        ];
    });
    return languages;
}

@interface FaceToFaceTranslationViewController () <ThingAudioRecordManagerDelegate, AVAudioPlayerDelegate>

@property (nonatomic, copy) NSArray<ThingSmartDeviceModel *> *devices;
@property (nonatomic, strong) FaceToFaceSideAudioConfig *leftAudioConfig;
@property (nonatomic, strong) FaceToFaceSideAudioConfig *rightAudioConfig;
@property (nonatomic, copy) NSString *leftLanguage;
@property (nonatomic, copy) NSString *rightLanguage;

@property (nonatomic, copy, nullable) NSString *listenerDeviceId;
@property (nonatomic, copy, nullable) NSString *activeDeviceId;
@property (nonatomic, strong) NSMutableOrderedSet<NSString *> *sessionDeviceIds;
@property (nonatomic, assign) ThingAudioRecordState recordState;
@property (nonatomic, assign) NSInteger activeSpeaker;
@property (nonatomic, assign) NSInteger turnSequence;
@property (nonatomic, copy) NSString *currentTurnKey;
@property (nonatomic, assign) BOOL operationPending;
@property (nonatomic, assign) BOOL endingSession;

@property (nonatomic, strong) UIButton *leftLanguageButton;
@property (nonatomic, strong) UIButton *rightLanguageButton;
@property (nonatomic, strong) UIButton *leftInputButton;
@property (nonatomic, strong) UIButton *leftOutputButton;
@property (nonatomic, strong) UIButton *leftTTSButton;
@property (nonatomic, strong) UIButton *leftTTSPlaybackModeButton;
@property (nonatomic, strong) UIButton *rightInputButton;
@property (nonatomic, strong) UIButton *rightOutputButton;
@property (nonatomic, strong) UIButton *rightTTSButton;
@property (nonatomic, strong) UIButton *rightTTSPlaybackModeButton;
@property (nonatomic, strong) UILabel *deviceHintLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIScrollView *conversationScrollView;
@property (nonatomic, strong) UIStackView *conversationStack;
@property (nonatomic, strong) UILabel *emptyConversationLabel;
@property (nonatomic, strong) UIButton *leftSpeakButton;
@property (nonatomic, strong) UIButton *rightSpeakButton;

@property (nonatomic, strong) NSMutableDictionary<NSString *, UILabel *> *asrLabels;
@property (nonatomic, strong) NSMutableDictionary<NSString *, UILabel *> *translationLabels;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *speakerByKey;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *bubbleKeyByResultKey;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSString *> *activeSentenceKeyBySpeaker;
@property (nonatomic, strong) NSMutableSet<NSString *> *recognizedSentenceKeys;
@property (nonatomic, strong) NSMutableDictionary<NSString *, ThingAudioRecordAsrResult *> *sentenceByBubbleKey;
@property (nonatomic, strong) NSMutableDictionary<NSString *, UIButton *> *ttsButtons;
@property (nonatomic, strong, nullable) AVAudioPlayer *ttsPlayer;
@property (nonatomic, copy, nullable) NSString *playingBubbleKey;
@property (nonatomic, copy, nullable) NSString *ttsRequestToken;
@property (nonatomic, copy, nullable) NSString *previousAudioCategory;
@property (nonatomic, copy, nullable) NSString *previousAudioMode;
@property (nonatomic, assign) AVAudioSessionCategoryOptions previousAudioOptions;
@property (nonatomic, assign) BOOL ttsActivatedAudioSession;
@property (nonatomic, assign) BOOL ttsChangedAudioRoute;
@property (nonatomic, strong, nullable) AVAudioSessionPortDescription *previousAudioInput;
@property (nonatomic, assign) AVAudioSessionPortOverride previousAudioOutputOverride;
@property (nonatomic, assign) ThingAudioTTSOutput playingTTSOutput;

@end

@implementation FaceToFaceTranslationViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self configureFamilyNavigationWithTitle:@"对话翻译"
                                   leftTitle:nil
                                  leftAction:nil
                                  rightTitle:nil
                                 rightAction:nil];

    self.leftAudioConfig = [self defaultSideAudioConfigForSpeaker:0];
    self.rightAudioConfig = [self defaultSideAudioConfigForSpeaker:1];
    self.leftLanguage = @"zh";
    self.rightLanguage = @"en";
    self.recordState = ThingAudioRecordStateUnknown;
    self.activeSpeaker = -1;
    self.sessionDeviceIds = [NSMutableOrderedSet orderedSet];
    self.asrLabels = [NSMutableDictionary dictionary];
    self.translationLabels = [NSMutableDictionary dictionary];
    self.speakerByKey = [NSMutableDictionary dictionary];
    self.bubbleKeyByResultKey = [NSMutableDictionary dictionary];
    self.activeSentenceKeyBySpeaker = [NSMutableDictionary dictionary];
    self.recognizedSentenceKeys = [NSMutableSet set];
    self.sentenceByBubbleKey = [NSMutableDictionary dictionary];
    self.ttsButtons = [NSMutableDictionary dictionary];

    [self setupUI];
    [self updateControls];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(audioSessionInterrupted:)
                                                 name:AVAudioSessionInterruptionNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(ttsAudioRouteChanged:)
                                                 name:AVAudioSessionRouteChangeNotification
                                               object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self loadDevices];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stopTTSPlayback];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    BOOL popped = self.navigationController && ![self.navigationController.viewControllers containsObject:self];
    BOOL dismissed = self.isBeingDismissed || self.navigationController.isBeingDismissed;
    if ((popped || dismissed) && !self.endingSession) {
        self.endingSession = YES;
        NSArray<NSString *> *deviceIds = self.sessionDeviceIds.array;
        if (deviceIds.count == 0 && self.activeDeviceId.length > 0) {
            deviceIds = @[self.activeDeviceId];
        }
        for (NSString *deviceId in deviceIds) {
            [[NativeAudioService sharedInstance] stopRecordingWithDeviceId:deviceId success:nil failure:nil];
        }
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self unbindListener];
}

#pragma mark - UI

- (void)setupUI {
    UIView *bottomPanel = [[UIView alloc] init];
    bottomPanel.translatesAutoresizingMaskIntoConstraints = NO;
    bottomPanel.backgroundColor = self.familyCardColor;
    bottomPanel.layer.shadowColor = UIColor.blackColor.CGColor;
    bottomPanel.layer.shadowOpacity = 0.08;
    bottomPanel.layer.shadowRadius = 10;
    bottomPanel.layer.shadowOffset = CGSizeMake(0, -3);
    [self.view addSubview:bottomPanel];

    self.leftSpeakButton = [self speakerButtonWithColor:UIColor.systemBlueColor action:@selector(leftSpeakButtonTapped:)];
    self.rightSpeakButton = [self speakerButtonWithColor:UIColor.systemOrangeColor action:@selector(rightSpeakButtonTapped:)];

    UIStackView *speakRow = [[UIStackView alloc] initWithArrangedSubviews:@[self.leftSpeakButton, self.rightSpeakButton]];
    speakRow.axis = UILayoutConstraintAxisHorizontal;
    speakRow.spacing = 10;
    speakRow.translatesAutoresizingMaskIntoConstraints = NO;
    [bottomPanel addSubview:speakRow];

    UIScrollView *pageScroll = [[UIScrollView alloc] init];
    pageScroll.translatesAutoresizingMaskIntoConstraints = NO;
    pageScroll.alwaysBounceVertical = YES;
    [self.view addSubview:pageScroll];

    UIStackView *pageStack = [[UIStackView alloc] init];
    pageStack.axis = UILayoutConstraintAxisVertical;
    pageStack.spacing = 14;
    pageStack.translatesAutoresizingMaskIntoConstraints = NO;
    [pageScroll addSubview:pageStack];

    [NSLayoutConstraint activateConstraints:@[
        [bottomPanel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [bottomPanel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [bottomPanel.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
        [speakRow.topAnchor constraintEqualToAnchor:bottomPanel.topAnchor constant:12],
        [speakRow.leadingAnchor constraintEqualToAnchor:bottomPanel.leadingAnchor constant:16],
        [speakRow.trailingAnchor constraintEqualToAnchor:bottomPanel.trailingAnchor constant:-16],
        [speakRow.bottomAnchor constraintEqualToAnchor:bottomPanel.bottomAnchor constant:-12],
        [self.leftSpeakButton.heightAnchor constraintEqualToConstant:76],
        [self.rightSpeakButton.heightAnchor constraintEqualToAnchor:self.leftSpeakButton.heightAnchor],
        [self.leftSpeakButton.widthAnchor constraintEqualToAnchor:self.rightSpeakButton.widthAnchor],

        [pageScroll.topAnchor constraintEqualToAnchor:self.familyContentGuide.topAnchor],
        [pageScroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [pageScroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [pageScroll.bottomAnchor constraintEqualToAnchor:bottomPanel.topAnchor],
        [pageStack.topAnchor constraintEqualToAnchor:pageScroll.contentLayoutGuide.topAnchor constant:12],
        [pageStack.leadingAnchor constraintEqualToAnchor:pageScroll.frameLayoutGuide.leadingAnchor constant:16],
        [pageStack.trailingAnchor constraintEqualToAnchor:pageScroll.frameLayoutGuide.trailingAnchor constant:-16],
        [pageStack.bottomAnchor constraintEqualToAnchor:pageScroll.contentLayoutGuide.bottomAnchor constant:-16],
    ]];

    self.leftLanguageButton = [self configButtonWithTitle:@"左侧：中文" action:@selector(leftLanguageButtonTapped:)];
    self.rightLanguageButton = [self configButtonWithTitle:@"右侧：英语" action:@selector(rightLanguageButtonTapped:)];
    self.leftInputButton = [self configButtonWithTitle:@"输入：手机麦克风" action:@selector(leftInputButtonTapped:)];
    self.leftOutputButton = [self configButtonWithTitle:@"输出：系统蓝牙" action:@selector(leftOutputButtonTapped:)];
    self.leftTTSButton = [self configButtonWithTitle:@"TTS：开启" action:@selector(leftTTSButtonTapped:)];
    self.leftTTSPlaybackModeButton = [self configButtonWithTitle:@"播放模式：实时播放" action:@selector(leftTTSPlaybackModeButtonTapped:)];
    self.rightInputButton = [self configButtonWithTitle:@"输入：系统蓝牙" action:@selector(rightInputButtonTapped:)];
    self.rightOutputButton = [self configButtonWithTitle:@"输出：未配置" action:@selector(rightOutputButtonTapped:)];
    self.rightTTSButton = [self configButtonWithTitle:@"TTS：关闭" action:@selector(rightTTSButtonTapped:)];
    self.rightTTSPlaybackModeButton = [self configButtonWithTitle:@"播放模式：实时播放" action:@selector(rightTTSPlaybackModeButtonTapped:)];
    self.rightTTSButton.tintColor = UIColor.secondaryLabelColor;

    UIStackView *languageRow = [self equalRowWithViews:@[self.leftLanguageButton, self.rightLanguageButton]];
    [pageStack addArrangedSubview:[self cardWithTitle:@"对话语言" content:languageRow]];

    UIStackView *leftAudioRow = [self equalRowWithViews:@[self.leftInputButton, self.leftOutputButton]];
    UIStackView *leftConfiguration = [[UIStackView alloc] initWithArrangedSubviews:@[leftAudioRow, self.leftTTSButton, self.leftTTSPlaybackModeButton]];
    leftConfiguration.axis = UILayoutConstraintAxisVertical;
    leftConfiguration.spacing = 10;
    [pageStack addArrangedSubview:[self cardWithTitle:@"左侧音频配置" content:leftConfiguration]];

    UIStackView *rightAudioRow = [self equalRowWithViews:@[self.rightInputButton, self.rightOutputButton]];
    UIStackView *rightConfiguration = [[UIStackView alloc] initWithArrangedSubviews:@[rightAudioRow, self.rightTTSButton, self.rightTTSPlaybackModeButton]];
    rightConfiguration.axis = UILayoutConstraintAxisVertical;
    rightConfiguration.spacing = 10;
    [pageStack addArrangedSubview:[self cardWithTitle:@"右侧音频配置" content:rightConfiguration]];

    self.deviceHintLabel = [[UILabel alloc] init];
    self.deviceHintLabel.font = [UIFont systemFontOfSize:13];
    self.deviceHintLabel.textColor = UIColor.systemOrangeColor;
    self.deviceHintLabel.numberOfLines = 0;
    self.deviceHintLabel.hidden = YES;
    [pageStack addArrangedSubview:self.deviceHintLabel];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    self.statusLabel.textColor = self.familySecondaryTextColor;
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.numberOfLines = 0;
    [pageStack addArrangedSubview:self.statusLabel];

    self.conversationScrollView = [[UIScrollView alloc] init];
    self.conversationScrollView.backgroundColor = self.familyCardColor;
    self.conversationScrollView.layer.cornerRadius = 16;
    self.conversationScrollView.alwaysBounceVertical = YES;
    [self.conversationScrollView.heightAnchor constraintGreaterThanOrEqualToConstant:300].active = YES;
    [pageStack addArrangedSubview:self.conversationScrollView];

    self.conversationStack = [[UIStackView alloc] init];
    self.conversationStack.axis = UILayoutConstraintAxisVertical;
    self.conversationStack.spacing = 12;
    self.conversationStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.conversationScrollView addSubview:self.conversationStack];
    [NSLayoutConstraint activateConstraints:@[
        [self.conversationStack.topAnchor constraintEqualToAnchor:self.conversationScrollView.contentLayoutGuide.topAnchor constant:16],
        [self.conversationStack.leadingAnchor constraintEqualToAnchor:self.conversationScrollView.frameLayoutGuide.leadingAnchor constant:12],
        [self.conversationStack.trailingAnchor constraintEqualToAnchor:self.conversationScrollView.frameLayoutGuide.trailingAnchor constant:-12],
        [self.conversationStack.bottomAnchor constraintEqualToAnchor:self.conversationScrollView.contentLayoutGuide.bottomAnchor constant:-16],
    ]];

    self.emptyConversationLabel = [[UILabel alloc] init];
    self.emptyConversationLabel.text = @"点击左侧或右侧按钮开始发言\n识别原文和翻译结果会实时显示在这里";
    self.emptyConversationLabel.font = [UIFont systemFontOfSize:15];
    self.emptyConversationLabel.textColor = UIColor.tertiaryLabelColor;
    self.emptyConversationLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyConversationLabel.numberOfLines = 0;
    [self.emptyConversationLabel.heightAnchor constraintGreaterThanOrEqualToConstant:250].active = YES;
    [self.conversationStack addArrangedSubview:self.emptyConversationLabel];
}

- (UIView *)cardWithTitle:(NSString *)title content:(UIView *)content {
    UIView *card = [[UIView alloc] init];
    card.backgroundColor = self.familyCardColor;
    card.layer.cornerRadius = 16;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = title;
    titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[titleLabel, content]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:card.topAnchor constant:14],
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:14],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-14],
        [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-14],
    ]];
    return card;
}

- (UIStackView *)equalRowWithViews:(NSArray<UIView *> *)views {
    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:views];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.spacing = 10;
    row.distribution = UIStackViewDistributionFillEqually;
    return row;
}

- (UIButton *)configButtonWithTitle:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    button.titleLabel.numberOfLines = 2;
    button.backgroundColor = UIColor.tertiarySystemFillColor;
    button.layer.cornerRadius = 10;
    button.contentEdgeInsets = UIEdgeInsetsMake(10, 10, 10, 10);
    [button.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (UIButton *)speakerButtonWithColor:(UIColor *)color action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.backgroundColor = color;
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    button.titleLabel.numberOfLines = 2;
    button.titleLabel.textAlignment = NSTextAlignmentCenter;
    button.layer.cornerRadius = 16;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

#pragma mark - Configuration

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    [self loadDevices];
}

- (void)loadDevices {
    __weak typeof(self) weakSelf = self;
    [[DeviceService sharedInstance] getDeviceListWithSuccess:^(NSArray<ThingSmartDeviceModel *> * _Nullable deviceList) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.devices = deviceList ?: @[];
        self.deviceHintLabel.hidden = self.devices.count > 0;
        self.deviceHintLabel.text = self.devices.count > 0 ? @"" : @"当前没有可用设备，仍可使用手机麦克风和手机扬声器。";
    } failure:^(NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.devices = @[];
        self.deviceHintLabel.text = [NSString stringWithFormat:@"设备加载失败：%@", error.localizedDescription ?: @"未知错误"];
        self.deviceHintLabel.hidden = NO;
    }];
}

- (FaceToFaceSideAudioConfig *)defaultSideAudioConfigForSpeaker:(NSInteger)speaker {
    FaceToFaceSideAudioConfig *config = [[FaceToFaceSideAudioConfig alloc] init];
    config.inputDeviceId = kFaceToFacePhoneDeviceId;
    config.ttsEncode = ThingAudioTTSEncode_DEFAULT;
    config.ttsDeviceId = @"";
    config.ttsPlaybackMode = ThingAudioTtsPlaybackModeImmediate;
    if (speaker == 0) {
        config.audioSource = ThingSystemMic16KMono;
        config.ttsOutput = ThingAudioTTSOutput_SYSTEM_BLUETOOTH;
        config.ttsEnabled = YES;
    } else {
        config.audioSource = ThingSystemBlueTooth16KMono;
        config.ttsOutput = ThingAudioTTSOutput_DEFAULT;
        config.ttsEnabled = NO;
    }
    return config;
}

- (FaceToFaceSideAudioConfig *)audioConfigForSpeaker:(NSInteger)speaker {
    return speaker == 0 ? self.leftAudioConfig : self.rightAudioConfig;
}

- (UIButton *)inputButtonForSpeaker:(NSInteger)speaker {
    return speaker == 0 ? self.leftInputButton : self.rightInputButton;
}

- (UIButton *)outputButtonForSpeaker:(NSInteger)speaker {
    return speaker == 0 ? self.leftOutputButton : self.rightOutputButton;
}

- (UIButton *)ttsButtonForSpeaker:(NSInteger)speaker {
    return speaker == 0 ? self.leftTTSButton : self.rightTTSButton;
}

- (void)leftInputButtonTapped:(UIButton *)sender {
    [self presentInputPickerForSpeaker:0 sourceView:sender];
}

- (void)rightInputButtonTapped:(UIButton *)sender {
    [self presentInputPickerForSpeaker:1 sourceView:sender];
}

- (void)presentInputPickerForSpeaker:(NSInteger)speaker sourceView:(UIButton *)sourceView {
    if (self.operationPending) return;
    NSString *side = speaker == 0 ? @"左侧" : @"右侧";
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"选择%@输入源", side] message:@"配置将在该侧下一次发言时生效" preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf = self;
    [sheet addAction:[UIAlertAction actionWithTitle:@"手机麦克风" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [weakSelf selectInputDeviceId:kFaceToFacePhoneDeviceId source:ThingSystemMic16KMono title:@"手机麦克风" speaker:speaker];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"系统蓝牙麦克风" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [weakSelf selectInputDeviceId:kFaceToFacePhoneDeviceId source:ThingSystemBlueTooth16KMono title:@"系统蓝牙" speaker:speaker];
    }]];
    for (ThingSmartDeviceModel *device in self.devices) {
        NSString *deviceId = device.devId;
        NSString *name = device.name.length > 0 ? device.name : @"未命名设备";
        [sheet addAction:[UIAlertAction actionWithTitle:name style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [weakSelf selectInputDeviceId:deviceId source:ThingEarPhonePro16KMono title:name speaker:speaker];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self configurePopover:sheet sourceView:sourceView];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)selectInputDeviceId:(NSString *)deviceId
                     source:(ThingAudioSource)source
                      title:(NSString *)title
                    speaker:(NSInteger)speaker {
    FaceToFaceSideAudioConfig *config = [self audioConfigForSpeaker:speaker];
    config.inputDeviceId = deviceId;
    config.audioSource = source;
    [[self inputButtonForSpeaker:speaker] setTitle:[NSString stringWithFormat:@"输入：%@", title] forState:UIControlStateNormal];
    [self updateControls];
}

- (void)leftOutputButtonTapped:(UIButton *)sender {
    [self presentOutputPickerForSpeaker:0 sourceView:sender];
}

- (void)rightOutputButtonTapped:(UIButton *)sender {
    [self presentOutputPickerForSpeaker:1 sourceView:sender];
}

- (void)presentOutputPickerForSpeaker:(NSInteger)speaker sourceView:(UIButton *)sourceView {
    if (self.operationPending) return;
    NSString *side = speaker == 0 ? @"左侧" : @"右侧";
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"选择%@ TTS 输出", side] message:@"消息回听使用该侧当前输出配置；实时 TTS 在该侧下一次发言时生效" preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf = self;
    [sheet addAction:[UIAlertAction actionWithTitle:@"手机扬声器" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [weakSelf selectOutput:ThingAudioTTSOutput_SYSTEM_MIC encode:ThingAudioTTSEncode_DEFAULT deviceId:@"" title:@"手机扬声器" speaker:speaker];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"系统蓝牙" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [weakSelf selectOutput:ThingAudioTTSOutput_SYSTEM_BLUETOOTH encode:ThingAudioTTSEncode_DEFAULT deviceId:@"" title:@"系统蓝牙" speaker:speaker];
    }]];
    for (ThingSmartDeviceModel *device in self.devices) {
        NSString *deviceId = device.devId;
        NSString *name = device.name.length > 0 ? device.name : @"未命名设备";
        [sheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"%@ · OPUS SILK", name] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [weakSelf selectOutput:ThingAudioTTSOutput_DEVICE encode:ThingAudioTTSEncode_OPUS_SILK deviceId:deviceId title:[NSString stringWithFormat:@"%@ · SILK", name] speaker:speaker];
        }]];
        [sheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"%@ · OPUS CELT", name] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [weakSelf selectOutput:ThingAudioTTSOutput_DEVICE encode:ThingAudioTTSEncode_OPUS_CELT deviceId:deviceId title:[NSString stringWithFormat:@"%@ · CELT", name] speaker:speaker];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self configurePopover:sheet sourceView:sourceView];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)selectOutput:(ThingAudioTTSOutput)output
               encode:(ThingAudioTTSEncode)encode
             deviceId:(NSString *)deviceId
                title:(NSString *)title
              speaker:(NSInteger)speaker {
    [self stopTTSPlayback];
    FaceToFaceSideAudioConfig *config = [self audioConfigForSpeaker:speaker];
    config.ttsOutput = output;
    config.ttsEncode = encode;
    config.ttsDeviceId = deviceId ?: @"";
    [[self outputButtonForSpeaker:speaker] setTitle:[NSString stringWithFormat:@"输出：%@", title] forState:UIControlStateNormal];
}

- (void)leftLanguageButtonTapped:(UIButton *)sender {
    [self presentLanguagePickerWithTitle:@"选择左侧语言" current:self.leftLanguage sourceView:sender completion:^(NSString *code) {
        self.leftLanguage = code;
        [self refreshLanguageTitles];
    }];
}

- (void)rightLanguageButtonTapped:(UIButton *)sender {
    [self presentLanguagePickerWithTitle:@"选择右侧语言" current:self.rightLanguage sourceView:sender completion:^(NSString *code) {
        self.rightLanguage = code;
        [self refreshLanguageTitles];
    }];
}

- (void)presentLanguagePickerWithTitle:(NSString *)title
                               current:(NSString *)current
                            sourceView:(UIView *)sourceView
                            completion:(void (^)(NSString *code))completion {
    if (self.operationPending) return;
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:title message:@"配置将在下一次发言时生效" preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSDictionary<NSString *, NSString *> *language in FaceToFaceLanguages()) {
        NSString *code = language[@"code"];
        NSString *name = language[@"name"];
        NSString *actionTitle = [current isEqualToString:code] ? [NSString stringWithFormat:@"%@  ✓", name] : name;
        [sheet addAction:[UIAlertAction actionWithTitle:actionTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            if (completion) completion(code);
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self configurePopover:sheet sourceView:sourceView];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)leftTTSButtonTapped:(UIButton *)sender {
    [self toggleTTSForSpeaker:0];
}

- (void)rightTTSButtonTapped:(UIButton *)sender {
    [self toggleTTSForSpeaker:1];
}

- (void)toggleTTSForSpeaker:(NSInteger)speaker {
    if (self.operationPending) return;
    FaceToFaceSideAudioConfig *config = [self audioConfigForSpeaker:speaker];
    config.ttsEnabled = !config.ttsEnabled;
    UIButton *button = [self ttsButtonForSpeaker:speaker];
    [button setTitle:config.ttsEnabled ? @"TTS：开启" : @"TTS：关闭" forState:UIControlStateNormal];
    button.tintColor = config.ttsEnabled ? UIColor.systemBlueColor : UIColor.secondaryLabelColor;
    [self updateControls];
}

- (void)leftTTSPlaybackModeButtonTapped:(UIButton *)sender {
    [self presentTTSPlaybackModePickerForSpeaker:0 sourceView:sender];
}

- (void)rightTTSPlaybackModeButtonTapped:(UIButton *)sender {
    [self presentTTSPlaybackModePickerForSpeaker:1 sourceView:sender];
}

- (void)presentTTSPlaybackModePickerForSpeaker:(NSInteger)speaker sourceView:(UIButton *)sourceView {
    FaceToFaceSideAudioConfig *config = [self audioConfigForSpeaker:speaker];
    if (self.operationPending || !config.ttsEnabled) return;
    NSString *side = speaker == 0 ? @"左侧" : @"右侧";
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"选择%@ TTS 播放模式", side]
                                                                 message:@"实时播放不缓存；仅缓存不播放；播放并缓存同时执行。缓存保存完整句 MP3，配置将在该侧下一次发言时生效。"
                                                          preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray<NSString *> *names = @[@"实时播放", @"仅缓存", @"播放并缓存"];
    NSArray<NSNumber *> *modes = @[@(ThingAudioTtsPlaybackModeImmediate), @(ThingAudioTtsPlaybackModeDeferred), @(ThingAudioTtsPlaybackModePlayAndCache)];
    for (NSUInteger index = 0; index < modes.count; index++) {
        ThingAudioTtsPlaybackMode mode = modes[index].integerValue;
        NSString *name = names[index];
        NSString *title = mode == config.ttsPlaybackMode ? [name stringByAppendingString:@"  ✓"] : name;
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            config.ttsPlaybackMode = mode;
            [sourceView setTitle:[NSString stringWithFormat:@"播放模式：%@", name] forState:UIControlStateNormal];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self configurePopover:sheet sourceView:sourceView];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)refreshLanguageTitles {
    NSString *leftName = [self displayNameForLanguage:self.leftLanguage];
    NSString *rightName = [self displayNameForLanguage:self.rightLanguage];
    [self.leftLanguageButton setTitle:[NSString stringWithFormat:@"左侧：%@", leftName] forState:UIControlStateNormal];
    [self.rightLanguageButton setTitle:[NSString stringWithFormat:@"右侧：%@", rightName] forState:UIControlStateNormal];
    [self updateControls];
}

- (NSString *)displayNameForLanguage:(NSString *)code {
    for (NSDictionary<NSString *, NSString *> *language in FaceToFaceLanguages()) {
        if ([language[@"code"] isEqualToString:code]) return language[@"name"];
    }
    return code.length > 0 ? code : @"-";
}

- (void)configurePopover:(UIAlertController *)alert sourceView:(UIView *)sourceView {
    if (alert.popoverPresentationController) {
        alert.popoverPresentationController.sourceView = sourceView;
        alert.popoverPresentationController.sourceRect = sourceView.bounds;
    }
}

#pragma mark - Conversation control

- (void)leftSpeakButtonTapped:(UIButton *)sender {
    [self handleSpeakerTap:0];
}

- (void)rightSpeakButtonTapped:(UIButton *)sender {
    [self handleSpeakerTap:1];
}

- (void)handleSpeakerTap:(NSInteger)speaker {
    FaceToFaceSideAudioConfig *audioConfig = [self audioConfigForSpeaker:speaker];
    if (self.operationPending || audioConfig.inputDeviceId.length == 0) return;

    if (self.recordState == ThingAudioRecordStateOngoing) {
        if (self.activeSpeaker == speaker) {
            [self pauseCurrentTurn];
        }
        return;
    }
    [self ensureMicrophonePermissionThenStartSpeaker:speaker];
}

- (void)ensureMicrophonePermissionThenStartSpeaker:(NSInteger)speaker {
    FaceToFaceSideAudioConfig *audioConfig = [self audioConfigForSpeaker:speaker];
    BOOL usesPhoneAudio = [audioConfig.inputDeviceId isEqualToString:kFaceToFacePhoneDeviceId];
    if (!usesPhoneAudio) {
        [self startSpeaker:speaker];
        return;
    }

    AVAudioSessionRecordPermission permission = AVAudioSession.sharedInstance.recordPermission;
    if (permission == AVAudioSessionRecordPermissionDenied) {
        [self showFamilyMessageWithTitle:@"无法使用麦克风" message:@"请在系统设置中允许此 App 访问麦克风后重试。"];
        return;
    }
    if (permission == AVAudioSessionRecordPermissionUndetermined) {
        __weak typeof(self) weakSelf = self;
        [AVAudioSession.sharedInstance requestRecordPermission:^(BOOL granted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) self = weakSelf;
                if (!self) return;
                if (granted) {
                    [self startSpeaker:speaker];
                } else {
                    [self showFamilyMessageWithTitle:@"麦克风权限未开启" message:@"使用手机或系统蓝牙输入需要麦克风权限。"];
                }
            });
        }];
        return;
    }
    [self startSpeaker:speaker];
}

- (void)pauseCurrentTurn {
    NSString *deviceId = self.activeDeviceId;
    if (deviceId.length == 0) return;

    self.operationPending = YES;
    [self updateControls];
    __weak typeof(self) weakSelf = self;
    [[NativeAudioService sharedInstance] pauseRecordingWithDeviceId:deviceId success:^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.operationPending = NO;
        self.recordState = ThingAudioRecordStatePaused;
        self.activeSpeaker = -1;
        [self updateControls];
    } failure:^(NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.operationPending = NO;
        ThingAudioRecordObject *task = [[NativeAudioService sharedInstance] activeTaskWithDeviceId:deviceId];
        if (task) self.recordState = task.state;
        [self updateControls];
        [self showFamilyMessageWithTitle:@"暂停发言失败" message:error.localizedDescription ?: @"未知错误"];
    }];
}

- (void)startSpeaker:(NSInteger)speaker {
    [self stopTTSPlayback];
    FaceToFaceSideAudioConfig *audioConfig = [self audioConfigForSpeaker:speaker];
    [self bindListenerToDeviceId:audioConfig.inputDeviceId];
    self.operationPending = YES;
    self.activeSpeaker = speaker;
    self.activeDeviceId = audioConfig.inputDeviceId;
    [self.sessionDeviceIds addObject:audioConfig.inputDeviceId];
    self.turnSequence += 1;
    self.currentTurnKey = [NSString stringWithFormat:@"turn-%ld-%ld", (long)self.turnSequence, (long)speaker];
    [self updateControls];

    ThingAudioRecordConfig *config = [self configForSpeaker:speaker];
    NSString *deviceId = audioConfig.inputDeviceId;
    __weak typeof(self) weakSelf = self;
    [[NativeAudioService sharedInstance] startRecordingWithDeviceId:deviceId config:config success:^(ThingAudioRecordObject *task) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.operationPending = NO;
        self.recordState = ThingAudioRecordStateOngoing;
        self.activeDeviceId = task.deviceId.length > 0 ? task.deviceId : deviceId;
        [self updateControls];
    } failure:^(NSError *error) {
        [weakSelf handleFailure:@"开始发言失败" error:error];
    }];
}

- (ThingAudioRecordConfig *)configForSpeaker:(NSInteger)speaker {
    FaceToFaceSideAudioConfig *audioConfig = [self audioConfigForSpeaker:speaker];
    NSString *sourceLanguage = speaker == 0 ? self.leftLanguage : self.rightLanguage;
    NSString *targetLanguage = speaker == 0 ? self.rightLanguage : self.leftLanguage;

    ThingAudioRecordConfig *config = [[ThingAudioRecordConfig alloc] init];
    config.saveDataWhenError = YES;
    config.recordType = ThingAudioRecordTypeFaceToFace;
    config.businessType = ThingAudioBusinessTypeTranslate;
    config.controlTimeout = 5;
    config.dataTimeout = 10;
    config.transferType = ThingAudioRecordTransferTypeRealTime;
    config.audioSource = audioConfig.audioSource;
    config.audioSourceList = @[@(audioConfig.audioSource)];
    config.needAsr = YES;
    config.needTranslate = YES;
    config.needTTS = audioConfig.ttsEnabled;
    config.ttsPlaybackMode = @(audioConfig.ttsPlaybackMode);
    config.needAmplitude = NO;
    config.needAutoRecognize = NO;
    config.originalLanguage = sourceLanguage;
    config.targetLanguage = targetLanguage;
    config.f2fChannel = (int)speaker;
    config.startLivingStatus = 0;

    if (config.needTTS) {
        ThingAudioTTSConfig *ttsConfig = [[ThingAudioTTSConfig alloc] initTtsConfigWith:audioConfig.ttsOutput
                                                                                 encode:audioConfig.ttsEncode
                                                                                channel:ThingAudioTTSOutputChannel_DEFAULT
                                                                               deviceId:audioConfig.ttsDeviceId ?: @""];
        config.ttsConfig = ttsConfig;
        config.ttsConfigList = @[ttsConfig];
    }
    config.audio3AConfig = [ThingAudio3AConfig optimalConfigForSupportTTS:config.needTTS];
    return config;
}

- (BOOL)isSessionActive {
    return self.recordState == ThingAudioRecordStateOngoing || self.recordState == ThingAudioRecordStatePaused;
}

- (void)handleFailure:(NSString *)title error:(NSError *)error {
    self.operationPending = NO;
    self.activeSpeaker = -1;
    ThingAudioRecordObject *task = self.activeDeviceId.length > 0
        ? [[NativeAudioService sharedInstance] activeTaskWithDeviceId:self.activeDeviceId]
        : nil;
    self.recordState = task ? task.state : ThingAudioRecordStateUnknown;
    [self updateControls];
    [self showFamilyMessageWithTitle:title message:error.localizedDescription ?: @"未知错误"];
}

- (void)updateControls {
    BOOL leftHasInput = self.leftAudioConfig.inputDeviceId.length > 0;
    BOOL rightHasInput = self.rightAudioConfig.inputDeviceId.length > 0;
    BOOL recording = self.recordState == ThingAudioRecordStateOngoing;
    [self updateTTSPlaybackButtons];
    self.leftTTSPlaybackModeButton.enabled = self.leftAudioConfig.ttsEnabled && !self.operationPending;
    self.rightTTSPlaybackModeButton.enabled = self.rightAudioConfig.ttsEnabled && !self.operationPending;
    self.leftSpeakButton.enabled = leftHasInput && !self.operationPending && (!recording || self.activeSpeaker == 0);
    self.rightSpeakButton.enabled = rightHasInput && !self.operationPending && (!recording || self.activeSpeaker == 1);

    NSString *leftName = [self displayNameForLanguage:self.leftLanguage];
    NSString *rightName = [self displayNameForLanguage:self.rightLanguage];
    NSString *leftAction = @"点击发言";
    NSString *rightAction = @"点击发言";
    if (self.recordState == ThingAudioRecordStateOngoing) {
        leftAction = self.activeSpeaker == 0 ? @"● 录音中" : @"等待中";
        rightAction = self.activeSpeaker == 1 ? @"● 录音中" : @"等待中";
    } else if (self.operationPending && self.activeSpeaker >= 0) {
        leftAction = self.activeSpeaker == 0 ? @"正在启动…" : @"点击发言";
        rightAction = self.activeSpeaker == 1 ? @"正在启动…" : @"点击发言";
    }
    [self.leftSpeakButton setTitle:[NSString stringWithFormat:@"左侧 %@\n%@ → %@", leftAction, leftName, rightName] forState:UIControlStateNormal];
    [self.rightSpeakButton setTitle:[NSString stringWithFormat:@"右侧 %@\n%@ → %@", rightAction, rightName, leftName] forState:UIControlStateNormal];

    self.leftSpeakButton.alpha = self.leftSpeakButton.enabled ? 1.0 : 0.35;
    self.rightSpeakButton.alpha = self.rightSpeakButton.enabled ? 1.0 : 0.35;
    self.leftSpeakButton.layer.borderColor = UIColor.whiteColor.CGColor;
    self.rightSpeakButton.layer.borderColor = UIColor.whiteColor.CGColor;
    self.leftSpeakButton.layer.borderWidth = self.recordState == ThingAudioRecordStateOngoing && self.activeSpeaker == 0 ? 3.0 : 0;
    self.rightSpeakButton.layer.borderWidth = self.recordState == ThingAudioRecordStateOngoing && self.activeSpeaker == 1 ? 3.0 : 0;

    if (self.operationPending) {
        self.statusLabel.text = @"正在切换发言状态…";
    } else if (self.recordState == ThingAudioRecordStateOngoing) {
        self.statusLabel.text = self.activeSpeaker == 0
            ? @"左侧正在发言；点击左侧暂停后，可选择下一位发言方"
            : @"右侧正在发言；点击右侧暂停后，可选择下一位发言方";
    } else if (self.recordState == ThingAudioRecordStatePaused) {
        self.statusLabel.text = @"本轮发言已结束，请点击任一侧继续";
    } else {
        self.statusLabel.text = @"点击左侧或右侧开始发言";
    }
}

#pragma mark - Listener

- (void)bindListenerToDeviceId:(NSString *)deviceId {
    if (deviceId.length == 0 || [self.listenerDeviceId isEqualToString:deviceId]) return;
    [self unbindListener];
    [[NativeAudioService sharedInstance] addRecordListener:self deviceId:deviceId];
    self.listenerDeviceId = deviceId;
}

- (void)unbindListener {
    if (self.listenerDeviceId.length == 0) return;
    [[NativeAudioService sharedInstance] removeRecordListener:self deviceId:self.listenerDeviceId];
    self.listenerDeviceId = nil;
}

- (void)record:(NSString *)deviceId didFinishWithError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.sessionDeviceIds removeObject:deviceId];
        if (self.endingSession) return;
        self.operationPending = NO;
        self.recordState = ThingAudioRecordStateFinish;
        self.activeSpeaker = -1;
        self.activeDeviceId = nil;
        [self.activeSentenceKeyBySpeaker removeAllObjects];
        [self updateControls];
        if (error) {
            [self showFamilyMessageWithTitle:@"对话异常结束" message:error.localizedDescription ?: @"未知错误"];
        }
    });
}

- (void)record:(NSString *)deviceId didUpdateStatus:(ThingAudioRecordStatus *)status {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.endingSession) return;
        self.recordState = status.state;
        self.operationPending = status.isStarting || status.isPausing || status.isStoping;
        if (status.state == ThingAudioRecordStatePaused || status.state == ThingAudioRecordStateFinish) {
            self.activeSpeaker = -1;
        }
        if (status.state == ThingAudioRecordStateFinish) {
            [self.sessionDeviceIds removeObject:deviceId];
            self.activeDeviceId = nil;
            [self.activeSentenceKeyBySpeaker removeAllObjects];
        }
        [self updateControls];
    });
}

- (void)record:(NSString *)deviceId onProcessResult:(ThingAudioRecordProcessResult *)result {
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL recognitionPhase = result.phase == ThingAudioRecordProcessPhaseAsr || result.phase == ThingAudioRecordProcessPhaseText;
        if (!recognitionPhase && result.text.length == 0 && result.translateText.length == 0) return;

        NSString *resultKey = [self resultKeyForProcessResult:result];
        if (resultKey.length == 0) return;

        NSString *mappedKey = self.bubbleKeyByResultKey[resultKey];
        NSInteger speaker = mappedKey.length > 0 && self.speakerByKey[mappedKey]
            ? self.speakerByKey[mappedKey].integerValue
            : self.activeSpeaker;
        if (mappedKey.length == 0 && (result.channel == 0 || result.channel == 1)) speaker = result.channel;
        if (speaker != 0 && speaker != 1) speaker = 0;
        NSString *key = [self bubbleKeyForResultKey:resultKey speaker:speaker];
        [self associateProcessResult:result withBubbleKey:key];
        [self ensureBubbleForKey:key speaker:speaker];

        if (recognitionPhase && result.text.length > 0) {
            self.asrLabels[key].text = result.text;
            self.asrLabels[key].textColor = self.familyPrimaryTextColor;
            [self.recognizedSentenceKeys addObject:key];
        }
        if (result.translateText.length > 0) {
            self.translationLabels[key].text = result.translateText;
            self.translationLabels[key].textColor = speaker == 0 ? UIColor.systemBlueColor : UIColor.systemOrangeColor;
        }
        [self updateTTSPlaybackButtons];

        BOOL recognitionCancelled = recognitionPhase && result.status == ThingAudioRecordProcessStatusCancel;
        BOOL recognizedSentenceEnded = recognitionPhase &&
            result.status == ThingAudioRecordProcessStatusEnd &&
            [self.recognizedSentenceKeys containsObject:key];
        if (recognitionCancelled || recognizedSentenceEnded) {
            NSNumber *speakerKey = @(speaker);
            if ([self.activeSentenceKeyBySpeaker[speakerKey] isEqualToString:key]) {
                [self.activeSentenceKeyBySpeaker removeObjectForKey:speakerKey];
            }
        }
        [self scrollConversationToBottom];
    });
}

- (NSString *)resultKeyForProcessResult:(ThingAudioRecordProcessResult *)result {
    NSString *requestKey = nil;
    if (result.requestId.length > 0) {
        requestKey = [NSString stringWithFormat:@"%@-%d", result.requestId, result.channel];
        if (self.bubbleKeyByResultKey[requestKey]) return requestKey;
    }
    NSString *asrKey = nil;
    if (result.asrId != 0) {
        asrKey = [NSString stringWithFormat:@"%lld-%d", result.asrId, result.channel];
        if (self.bubbleKeyByResultKey[asrKey]) return asrKey;
    }
    return requestKey ?: asrKey ?: self.currentTurnKey;
}

- (NSString *)bubbleKeyForResultKey:(NSString *)resultKey speaker:(NSInteger)speaker {
    NSString *mappedKey = self.bubbleKeyByResultKey[resultKey];
    if (mappedKey.length > 0) return mappedKey;

    NSNumber *speakerKey = @(speaker);
    NSString *activeKey = self.activeSentenceKeyBySpeaker[speakerKey];
    NSString *bubbleKey = activeKey.length > 0 ? activeKey : resultKey;
    self.bubbleKeyByResultKey[resultKey] = bubbleKey;
    if (activeKey.length == 0) self.activeSentenceKeyBySpeaker[speakerKey] = bubbleKey;
    return bubbleKey;
}

- (void)associateProcessResult:(ThingAudioRecordProcessResult *)result withBubbleKey:(NSString *)bubbleKey {
    ThingAudioRecordAsrResult *sentence = self.sentenceByBubbleKey[bubbleKey];
    if (!sentence) {
        sentence = [[ThingAudioRecordAsrResult alloc] init];
        self.sentenceByBubbleKey[bubbleKey] = sentence;
    }
    if (result.recordId.length > 0) sentence.recordId = result.recordId;
    if (result.requestId.length > 0) sentence.requestId = result.requestId;
    if (result.asrId > 0) sentence.asrId = result.asrId;
    sentence.channel = result.channel;
    if (result.requestId.length > 0) {
        NSString *requestKey = [NSString stringWithFormat:@"%@-%d", result.requestId, result.channel];
        self.bubbleKeyByResultKey[requestKey] = bubbleKey;
    }
    if (result.asrId != 0) {
        NSString *asrKey = [NSString stringWithFormat:@"%lld-%d", result.asrId, result.channel];
        self.bubbleKeyByResultKey[asrKey] = bubbleKey;
    }
}

- (void)ensureBubbleForKey:(NSString *)key speaker:(NSInteger)speaker {
    if (self.asrLabels[key]) return;
    self.emptyConversationLabel.hidden = YES;
    self.speakerByKey[key] = @(speaker);

    NSString *sourceLanguage = speaker == 0 ? self.leftLanguage : self.rightLanguage;
    NSString *targetLanguage = speaker == 0 ? self.rightLanguage : self.leftLanguage;
    UIColor *accent = speaker == 0 ? UIColor.systemBlueColor : UIColor.systemOrangeColor;

    UILabel *header = [[UILabel alloc] init];
    header.text = [NSString stringWithFormat:@"%@ · %@ → %@", speaker == 0 ? @"左侧" : @"右侧", [self displayNameForLanguage:sourceLanguage], [self displayNameForLanguage:targetLanguage]];
    header.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    header.textColor = accent;

    UILabel *asr = [[UILabel alloc] init];
    asr.text = @"正在识别…";
    asr.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    asr.textColor = UIColor.secondaryLabelColor;
    asr.numberOfLines = 0;

    UILabel *translation = [[UILabel alloc] init];
    translation.text = @"正在翻译…";
    translation.font = [UIFont systemFontOfSize:15];
    translation.textColor = UIColor.secondaryLabelColor;
    translation.numberOfLines = 0;

    UIButton *ttsButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [ttsButton setImage:[UIImage systemImageNamed:@"speaker.wave.2.fill"] forState:UIControlStateNormal];
    ttsButton.tintColor = accent;
    ttsButton.accessibilityLabel = @"播放此消息的 TTS";
    ttsButton.accessibilityHint = @"需开启 TTS，并选择仅缓存或播放并缓存";
    [ttsButton.widthAnchor constraintEqualToConstant:44].active = YES;
    [ttsButton.heightAnchor constraintEqualToConstant:44].active = YES;
    __weak typeof(self) weakSelf = self;
    [ttsButton addAction:[UIAction actionWithHandler:^(__kindof UIAction *action) {
        [weakSelf playTTSForBubbleKey:key];
    }] forControlEvents:UIControlEventTouchUpInside];
    self.ttsButtons[key] = ttsButton;

    UIStackView *translationRow = [[UIStackView alloc] initWithArrangedSubviews:@[translation, ttsButton]];
    translationRow.axis = UILayoutConstraintAxisHorizontal;
    translationRow.alignment = UIStackViewAlignmentTop;
    translationRow.spacing = 6;

    UIStackView *texts = [[UIStackView alloc] initWithArrangedSubviews:@[header, asr, translationRow]];
    texts.axis = UILayoutConstraintAxisVertical;
    texts.spacing = 6;
    texts.translatesAutoresizingMaskIntoConstraints = NO;

    UIView *bubble = [[UIView alloc] init];
    bubble.backgroundColor = [accent colorWithAlphaComponent:0.10];
    bubble.layer.cornerRadius = 14;
    [bubble addSubview:texts];
    [NSLayoutConstraint activateConstraints:@[
        [texts.topAnchor constraintEqualToAnchor:bubble.topAnchor constant:12],
        [texts.leadingAnchor constraintEqualToAnchor:bubble.leadingAnchor constant:14],
        [texts.trailingAnchor constraintEqualToAnchor:bubble.trailingAnchor constant:-14],
        [texts.bottomAnchor constraintEqualToAnchor:bubble.bottomAnchor constant:-12],
    ]];

    UIView *spacer = [[UIView alloc] init];
    UIStackView *row = speaker == 0
        ? [[UIStackView alloc] initWithArrangedSubviews:@[bubble, spacer]]
        : [[UIStackView alloc] initWithArrangedSubviews:@[spacer, bubble]];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.spacing = 32;
    [bubble.widthAnchor constraintLessThanOrEqualToAnchor:row.widthAnchor multiplier:0.84].active = YES;
    [self.conversationStack addArrangedSubview:row];

    self.asrLabels[key] = asr;
    self.translationLabels[key] = translation;
}

#pragma mark - Message TTS playback

- (void)updateTTSPlaybackButtons {
    BOOL enabled = !self.operationPending && self.recordState != ThingAudioRecordStateOngoing;
    for (NSString *key in self.ttsButtons) {
        UIButton *button = self.ttsButtons[key];
        button.enabled = enabled;
        BOOL playing = [self.playingBubbleKey isEqualToString:key];
        [button setImage:[UIImage systemImageNamed:playing ? @"stop.fill" : @"speaker.wave.2.fill"] forState:UIControlStateNormal];
        button.accessibilityLabel = playing ? @"停止此消息的 TTS" : @"播放此消息的 TTS";
    }
}

- (void)playTTSForBubbleKey:(NSString *)key {
    if (self.operationPending || self.recordState == ThingAudioRecordStateOngoing) return;
    if ([self.playingBubbleKey isEqualToString:key]) {
        [self stopTTSPlayback];
        return;
    }
    [self stopTTSPlayback];
    ThingAudioRecordAsrResult *identity = self.sentenceByBubbleKey[key];
    if (identity.recordId.length == 0 || (identity.requestId.length == 0 && identity.asrId <= 0)) {
        [self showFamilyMessageWithTitle:@"暂无 TTS 缓存" message:@"该消息尚未取得分句记录，请等待识别和翻译完成后重试。"];
        return;
    }
    NSString *token = NSUUID.UUID.UUIDString;
    self.ttsRequestToken = token;
    __weak typeof(self) weakSelf = self;
    [[NativeAudioService sharedInstance] fetchTTSSentencesWithRecordId:identity.recordId success:^(NSArray<ThingAudioRecordAsrResult *> *list) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || ![self.ttsRequestToken isEqualToString:token]) return;
        self.ttsRequestToken = nil;
        if (self.operationPending || self.recordState == ThingAudioRecordStateOngoing) return;
        for (ThingAudioRecordAsrResult *sentence in list) {
            if (![sentence.recordId isEqualToString:identity.recordId] || sentence.channel != identity.channel) continue;
            if (identity.asrId > 0 && sentence.asrId != identity.asrId) continue;
            if (identity.requestId.length > 0 && ![sentence.requestId isEqualToString:identity.requestId]) continue;
            [self playTTSAtPath:sentence.ttsPath bubbleKey:key];
            return;
        }
        [self showFamilyMessageWithTitle:@"暂无 TTS 缓存"
                                message:@"该消息尚未生成完整缓存，或录制时未开启缓存。请开启该侧 TTS 并选择“仅缓存”或“播放并缓存”；刚结束的句子可稍后重试。"];
    } failure:^(NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || ![self.ttsRequestToken isEqualToString:token]) return;
        self.ttsRequestToken = nil;
        [self showFamilyMessageWithTitle:@"读取 TTS 失败" message:error.localizedDescription];
    }];
}

- (BOOL)currentTTSOutputMatches:(ThingAudioTTSOutput)output {
    for (AVAudioSessionPortDescription *port in AVAudioSession.sharedInstance.currentRoute.outputs) {
        if (output == ThingAudioTTSOutput_SYSTEM_MIC && [port.portType isEqualToString:AVAudioSessionPortBuiltInSpeaker]) return YES;
        if (output == ThingAudioTTSOutput_SYSTEM_BLUETOOTH &&
            ([port.portType isEqualToString:AVAudioSessionPortBluetoothA2DP] ||
             [port.portType isEqualToString:AVAudioSessionPortBluetoothHFP] ||
             [port.portType isEqualToString:AVAudioSessionPortBluetoothLE])) return YES;
    }
    return NO;
}

- (BOOL)prepareTTSOutput:(ThingAudioTTSOutput)output error:(NSError **)error {
    AVAudioSession *session = AVAudioSession.sharedInstance;
    BOOL supportsPlayback = [session.category isEqualToString:AVAudioSessionCategoryPlayAndRecord] ||
                            [session.category isEqualToString:AVAudioSessionCategoryPlayback];
    // 手机麦克风 + 蓝牙 TTS 已由 SDK 配好路由时，切换类别可能触发 561017449。
    if (supportsPlayback && [self currentTTSOutputMatches:output]) return YES;
    self.previousAudioInput = session.preferredInput;
    self.previousAudioOutputOverride = [session.currentRoute.outputs.firstObject.portType isEqualToString:AVAudioSessionPortBuiltInSpeaker]
        ? AVAudioSessionPortOverrideSpeaker : AVAudioSessionPortOverrideNone;
    self.ttsChangedAudioRoute = YES;
    if (output == ThingAudioTTSOutput_SYSTEM_BLUETOOTH &&
        [session.category isEqualToString:AVAudioSessionCategoryPlayAndRecord]) {
        if (![session overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:error]) return NO;
        if ([self currentTTSOutputMatches:output]) return YES;
    }
    // 蓝牙回听使用 Playback，避免 SDK 在 PlayAndRecord 下重新施加上一侧的扬声器偏好。
    NSString *category = output == ThingAudioTTSOutput_SYSTEM_MIC
        ? AVAudioSessionCategoryPlayAndRecord : AVAudioSessionCategoryPlayback;
    // 只在路由需要时修改类别；可播放的 SDK 会话不重复激活。
    if (![category isEqualToString:session.category]) {
        self.previousAudioCategory = session.category;
        self.previousAudioMode = session.mode;
        self.previousAudioOptions = session.categoryOptions;
        if (![session setCategory:category mode:AVAudioSessionModeDefault options:0 error:error]) return NO;
    }
    if (!supportsPlayback) {
        if (![session setActive:YES error:error]) return NO;
        self.ttsActivatedAudioSession = YES;
    }
    if ([session.category isEqualToString:AVAudioSessionCategoryPlayAndRecord]) {
        if (![session overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:error]) return NO;
    }
    if ([self currentTTSOutputMatches:output]) return YES;
    if (error) {
        *error = [NSError errorWithDomain:@"FaceToFaceTTSPlayback" code:1 userInfo:@{
            NSLocalizedDescriptionKey: output == ThingAudioTTSOutput_SYSTEM_BLUETOOTH
                ? @"未能切换到蓝牙输出，请确认耳机已连接并在系统中选为音频输出后重试。"
                : @"未能切换到手机扬声器，请稍后重试。"
        }];
    }
    return NO;
}

- (void)playTTSAtPath:(NSString *)path bubbleKey:(NSString *)key {
    NSNumber *speaker = self.speakerByKey[key];
    ThingAudioTTSOutput output = [self audioConfigForSpeaker:speaker.integerValue].ttsOutput;
    if (!speaker || output == ThingAudioTTSOutput_DEFAULT) {
        [self showFamilyMessageWithTitle:@"请选择 TTS 输出" message:@"请先设置该消息所属侧的 TTS 输出设备。"];
        return;
    }
    if (output == ThingAudioTTSOutput_DEVICE) {
        [self showFamilyMessageWithTitle:@"暂不支持设备直传回听" message:@"当前 SDK 未提供历史 TTS 文件的设备直传接口。请将该侧输出设为系统蓝牙或手机扬声器后回听。"];
        return;
    }
    if (![NSFileManager.defaultManager isReadableFileAtPath:path]) {
        [self showFamilyMessageWithTitle:@"缓存文件不可用" message:@"该消息的 TTS 文件已被清理或无法读取。"];
        return;
    }
    NSError *error = nil;
    AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path] error:&error];
    if (!player) {
        [self showFamilyMessageWithTitle:@"TTS 加载失败" message:error.localizedDescription];
        return;
    }
    if (![self prepareTTSOutput:output error:&error]) {
        [self stopTTSPlayback];
        [self showFamilyMessageWithTitle:@"无法播放 TTS" message:error.localizedDescription];
        return;
    }
    player.delegate = self;
    self.ttsPlayer = player;
    self.playingBubbleKey = key;
    self.playingTTSOutput = output;
    if (![player play]) {
        [self stopTTSPlayback];
        [self showFamilyMessageWithTitle:@"TTS 播放失败" message:@"无法播放该消息的缓存音频，请稍后重试。"];
        return;
    }
    [self updateTTSPlaybackButtons];
}

- (void)stopTTSPlayback {
    self.ttsRequestToken = nil;
    [self.ttsPlayer stop];
    self.ttsPlayer = nil;
    self.playingBubbleKey = nil;
    AVAudioSession *session = AVAudioSession.sharedInstance;
    if (self.previousAudioCategory) {
        if (self.ttsActivatedAudioSession) {
            [session setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
        }
        [session setCategory:self.previousAudioCategory mode:self.previousAudioMode options:self.previousAudioOptions error:nil];
        self.previousAudioCategory = nil;
        self.previousAudioMode = nil;
    }
    if (self.ttsChangedAudioRoute && [session.category isEqualToString:AVAudioSessionCategoryPlayAndRecord]) {
        [session setPreferredInput:self.previousAudioInput error:nil];
        [session overrideOutputAudioPort:self.previousAudioOutputOverride error:nil];
    }
    self.ttsActivatedAudioSession = NO;
    self.ttsChangedAudioRoute = NO;
    self.previousAudioInput = nil;
    [self updateTTSPlaybackButtons];
}

- (void)ttsAudioRouteChanged:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.ttsPlayer.isPlaying || [self currentTTSOutputMatches:self.playingTTSOutput]) return;
        [self stopTTSPlayback];
        [self showFamilyMessageWithTitle:@"TTS 播放已停止" message:@"音频输出已变化，请确认该侧输出设备后重新播放。"];
    });
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    if (player == self.ttsPlayer) [self stopTTSPlayback];
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error {
    if (player != self.ttsPlayer) return;
    [self stopTTSPlayback];
    [self showFamilyMessageWithTitle:@"TTS 解码失败" message:error.localizedDescription];
}

- (void)audioSessionInterrupted:(NSNotification *)notification {
    if ([notification.userInfo[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue] != AVAudioSessionInterruptionTypeBegan) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self stopTTSPlayback];
    });
}

- (void)scrollConversationToBottom {
    [self.conversationScrollView layoutIfNeeded];
    CGFloat offsetY = MAX(0, self.conversationScrollView.contentSize.height - self.conversationScrollView.bounds.size.height);
    [self.conversationScrollView setContentOffset:CGPointMake(0, offsetY) animated:YES];
}

@end
