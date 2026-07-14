@import XCTest;

#import "CustomBLEPairingSession.h"

@interface FakeBLEPairingAdapter : NSObject <CustomBLEPairingAdapter>
@property (nonatomic, assign) long long startedHomeID;
@property (nonatomic, copy) CustomBLEPairingDeviceHandler deviceHandler;
@property (nonatomic, copy) CustomBLEPairingFailureHandler scanFailureHandler;
@property (nonatomic, copy) CustomBLEPairingTokenCompletion tokenCompletion;
@property (nonatomic, copy) CustomBLEPairingActivationCompletion activationCompletion;
@property (nonatomic, copy) NSString *activatedIdentifier;
@property (nonatomic, assign) NSUInteger tokenRequestCount;
@property (nonatomic, assign) BOOL cancelled;
@end

@implementation FakeBLEPairingAdapter
- (void)startScanningForHomeID:(long long)homeID deviceHandler:(CustomBLEPairingDeviceHandler)deviceHandler failureHandler:(CustomBLEPairingFailureHandler)failureHandler {
    self.startedHomeID = homeID;
    self.deviceHandler = deviceHandler;
    self.scanFailureHandler = failureHandler;
}
- (void)stopScanningAndClearCache:(BOOL)clearCache {}
- (void)requestTokenForHomeID:(long long)homeID completion:(CustomBLEPairingTokenCompletion)completion {
    self.tokenRequestCount += 1;
    self.tokenCompletion = completion;
}
- (void)activateDeviceWithIdentifier:(NSString *)identifier homeID:(long long)homeID token:(NSString *)token completion:(CustomBLEPairingActivationCompletion)completion {
    self.activatedIdentifier = identifier;
    self.activationCompletion = completion;
}
- (void)cancelAndClearCache { self.cancelled = YES; }
@end

@interface CustomBLEPairingSessionTests : XCTestCase
@end

@implementation CustomBLEPairingSessionTests

- (void)testStartBeginsScanningForCurrentHome {
    FakeBLEPairingAdapter *adapter = [FakeBLEPairingAdapter new];
    CustomBLEPairingSession *session = [[CustomBLEPairingSession alloc] initWithAdapter:adapter];
    __block CustomBLEPairingSnapshot *latestSnapshot = nil;

    [session startWithHomeID:42 eventHandler:^(CustomBLEPairingSnapshot *snapshot) {
        latestSnapshot = snapshot;
    }];

    XCTAssertEqual(adapter.startedHomeID, 42);
    XCTAssertEqual(latestSnapshot.state, CustomBLEPairingStateScanning);
}

- (void)testRepeatedDiscoveryUpdatesOneDeviceRow {
    FakeBLEPairingAdapter *adapter = [FakeBLEPairingAdapter new];
    CustomBLEPairingSession *session = [[CustomBLEPairingSession alloc] initWithAdapter:adapter];
    __block CustomBLEPairingSnapshot *latestSnapshot = nil;
    [session startWithHomeID:42 eventHandler:^(CustomBLEPairingSnapshot *snapshot) { latestSnapshot = snapshot; }];

    adapter.deviceHandler([[CustomBLEPairingDevice alloc] initWithIdentifier:@"ble-1" name:@"旧名称" productID:@"pid" typeDescription:@"BLE 单点" statusDescription:@"待配网" deviceID:nil]);
    adapter.deviceHandler([[CustomBLEPairingDevice alloc] initWithIdentifier:@"ble-1" name:@"新名称" productID:@"pid" typeDescription:@"BLE 单点" statusDescription:@"待配网" deviceID:nil]);

    XCTAssertEqual(latestSnapshot.devices.count, 1);
    XCTAssertEqualObjects(latestSnapshot.devices.firstObject.name, @"新名称");
}

- (void)testInvalidHomeFailsBeforeStartingAdapter {
    FakeBLEPairingAdapter *adapter = [FakeBLEPairingAdapter new];
    CustomBLEPairingSession *session = [[CustomBLEPairingSession alloc] initWithAdapter:adapter];
    __block CustomBLEPairingSnapshot *latestSnapshot = nil;

    [session startWithHomeID:0 eventHandler:^(CustomBLEPairingSnapshot *snapshot) { latestSnapshot = snapshot; }];

    XCTAssertEqual(adapter.startedHomeID, 0);
    XCTAssertEqual(latestSnapshot.state, CustomBLEPairingStateFailed);
    XCTAssertEqualObjects(latestSnapshot.failure.stage, @"preflight");
    XCTAssertFalse(latestSnapshot.failure.isRetryable);
}

- (void)testSelectedDeviceUsesFreshTokenAndSucceeds {
    FakeBLEPairingAdapter *adapter = [FakeBLEPairingAdapter new];
    CustomBLEPairingSession *session = [[CustomBLEPairingSession alloc] initWithAdapter:adapter];
    __block CustomBLEPairingSnapshot *latestSnapshot = nil;
    [session startWithHomeID:42 eventHandler:^(CustomBLEPairingSnapshot *snapshot) { latestSnapshot = snapshot; }];
    CustomBLEPairingDevice *candidate = [[CustomBLEPairingDevice alloc] initWithIdentifier:@"ble-1" name:@"耳机" productID:@"pid" typeDescription:@"BLE 单点" statusDescription:@"待配网" deviceID:nil];
    adapter.deviceHandler(candidate);

    [session activateDeviceWithIdentifier:@"ble-1"];
    [session activateDeviceWithIdentifier:@"ble-1"];
    XCTAssertEqual(latestSnapshot.state, CustomBLEPairingStateAcquiringToken);
    XCTAssertEqual(adapter.tokenRequestCount, 1);

    adapter.tokenCompletion(@"fresh-token", nil);
    XCTAssertEqual(latestSnapshot.state, CustomBLEPairingStateActivating);
    XCTAssertEqualObjects(adapter.activatedIdentifier, @"ble-1");

    CustomBLEPairingDevice *activated = [[CustomBLEPairingDevice alloc] initWithIdentifier:@"ble-1" name:@"耳机" productID:@"pid" typeDescription:@"BLE 单点" statusDescription:@"已激活" deviceID:@"dev-123"];
    adapter.activationCompletion(activated, nil);
    XCTAssertEqual(latestSnapshot.state, CustomBLEPairingStateSucceeded);
    XCTAssertEqualObjects(latestSnapshot.resultDevice.deviceID, @"dev-123");
}

- (void)testCancelSuppressesLateCallbacks {
    FakeBLEPairingAdapter *adapter = [FakeBLEPairingAdapter new];
    CustomBLEPairingSession *session = [[CustomBLEPairingSession alloc] initWithAdapter:adapter];
    __block CustomBLEPairingSnapshot *latestSnapshot = nil;
    [session startWithHomeID:42 eventHandler:^(CustomBLEPairingSnapshot *snapshot) { latestSnapshot = snapshot; }];
    CustomBLEPairingDeviceHandler lateDeviceHandler = adapter.deviceHandler;

    [session cancel];
    lateDeviceHandler([[CustomBLEPairingDevice alloc] initWithIdentifier:@"late" name:@"迟到设备" productID:@"pid" typeDescription:@"BLE 单点" statusDescription:@"待配网" deviceID:nil]);

    XCTAssertTrue(adapter.cancelled);
    XCTAssertEqual(latestSnapshot.state, CustomBLEPairingStateCancelled);
    XCTAssertEqual(latestSnapshot.devices.count, 0);
}

- (void)testTokenFailureDoesNotStartActivation {
    FakeBLEPairingAdapter *adapter = [FakeBLEPairingAdapter new];
    CustomBLEPairingSession *session = [[CustomBLEPairingSession alloc] initWithAdapter:adapter];
    __block CustomBLEPairingSnapshot *latestSnapshot = nil;
    [session startWithHomeID:42 eventHandler:^(CustomBLEPairingSnapshot *snapshot) { latestSnapshot = snapshot; }];
    adapter.deviceHandler([[CustomBLEPairingDevice alloc] initWithIdentifier:@"ble-1" name:@"耳机" productID:@"pid" typeDescription:@"BLE 单点" statusDescription:@"待配网" deviceID:nil]);

    [session activateDeviceWithIdentifier:@"ble-1"];
    CustomBLEPairingFailure *failure = [[CustomBLEPairingFailure alloc] initWithStage:@"token" code:401 message:@"Token 获取失败" retryable:YES];
    adapter.tokenCompletion(nil, failure);

    XCTAssertEqual(latestSnapshot.state, CustomBLEPairingStateFailed);
    XCTAssertEqualObjects(latestSnapshot.failure.stage, @"token");
    XCTAssertNil(adapter.activatedIdentifier);
    XCTAssertTrue(adapter.cancelled);
}

- (void)testCancelWhileAcquiringTokenSuppressesLateToken {
    FakeBLEPairingAdapter *adapter = [FakeBLEPairingAdapter new];
    CustomBLEPairingSession *session = [[CustomBLEPairingSession alloc] initWithAdapter:adapter];
    __block CustomBLEPairingSnapshot *latestSnapshot = nil;
    [session startWithHomeID:42 eventHandler:^(CustomBLEPairingSnapshot *snapshot) { latestSnapshot = snapshot; }];
    adapter.deviceHandler([[CustomBLEPairingDevice alloc] initWithIdentifier:@"ble-1" name:@"耳机" productID:@"pid" typeDescription:@"BLE 单点" statusDescription:@"待配网" deviceID:nil]);
    [session activateDeviceWithIdentifier:@"ble-1"];
    CustomBLEPairingTokenCompletion lateTokenCompletion = adapter.tokenCompletion;

    [session cancel];
    lateTokenCompletion(@"late-token", nil);

    XCTAssertEqual(latestSnapshot.state, CustomBLEPairingStateCancelled);
    XCTAssertNil(adapter.activatedIdentifier);
}

- (void)testActivationWithoutDeviceIDFailsAndCleansUp {
    FakeBLEPairingAdapter *adapter = [FakeBLEPairingAdapter new];
    CustomBLEPairingSession *session = [[CustomBLEPairingSession alloc] initWithAdapter:adapter];
    __block CustomBLEPairingSnapshot *latestSnapshot = nil;
    [session startWithHomeID:42 eventHandler:^(CustomBLEPairingSnapshot *snapshot) { latestSnapshot = snapshot; }];
    adapter.deviceHandler([[CustomBLEPairingDevice alloc] initWithIdentifier:@"ble-1" name:@"耳机" productID:@"pid" typeDescription:@"BLE 单点" statusDescription:@"待配网" deviceID:nil]);
    [session activateDeviceWithIdentifier:@"ble-1"];
    adapter.tokenCompletion(@"fresh-token", nil);

    CustomBLEPairingDevice *invalidResult = [[CustomBLEPairingDevice alloc] initWithIdentifier:@"ble-1" name:@"耳机" productID:@"pid" typeDescription:@"BLE 单点" statusDescription:@"已激活" deviceID:nil];
    adapter.activationCompletion(invalidResult, nil);

    XCTAssertEqual(latestSnapshot.state, CustomBLEPairingStateFailed);
    XCTAssertEqualObjects(latestSnapshot.failure.stage, @"activation");
    XCTAssertTrue(adapter.cancelled);
}

- (void)testKnownSDKErrorsHaveReadableRetryPolicy {
    NSError *timeoutError = [NSError errorWithDomain:@"test" code:1512 userInfo:nil];
    CustomBLEPairingFailure *timeout = [CustomBLEPairingFailure failureForStage:@"scan" sdkError:timeoutError];
    XCTAssertTrue(timeout.isRetryable);
    XCTAssertTrue([timeout.message containsString:@"超时"]);

    NSError *boundError = [NSError errorWithDomain:@"test" code:3711 userInfo:nil];
    CustomBLEPairingFailure *bound = [CustomBLEPairingFailure failureForStage:@"activation" sdkError:boundError];
    XCTAssertFalse(bound.isRetryable);
    XCTAssertTrue([bound.message containsString:@"已被绑定"]);

    NSError *unauthorizedProductError = [NSError errorWithDomain:@"test" code:3713 userInfo:nil];
    CustomBLEPairingFailure *unauthorizedProduct = [CustomBLEPairingFailure failureForStage:@"activation" sdkError:unauthorizedProductError];
    XCTAssertFalse(unauthorizedProduct.isRetryable);
    XCTAssertTrue([unauthorizedProduct.message containsString:@"未获授权"]);

    NSError *expiredTokenError = [NSError errorWithDomain:@"test" code:3718 userInfo:nil];
    CustomBLEPairingFailure *expiredToken = [CustomBLEPairingFailure failureForStage:@"activation" sdkError:expiredTokenError];
    XCTAssertTrue(expiredToken.isRetryable);
    XCTAssertTrue([expiredToken.message containsString:@"Token"]);

    NSError *permissionError = [NSError errorWithDomain:@"test" code:3719 userInfo:nil];
    CustomBLEPairingFailure *permission = [CustomBLEPairingFailure failureForStage:@"scan" sdkError:permissionError];
    XCTAssertFalse(permission.isRetryable);
    XCTAssertTrue([permission.message containsString:@"权限"]);
}

@end
