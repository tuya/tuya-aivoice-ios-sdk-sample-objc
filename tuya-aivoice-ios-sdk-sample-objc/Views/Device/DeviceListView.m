//
//  DeviceListView.m
//  AIVoiceDemo
//
//  Created by Bacson on 2026/1/29.
//

#import "DeviceListView.h"
#import <ThingSmartDeviceKit/ThingSmartDeviceKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

// 渐变图标容器视图
@interface GradientIconView : UIView
@property (nonatomic, strong) CAGradientLayer *gradientLayer;
@end

@implementation GradientIconView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.gradientLayer = [CAGradientLayer layer];
        self.gradientLayer.colors = @[
            (__bridge id)[UIColor colorWithRed:0.2 green:0.4 blue:1.0 alpha:1.0].CGColor,
            (__bridge id)[UIColor colorWithRed:0.4 green:0.6 blue:1.0 alpha:1.0].CGColor
        ];
        self.gradientLayer.startPoint = CGPointMake(0, 0);
        self.gradientLayer.endPoint = CGPointMake(1, 1);
        self.gradientLayer.cornerRadius = 20;
        [self.layer insertSublayer:self.gradientLayer atIndex:0];
        self.layer.cornerRadius = 20;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.gradientLayer.frame = self.bounds;
}

@end

@interface DeviceListView () <UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout>

@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) NSArray<ThingSmartDeviceModel *> *devices;

@end

@implementation DeviceListView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
        self.devices = @[];
    }
    return self;
}

- (void)setupUI {
    self.backgroundColor = [UIColor clearColor];
    
    // 创建布局
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionVertical;
    layout.minimumInteritemSpacing = 0;
    layout.minimumLineSpacing = 12;
    layout.sectionInset = UIEdgeInsetsMake(0, 20, 0, 20);
    
    // 创建 CollectionView
    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.collectionView.backgroundColor = [UIColor clearColor];
    self.collectionView.showsVerticalScrollIndicator = YES;
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.collectionView];
    
    // 注册 Cell
    [self.collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"DeviceCell"];
    
    // 空状态标签
    self.emptyLabel = [[UILabel alloc] init];
    self.emptyLabel.text = @"暂无设备\n点击上方 添加设备 开始配网";
    self.emptyLabel.textColor = [UIColor secondaryLabelColor];
    self.emptyLabel.font = [UIFont systemFontOfSize:14];
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.numberOfLines = 0;
    self.emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyLabel.hidden = YES;
    [self addSubview:self.emptyLabel];
    
    // 布局约束
    [NSLayoutConstraint activateConstraints:@[
        [self.collectionView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.collectionView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.collectionView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.collectionView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        
        [self.emptyLabel.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [self.emptyLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [self.emptyLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:40],
        [self.emptyLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-40],
    ]];
}

- (void)reloadDevices:(NSArray<ThingSmartDeviceModel *> *)devices {
    self.devices = devices ?: @[];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.collectionView reloadData];
        if (self.devices.count == 0) {
            [self showEmptyState];
        } else {
            [self hideEmptyState];
        }
    });
}

- (void)showEmptyState {
    self.emptyLabel.hidden = NO;
    self.collectionView.hidden = YES;
}

- (void)hideEmptyState {
    self.emptyLabel.hidden = YES;
    self.collectionView.hidden = NO;
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.devices.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"DeviceCell" forIndexPath:indexPath];
    
    // 移除之前的子视图
    for (UIView *subview in cell.contentView.subviews) {
        [subview removeFromSuperview];
    }
    
    ThingSmartDeviceModel *device = self.devices[indexPath.item];
    
    // 创建卡片视图
    UIView *cardView = [[UIView alloc] init];
    cardView.backgroundColor = [UIColor whiteColor];
    cardView.layer.cornerRadius = 16;
    cardView.layer.shadowColor = [UIColor blackColor].CGColor;
    cardView.layer.shadowOffset = CGSizeMake(0, 2);
    cardView.layer.shadowRadius = 8;
    cardView.layer.shadowOpacity = 0.1;
    cardView.translatesAutoresizingMaskIntoConstraints = NO;
    [cell.contentView addSubview:cardView];
    
    // 设备图标容器（带渐变背景）
    GradientIconView *iconContainer = [[GradientIconView alloc] init];
    iconContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [cardView addSubview:iconContainer];
    
    // 设备图标 - 使用更精美的耳机图标
    UIImageView *iconImageView = [[UIImageView alloc] init];
    UIImage *headphoneImage = [UIImage systemImageNamed:@"airpodspro"];
    if (!headphoneImage) {
        headphoneImage = [UIImage systemImageNamed:@"beats.headphones"];
    }
    if (!headphoneImage) {
        headphoneImage = [UIImage systemImageNamed:@"headphones"];
    }
    iconImageView.image = headphoneImage;
    iconImageView.tintColor = [UIColor whiteColor];
    iconImageView.contentMode = UIViewContentModeScaleAspectFit;
    iconImageView.translatesAutoresizingMaskIntoConstraints = NO;
    [iconContainer addSubview:iconImageView];
    
    // 设备名称
    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.text = device.name ?: @"未命名设备";
    nameLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    nameLabel.textColor = [UIColor labelColor];
    nameLabel.textAlignment = NSTextAlignmentLeft;
    nameLabel.numberOfLines = 1;
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [cardView addSubview:nameLabel];
    
    // 右箭头图标
    UIImageView *arrowImageView = [[UIImageView alloc] init];
    arrowImageView.image = [UIImage systemImageNamed:@"chevron.right"];
    arrowImageView.tintColor = [UIColor secondaryLabelColor];
    arrowImageView.translatesAutoresizingMaskIntoConstraints = NO;
    [cardView addSubview:arrowImageView];
    
    // 布局约束
    [NSLayoutConstraint activateConstraints:@[
        [cardView.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor],
        [cardView.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor],
        [cardView.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor],
        [cardView.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor],
        
        // 图标容器
        [iconContainer.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:16],
        [iconContainer.centerYAnchor constraintEqualToAnchor:cardView.centerYAnchor],
        [iconContainer.widthAnchor constraintEqualToConstant:56],
        [iconContainer.heightAnchor constraintEqualToConstant:56],
        
        // 图标
        [iconImageView.centerXAnchor constraintEqualToAnchor:iconContainer.centerXAnchor],
        [iconImageView.centerYAnchor constraintEqualToAnchor:iconContainer.centerYAnchor],
        [iconImageView.widthAnchor constraintEqualToConstant:32],
        [iconImageView.heightAnchor constraintEqualToConstant:32],
        
        // 设备名称
        [nameLabel.leadingAnchor constraintEqualToAnchor:iconContainer.trailingAnchor constant:16],
        [nameLabel.centerYAnchor constraintEqualToAnchor:cardView.centerYAnchor],
        [nameLabel.trailingAnchor constraintEqualToAnchor:arrowImageView.leadingAnchor constant:-12],
        
        // 右箭头
        [arrowImageView.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-16],
        [arrowImageView.centerYAnchor constraintEqualToAnchor:cardView.centerYAnchor],
        [arrowImageView.widthAnchor constraintEqualToConstant:12],
        [arrowImageView.heightAnchor constraintEqualToConstant:20],
    ]];
    
    return cell;
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat width = collectionView.bounds.size.width - 40; // 减去左右边距
    return CGSizeMake(width, 88);
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    ThingSmartDeviceModel *device = self.devices[indexPath.item];
    if ([self.delegate respondsToSelector:@selector(deviceListView:didSelectDevice:)]) {
        [self.delegate deviceListView:self didSelectDevice:device];
    }
}

@end
