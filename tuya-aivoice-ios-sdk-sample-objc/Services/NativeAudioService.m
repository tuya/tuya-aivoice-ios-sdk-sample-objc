//
//  NativeAudioService.m
//  AIVoiceDemo
//

#import "NativeAudioService.h"
#import <TUniAudioDetectManager/ThingAudioDetectManagerNative.h>

@interface NativeAudioService ()
@property (nonatomic, strong) id<ThingAudioDetectManagerNativeProtocol> manager;
@end

@implementation NativeAudioService

+ (instancetype)sharedInstance {
    static NativeAudioService *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[NativeAudioService alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _manager = [ThingAudioDetectManagerNative sharedInstance];
    }
    return self;
}

#pragma mark - Main-thread helper

/// 将 block 派发到主线程执行。
static void native_main(void(^block)(void)) {
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

#pragma mark - Recording control

- (nullable ThingAudioRecordObject *)activeTaskWithDeviceId:(NSString *)deviceId {
    return [self.manager recordTransferTaskWithDeviceId:deviceId];
}

- (void)startRecordingWithDeviceId:(NSString *)deviceId
                            config:(ThingAudioRecordConfig *)config
                           success:(nullable void(^)(ThingAudioRecordObject *task))success
                           failure:(nullable NativeAudioFailure)failure {
    [self.manager startAudioRecordingWithDeviceId:deviceId config:config success:^(ThingAudioRecordObject *task) {
        native_main(^{ if (success) success(task); });
    } failure:^(NSError *error) {
        native_main(^{ if (failure) failure(error); });
    }];
}

- (void)pauseRecordingWithDeviceId:(NSString *)deviceId
                           success:(nullable void(^)(void))success
                           failure:(nullable NativeAudioFailure)failure {
    [self.manager pauseRecordTransferWithDeviceId:deviceId success:^{
        native_main(^{ if (success) success(); });
    } failure:^(NSError *error) {
        native_main(^{ if (failure) failure(error); });
    }];
}

- (void)resumeRecordingWithDeviceId:(NSString *)deviceId
                            success:(nullable void(^)(void))success
                            failure:(nullable NativeAudioFailure)failure {
    [self.manager resumeRecordTransferWithDeviceId:deviceId success:^{
        native_main(^{ if (success) success(); });
    } failure:^(NSError *error) {
        native_main(^{ if (failure) failure(error); });
    }];
}

- (void)stopRecordingWithDeviceId:(NSString *)deviceId
                          success:(nullable void(^)(void))success
                          failure:(nullable NativeAudioFailure)failure {
    [self.manager stopRecordTransferWithDeviceId:deviceId success:^{
        native_main(^{ if (success) success(); });
    } failure:^(NSError *error) {
        native_main(^{ if (failure) failure(error); });
    }];
}

#pragma mark - Listener forwarding

- (void)addRecordListener:(id<ThingAudioRecordManagerDelegate>)listener deviceId:(NSString *)deviceId {
    [self.manager addRecordListener:listener deviceId:deviceId];
}

- (void)removeRecordListener:(id<ThingAudioRecordManagerDelegate>)listener deviceId:(NSString *)deviceId {
    [self.manager removeRecordListener:listener deviceId:deviceId];
}

#pragma mark - File list & search

- (void)fetchAllRecordsWithSuccess:(nullable void(^)(NSArray<ThingAudioRecordFile *> *list))success
                           failure:(nullable NativeAudioFailure)failure {
    ThingAudioRecordFilesParams *params = [[ThingAudioRecordFilesParams alloc] init];
    // 按 recordTime 降序，展示最新录音在前。
    params.orderBy = @(1);
    params.asc = @(0);
    [self.manager getRecordTransferResultList:params success:^(NSArray<ThingAudioRecordFile *> *list) {
        native_main(^{ if (success) success(list ?: @[]); });
    } failure:^(NSError *error) {
        native_main(^{ if (failure) failure(error); });
    }];
}

- (void)searchRecordsWithKeyword:(NSString *)keyword
                         success:(nullable void(^)(NSArray<ThingAudioRecordSearchMixResultItem *> *list))success
                         failure:(nullable NativeAudioFailure)failure {
    ThingAudioRecordSearchMixParams *params = [[ThingAudioRecordSearchMixParams alloc] init];
    params.content = keyword;
    [self.manager searchRecordTransferResult:params success:^(NSArray<ThingAudioRecordSearchMixResultItem *> *list) {
        native_main(^{ if (success) success(list ?: @[]); });
    } failure:^(NSError *error) {
        native_main(^{ if (failure) failure(error); });
    }];
}

#pragma mark - File detail

- (void)fetchRecordDetailWithRecordId:(NSString *)recordId
                    amplitudeMaxCount:(NSInteger)amplitudeMaxCount
                              success:(nullable void(^)(ThingAudioRecordFile *file))success
                              failure:(nullable NativeAudioFailure)failure {
    [self.manager getRecordTransferResultDetail:recordId amplitudeMaxCount:amplitudeMaxCount success:^(ThingAudioRecordFile *file) {
        native_main(^{ if (success) success(file); });
    } failure:^(NSError *error) {
        native_main(^{ if (failure) failure(error); });
    }];
}

#pragma mark - Transcription & Summary content

- (void)fetchTranscriptionWithFileId:(long long)fileId
                             success:(nullable void(^)(NSString *text))success
                             failure:(nullable NativeAudioFailure)failure {
    [self.manager getRecordTransferRecognizeResult:fileId success:^(NSString *text) {
        native_main(^{ if (success) success(text ?: @""); });
    } failure:^(NSError *error) {
        native_main(^{ if (failure) failure(error); });
    }];
}

- (void)fetchSummaryWithFileId:(long long)fileId
                       success:(nullable void(^)(NSString *text))success
                       failure:(nullable NativeAudioFailure)failure {
    [self.manager getRecordTransferSummaryResult:fileId success:^(NSString *text) {
        native_main(^{ if (success) success(text ?: @""); });
    } failure:^(NSError *error) {
        native_main(^{ if (failure) failure(error); });
    }];
}

- (void)fetchTranscriptionSentencesWithFileId:(long long)fileId
                                      success:(nullable void(^)(NSArray<ThingAudioRecordAsrResult *> *list))success
                                      failure:(nullable NativeAudioFailure)failure {
    ThingAudioRecordAsrsParams *params = [[ThingAudioRecordAsrsParams alloc] init];
    params.fileId = @(fileId);
    [self.manager getRecordTransferRealTimeResult:params success:^(NSArray<ThingAudioRecordAsrResult *> *list) {
        native_main(^{ if (success) success(list ?: @[]); });
    } failure:^(NSError *error) {
        native_main(^{ if (failure) failure(error); });
    }];
}

#pragma mark - Offline processing

- (void)processRecordWithFileId:(long long)fileId
                       recordId:(NSString *)recordId
                       taskType:(NSInteger)taskType
                translationLang:(nullable NSString *)translationLang
                        success:(nullable void(^)(NSString *taskId))success
                        progress:(nullable void(^)(NSInteger progress))progress
                         failure:(nullable NativeAudioFailure)failure {
    ThingAudioRecordUploadFileParams *params = [[ThingAudioRecordUploadFileParams alloc] init];
    params.fileId = fileId;
    params.recordId = recordId;
    if (translationLang.length > 0) {
        params.transLang = translationLang;
    }
    // SDK 的 success 是 void(^)(void)，taskId 由方法返回值同步给出。
    NSString *taskId = [self.manager processRecordTransferResult:params
                                                        taskType:taskType
                                                        progress:^(double prog, int status) {
        native_main(^{ if (progress) progress((NSInteger)prog); });
    } success:^{
        native_main(^{ if (success) success(taskId); });
    } failure:^(NSError *error) {
        native_main(^{ if (failure) failure(error); });
    }];
}

@end
