//
//  DeviceListView.h
//  AIVoiceDemo
//
//  Created by Bacson on 2026/1/29.
//

#import <UIKit/UIKit.h>
#import <ThingSmartDeviceKit/ThingSmartDeviceKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol DeviceListViewDelegate <NSObject>

@optional
- (void)deviceListView:(UIView *)view didSelectDevice:(ThingSmartDeviceModel *)device;

@end

@interface DeviceListView : UIView

@property (nonatomic, weak) id<DeviceListViewDelegate> delegate;

/**
 * 刷新设备列表
 */
- (void)reloadDevices:(NSArray<ThingSmartDeviceModel *> *)devices;

/**
 * 显示空状态
 */
- (void)showEmptyState;

/**
 * 隐藏空状态
 */
- (void)hideEmptyState;

@end

NS_ASSUME_NONNULL_END
