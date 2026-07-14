//
//  CustomBLEPairingSession.m
//  tuya-aivoice-ios-sdk-sample-objc
//

#import "CustomBLEPairingSession.h"
#import <ThingSmartActivatorCoreKit/ThingSmartActivator.h>
#import <ThingSmartBusinessExtensionKit/ThingSmartBusinessExtensionKit.h>

static const NSTimeInterval CustomBLEPairingScanTimeout = 120.0;

@interface CustomBLEPairingDevice ()
@property (nonatomic, copy, readwrite) NSString *identifier;
@property (nonatomic, copy, readwrite) NSString *name;
@property (nonatomic, copy, readwrite) NSString *productID;
@property (nonatomic, copy, readwrite) NSString *typeDescription;
@property (nonatomic, copy, readwrite) NSString *statusDescription;
@property (nonatomic, copy, readwrite, nullable) NSString *deviceID;
@end

@implementation CustomBLEPairingDevice

- (instancetype)initWithIdentifier:(NSString *)identifier
                              name:(NSString *)name
                         productID:(NSString *)productID
                    typeDescription:(NSString *)typeDescription
                  statusDescription:(NSString *)statusDescription
                          deviceID:(NSString *)deviceID {
    self = [super init];
    if (self) {
        _identifier = [identifier copy];
        _name = [name copy];
        _productID = [productID copy];
        _typeDescription = [typeDescription copy];
        _statusDescription = [statusDescription copy];
        _deviceID = [deviceID copy];
    }
    return self;
}

@end

@interface CustomBLEPairingFailure ()
@property (nonatomic, copy, readwrite) NSString *stage;
@property (nonatomic, assign, readwrite) NSInteger code;
@property (nonatomic, copy, readwrite) NSString *message;
@property (nonatomic, assign, readwrite, getter=isRetryable) BOOL retryable;
@end

@implementation CustomBLEPairingFailure

- (instancetype)initWithStage:(NSString *)stage code:(NSInteger)code message:(NSString *)message retryable:(BOOL)retryable {
    self = [super init];
    if (self) {
        _stage = [stage copy];
        _code = code;
        _message = [message copy];
        _retryable = retryable;
    }
    return self;
}

+ (instancetype)failureForStage:(NSString *)stage sdkError:(NSError *)error {
    NSInteger code = error ? error.code : -1;
    NSString *message = error.localizedDescription.length > 0 ? error.localizedDescription : @"未知 SDK 错误";
    BOOL retryable = YES;

    switch (code) {
        case ThingSmartActivatorDiscoveryErrorTimeout:
        case ThingSmartActivatorDiscoveryErrorBleScanExpired:
            message = @"扫描或激活超时，请确认设备处于待配网状态后重试";
            break;
        case ThingSmartActivatorDiscoveryErrorTokenExpired:
            message = @"配网 Token 已失效，请重新扫描并获取新 Token";
            break;
        case ThingSmartActivatorDiscoveryErrorDeviceAlreadyBound:
        case ThingSmartActivatorDiscoveryErrorDeviceActiveRepeated:
            message = @"设备已被绑定，不能直接添加到当前家庭";
            retryable = NO;
            break;
        case ThingSmartActivatorDiscoveryErrorAPPUnsupportProduct:
        case ThingSmartActivatorDiscoveryErrorAPPUnsupportUUID:
            message = @"当前 App 未获授权使用该设备产品";
            retryable = NO;
            break;
        case ThingSmartActivatorDiscoveryErrorPermissionDenied:
            message = @"缺少蓝牙或配网权限，请在系统设置中授权";
            retryable = NO;
            break;
        case ThingSmartActivatorDiscoveryErrorUserSessionLoss:
            message = @"登录状态已失效，请重新登录";
            retryable = NO;
            break;
        case ThingSmartActivatorDiscoveryErrorNoNetwork:
            message = @"手机网络不可用，无法完成设备激活";
            break;
        default:
            break;
    }
    return [[self alloc] initWithStage:stage code:code message:message retryable:retryable];
}

@end

@interface CustomBLEPairingSnapshot ()
@property (nonatomic, assign, readwrite) CustomBLEPairingState state;
@property (nonatomic, copy, readwrite) NSArray<CustomBLEPairingDevice *> *devices;
@property (nonatomic, strong, readwrite, nullable) CustomBLEPairingFailure *failure;
@property (nonatomic, strong, readwrite, nullable) CustomBLEPairingDevice *resultDevice;
@property (nonatomic, copy, readwrite) NSString *logLine;
@property (nonatomic, assign, readwrite) NSTimeInterval elapsed;
@end

@implementation CustomBLEPairingSnapshot
@end

@interface CustomBLEPairingTuyaAdapter : NSObject <CustomBLEPairingAdapter, ThingSmartActivatorSearchDelegate, ThingSmartActivatorActiveDelegate>
@property (nonatomic, strong) ThingSmartActivatorDiscovery *discovery;
@property (nonatomic, strong) ThingSmartActivatorTypeBleModel *bleModel;
@property (nonatomic, strong) ThingSmartActivator *tokenActivator;
@property (nonatomic, strong) NSMutableDictionary<NSString *, ThingSmartActivatorDeviceModel *> *sdkDevices;
@property (nonatomic, copy, nullable) CustomBLEPairingDeviceHandler deviceHandler;
@property (nonatomic, copy, nullable) CustomBLEPairingFailureHandler scanFailureHandler;
@property (nonatomic, copy, nullable) CustomBLEPairingActivationCompletion activationCompletion;
@end

@implementation CustomBLEPairingTuyaAdapter

- (instancetype)init {
    self = [super init];
    if (self) {
        _tokenActivator = [ThingSmartActivator new];
        _sdkDevices = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)startScanningForHomeID:(long long)homeID
                 deviceHandler:(CustomBLEPairingDeviceHandler)deviceHandler
                failureHandler:(CustomBLEPairingFailureHandler)failureHandler {
    [self cancelAndClearCache];
    self.deviceHandler = deviceHandler;
    self.scanFailureHandler = failureHandler;
    [self.sdkDevices removeAllObjects];

    self.bleModel = [ThingSmartActivatorTypeBleModel new];
    self.bleModel.type = ThingSmartActivatorTypeBle;
    self.bleModel.typeName = @"BLE single point";
    self.bleModel.scanType = ThingActivatorBleScanTypeNoraml;
    self.bleModel.activeType = ThingActivatorBleActiveTypeDefault;
    self.bleModel.spaceId = homeID;
    self.bleModel.timeout = (NSInteger)CustomBLEPairingScanTimeout;

    self.discovery = [ThingSmartActivatorDiscovery new];
    [self.discovery loadConfig];
    [self.discovery registerWithActivatorList:@[self.bleModel]];
    [self.discovery setupDelegate:self];
    [self.discovery startSearch:@[self.bleModel]];
}

- (void)stopScanningAndClearCache:(BOOL)clearCache {
    if (self.discovery && self.bleModel) {
        [self.discovery stopSearch:@[self.bleModel] clearCache:clearCache];
    }
}

- (void)requestTokenForHomeID:(long long)homeID completion:(CustomBLEPairingTokenCompletion)completion {
    [self.tokenActivator getTokenWithHomeId:homeID success:^(NSString *token) {
        completion(token, nil);
    } failure:^(NSError *error) {
        completion(nil, [self failureForStage:@"token" error:error]);
    }];
}

- (void)activateDeviceWithIdentifier:(NSString *)identifier
                              homeID:(long long)homeID
                               token:(NSString *)token
                          completion:(CustomBLEPairingActivationCompletion)completion {
    ThingSmartActivatorDeviceModel *device = self.sdkDevices[identifier];
    if (!device) {
        CustomBLEPairingFailure *failure = [[CustomBLEPairingFailure alloc] initWithStage:@"activation" code:-4 message:@"待激活设备已不在扫描缓存中" retryable:YES];
        completion(nil, failure);
        return;
    }

    self.activationCompletion = completion;
    self.bleModel.spaceId = homeID;
    self.bleModel.token = token;
    [self.discovery startActive:self.bleModel deviceList:@[device]];
}

- (void)cancelAndClearCache {
    if (self.discovery && self.bleModel) {
        [self.discovery stopSearch:@[self.bleModel] clearCache:YES];
        [self.discovery stopActive:@[self.bleModel] clearCache:YES];
        [self.discovery removeDelegate:self];
    }
    self.discovery = nil;
    self.bleModel = nil;
    self.deviceHandler = nil;
    self.scanFailureHandler = nil;
    self.activationCompletion = nil;
    [self.sdkDevices removeAllObjects];
}

- (void)activatorService:(id<ThingSmartActivatorSearchProtocol>)service
            activatorType:(ThingSmartActivatorTypeModel *)type
            didFindDevice:(ThingSmartActivatorDeviceModel *)device
                    error:(ThingSmartActivatorErrorModel *)errorModel {
    if (![NSThread isMainThread]) {
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf activatorService:service activatorType:type didFindDevice:device error:errorModel];
        });
        return;
    }
    if (errorModel) {
        if (self.scanFailureHandler) {
            self.scanFailureHandler([self failureForStage:@"scan" error:errorModel.error]);
        }
        return;
    }
    if (!device || device.deviceModelType != ThingSearchDeviceModelTypeBle || device.uniqueID.length == 0) {
        return;
    }
    self.sdkDevices[device.uniqueID] = device;
    if (self.deviceHandler) {
        self.deviceHandler([self publicDeviceFromSDKDevice:device]);
    }
}

- (void)activatorService:(id<ThingSmartActivatorSearchProtocol>)service
            activatorType:(ThingSmartActivatorTypeModel *)type
          didUpdateDevice:(ThingSmartActivatorDeviceModel *)device {
    [self activatorService:service activatorType:type didFindDevice:device error:nil];
}

- (void)activatorService:(id<ThingSmartActivatorActiveProtocol>)service
           activatorType:(ThingSmartActivatorTypeModel *)type
       didReceiveDevices:(NSArray<ThingSmartActivatorDeviceModel *> *)devices
                   error:(ThingSmartActivatorErrorModel *)errorModel {
    if (![NSThread isMainThread]) {
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf activatorService:service activatorType:type didReceiveDevices:devices error:errorModel];
        });
        return;
    }
    CustomBLEPairingActivationCompletion completion = self.activationCompletion;
    self.activationCompletion = nil;
    if (!completion) {
        return;
    }
    if (errorModel) {
        completion(nil, [self failureForStage:@"activation" error:errorModel.error]);
        return;
    }
    ThingSmartActivatorDeviceModel *device = devices.firstObject;
    if (!device || device.devId.length == 0) {
        CustomBLEPairingFailure *failure = [[CustomBLEPairingFailure alloc] initWithStage:@"activation" code:-3 message:@"SDK 未返回有效的已激活设备或 devId" retryable:YES];
        completion(nil, failure);
        return;
    }
    completion([self publicDeviceFromSDKDevice:device], nil);
}

- (CustomBLEPairingDevice *)publicDeviceFromSDKDevice:(ThingSmartActivatorDeviceModel *)device {
    NSString *name = device.name.length > 0 ? device.name : @"未命名 BLE 设备";
    NSString *productID = device.productId.length > 0 ? device.productId : @"-";
    NSString *status = [self statusDescription:device.deviceStatus];
    NSString *deviceID = device.devId.length > 0 ? device.devId : nil;
    return [[CustomBLEPairingDevice alloc] initWithIdentifier:device.uniqueID
                                                        name:name
                                                   productID:productID
                                              typeDescription:@"BLE 单点"
                                            statusDescription:status
                                                    deviceID:deviceID];
}

- (NSString *)statusDescription:(ThingSearchDeviceStatus)status {
    switch (status) {
        case ThingSearchDeviceStatusNoNetwork: return @"未联网";
        case ThingSearchDeviceStatusNetwork: return @"已联网";
        case ThingSearchDeviceStatusRetry: return @"可重试";
        case ThingSearchDeviceStatusFailure: return @"失败";
        case ThingSearchDeviceStatusDefault: return @"待配网";
    }
    return @"未知状态";
}

- (CustomBLEPairingFailure *)failureForStage:(NSString *)stage error:(NSError *)error {
    return [CustomBLEPairingFailure failureForStage:stage sdkError:error];
}

@end

@interface CustomBLEPairingSession ()
@property (nonatomic, strong) id<CustomBLEPairingAdapter> adapter;
@property (nonatomic, copy, nullable) CustomBLEPairingEventHandler eventHandler;
@property (nonatomic, assign) long long homeID;
@property (nonatomic, assign) CustomBLEPairingState state;
@property (nonatomic, strong) NSDate *startedAt;
@property (nonatomic, strong) NSMutableDictionary<NSString *, CustomBLEPairingDevice *> *devicesByIdentifier;
@property (nonatomic, copy, nullable) NSString *selectedIdentifier;
@property (nonatomic, assign) NSUInteger generation;
@property (nonatomic, strong, nullable) NSTimer *scanTimeoutTimer;
@end

@implementation CustomBLEPairingSession

- (instancetype)init {
    return [self initWithAdapter:[CustomBLEPairingTuyaAdapter new]];
}

- (instancetype)initWithAdapter:(id<CustomBLEPairingAdapter>)adapter {
    self = [super init];
    if (self) {
        _adapter = adapter;
        _state = CustomBLEPairingStateIdle;
        _devicesByIdentifier = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)dealloc {
    [self stopScanTimeout];
    [self.adapter cancelAndClearCache];
}

- (void)startWithHomeID:(long long)homeID eventHandler:(CustomBLEPairingEventHandler)eventHandler {
    if (self.state != CustomBLEPairingStateIdle) {
        [self.adapter cancelAndClearCache];
    }
    [self stopScanTimeout];
    self.generation += 1;
    self.homeID = homeID;
    self.eventHandler = eventHandler;
    self.startedAt = [NSDate date];
    self.selectedIdentifier = nil;
    [self.devicesByIdentifier removeAllObjects];
    if (homeID <= 0) {
        self.state = CustomBLEPairingStateFailed;
        CustomBLEPairingFailure *failure = [[CustomBLEPairingFailure alloc] initWithStage:@"preflight" code:-1 message:@"当前家庭 ID 无效" retryable:NO];
        [self emitSnapshotWithFailure:failure result:nil logLine:failure.message];
        return;
    }
    self.state = CustomBLEPairingStateScanning;
    [self emitLog:@"开始扫描 BLE 单点设备"];
    [self startScanTimeout];

    NSUInteger generation = self.generation;
    __weak typeof(self) weakSelf = self;
    [self.adapter startScanningForHomeID:homeID deviceHandler:^(CustomBLEPairingDevice *device) {
        [weakSelf performOnMain:^{
            if (weakSelf.generation == generation) {
                [weakSelf handleDiscoveredDevice:device];
            }
        }];
    } failureHandler:^(CustomBLEPairingFailure *failure) {
        [weakSelf performOnMain:^{
            if (weakSelf.generation == generation && weakSelf.state == CustomBLEPairingStateScanning) {
                [weakSelf handleFailure:failure];
            }
        }];
    }];
}

- (void)activateDeviceWithIdentifier:(NSString *)identifier {
    if (self.state != CustomBLEPairingStateScanning || !self.devicesByIdentifier[identifier]) {
        return;
    }

    self.selectedIdentifier = identifier;
    [self stopScanTimeout];
    [self.adapter stopScanningAndClearCache:NO];
    self.state = CustomBLEPairingStateAcquiringToken;
    [self emitLog:@"正在获取配网 Token"];

    NSUInteger generation = self.generation;
    __weak typeof(self) weakSelf = self;
    [self.adapter requestTokenForHomeID:self.homeID completion:^(NSString *token, CustomBLEPairingFailure *failure) {
        [weakSelf performOnMain:^{
            if (weakSelf.generation != generation || weakSelf.state != CustomBLEPairingStateAcquiringToken) {
                return;
            }
            if (failure || token.length == 0) {
                CustomBLEPairingFailure *resolvedFailure = failure ?: [[CustomBLEPairingFailure alloc] initWithStage:@"token" code:-2 message:@"获取到的配网 Token 为空" retryable:YES];
                [weakSelf handleFailure:resolvedFailure];
                return;
            }

            weakSelf.state = CustomBLEPairingStateActivating;
            [weakSelf emitLog:@"Token 获取成功，开始激活设备"];
            NSString *selectedIdentifier = weakSelf.selectedIdentifier;
            [weakSelf.adapter activateDeviceWithIdentifier:selectedIdentifier homeID:weakSelf.homeID token:token completion:^(CustomBLEPairingDevice *device, CustomBLEPairingFailure *activationFailure) {
                [weakSelf performOnMain:^{
                    if (weakSelf.generation != generation || weakSelf.state != CustomBLEPairingStateActivating) {
                        return;
                    }
                    if (activationFailure || !device || device.deviceID.length == 0) {
                        CustomBLEPairingFailure *resolvedFailure = activationFailure ?: [[CustomBLEPairingFailure alloc] initWithStage:@"activation" code:-3 message:@"SDK 未返回有效的已激活设备或 devId" retryable:YES];
                        [weakSelf handleFailure:resolvedFailure];
                        return;
                    }
                    weakSelf.devicesByIdentifier[device.identifier] = device;
                    weakSelf.state = CustomBLEPairingStateSucceeded;
                    [weakSelf.adapter cancelAndClearCache];
                    [weakSelf emitSnapshotWithFailure:nil result:device logLine:[NSString stringWithFormat:@"设备激活成功：%@", device.name]];
                }];
            }];
        }];
    }];
}

- (void)cancel {
    self.generation += 1;
    [self stopScanTimeout];
    [self.adapter cancelAndClearCache];
    self.state = CustomBLEPairingStateCancelled;
    [self emitLog:@"配网已取消"];
}

- (void)handleDiscoveredDevice:(CustomBLEPairingDevice *)device {
    if (self.state != CustomBLEPairingStateScanning || device.identifier.length == 0) {
        return;
    }
    self.devicesByIdentifier[device.identifier] = device;
    [self emitLog:[NSString stringWithFormat:@"发现设备：%@", device.name]];
}

- (void)handleFailure:(CustomBLEPairingFailure *)failure {
    [self stopScanTimeout];
    [self.adapter cancelAndClearCache];
    self.state = CustomBLEPairingStateFailed;
    NSString *logLine = [NSString stringWithFormat:@"阶段=%@ SDK错误码=%ld %@", failure.stage, (long)failure.code, failure.message];
    [self emitSnapshotWithFailure:failure result:nil logLine:logLine];
}

- (void)startScanTimeout {
    [self stopScanTimeout];
    __weak typeof(self) weakSelf = self;
    self.scanTimeoutTimer = [NSTimer scheduledTimerWithTimeInterval:CustomBLEPairingScanTimeout repeats:NO block:^(NSTimer *timer) {
        CustomBLEPairingSession *strongSelf = weakSelf;
        if (!strongSelf || strongSelf.state != CustomBLEPairingStateScanning) {
            return;
        }
        NSError *timeoutError = [NSError errorWithDomain:ThingSmartActivatorDiscoveryErrorDomain
                                                     code:ThingSmartActivatorDiscoveryErrorTimeout
                                                 userInfo:nil];
        [strongSelf handleFailure:[CustomBLEPairingFailure failureForStage:@"scan" sdkError:timeoutError]];
    }];
}

- (void)stopScanTimeout {
    [self.scanTimeoutTimer invalidate];
    self.scanTimeoutTimer = nil;
}

- (void)performOnMain:(dispatch_block_t)block {
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

- (void)emitLog:(NSString *)logLine {
    [self emitSnapshotWithFailure:nil result:nil logLine:logLine];
}

- (void)emitSnapshotWithFailure:(CustomBLEPairingFailure *)failure
                          result:(CustomBLEPairingDevice *)result
                         logLine:(NSString *)logLine {
    if (!self.eventHandler) {
        return;
    }
    CustomBLEPairingSnapshot *snapshot = [CustomBLEPairingSnapshot new];
    snapshot.state = self.state;
    snapshot.devices = [self.devicesByIdentifier.allValues sortedArrayUsingComparator:^NSComparisonResult(CustomBLEPairingDevice *left, CustomBLEPairingDevice *right) {
        return [left.name localizedCaseInsensitiveCompare:right.name];
    }];
    snapshot.failure = failure;
    snapshot.resultDevice = result;
    snapshot.logLine = logLine ?: @"";
    snapshot.elapsed = self.startedAt ? -[self.startedAt timeIntervalSinceNow] : 0;
    self.eventHandler(snapshot);
}

@end

NSString *CustomBLEPairingStateDescription(CustomBLEPairingState state) {
    switch (state) {
        case CustomBLEPairingStateIdle: return @"空闲";
        case CustomBLEPairingStateScanning: return @"扫描中";
        case CustomBLEPairingStateAcquiringToken: return @"获取 Token";
        case CustomBLEPairingStateActivating: return @"激活中";
        case CustomBLEPairingStateSucceeded: return @"成功";
        case CustomBLEPairingStateFailed: return @"失败";
        case CustomBLEPairingStateCancelled: return @"已取消";
    }
    return @"未知";
}
