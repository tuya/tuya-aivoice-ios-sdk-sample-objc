//
//  ActivatorService.m
//  AIVoiceDemo
//
//  Created by Bacson on 2026/1/29.
//

#import "ActivatorService.h"
#import <ThingSmartDeviceKit/ThingSmartDeviceKit.h>
#import <ThingSmartBizCore/ThingSmartBizCore.h>
#import <ThingModuleServices/ThingActivatorProtocol.h>

/*
 MARK: AIVoice 配网服务
 配网相关接口示例，配网快速接入，支持多种配网方式方式，详情请参考：
 https://developer.tuya.com/cn/docs/app-development/activator?id=Ka5cgmlzpfig4
*/

@interface ActivatorService ()

@property (nonatomic, copy, nullable) ActivatorCompletionBlock completionBlock;

@end

@implementation ActivatorService

+ (instancetype)sharedInstance {
    static ActivatorService *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[ActivatorService alloc] init];
    });
    return instance;
}

//#pragma mark - ThingFamilyProtocol
//- (long long)currentFamilyId {
//    ThingSmartHome *home = [[ThingSmartHomeManager new] homes];
//    if (!home) {
//        NSLog(@"ActivatorService: 当前家庭不存在，无法进行配网");
//        return 0;
//    }
//    return home.homeId;
//}


#pragma mark - Public Methods

- (void)gotoDeviceConfig {
    id<ThingActivatorProtocol> impl = [[ThingSmartBizCore sharedInstance] serviceOfProtocol:@protocol(ThingActivatorProtocol)];
    if (!impl) {
        NSLog(@"ActivatorService: ThingActivatorProtocol 服务不可用");
        return;
    }
    
    [impl gotoCategoryViewController];
    
    // 设置配网完成回调
    if (self.completionBlock) {
        [impl activatorCompletion:ThingActivatorCompletionNodeNormal customJump:NO completionBlock:self.completionBlock];
    }
}

- (void)gotoQRCodeConfig {
    id<ThingActivatorProtocol> impl = [[ThingSmartBizCore sharedInstance] serviceOfProtocol:@protocol(ThingActivatorProtocol)];
    if (!impl) {
        NSLog(@"ActivatorService: ThingActivatorProtocol 服务不可用");
        return;
    }
    
    if ([impl respondsToSelector:@selector(gotoQRCodeViewControllerWithUserInfo:)]) {
        [impl gotoQRCodeViewControllerWithUserInfo:nil];
        
        // 设置配网完成回调
        if (self.completionBlock) {
            [impl activatorCompletion:ThingActivatorCompletionNodeNormal customJump:NO completionBlock:self.completionBlock];
        }
    } else {
        NSLog(@"ActivatorService: 扫码配网功能不可用");
    }
}

- (void)setActivatorCompletion:(ActivatorCompletionBlock)completionBlock {
    self.completionBlock = completionBlock;
}

@end
