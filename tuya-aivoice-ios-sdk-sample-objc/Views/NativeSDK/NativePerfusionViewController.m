//
//  NativePerfusionViewController.m
//  AIVoiceDemo
//

#import "NativePerfusionViewController.h"
#import "NativeAudioService.h"
#import "PerfusionDebuggerService.h"
#import "PerfusionWERCalculator.h"
#import "PerfusionReportBuilder.h"
#import <AVFAudio/AVFAudio.h>
#import <ThingAudioRecordInterface/ThingAudioRecordInterface.h>

/// 灌流走手机录音链路，deviceId 固定为手机麦克风约定值。
static NSString *const kPerfusionDeviceId = @"PHONE";
/// 事件日志最大保留条数。
static const NSUInteger kPerfusionMaxLogCount = 200;

/// 可选语种表：{代码, 展示名}，与录音页保持一致。
static NSArray<NSDictionary<NSString *, NSString *> *> *kPerfusionLanguages(void) {
    static dispatch_once_t once;
    static NSArray *languages = nil;
    dispatch_once(&once, ^{
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

/// 文件选择器当前的用途，回调里据此分流。
typedef NS_ENUM(NSInteger, NativePerfusionPickerPurpose) {
    NativePerfusionPickerPurposeAudio = 0,
    NativePerfusionPickerPurposeReference,
};

@interface NativePerfusionViewController () <ThingAudioRecordManagerDelegate,
                                            UIDocumentPickerDelegate>

#pragma mark 配置
/// 当前选中的灌流音频文件名（位于灌流目录下）。
@property (nonatomic, copy, nullable) NSString *selectedFileName;
/// 当前选中的参考答案文件名（位于参考答案目录下）。
@property (nonatomic, copy, nullable) NSString *selectedReferenceFileName;
/// 参考答案原文，选中文件后读入。
@property (nonatomic, copy, nullable) NSString *referenceText;
@property (nonatomic, assign) NativePerfusionPickerPurpose pickerPurpose;
@property (nonatomic, copy) NSString *selectedOriginalLanguage;
@property (nonatomic, copy) NSString *selectedTargetLanguage;

#pragma mark 视图
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) UIButton *fileButton;
@property (nonatomic, strong) UIButton *historyButton;
@property (nonatomic, strong) UIButton *referenceButton;
@property (nonatomic, strong) UIButton *referenceHistoryButton;
@property (nonatomic, strong) UILabel *referenceDetailLabel;
@property (nonatomic, strong) UILabel *werSummaryLabel;
@property (nonatomic, strong) UIButton *exportReportButton;
@property (nonatomic, strong) UILabel *fileDetailLabel;
@property (nonatomic, strong) UILabel *audioFormatLabel;
@property (nonatomic, strong) UILabel *providerLabel;
@property (nonatomic, strong) UISwitch *asrSwitch;
@property (nonatomic, strong) UISwitch *translateSwitch;
@property (nonatomic, strong) UISwitch *ttsSwitch;
@property (nonatomic, strong) UISwitch *autoStopSwitch;
@property (nonatomic, strong) UIButton *originalLanguageButton;
@property (nonatomic, strong) UIButton *targetLanguageButton;
@property (nonatomic, strong) UILabel *stateLabel;
@property (nonatomic, strong) UILabel *durationLabel;
@property (nonatomic, strong) UIButton *startButton;
@property (nonatomic, strong) UIButton *stopButton;
@property (nonatomic, strong) UITextView *asrTextView;
@property (nonatomic, strong) UITextView *translateTextView;
@property (nonatomic, strong) UITextView *logTextView;
@property (nonatomic, strong) UITextView *resultTextView;
@property (nonatomic, strong) UIButton *resultCopyButton;

#pragma mark 运行时状态
@property (nonatomic, assign) ThingAudioRecordState recordState;
@property (nonatomic, assign) BOOL operationPending;
/// 一次灌流是否仍在进行（start 成功到结果汇总之间）。
@property (nonatomic, assign) BOOL perfusionRunning;
/// 结果是否已汇总，保证灌流结束与录音结束两路回调只出一次结果。
@property (nonatomic, assign) BOOL resultSettled;
@property (nonatomic, copy, nullable) NSString *currentRecordId;
@property (nonatomic, copy, nullable) NSString *runningFileName;
@property (nonatomic, strong, nullable) NSDate *startDate;
@property (nonatomic, strong, nullable) NSTimer *durationTimer;
@property (nonatomic, assign) BOOL listenerBound;

#pragma mark 过程数据
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *asrTexts;
@property (nonatomic, strong) NSMutableArray<NSString *> *asrOrder;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *translateTexts;
@property (nonatomic, strong) NSMutableArray<NSString *> *translateOrder;
@property (nonatomic, strong) NSMutableArray<NSString *> *eventLogs;
/// 收到的 TTS 阶段回调次数，用于结果里体现 TTS 是否真的跑起来了。
@property (nonatomic, assign) NSUInteger ttsCallbackCount;
/// 最近一次结果文本，供复制按钮使用。
@property (nonatomic, copy, nullable) NSString *lastResultText;
/// 最近一次评估结果，供导出报告使用。
@property (nonatomic, strong, nullable) PerfusionWERResult *lastWERResult;
@property (nonatomic, copy, nullable) NSArray<PerfusionWERLineResult *> *lastLineResults;
@property (nonatomic, strong, nullable) PerfusionReportInput *lastReportInput;

@end

@implementation NativePerfusionViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self configureFamilyNavigationWithTitle:@"灌流调试"
                                   leftTitle:nil
                                  leftAction:nil
                                  rightTitle:nil
                                 rightAction:nil];

    self.selectedOriginalLanguage = @"zh";
    self.selectedTargetLanguage = @"en";
    self.recordState = ThingAudioRecordStateUnknown;
    self.asrTexts = [NSMutableDictionary dictionary];
    self.asrOrder = [NSMutableArray array];
    self.translateTexts = [NSMutableDictionary dictionary];
    self.translateOrder = [NSMutableArray array];
    self.eventLogs = [NSMutableArray array];

    [PerfusionDebuggerService ensureAudioFilesDirectory];
    [self setupUI];
    [self bindRecordListener];
    [self refreshFileState];
    [self refreshReferenceState];
    [self refreshProviderState];
    [self resetProcessViews];
    [self updateControls];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshFileState];
    [self refreshReferenceState];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    // 离开页面时收尾：计时器强引用 self，且灌流不应在后台继续跑。
    if (self.perfusionRunning) {
        [self stopPerfusionWithReason:@"离开灌流页"];
    }
    [self stopDurationTimer];
}

- (void)dealloc {
    [self stopDurationTimer];
    if (_listenerBound) {
        [[NativeAudioService sharedInstance] removeRecordListener:self deviceId:kPerfusionDeviceId];
    }
    // 页面销毁后不再影响正常录音链路。
    [[PerfusionDebuggerService sharedInstance] reset];
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
        [self.scrollView.topAnchor constraintEqualToAnchor:self.familyContentGuide.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.contentStack.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor constant:16],
        [self.contentStack.leadingAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.leadingAnchor constant:16],
        [self.contentStack.trailingAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.trailingAnchor constant:-16],
        [self.contentStack.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor constant:-24],
    ]];

    // 灌流音频
    self.fileButton = [self actionButtonWithTitle:@"选择文件" action:@selector(fileButtonTapped:)];
    self.fileButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    self.historyButton = [self actionButtonWithTitle:@"已导入" action:@selector(historyButtonTapped:)];
    [self.historyButton.widthAnchor constraintEqualToConstant:84].active = YES;

    self.fileDetailLabel = [self bodyLabel];
    self.fileDetailLabel.numberOfLines = 0;
    self.fileDetailLabel.textColor = UIColor.secondaryLabelColor;
    self.fileDetailLabel.font = [UIFont systemFontOfSize:12];

    self.providerLabel = [self bodyLabel];
    self.providerLabel.numberOfLines = 0;
    self.providerLabel.font = [UIFont systemFontOfSize:12];

    self.audioFormatLabel = [self bodyLabel];
    self.audioFormatLabel.numberOfLines = 0;
    self.audioFormatLabel.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightMedium];

    UIStackView *fileStack = [self verticalStack];
    [fileStack addArrangedSubview:[self horizontalStackWithViews:@[self.fileButton, self.historyButton]]];
    [fileStack addArrangedSubview:self.audioFormatLabel];
    [fileStack addArrangedSubview:self.fileDetailLabel];
    [fileStack addArrangedSubview:self.providerLabel];
    [self.contentStack addArrangedSubview:[self cardWithTitle:@"灌流音频" content:fileStack]];

    // 参考答案：用于计算 WER，未选择时只导出识别结果
    self.referenceButton = [self actionButtonWithTitle:@"选择参考答案" action:@selector(referenceButtonTapped:)];
    self.referenceButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    self.referenceHistoryButton = [self actionButtonWithTitle:@"已导入" action:@selector(referenceHistoryButtonTapped:)];
    [self.referenceHistoryButton.widthAnchor constraintEqualToConstant:84].active = YES;

    self.referenceDetailLabel = [self bodyLabel];
    self.referenceDetailLabel.numberOfLines = 0;
    self.referenceDetailLabel.textColor = UIColor.secondaryLabelColor;
    self.referenceDetailLabel.font = [UIFont systemFontOfSize:12];

    UIStackView *referenceStack = [self verticalStack];
    [referenceStack addArrangedSubview:[self horizontalStackWithViews:@[self.referenceButton, self.referenceHistoryButton]]];
    [referenceStack addArrangedSubview:self.referenceDetailLabel];
    [self.contentStack addArrangedSubview:[self cardWithTitle:@"参考答案（WER 标准）" content:referenceStack]];

    // 处理能力
    self.asrSwitch = [[UISwitch alloc] init];
    self.asrSwitch.on = YES;
    self.translateSwitch = [[UISwitch alloc] init];
    self.translateSwitch.on = YES;
    self.ttsSwitch = [[UISwitch alloc] init];
    self.ttsSwitch.on = NO;
    self.autoStopSwitch = [[UISwitch alloc] init];
    self.autoStopSwitch.on = YES;

    self.originalLanguageButton = [self actionButtonWithTitle:@"中文" action:@selector(originalLanguageButtonTapped:)];
    self.originalLanguageButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    self.targetLanguageButton = [self actionButtonWithTitle:@"英语" action:@selector(targetLanguageButtonTapped:)];
    self.targetLanguageButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;

    UIStackView *configStack = [self verticalStack];
    [configStack addArrangedSubview:[self fieldTitleLabel:@"处理能力"]];
    [configStack addArrangedSubview:[self toggleRowWithTitle:@"ASR 识别" switchControl:self.asrSwitch]];
    [configStack addArrangedSubview:[self toggleRowWithTitle:@"翻译" switchControl:self.translateSwitch]];
    [configStack addArrangedSubview:[self toggleRowWithTitle:@"TTS 播报" switchControl:self.ttsSwitch]];
    [configStack addArrangedSubview:[self separatorLine]];
    [configStack addArrangedSubview:[self fieldTitleLabel:@"语言设置"]];
    [configStack addArrangedSubview:[self labeledRowWithTitle:@"源语言" control:self.originalLanguageButton]];
    [configStack addArrangedSubview:[self labeledRowWithTitle:@"目标语言" control:self.targetLanguageButton]];
    [configStack addArrangedSubview:[self separatorLine]];
    [configStack addArrangedSubview:[self fieldTitleLabel:@"灌流行为"]];
    [configStack addArrangedSubview:[self toggleRowWithTitle:@"文件读完自动结束" switchControl:self.autoStopSwitch]];
    [self.contentStack addArrangedSubview:[self cardWithTitle:@"参数设置" content:configStack]];

    // 灌流控制
    self.stateLabel = [self valueLabel];
    self.durationLabel = [self valueLabel];
    self.durationLabel.font = [UIFont monospacedDigitSystemFontOfSize:28 weight:UIFontWeightSemibold];

    self.startButton = [self primaryButtonWithTitle:@"开始灌流" action:@selector(startButtonTapped:)];
    self.stopButton = [self destructiveButtonWithTitle:@"停止" action:@selector(stopButtonTapped:)];
    UIStackView *controlRow = [self horizontalStackWithViews:@[self.startButton, self.stopButton]];
    controlRow.distribution = UIStackViewDistributionFillEqually;

    UIStackView *controlStack = [self verticalStack];
    [controlStack addArrangedSubview:self.stateLabel];
    [controlStack addArrangedSubview:self.durationLabel];
    [controlStack addArrangedSubview:controlRow];
    [self.contentStack addArrangedSubview:[self cardWithTitle:@"灌流控制" content:controlStack]];

    // 过程数据
    self.asrTextView = [self readonlyTextViewWithPlaceholder:@"等待 ASR 回调…" height:140];
    [self.contentStack addArrangedSubview:[self cardWithTitle:@"实时 ASR" content:self.asrTextView]];

    self.translateTextView = [self readonlyTextViewWithPlaceholder:@"等待翻译回调…" height:110];
    [self.contentStack addArrangedSubview:[self cardWithTitle:@"实时翻译" content:self.translateTextView]];

    // 灌流结果
    self.werSummaryLabel = [self bodyLabel];
    self.werSummaryLabel.numberOfLines = 0;
    self.werSummaryLabel.font = [UIFont monospacedDigitSystemFontOfSize:15 weight:UIFontWeightSemibold];
    self.werSummaryLabel.textColor = UIColor.secondaryLabelColor;
    self.werSummaryLabel.text = @"WER：完成一次灌流后计算";

    self.resultTextView = [self readonlyTextViewWithPlaceholder:@"灌流结束后在此展示导出结果" height:200];
    self.resultTextView.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    self.resultCopyButton = [self actionButtonWithTitle:@"复制结果" action:@selector(resultCopyButtonTapped:)];
    self.exportReportButton = [self primaryButtonWithTitle:@"导出测试报告" action:@selector(exportReportButtonTapped:)];
    UIStackView *resultButtonRow = [self horizontalStackWithViews:@[self.resultCopyButton, self.exportReportButton]];
    resultButtonRow.distribution = UIStackViewDistributionFillEqually;

    UIStackView *resultStack = [self verticalStack];
    [resultStack addArrangedSubview:self.werSummaryLabel];
    [resultStack addArrangedSubview:[self separatorLine]];
    [resultStack addArrangedSubview:self.resultTextView];
    [resultStack addArrangedSubview:resultButtonRow];
    [self.contentStack addArrangedSubview:[self cardWithTitle:@"灌流结果" content:resultStack]];

    self.logTextView = [self readonlyTextViewWithPlaceholder:@"SDK 事件日志" height:180];
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

- (UILabel *)valueLabel {
    UILabel *label = [[UILabel alloc] init];
    label.font = [UIFont systemFontOfSize:17 weight:UIFontWeightMedium];
    label.textColor = UIColor.labelColor;
    label.textAlignment = NSTextAlignmentCenter;
    return label;
}

- (UIView *)toggleRowWithTitle:(NSString *)title switchControl:(UISwitch *)switchControl {
    UILabel *label = [[UILabel alloc] init];
    label.text = title;
    label.font = [UIFont systemFontOfSize:15];
    label.textColor = UIColor.labelColor;
    [label setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [label setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
    return [self horizontalStackWithViews:@[label, switchControl]];
}

- (UIView *)labeledRowWithTitle:(NSString *)title control:(UIView *)control {
    UILabel *label = [[UILabel alloc] init];
    label.text = title;
    label.font = [UIFont systemFontOfSize:15];
    label.textColor = UIColor.labelColor;
    [label setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [label setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [label.widthAnchor constraintEqualToConstant:78].active = YES;
    return [self horizontalStackWithViews:@[label, control]];
}

- (UIView *)separatorLine {
    UIView *line = [[UIView alloc] init];
    line.backgroundColor = UIColor.separatorColor;
    [line.heightAnchor constraintEqualToConstant:0.5].active = YES;
    return line;
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

#pragma mark - 灌流音频选择

- (void)refreshFileState {
    NSArray<NSString *> *files = [PerfusionDebuggerService availableAudioFileNames];
    // 选中的文件被删掉时回落到空。
    if (self.selectedFileName.length > 0 && ![files containsObject:self.selectedFileName]) {
        self.selectedFileName = nil;
    }
    if (self.selectedFileName.length == 0 && files.count > 0) {
        self.selectedFileName = files.firstObject;
    }

    [self.fileButton setTitle:self.selectedFileName.length > 0 ? self.selectedFileName : @"选择文件"
                     forState:UIControlStateNormal];

    // 底层把文件内容当成 16k/16bit 单声道 PCM 直接替换采集流，格式不符会「灌流在跑但没有 ASR 输出」。
    if (self.selectedFileName.length > 0) {
        PerfusionAudioFileInfo *info = [PerfusionDebuggerService audioFileInfoWithFileName:self.selectedFileName];
        if (info.isRecommended) {
            self.audioFormatLabel.textColor = UIColor.systemGreenColor;
            self.audioFormatLabel.text = [NSString stringWithFormat:@"✓ %@", info.summary];
        } else {
            self.audioFormatLabel.textColor = info.isDecodable ? UIColor.systemOrangeColor : UIColor.systemRedColor;
            self.audioFormatLabel.text = [NSString stringWithFormat:@"%@ %@\n%@",
                                          info.isDecodable ? @"⚠️" : @"✗", info.summary, info.warning ?: @""];
        }
    } else {
        self.audioFormatLabel.textColor = UIColor.secondaryLabelColor;
        self.audioFormatLabel.text = @"需要 16kHz / 16bit / 单声道的整型 PCM WAV";
    }

    NSMutableString *detail = [NSMutableString string];
    if (self.selectedFileName.length > 0) {
        unsigned long long size = [PerfusionDebuggerService fileSizeOfAudioFileNamed:self.selectedFileName];
        [detail appendFormat:@"文件大小 %.1f KB\n", size / 1024.0];
    }
    [detail appendFormat:@"已导入 %lu 个文件（支持 wav / mp3）\n", (unsigned long)files.count];
    [detail appendString:@"选中的文件会拷贝到灌流工作目录后再喂给录音链路\n"
     "格式不符可用 afconvert 转换：afconvert -f WAVE -d LEI16@16000 -c 1 in.wav out.wav"];
    self.fileDetailLabel.text = detail;

    [self updateControls];
}

- (void)refreshProviderState {
    PerfusionDebuggerService *service = [PerfusionDebuggerService sharedInstance];
    NSString *className = [service currentProviderClassName];
    if ([service isProviderReady]) {
        self.providerLabel.text = [NSString stringWithFormat:@"灌流配置提供者已就绪（%@）", className];
        self.providerLabel.textColor = UIColor.systemGreenColor;
    } else if (className.length > 0) {
        // 被别的实现占位时，本页配置不会被底层读到。
        self.providerLabel.text = [NSString stringWithFormat:@"调试配置已被 %@ 接管，灌流配置不会生效", className];
        self.providerLabel.textColor = UIColor.systemRedColor;
    } else {
        self.providerLabel.text = @"灌流配置提供者未就绪，将在开始灌流时补注册";
        self.providerLabel.textColor = UIColor.systemOrangeColor;
    }
}

/// 选文件：直接拉起系统文件选择器，选中的文件落地到灌流目录后立即设为当前灌流文件。
- (void)fileButtonTapped:(UIButton *)sender {
    self.pickerPurpose = NativePerfusionPickerPurposeAudio;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    // 用 UTI 字符串初始化，兼容 iOS 13。
    UIDocumentPickerViewController *picker =
        [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.audio", @"public.mp3", @"com.microsoft.waveform-audio"]
                                                              inMode:UIDocumentPickerModeImport];
#pragma clang diagnostic pop
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    [self presentViewController:picker animated:YES completion:nil];
}

/// 已导入过的文件走这里快速复用，顺带提供删除。
- (void)historyButtonTapped:(UIButton *)sender {
    NSArray<NSString *> *files = [PerfusionDebuggerService availableAudioFileNames];
    if (files.count == 0) {
        [self showFamilyMessageWithTitle:@"还没有导入过文件" message:@"点击「选择文件」从本地挑一个 wav / mp3。"];
        return;
    }

    NSMutableArray<FamilyUIAction *> *actions = [NSMutableArray array];
    __weak typeof(self) weakSelf = self;
    for (NSString *fileName in files) {
        [actions addObject:[FamilyUIAction actionWithTitle:fileName handler:^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            self.selectedFileName = fileName;
            [self appendLog:[NSString stringWithFormat:@"选择灌流文件 %@", fileName]];
            [self refreshFileState];
        }]];
    }
    if (self.selectedFileName.length > 0) {
        NSString *deleting = self.selectedFileName;
        [actions addObject:[FamilyUIAction destructiveActionWithTitle:[NSString stringWithFormat:@"删除 %@", deleting]
                                                             handler:^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            NSError *error = nil;
            if ([PerfusionDebuggerService removeAudioFileNamed:deleting error:&error]) {
                [self appendLog:[NSString stringWithFormat:@"删除灌流文件 %@", deleting]];
                self.selectedFileName = nil;
            } else {
                [self showFamilyMessageWithTitle:@"删除失败" message:error.localizedDescription ?: @""];
            }
            [self refreshFileState];
        }]];
    }

    [self showFamilyActionSheetWithTitle:@"已导入的灌流音频" message:nil actions:actions];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url = urls.firstObject;
    if (!url) return;

    NSError *error = nil;
    if (self.pickerPurpose == NativePerfusionPickerPurposeReference) {
        NSString *fileName = [PerfusionDebuggerService importReferenceFileFromURL:url error:&error];
        if (fileName.length == 0) {
            [self showFamilyMessageWithTitle:@"参考答案读取失败" message:error.localizedDescription ?: @"未知错误"];
            return;
        }
        [self selectReferenceFileNamed:fileName];
        return;
    }

    NSString *fileName = [PerfusionDebuggerService importAudioFileFromURL:url error:&error];
    if (fileName.length == 0) {
        [self showFamilyMessageWithTitle:@"文件读取失败" message:error.localizedDescription ?: @"未知错误"];
        return;
    }

    self.selectedFileName = fileName;
    [self appendLog:[NSString stringWithFormat:@"选择灌流文件 %@", fileName]];
    [self refreshFileState];
}

#pragma mark - 参考答案选择

/// 选参考答案：拉起文件选择器，选中的 txt 落地到参考答案目录后立即生效。
- (void)referenceButtonTapped:(UIButton *)sender {
    self.pickerPurpose = NativePerfusionPickerPurposeReference;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    UIDocumentPickerViewController *picker =
        [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.plain-text", @"public.text", @"public.data"]
                                                              inMode:UIDocumentPickerModeImport];
#pragma clang diagnostic pop
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    [self presentViewController:picker animated:YES completion:nil];
}

/// 已导入过的参考答案走这里快速复用，顺带提供删除与「不使用参考答案」。
- (void)referenceHistoryButtonTapped:(UIButton *)sender {
    NSArray<NSString *> *files = [PerfusionDebuggerService availableReferenceFileNames];
    if (files.count == 0) {
        [self showFamilyMessageWithTitle:@"还没有导入过参考答案" message:@"点击「选择参考答案」从本地挑一个 txt 文件。"];
        return;
    }

    NSMutableArray<FamilyUIAction *> *actions = [NSMutableArray array];
    __weak typeof(self) weakSelf = self;
    for (NSString *fileName in files) {
        [actions addObject:[FamilyUIAction actionWithTitle:fileName handler:^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            [self selectReferenceFileNamed:fileName];
        }]];
    }
    if (self.selectedReferenceFileName.length > 0) {
        [actions addObject:[FamilyUIAction actionWithTitle:@"不使用参考答案" handler:^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            self.selectedReferenceFileName = nil;
            self.referenceText = nil;
            [self appendLog:@"已取消参考答案，本次不计算 WER"];
            [self refreshReferenceState];
        }]];
        NSString *deleting = self.selectedReferenceFileName;
        [actions addObject:[FamilyUIAction destructiveActionWithTitle:[NSString stringWithFormat:@"删除 %@", deleting]
                                                             handler:^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            NSError *error = nil;
            if ([PerfusionDebuggerService removeReferenceFileNamed:deleting error:&error]) {
                [self appendLog:[NSString stringWithFormat:@"删除参考答案 %@", deleting]];
                self.selectedReferenceFileName = nil;
                self.referenceText = nil;
            } else {
                [self showFamilyMessageWithTitle:@"删除失败" message:error.localizedDescription ?: @""];
            }
            [self refreshReferenceState];
        }]];
    }

    [self showFamilyActionSheetWithTitle:@"已导入的参考答案" message:nil actions:actions];
}

- (void)selectReferenceFileNamed:(NSString *)fileName {
    NSString *text = [PerfusionDebuggerService referenceTextWithFileName:fileName];
    if (text.length == 0) {
        [self showFamilyMessageWithTitle:@"参考答案为空" message:@"文件内容读取为空，请确认是 UTF-8 文本。"];
        return;
    }
    self.selectedReferenceFileName = fileName;
    self.referenceText = text;
    [self appendLog:[NSString stringWithFormat:@"选择参考答案 %@", fileName]];
    [self refreshReferenceState];
}

- (void)refreshReferenceState {
    NSArray<NSString *> *files = [PerfusionDebuggerService availableReferenceFileNames];
    // 选中的文件被删掉时回落到空。
    if (self.selectedReferenceFileName.length > 0 && ![files containsObject:self.selectedReferenceFileName]) {
        self.selectedReferenceFileName = nil;
        self.referenceText = nil;
    }

    [self.referenceButton setTitle:self.selectedReferenceFileName.length > 0 ? self.selectedReferenceFileName : @"选择参考答案"
                          forState:UIControlStateNormal];

    NSMutableString *detail = [NSMutableString string];
    if (self.referenceText.length > 0) {
        NSArray<NSString *> *lines = [PerfusionWERCalculator normalizedLinesFromReferenceText:self.referenceText];
        NSString *normalized = [PerfusionWERCalculator normalizeText:self.referenceText];
        NSUInteger words = normalized.length > 0 ? [normalized componentsSeparatedByString:@" "].count : 0;
        [detail appendFormat:@"归一化后 %lu 词 / %lu 行，作为 WER 的分母 N\n",
         (unsigned long)words, (unsigned long)lines.count];
        [detail appendString:@"逐句对比按行切分，建议参考答案每行一句、与音频停顿一致\n"];
    } else {
        [detail appendString:@"未选择参考答案，本次只导出识别结果、不计算 WER\n"];
    }
    [detail appendFormat:@"已导入 %lu 份参考答案（txt，UTF-8）", (unsigned long)files.count];
    self.referenceDetailLabel.text = detail;

    [self updateControls];
}

#pragma mark - 语言选择

- (void)originalLanguageButtonTapped:(UIButton *)sender {
    __weak typeof(self) weakSelf = self;
    [self presentLanguagePickerWithTitle:@"选择源语言" selected:self.selectedOriginalLanguage confirm:^(NSString *code) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.selectedOriginalLanguage = code;
        [self.originalLanguageButton setTitle:[self displayNameForLanguageCode:code] forState:UIControlStateNormal];
    }];
}

- (void)targetLanguageButtonTapped:(UIButton *)sender {
    __weak typeof(self) weakSelf = self;
    [self presentLanguagePickerWithTitle:@"选择目标语言" selected:self.selectedTargetLanguage confirm:^(NSString *code) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.selectedTargetLanguage = code;
        [self.targetLanguageButton setTitle:[self displayNameForLanguageCode:code] forState:UIControlStateNormal];
    }];
}

- (void)presentLanguagePickerWithTitle:(NSString *)title
                              selected:(NSString *)selectedCode
                               confirm:(void (^)(NSString *code))confirm {
    NSMutableArray<FamilyUIAction *> *actions = [NSMutableArray array];
    for (NSDictionary<NSString *, NSString *> *language in kPerfusionLanguages()) {
        NSString *code = language[@"code"];
        NSString *name = language[@"name"];
        NSString *actionTitle = [code isEqualToString:selectedCode] ? [NSString stringWithFormat:@"%@ ✓", name] : name;
        [actions addObject:[FamilyUIAction actionWithTitle:actionTitle handler:^{
            if (confirm) confirm(code);
        }]];
    }
    [self showFamilyActionSheetWithTitle:title message:nil actions:actions];
}

- (NSString *)displayNameForLanguageCode:(NSString *)code {
    for (NSDictionary<NSString *, NSString *> *language in kPerfusionLanguages()) {
        if ([language[@"code"] isEqualToString:code]) return language[@"name"];
    }
    return code ?: @"-";
}

#pragma mark - 灌流控制

- (void)startButtonTapped:(UIButton *)sender {
    if (self.operationPending || self.perfusionRunning) return;
    if (self.selectedFileName.length == 0) {
        [self showFamilyMessageWithTitle:@"未选择灌流音频" message:@"请先选择或导入一个 wav / mp3 文件。"];
        return;
    }

    // 灌流虽然替换采集数据，但底层仍会启动音频采集链路，麦克风权限缺失会导致启动失败。
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
                    [self beginPerfusion];
                } else {
                    [self showFamilyMessageWithTitle:@"麦克风权限未开启" message:@"灌流依赖音频采集链路，需要麦克风权限。"];
                }
            });
        }];
        return;
    }
    [self beginPerfusion];
}

/// 开始前校验音频格式：底层只吃整型 PCM，格式不符会「灌流在跑但没有任何 ASR 输出」。
- (void)beginPerfusion {
    PerfusionAudioFileInfo *info = [PerfusionDebuggerService audioFileInfoWithFileName:self.selectedFileName];
    NSString *convertHint = @"\n\n可用 macOS 自带命令转换：\nafconvert -f WAVE -d LEI16@16000 -c 1 输入.wav 输出.wav";

    if (!info.isDecodable) {
        [self appendLog:[NSString stringWithFormat:@"音频格式不支持：%@", info.summary]];
        [self showFamilyMessageWithTitle:@"音频格式不支持"
                                message:[NSString stringWithFormat:@"%@\n\n当前文件：%@%@",
                                         info.warning ?: @"底层只支持整型 PCM 的 WAV。",
                                         info.summary, convertHint]];
        return;
    }
    if (!info.isRecommended) {
        __weak typeof(self) weakSelf = self;
        [self showFamilyConfirmationWithTitle:@"音频参数与链路不一致"
                                     message:[NSString stringWithFormat:@"当前文件：%@\n\n%@%@",
                                              info.summary, info.warning ?: @"", convertHint]
                                confirmTitle:@"仍然开始"
                                 destructive:NO
                                     confirm:^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            [self appendLog:[NSString stringWithFormat:@"音频参数不匹配仍继续：%@", info.summary]];
            [self performPerfusion];
        }];
        return;
    }
    [self appendLog:[NSString stringWithFormat:@"音频格式校验通过：%@", info.summary]];
    [self performPerfusion];
}

- (void)performPerfusion {
    PerfusionDebuggerService *service = [PerfusionDebuggerService sharedInstance];
    if (![service registerProvider]) {
        [self showFamilyMessageWithTitle:@"灌流不可用"
                                message:@"未能向底层注册灌流配置提供者，当前构建无法进行灌流。"];
        [self refreshProviderState];
        return;
    }
    [self refreshProviderState];

    [self resetProcessViews];
    [service resetConfigFetchCount];
    self.operationPending = YES;
    self.resultSettled = NO;
    self.ttsCallbackCount = 0;
    self.runningFileName = self.selectedFileName;
    [self updateControls];

    // 灌流参数在 start 之前写入，底层启动音频输入时会回读。
    service.perfusionEnabled = YES;
    service.perfusionFileName = self.selectedFileName;
    service.autoCloseFileWhenPerfusionEnd = self.autoStopSwitch.isOn;

    __weak typeof(self) weakSelf = self;
    service.didEndHandler = ^(NSString *fileName) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self appendLog:[NSString stringWithFormat:@"灌流文件读取完成 file=%@", fileName ?: @"-"]];
        if (self.autoStopSwitch.isOn) {
            [self stopPerfusionWithReason:@"灌流文件读取完成"];
        }
    };

    ThingAudioRecordConfig *config = [[ThingAudioRecordConfig alloc] init];
    config.recordType = ThingAudioRecordTypeMeet;
    config.businessType = ThingAudioBusinessTypeNote;
    config.transferType = ThingAudioRecordTransferTypeRealTime;
    // 灌流只在手机麦克风输入链路上生效。
    config.audioSource = ThingSystemMic16KMono;
    config.audioSourceList = @[@(ThingSystemMic16KMono)];
    config.needAsr = self.asrSwitch.isOn;
    config.needTranslate = self.translateSwitch.isOn;
    config.needTTS = self.ttsSwitch.isOn;
    config.needAmplitude = NO;
    config.needAutoRecognize = NO;
    config.originalLanguage = self.selectedOriginalLanguage;
    config.targetLanguage = self.selectedTargetLanguage;
    config.startLivingStatus = 0;
    // 灌流素材是既有音频，关闭 3A 保持输入数据原样。
    config.audio3AConfig = [[ThingAudio3AConfig alloc] initWithEnableRnAns:NO ans:NO level:0 agc:NO aec:NO];

    [self appendLog:[NSString stringWithFormat:@"调用 start file=%@ asr=%d translate=%d tts=%d %@->%@",
                     self.selectedFileName, config.needAsr, config.needTranslate, config.needTTS,
                     self.selectedOriginalLanguage, self.selectedTargetLanguage]];

    [[NativeAudioService sharedInstance] startRecordingWithDeviceId:kPerfusionDeviceId
                                                            config:config
                                                           success:^(ThingAudioRecordObject *task) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.operationPending = NO;
        self.perfusionRunning = YES;
        self.currentRecordId = task.recordId;
        self.startDate = NSDate.date;
        [self startDurationTimer];
        [self appendLog:[NSString stringWithFormat:@"start 成功 recordId=%@", task.recordId ?: @"-"]];
        [self updateControls];
        [self verifyPerfusionTookEffect];
    } failure:^(NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.operationPending = NO;
        [[PerfusionDebuggerService sharedInstance] reset];
        [self appendLog:[NSString stringWithFormat:@"start 失败 %@", error.localizedDescription ?: @"-"]];
        [self showFamilyMessageWithTitle:@"开始灌流失败" message:error.localizedDescription ?: @""];
        [self updateControls];
    }];
}

/// 底层启动音频输入时会回读灌流配置，若始终没读说明注册没生效，此时录的是真实麦克风。
- (void)verifyPerfusionTookEffect {
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !self.perfusionRunning) return;
        NSUInteger count = [PerfusionDebuggerService sharedInstance].configFetchCount;
        [self appendLog:[NSString stringWithFormat:@"底层回读灌流配置 %lu 次", (unsigned long)count]];
        if (count == 0) {
            [self appendLog:@"⚠️ 底层未读取灌流配置，当前录制的是真实麦克风输入"];
            [self showFamilyMessageWithTitle:@"灌流未生效"
                                    message:@"底层没有回读灌流配置，本次录制的是真实麦克风输入。请确认调试配置提供者已注册。"];
        }
    });
}

- (void)stopButtonTapped:(UIButton *)sender {
    [self stopPerfusionWithReason:@"手动停止"];
}

- (void)stopPerfusionWithReason:(NSString *)reason {
    if (!self.perfusionRunning || self.operationPending) return;
    self.operationPending = YES;
    [self updateControls];
    [self appendLog:[NSString stringWithFormat:@"调用 stop（%@）", reason]];

    __weak typeof(self) weakSelf = self;
    [[NativeAudioService sharedInstance] stopRecordingWithDeviceId:kPerfusionDeviceId success:^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.operationPending = NO;
        [self updateControls];
        [self appendLog:@"stop 成功"];
        [self settleResultWithReason:reason error:nil];
    } failure:^(NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.operationPending = NO;
        [self updateControls];
        [self appendLog:[NSString stringWithFormat:@"stop 失败 %@", error.localizedDescription ?: @"-"]];
        [self settleResultWithReason:reason error:error];
    }];
}

#pragma mark - 计时

- (void)startDurationTimer {
    [self stopDurationTimer];
    self.durationTimer = [NSTimer scheduledTimerWithTimeInterval:0.2
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
    [self updateDurationLabel];
}

- (void)updateDurationLabel {
    NSTimeInterval elapsed = self.startDate ? [NSDate.date timeIntervalSinceDate:self.startDate] : 0;
    NSInteger totalMs = (NSInteger)(elapsed * 1000);
    self.durationLabel.text = [NSString stringWithFormat:@"%02ld:%02ld.%03ld",
                               (long)(totalMs / 60000), (long)((totalMs / 1000) % 60), (long)(totalMs % 1000)];
}

#pragma mark - 录音监听

- (void)bindRecordListener {
    if (self.listenerBound) return;
    [[NativeAudioService sharedInstance] addRecordListener:self deviceId:kPerfusionDeviceId];
    self.listenerBound = YES;
}

- (void)record:(NSString *)deviceId didFinishWithError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self appendLog:[NSString stringWithFormat:@"finish error=%@", error.localizedDescription ?: @"none"]];
        [self settleResultWithReason:error ? @"录音链路异常结束" : @"录音链路结束" error:error];
    });
}

- (void)record:(NSString *)deviceId didUpdateStatus:(ThingAudioRecordStatus *)status {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.recordState = status.state;
        [self appendLog:[NSString stringWithFormat:@"status state=%lu", (unsigned long)status.state]];
        if (status.state == ThingAudioRecordStateFinish) {
            [self settleResultWithReason:@"录音状态结束" error:nil];
            return;
        }
        [self updateControls];
    });
}

- (void)record:(NSString *)deviceId onProcessResult:(ThingAudioRecordProcessResult *)result {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self appendLog:[NSString stringWithFormat:@"process %@/%@ asrId=%lld text=%@ translate=%@(%@) error=%@",
                         [self titleForProcessPhase:result.phase],
                         [self titleForProcessStatus:result.status],
                         result.asrId,
                         result.text ?: @"-",
                         result.translateText ?: @"-",
                         [self titleForProcessStatus:result.translateStatus],
                         result.error.localizedDescription ?: @"none"]];

        if (result.phase == ThingAudioRecordProcessPhaseTts) self.ttsCallbackCount++;

        // 句子聚合 key：优先 asrId+channel，回落 requestId。
        NSString *key = result.asrId != 0 ? [NSString stringWithFormat:@"%lld-%d", result.asrId, result.channel]
                                          : result.requestId;

        if ((result.phase == ThingAudioRecordProcessPhaseAsr || result.phase == ThingAudioRecordProcessPhaseText)
            && key.length > 0 && result.text.length > 0) {
            if (!self.asrTexts[key]) [self.asrOrder addObject:key];
            self.asrTexts[key] = result.text;
            [self refreshASRText];
        }

        // 译文在 translateText 上，伴随独立的 translateStatus；Cancel 不覆盖已有译文。
        if (key.length > 0 &&
            (result.translateText.length > 0 || result.translateStatus == ThingAudioRecordProcessStatusEnd)) {
            if (self.translateTexts[key] == nil) [self.translateOrder addObject:key];
            if (result.translateStatus != ThingAudioRecordProcessStatusCancel || self.translateTexts[key] == nil) {
                self.translateTexts[key] = result.translateText.length > 0 ? result.translateText : @"";
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

#pragma mark - 过程数据渲染

- (void)refreshASRText {
    NSString *text = [self joinedTextWithOrder:self.asrOrder texts:self.asrTexts];
    self.asrTextView.textColor = UIColor.labelColor;
    self.asrTextView.text = text.length > 0 ? text : @"等待 ASR 回调…";
    [self.asrTextView scrollRangeToVisible:NSMakeRange(self.asrTextView.text.length, 0)];
}

- (void)refreshTranslateText {
    NSString *text = [self joinedTextWithOrder:self.translateOrder texts:self.translateTexts];
    self.translateTextView.textColor = UIColor.labelColor;
    self.translateTextView.text = text.length > 0 ? text : @"等待翻译回调…";
    [self.translateTextView scrollRangeToVisible:NSMakeRange(self.translateTextView.text.length, 0)];
}

- (NSString *)joinedTextWithOrder:(NSArray<NSString *> *)order texts:(NSDictionary<NSString *, NSString *> *)texts {
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    for (NSString *key in order) {
        NSString *line = texts[key];
        if (line.length > 0) [lines addObject:line];
    }
    return [lines componentsJoinedByString:@"\n"];
}

- (void)resetProcessViews {
    self.lastWERResult = nil;
    self.lastLineResults = nil;
    [self refreshWERSummary];
    [self.asrTexts removeAllObjects];
    [self.asrOrder removeAllObjects];
    [self.translateTexts removeAllObjects];
    [self.translateOrder removeAllObjects];
    self.currentRecordId = nil;
    self.startDate = nil;
    self.durationLabel.text = @"00:00.000";
    self.asrTextView.textColor = UIColor.secondaryLabelColor;
    self.asrTextView.text = @"等待 ASR 回调…";
    self.translateTextView.textColor = UIColor.secondaryLabelColor;
    self.translateTextView.text = @"等待翻译回调…";
}

#pragma mark - 结果汇总

- (void)settleResultWithReason:(NSString *)reason error:(nullable NSError *)error {
    // 灌流结束、stop 回调、录音状态结束可能先后到达，只汇总一次；
    // 但每次都要刷新控件，否则先到的回调汇总结果、后到的回调清 pending 时 UI 会停在「处理中」。
    if (self.resultSettled || !self.perfusionRunning) {
        [self updateControls];
        return;
    }
    self.resultSettled = YES;
    self.perfusionRunning = NO;
    // 结果已经汇总，无论 stop 回调是否返回都不再是处理中状态。
    self.operationPending = NO;
    [self stopDurationTimer];
    [self updateDurationLabel];

    PerfusionDebuggerService *service = [PerfusionDebuggerService sharedInstance];
    service.perfusionEnabled = NO;
    service.didEndHandler = nil;

    NSArray<NSString *> *asrSentences = [self sentencesWithOrder:self.asrOrder texts:self.asrTexts];
    NSArray<NSString *> *translateSentences = [self sentencesWithOrder:self.translateOrder texts:self.translateTexts];

    PerfusionReportInput *input = [[PerfusionReportInput alloc] init];
    input.audioFileName = self.runningFileName;
    input.referenceFileName = self.selectedReferenceFileName;
    input.referenceText = self.referenceText;
    input.asrSentences = asrSentences;
    input.translateSentences = translateSentences;
    input.startDate = self.startDate;
    input.endDate = NSDate.date;
    input.recordId = self.currentRecordId;
    input.finishReason = error ? [NSString stringWithFormat:@"%@（%@）", reason ?: @"-",
                                  error.localizedDescription ?: @"错误"] : (reason ?: @"-");
    input.asrEnabled = self.asrSwitch.isOn;
    input.translateEnabled = self.translateSwitch.isOn;
    input.ttsEnabled = self.ttsSwitch.isOn;
    input.originalLanguage = [self displayNameForLanguageCode:self.selectedOriginalLanguage];
    input.targetLanguage = [self displayNameForLanguageCode:self.selectedTargetLanguage];
    input.configFetchCount = service.configFetchCount;
    input.ttsCallbackCount = self.ttsCallbackCount;

    // 有参考答案才评估 WER；口径与 ASR_WER/WER.py 一致。
    PerfusionWERResult *werResult = nil;
    NSArray<PerfusionWERLineResult *> *lineResults = nil;
    if (self.referenceText.length > 0) {
        NSString *hypothesis = [asrSentences componentsJoinedByString:@" "];
        werResult = [PerfusionWERCalculator evaluateReference:self.referenceText hypothesis:hypothesis];
        NSArray<NSString *> *referenceLines = [PerfusionWERCalculator normalizedLinesFromReferenceText:self.referenceText];
        if (referenceLines.count > 0) {
            lineResults = [PerfusionWERCalculator evaluateReferenceLines:referenceLines
                                                     hypothesisSegments:asrSentences];
        }
        [self appendLog:[NSString stringWithFormat:@"WER 计算完成 准确率=%.2f%% WER=%.2f%% N=%lu S=%lu D=%lu I=%lu",
                         werResult.accuracy * 100, werResult.wer * 100,
                         (unsigned long)werResult.referenceCount, (unsigned long)werResult.substitutions,
                         (unsigned long)werResult.deletions, (unsigned long)werResult.insertions]];
    }

    self.lastReportInput = input;
    self.lastWERResult = werResult;
    self.lastLineResults = lineResults;
    self.lastResultText = [PerfusionReportBuilder textSummaryWithInput:input werResult:werResult];

    self.resultTextView.textColor = UIColor.labelColor;
    self.resultTextView.text = self.lastResultText;
    [self refreshWERSummary];
    [self appendLog:[NSString stringWithFormat:@"灌流结束，结果已导出（%@）", reason ?: @"-"]];
    [self updateControls];
}

/// 把按 key 聚合的分句还原成有序数组。
- (NSArray<NSString *> *)sentencesWithOrder:(NSArray<NSString *> *)order
                                      texts:(NSDictionary<NSString *, NSString *> *)texts {
    NSMutableArray<NSString *> *sentences = [NSMutableArray array];
    for (NSString *key in order) {
        NSString *text = texts[key];
        if (text.length > 0) [sentences addObject:text];
    }
    return sentences;
}

- (void)refreshWERSummary {
    PerfusionWERResult *result = self.lastWERResult;
    if (!result || result.referenceCount == 0) {
        self.werSummaryLabel.textColor = UIColor.secondaryLabelColor;
        self.werSummaryLabel.text = self.selectedReferenceFileName.length > 0
            ? @"WER：参考答案为空，未计算"
            : @"WER：未选择参考答案，未计算";
        return;
    }
    self.werSummaryLabel.textColor = result.accuracy >= 0.9 ? UIColor.systemGreenColor
        : (result.accuracy >= 0.7 ? UIColor.systemOrangeColor : UIColor.systemRedColor);
    self.werSummaryLabel.text = [NSString stringWithFormat:
        @"准确率 %.2f%%　WER %.2f%%\nN=%lu  S=%lu  D=%lu  I=%lu  命中=%lu",
        result.accuracy * 100, result.wer * 100,
        (unsigned long)result.referenceCount, (unsigned long)result.substitutions,
        (unsigned long)result.deletions, (unsigned long)result.insertions,
        (unsigned long)result.hits];
}

#pragma mark - 报告导出

- (void)exportReportButtonTapped:(UIButton *)sender {
    if (!self.lastReportInput) {
        [self showFamilyMessageWithTitle:@"暂无结果" message:@"请先完成一次灌流。"];
        return;
    }

    NSError *error = nil;
    NSURL *url = [PerfusionReportBuilder writeReportWithInput:self.lastReportInput
                                                    werResult:self.lastWERResult
                                                  lineResults:self.lastLineResults
                                                        error:&error];
    if (!url) {
        [self showFamilyMessageWithTitle:@"报告生成失败" message:error.localizedDescription ?: @"未知错误"];
        return;
    }
    [self appendLog:[NSString stringWithFormat:@"报告已生成 %@", url.lastPathComponent]];

    UIActivityViewController *activity =
        [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
    // iPad 上必须给出弹出锚点，否则会崩。
    activity.popoverPresentationController.sourceView = sender;
    activity.popoverPresentationController.sourceRect = sender.bounds;
    [self presentViewController:activity animated:YES completion:nil];
}

- (void)resultCopyButtonTapped:(UIButton *)sender {
    if (self.lastResultText.length == 0) {
        [self showFamilyMessageWithTitle:@"暂无结果" message:@"请先完成一次灌流。"];
        return;
    }
    UIPasteboard.generalPasteboard.string = self.lastResultText;
    [self showFamilyMessageWithTitle:@"已复制" message:@"灌流结果已复制到剪贴板。"];
}

#pragma mark - 控件状态与日志

- (void)updateControls {
    BOOL canStart = !self.perfusionRunning && !self.operationPending && self.selectedFileName.length > 0;
    self.startButton.enabled = canStart;
    self.startButton.alpha = canStart ? 1.0 : 0.4;
    self.stopButton.enabled = self.perfusionRunning && !self.operationPending;
    self.stopButton.alpha = self.stopButton.isEnabled ? 1.0 : 0.4;

    BOOL configEditable = !self.perfusionRunning && !self.operationPending;
    self.fileButton.enabled = configEditable;
    self.historyButton.enabled = configEditable;
    self.referenceButton.enabled = configEditable;
    self.referenceHistoryButton.enabled = configEditable;
    self.asrSwitch.enabled = configEditable;
    self.translateSwitch.enabled = configEditable;
    self.ttsSwitch.enabled = configEditable;
    self.originalLanguageButton.enabled = configEditable;
    self.targetLanguageButton.enabled = configEditable;
    self.resultCopyButton.enabled = self.lastResultText.length > 0;
    self.resultCopyButton.alpha = self.resultCopyButton.isEnabled ? 1.0 : 0.4;
    self.exportReportButton.enabled = (self.lastReportInput != nil);
    self.exportReportButton.alpha = self.exportReportButton.isEnabled ? 1.0 : 0.4;

    if (self.operationPending) {
        self.stateLabel.text = @"处理中…";
        self.stateLabel.textColor = UIColor.systemOrangeColor;
    } else if (self.perfusionRunning) {
        self.stateLabel.text = @"灌流进行中";
        self.stateLabel.textColor = UIColor.systemGreenColor;
    } else if (self.lastResultText.length > 0) {
        self.stateLabel.text = @"灌流已结束";
        self.stateLabel.textColor = UIColor.labelColor;
    } else {
        self.stateLabel.text = @"未开始";
        self.stateLabel.textColor = UIColor.secondaryLabelColor;
    }
}

- (void)appendLog:(NSString *)message {
    if (message.length == 0) return;
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"HH:mm:ss.SSS";
    [self.eventLogs addObject:[NSString stringWithFormat:@"[%@] %@", [formatter stringFromDate:NSDate.date], message]];
    if (self.eventLogs.count > kPerfusionMaxLogCount) [self.eventLogs removeObjectAtIndex:0];
    self.logTextView.textColor = UIColor.labelColor;
    self.logTextView.text = [self.eventLogs componentsJoinedByString:@"\n"];
    [self.logTextView scrollRangeToVisible:NSMakeRange(self.logTextView.text.length, 0)];
}

@end
