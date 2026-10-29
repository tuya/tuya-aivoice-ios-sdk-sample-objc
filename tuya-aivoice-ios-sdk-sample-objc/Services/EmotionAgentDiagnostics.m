#import "EmotionAgentDiagnostics.h"
#import <ThingSmartNetworkKit/ThingSmartRequest.h>

// C 端 Agent ATOP 命名空间；角色面板 REST 路径不能直接改写为 ATOP 名称.
static NSString * const EmotionAgentRoleAPIBase = @"m.life.ai.agent.role.";
static NSString * const EmotionAgentChatAPIBase = @"m.life.ai.agent.chat.";
static NSString * const EmotionAgentAPIVersion = @"1.0";

/// 配置日志保留人设与能力字段，移除凭证、历史回复和个人记忆。
static id EmotionAgentLogValue(id value) {
    if ([value isKindOfClass:NSDictionary.class]) {
        NSMutableDictionary *result = [NSMutableDictionary dictionary];
        for (NSString *key in value) {
            NSString *lower = key.lowercaseString;
            BOOL privateValue = [lower containsString:@"token"] || [lower containsString:@"secret"] ||
                [lower containsString:@"password"] || [lower containsString:@"authorization"] ||
                [lower containsString:@"localkey"] || [lower containsString:@"memory"] ||
                [lower isEqualToString:@"lasttextanswer"] || [lower isEqualToString:@"rolevariables"] ||
                [lower isEqualToString:@"sid"] || [lower isEqualToString:@"sessionid"];
            result[key] = privateValue ? @"<REDACTED>" : EmotionAgentLogValue(value[key]);
        }
        return result;
    }
    if ([value isKindOfClass:NSArray.class]) {
        NSMutableArray *result = [NSMutableArray array];
        for (id item in value) { [result addObject:EmotionAgentLogValue(item)]; }
        return result;
    }
    return value ?: NSNull.null;
}

static void EmotionAgentLog(NSString *runId, NSString *event, id payload) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:EmotionAgentLogValue(payload)
                                                  options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:nil];
    NSString *json = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : @"无法序列化响应";
    NSLog(@"[EmotionAgentConfig][%@] %@ %@", runId, event, json);
}

@interface EmotionAgentDiagnostics ()
@property (nonatomic, strong) ThingSmartRequest *request;
@property (nonatomic, assign, readwrite, getter=isRunning) BOOL running;
@end

@implementation EmotionAgentDiagnostics

- (instancetype)init { return [self initWithRequest:[ThingSmartRequest new]]; }

- (instancetype)initWithRequest:(ThingSmartRequest *)request {
    self = [super init];
    if (self) { _request = request; }
    return self;
}

- (void)fetchDeviceId:(NSString *)deviceId productId:(NSString *)productId completion:(void (^)(NSDictionary<NSString *, NSDictionary *> *))completion {
    NSAssert(NSThread.isMainThread, @"配置诊断需要在主线程发起");
    if (self.running || deviceId.length == 0) {
        completion(@{@"diagnostic": @{@"success": @NO, @"message": self.running ? @"配置查询正在进行" : @"未设置测试设备 devId"}});
        return;
    }
    self.running = YES;
    NSString *runId = NSUUID.UUID.UUIDString;
    EmotionAgentLog(runId, @"begin", @{@"devId": deviceId, @"productId": productId ?: @"",
        @"scope": @"查询 devId 当前默认项目和绑定角色；角色列表不等于产品全部方案列表"});
    NSMutableArray *queries = [@[
        @{@"name": @"initializedRole", @"apiName": [EmotionAgentRoleAPIBase stringByAppendingString:@"initialize-agent-role-binding"], @"params": @{@"devId": deviceId}},
        @{@"name": @"roleTemplates", @"apiName": [EmotionAgentRoleAPIBase stringByAppendingString:@"role-template.list"], @"params": @{@"devId": deviceId}},
        @{@"name": @"currentEmotion", @"apiName": [EmotionAgentChatAPIBase stringByAppendingString:@"chat-emotion.current"], @"params": @{@"devId": deviceId}},
    ] mutableCopy];
    NSMutableDictionary *report = [@{
        @"project": @{
            @"success": @NO,
            @"status": @"unsupported",
            @"message": @"ATOP 未提供 get-agent-project-role；小程序该信息走 panel REST/highway 接口，本次按要求不发送 highway 请求"
        }
    } mutableCopy];
    EmotionAgentLog(runId, @"unsupported", report[@"project"]);
    [self fetchQueries:queries index:0 runId:runId report:report completion:completion];
}

- (void)fetchQueries:(NSMutableArray<NSDictionary *> *)queries index:(NSUInteger)index runId:(NSString *)runId
              report:(NSMutableDictionary *)report completion:(void (^)(NSDictionary<NSString *, NSDictionary *> *))completion {
    if (index == queries.count) {
        self.running = NO;
        EmotionAgentLog(runId, @"complete", @{@"queryCount": @(report.count)});
        completion([report copy]);
        return;
    }
    NSMutableDictionary *query = [queries[index] mutableCopy];
    NSString *apiName = query[@"apiName"];
    NSDictionary *params = query[@"params"];
    NSTimeInterval start = NSDate.timeIntervalSinceReferenceDate;
    EmotionAgentLog(runId, @"request", @{@"name": query[@"name"], @"method": @"ATOP", @"apiName": apiName,
        @"version": EmotionAgentAPIVersion, @"postData": params});
    [self.request requestWithApiName:apiName postData:params version:EmotionAgentAPIVersion success:^(id response) {
        dispatch_async(dispatch_get_main_queue(), ^{
            id decoded = response;
            if ([decoded isKindOfClass:NSString.class]) {
                NSData *data = [decoded dataUsingEncoding:NSUTF8StringEncoding];
                decoded = data ? [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingFragmentsAllowed error:nil] : nil;
            }
            NSDictionary *envelope = [decoded isKindOfClass:NSDictionary.class] ? decoded : nil;
            id successValue = envelope[@"success"];
            BOOL explicitFailure = [successValue respondsToSelector:@selector(boolValue)] && ![successValue boolValue];
            BOOL validPayload = [decoded isKindOfClass:NSDictionary.class] || [decoded isKindOfClass:NSArray.class];
            BOOL succeeded = validPayload && !explicitFailure;
            NSMutableDictionary *entry = [@{@"success": @(succeeded), @"apiName": apiName,
                @"version": EmotionAgentAPIVersion,
                @"requestId": self.request.lastRequestId ?: @"",
                @"elapsedMs": @((NSInteger)((NSDate.timeIntervalSinceReferenceDate - start) * 1000)),
                @"response": EmotionAgentLogValue(decoded)} mutableCopy];
            if (!validPayload) { entry[@"message"] = @"响应为空或不是有效 JSON 配置"; }
            // 记录 SDK 交付的原始结构，兼容完整 envelope 与已拆包的 result。
            report[query[@"name"]] = entry;
            EmotionAgentLog(runId, succeeded ? @"response" : @"apiFailure", entry);
            [self fetchQueries:queries index:index + 1 runId:runId report:report completion:completion];
        });
    } failure:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSDictionary *entry = @{@"success": @NO, @"apiName": apiName, @"version": EmotionAgentAPIVersion,
                @"domain": error.domain ?: @"",
                @"requestId": self.request.lastRequestId ?: @"",
                @"code": @(error.code), @"message": error.localizedDescription ?: @"请求失败",
                @"reason": error.userInfo[NSLocalizedFailureReasonErrorKey] ?: @"",
                @"elapsedMs": @((NSInteger)((NSDate.timeIntervalSinceReferenceDate - start) * 1000))};
            report[query[@"name"]] = entry;
            EmotionAgentLog(runId, @"requestFailure", entry);
            // 单个接口无权限或未开通时继续，便于看出该设备实际可访问的配置。
            [self fetchQueries:queries index:index + 1 runId:runId report:report completion:completion];
        });
    }];
}

@end
