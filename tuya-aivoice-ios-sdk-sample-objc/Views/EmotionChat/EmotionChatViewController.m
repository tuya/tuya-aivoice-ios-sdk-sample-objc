#import "EmotionChatViewController.h"
#import "EmotionVoiceInput.h"
#import "EmotionAgentDiagnostics.h"
#import "EmotionAIStreamService.h"
#import <ThingSmartDeviceKit/ThingSmartDeviceKit.h>
#import <AVFoundation/AVFoundation.h>

@implementation EmotionAgentConfiguration
- (instancetype)init {
    self = [super init];
    if (self) {
        _roleIds = @{};
        _useDeviceIdentity = NO;
        _ttsEnabled = YES;
    }
    return self;
}
@end

@interface EmotionChatMessage : NSObject
@property (nonatomic, copy) NSString *text;
@property (nonatomic, strong, nullable) NSURL *audioURL;
@property (nonatomic, assign) NSTimeInterval duration;
@property (nonatomic, assign) BOOL assistant;
@property (nonatomic, assign) BOOL pending;
@property (nonatomic, copy, nullable) NSString *status;
@end
@implementation EmotionChatMessage
@end

@interface EmotionChatViewController () <UITextViewDelegate, UIGestureRecognizerDelegate>
@property (nonatomic, copy) NSArray<NSDictionary *> *roles;
@property (nonatomic, assign) NSUInteger roleIndex;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray<EmotionChatMessage *> *> *conversations;
@property (nonatomic, strong) EmotionVoiceInput *voiceInput;
@property (nonatomic, strong) UIButton *roleButton;
@property (nonatomic, strong) UIButton *roleDetailButton;
@property (nonatomic, strong) UILabel *emotionLabel;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *messagesStack;
@property (nonatomic, strong) UIStackView *composer;
@property (nonatomic, strong) UIStackView *inputRow;
@property (nonatomic, strong) UIButton *modeButton;
@property (nonatomic, strong) UIButton *recordButton;
@property (nonatomic, strong) UITextView *textInput;
@property (nonatomic, strong) UILabel *textPlaceholder;
@property (nonatomic, strong) UIButton *sendButton;
@property (nonatomic, strong) UILabel *inputHint;
@property (nonatomic, strong) UILabel *feedbackLabel;
@property (nonatomic, strong) UIView *recordingOverlay;
@property (nonatomic, strong) UILabel *recordingTitle;
@property (nonatomic, strong) UILabel *recordingTime;
@property (nonatomic, strong) UILabel *recordingHint;
@property (nonatomic, strong) UILabel *recordingRoute;
@property (nonatomic, strong) NSMutableArray<NSLayoutConstraint *> *meterHeights;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *levels;
@property (nonatomic, strong) NSTimer *meterTimer;
@property (nonatomic, strong) UILongPressGestureRecognizer *recordGesture;
@property (nonatomic, assign) BOOL cancelOnRelease;
@property (nonatomic, assign) BOOL permissionPending;
@property (nonatomic, assign) BOOL textMode;
@property (nonatomic, assign) NSUInteger operationGeneration;
@property (nonatomic, strong) NSLayoutConstraint *composerBottom;
@property (nonatomic, assign) CGFloat keyboardOverlap;
@property (nonatomic, strong) NSLayoutConstraint *textHeight;
@property (nonatomic, strong) UIStackView *reviewPanel;
@property (nonatomic, strong) UILabel *reviewStatus;
@property (nonatomic, strong) UITextView *reviewText;
@property (nonatomic, strong) UIButton *reviewPlayButton;
@property (nonatomic, strong) UIButton *reviewSendButton;
@property (nonatomic, strong, nullable) NSURL *pendingURL;
@property (nonatomic, assign) NSTimeInterval pendingDuration;
@property (nonatomic, assign) BOOL recognizing;
@property (nonatomic, strong, nullable) NSURL *playingURL;
@property (nonatomic, weak, nullable) UIButton *playingButton;
@property (nonatomic, strong) EmotionAgentDiagnostics *agentDiagnostics;
@property (nonatomic, assign) BOOL didQueryAgentConfiguration;
@property (nonatomic, strong, nullable) EmotionAIStreamService *aiStreamService;
@property (nonatomic, strong, nullable) EmotionChatMessage *streamingAssistantMessage;
@property (nonatomic, strong, nullable) EmotionChatMessage *activeVoiceMessage;
@end

static NSDictionary *EmotionAgentResponsePayload(NSDictionary *entry) {
    id response = entry[@"response"];
    if ([response isKindOfClass:NSDictionary.class] && response[@"result"] != nil) {
        response = response[@"result"];
    }
    return [response isKindOfClass:NSDictionary.class] ? response : nil;
}

static NSString *EmotionAgentDisplayEmotion(NSDictionary *emotion) {
    if (![emotion[@"emotionOpen"] boolValue]) { return @"心情展示已关闭"; }
    NSString *text = [emotion[@"text"] isKindOfClass:NSString.class] ? emotion[@"text"] : nil;
    if (text.length) { return [NSString stringWithFormat:@"当前心情 · %@", text]; }
    NSString *value = [emotion[@"emotion"] isKindOfClass:NSString.class] ? emotion[@"emotion"] : nil;
    NSDictionary *names = @{@"HAPPY": @"开心", @"SAD": @"低落", @"ANGRY": @"生气", @"CALM": @"平静", @"DEFAULT": @"默认"};
    if (!value.length && [emotion[@"url"] isKindOfClass:NSString.class] && [emotion[@"url"] length]) {
        return @"当前心情 · 默认表情";
    }
    return [NSString stringWithFormat:@"当前心情 · %@", names[value] ?: (value.length ? value : @"默认")];
}

static NSString *EmotionAgentShortText(NSString *text, NSUInteger maxLength) {
    if (text.length <= maxLength) { return text ?: @""; }
    return [[text substringToIndex:maxLength] stringByAppendingString:@"…"];
}

@implementation EmotionChatViewController

- (UIColor *)accentColor { return [UIColor colorWithRed:0.13 green:0.37 blue:0.31 alpha:1]; }
- (UIColor *)mintColor { return [UIColor colorWithRed:0.88 green:0.94 blue:0.90 alpha:1]; }
- (UIColor *)inkColor { return [UIColor colorWithRed:0.16 green:0.21 blue:0.19 alpha:1]; }
- (UIColor *)mutedColor { return [UIColor colorWithRed:0.36 green:0.41 blue:0.38 alpha:1]; }

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.97 green:0.97 blue:0.95 alpha:1];
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
    self.agentConfiguration = self.agentConfiguration ?: [EmotionAgentConfiguration new];
    self.roles = @[
        @{@"key": @"autumn", @"name": @"知秋", @"symbol": @"leaf.fill", @"description": @"温柔倾听，陪你慢慢理清思绪", @"greeting": @"最近有什么放在心里的事？\n不必组织好语言，从你想说的地方开始。"},
        @{@"key": @"ocean", @"name": @"听澜", @"symbol": @"water.waves", @"description": @"安静陪伴，给情绪一点空间", @"greeting": @"今天的心情是什么样的？\n你可以慢慢说，也可以先停一会儿。"},
        @{@"key": @"sunshine", @"name": @"暖阳", @"symbol": @"sun.max.fill", @"description": @"轻松聊聊，发现生活里的小小暖意", @"greeting": @"今天有没有一个瞬间，让你想找人聊聊？\n开心的、烦心的，都可以放在这里。"},
    ];
    self.conversations = [NSMutableDictionary dictionary];
    self.voiceInput = [EmotionVoiceInput new];
    __weak typeof(self) weakSelf = self;
    self.voiceInput.recordingFailureHandler = ^(NSError *error) {
        [weakSelf resetRecordingUI];
        [weakSelf showFeedback:error.localizedDescription];
    };
    [self configureFamilyNavigationWithTitle:@"情绪树洞" leftTitle:@"" leftAction:nil rightTitle:nil rightAction:nil];
#if DEBUG
    if (self.agentConfiguration.deviceId.length) {
        [self configureFamilyNavigationWithTitle:@"情绪树洞" leftTitle:@"配置" leftAction:^{ [weakSelf queryAgentConfiguration]; }
                                      rightTitle:nil rightAction:nil];
    }
#endif
    self.familyNavigationRightButton.hidden = NO;
    self.familyNavigationRightButton.accessibilityIdentifier = @"emotion.tts";
    self.familyNavigationRightButton.accessibilityLabel = @"TTS 播放";
    [self.familyNavigationRightButton addTarget:self action:@selector(toggleTTS) forControlEvents:UIControlEventTouchUpInside];
    [self updateTTSNavigationButton];
    [self buildPage];
    [self buildRecordingOverlay];
    [self renderConversation];
    UITapGestureRecognizer *backgroundTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    backgroundTap.cancelsTouchesInView = NO;
    backgroundTap.delegate = self;
    [self.view addGestureRecognizer:backgroundTap];
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    [center addObserver:self selector:@selector(keyboardChanged:) name:UIKeyboardWillChangeFrameNotification object:nil];
    [center addObserver:self selector:@selector(keyboardChanged:) name:UIKeyboardWillShowNotification object:nil];
    [center addObserver:self selector:@selector(keyboardChanged:) name:UIKeyboardWillHideNotification object:nil];
    [center addObserver:self selector:@selector(applicationInactive:) name:UIApplicationWillResignActiveNotification object:nil];
    [center addObserver:self selector:@selector(audioInterrupted:) name:AVAudioSessionInterruptionNotification object:nil];
    [center addObserver:self selector:@selector(audioRouteChanged:) name:AVAudioSessionRouteChangeNotification object:nil];
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
    [_meterTimer invalidate];
    [_aiStreamService stop];
}

- (void)updateTTSNavigationButton {
    BOOL enabled = self.agentConfiguration.ttsEnabled;
    UIImage *image = [UIImage systemImageNamed:enabled ? @"speaker.wave.2.fill" : @"speaker.slash.fill"];
    [self.familyNavigationRightButton setImage:image forState:UIControlStateNormal];
    [self.familyNavigationRightButton setTitle:@"" forState:UIControlStateNormal];
    self.familyNavigationRightButton.accessibilityValue = enabled ? @"已开启" : @"已关闭";
}

- (void)toggleTTS {
    if (self.aiStreamService.isRecording || self.permissionPending) {
        return;
    }
    self.agentConfiguration.ttsEnabled = !self.agentConfiguration.ttsEnabled;
    if (self.aiStreamService) {
        [self.aiStreamService stop];
        self.aiStreamService = nil;
    }
    [self updateTTSNavigationButton];
    [self showFeedback:self.agentConfiguration.ttsEnabled ? @"已开启 AI 语音播放。" : @"已关闭 AI 语音播放。"];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
#if DEBUG
    if (!self.didQueryAgentConfiguration && self.agentConfiguration.deviceId.length) {
        [self queryAgentConfiguration];
    }
#endif
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (self.keyboardOverlap > 0) {
        self.composerBottom.constant = -self.keyboardOverlap;
    }
}

- (void)queryAgentConfiguration {
    [self.view endEditing:YES];
    if (self.agentDiagnostics.isRunning) {
        [self showFeedback:@"正在查询测试设备的智能体配置，请稍候。"];
        return;
    }
    self.didQueryAgentConfiguration = YES;
    self.agentDiagnostics = self.agentDiagnostics ?: [EmotionAgentDiagnostics new];
    [self showFeedback:@"正在通过接口查询智能体配置…"];
    __weak typeof(self) weakSelf = self;
    [self.agentDiagnostics fetchDeviceId:self.agentConfiguration.deviceId ?: @""
                              productId:self.agentConfiguration.productId ?: @""
                             completion:^(NSDictionary<NSString *, NSDictionary *> *report) {
        [weakSelf applyAgentConfigurationReport:report];
    }];
}

- (void)applyAgentConfigurationReport:(NSDictionary<NSString *, NSDictionary *> *)report {
    NSDictionary *initializedEntry = report[@"initializedRole"];
    NSDictionary *templateEntry = report[@"roleTemplates"];
    NSDictionary *emotionEntry = report[@"currentEmotion"];
    NSDictionary *initializedRole = EmotionAgentResponsePayload(initializedEntry);
    id templateResponse = templateEntry[@"response"];
    if ([templateResponse isKindOfClass:NSDictionary.class] && templateResponse[@"result"] != nil) {
        templateResponse = templateResponse[@"result"];
    }
    NSArray *templates = [templateResponse isKindOfClass:NSArray.class] ? templateResponse : nil;
    NSDictionary *emotion = EmotionAgentResponsePayload(emotionEntry);
    if (emotion) {
        self.emotionLabel.text = EmotionAgentDisplayEmotion(emotion);
        self.emotionLabel.hidden = NO;
    }
    if (templates.count) {
        NSMutableArray<NSDictionary *> *cloudRoles = [NSMutableArray arrayWithCapacity:templates.count];
        for (NSDictionary *template in templates) {
            if (![template isKindOfClass:NSDictionary.class]) { continue; }
            NSString *roleId = [template[@"roleId"] description];
            NSString *name = [template[@"roleName"] description];
            if (!roleId.length || !name.length) { continue; }
            NSString *overview = [template[@"roleOverview"] isKindOfClass:NSString.class] ? template[@"roleOverview"] : @"云端智能体角色";
            NSString *introduce = [template[@"roleIntroduce"] isKindOfClass:NSString.class] ? template[@"roleIntroduce"] : overview;
            NSMutableDictionary *role = [@{
                @"key": roleId,
                @"roleId": roleId,
                @"name": name,
                @"symbol": @"person.crop.circle.fill",
                @"description": overview,
                @"greeting": [NSString stringWithFormat:@"我是%@，可以陪你聊聊此刻的心情。", name],
                @"roleIntroduce": introduce,
                @"roleOverview": overview,
                @"details": template,
            } mutableCopy];
            if ([template[@"defaultFlag"] boolValue]) { role[@"isDefault"] = @YES; }
            [cloudRoles addObject:role];
        }
        if (initializedRole.count) {
            NSString *currentRoleId = [initializedRole[@"roleId"] description];
            NSUInteger currentIndex = [cloudRoles indexOfObjectPassingTest:^BOOL(NSDictionary *role, NSUInteger idx, BOOL *stop) {
                return [role[@"roleId"] isEqualToString:currentRoleId];
            }];
            if (currentIndex != NSNotFound) {
                NSMutableDictionary *currentRole = [cloudRoles[currentIndex] mutableCopy];
                currentRole[@"isCurrent"] = @YES;
                currentRole[@"details"] = initializedRole;
                currentRole[@"roleIntroduce"] = initializedRole[@"roleIntroduce"] ?: currentRole[@"roleIntroduce"];
                currentRole[@"description"] = initializedRole[@"roleOverview"] ?: currentRole[@"description"];
                cloudRoles[currentIndex] = currentRole;
                self.roleIndex = currentIndex;
            }
        }
        if (self.roleIndex >= cloudRoles.count || ![cloudRoles[self.roleIndex][@"isCurrent"] boolValue]) {
            NSUInteger defaultIndex = [cloudRoles indexOfObjectPassingTest:^BOOL(NSDictionary *role, NSUInteger idx, BOOL *stop) {
                return [role[@"isDefault"] boolValue];
            }];
            if (defaultIndex != NSNotFound) { self.roleIndex = defaultIndex; }
        }
        if (cloudRoles.count) {
            self.roles = cloudRoles;
            if (self.roleIndex >= self.roles.count) { self.roleIndex = 0; }
            [self renderConversation];
        }
    }
    NSArray<NSString *> *queryNames = @[@"initializedRole", @"roleTemplates", @"currentEmotion"];
    NSMutableArray<NSString *> *failures = [NSMutableArray array];
    NSDictionary *displayNames = @{@"initializedRole": @"角色初始化", @"roleTemplates": @"角色模板", @"currentEmotion": @"当前心情"};
    for (NSString *name in queryNames) {
        NSDictionary *entry = report[name];
        if ([entry[@"success"] boolValue]) { continue; }
        NSString *reason = entry[@"message"] ?: entry[@"reason"] ?: @"请求失败";
        NSNumber *code = entry[@"code"];
        NSString *suffix = code ? [NSString stringWithFormat:@"（错误码 %@）", code] : @"";
        NSString *apiName = [entry[@"apiName"] isKindOfClass:NSString.class] ? entry[@"apiName"] : @"未知接口";
        [failures addObject:[NSString stringWithFormat:@"%@ [%@] %@：%@", displayNames[name], apiName, suffix, reason]];
    }
    NSDictionary *project = report[@"project"];
    if (failures.count) {
        [self showFeedback:[NSString stringWithFormat:@"接口失败：%@。控制台筛选 EmotionAgentConfig。", [failures componentsJoinedByString:@"；"]]];
    } else if ([project[@"status"] isEqualToString:@"unsupported"]) {
        [self showFeedback:[NSString stringWithFormat:@"配置完成：当前角色%@，角色模板%lu个；方案查询接口暂不支持。",
                            self.roles[self.roleIndex][@"name"], (unsigned long)self.roles.count]];
    } else {
        [self showFeedback:@"智能体配置已更新。"];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.operationGeneration += 1;
    [self cancelActiveRecording];
    [self stopPlayback];
    if (self.recognizing) {
        [self.voiceInput cancelTranscription];
        self.recognizing = NO;
        self.reviewText.editable = YES;
        self.reviewStatus.text = @"转写已暂停，可补充文字或保留语音";
        self.reviewSendButton.enabled = YES;
    }
    [self.view endEditing:YES];
}

- (UILabel *)label:(NSString *)text size:(CGFloat)size weight:(UIFontWeight)weight color:(UIColor *)color {
    UILabel *label = [UILabel new];
    label.text = text;
    label.font = [UIFont systemFontOfSize:size weight:weight];
    label.adjustsFontForContentSizeCategory = YES;
    label.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:label.font maximumPointSize:size + 7];
    label.textColor = color;
    label.numberOfLines = 0;
    return label;
}

- (UIButton *)button:(NSString *)title symbol:(NSString *)symbol action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:self.accentColor forState:UIControlStateNormal];
    if (symbol) { [button setImage:[UIImage systemImageNamed:symbol] forState:UIControlStateNormal]; }
    button.tintColor = self.accentColor;
    button.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    button.contentEdgeInsets = UIEdgeInsetsMake(10, 12, 10, 12);
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [button.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
    return button;
}

- (UIStackView *)stack:(NSArray<UIView *> *)views axis:(UILayoutConstraintAxis)axis spacing:(CGFloat)spacing {
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:views];
    stack.axis = axis;
    stack.spacing = spacing;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    return stack;
}

- (void)buildPage {
    self.roleButton = [self button:@"" symbol:@"chevron.down" action:@selector(selectRole)];
    self.roleButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    self.roleButton.titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightSemibold];
    self.roleButton.accessibilityIdentifier = @"emotion.role";
    self.roleButton.accessibilityHint = @"点击切换陪伴角色";
    self.roleDetailButton = [self button:@"查看详情" symbol:nil action:@selector(showCurrentRoleDetails)];
    self.roleDetailButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    self.roleDetailButton.accessibilityIdentifier = @"emotion.roleDetails";
    self.emotionLabel = [self label:@"当前心情 · 默认" size:12 weight:UIFontWeightMedium color:self.accentColor];
    self.emotionLabel.hidden = YES;
    UIStackView *roleHeader = [self stack:@[self.roleButton, self.roleDetailButton] axis:UILayoutConstraintAxisHorizontal spacing:8];
    roleHeader.alignment = UIStackViewAlignmentCenter;
    [self.roleButton setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [self.roleDetailButton setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.roleDetailButton setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    UIStackView *roleStack = [self stack:@[roleHeader, self.emotionLabel] axis:UILayoutConstraintAxisVertical spacing:4];
    roleStack.layoutMargins = UIEdgeInsetsMake(8, 18, 14, 18);
    roleStack.layoutMarginsRelativeArrangement = YES;
    roleStack.backgroundColor = self.mintColor;
    roleStack.layer.cornerRadius = 22;

    NSString *modeText = self.agentConfiguration.solutionCode.length > 0 ? @"已接入智能体 · 随时倾听你的心声" : @"体验模式 · 智能体待接入";
    UILabel *modeLabel = [self label:modeText size:12 weight:UIFontWeightMedium color:self.mutedColor];
    modeLabel.textAlignment = NSTextAlignmentCenter;
    self.scrollView = [UIScrollView new];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.scrollView.alwaysBounceVertical = YES;
    self.messagesStack = [self stack:@[] axis:UILayoutConstraintAxisVertical spacing:20];
    [self.scrollView addSubview:self.messagesStack];
    self.composer = [self stack:@[] axis:UILayoutConstraintAxisVertical spacing:8];
    self.composer.layoutMargins = UIEdgeInsetsMake(10, 16, 8, 16);
    self.composer.layoutMarginsRelativeArrangement = YES;
    self.composer.backgroundColor = self.view.backgroundColor;
    [self buildComposer];
    [self.view addSubview:roleStack];
    modeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:modeLabel];
    [self.view addSubview:self.scrollView];
    [self.view addSubview:self.composer];
    self.composerBottom = [self.composer.bottomAnchor constraintEqualToAnchor:self.familyContentGuide.bottomAnchor];
    [NSLayoutConstraint activateConstraints:@[
        [roleStack.topAnchor constraintEqualToAnchor:self.familyContentGuide.topAnchor constant:12],
        [roleStack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [roleStack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [modeLabel.topAnchor constraintEqualToAnchor:roleStack.bottomAnchor constant:12],
        [modeLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [modeLabel.widthAnchor constraintLessThanOrEqualToAnchor:self.view.widthAnchor constant:-40],
        [self.scrollView.topAnchor constraintEqualToAnchor:modeLabel.bottomAnchor constant:10],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.composer.topAnchor],
        [self.messagesStack.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor constant:22],
        [self.messagesStack.leadingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor constant:20],
        [self.messagesStack.trailingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor constant:-20],
        [self.messagesStack.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor constant:-20],
        [self.messagesStack.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor constant:-40],
        [self.composer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.composer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        self.composerBottom,
    ]];
}

- (void)buildComposer {
    self.feedbackLabel = [self label:@"" size:13 weight:UIFontWeightMedium color:self.accentColor];
    self.feedbackLabel.accessibilityIdentifier = @"emotion.feedback";
    self.feedbackLabel.hidden = YES;
    [self.composer addArrangedSubview:self.feedbackLabel];
    [self buildReviewPanel];
    [self.composer addArrangedSubview:self.reviewPanel];
    self.modeButton = [self button:@"" symbol:@"keyboard" action:@selector(toggleInputMode)];
    self.modeButton.accessibilityLabel = @"切换为文字输入";
    self.modeButton.accessibilityIdentifier = @"emotion.inputMode";
    [self.modeButton.widthAnchor constraintEqualToConstant:48].active = YES;
    self.recordButton = [self button:@"按住说话" symbol:@"mic.fill" action:@selector(accessibleRecordTap)];
    self.recordButton.backgroundColor = self.accentColor;
    [self.recordButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.recordButton.tintColor = UIColor.whiteColor;
    self.recordButton.layer.cornerRadius = 24;
    self.recordButton.accessibilityIdentifier = @"emotion.record";
    self.recordButton.accessibilityHint = @"按住开始录音，向上滑动取消。旁白模式下双击开始，再次双击完成。";
    self.recordGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(recordGestureChanged:)];
    self.recordGesture.minimumPressDuration = 0.15;
    self.recordGesture.allowableMovement = CGFLOAT_MAX;
    [self.recordButton addGestureRecognizer:self.recordGesture];

    self.textInput = [UITextView new];
    self.textInput.delegate = self;
    self.textInput.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    self.textInput.adjustsFontForContentSizeCategory = YES;
    self.textInput.backgroundColor = UIColor.whiteColor;
    self.textInput.textColor = self.inkColor;
    self.textInput.tintColor = self.accentColor;
    self.textInput.layer.cornerRadius = 18;
    self.textInput.textContainerInset = UIEdgeInsetsMake(12, 12, 12, 12);
    self.textInput.accessibilityLabel = @"想说的话";
    self.textInput.accessibilityIdentifier = @"emotion.textInput";
    self.textInput.hidden = YES;
    self.textPlaceholder = [self label:@"说说此刻的心情…" size:15 weight:UIFontWeightRegular color:self.mutedColor];
    self.textPlaceholder.userInteractionEnabled = NO;
    self.textPlaceholder.translatesAutoresizingMaskIntoConstraints = NO;
    [self.textInput addSubview:self.textPlaceholder];
    [NSLayoutConstraint activateConstraints:@[
        [self.textPlaceholder.leadingAnchor constraintEqualToAnchor:self.textInput.leadingAnchor constant:16],
        [self.textPlaceholder.topAnchor constraintEqualToAnchor:self.textInput.topAnchor constant:13],
    ]];
    self.sendButton = [self button:@"" symbol:@"arrow.up" action:@selector(sendText)];
    self.sendButton.backgroundColor = self.accentColor;
    self.sendButton.tintColor = UIColor.whiteColor;
    self.sendButton.layer.cornerRadius = 22;
    self.sendButton.accessibilityLabel = @"发送文字";
    self.sendButton.accessibilityIdentifier = @"emotion.sendText";
    self.sendButton.hidden = YES;
    self.sendButton.enabled = NO;
    [self.sendButton.widthAnchor constraintEqualToConstant:44].active = YES;
    self.inputRow = [self stack:@[self.modeButton, self.recordButton, self.textInput, self.sendButton] axis:UILayoutConstraintAxisHorizontal spacing:8];
    self.inputRow.alignment = UIStackViewAlignmentCenter;
    [self.recordButton.heightAnchor constraintEqualToConstant:50].active = YES;
    self.textHeight = [self.textInput.heightAnchor constraintEqualToConstant:48];
    self.textHeight.active = YES;
    [self.composer addArrangedSubview:self.inputRow];
    self.inputHint = [self label:@"按住录音，上滑取消 · 最长 60 秒" size:12 weight:UIFontWeightRegular color:self.mutedColor];
    self.inputHint.textAlignment = NSTextAlignmentCenter;
    [self.composer addArrangedSubview:self.inputHint];
}

- (void)buildReviewPanel {
    UILabel *title = [self label:@"发送前，再听一听" size:16 weight:UIFontWeightSemibold color:self.inkColor];
    self.reviewStatus = [self label:@"正在转成文字…" size:12 weight:UIFontWeightRegular color:self.mutedColor];
    self.reviewText = [UITextView new];
    self.reviewText.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    self.reviewText.adjustsFontForContentSizeCategory = YES;
    self.reviewText.textColor = self.inkColor;
    self.reviewText.backgroundColor = UIColor.clearColor;
    self.reviewText.tintColor = self.accentColor;
    self.reviewText.accessibilityLabel = @"语音转写，可编辑";
    self.reviewText.accessibilityIdentifier = @"emotion.reviewText";
    [self.reviewText.heightAnchor constraintEqualToConstant:76].active = YES;
    self.reviewPlayButton = [self button:@"试听" symbol:@"play.fill" action:@selector(playPendingAudio)];
    self.reviewPlayButton.accessibilityIdentifier = @"emotion.previewAudio";
    UIButton *discard = [self button:@"重录" symbol:nil action:@selector(discardPendingAudio)];
    discard.accessibilityIdentifier = @"emotion.discardAudio";
    self.reviewSendButton = [self button:@"发送" symbol:@"arrow.up" action:@selector(sendPendingAudio)];
    self.reviewSendButton.accessibilityIdentifier = @"emotion.sendAudio";
    UIView *spacer = [UIView new];
    UIStackView *actions = [self stack:@[self.reviewPlayButton, discard, spacer, self.reviewSendButton] axis:UILayoutConstraintAxisHorizontal spacing:4];
    [self.reviewPlayButton setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [discard setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.reviewSendButton setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    self.reviewPanel = [self stack:@[title, self.reviewStatus, self.reviewText, actions] axis:UILayoutConstraintAxisVertical spacing:6];
    self.reviewPanel.backgroundColor = UIColor.whiteColor;
    self.reviewPanel.layer.cornerRadius = 20;
    self.reviewPanel.layoutMargins = UIEdgeInsetsMake(16, 16, 8, 16);
    self.reviewPanel.layoutMarginsRelativeArrangement = YES;
    self.reviewPanel.hidden = YES;
}

- (void)buildRecordingOverlay {
    self.recordingOverlay = [UIView new];
    self.recordingOverlay.backgroundColor = [self.view.backgroundColor colorWithAlphaComponent:0.97];
    self.recordingOverlay.translatesAutoresizingMaskIntoConstraints = NO;
    self.recordingOverlay.hidden = YES;
    [self.view addSubview:self.recordingOverlay];
    self.recordingTitle = [self label:@"正在听你说" size:24 weight:UIFontWeightSemibold color:self.inkColor];
    self.recordingTime = [self label:@"00:00" size:24 weight:UIFontWeightMedium color:self.accentColor];
    self.recordingTime.font = [UIFont monospacedDigitSystemFontOfSize:24 weight:UIFontWeightMedium];
    self.recordingTime.accessibilityElementsHidden = YES;
    self.recordingHint = [self label:@"松开后直接发送语音\n向上滑动取消" size:15 weight:UIFontWeightRegular color:self.mutedColor];
    self.recordingRoute = [self label:@"" size:12 weight:UIFontWeightRegular color:self.mutedColor];
    UIStackView *meter = [self stack:@[] axis:UILayoutConstraintAxisHorizontal spacing:4];
    meter.alignment = UIStackViewAlignmentCenter;
    meter.distribution = UIStackViewDistributionFillEqually;
    meter.accessibilityElementsHidden = YES;
    self.meterHeights = [NSMutableArray array];
    self.levels = [NSMutableArray array];
    for (NSUInteger index = 0; index < 24; index++) {
        UIView *bar = [UIView new];
        bar.backgroundColor = self.accentColor;
        bar.layer.cornerRadius = 2;
        [meter addArrangedSubview:bar];
        NSLayoutConstraint *height = [bar.heightAnchor constraintEqualToConstant:6];
        height.active = YES;
        [self.meterHeights addObject:height];
        [self.levels addObject:@0];
    }
    [meter.heightAnchor constraintEqualToConstant:84].active = YES;
    [meter.widthAnchor constraintEqualToConstant:236].active = YES;
    UIStackView *content = [self stack:@[self.recordingTitle, self.recordingTime, meter, self.recordingHint, self.recordingRoute] axis:UILayoutConstraintAxisVertical spacing:20];
    content.alignment = UIStackViewAlignmentCenter;
    self.recordingHint.textAlignment = NSTextAlignmentCenter;
    self.recordingRoute.textAlignment = NSTextAlignmentCenter;
    [self.recordingOverlay addSubview:content];
    [NSLayoutConstraint activateConstraints:@[
        [self.recordingOverlay.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor],
        [self.recordingOverlay.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.recordingOverlay.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.recordingOverlay.bottomAnchor constraintEqualToAnchor:self.composer.topAnchor],
        [content.centerXAnchor constraintEqualToAnchor:self.recordingOverlay.centerXAnchor],
        [content.centerYAnchor constraintEqualToAnchor:self.recordingOverlay.centerYAnchor],
        [content.widthAnchor constraintLessThanOrEqualToAnchor:self.recordingOverlay.widthAnchor constant:-40],
    ]];
}

#pragma mark - Conversation and roles

- (NSMutableArray<EmotionChatMessage *> *)currentMessages {
    NSString *key = self.roles[self.roleIndex][@"key"];
    if (!self.conversations[key]) { self.conversations[key] = [NSMutableArray array]; }
    return self.conversations[key];
}

- (void)renderConversation {
    NSDictionary *role = self.roles[self.roleIndex];
    [self.roleButton setTitle:[NSString stringWithFormat:@"  %@", role[@"name"]] forState:UIControlStateNormal];
    [self.roleButton setImage:[UIImage systemImageNamed:role[@"symbol"]] forState:UIControlStateNormal];
    self.roleButton.accessibilityLabel = [NSString stringWithFormat:@"当前角色%@，切换角色", role[@"name"]];
    self.roleDetailButton.accessibilityLabel = [NSString stringWithFormat:@"查看%@详情", role[@"name"]];
    for (UIView *view in self.messagesStack.arrangedSubviews) {
        [self.messagesStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }
    UILabel *welcome = [self label:@"在这里，慢慢说。" size:28 weight:UIFontWeightSemibold color:self.inkColor];
    welcome.accessibilityTraits |= UIAccessibilityTraitHeader;
    UILabel *greeting = [self label:role[@"greeting"] size:16 weight:UIFontWeightRegular color:self.mutedColor];
    [self.messagesStack addArrangedSubview:[self stack:@[welcome, greeting] axis:UILayoutConstraintAxisVertical spacing:12]];
    if (self.currentMessages.count == 0) {
        for (NSString *suggestion in @[@"最近工作有些累", @"有一件事，我一直放不下"]) {
            UIButton *button = [self button:suggestion symbol:@"plus.bubble" action:@selector(useSuggestion:)];
            button.backgroundColor = UIColor.whiteColor;
            button.layer.cornerRadius = 18;
            button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
            button.titleLabel.numberOfLines = 0;
            [self.messagesStack addArrangedSubview:button];
        }
    }
    for (EmotionChatMessage *message in self.currentMessages) {
        UIStackView *bubble = [self stack:@[] axis:UILayoutConstraintAxisVertical spacing:10];
        bubble.backgroundColor = message.assistant ? UIColor.whiteColor : self.mintColor;
        bubble.layer.cornerRadius = 20;
        bubble.layoutMargins = UIEdgeInsetsMake(14, 16, 14, 16);
        bubble.layoutMarginsRelativeArrangement = YES;
        if (message.audioURL) {
            UIButton *audio = [self button:[NSString stringWithFormat:@"语音 · %.0f 秒", ceil(message.duration)] symbol:@"play.fill" action:@selector(playMessageAudio:)];
            audio.tag = [self.currentMessages indexOfObject:message];
            audio.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
            audio.accessibilityLabel = [NSString stringWithFormat:@"播放语音，%.0f秒", ceil(message.duration)];
            [bubble addArrangedSubview:audio];
        }
        if (message.text.length) { [bubble addArrangedSubview:[self label:message.text size:16 weight:UIFontWeightRegular color:self.inkColor]]; }
        NSString *statusText = message.assistant ? (message.pending ? @"智能体回复中…" : @"智能体") : (message.status ?: @"已发送");
        UILabel *status = [self label:statusText size:12 weight:UIFontWeightRegular color:self.mutedColor];
        [bubble addArrangedSubview:status];
        UIView *row = [UIView new];
        [row addSubview:bubble];
        [NSLayoutConstraint activateConstraints:@[
            [bubble.topAnchor constraintEqualToAnchor:row.topAnchor],
            [bubble.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
            [bubble.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
            [bubble.leadingAnchor constraintGreaterThanOrEqualToAnchor:row.leadingAnchor constant:28],
            [bubble.widthAnchor constraintGreaterThanOrEqualToConstant:200],
        ]];
        [self.messagesStack addArrangedSubview:row];
    }
    [self scrollToLatest];
}

- (void)selectRole {
    [self.view endEditing:YES];
    if (self.pendingURL) {
        [self showFeedback:@"请先发送这段语音，或点“重录”放弃后切换角色。"];
        return;
    }
    NSMutableArray *actions = [NSMutableArray array];
    __weak typeof(self) weakSelf = self;
    [self.roles enumerateObjectsUsingBlock:^(NSDictionary *role, NSUInteger index, BOOL *stop) {
        NSString *title = index == self.roleIndex
            ? [NSString stringWithFormat:@"%@（当前）", role[@"name"]]
            : role[@"name"];
        [actions addObject:[FamilyUIAction actionWithTitle:title handler:^{
            if (index != weakSelf.roleIndex) { [weakSelf selectRoleAtIndex:index]; }
        }]];
    }];
    [self showFamilyActionSheetWithTitle:@"切换陪伴角色" message:@"点击角色名称即可切换。" actions:actions];
}

- (void)showCurrentRoleDetails {
    [self showRoleDetailsAtIndex:self.roleIndex];
}

- (void)showRoleDetailsAtIndex:(NSUInteger)index {
    if (index >= self.roles.count) { return; }
    NSDictionary *role = self.roles[index];
    NSMutableString *message = [NSMutableString string];
    NSString *overview = role[@"roleOverview"] ?: role[@"description"];
    if (overview.length) { [message appendFormat:@"%@\n\n", overview]; }
    NSString *introduce = role[@"roleIntroduce"];
    if (introduce.length && ![introduce isEqualToString:overview]) { [message appendString:introduce]; }
    NSDictionary *details = role[@"details"];
    if ([details isKindOfClass:NSDictionary.class]) {
        NSString *language = details[@"useLangName"];
        NSString *timbre = details[@"useTimbreName"];
        if (language.length || timbre.length) {
            [message appendFormat:@"\n\n语言：%@\n音色：%@", language ?: @"未设置", timbre ?: @"未设置"];
        }
    }
    NSMutableArray<FamilyUIAction *> *actions = [NSMutableArray array];
    __weak typeof(self) weakSelf = self;
    if (index != self.roleIndex) {
        [actions addObject:[FamilyUIAction actionWithTitle:@"使用这个角色" handler:^{ [weakSelf selectRoleAtIndex:index]; }]];
    }
    [self showFamilyActionSheetWithTitle:role[@"name"] message:EmotionAgentShortText(message, 1800) actions:actions];
}

- (void)selectRoleAtIndex:(NSUInteger)index {
    if (index >= self.roles.count) { return; }
    [self stopPlayback];
    [self.aiStreamService stop];
    self.aiStreamService = nil;
    self.streamingAssistantMessage = nil;
    self.activeVoiceMessage = nil;
    self.roleIndex = index;
    self.textInput.text = @"";
    [self textViewDidChange:self.textInput];
    self.feedbackLabel.hidden = YES;
    [self renderConversation];
}

- (void)clearConversation {
    if (self.aiStreamService.isRecording || self.permissionPending) { return; }
    __weak typeof(self) weakSelf = self;
    [self showFamilyConfirmationWithTitle:@"清空这段聊天？" message:@"当前角色的本地消息与录音将删除，其他角色不受影响。" confirmTitle:@"清空" destructive:YES confirm:^{
        typeof(self) self = weakSelf;
        [self stopPlayback];
        [self.aiStreamService stop];
        self.aiStreamService = nil;
        self.streamingAssistantMessage = nil;
        self.activeVoiceMessage = nil;
        [self discardPendingAudio];
        for (EmotionChatMessage *message in self.currentMessages) {
            if (message.audioURL) { [self.voiceInput deleteRecording:message.audioURL]; }
        }
        [self.currentMessages removeAllObjects];
        self.textInput.text = @"";
        [self textViewDidChange:self.textInput];
        [self renderConversation];
        [self showFeedback:@"当前角色的本地聊天已清空。"];
    }];
}

- (void)useSuggestion:(UIButton *)sender {
    if (!self.textMode) { [self toggleInputMode]; }
    self.textInput.text = sender.currentTitle;
    [self textViewDidChange:self.textInput];
    [self.textInput becomeFirstResponder];
}

- (void)sendText {
    NSString *text = [self.textInput.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!text.length || self.pendingURL) { return; }
    self.streamingAssistantMessage = nil;
    EmotionChatMessage *message = [EmotionChatMessage new];
    message.text = text;
    message.status = @"发送中…";
    [self.currentMessages addObject:message];
    self.textInput.text = @"";
    [self textViewDidChange:self.textInput];
    [self renderConversation];
    [self sendTextToAgent:text userMessage:message];
}

- (void)prepareAIStreamService:(void (^)(NSError * _Nullable error))completion {
    EmotionAgentConfiguration *configuration = self.agentConfiguration;
    if (configuration.solutionCode.length == 0) {
        if (completion) completion([NSError errorWithDomain:@"emotion-chat" code:2 userInfo:@{NSLocalizedDescriptionKey: @"请在测试配置中填写 Agent ID。"}]);
        return;
    }
    __weak typeof(self) weakSelf = self;
    void (^start)(void) = ^{
        typeof(self) self = weakSelf;
        if (!self) return;
        [self.aiStreamService startWithCompletion:completion];
    };
    if (self.aiStreamService) {
        start();
        return;
    }
    [self loadHomeId:^(long long homeId, NSError *error) {
        typeof(self) self = weakSelf;
        if (!self) return;
        if (error || homeId <= 0) {
            if (completion) completion(error ?: [NSError errorWithDomain:@"emotion-chat" code:1 userInfo:@{NSLocalizedDescriptionKey: @"未找到当前家庭，无法建立 AI 通道。"}]);
            return;
        }
        long long ownerId = configuration.ownerId.longLongValue > 0 ? configuration.ownerId.longLongValue : homeId;
        NSLog(@"[EmotionAIStream] ownerId source=%@ value=%lld homeId=%lld",
              configuration.ownerId.length > 0 ? @"debug-config" : @"current-home",
              ownerId,
              homeId);
        self.aiStreamService = [[EmotionAIStreamService alloc] initWithSolutionCode:configuration.solutionCode
                                                                         miniProgramId:configuration.miniProgramId
                                                                               homeId:ownerId
                                                                            deviceId:configuration.deviceId
                                                                    useDeviceIdentity:configuration.useDeviceIdentity];
        self.aiStreamService.ttsEnabled = configuration.ttsEnabled;
        self.aiStreamService.stateHandler = ^(NSString *state, NSError *stateError) {
            if (stateError) NSLog(@"[EmotionAIStream] %@: %@", state, stateError);
            else NSLog(@"[EmotionAIStream] %@", state);
        };
        self.aiStreamService.textHandler = ^(NSString *responseText, ThingStreamPacketStreamFlag streamFlag) {
            [weakSelf appendAgentText:responseText streamFlag:streamFlag];
        };
        self.aiStreamService.eventHandler = ^(ThingStreamPacketEventType eventType) {
            if (eventType == ThingStreamPacketEventTypeEnd || eventType == ThingStreamPacketEventTypeChatBreak) {
                EmotionChatMessage *message = weakSelf.streamingAssistantMessage;
                message.pending = NO;
                [weakSelf renderConversation];
                weakSelf.streamingAssistantMessage = nil;
            }
        };
        start();
    }];
}

- (void)sendTextToAgent:(NSString *)text userMessage:(EmotionChatMessage *)userMessage {
    __weak typeof(self) weakSelf = self;
    [self prepareAIStreamService:^(NSError *error) {
        typeof(self) self = weakSelf;
        if (!self) return;
        if (error) {
            userMessage.status = @"连接失败";
            [self renderConversation];
            [self showFeedback:[NSString stringWithFormat:@"AI 通道失败：%@", error.localizedDescription ?: @"未知错误"]];
            return;
        }
        [self.aiStreamService sendText:text completion:^(NSError *sendError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (sendError) {
                    userMessage.status = @"发送失败";
                    [self renderConversation];
                    [self showFeedback:[NSString stringWithFormat:@"AI 请求失败：%@", sendError.localizedDescription ?: @"未知错误"]];
                } else {
                    userMessage.status = @"已发送";
                    [self renderConversation];
                }
            });
        }];
    }];
}

- (void)loadHomeId:(void (^)(long long homeId, NSError * _Nullable error))completion {
    ThingSmartHomeManager *manager = [ThingSmartHomeManager new];
    [manager getHomeListWithSuccess:^(NSArray<ThingSmartHomeModel *> *homes) {
        ThingSmartHomeModel *home = homes.firstObject;
        if (!home || home.homeId <= 0) {
            NSError *error = [NSError errorWithDomain:@"emotion-chat" code:1 userInfo:@{NSLocalizedDescriptionKey: @"当前账号没有可用家庭"}];
            completion(0, error);
            return;
        }
        completion(home.homeId, nil);
    } failure:^(NSError *error) {
        completion(0, error);
    }];
}

- (void)appendAgentText:(NSString *)rawText streamFlag:(ThingStreamPacketStreamFlag)streamFlag {
    if (rawText.length == 0) return;
    NSData *data = [rawText dataUsingEncoding:NSUTF8StringEncoding];
    id object = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    if (![object isKindOfClass:NSDictionary.class]) return;
    NSDictionary *json = object;
    NSString *bizType = [json[@"bizType"] isKindOfClass:NSString.class] ? json[@"bizType"] : nil;
    NSDictionary *payload = [json[@"data"] isKindOfClass:NSDictionary.class] ? json[@"data"] : nil;
    if ([bizType isEqualToString:@"ASR"]) {
        NSString *asrText = [payload[@"text"] isKindOfClass:NSString.class] ? payload[@"text"] : nil;
        if (asrText.length && self.activeVoiceMessage) {
            self.activeVoiceMessage.text = asrText;
            [self renderConversation];
        }
        return;
    }
    if (![bizType isEqualToString:@"NLG"]) return;
    NSString *content = [payload[@"content"] isKindOfClass:NSString.class] ? payload[@"content"] : nil;
    if (content.length == 0) return;
    if (!self.streamingAssistantMessage) {
        self.streamingAssistantMessage = [EmotionChatMessage new];
        self.streamingAssistantMessage.assistant = YES;
        self.streamingAssistantMessage.pending = YES;
        [self.currentMessages addObject:self.streamingAssistantMessage];
    }
    NSString *appendMode = [payload[@"appendMode"] isKindOfClass:NSString.class] ? payload[@"appendMode"] : nil;
    if ([appendMode isEqualToString:@"replace"] || streamFlag == ThingStreamPacketStreamFlagOnlyOne) {
        self.streamingAssistantMessage.text = content;
    } else {
        self.streamingAssistantMessage.text = [self.streamingAssistantMessage.text ?: @"" stringByAppendingString:content];
    }
    [self renderConversation];
}

#pragma mark - Input and recording

- (void)toggleInputMode {
    if (self.aiStreamService.isRecording || self.permissionPending) { return; }
    self.textMode = !self.textMode;
    self.recordButton.hidden = self.textMode;
    self.textInput.hidden = !self.textMode;
    self.sendButton.hidden = !self.textMode;
    [self.modeButton setImage:[UIImage systemImageNamed:self.textMode ? @"mic.fill" : @"keyboard"] forState:UIControlStateNormal];
    self.modeButton.accessibilityLabel = self.textMode ? @"切换为语音输入" : @"切换为文字输入";
    self.inputHint.text = self.textMode ? @"消息仅保留在当前页面" : @"按住录音，语音直接发送 · 最长 60 秒";
    if (self.textMode) {
        [self.view layoutIfNeeded];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.textMode && self.textInput.window) {
                [self.textInput becomeFirstResponder];
            }
        });
    } else {
        [self dismissKeyboard];
    }
}

- (void)textViewDidChange:(UITextView *)textView {
    self.textPlaceholder.hidden = self.textInput.text.length > 0;
    self.sendButton.enabled = [self.textInput.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length > 0 && !self.pendingURL;
    self.sendButton.alpha = self.sendButton.enabled ? 1 : 0.45;
    CGFloat height = [self.textInput sizeThatFits:CGSizeMake(MAX(self.textInput.bounds.size.width, 160), CGFLOAT_MAX)].height;
    self.textHeight.constant = MIN(112, MAX(48, height));
    self.textInput.scrollEnabled = height > 112;
}

- (void)recordGestureChanged:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        [self beginRecordingRequiringHold:YES];
    } else if (gesture.state == UIGestureRecognizerStateChanged) {
        self.cancelOnRelease = [gesture locationInView:self.recordButton].y < -55;
        [self updateRecordingAppearance];
    } else if (gesture.state == UIGestureRecognizerStateEnded) {
        if (self.permissionPending) {
            self.operationGeneration += 1;
            self.permissionPending = NO;
        }
        if (self.aiStreamService.isRecording) { [self finishRecordingCancelled:self.cancelOnRelease]; }
    } else if (gesture.state == UIGestureRecognizerStateCancelled || gesture.state == UIGestureRecognizerStateFailed) {
        if (self.aiStreamService.isRecording || self.permissionPending) { [self cancelActiveRecording]; }
    }
}

- (void)accessibleRecordTap {
    if (!UIAccessibilityIsVoiceOverRunning()) {
        [self showFeedback:@"请按住说话，松开后会直接发送语音。"];
        return;
    }
    if (self.aiStreamService.isRecording) { [self finishRecordingCancelled:NO]; }
    else { [self beginRecordingRequiringHold:NO]; }
}

- (void)beginRecordingRequiringHold:(BOOL)requiresHold {
    if (self.pendingURL || self.permissionPending || self.aiStreamService.isRecording) { return; }
    [self.view endEditing:YES];
    [self stopPlayback];
    self.feedbackLabel.hidden = YES;
    self.permissionPending = YES;
    self.cancelOnRelease = NO;
    NSUInteger generation = ++self.operationGeneration;
    __weak typeof(self) weakSelf = self;
    [self.voiceInput requestRecordingPermission:^(BOOL granted) {
        typeof(self) self = weakSelf;
        if (!self || generation != self.operationGeneration) { return; }
        self.permissionPending = NO;
        if (!granted) {
            [self showMicrophonePermissionHelp];
            return;
        }
        BOOL holding = self.recordGesture.state == UIGestureRecognizerStateBegan || self.recordGesture.state == UIGestureRecognizerStateChanged;
        if ((requiresHold && !holding) || !self.view.window || UIApplication.sharedApplication.applicationState != UIApplicationStateActive) { return; }
        [self prepareAIStreamService:^(NSError *error) {
            typeof(self) self = weakSelf;
            if (!self || generation != self.operationGeneration) { return; }
            if (error) {
                [self showFeedback:error.localizedDescription ?: @"无法连接 AI，请重试。"];
                return;
            }
            self.streamingAssistantMessage = nil;
            EmotionChatMessage *message = [EmotionChatMessage new];
            message.status = @"发送中…";
            [self.currentMessages addObject:message];
            self.activeVoiceMessage = message;
            [self renderConversation];
            [self.aiStreamService startAudioRecordingWithCompletion:^(NSError *startError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    typeof(self) self = weakSelf;
                    if (!self || generation != self.operationGeneration) { return; }
                    if (startError) {
                        [self.currentMessages removeObject:message];
                        if (self.activeVoiceMessage == message) { self.activeVoiceMessage = nil; }
                        [self renderConversation];
                        [self showFeedback:startError.localizedDescription ?: @"无法开始语音发送，请重试。"];
                        return;
                    }
                    self.recordingOverlay.hidden = NO;
                    self.roleButton.enabled = NO;
                    self.modeButton.enabled = NO;
                    [self setFamilyNavigationRightEnabled:NO];
                    for (NSUInteger index = 0; index < self.levels.count; index++) { self.levels[index] = @0; }
                    self.recordingRoute.text = [NSString stringWithFormat:@"正在使用：%@", AVAudioSession.sharedInstance.currentRoute.inputs.firstObject.portName ?: @"麦克风"];
                    [self updateRecordingAppearance];
                    [self updateMeter];
                    self.meterTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 repeats:YES block:^(NSTimer *timer) { [weakSelf updateMeter]; }];
                    [[NSRunLoop mainRunLoop] addTimer:self.meterTimer forMode:NSRunLoopCommonModes];
                    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];
                    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, @"开始录音，语音会直接发送给智能体。" );
                });
            }];
        }];
    }];
}

- (void)showMicrophonePermissionHelp {
    __weak typeof(self) weakSelf = self;
    [self showFamilyActionSheetWithTitle:@"需要麦克风权限" message:@"请在系统设置中允许麦克风访问；也可以切换为文字输入。" actions:@[
        [FamilyUIAction actionWithTitle:@"前往设置" handler:^{ [UIApplication.sharedApplication openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString] options:@{} completionHandler:nil]; }],
        [FamilyUIAction actionWithTitle:@"使用文字输入" handler:^{ if (!weakSelf.textMode) { [weakSelf toggleInputMode]; } }],
    ]];
}

- (void)updateRecordingAppearance {
    if (!self.aiStreamService.isRecording) { return; }
    UIColor *color = self.cancelOnRelease ? UIColor.systemRedColor : self.accentColor;
    self.recordingTitle.text = self.cancelOnRelease ? @"松开，取消这段录音" : @"正在听你说";
    self.recordingTitle.textColor = self.cancelOnRelease ? UIColor.systemRedColor : self.inkColor;
    self.recordingHint.text = self.cancelOnRelease ? @"移回按钮，继续录音" : @"松开后直接发送语音\n向上滑动取消";
    self.recordButton.backgroundColor = color;
    [self.recordButton setTitle:self.cancelOnRelease ? @"松开取消" : @"松开完成" forState:UIControlStateNormal];
}

- (void)updateMeter {
    if (!self.aiStreamService.isRecording) { return; }
    NSTimeInterval duration = self.aiStreamService.recordingDuration;
    self.recordingTime.text = [NSString stringWithFormat:@"00:%02ld / 01:00", (long)floor(duration)];
    [self.levels removeObjectAtIndex:0];
    [self.levels addObject:@(self.aiStreamService.recordingLevel)];
    [self.meterHeights enumerateObjectsUsingBlock:^(NSLayoutConstraint *height, NSUInteger index, BOOL *stop) {
        height.constant = 6 + MIN(1, self.levels[index].floatValue) * 72;
    }];
    if (duration >= 60) { [self finishRecordingCancelled:self.cancelOnRelease]; }
}

- (void)finishRecordingCancelled:(BOOL)cancelled {
    NSTimeInterval duration = self.aiStreamService.recordingDuration;
    if (cancelled || duration < 0.7) {
        [self.aiStreamService cancelAudioRecording];
        if (self.activeVoiceMessage) {
            [self.currentMessages removeObject:self.activeVoiceMessage];
            self.activeVoiceMessage = nil;
            [self renderConversation];
        }
        [self resetRecordingUI];
        [self showFeedback:cancelled ? @"录音已取消。" : @"说话时间太短，请按住再说一次。"];
        return;
    }
    [self resetRecordingUI];
    __weak typeof(self) weakSelf = self;
    [self.aiStreamService stopAudioRecordingWithCompletion:^(NSURL *audioURL, NSTimeInterval audioDuration, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            typeof(self) self = weakSelf;
            if (!self) return;
            EmotionChatMessage *message = self.activeVoiceMessage;
            if (!message) {
                message = [EmotionChatMessage new];
                [self.currentMessages addObject:message];
            }
            message.audioURL = audioURL;
            message.duration = audioDuration;
            message.status = error ? @"发送失败" : @"已发送";
            [self renderConversation];
            [self scrollToLatest];
            if (error) {
                [self showFeedback:[NSString stringWithFormat:@"语音发送失败：%@", error.localizedDescription ?: @"未知错误"]];
            }
        });
    }];
}

- (void)resetRecordingUI {
    [self.meterTimer invalidate];
    self.meterTimer = nil;
    self.recordingOverlay.hidden = YES;
    self.roleButton.enabled = YES;
    self.modeButton.enabled = YES;
    [self setFamilyNavigationRightEnabled:YES];
    self.recordButton.backgroundColor = self.accentColor;
    [self.recordButton setTitle:@"按住说话" forState:UIControlStateNormal];
    self.cancelOnRelease = NO;
}

- (void)cancelActiveRecording {
    self.operationGeneration += 1;
    self.permissionPending = NO;
    [self.aiStreamService cancelAudioRecording];
    if (self.activeVoiceMessage) {
        [self.currentMessages removeObject:self.activeVoiceMessage];
        self.activeVoiceMessage = nil;
        [self renderConversation];
    }
    [self.voiceInput cancelRecording];
    [self resetRecordingUI];
}

- (void)discardPendingAudio {
    self.operationGeneration += 1;
    [self.voiceInput cancelTranscription];
    [self stopPlayback];
    if (self.pendingURL) { [self.voiceInput deleteRecording:self.pendingURL]; }
    self.pendingURL = nil;
    self.recognizing = NO;
    self.reviewPanel.hidden = YES;
    self.inputRow.hidden = NO;
    self.inputHint.hidden = NO;
    self.recordButton.enabled = YES;
    self.reviewText.text = @"";
    [self.view endEditing:YES];
    [self textViewDidChange:self.textInput];
}

- (void)sendPendingAudio {
    if (!self.pendingURL || self.recognizing) { return; }
    NSString *text = [self.reviewText.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSURL *audioURL = self.pendingURL;
    NSTimeInterval duration = self.pendingDuration;

    self.streamingAssistantMessage = nil;
    EmotionChatMessage *message = [EmotionChatMessage new];
    message.audioURL = audioURL;
    message.duration = duration;
    message.text = text;
    message.status = @"发送中…";
    [self.currentMessages addObject:message];

    self.pendingURL = nil;
    [self discardPendingAudio];
    [self renderConversation];

    if (text.length > 0) {
        [self sendTextToAgent:text userMessage:message];
    } else {
        message.status = @"已保留语音";
        [self renderConversation];
        [self showFeedback:@"语音未识别出文字，仅保留本地音频。"];
    }
}

#pragma mark - Playback and lifecycle

- (void)playPendingAudio { if (self.pendingURL) { [self playURL:self.pendingURL button:self.reviewPlayButton]; } }

- (void)playMessageAudio:(UIButton *)sender {
    if ((NSUInteger)sender.tag < self.currentMessages.count) { [self playURL:self.currentMessages[sender.tag].audioURL button:sender]; }
}

- (void)playURL:(NSURL *)url button:(UIButton *)button {
    if ([self.playingURL isEqual:url]) { [self stopPlayback]; return; }
    [self stopPlayback];
    NSError *error = nil;
    __weak typeof(self) weakSelf = self;
    if (![self.voiceInput playURL:url completion:^{ [weakSelf stopPlayback]; } error:&error]) {
        [self showFeedback:error.localizedDescription ?: @"语音播放失败，请重试。"];
        return;
    }
    self.playingURL = url;
    self.playingButton = button;
    [button setImage:[UIImage systemImageNamed:@"stop.fill"] forState:UIControlStateNormal];
    button.accessibilityValue = @"正在播放，点按停止";
}

- (void)stopPlayback {
    [self.voiceInput stopPlayback];
    [self.playingButton setImage:[UIImage systemImageNamed:@"play.fill"] forState:UIControlStateNormal];
    self.playingButton.accessibilityValue = nil;
    self.playingURL = nil;
    self.playingButton = nil;
}

- (void)applicationInactive:(NSNotification *)notification {
    if (self.aiStreamService.isRecording) {
        [self cancelActiveRecording];
        [self showFeedback:@"录音因应用离开前台而取消，请重新录制。"];
    }
    [self stopPlayback];
}

- (void)audioInterrupted:(NSNotification *)notification {
    if ([notification.userInfo[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue] == AVAudioSessionInterruptionTypeBegan) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self applicationInactive:notification]; });
    }
}

- (void)audioRouteChanged:(NSNotification *)notification {
    AVAudioSessionRouteChangeReason reason = [notification.userInfo[AVAudioSessionRouteChangeReasonKey] unsignedIntegerValue];
    if (reason == AVAudioSessionRouteChangeReasonOldDeviceUnavailable) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.aiStreamService.isRecording) {
                [self cancelActiveRecording];
                [self showFeedback:@"音频设备已断开，录音已取消，请重新录制。"];
            }
            [self stopPlayback];
        });
    }
}

- (void)dismissKeyboard {
    [self.textInput resignFirstResponder];
    [self.reviewText resignFirstResponder];
    [self.view endEditing:YES];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if (self.aiStreamService.isRecording || self.permissionPending) { return NO; }
    for (UIView *view = touch.view; view; view = view.superview) {
        if ([view isKindOfClass:UIControl.class] || [view isKindOfClass:UITextView.class]) { return NO; }
    }
    return self.textInput.isFirstResponder || self.reviewText.isFirstResponder;
}

- (void)keyboardChanged:(NSNotification *)notification {
    CGRect screenFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    UIWindow *window = self.view.window;
    CGRect frame = screenFrame;
    if (window) {
        CGRect windowFrame = [window convertRect:screenFrame fromWindow:nil];
        frame = [self.view convertRect:windowFrame fromView:window];
    }
    CGFloat safeBottom = CGRectGetMaxY(self.view.bounds) - self.view.safeAreaInsets.bottom;
    BOOL overlapsHorizontally = CGRectGetMinX(frame) < CGRectGetMaxX(self.view.bounds) && CGRectGetMaxX(frame) > 0;
    self.keyboardOverlap = overlapsHorizontally ? MAX(0, safeBottom - CGRectGetMinY(frame)) : 0;
    self.composerBottom.constant = -self.keyboardOverlap;
    [self.view setNeedsLayout];
    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationOptions options = [notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] unsignedIntegerValue] << 16;
    [UIView animateWithDuration:duration delay:0 options:options animations:^{ [self.view layoutIfNeeded]; } completion:^(BOOL finished) { [self scrollToLatest]; }];
}

- (void)scrollToLatest {
    [self.view layoutIfNeeded];
    CGFloat offset = MAX(0, self.scrollView.contentSize.height - self.scrollView.bounds.size.height);
    [self.scrollView setContentOffset:CGPointMake(0, offset) animated:!UIAccessibilityIsReduceMotionEnabled()];
}

- (void)showFeedback:(NSString *)message {
    self.feedbackLabel.text = message;
    self.feedbackLabel.hidden = message.length == 0;
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, message);
}

@end
