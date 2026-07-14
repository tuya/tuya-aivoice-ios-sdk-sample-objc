//
//  CustomBLEPairingSession.h
//  tuya-aivoice-ios-sdk-sample-objc
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, CustomBLEPairingState) {
    CustomBLEPairingStateIdle,
    CustomBLEPairingStateScanning,
    CustomBLEPairingStateAcquiringToken,
    CustomBLEPairingStateActivating,
    CustomBLEPairingStateSucceeded,
    CustomBLEPairingStateFailed,
    CustomBLEPairingStateCancelled,
};

@interface CustomBLEPairingDevice : NSObject

@property (nonatomic, copy, readonly) NSString *identifier;
@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, copy, readonly) NSString *productID;
@property (nonatomic, copy, readonly) NSString *typeDescription;
@property (nonatomic, copy, readonly) NSString *statusDescription;
@property (nonatomic, copy, readonly, nullable) NSString *deviceID;

- (instancetype)initWithIdentifier:(NSString *)identifier
                              name:(NSString *)name
                         productID:(NSString *)productID
                    typeDescription:(NSString *)typeDescription
                  statusDescription:(NSString *)statusDescription
                          deviceID:(nullable NSString *)deviceID NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

@interface CustomBLEPairingFailure : NSObject

@property (nonatomic, copy, readonly) NSString *stage;
@property (nonatomic, assign, readonly) NSInteger code;
@property (nonatomic, copy, readonly) NSString *message;
@property (nonatomic, assign, readonly, getter=isRetryable) BOOL retryable;

- (instancetype)initWithStage:(NSString *)stage
                          code:(NSInteger)code
                       message:(NSString *)message
                     retryable:(BOOL)retryable NS_DESIGNATED_INITIALIZER;

+ (instancetype)failureForStage:(NSString *)stage sdkError:(nullable NSError *)error;

- (instancetype)init NS_UNAVAILABLE;

@end


@interface CustomBLEPairingSnapshot : NSObject

@property (nonatomic, assign, readonly) CustomBLEPairingState state;
@property (nonatomic, copy, readonly) NSArray<CustomBLEPairingDevice *> *devices;
@property (nonatomic, strong, readonly, nullable) CustomBLEPairingFailure *failure;
@property (nonatomic, strong, readonly, nullable) CustomBLEPairingDevice *resultDevice;
@property (nonatomic, copy, readonly) NSString *logLine;
@property (nonatomic, assign, readonly) NSTimeInterval elapsed;

@end

typedef void (^CustomBLEPairingEventHandler)(CustomBLEPairingSnapshot *snapshot);
typedef void (^CustomBLEPairingDeviceHandler)(CustomBLEPairingDevice *device);
typedef void (^CustomBLEPairingFailureHandler)(CustomBLEPairingFailure *failure);
typedef void (^CustomBLEPairingTokenCompletion)(NSString * _Nullable token, CustomBLEPairingFailure * _Nullable failure);
typedef void (^CustomBLEPairingActivationCompletion)(CustomBLEPairingDevice * _Nullable device, CustomBLEPairingFailure * _Nullable failure);

@protocol CustomBLEPairingAdapter <NSObject>

- (void)startScanningForHomeID:(long long)homeID
                 deviceHandler:(CustomBLEPairingDeviceHandler)deviceHandler
                 failureHandler:(CustomBLEPairingFailureHandler)failureHandler;
- (void)stopScanningAndClearCache:(BOOL)clearCache;
- (void)requestTokenForHomeID:(long long)homeID completion:(CustomBLEPairingTokenCompletion)completion;
- (void)activateDeviceWithIdentifier:(NSString *)identifier
                              homeID:(long long)homeID
                               token:(NSString *)token
                          completion:(CustomBLEPairingActivationCompletion)completion;
- (void)cancelAndClearCache;

@end

@interface CustomBLEPairingSession : NSObject

- (instancetype)init;
- (instancetype)initWithAdapter:(id<CustomBLEPairingAdapter>)adapter NS_DESIGNATED_INITIALIZER;

- (void)startWithHomeID:(long long)homeID eventHandler:(CustomBLEPairingEventHandler)eventHandler;
- (void)activateDeviceWithIdentifier:(NSString *)identifier;
- (void)cancel;

@end


FOUNDATION_EXPORT NSString *CustomBLEPairingStateDescription(CustomBLEPairingState state);

NS_ASSUME_NONNULL_END
