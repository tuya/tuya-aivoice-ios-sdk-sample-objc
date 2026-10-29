@import XCTest;
#import "../tuya-aivoice-ios-sdk-sample-objc/Services/EmotionAgentDiagnostics.h"

@interface EmotionAgentTestRequest : NSObject
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *calls;
@property (nonatomic, strong) NSArray *responses;
@end

@implementation EmotionAgentTestRequest
- (instancetype)init {
    self = [super init];
    if (self) { _calls = [NSMutableArray array]; _responses = @[]; }
    return self;
}
- (NSString *)lastRequestId { return @"test-request-id"; }
- (void)requestWithApiName:(NSString *)apiName postData:(NSDictionary *)postData version:(NSString *)version
                   success:(void (^)(id))success failure:(void (^)(NSError *))failure {
    NSUInteger index = self.calls.count;
    [self.calls addObject:@{@"apiName": apiName, @"version": version, @"postData": postData ?: NSNull.null}];
    id result = index < self.responses.count ? self.responses[index] : @{};
    if ([result isKindOfClass:NSError.class]) { failure(result); }
    else { success(result); }
}
@end

@interface EmotionAgentDiagnosticsTests : XCTestCase
@end

@implementation EmotionAgentDiagnosticsTests

- (void)testDeviceQueriesContinueAfterFailure {
    EmotionAgentTestRequest *request = [EmotionAgentTestRequest new];
    request.responses = @[
        @{@"roleId": @"cloud-role", @"bindRoleType": @1, @"roleName": @"云端角色"},
        [NSError errorWithDomain:@"test" code:403 userInfo:@{NSLocalizedDescriptionKey: @"No permission"}],
        @{@"emotion": @"HAPPY", @"text": @"😀"},
    ];
    EmotionAgentDiagnostics *diagnostics = [[EmotionAgentDiagnostics alloc] initWithRequest:(id)request];
    XCTestExpectation *done = [self expectationWithDescription:@"全部 ATOP 查询完成"];
    __block NSDictionary *finalReport;
    [diagnostics fetchDeviceId:@"vdevo179327539385299" productId:@"bjgihalp" completion:^(NSDictionary *report) {
        finalReport = report;
        XCTAssertEqual(report.count, 4);
        XCTAssertTrue([report[@"initializedRole"][@"success"] boolValue]);
        XCTAssertFalse([report[@"roleTemplates"][@"success"] boolValue]);
        XCTAssertTrue([report[@"currentEmotion"][@"success"] boolValue]);
        XCTAssertEqualObjects(report[@"initializedRole"][@"requestId"], @"test-request-id");
        XCTAssertFalse(diagnostics.isRunning);
        [done fulfill];
    }];
    [self waitForExpectationsWithTimeout:2 handler:nil];
    XCTAssertFalse([finalReport[@"project"][@"success"] boolValue]);
    XCTAssertEqualObjects(finalReport[@"project"][@"status"], @"unsupported");
    XCTAssertEqual(request.calls.count, 3);
    NSArray *expectedAPIs = @[
        @"m.life.ai.agent.role.initialize-agent-role-binding",
        @"m.life.ai.agent.role.role-template.list",
        @"m.life.ai.agent.chat.chat-emotion.current",
    ];
    for (NSUInteger index = 0; index < request.calls.count; index++) {
        NSDictionary *call = request.calls[index];
        XCTAssertEqualObjects(call[@"apiName"], expectedAPIs[index]);
        XCTAssertEqualObjects(call[@"version"], @"1.0");
        XCTAssertEqualObjects(call[@"postData"][@"devId"], @"vdevo179327539385299");
        XCTAssertNil(call[@"postData"][@"productId"]);
        XCTAssertFalse([call[@"apiName"] containsString:@"/v1.0/"]);
    }
    XCTAssertNil(request.calls[1][@"postData"][@"roleId"]);
    XCTAssertNil(request.calls[1][@"postData"][@"bindRoleType"]);
    XCTAssertEqualObjects(request.calls[2][@"postData"][@"devId"], @"vdevo179327539385299");
}

- (void)testJSONResponseRedactsPrivateFieldsAndDetectsBusinessFailure {
    EmotionAgentTestRequest *request = [EmotionAgentTestRequest new];
    request.responses = @[
        @{@"roleId": @"role-1", @"bindRoleType": @0, @"memoryInfo": @"private-memory", @"lastTextAnswer": @"private-answer",
          @"nested": @{@"agentToken": @"private-token"}},
        @[],
        @{@"list": @[]},
    ];
    EmotionAgentDiagnostics *diagnostics = [[EmotionAgentDiagnostics alloc] initWithRequest:(id)request];
    XCTestExpectation *done = [self expectationWithDescription:@"兼容响应格式"];
    [diagnostics fetchDeviceId:@"test-device" productId:@"test-product" completion:^(NSDictionary *report) {
        NSDictionary *role = report[@"initializedRole"][@"response"];
        XCTAssertEqualObjects(role[@"roleId"], @"role-1");
        XCTAssertEqualObjects(role[@"memoryInfo"], @"<REDACTED>");
        XCTAssertEqualObjects(role[@"lastTextAnswer"], @"<REDACTED>");
        XCTAssertEqualObjects(role[@"nested"][@"agentToken"], @"<REDACTED>");
        [done fulfill];
    }];
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

- (void)testMissingDeviceDoesNotSendRequests {
    EmotionAgentTestRequest *request = [EmotionAgentTestRequest new];
    EmotionAgentDiagnostics *diagnostics = [[EmotionAgentDiagnostics alloc] initWithRequest:(id)request];
    [diagnostics fetchDeviceId:@"" productId:@"test-product" completion:^(NSDictionary *report) {
        XCTAssertFalse([report[@"diagnostic"][@"success"] boolValue]);
    }];
    XCTAssertEqual(request.calls.count, 0);
}

@end
