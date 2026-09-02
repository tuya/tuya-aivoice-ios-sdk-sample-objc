//
//  NativeAudioService.h
//  AIVoiceDemo
//
//  Native SDK 调用封装层。统一封装 ThingAudioDetectManagerNative 的录音控制、
//  文件列表、详情、转写/总结/翻译等接口，并保证所有回调在主线程触发。
//

#import <Foundation/Foundation.h>
#import <ThingAudioRecordInterface/ThingAudioRecordInterface.h>

NS_ASSUME_NONNULL_BEGIN

@class ThingAudioRecordConfig;
@class ThingAudioRecordObject;
@class ThingAudioRecordFile;
@class ThingAudioRecordSearchMixResultItem;
@protocol ThingAudioRecordManagerDelegate;
@protocol ThingAudioRecordSyncManagerDelegate;

/// 失败回调类型。
typedef void(^NativeAudioFailure)(NSError *error);
/// 文件上传进度回调。progress 为上传进度值，status 为底层上传状态。
typedef void(^NativeAudioProcessProgress)(double progress, int status);

@interface NativeAudioService : NSObject

+ (instancetype)sharedInstance;

#pragma mark - Recording control

/// 同步查询设备活动录音任务；无任务或服务不可用时返回 nil。
- (nullable ThingAudioRecordObject *)activeTaskWithDeviceId:(NSString *)deviceId;

/// 开始录音。
- (void)startRecordingWithDeviceId:(NSString *)deviceId
                            config:(ThingAudioRecordConfig *)config
                           success:(nullable void(^)(ThingAudioRecordObject *task))success
                           failure:(nullable NativeAudioFailure)failure;

/// 暂停录音。
- (void)pauseRecordingWithDeviceId:(NSString *)deviceId
                           success:(nullable void(^)(void))success
                           failure:(nullable NativeAudioFailure)failure;

/// 恢复录音。
- (void)resumeRecordingWithDeviceId:(NSString *)deviceId
                            success:(nullable void(^)(void))success
                            failure:(nullable NativeAudioFailure)failure;

/// 结束录音。
- (void)stopRecordingWithDeviceId:(NSString *)deviceId
                          success:(nullable void(^)(void))success
                          failure:(nullable NativeAudioFailure)failure;

#pragma mark - Listener forwarding

/// 注册录音事件监听器（按设备隔离），转发给底层 Manager。
- (void)addRecordListener:(id<ThingAudioRecordManagerDelegate>)listener deviceId:(NSString *)deviceId;

/// 移除录音事件监听器，必须与注册时使用同一实例和 deviceId。
- (void)removeRecordListener:(id<ThingAudioRecordManagerDelegate>)listener deviceId:(NSString *)deviceId;

/// 注册转写/总结/翻译等文件同步状态监听器（全局），转发给底层 Manager。
- (void)addSyncListener:(id<ThingAudioRecordSyncManagerDelegate>)listener;

/// 移除文件同步状态监听器，必须与注册时使用同一实例。
- (void)removeSyncListener:(id<ThingAudioRecordSyncManagerDelegate>)listener;

#pragma mark - File list & search

/// 查询全部已入库录音（按 recordTime 降序）。
- (void)fetchAllRecordsWithSuccess:(nullable void(^)(NSArray<ThingAudioRecordFile *> *list))success
                           failure:(nullable NativeAudioFailure)failure;

/// 混合搜索录音（标题、标签、转写内容）。
- (void)searchRecordsWithKeyword:(NSString *)keyword
                         success:(nullable void(^)(NSArray<ThingAudioRecordSearchMixResultItem *> *list))success
                         failure:(nullable NativeAudioFailure)failure;

#pragma mark - File detail

/// 按 recordId 查询单条录音详情。
- (void)fetchRecordDetailWithRecordId:(NSString *)recordId
                    amplitudeMaxCount:(NSInteger)amplitudeMaxCount
                              success:(nullable void(^)(ThingAudioRecordFile *file))success
                              failure:(nullable NativeAudioFailure)failure;

#pragma mark - Transcription & Summary content

/// 查询转写文本。
- (void)fetchTranscriptionWithFileId:(long long)fileId
                             success:(nullable void(^)(NSString *text))success
                             failure:(nullable NativeAudioFailure)failure;

/// 查询总结文本。
- (void)fetchSummaryWithFileId:(long long)fileId
                       success:(nullable void(^)(NSString *text))success
                       failure:(nullable NativeAudioFailure)failure;

/// 查询实时 ASR 分句列表（含时间戳），用于按句展示转写内容。
- (void)fetchTranscriptionSentencesWithFileId:(long long)fileId
                                      success:(nullable void(^)(NSArray<ThingAudioRecordAsrResult *> *list))success
                                      failure:(nullable NativeAudioFailure)failure;

#pragma mark - Offline processing (transcribe / summarize / translate)

/// 使用完整原生参数发起离线转写、总结或翻译任务。
- (void)processRecordWithParams:(ThingAudioRecordUploadFileParams *)params
                       taskType:(NSInteger)taskType
                        success:(nullable void(^)(NSString * _Nullable taskId))success
                       progress:(nullable NativeAudioProcessProgress)progress
                        failure:(nullable NativeAudioFailure)failure;

/// 发起离线处理任务。taskType: 0 转写，1 总结，2 翻译。
- (void)processRecordWithFileId:(long long)fileId
                       recordId:(NSString *)recordId
                       taskType:(NSInteger)taskType
                translationLang:(nullable NSString *)translationLang
                        success:(nullable void(^)(NSString * _Nullable taskId))success
                        progress:(nullable NativeAudioProcessProgress)progress
                         failure:(nullable NativeAudioFailure)failure;

@end

NS_ASSUME_NONNULL_END
