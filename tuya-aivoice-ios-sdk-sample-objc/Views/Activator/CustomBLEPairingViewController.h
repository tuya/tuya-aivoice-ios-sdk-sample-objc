//
//  CustomBLEPairingViewController.h
//  tuya-aivoice-ios-sdk-sample-objc
//

#import "FamilyBaseViewController.h"

@class CustomBLEPairingDevice;

NS_ASSUME_NONNULL_BEGIN

typedef void (^CustomBLEPairingViewCompletion)(CustomBLEPairingDevice *device);

@interface CustomBLEPairingViewController : FamilyBaseViewController

- (instancetype)initWithHomeID:(long long)homeID
                     completion:(nullable CustomBLEPairingViewCompletion)completion NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
