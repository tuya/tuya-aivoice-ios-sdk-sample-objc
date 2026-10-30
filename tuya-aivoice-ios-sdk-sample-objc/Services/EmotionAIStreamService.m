#import "EmotionAIStreamService.h"
#import <ThingSmartStreamBizKit/ThingSmartStreamBizKit.h>
#import <math.h>

static NSString * const EmotionAIStreamErrorDomain = @"EmotionAIStreamService";

@interface EmotionAIStreamService () <ThingStreamRecorderDelegate, ThingStreamPlayerDelegate>
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
@property (nonatomic, strong, nullable) ThingStreamRecorder *recorder;
@property (nonatomic, copy, nullable) NSString *audioEventId;
@property (nonatomic, assign, getter=isRecording) BOOL recording;
@property (nonatomic, assign) BOOL stoppingAudio;
@property (nonatomic, assign) NSTimeInterval recordingStartedAt;
@property (nonatomic, assign) NSTimeInterval recordingDuration;
@property (nonatomic, assign) float recordingLevel;
@property (nonatomic, strong) NSMutableData *recordingPCM;
@property (nonatomic, strong, nullable) ThingStreamPlayer *ttsPlayer;
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
        _ttsEnabled = YES;
        _recordingPCM = [NSMutableData data];
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
            @"needTts": @(self.ttsEnabled),
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
    if (self.recording) {
        if (completion) completion([self errorWithCode:7 message:@"当前语音仍在发送"]);
        return;
    }
    if (self.sending) {
        if (completion) completion([self errorWithCode:8 message:@"上一条消息仍在处理"]);
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
                if (completion) completion(error ?: [self errorWithCode:9 message:@"文本发送失败"]);
                return;
            }
            [self.client sendEventEnd:self.activeEventId
                            sessionId:self.sessionId
                             userData:nil
                           completion:^(BOOL endSuccess, NSError *endError) {
                __strong typeof(weakSelf) self = weakSelf;
                if (!self) return;
                self.sending = NO;
                if (completion) completion(endSuccess ? nil : (endError ?: [self errorWithCode:10 message:@"对话事件结束失败"]));
            }];
        }];
    } failure:^(NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.sending = NO;
        if (completion) completion(error ?: [self errorWithCode:11 message:@"对话事件开始失败"]);
    }];
}

- (void)startAudioRecordingWithCompletion:(void (^)(NSError * _Nullable))completion {
    if (self.recording) {
        if (completion) completion([self errorWithCode:12 message:@"已有一段语音正在发送"]);
        return;
    }
    __weak typeof(self) weakSelf = self;
    [self startWithCompletion:^(NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || error) {
            if (completion) completion(error ?: [self errorWithCode:13 message:@"AI Stream Session 尚未就绪"]);
            return;
        }
        self.recorder = [[ThingStreamRecorder alloc] initWithDelegate:self];
        ThingStreamRecorderExtendConfig *config = [ThingStreamRecorderExtendConfig defaultOpusConfig];
        config.vadModelPath = nil;
        [self.recorder updateRecorderExtendConfig:config];
        NSString *audioDirectory = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/EmotionAudio"];
        [NSFileManager.defaultManager createDirectoryAtPath:audioDirectory
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:nil];
        self.recorder.baseSavePath = [audioDirectory stringByAppendingString:@"/"];
        if (![self.recorder initVoiceDetector] || ![self.recorder startRecorder:YES]) {
            self.recorder = nil;
            if (completion) completion([self errorWithCode:14 message:@"AI Stream 录音器启动失败"]);
            return;
        }
        self.recordingPCM = [NSMutableData data];
        self.recording = YES;
        self.recordingStartedAt = NSDate.date.timeIntervalSince1970;
        self.recordingDuration = 0;
        self.recordingLevel = 0;
        [self.client sendEventStart:self.sessionId
                           userData:nil
                            success:^(NSString *eventId) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            self.audioEventId = eventId;
            ThingStreamAudioPacketModel *packet = [self.recorder firstAudioPacket];
            packet.sessionID = self.sessionId;
            packet.dataChannel = nil;
            [self.client sendAudioData:packet completion:^(BOOL success, NSError *error) {
                if (!success) {
                    [self cancelAudioRecording];
                    if (completion) completion(error ?: [self errorWithCode:15 message:@"首个音频包发送失败"]);
                    return;
                }
                if (completion) completion(nil);
            }];
        } failure:^(NSError *error) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            [self cancelAudioRecording];
            if (completion) completion(error ?: [self errorWithCode:16 message:@"语音事件开始失败"]);
        }];
    }];
}

- (void)stopAudioRecordingWithCompletion:(EmotionAIStreamAudioCompletion)completion {
    if (!self.recording || !self.recorder || self.sessionId.length == 0 || self.audioEventId.length == 0) {
        if (completion) completion(nil, 0, [self errorWithCode:17 message:@"当前没有可结束的语音会话"]);
        return;
    }
    self.recordingDuration = MAX(0, NSDate.date.timeIntervalSince1970 - self.recordingStartedAt);
    self.stoppingAudio = YES;
    NSString *recordingPath = [self.recorder stopRecorder];
    self.recording = NO;
    self.stoppingAudio = NO;
    NSURL *audioURL = [self savePCMRecording];
    if (!audioURL && recordingPath.length > 0) {
        audioURL = [NSURL fileURLWithPath:recordingPath];
    }
    self.recorder = nil;
    ThingStreamAudioPacketModel *packet = [ThingStreamAudioPacketModel packetWithPayload:nil
                                                                                 sessionID:self.sessionId
                                                                               dataChannel:nil
                                                                                streamFlag:ThingStreamPacketStreamFlagStreamEnd];
    __weak typeof(self) weakSelf = self;
    [self.client sendAudioData:packet completion:^(BOOL success, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (!success) {
            if (completion) completion(audioURL, self.recordingDuration,
                                       error ?: [self errorWithCode:18 message:@"音频结束包发送失败"]);
            return;
        }
        [self.client sendEventEnd:self.audioEventId
                         sessionId:self.sessionId
                          userData:nil
                        completion:^(BOOL endSuccess, NSError *endError) {
            NSError *finalError = endSuccess ? nil : (endError ?: [self errorWithCode:19 message:@"语音事件结束失败"]);
            if (completion) completion(audioURL, self.recordingDuration, finalError);
            self.audioEventId = nil;
        }];
    }];
}

- (void)cancelAudioRecording {
    if (self.recorder) {
        self.stoppingAudio = YES;
        [self.recorder stopRecorder];
        self.recorder = nil;
    }
    self.recording = NO;
    self.stoppingAudio = NO;
    self.recordingDuration = 0;
    self.recordingLevel = 0;
    self.recordingPCM = [NSMutableData data];
    if (self.audioEventId.length > 0 && self.sessionId.length > 0) {
        [self.client sendEventChatBreak:self.audioEventId sessionId:self.sessionId completion:nil];
    }
    self.audioEventId = nil;
}

- (void)stop {
    [self cancelAudioRecording];
    [self.ttsPlayer stop];
    [self.ttsPlayer destroy];
    self.ttsPlayer = nil;
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

- (void)streamClientDidReceiveAudio:(ThingStreamAudioPacketModel *)packet {
    if (!self.ttsEnabled || !packet) {
        return;
    }
    if (packet.streamFlag == ThingStreamPacketStreamFlagStreamStart ||
        packet.streamFlag == ThingStreamPacketStreamFlagOnlyOne) {
        self.ttsPlayer = self.ttsPlayer ?: [[ThingStreamPlayer alloc] init];
        [self.ttsPlayer stop];
        self.ttsPlayer.delegate = self;
        self.ttsPlayer.supportPlayWhileRecord = YES;
        ThingStreamPlayerSupportAudioCodec codec = (ThingStreamPlayerSupportAudioCodec)packet.codecType;
        if (![self.ttsPlayer configSampleRate:packet.sampleRate
                                    channels:packet.channels
                                    bitDepth:packet.bitDepth
                                    codecType:codec]) {
            if (self.stateHandler) {
                self.stateHandler(@"TTS 播放初始化失败", [self errorWithCode:20 message:@"不支持当前 TTS 音频格式"]);
            }
            return;
        }
        [self.ttsPlayer play];
    }
    if (self.ttsPlayer.isPlaying) {
        [self.ttsPlayer feedData:packet.payload ?: [NSData data]
                           isLast:packet.streamFlag == ThingStreamPacketStreamFlagStreamEnd];
    }
}

- (void)audioPlayer:(ThingStreamPlayer *)player didEncounterError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.stateHandler) self.stateHandler(@"TTS 播放失败", error);
    });
}

- (void)recorderDidRecVoice:(NSData *)voiceData {
    if (!self.recording && !self.stoppingAudio) return;
    @synchronized (self.recordingPCM) {
        [self.recordingPCM appendData:voiceData];
    }
    self.recordingDuration = MAX(0, NSDate.date.timeIntervalSince1970 - self.recordingStartedAt);
    if (voiceData.length < sizeof(int16_t)) return;
    const int16_t *samples = voiceData.bytes;
    NSUInteger count = voiceData.length / sizeof(int16_t);
    double sum = 0;
    for (NSUInteger index = 0; index < count; index++) {
        double sample = samples[index] / 32768.0;
        sum += sample * sample;
    }
    self.recordingLevel = (float)MIN(1.0, sqrt(sum / count) * 4.0);
}

- (NSURL *)savePCMRecording {
    NSData *pcm;
    @synchronized (self.recordingPCM) {
        pcm = [self.recordingPCM copy];
    }
    if (pcm.length == 0) return nil;

    NSString *directory = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/EmotionAudio"];
    if (![[NSFileManager defaultManager] createDirectoryAtPath:directory
                                      withIntermediateDirectories:YES
                                                       attributes:nil
                                                            error:nil]) {
        return nil;
    }
    NSString *path = [directory stringByAppendingPathComponent:
                      [NSString stringWithFormat:@"%@.wav", NSUUID.UUID.UUIDString]];
    NSMutableData *wav = [NSMutableData dataWithCapacity:44 + pcm.length];
    uint32_t fileSize = (uint32_t)(36 + pcm.length);
    uint32_t dataSize = (uint32_t)pcm.length;
    uint16_t audioFormat = 1;
    uint16_t channels = 1;
    uint32_t sampleRate = 16000;
    uint16_t bitsPerSample = 16;
    uint32_t byteRate = sampleRate * channels * bitsPerSample / 8;
    uint16_t blockAlign = channels * bitsPerSample / 8;
    [wav appendBytes:"RIFF" length:4];
    [wav appendBytes:&fileSize length:4];
    [wav appendBytes:"WAVEfmt " length:8];
    uint32_t fmtSize = 16;
    [wav appendBytes:&fmtSize length:4];
    [wav appendBytes:&audioFormat length:2];
    [wav appendBytes:&channels length:2];
    [wav appendBytes:&sampleRate length:4];
    [wav appendBytes:&byteRate length:4];
    [wav appendBytes:&blockAlign length:2];
    [wav appendBytes:&bitsPerSample length:2];
    [wav appendBytes:"data" length:4];
    [wav appendBytes:&dataSize length:4];
    [wav appendData:pcm];
    return [wav writeToFile:path atomically:YES] ? [NSURL fileURLWithPath:path] : nil;
}

- (void)recorderDidRecVoicePacket:(ThingStreamAudioPacketModel *)packet {
    if (!self.recording || self.stoppingAudio || self.audioEventId.length == 0 || self.sessionId.length == 0) return;
    packet.sessionID = self.sessionId;
    packet.dataChannel = nil;
    [self.client sendAudioData:packet completion:^(BOOL success, NSError *error) {
        if (!success) {
            NSLog(@"[EmotionAIStream] audio packet failed error=%@", error);
        }
    }];
}

- (void)recorderDidHappendedError:(NSError *)error {
    NSLog(@"[EmotionAIStream] recorder error=%@", error);
    [self cancelAudioRecording];
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
