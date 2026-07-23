//
//  NativeRecordListCell.m
//  AIVoiceDemo
//

#import "NativeRecordListCell.h"
#import <ThingAudioRecordInterface/ThingAudioRecordInterface.h>

#pragma mark - Theme colors (mirrors FamilyBaseViewController tokens)

static UIColor *nativeCardColor(void) { return UIColor.whiteColor; }
static UIColor *nativePrimaryText(void) {
    return [UIColor colorWithRed:0.11 green:0.12 blue:0.15 alpha:1.0];
}
static UIColor *nativeSecondaryText(void) {
    return [UIColor colorWithRed:0.53 green:0.55 blue:0.60 alpha:1.0];
}
static UIColor *nativeAccentColor(void) {
    return [UIColor colorWithRed:1.0 green:0.33 blue:0.17 alpha:1.0];
}
static UIColor *nativeDestructiveColor(void) {
    return [UIColor colorWithRed:0.95 green:0.22 blue:0.22 alpha:1.0];
}

@interface NativeRecordListCell ()
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIView *statusDot;
@property (nonatomic, strong) UILabel *statusLabel;
@end

@implementation NativeRecordListCell

+ (NSString *)reuseIdentifier {
    return @"NativeRecordListCell";
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self setupViews];
    }
    return self;
}

- (void)setupViews {
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.layoutMargins = UIEdgeInsetsMake(0, 16, 0, 16);
    self.preservesSuperviewLayoutMargins = NO;

    self.cardView = [[UIView alloc] init];
    self.cardView.backgroundColor = nativeCardColor();
    self.cardView.layer.cornerRadius = 20;
    self.cardView.layer.masksToBounds = YES;
    self.cardView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.cardView];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    self.titleLabel.textColor = nativePrimaryText();
    self.titleLabel.numberOfLines = 1;
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;

    self.subtitleLabel = [[UILabel alloc] init];
    self.subtitleLabel.font = [UIFont systemFontOfSize:14];
    self.subtitleLabel.textColor = nativeSecondaryText();
    self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;

    self.statusDot = [[UIView alloc] init];
    self.statusDot.layer.cornerRadius = 4;
    self.statusDot.layer.masksToBounds = YES;
    self.statusDot.translatesAutoresizingMaskIntoConstraints = NO;

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.font = [UIFont systemFontOfSize:12];
    self.statusLabel.textColor = nativeSecondaryText();
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;

    [self.cardView addSubview:self.titleLabel];
    [self.cardView addSubview:self.subtitleLabel];
    [self.cardView addSubview:self.statusDot];
    [self.cardView addSubview:self.statusLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:5],
        [self.cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-5],

        [self.titleLabel.topAnchor constraintEqualToAnchor:self.cardView.topAnchor constant:14],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:16],
        [self.titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.statusLabel.leadingAnchor constant:-8],

        [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:4],
        [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.subtitleLabel.bottomAnchor constraintEqualToAnchor:self.cardView.bottomAnchor constant:-14],

        [self.statusLabel.topAnchor constraintEqualToAnchor:self.titleLabel.topAnchor],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-16],

        [self.statusDot.centerYAnchor constraintEqualToAnchor:self.statusLabel.centerYAnchor],
        [self.statusDot.trailingAnchor constraintEqualToAnchor:self.statusLabel.leadingAnchor constant:-5],
        [self.statusDot.widthAnchor constraintEqualToConstant:8],
        [self.statusDot.heightAnchor constraintEqualToConstant:8],
    ]];
}

#pragma mark - Configuration

- (void)configureWithRecordFile:(ThingAudioRecordFile *)file {
    self.titleLabel.text = file.name.length > 0 ? file.name : @"未命名录音";
    self.subtitleLabel.text = [NSString stringWithFormat:@"%@  ·  %@",
                               [self dateStringFromSeconds:file.recordTime],
                               [self durationStringFromMs:file.duration]];
    [self applyTransferStatus:file.transfer];
}

- (void)configureWithSearchItem:(ThingAudioRecordSearchMixResultItem *)item {
    self.titleLabel.text = item.title.length > 0 ? item.title : @"未命名录音";
    self.subtitleLabel.text = [NSString stringWithFormat:@"%@  ·  %@",
                               [self dateStringFromSeconds:item.recordTime],
                               [self durationStringFromMs:item.duration]];
    // 搜索结果没有 transfer 字段，统一显示为搜索命中状态。
    self.statusLabel.text = @"搜索命中";
    self.statusDot.backgroundColor = nativeAccentColor();
}

/// transfer: 0 未转写，1 转写中，2 已转写，3 转写失败
- (void)applyTransferStatus:(int)transfer {
    switch (transfer) {
        case 1:
            self.statusLabel.text = @"转写中";
            self.statusDot.backgroundColor = nativeAccentColor();
            break;
        case 2:
            self.statusLabel.text = @"已转写";
            self.statusDot.backgroundColor = UIColor.systemGreenColor;
            break;
        case 3:
            self.statusLabel.text = @"转写失败";
            self.statusDot.backgroundColor = nativeDestructiveColor();
            break;
        case 0:
        default:
            self.statusLabel.text = @"未转写";
            self.statusDot.backgroundColor = nativeSecondaryText();
            break;
    }
}

#pragma mark - Formatting helpers

- (NSString *)dateStringFromSeconds:(long long)seconds {
    if (seconds <= 0) return @"-";
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:seconds];
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"MM-dd HH:mm";
    });
    return [formatter stringFromDate:date];
}

- (NSString *)durationStringFromMs:(long long)milliseconds {
    long totalSeconds = MAX(0, milliseconds / 1000);
    long min = totalSeconds / 60;
    long sec = totalSeconds % 60;
    if (min >= 60) {
        return [NSString stringWithFormat:@"%ld:%02ld:%02ld", min / 60, min % 60, sec];
    }
    return [NSString stringWithFormat:@"%ld:%02ld", min, sec];
}

@end
