//
//  NativeRecordDetailViewController.m
//  AIVoiceDemo
//

#import "NativeRecordDetailViewController.h"
#import "NativeAudioService.h"
#import <ThingAudioRecordInterface/ThingAudioRecordInterface.h>
#import <AVFoundation/AVFoundation.h>
#import <math.h>

/// 静态振幅立柱配置。
static const CGFloat kDetailWaveformBarSpacing = 2.0;
static const CGFloat kDetailWaveformBarMinWidth = 2.0;

@interface NativeRecordDetailViewController () <AVAudioPlayerDelegate>

@property (nonatomic, copy) NSString *recordId;
@property (nonatomic, strong, nullable) ThingAudioRecordFile *file;

// UI
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *contentStack;

// 信息卡片
@property (nonatomic, strong) UILabel *infoLabel;

// 振幅卡片
@property (nonatomic, strong) UIView *waveformView;
@property (nonatomic, strong) NSMutableArray<CALayer *> *waveformBars;

// 播放卡片
@property (nonatomic, strong) UIButton *playButton;
@property (nonatomic, strong) UISlider *progressSlider;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong, nullable) NSTimer *playTimer;

// 转写/总结卡片
@property (nonatomic, strong) UILabel *transferStatusLabel;
@property (nonatomic, strong) UIStackView *transferContainer;
@property (nonatomic, strong) UILabel *summaryStatusLabel;
@property (nonatomic, strong) UITextView *summaryTextView;

// 操作按钮
@property (nonatomic, strong) UIButton *transcribeButton;
@property (nonatomic, strong) UIButton *summarizeButton;
@property (nonatomic, strong) UIButton *translateButton;

// 播放器
@property (nonatomic, strong, nullable) AVAudioPlayer *audioPlayer;

// 状态
@property (nonatomic, assign) BOOL processing;

@end

@implementation NativeRecordDetailViewController

#pragma mark - Init

- (instancetype)initWithRecordId:(NSString *)recordId {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _recordId = [recordId copy];
    }
    return self;
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    [self configureFamilyNavigationWithTitle:@"录音详情"
                                   leftTitle:@"‹"
                                  leftAction:^{
        [self.navigationController popViewControllerAnimated:YES];
    }
                                  rightTitle:nil
                                 rightAction:nil];

    self.waveformBars = [NSMutableArray array];
    [self setupUI];
    [self loadDetail];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stopPlaybackTimer];
    [self.audioPlayer stop];
    self.audioPlayer = nil;
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
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.familyContentGuide.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.familyContentGuide.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.familyContentGuide.bottomAnchor],
        [self.contentStack.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor constant:16],
        [self.contentStack.leadingAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.leadingAnchor constant:16],
        [self.contentStack.trailingAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.trailingAnchor constant:-16],
        [self.contentStack.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor constant:-24],
    ]];

    [self setupInfoCard];
    [self setupWaveformCard];
    [self setupPlaybackCard];
    [self setupTransferCard];
    [self setupSummaryCard];
    [self setupActionsCard];
}

- (UIView *)cardViewWithTitle:(NSString *)title content:(UIView *)content {
    UIView *card = [[UIView alloc] init];
    card.backgroundColor = self.familyCardColor;
    card.layer.cornerRadius = 14;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = title;
    titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    titleLabel.textColor = self.familyPrimaryTextColor;

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

- (void)setupInfoCard {
    self.infoLabel = [[UILabel alloc] init];
    self.infoLabel.font = [UIFont systemFontOfSize:15];
    self.infoLabel.textColor = self.familySecondaryTextColor;
    self.infoLabel.numberOfLines = 0;
    self.infoLabel.text = @"加载中…";
    [self.contentStack addArrangedSubview:[self cardViewWithTitle:@"录音信息" content:self.infoLabel]];
}

- (void)setupWaveformCard {
    self.waveformView = [[UIView alloc] init];
    self.waveformView.backgroundColor = [self.familySecondaryTextColor colorWithAlphaComponent:0.1];
    self.waveformView.layer.cornerRadius = 10;
    self.waveformView.layer.masksToBounds = YES;
    self.waveformView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.waveformView.heightAnchor constraintEqualToConstant:80].active = YES;
    [self.contentStack addArrangedSubview:[self cardViewWithTitle:@"振幅" content:self.waveformView]];
}

- (void)setupPlaybackCard {
    self.playButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.playButton setImage:[UIImage systemImageNamed:@"play.fill"] forState:UIControlStateNormal];
    self.playButton.tintColor = self.familyAccentColor;
    self.playButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.playButton.widthAnchor constraintEqualToConstant:44].active = YES;
    [self.playButton addTarget:self action:@selector(playButtonTapped) forControlEvents:UIControlEventTouchUpInside];

    self.progressSlider = [[UISlider alloc] init];
    self.progressSlider.translatesAutoresizingMaskIntoConstraints = NO;
    [self.progressSlider addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];

    self.timeLabel = [[UILabel alloc] init];
    self.timeLabel.font = [UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightRegular];
    self.timeLabel.textColor = self.familySecondaryTextColor;
    self.timeLabel.text = @"00:00 / 00:00";
    self.timeLabel.translatesAutoresizingMaskIntoConstraints = NO;

    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[self.playButton, self.progressSlider]];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.spacing = 12;
    row.alignment = UIStackViewAlignmentCenter;

    UIStackView *content = [[UIStackView alloc] initWithArrangedSubviews:@[row, self.timeLabel]];
    content.axis = UILayoutConstraintAxisVertical;
    content.spacing = 8;

    [self.contentStack addArrangedSubview:[self cardViewWithTitle:@"音频播放" content:content]];
}

- (void)setupTransferCard {
    self.transferStatusLabel = [[UILabel alloc] init];
    self.transferStatusLabel.font = [UIFont systemFontOfSize:13];
    self.transferStatusLabel.textColor = self.familySecondaryTextColor;
    self.transferStatusLabel.text = @"-";

    // 转写内容容器：垂直排列每句话（时间戳 + 文本）。
    self.transferContainer = [[UIStackView alloc] init];
    self.transferContainer.axis = UILayoutConstraintAxisVertical;
    self.transferContainer.spacing = 10;

    UIStackView *content = [[UIStackView alloc] initWithArrangedSubviews:@[self.transferStatusLabel, self.transferContainer]];
    content.axis = UILayoutConstraintAxisVertical;
    content.spacing = 8;

    [self.contentStack addArrangedSubview:[self cardViewWithTitle:@"转写" content:content]];
}

- (void)setupSummaryCard {
    self.summaryStatusLabel = [[UILabel alloc] init];
    self.summaryStatusLabel.font = [UIFont systemFontOfSize:13];
    self.summaryStatusLabel.textColor = self.familySecondaryTextColor;
    self.summaryStatusLabel.text = @"-";

    self.summaryTextView = [[UITextView alloc] init];
    self.summaryTextView.editable = NO;
    self.summaryTextView.selectable = YES;
    self.summaryTextView.backgroundColor = [self.familySecondaryTextColor colorWithAlphaComponent:0.08];
    self.summaryTextView.layer.cornerRadius = 10;
    self.summaryTextView.textContainerInset = UIEdgeInsetsMake(10, 10, 10, 10);
    self.summaryTextView.font = [UIFont systemFontOfSize:15];
    self.summaryTextView.textColor = self.familyPrimaryTextColor;
    self.summaryTextView.text = @"";
    [self.summaryTextView.heightAnchor constraintGreaterThanOrEqualToConstant:100].active = YES;

    UIStackView *content = [[UIStackView alloc] initWithArrangedSubviews:@[self.summaryStatusLabel, self.summaryTextView]];
    content.axis = UILayoutConstraintAxisVertical;
    content.spacing = 8;

    [self.contentStack addArrangedSubview:[self cardViewWithTitle:@"总结" content:content]];
}

- (void)setupActionsCard {
    self.transcribeButton = [self actionButtonWithTitle:@"发起转写" selector:@selector(transcribeButtonTapped)];
    self.summarizeButton = [self actionButtonWithTitle:@"发起总结" selector:@selector(summarizeButtonTapped)];
    self.translateButton = [self actionButtonWithTitle:@"发起翻译" selector:@selector(translateButtonTapped)];

    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[self.transcribeButton, self.summarizeButton, self.translateButton]];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.distribution = UIStackViewDistributionFillEqually;
    row.spacing = 10;

    [self.contentStack addArrangedSubview:[self cardViewWithTitle:@"AI 处理" content:row]];
}

- (UIButton *)actionButtonWithTitle:(NSString *)title selector:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    button.backgroundColor = [self.familyAccentColor colorWithAlphaComponent:0.1];
    [button setTitleColor:self.familyAccentColor forState:UIControlStateNormal];
    button.layer.cornerRadius = 10;
    button.contentEdgeInsets = UIEdgeInsetsMake(10, 8, 10, 8);
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

#pragma mark - Data loading

- (void)loadDetail {
    __weak typeof(self) weakSelf = self;
    [[NativeAudioService sharedInstance] fetchRecordDetailWithRecordId:self.recordId
                                                     amplitudeMaxCount:200
                                                               success:^(ThingAudioRecordFile *file) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.file = file;
        [self populateInfo];
        [self populateWaveform];
        [self prepareAudioPlayer];
        [self loadTransferAndSummary];
    } failure:^(NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self showFamilyMessageWithTitle:@"加载详情失败" message:error.localizedDescription];
    }];
}

- (void)populateInfo {
    ThingAudioRecordFile *f = self.file;
    if (!f) return;
    self.infoLabel.text = [NSString stringWithFormat:
                           @"名称：%@\n"
                           @"时长：%@\n"
                           @"录音时间：%@\n"
                           @"录音类型：%@\n"
                           @"转写状态：%@  ·  总结状态：%@  ·  翻译状态：%@",
                           f.name.length > 0 ? f.name : @"-",
                           [self durationStringFromMs:f.duration],
                           [self dateStringFromSeconds:f.recordTime],
                           [self recordTypeString:f.recordType],
                           [self transferStatusString:f.transfer],
                           [self summaryStatusString:f.summary],
                           [self translateStatusString:f.tranlateState]];
    [self updateTransferStatus:f.transfer];
    [self updateSummaryStatus:f.summary];
}

- (void)loadTransferAndSummary {
    if (!self.file) return;
    long long fileId = self.file.fileId;
    __weak typeof(self) weakSelf = self;

    // 转写：优先取 ASR 表（实时转写产生的分句数据，含时间戳）。
    // 若 ASR 表为空（如离线转写的录音），fallback 到整段文本接口。
    [[NativeAudioService sharedInstance] fetchTranscriptionSentencesWithFileId:fileId success:^(NSArray<ThingAudioRecordAsrResult *> *list) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (list.count > 0) {
            [self populateTransferSentences:list];
        } else {
            // ASR 表为空，fallback 到整段转写文本。
            [self fetchPlainTranscriptionWithFileId:fileId];
        }
    } failure:^(NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self fetchPlainTranscriptionWithFileId:fileId];
    }];

    // 总结：纯文本展示。
    [[NativeAudioService sharedInstance] fetchSummaryWithFileId:fileId success:^(NSString *text) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.summaryTextView.text = text.length > 0 ? text : @"（暂无总结内容）";
    } failure:^(NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.summaryTextView.text = @"";
    }];
}

/// 用 ASR 分句列表填充转写容器：每句一行，左侧时间戳 + 右侧文本。
/// Fallback：ASR 表为空时，取整段转写文本，无时间戳纯文本展示。
- (void)fetchPlainTranscriptionWithFileId:(long long)fileId {
    __weak typeof(self) weakSelf = self;
    [[NativeAudioService sharedInstance] fetchTranscriptionWithFileId:fileId success:^(NSString *text) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        // 清空旧的按句视图，用单条纯文本占位。
        for (UIView *v in self.transferContainer.arrangedSubviews) {
            [self.transferContainer removeArrangedSubview:v];
            [v removeFromSuperview];
        }
        UILabel *plainLabel = [[UILabel alloc] init];
        plainLabel.text = text.length > 0 ? text : @"（暂无转写内容）";
        plainLabel.font = [UIFont systemFontOfSize:15];
        plainLabel.textColor = self.familyPrimaryTextColor;
        plainLabel.numberOfLines = 0;
        [self.transferContainer addArrangedSubview:plainLabel];
    } failure:^(NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        for (UIView *v in self.transferContainer.arrangedSubviews) {
            [self.transferContainer removeArrangedSubview:v];
            [v removeFromSuperview];
        }
        UILabel *errorLabel = [[UILabel alloc] init];
        errorLabel.text = @"（暂无转写内容）";
        errorLabel.font = [UIFont systemFontOfSize:14];
        errorLabel.textColor = self.familySecondaryTextColor;
        [self.transferContainer addArrangedSubview:errorLabel];
    }];
}

/// 用 ASR 分句列表填充转写容器：每句一行，左侧时间戳 + 右侧文本。
- (void)populateTransferSentences:(NSArray<ThingAudioRecordAsrResult *> *)sentences {
    // 清空旧内容。
    for (UIView *v in self.transferContainer.arrangedSubviews) {
        [self.transferContainer removeArrangedSubview:v];
        [v removeFromSuperview];
    }

    if (sentences.count == 0) {
        UILabel *placeholder = [[UILabel alloc] init];
        placeholder.text = @"（暂无转写内容）";
        placeholder.font = [UIFont systemFontOfSize:14];
        placeholder.textColor = self.familySecondaryTextColor;
        [self.transferContainer addArrangedSubview:placeholder];
        return;
    }

    for (ThingAudioRecordAsrResult *sentence in sentences) {
        NSString *text = sentence.text.length > 0 ? sentence.text : sentence.asr;
        if (text.length == 0) continue;
        [self.transferContainer addArrangedSubview:[self transferSentenceRowWithTimestamp:sentence.beginTime text:text]];
    }
}

/// 构建单句行：左侧时间戳（品牌色小字）+ 右侧转写文本。
- (UIView *)transferSentenceRowWithTimestamp:(long long)beginTimeMs text:(NSString *)text {
    UILabel *timeLabel = [[UILabel alloc] init];
    timeLabel.text = [self timeStringFromMs:beginTimeMs];
    timeLabel.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightMedium];
    timeLabel.textColor = self.familyAccentColor;
    timeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [timeLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [timeLabel.widthAnchor constraintEqualToConstant:64].active = YES;

    UILabel *textLabel = [[UILabel alloc] init];
    textLabel.text = text;
    textLabel.font = [UIFont systemFontOfSize:15];
    textLabel.textColor = self.familyPrimaryTextColor;
    textLabel.numberOfLines = 0;
    textLabel.translatesAutoresizingMaskIntoConstraints = NO;

    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[timeLabel, textLabel]];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.alignment = UIStackViewAlignmentTop;
    row.spacing = 10;
    return row;
}

/// 毫秒 → HH:mm:ss 时间戳，例如 7000ms → "00:00:07"。
- (NSString *)timeStringFromMs:(long long)ms {
    long totalSeconds = MAX(0, ms / 1000);
    long hours = totalSeconds / 3600;
    long min = (totalSeconds % 3600) / 60;
    long sec = totalSeconds % 60;
    return [NSString stringWithFormat:@"%02ld:%02ld:%02ld", hours, min, sec];
}

#pragma mark - Waveform rendering

- (void)populateWaveform {
    NSArray<NSNumber *> *amps = [self parseAmplitudes:self.file.amplitudes];
    if (amps.count == 0) return;
    [self renderWaveformWithValues:amps];
}

/// 将逗号分隔的振幅字符串解析为数值数组。
- (NSArray<NSNumber *> *)parseAmplitudes:(NSString *)raw {
    if (raw.length == 0) return @[];
    NSArray<NSString *> *parts = [raw componentsSeparatedByString:@","];
    NSMutableArray<NSNumber *> *result = [NSMutableArray arrayWithCapacity:parts.count];
    for (NSString *part in parts) {
        double value = [part doubleValue];
        if (value > 1.0) value = value / 100.0;
        value = MAX(0.04, MIN(1.0, value));
        [result addObject:@(value)];
    }
    return result;
}

- (void)renderWaveformWithValues:(NSArray<NSNumber *> *)values {
    CGRect bounds = self.waveformView.bounds;
    if (CGRectIsEmpty(bounds) || values.count == 0) return;

    // 清除旧图层。
    for (CALayer *bar in self.waveformBars) { [bar removeFromSuperlayer]; }
    [self.waveformBars removeAllObjects];

    NSUInteger count = values.count;
    CGFloat available = CGRectGetWidth(bounds);
    CGFloat totalSpacing = MAX(0, (CGFloat)(count - 1)) * kDetailWaveformBarSpacing;
    CGFloat barWidth = (available - totalSpacing) / (CGFloat)count;
    // 柱宽限幅：数据少时不至于过粗溢出，数据多时保持最小可见宽度。
    barWidth = MAX(kDetailWaveformBarMinWidth, MIN(barWidth, 6.0));

    CGFloat viewHeight = CGRectGetHeight(bounds);
    CGFloat centerY = CGRectGetMidY(bounds);
    CGFloat stride = barWidth + kDetailWaveformBarSpacing;
    // 从左侧开始排列，确保最右侧不溢出视图边界。
    CGFloat firstCenterX = barWidth / 2.0;

    for (NSUInteger idx = 0; idx < count; idx++) {
        double value = values[idx].doubleValue;
        CGFloat height = MAX(barWidth, round(value * viewHeight * 0.92));
        CGFloat centerX = firstCenterX + (CGFloat)idx * stride;

        CALayer *bar = [CALayer layer];
        bar.backgroundColor = self.familyAccentColor.CGColor;
        bar.cornerRadius = 1.0;
        bar.bounds = CGRectMake(0, 0, barWidth, height);
        bar.position = CGPointMake(centerX, centerY);
        [self.waveformView.layer addSublayer:bar];
        [self.waveformBars addObject:bar];
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    // 视图布局完成后重绘振幅。
    if (self.file.amplitudes.length > 0 && self.waveformBars.count == 0) {
        [self populateWaveform];
    }
}

#pragma mark - Audio playback

- (void)prepareAudioPlayer {
    NSString *path = self.file.filePath;
    if (path.length == 0) {
        [self.playButton setEnabled:NO];
        self.timeLabel.text = @"无音频文件";
        return;
    }
    NSURL *url = [NSURL fileURLWithPath:path];
    NSError *error = nil;
    AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];
    if (error || !player) {
        [self.playButton setEnabled:NO];
        self.timeLabel.text = @"音频加载失败";
        return;
    }
    player.delegate = self;
    [player prepareToPlay];
    self.audioPlayer = player;
    [self updateTimeLabel];
}

- (void)playButtonTapped {
    if (!self.audioPlayer) return;
    if (self.audioPlayer.playing) {
        [self.audioPlayer pause];
        [self.playButton setImage:[UIImage systemImageNamed:@"play.fill"] forState:UIControlStateNormal];
        [self stopPlaybackTimer];
    } else {
        [self.audioPlayer play];
        [self.playButton setImage:[UIImage systemImageNamed:@"pause.fill"] forState:UIControlStateNormal];
        [self startPlaybackTimer];
    }
}

- (void)sliderValueChanged:(UISlider *)slider {
    if (!self.audioPlayer) return;
    self.audioPlayer.currentTime = slider.value * self.audioPlayer.duration;
    [self updateTimeLabel];
}

- (void)startPlaybackTimer {
    [self stopPlaybackTimer];
    self.playTimer = [NSTimer scheduledTimerWithTimeInterval:0.2
                                                      target:self
                                                    selector:@selector(playbackTimerFired)
                                                    userInfo:nil
                                                     repeats:YES];
}

- (void)stopPlaybackTimer {
    [self.playTimer invalidate];
    self.playTimer = nil;
}

- (void)playbackTimerFired {
    [self updateTimeLabel];
}

- (void)updateTimeLabel {
    if (!self.audioPlayer) {
        self.timeLabel.text = @"00:00 / 00:00";
        return;
    }
    NSTimeInterval current = self.audioPlayer.currentTime;
    NSTimeInterval total = self.audioPlayer.duration;
    if (total > 0) {
        self.progressSlider.value = current / total;
    }
    self.timeLabel.text = [NSString stringWithFormat:@"%@ / %@",
                           [self durationStringFromSeconds:current],
                           [self durationStringFromSeconds:total]];
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    [self.playButton setImage:[UIImage systemImageNamed:@"play.fill"] forState:UIControlStateNormal];
    [self stopPlaybackTimer];
    self.progressSlider.value = 0;
    [self updateTimeLabel];
}

#pragma mark - AI processing actions

- (void)transcribeButtonTapped {
    [self processWithTaskType:0 button:self.transcribeButton name:@"转写"];
}

- (void)summarizeButtonTapped {
    [self processWithTaskType:1 button:self.summarizeButton name:@"总结"];
}

- (void)translateButtonTapped {
    [self processWithTaskType:2 button:self.translateButton name:@"翻译"];
}

- (void)processWithTaskType:(NSInteger)taskType button:(UIButton *)button name:(NSString *)name {
    if (self.processing || !self.file) return;
    self.processing = YES;
    [self setProcessingButtonsEnabled:NO];
    NSString *originalTitle = [button titleForState:UIControlStateNormal];
    [button setTitle:[NSString stringWithFormat:@"%@中…", name] forState:UIControlStateNormal];

    NSString *targetLang = self.file.targetLanguage.length > 0 ? self.file.targetLanguage : @"en";
    __weak typeof(self) weakSelf = self;
    [[NativeAudioService sharedInstance] processRecordWithFileId:self.file.fileId
                                                        recordId:self.file.recordId
                                                        taskType:taskType
                                                 translationLang:(taskType == 2 ? targetLang : nil)
                                                        success:^(NSString *taskId) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [button setTitle:originalTitle forState:UIControlStateNormal];
        [self showFamilyMessageWithTitle:[NSString stringWithFormat:@"%@任务已发起", name]
                                 message:@"处理需要一些时间，请稍后返回列表刷新查看结果。"];
        // 延迟 2s 后重新拉取详情，给底层入库时间。
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            self.processing = NO;
            [self setProcessingButtonsEnabled:YES];
            [self loadDetail];
        });
    } progress:^(NSInteger progress) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [button setTitle:[NSString stringWithFormat:@"%@ %ld%%", name, (long)progress] forState:UIControlStateNormal];
    } failure:^(NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [button setTitle:originalTitle forState:UIControlStateNormal];
        self.processing = NO;
        [self setProcessingButtonsEnabled:YES];
        [self showFamilyMessageWithTitle:[NSString stringWithFormat:@"%@失败", name] message:error.localizedDescription];
    }];
}

- (void)setProcessingButtonsEnabled:(BOOL)enabled {
    self.transcribeButton.enabled = enabled;
    self.summarizeButton.enabled = enabled;
    self.translateButton.enabled = enabled;
}

#pragma mark - Status helpers

- (void)updateTransferStatus:(int)transfer {
    self.transferStatusLabel.text = [NSString stringWithFormat:@"状态：%@", [self transferStatusString:transfer]];
}

- (void)updateSummaryStatus:(int)summary {
    self.summaryStatusLabel.text = [NSString stringWithFormat:@"状态：%@", [self summaryStatusString:summary]];
}

- (NSString *)transferStatusString:(int)status {
    switch (status) {
        case 1: return @"转写中";
        case 2: return @"已转写";
        case 3: return @"转写失败";
        case 0:
        default: return @"未转写";
    }
}

- (NSString *)summaryStatusString:(int)status {
    switch (status) {
        case 1: return @"未总结";
        case 2: return @"总结中";
        case 3: return @"已总结";
        case 4: return @"总结失败";
        case 0:
        default: return @"-";
    }
}

- (NSString *)translateStatusString:(int)status {
    switch (status) {
        case 1: return @"未翻译";
        case 2: return @"翻译中";
        case 3: return @"已翻译";
        case 4: return @"翻译失败";
        case 0:
        default: return @"-";
    }
}

- (NSString *)recordTypeString:(ThingAudioRecordType)type {
    switch (type) {
        case ThingAudioRecordTypeCall: return @"电话录音";
        case ThingAudioRecordTypeMeet: return @"会议录音";
        case ThingAudioRecordTypeSimultaneousInterpretation: return @"同声传译";
        case ThingAudioRecordTypeFaceToFace: return @"面对面翻译";
        case ThingAudioRecordTypeImport: return @"音频导入";
        default: return @"-";
    }
}

#pragma mark - Formatting helpers

- (NSString *)durationStringFromMs:(long long)milliseconds {
    return [self durationStringFromSeconds:(NSTimeInterval)(milliseconds / 1000)];
}

- (NSString *)durationStringFromSeconds:(NSTimeInterval)seconds {
    int total = (int)MAX(0, seconds);
    int min = total / 60;
    int sec = total % 60;
    if (min >= 60) {
        return [NSString stringWithFormat:@"%d:%02d:%02d", min / 60, min % 60, sec];
    }
    return [NSString stringWithFormat:@"%02d:%02d", min, sec];
}

- (NSString *)dateStringFromSeconds:(long long)seconds {
    if (seconds <= 0) return @"-";
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:seconds];
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyy-MM-dd HH:mm";
    });
    return [formatter stringFromDate:date];
}

@end
