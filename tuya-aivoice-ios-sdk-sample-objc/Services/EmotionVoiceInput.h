#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 页面独占的语音输入：临时录音、系统转写和回放，不上传到智能体。
@interface EmotionVoiceInput : NSObject

@property (nonatomic, readonly, getter=isRecording) BOOL recording;
@property (nonatomic, readonly) NSTimeInterval duration;
@property (nonatomic, readonly) float level;
@property (nonatomic, copy, readonly) NSString *inputName;
@property (nonatomic, copy, nullable) void (^recordingFailureHandler)(NSError *error);

- (void)requestRecordingPermission:(void (^)(BOOL granted))completion;
- (BOOL)startRecording:(NSError **)error;
- (nullable NSURL *)finishRecording;
- (void)cancelRecording;
- (void)transcribeURL:(NSURL *)url completion:(void (^)(NSString *text, NSError * _Nullable error))completion;
- (void)cancelTranscription;
- (BOOL)playURL:(NSURL *)url completion:(void (^)(void))completion error:(NSError **)error;
- (void)stopPlayback;
- (void)deleteRecording:(NSURL *)url;

@end

NS_ASSUME_NONNULL_END
