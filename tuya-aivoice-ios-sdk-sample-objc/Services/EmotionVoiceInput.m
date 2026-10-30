#import "EmotionVoiceInput.h"
#import <AVFoundation/AVFoundation.h>
#import <Speech/Speech.h>
#import <math.h>

@interface EmotionVoiceInput () <AVAudioRecorderDelegate, AVAudioPlayerDelegate>
@property (nonatomic, strong) AVAudioRecorder *recorder;
@property (nonatomic, strong) AVAudioPlayer *player;
@property (nonatomic, strong) SFSpeechRecognizer *recognizer;
@property (nonatomic, strong) SFSpeechRecognitionTask *recognitionTask;
@property (nonatomic, strong) NSURL *directory;
@property (nonatomic, assign) NSUInteger recognitionGeneration;
@property (nonatomic, copy) void (^recognitionCompletion)(NSString *, NSError *);
@property (nonatomic, copy) void (^playbackCompletion)(void);
@property (nonatomic, copy) NSString *previousCategory;
@property (nonatomic, copy) NSString *previousMode;
@property (nonatomic, assign) AVAudioSessionCategoryOptions previousOptions;
@end

@implementation EmotionVoiceInput

- (instancetype)init {
    self = [super init];
    if (self) {
        _directory = [[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES]
                      URLByAppendingPathComponent:[@"EmotionChat-" stringByAppendingString:NSUUID.UUID.UUIDString] isDirectory:YES];
    }
    return self;
}

- (void)dealloc {
    [self cancelTranscription];
    [self cancelRecording];
    [self stopPlayback];
    [NSFileManager.defaultManager removeItemAtURL:_directory error:nil];
}

- (void)requestRecordingPermission:(void (^)(BOOL))completion {
    [AVAudioSession.sharedInstance requestRecordPermission:^(BOOL granted) {
        dispatch_async(dispatch_get_main_queue(), ^{ completion(granted); });
    }];
}

- (BOOL)activateSessionForRecording:(BOOL)recording error:(NSError **)error {
    AVAudioSession *session = AVAudioSession.sharedInstance;
    self.previousCategory = session.category;
    self.previousMode = session.mode;
    self.previousOptions = session.categoryOptions;
    NSString *category = recording ? AVAudioSessionCategoryPlayAndRecord : AVAudioSessionCategoryPlayback;
    AVAudioSessionCategoryOptions options = recording ? AVAudioSessionCategoryOptionAllowBluetoothHFP : 0;
    if (![session setCategory:category mode:AVAudioSessionModeDefault options:options error:error] ||
        ![session setActive:YES error:error]) {
        [self restoreSession];
        return NO;
    }
    return YES;
}

- (void)restoreSession {
    if (!self.previousCategory) { return; }
    AVAudioSession *session = AVAudioSession.sharedInstance;
    [session setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
    [session setCategory:self.previousCategory mode:self.previousMode options:self.previousOptions error:nil];
    self.previousCategory = nil;
}

- (BOOL)startRecording:(NSError **)error {
    [self stopPlayback];
    [self cancelRecording];
    if (![self activateSessionForRecording:YES error:error]) { return NO; }
    if (![NSFileManager.defaultManager createDirectoryAtURL:self.directory withIntermediateDirectories:YES attributes:nil error:error]) {
        [self restoreSession];
        return NO;
    }
    NSURL *url = [self.directory URLByAppendingPathComponent:[NSUUID.UUID.UUIDString stringByAppendingPathExtension:@"m4a"]];
    NSDictionary *settings = @{
        AVFormatIDKey: @(kAudioFormatMPEG4AAC),
        AVSampleRateKey: @16000,
        AVNumberOfChannelsKey: @1,
        AVEncoderAudioQualityKey: @(AVAudioQualityHigh),
    };
    self.recorder = [[AVAudioRecorder alloc] initWithURL:url settings:settings error:error];
    self.recorder.delegate = self;
    self.recorder.meteringEnabled = YES;
    if (!self.recorder || ![self.recorder record]) {
        if (error && !*error) {
            *error = [NSError errorWithDomain:@"EmotionVoiceInput" code:1 userInfo:@{NSLocalizedDescriptionKey: @"无法开始录音，请检查麦克风是否被其他功能占用。"}];
        }
        [self cancelRecording];
        return NO;
    }
    return YES;
}

- (BOOL)isRecording { return self.recorder.isRecording; }
- (NSTimeInterval)duration { return self.recorder.currentTime; }

- (float)level {
    [self.recorder updateMeters];
    return self.recorder.isRecording ? powf(10, [self.recorder averagePowerForChannel:0] / 40.0f) : 0;
}

- (NSString *)inputName {
    return AVAudioSession.sharedInstance.currentRoute.inputs.firstObject.portName ?: @"麦克风";
}

- (NSURL *)finishRecording {
    NSURL *url = self.recorder.url;
    self.recorder.delegate = nil;
    [self.recorder stop];
    self.recorder = nil;
    [self restoreSession];
    return url;
}

- (void)cancelRecording {
    NSURL *url = [self finishRecording];
    if (url) { [self deleteRecording:url]; }
}

- (void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder *)recorder error:(NSError *)error {
    [self cancelRecording];
    if (self.recordingFailureHandler) { self.recordingFailureHandler(error); }
}

- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag {
    if (!flag) {
        NSError *error = [NSError errorWithDomain:@"EmotionVoiceInput" code:2 userInfo:@{NSLocalizedDescriptionKey: @"录音被中断，请重新录制。"}];
        [self audioRecorderEncodeErrorDidOccur:recorder error:error];
    }
}

- (void)transcribeURL:(NSURL *)url completion:(void (^)(NSString *, NSError *))completion {
    [self cancelTranscription];
    NSUInteger generation = self.recognitionGeneration;
    self.recognitionCompletion = completion;
    __weak typeof(self) weakSelf = self;
    [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus status) {
        dispatch_async(dispatch_get_main_queue(), ^{
            typeof(self) self = weakSelf;
            if (!self || generation != self.recognitionGeneration) { return; }
            if (status != SFSpeechRecognizerAuthorizationStatusAuthorized) {
                [self completeRecognition:@"" errorMessage:@"未获语音识别权限。可以补充文字，或直接保留语音。"];
                return;
            }
            self.recognizer = [[SFSpeechRecognizer alloc] initWithLocale:[NSLocale localeWithLocaleIdentifier:@"zh-CN"]];
            if (!self.recognizer.isAvailable) {
                [self completeRecognition:@"" errorMessage:@"语音识别暂不可用。可以补充文字，或直接保留语音。"];
                return;
            }
            SFSpeechURLRecognitionRequest *request = [[SFSpeechURLRecognitionRequest alloc] initWithURL:url];
            request.shouldReportPartialResults = NO;
            request.taskHint = SFSpeechRecognitionTaskHintDictation;
            self.recognitionTask = [self.recognizer recognitionTaskWithRequest:request resultHandler:^(SFSpeechRecognitionResult *result, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    typeof(self) self = weakSelf;
                    if (!self || generation != self.recognitionGeneration) { return; }
                    if (result.isFinal) {
                        [self completeRecognition:result.bestTranscription.formattedString errorMessage:nil];
                    } else if (error) {
                        [self completeRecognition:@"" errorMessage:@"转写未完成，请检查网络；语音已保留，可以补充文字。"];
                    }
                });
            }];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 15 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                typeof(self) self = weakSelf;
                if (self && generation == self.recognitionGeneration && self.recognitionCompletion) {
                    [self completeRecognition:@"" errorMessage:@"转写超时，语音已保留。可以补充文字后发送。"];
                }
            });
        });
    }];
}

- (void)completeRecognition:(NSString *)text errorMessage:(NSString *)message {
    void (^completion)(NSString *, NSError *) = self.recognitionCompletion;
    [self cancelTranscription];
    NSError *error = message ? [NSError errorWithDomain:@"EmotionVoiceInput" code:3 userInfo:@{NSLocalizedDescriptionKey: message}] : nil;
    if (completion) { completion(text, error); }
}

- (void)cancelTranscription {
    self.recognitionGeneration += 1;
    self.recognitionCompletion = nil;
    [self.recognitionTask cancel];
    self.recognitionTask = nil;
    self.recognizer = nil;
}

- (BOOL)playURL:(NSURL *)url completion:(void (^)(void))completion error:(NSError **)error {
    [self stopPlayback];
    if (![self activateSessionForRecording:NO error:error]) { return NO; }
    self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:error];
    self.player.delegate = self;
    if (!self.player || ![self.player play]) {
        if (error && !*error) {
            *error = [NSError errorWithDomain:@"EmotionVoiceInput" code:4 userInfo:@{NSLocalizedDescriptionKey: @"这段语音暂时无法播放，请重新录制。"}];
        }
        [self stopPlayback];
        return NO;
    }
    self.playbackCompletion = completion;
    return YES;
}

- (void)stopPlayback {
    [self.player stop];
    self.player = nil;
    self.playbackCompletion = nil;
    [self restoreSession];
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    void (^completion)(void) = self.playbackCompletion;
    [self stopPlayback];
    if (completion) { completion(); }
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error {
    [self audioPlayerDidFinishPlaying:player successfully:NO];
}

- (void)deleteRecording:(NSURL *)url {
    NSString *path = url.path;
    NSString *savedAudioDirectory = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/EmotionAudio"];
    if (path.length && [url isFileURL] &&
        ([path hasPrefix:[self.directory.path stringByAppendingString:@"/"]] ||
         [path hasPrefix:[savedAudioDirectory stringByAppendingString:@"/"]])) {
        [NSFileManager.defaultManager removeItemAtURL:url error:nil];
    }
}

@end
