//
//  AuthService.m
//  AIVoiceDemo
//
//  Created by Bacson on 2026/1/28.
//

#import "AuthService.h"
#import <ThingSmartBaseKit/ThingSmartUser.h>

@implementation AuthService

+ (instancetype)sharedInstance {
    static AuthService *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[AuthService alloc] init];
    });
    return instance;
}

- (void)sendVerifyCodeWithUserName:(NSString *)userName
                             region:(NSString *)region
                        countryCode:(NSString *)countryCode
                               type:(NSInteger)type
                            success:(AuthSuccessBlock)success
                            failure:(AuthFailureBlock)failure {
    [[ThingSmartUser sharedInstance] sendVerifyCodeWithUserName:userName
                                                          region:region
                                                     countryCode:countryCode
                                                            type:type
                                                         success:^{
        if (success) {
            success();
        }
    } failure:^(NSError *error) {
        if (failure) {
            failure(error);
        }
    }];
}

- (void)registerByPhone:(NSString *)countryCode
             phoneNumber:(NSString *)phoneNumber
                password:(NSString *)password
                    code:(NSString *)code
                 success:(AuthSuccessBlock)success
                 failure:(AuthFailureBlock)failure {
    [[ThingSmartUser sharedInstance] registerByPhone:countryCode
                                          phoneNumber:phoneNumber
                                             password:password
                                                 code:code
                                              success:^{
        if (success) {
            success();
        }
    } failure:^(NSError *error) {
        if (failure) {
            failure(error);
        }
    }];
}

- (void)loginByPhone:(NSString *)countryCode
         phoneNumber:(NSString *)phoneNumber
            password:(NSString *)password
             success:(AuthSuccessBlock)success
             failure:(AuthFailureBlock)failure {
    [[ThingSmartUser sharedInstance] loginByPhone:countryCode
                                      phoneNumber:phoneNumber
                                         password:password
                                          success:^{
        if (success) {
            success();
        }
    } failure:^(NSError *error) {
        if (failure) {
            failure(error);
        }
    }];
}

@end
