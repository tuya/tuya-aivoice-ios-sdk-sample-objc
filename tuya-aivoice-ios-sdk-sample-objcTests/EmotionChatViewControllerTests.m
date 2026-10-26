@import XCTest;
#import "../tuya-aivoice-ios-sdk-sample-objc/Views/EmotionChat/EmotionChatViewController.h"
#import "../tuya-aivoice-ios-sdk-sample-objc/Services/EmotionVoiceInput.h"

@interface EmotionChatViewController (Testing)
- (NSMutableArray *)currentMessages;
- (void)sendText;
- (void)finishRecordingCancelled:(BOOL)cancelled;
- (void)discardPendingAudio;
- (void)sendPendingAudio;
- (void)recordGestureChanged:(UILongPressGestureRecognizer *)gesture;
- (void)keyboardChanged:(NSNotification *)notification;
@end

@interface EmotionTestEndedGesture : UILongPressGestureRecognizer
@end
@implementation EmotionTestEndedGesture
- (UIGestureRecognizerState)state { return UIGestureRecognizerStateEnded; }
@end

@interface EmotionTestVoiceInput : EmotionVoiceInput
@property (nonatomic, assign) NSTimeInterval testDuration;
@property (nonatomic, assign) NSUInteger cancellationCount;
@property (nonatomic, strong) NSURL *testURL;
@property (nonatomic, strong) NSMutableArray *completions;
@property (nonatomic, strong) NSMutableArray<NSURL *> *deletedURLs;
@end

@implementation EmotionTestVoiceInput
- (instancetype)init {
    self = [super init];
    if (self) {
        _testDuration = 2;
        _testURL = [NSURL fileURLWithPath:@"/tmp/emotion-test-recording.m4a"];
        _completions = [NSMutableArray array];
        _deletedURLs = [NSMutableArray array];
    }
    return self;
}
- (NSTimeInterval)duration { return self.testDuration; }
- (NSURL *)finishRecording { return self.testURL; }
- (void)cancelRecording { self.cancellationCount += 1; }
- (void)deleteRecording:(NSURL *)url { [self.deletedURLs addObject:url]; }
- (void)transcribeURL:(NSURL *)url completion:(void (^)(NSString *, NSError *))completion {
    [self.completions addObject:[completion copy]];
}
@end

@interface EmotionChatViewControllerTests : XCTestCase
@property (nonatomic, strong) EmotionChatViewController *controller;
@property (nonatomic, strong) EmotionTestVoiceInput *voiceInput;
@end

@implementation EmotionChatViewControllerTests

- (void)setUp {
    [super setUp];
    self.controller = [EmotionChatViewController new];
    [self.controller loadViewIfNeeded];
    self.voiceInput = [EmotionTestVoiceInput new];
    [self.controller setValue:self.voiceInput forKey:@"voiceInput"];
}

- (void)tearDown {
    self.controller = nil;
    self.voiceInput = nil;
    [super tearDown];
}

- (void)testWhitespaceDoesNotCreateMessage {
    UITextView *input = [self.controller valueForKey:@"textInput"];
    input.text = @"  \n ";
    [self.controller sendText];
    XCTAssertEqual(self.controller.currentMessages.count, 0);
}

- (void)testMessagesRemainIsolatedWhenSwitchingRoles {
    UITextView *input = [self.controller valueForKey:@"textInput"];
    input.text = @"只告诉知秋的话";
    [self.controller sendText];
    [self.controller setValue:@1 forKey:@"roleIndex"];
    XCTAssertEqual(self.controller.currentMessages.count, 0);
    input.text = @"只告诉听澜的话";
    [self.controller sendText];
    [self.controller setValue:@0 forKey:@"roleIndex"];
    XCTAssertEqual(self.controller.currentMessages.count, 1);
    XCTAssertEqualObjects([self.controller.currentMessages.firstObject valueForKey:@"text"], @"只告诉知秋的话");
}

- (void)testShortOrCancelledRecordingDoesNotCreateDraft {
    self.voiceInput.testDuration = 0.2;
    [self.controller finishRecordingCancelled:NO];
    XCTAssertNil([self.controller valueForKey:@"pendingURL"]);
    self.voiceInput.testDuration = 2;
    [self.controller finishRecordingCancelled:YES];
    XCTAssertNil([self.controller valueForKey:@"pendingURL"]);
    XCTAssertEqual(self.voiceInput.cancellationCount, 2);
    XCTAssertEqual(self.voiceInput.completions.count, 0);
}

- (void)testOldTranscriptionCannotOverwriteNewRecording {
    [self.controller finishRecordingCancelled:NO];
    void (^oldCompletion)(NSString *, NSError *) = self.voiceInput.completions.firstObject;
    [self.controller discardPendingAudio];
    [self.controller finishRecordingCancelled:NO];
    oldCompletion(@"上一段录音的迟到结果", nil);
    UITextView *review = [self.controller valueForKey:@"reviewText"];
    XCTAssertEqualObjects(review.text, @"");
    XCTAssertTrue([[self.controller valueForKey:@"recognizing"] boolValue]);
    void (^newCompletion)(NSString *, NSError *) = self.voiceInput.completions.lastObject;
    newCompletion(@"新的录音内容", nil);
    XCTAssertEqualObjects(review.text, @"新的录音内容");
}

- (void)testTranscriptionFailureStillAllowsSavingAudio {
    [self.controller finishRecordingCancelled:NO];
    void (^completion)(NSString *, NSError *) = self.voiceInput.completions.lastObject;
    completion(@"", [NSError errorWithDomain:@"test" code:1 userInfo:nil]);
    [self.controller sendPendingAudio];
    XCTAssertEqual(self.controller.currentMessages.count, 1);
    XCTAssertEqualObjects([self.controller.currentMessages.firstObject valueForKey:@"audioURL"], self.voiceInput.testURL);
    XCTAssertEqual(self.voiceInput.deletedURLs.count, 0);
    XCTAssertNil([self.controller valueForKey:@"pendingURL"]);
}

- (void)testReleaseAfterAutomaticStopDoesNotInvalidateTranscription {
    // 达到时长上限后先停止并转写，用户随后才松手。
    [self.controller finishRecordingCancelled:NO];
    [self.controller recordGestureChanged:[EmotionTestEndedGesture new]];
    void (^completion)(NSString *, NSError *) = self.voiceInput.completions.lastObject;
    completion(@"录音结束后的转写", nil);
    UITextView *review = [self.controller valueForKey:@"reviewText"];
    XCTAssertEqualObjects(review.text, @"录音结束后的转写");
    XCTAssertFalse([[self.controller valueForKey:@"recognizing"] boolValue]);
}

- (void)testEditedTranscriptIsSavedWithAudio {
    [self.controller finishRecordingCancelled:NO];
    void (^completion)(NSString *, NSError *) = self.voiceInput.completions.lastObject;
    completion(@"识别的内容", nil);
    UITextView *review = [self.controller valueForKey:@"reviewText"];
    review.text = @"校对后的内容";
    [self.controller sendPendingAudio];
    XCTAssertEqualObjects([self.controller.currentMessages.firstObject valueForKey:@"text"], @"校对后的内容");
    XCTAssertNil(self.controller.agentConfiguration.solutionCode);
    XCTAssertEqual(self.controller.agentConfiguration.roleIds.count, 0);
}

- (void)testVoiceReviewRemainsVisibleAboveKeyboard {
    UIWindowScene *scene = (UIWindowScene *)UIApplication.sharedApplication.connectedScenes.anyObject;
    UIWindow *window = [[UIWindow alloc] initWithWindowScene:scene];
    window.rootViewController = self.controller;
    [window makeKeyAndVisible];
    [self.controller finishRecordingCancelled:NO];
    void (^completion)(NSString *, NSError *) = self.voiceInput.completions.lastObject;
    completion(@"最近工作有些累，想找个人聊聊。", nil);
    CGRect bounds = self.controller.view.bounds;
    CGRect keyboard = CGRectMake(0, bounds.size.height - 320, bounds.size.width, 320);
    [self.controller keyboardChanged:[NSNotification notificationWithName:UIKeyboardWillChangeFrameNotification object:nil userInfo:@{
        UIKeyboardFrameEndUserInfoKey: [NSValue valueWithCGRect:keyboard],
        UIKeyboardAnimationDurationUserInfoKey: @0,
        UIKeyboardAnimationCurveUserInfoKey: @(UIViewAnimationCurveEaseInOut),
    }]];
    [self.controller.view layoutIfNeeded];
    UIView *review = [self.controller valueForKey:@"reviewPanel"];
    CGRect frame = [review convertRect:review.bounds toView:self.controller.view];
    XCTAssertGreaterThanOrEqual(CGRectGetMinY(frame), self.controller.view.safeAreaInsets.top + 56);
    XCTAssertLessThanOrEqual(CGRectGetMaxY(frame), CGRectGetMinY(keyboard));
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:bounds.size];
    UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [self.controller.view drawViewHierarchyInRect:bounds afterScreenUpdates:YES];
    }];
    XCTAttachment *attachment = [XCTAttachment attachmentWithImage:image];
    attachment.name = @"voice-review-keyboard-layout";
    attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:attachment];
    window.hidden = YES;
}

@end
