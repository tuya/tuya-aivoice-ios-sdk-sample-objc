//
//  DeviceListView.m
//  AIVoiceDemo
//
//  Created by Bacson on 2026/1/29.
//

#import "DeviceListView.h"
#import <ThingSmartDeviceKit/ThingSmartDeviceKit.h>

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
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    layout.minimumInteritemSpacing = 12;
    layout.minimumLineSpacing = 12;
    layout.sectionInset = UIEdgeInsetsMake(0, 20, 0, 20);
    
    // 创建 CollectionView
    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.collectionView.backgroundColor = [UIColor clearColor];
    self.collectionView.showsHorizontalScrollIndicator = NO;
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
    cardView.backgroundColor = [UIColor secondarySystemBackgroundColor];
    cardView.layer.cornerRadius = 12;
    cardView.layer.shadowColor = [UIColor blackColor].CGColor;
    cardView.layer.shadowOffset = CGSizeMake(0, 2);
    cardView.layer.shadowRadius = 4;
    cardView.layer.shadowOpacity = 0.1;
    cardView.translatesAutoresizingMaskIntoConstraints = NO;
    [cell.contentView addSubview:cardView];
    
    // 设备图标
    UIImageView *iconImageView = [[UIImageView alloc] init];
    iconImageView.image = [UIImage systemImageNamed:@"headphones"];
    iconImageView.tintColor = [UIColor systemBlueColor];
    iconImageView.contentMode = UIViewContentModeScaleAspectFit;
    iconImageView.translatesAutoresizingMaskIntoConstraints = NO;
    [cardView addSubview:iconImageView];
    
    // 设备名称
    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.text = device.name ?: @"未命名设备";
    nameLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    nameLabel.textColor = [UIColor labelColor];
    nameLabel.textAlignment = NSTextAlignmentCenter;
    nameLabel.numberOfLines = 2;
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [cardView addSubview:nameLabel];
    
    // 设备状态
    UILabel *statusLabel = [[UILabel alloc] init];
    BOOL isOnline = device.isOnline;
    statusLabel.text = isOnline ? @"在线" : @"离线";
    statusLabel.font = [UIFont systemFontOfSize:12];
    statusLabel.textColor = isOnline ? [UIColor systemGreenColor] : [UIColor secondaryLabelColor];
    statusLabel.textAlignment = NSTextAlignmentCenter;
    statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [cardView addSubview:statusLabel];
    
    // 布局约束
    [NSLayoutConstraint activateConstraints:@[
        [cardView.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor],
        [cardView.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor],
        [cardView.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor],
        [cardView.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor],
        
        [iconImageView.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:16],
        [iconImageView.centerXAnchor constraintEqualToAnchor:cardView.centerXAnchor],
        [iconImageView.widthAnchor constraintEqualToConstant:40],
        [iconImageView.heightAnchor constraintEqualToConstant:40],
        
        [nameLabel.topAnchor constraintEqualToAnchor:iconImageView.bottomAnchor constant:8],
        [nameLabel.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:8],
        [nameLabel.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-8],
        
        [statusLabel.topAnchor constraintEqualToAnchor:nameLabel.bottomAnchor constant:4],
        [statusLabel.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:8],
        [statusLabel.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-8],
        [statusLabel.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor constant:-12],
    ]];
    
    return cell;
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return CGSizeMake(120, 140);
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    ThingSmartDeviceModel *device = self.devices[indexPath.item];
    if ([self.delegate respondsToSelector:@selector(deviceListView:didSelectDevice:)]) {
        [self.delegate deviceListView:self didSelectDevice:device];
    }
}

@end
