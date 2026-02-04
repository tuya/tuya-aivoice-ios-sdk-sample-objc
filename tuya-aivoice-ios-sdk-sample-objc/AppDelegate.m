//
//  AppDelegate.m
//  AIVoiceDemo
//
//  Created by Bacson on 2026/1/28.
//

#import "AppDelegate.h"
#import "AppKey.h"
#import "ActivatorService.h"
#import <ThingSmartBizCore/ThingSmartBizCore.h>
#import <ThingModuleServices/ThingFamilyProtocol.h>
#import <ThingSmartBaseKit/ThingSmartBaseKit.h>
#import <ThingSmartMiniAppBizBundle/ThingSmartMiniAppBizBundle.h>
#import <ThingModuleManager/ThingModuleManager.h>

@interface AppDelegate ()

@end

@implementation AppDelegate

- (UIWindow *)window {
    // iOS 13+ Scene-based 应用中，返回当前活跃的 window
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *windowScene in [UIApplication sharedApplication].connectedScenes) {
            if (windowScene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *w in windowScene.windows) {
                    if (w.isKeyWindow) {
                        return w;
                    }
                }
                // 如果没有找到 keyWindow，返回第一个 window
                if (windowScene.windows.count > 0) {
                    return windowScene.windows.firstObject;
                }
            }
        }
        return nil;
    } else {
        // iOS 13 以下，使用传统方式
        return [UIApplication sharedApplication].keyWindow;
    }
}

- (void)setWindow:(UIWindow *)window {
    // 在 Scene-based 应用中，window 由 SceneDelegate 管理，这里不做任何操作
    // 这个方法只是为了兼容性而存在
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    [[ThingSmartSDK sharedInstance] startWithAppKey:APP_KEY secretKey:APP_SECRET_KEY];
#if DEBUG
    [[ThingSmartSDK sharedInstance] setDebugMode:YES];
#endif
    
    // 初始化 MiniApp SDK
    [[ThingMiniAppClient initialClient] initialize];
    
    // 开启 vConsole 调试开关
    [[ThingMiniAppClient debugClient] vConsoleDebugEnable:YES];
    
    // 注册配网协议实现
    [[ThingSmartBizCore sharedInstance] registerService:@protocol(ThingFamilyProtocol) withInstance:[ActivatorService sharedInstance]];

    
    return [[ThingModuleManager sharedInstance] application:application didFinishLaunchingWithOptions:launchOptions];
}


#pragma mark - UISceneSession lifecycle


- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession options:(UISceneConnectionOptions *)options {
    // Called when a new scene session is being created.
    // Use this method to select a configuration to create the new scene with.
    return [[UISceneConfiguration alloc] initWithName:@"Default Configuration" sessionRole:connectingSceneSession.role];
}


- (void)application:(UIApplication *)application didDiscardSceneSessions:(NSSet<UISceneSession *> *)sceneSessions {
    // Called when the user discards a scene session.
    // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
    // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
}


@end
