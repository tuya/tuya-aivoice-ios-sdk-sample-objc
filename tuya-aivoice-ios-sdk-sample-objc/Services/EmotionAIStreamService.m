#import "EmotionAIStreamService.h"

static NSString * const EmotionAIStreamErrorDomain = @"EmotionAIStreamService";

@interface EmotionAIStreamService ()
@property (nonatomic, copy) NSString *solutionCode;
@property (nonatomic, copy, nullable) NSString *miniProgramId;
@property (nonatomic, assign) long long homeId;
@property (nonatomic, copy) NSString *deviceId;
@property (nonatomic, assign) BOOL useDeviceIdentity;
@property (nonatomic, strong) ThingSmartStreamClient *client;
@property (nonatomic, copy) NSString *sessionId;
@property (nonatomic, copy) NSString *activeEventId;
@property (nonatomic, assign, getter=isReady) BOOL ready;
@property (nonatomic, assign) BOOL starting;
@property (nonatomic, assign) BOOL sending;
@property (nonatomic, copy) void (^startCompletion)(NSError * _Nullable error);
@end

@implementation EmotionAIStreamService

- (instancetype)initWithSolutionCode:(NSString *)solutionCode
                        miniProgramId:(nullable NSString *)miniProgramId
                              homeId:(long long)homeId
                           deviceId:(nullable NSString *)deviceId
                   useDeviceIdentity:(BOOL)useDeviceIdentity {
    self = [super init];
    if (self) {
        _solutionCode = [solutionCode copy];
        _miniProgramId = [miniProgramId copy];
        _homeId = homeId;
        _deviceId = [deviceId copy];
        _useDeviceIdentity = useDeviceIdentity;
    }
    return self;
}

- (NSError *)errorWithCode:(NSInteger)code message:(NSString *)message {
    return [NSError errorWithDomain:EmotionAIStreamErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

- (void)startWithCompletion:(void (^)(NSError * _Nullable))completion {
    if (self.ready) {
        if (completion) completion(nil);
        return;
    }
    if (self.starting) {
        self.startCompletion = completion;
        return;
    }
    if (self.solutionCode.length == 0) {
        NSError *error = [self errorWithCode:1 message:@"未配置 Agent ID"];
        if (completion) completion(error);
        if (self.stateHandler) self.stateHandler(@"配置缺失", error);
        return;
    }
    if (self.useDeviceIdentity && self.deviceId.length == 0) {
        NSError *error = [self errorWithCode:2 message:@"设备身份模式缺少 devId"];
        if (completion) completion(error);
        if (self.stateHandler) self.stateHandler(@"设备身份不可用", error);
        return;
    }
    if (self.useDeviceIdentity) {
        self.client = [ThingSmartStreamClient clientForAgentDevice:self.deviceId];
    } else {
        self.client = [ThingSmartStreamClient clientForApp];
    }
    if (!self.client) {
        NSError *error = [self errorWithCode:3 message:@"无法创建 AI Stream 通道"];
        if (completion) completion(error);
        return;
    }
    [self.client addDelegate:self];
    self.starting = YES;
    self.startCompletion = completion;
    if (self.stateHandler) self.stateHandler(@"连接中", nil);
    __weak typeof(self) weakSelf = self;
    void (^createSession)(void) = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        ThingStreamQueryAgentTokenParams *params = [ThingStreamQueryAgentTokenParams new];
        params.solutionCode = self.solutionCode;
        params.ownerId = [NSString stringWithFormat:@"%lld", self.homeId];
        params.api = @"m.life.ai.token.get";
        params.apiVerion = @"1.0";
        NSMutableDictionary *extParams = [@{
            @"miniProgramId": self.miniProgramId ?: @"",
            @"needTts": @YES,
        } mutableCopy];
        if (self.useDeviceIdentity && self.deviceId.length > 0) {
            extParams[@"deviceId"] = self.deviceId;
        }
        params.extParams = extParams;
        NSLog(@"[EmotionAIStream] token params api=%@ version=%@ solutionCode=%@ ownerId=%@ miniProgramId=%@ deviceId=%@",
              params.api,
              params.apiVerion,
              params.solutionCode,
              params.ownerId,
              self.miniProgramId.length > 0 ? self.miniProgramId : @"<empty>",
              self.deviceId.length > 0 ? self.deviceId : @"<empty>");
        if (self.stateHandler) self.stateHandler(@"获取 Agent Token", nil);
        [self.client createSessionWithQueryParams:params
                                reuseDataChannel:NO
                                   cacheBasePath:[NSHomeDirectory() stringByAppendingString:@"/Documents/"]
                                         userData:@""
                                       completion:^(ThingStreamSessionInfo *result, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) self = weakSelf;
                if (!self) return;
                self.starting = NO;
                if (!result || error) {
                    NSError *finalError = error ?: [self errorWithCode:4 message:@"AI Stream Session 创建失败"];
                    if (self.startCompletion) self.startCompletion(finalError);
                    self.startCompletion = nil;
                    if (self.stateHandler) self.stateHandler(@"Session 创建失败", finalError);
                    return;
                }
                self.sessionId = result.sessionID;
                NSLog(@"[EmotionAIStream] session created sessionId=%@ sendDataChannels=%@ recvDataChannels=%@",
                      result.sessionID,
                      result.sendDataChannels ?: @[],
                      result.recvDataChannels ?: @[]);
                self.ready = YES;
                if (self.startCompletion) self.startCompletion(nil);
                self.startCompletion = nil;
                if (self.stateHandler) self.stateHandler(@"已连接", nil);
            });
        }];
    };
    if (self.client.isConnected) {
        createSession();
    } else {
        [self.client connect:^(__unused NSString *connectionId) {
            createSession();
        }];
    }
}

- (void)sendText:(NSString *)text completion:(void (^)(NSError * _Nullable))completion {
    NSString *trimmed = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmed.length == 0) {
        if (completion) completion([self errorWithCode:5 message:@"文本内容为空"]);
        return;
    }
    if (!self.ready || self.sessionId.length == 0) {
        if (completion) completion([self errorWithCode:6 message:@"AI Stream Session 尚未就绪"]);
        return;
    }
    if (self.sending) {
        if (completion) completion([self errorWithCode:7 message:@"上一条消息仍在处理"]);
        return;
    }
    self.sending = YES;
    __weak typeof(self) weakSelf = self;
    [self.client sendEventStart:self.sessionId
                        userData:nil
                         success:^(NSString *eventId) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.activeEventId = eventId;
        ThingStreamTextPacketModel *packet = [ThingStreamTextPacketModel packetWithText:trimmed
                                                                                 sessionID:self.sessionId
                                                                               dataChannel:nil];
        [self.client sendTextData:packet completion:^(BOOL success, NSError *error) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            if (!success) {
                self.sending = NO;
                if (completion) completion(error ?: [self errorWithCode:8 message:@"文本发送失败"]);
                return;
            }
            [self.client sendEventEnd:self.activeEventId
                            sessionId:self.sessionId
                             userData:nil
                           completion:^(BOOL endSuccess, NSError *endError) {
                __strong typeof(weakSelf) self = weakSelf;
                if (!self) return;
                self.sending = NO;
                if (completion) completion(endSuccess ? nil : (endError ?: [self errorWithCode:9 message:@"对话事件结束失败"]));
            }];
        }];
    } failure:^(NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.sending = NO;
        if (completion) completion(error ?: [self errorWithCode:10 message:@"对话事件开始失败"]);
    }];
}

- (void)stop {
    if (self.sessionId.length > 0) {
        [self.client closeSession:self.sessionId
                         withCode:ThingStreamAttributeConnectionSessionCodeCloseByClient
                       completion:nil];
    }
    [self.client removeDelegate:self];
    if (self.useDeviceIdentity) [self.client destroy];
    else [self.client disconnect];
    self.client = nil;
    self.sessionId = nil;
    self.activeEventId = nil;
    self.ready = NO;
    self.starting = NO;
    self.sending = NO;
}

- (void)streamClient:(ThingSmartStreamClient *)client connectState:(ThingSmartStreamConnectState)connectState error:(NSError *)error {
    NSLog(@"[EmotionAIStream] connect state=%lu connectionId=%@ error=%@",
          (unsigned long)connectState,
          client.connectionID ?: @"<empty>",
          error ?: @"<none>");
    if (connectState == ThingSmartStreamConnectStateClosedByServer || connectState == ThingSmartStreamConnectStateClosed) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.starting && self.startCompletion) {
                self.starting = NO;
                void (^completion)(NSError * _Nullable) = self.startCompletion;
                self.startCompletion = nil;
                completion(error ?: [self errorWithCode:11 message:@"AI Stream 通道连接失败"]);
            }
            if (self.stateHandler) self.stateHandler(@"通道已断开", error);
        });
    }
}

- (void)streamClientSessionId:(NSString *)sessionID changedSessionState:(ThingSmartStreamSessionState)sessionState error:(NSError *)error {
    NSLog(@"[EmotionAIStream] session state=%lu sessionId=%@ error=%@",
          (unsigned long)sessionState,
          sessionID ?: @"<empty>",
          error ?: @"<none>");
    if (sessionState == ThingSmartStreamSessionStateAgentTokenExpired) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.stateHandler) self.stateHandler(@"Agent Token 已过期", error);
        });
    }
}

- (void)streamClientDidReceiveText:(ThingStreamTextPacketModel *)packet {
    NSString *text = packet.text;
    if (text.length == 0 && packet.payload.length > 0) {
        text = [[NSString alloc] initWithData:packet.payload encoding:NSUTF8StringEncoding];
    }
    if (!self.textHandler || text.length == 0) return;
    NSLog(@"[EmotionAIStream] text streamFlag=%lu payloadLength=%lu text=%@",
          (unsigned long)packet.streamFlag,
          (unsigned long)packet.payload.length,
          text);
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.textHandler) self.textHandler(text, packet.streamFlag);
    });
}

- (void)streamClientDidReceiveEvent:(ThingStreamEventPacketModel *)packet {
    NSLog(@"[EmotionAIStream] event type=%lu eventId=%@ sessionId=%@",
          (unsigned long)packet.eventType,
          packet.eventId ?: @"<empty>",
          packet.sessionID ?: @"<empty>");
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.eventHandler) self.eventHandler(packet.eventType);
    });
}

@end
