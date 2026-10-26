#import "EmotionChatViewController.h"
#import "EmotionVoiceInput.h"
#import <AVFoundation/AVFoundation.h>

@implementation EmotionAgentConfiguration
- (instancetype)init {
    self = [super init];
    if (self) { _roleIds = @{}; }
    return self;
}
@end

@interface EmotionChatMessage : NSObject
@property (nonatomic, copy) NSString *text;
@property (nonatomic, strong, nullable) NSURL *audioURL;
@property (nonatomic, assign) NSTimeInterval duration;
@end
@implementation EmotionChatMessage
@end

@interface EmotionChatViewController () <UITextViewDelegate>
@property (nonatomic, copy) NSArray<NSDictionary<NSString *, NSString *> *> *roles;
@property (nonatomic, assign) NSUInteger roleIndex;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray<EmotionChatMessage *> *> *conversations;
@property (nonatomic, strong) EmotionVoiceInput *voiceInput;
@property (nonatomic, strong) UIButton *roleButton;
@property (nonatomic, strong) UILabel *roleDescription;
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
@end

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
    [self configureFamilyNavigationWithTitle:@"情绪树洞" leftTitle:@"" leftAction:nil rightTitle:@"清空" rightAction:^{ [weakSelf clearConversation]; }];
    self.familyNavigationRightButton.accessibilityLabel = @"清空当前角色的本地聊天";
    [self.familyNavigationRightButton setTitleColor:self.accentColor forState:UIControlStateNormal];
    [self buildPage];
    [self buildRecordingOverlay];
    [self renderConversation];
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    [center addObserver:self selector:@selector(keyboardChanged:) name:UIKeyboardWillChangeFrameNotification object:nil];
    [center addObserver:self selector:@selector(applicationInactive:) name:UIApplicationWillResignActiveNotification object:nil];
    [center addObserver:self selector:@selector(audioInterrupted:) name:AVAudioSessionInterruptionNotification object:nil];
    [center addObserver:self selector:@selector(audioRouteChanged:) name:AVAudioSessionRouteChangeNotification object:nil];
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
    [_meterTimer invalidate];
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
    self.roleButton = [self button:@"" symbol:@"leaf.fill" action:@selector(selectRole)];
    self.roleButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    self.roleButton.titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightSemibold];
    self.roleButton.accessibilityIdentifier = @"emotion.role";
    self.roleDescription = [self label:@"" size:13 weight:UIFontWeightRegular color:self.mutedColor];
    UIStackView *roleStack = [self stack:@[self.roleButton, self.roleDescription] axis:UILayoutConstraintAxisVertical spacing:0];
    roleStack.layoutMargins = UIEdgeInsetsMake(8, 18, 14, 18);
    roleStack.layoutMarginsRelativeArrangement = YES;
    roleStack.backgroundColor = self.mintColor;
    roleStack.layer.cornerRadius = 22;

    UILabel *modeLabel = [self label:@"体验模式 · 智能体待接入" size:12 weight:UIFontWeightMedium color:self.mutedColor];
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
    self.recordingHint = [self label:@"松开后可试听、校对文字\n向上滑动取消" size:15 weight:UIFontWeightRegular color:self.mutedColor];
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
    [self.roleButton setTitle:[NSString stringWithFormat:@"  %@  ⌄", role[@"name"]] forState:UIControlStateNormal];
    [self.roleButton setImage:[UIImage systemImageNamed:role[@"symbol"]] forState:UIControlStateNormal];
    self.roleButton.accessibilityLabel = [NSString stringWithFormat:@"当前角色%@，切换角色", role[@"name"]];
    self.roleDescription.text = role[@"description"];
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
        bubble.backgroundColor = self.mintColor;
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
        UILabel *status = [self label:@"待发送 · 智能体尚未接入" size:12 weight:UIFontWeightRegular color:self.mutedColor];
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
        [actions addObject:[FamilyUIAction actionWithTitle:[NSString stringWithFormat:@"%@ · %@", role[@"name"], role[@"description"]] handler:^{
            [weakSelf stopPlayback];
            weakSelf.roleIndex = index;
            weakSelf.textInput.text = @"";
            [weakSelf textViewDidChange:weakSelf.textInput];
            weakSelf.feedbackLabel.hidden = YES;
            [weakSelf renderConversation];
        }]];
    }];
    [self showFamilyActionSheetWithTitle:@"选择陪伴角色" message:@"当前为本地角色预览，各角色的消息单独保留。" actions:actions];
}

- (void)clearConversation {
    if (self.voiceInput.isRecording || self.permissionPending) { return; }
    __weak typeof(self) weakSelf = self;
    [self showFamilyConfirmationWithTitle:@"清空这段聊天？" message:@"当前角色的本地消息与录音将删除，其他角色不受影响。" confirmTitle:@"清空" destructive:YES confirm:^{
        typeof(self) self = weakSelf;
        [self stopPlayback];
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
    EmotionChatMessage *message = [EmotionChatMessage new];
    message.text = text;
    [self.currentMessages addObject:message];
    self.textInput.text = @"";
    [self textViewDidChange:self.textInput];
    [self renderConversation];
    [self showFeedback:@"已保留在本页；接入智能体后才能获得回复。"];
}

#pragma mark - Input and recording

- (void)toggleInputMode {
    if (self.voiceInput.isRecording || self.permissionPending) { return; }
    self.textMode = !self.textMode;
    self.recordButton.hidden = self.textMode;
    self.textInput.hidden = !self.textMode;
    self.sendButton.hidden = !self.textMode;
    [self.modeButton setImage:[UIImage systemImageNamed:self.textMode ? @"mic.fill" : @"keyboard"] forState:UIControlStateNormal];
    self.modeButton.accessibilityLabel = self.textMode ? @"切换为语音输入" : @"切换为文字输入";
    self.inputHint.text = self.textMode ? @"消息仅保留在当前页面" : @"按住录音，上滑取消 · 最长 60 秒";
    if (self.textMode) { [self.textInput becomeFirstResponder]; }
    else { [self.view endEditing:YES]; }
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
        if (self.voiceInput.isRecording) { [self finishRecordingCancelled:self.cancelOnRelease]; }
    } else if (gesture.state == UIGestureRecognizerStateCancelled || gesture.state == UIGestureRecognizerStateFailed) {
        if (self.voiceInput.isRecording || self.permissionPending) { [self cancelActiveRecording]; }
    }
}

- (void)accessibleRecordTap {
    if (!UIAccessibilityIsVoiceOverRunning()) {
        [self showFeedback:@"请按住说话，松开后可以试听和校对。"];
        return;
    }
    if (self.voiceInput.isRecording) { [self finishRecordingCancelled:NO]; }
    else { [self beginRecordingRequiringHold:NO]; }
}

- (void)beginRecordingRequiringHold:(BOOL)requiresHold {
    if (self.pendingURL || self.permissionPending || self.voiceInput.isRecording) { return; }
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
        NSError *error = nil;
        if (![self.voiceInput startRecording:&error]) {
            [self showFeedback:error.localizedDescription ?: @"无法开始录音，请重试。"];
            return;
        }
        self.recordingOverlay.hidden = NO;
        self.roleButton.enabled = NO;
        self.modeButton.enabled = NO;
        [self setFamilyNavigationRightEnabled:NO];
        for (NSUInteger index = 0; index < self.levels.count; index++) { self.levels[index] = @0; }
        self.recordingRoute.text = [NSString stringWithFormat:@"正在使用：%@", self.voiceInput.inputName];
        [self updateRecordingAppearance];
        [self updateMeter];
        self.meterTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 repeats:YES block:^(NSTimer *timer) { [weakSelf updateMeter]; }];
        [[NSRunLoop mainRunLoop] addTimer:self.meterTimer forMode:NSRunLoopCommonModes];
        [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];
        UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, @"开始录音，再次双击完成。" );
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
    if (!self.voiceInput.isRecording) { return; }
    UIColor *color = self.cancelOnRelease ? UIColor.systemRedColor : self.accentColor;
    self.recordingTitle.text = self.cancelOnRelease ? @"松开，取消这段录音" : @"正在听你说";
    self.recordingTitle.textColor = self.cancelOnRelease ? UIColor.systemRedColor : self.inkColor;
    self.recordingHint.text = self.cancelOnRelease ? @"移回按钮，继续录音" : @"松开后可试听、校对文字\n向上滑动取消";
    self.recordButton.backgroundColor = color;
    [self.recordButton setTitle:self.cancelOnRelease ? @"松开取消" : @"松开完成" forState:UIControlStateNormal];
}

- (void)updateMeter {
    if (!self.voiceInput.isRecording) { return; }
    NSTimeInterval duration = self.voiceInput.duration;
    self.recordingTime.text = [NSString stringWithFormat:@"00:%02ld / 01:00", (long)floor(duration)];
    [self.levels removeObjectAtIndex:0];
    [self.levels addObject:@(self.voiceInput.level)];
    [self.meterHeights enumerateObjectsUsingBlock:^(NSLayoutConstraint *height, NSUInteger index, BOOL *stop) {
        height.constant = 6 + MIN(1, self.levels[index].floatValue) * 72;
    }];
    if (duration >= 60) { [self finishRecordingCancelled:self.cancelOnRelease]; }
}

- (void)finishRecordingCancelled:(BOOL)cancelled {
    NSTimeInterval duration = self.voiceInput.duration;
    if (cancelled || duration < 0.7) {
        [self.voiceInput cancelRecording];
        [self resetRecordingUI];
        [self showFeedback:cancelled ? @"录音已取消。" : @"说话时间太短，请按住再说一次。"];
        return;
    }
    self.pendingURL = [self.voiceInput finishRecording];
    self.pendingDuration = duration;
    [self resetRecordingUI];
    self.reviewPanel.hidden = NO;
    self.inputRow.hidden = YES;
    self.inputHint.hidden = YES;
    self.reviewText.text = @"";
    self.reviewText.editable = NO;
    self.reviewStatus.text = @"正在转成文字，可先试听…";
    self.reviewSendButton.enabled = NO;
    self.recordButton.enabled = NO;
    self.recognizing = YES;
    NSUInteger generation = ++self.operationGeneration;
    __weak typeof(self) weakSelf = self;
    [self.voiceInput transcribeURL:self.pendingURL completion:^(NSString *text, NSError *error) {
        typeof(self) self = weakSelf;
        if (!self || generation != self.operationGeneration || !self.pendingURL) { return; }
        self.recognizing = NO;
        self.reviewText.text = text;
        self.reviewText.editable = YES;
        self.reviewStatus.text = error ? error.localizedDescription : (text.length ? @"识别完成，文字可以修改" : @"没有识别到文字，可以补充或保留语音");
        self.reviewSendButton.enabled = YES;
        UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, self.reviewStatus.text);
    }];
    [self textViewDidChange:self.textInput];
    [self scrollToLatest];
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
    EmotionChatMessage *message = [EmotionChatMessage new];
    message.audioURL = self.pendingURL;
    message.duration = self.pendingDuration;
    message.text = [self.reviewText.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    [self.currentMessages addObject:message];
    self.pendingURL = nil;
    [self discardPendingAudio];
    [self renderConversation];
    [self showFeedback:@"语音已保留在本页；智能体尚未接入。"];
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
    if (self.voiceInput.isRecording) {
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
            if (self.voiceInput.isRecording) {
                [self cancelActiveRecording];
                [self showFeedback:@"音频设备已断开，录音已取消，请重新录制。"];
            }
            [self stopPlayback];
        });
    }
}

- (void)keyboardChanged:(NSNotification *)notification {
    if (!self.view.window) { return; }
    CGRect screenFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect frame = [self.view convertRect:screenFrame fromView:nil];
    CGFloat safeBottom = CGRectGetMaxY(self.view.bounds) - self.view.safeAreaInsets.bottom;
    BOOL overlapsHorizontally = CGRectGetMinX(frame) < CGRectGetMaxX(self.view.bounds) && CGRectGetMaxX(frame) > 0;
    self.composerBottom.constant = overlapsHorizontally ? -MAX(0, safeBottom - CGRectGetMinY(frame)) : 0;
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
