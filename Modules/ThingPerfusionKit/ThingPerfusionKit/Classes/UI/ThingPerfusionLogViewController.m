//
//  ThingPerfusionLogViewController.m
//  ThingPerfusionKit
//

#import "ThingPerfusionLogViewController.h"
#import "ThingPerfusionLogStore.h"

@interface ThingPerfusionLogViewController ()

@property (nonatomic, strong) UITextView *logTextView;
@property (nonatomic, strong) UILabel *countLabel;
@property (nonatomic, strong) UIButton *exportButton;
@property (nonatomic, strong) UIButton *clearButton;
@property (nonatomic, strong) UISwitch *followSwitch;

@end

@implementation ThingPerfusionLogViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"事件日志";
    [self setupUI];
    [self reloadLog];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(logDidAppend:)
                                               name:ThingPerfusionLogDidAppendNotification
                                             object:nil];
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

#pragma mark - UI

- (void)setupUI {
    self.countLabel = [[UILabel alloc] init];
    self.countLabel.font = [UIFont systemFontOfSize:13];
    self.countLabel.textColor = UIColor.secondaryLabelColor;
    self.countLabel.numberOfLines = 0;
    self.countLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.countLabel];

    self.logTextView = [[UITextView alloc] init];
    self.logTextView.editable = NO;
    self.logTextView.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    self.logTextView.backgroundColor = UIColor.secondarySystemBackgroundColor;
    self.logTextView.layer.cornerRadius = 10;
    self.logTextView.textContainerInset = UIEdgeInsetsMake(10, 10, 10, 10);
    self.logTextView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.logTextView];

    // 实时刷新时自动滚到底部；排查时想往上翻就关掉
    self.followSwitch = [[UISwitch alloc] init];
    self.followSwitch.on = YES;
    UILabel *followLabel = [[UILabel alloc] init];
    followLabel.text = @"自动滚动到最新";
    followLabel.font = [UIFont systemFontOfSize:14];
    followLabel.textColor = UIColor.labelColor;

    self.exportButton = [self buttonWithTitle:@"导出日志" action:@selector(exportTapped:) primary:YES];
    self.clearButton = [self buttonWithTitle:@"清空" action:@selector(clearTapped:) primary:NO];

    UIStackView *followRow = [[UIStackView alloc] initWithArrangedSubviews:@[followLabel, self.followSwitch]];
    followRow.spacing = 10;
    UIStackView *buttonRow = [[UIStackView alloc] initWithArrangedSubviews:@[self.clearButton, self.exportButton]];
    buttonRow.spacing = 10;
    buttonRow.distribution = UIStackViewDistributionFillEqually;

    UIStackView *bottomStack = [[UIStackView alloc] initWithArrangedSubviews:@[followRow, buttonRow]];
    bottomStack.axis = UILayoutConstraintAxisVertical;
    bottomStack.spacing = 12;
    bottomStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:bottomStack];

    [NSLayoutConstraint activateConstraints:@[
        [self.countLabel.topAnchor constraintEqualToAnchor:self.contentGuide.topAnchor constant:12],
        [self.countLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.countLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],

        [self.logTextView.topAnchor constraintEqualToAnchor:self.countLabel.bottomAnchor constant:10],
        [self.logTextView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.logTextView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.logTextView.bottomAnchor constraintEqualToAnchor:bottomStack.topAnchor constant:-12],

        [bottomStack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [bottomStack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [bottomStack.bottomAnchor constraintEqualToAnchor:self.contentGuide.bottomAnchor constant:-16],
    ]];
}

- (UIButton *)buttonWithTitle:(NSString *)title action:(SEL)action primary:(BOOL)primary {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    button.layer.cornerRadius = 10;
    button.contentEdgeInsets = UIEdgeInsetsMake(12, 14, 12, 14);
    if (primary) {
        button.backgroundColor = UIColor.systemBlueColor;
        [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    } else {
        button.backgroundColor = [UIColor.systemRedColor colorWithAlphaComponent:0.12];
        [button setTitleColor:UIColor.systemRedColor forState:UIControlStateNormal];
    }
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

#pragma mark - 数据

- (void)reloadLog {
    NSArray<NSString *> *entries = [ThingPerfusionLogStore sharedInstance].entries;
    self.countLabel.text = [NSString stringWithFormat:
        @"共 %lu 条 ｜ 记录 SDK 调用与回调事件（start/stop、录音状态、实时识别、配置回读、WER 结果）",
        (unsigned long)entries.count];
    self.logTextView.text = entries.count > 0
        ? [entries componentsJoinedByString:@"\n"]
        : @"暂无日志。回到灌流页执行一次灌流即可产生记录。";
    if (self.followSwitch.isOn) [self scrollToBottom];
    [self updateControls];
}

- (void)logDidAppend:(NSNotification *)notification {
    [self reloadLog];
}

- (void)scrollToBottom {
    if (self.logTextView.text.length == 0) return;
    [self.logTextView scrollRangeToVisible:NSMakeRange(self.logTextView.text.length - 1, 1)];
}

- (void)updateControls {
    BOOL hasLog = [ThingPerfusionLogStore sharedInstance].entries.count > 0;
    self.exportButton.enabled = hasLog;
    self.exportButton.alpha = hasLog ? 1.0 : 0.4;
    self.clearButton.enabled = hasLog;
    self.clearButton.alpha = hasLog ? 1.0 : 0.4;
}

#pragma mark - 操作

- (void)exportTapped:(UIButton *)sender {
    NSError *error = nil;
    NSURL *url = [[ThingPerfusionLogStore sharedInstance] writeToFileWithError:&error];
    if (!url) {
        [self showMessageWithTitle:@"导出失败" message:error.localizedDescription ?: @"未知错误"];
        return;
    }
    UIActivityViewController *activity =
        [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
    // iPad 上必须给出弹出锚点，否则会崩。
    activity.popoverPresentationController.sourceView = sender;
    activity.popoverPresentationController.sourceRect = sender.bounds;
    [self presentViewController:activity animated:YES completion:nil];
}

- (void)clearTapped:(UIButton *)sender {
    __weak typeof(self) weakSelf = self;
    [self showConfirmationWithTitle:@"清空日志"
                           message:@"已记录的事件日志将被清除，导出过的文件不受影响。"
                      confirmTitle:@"清空"
                       destructive:YES
                           confirm:^{
        [[ThingPerfusionLogStore sharedInstance] clear];
        [weakSelf reloadLog];
    }];
}

@end
