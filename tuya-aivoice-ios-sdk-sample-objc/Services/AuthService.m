//
//  AuthService.m
//  AIVoiceDemo
//
//  Created by Bacson on 2026/1/28.
//

#import "AuthService.h"
#import <ThingSmartBaseKit/ThingSmartBaseKit.h>


/*
 MARK: AIVoice 登录注册服务
 登录注册相关接口示例，登录注册支持多种方式，详情请参考：
 https://developer.tuya.com/cn/docs/app-development/user?id=Ka5cgmm97jlt2
*/
@implementation AuthService

+ (instancetype)sharedInstance {
    static AuthService *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[AuthService alloc] init];
    });
    return instance;
}

- (NSString *)getDefaultRegionWithCountryCode:(NSString *)countryCode {
    return [[ThingSmartUser sharedInstance] getDefaultRegionWithCountryCode:countryCode];
}

#pragma mark - 验证码

- (void)getWhiteListWhoCanSendMobileCodeSuccess:(void (^)(NSString *))success
                                        failure:(AuthFailureBlock)failure {
    [[ThingSmartUser sharedInstance] getWhiteListWhoCanSendMobileCodeSuccess:^(NSString *regions) {
        if (success) success(regions);
    } failure:^(NSError *error) {
        if (failure) failure(error);
    }];
}

- (void)sendVerifyCodeWithUserName:(NSString *)userName
                             region:(NSString *)region
                        countryCode:(NSString *)countryCode
                               type:(AuthVerifyCodeType)type
                            success:(AuthSuccessBlock)success
                            failure:(AuthFailureBlock)failure {
    [[ThingSmartUser sharedInstance] sendVerifyCodeWithUserName:userName
                                                          region:region
                                                     countryCode:countryCode
                                                            type:(NSInteger)type
                                                         success:^{
        if (success) success();
    } failure:^(NSError *error) {
        if (failure) failure(error);
    }];
}

- (void)checkCodeWithUserName:(NSString *)userName
                       region:(NSString *)region
                  countryCode:(NSString *)countryCode
                         code:(NSString *)code
                         type:(AuthVerifyCodeType)type
                      success:(void (^)(BOOL))success
                      failure:(AuthFailureBlock)failure {
    [[ThingSmartUser sharedInstance] checkCodeWithUserName:userName
                                                    region:region
                                               countryCode:countryCode
                                                      code:code
                                                      type:(NSInteger)type
                                                   success:^(BOOL result) {
        if (success) success(result);
    } failure:^(NSError *error) {
        if (failure) failure(error);
    }];
}

#pragma mark - 手机号

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
        if (success) success();
    } failure:^(NSError *error) {
        if (failure) failure(error);
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
        if (success) success();
    } failure:^(NSError *error) {
        if (failure) failure(error);
    }];
}

- (void)loginByPhoneWithCode:(NSString *)countryCode
                 phoneNumber:(NSString *)phoneNumber
                        code:(NSString *)code
                     success:(AuthSuccessBlock)success
                     failure:(AuthFailureBlock)failure {
    [[ThingSmartUser sharedInstance] loginWithMobile:phoneNumber
                                         countryCode:countryCode
                                                code:code
                                             success:^{
        if (success) success();
    } failure:^(NSError *error) {
        if (failure) failure(error);
    }];
}

- (void)resetPasswordByPhone:(NSString *)countryCode
                 phoneNumber:(NSString *)phoneNumber
                 newPassword:(NSString *)newPassword
                        code:(NSString *)code
                     success:(AuthSuccessBlock)success
                     failure:(AuthFailureBlock)failure {
    [[ThingSmartUser sharedInstance] resetPasswordByPhone:countryCode
                                              phoneNumber:phoneNumber
                                              newPassword:newPassword
                                                     code:code
                                                  success:^{
        if (success) success();
    } failure:^(NSError *error) {
        if (failure) failure(error);
    }];
}

#pragma mark - 邮箱

- (void)registerByEmail:(NSString *)countryCode
                  email:(NSString *)email
               password:(NSString *)password
                   code:(NSString *)code
                success:(AuthSuccessBlock)success
                failure:(AuthFailureBlock)failure {
    [[ThingSmartUser sharedInstance] registerByEmail:countryCode
                                                email:email
                                             password:password
                                                 code:code
                                              success:^{
        if (success) success();
    } failure:^(NSError *error) {
        if (failure) failure(error);
    }];
}

- (void)loginByEmail:(NSString *)countryCode
               email:(NSString *)email
            password:(NSString *)password
             success:(AuthSuccessBlock)success
             failure:(AuthFailureBlock)failure {
    [[ThingSmartUser sharedInstance] loginByEmail:countryCode
                                            email:email
                                         password:password
                                          success:^{
        if (success) success();
    } failure:^(NSError *error) {
        if (failure) failure(error);
    }];
}

- (void)loginByEmailWithCode:(NSString *)countryCode
                       email:(NSString *)email
                        code:(NSString *)code
                     success:(AuthSuccessBlock)success
                     failure:(AuthFailureBlock)failure {
    [[ThingSmartUser sharedInstance] loginWithEmail:email
                                        countryCode:countryCode
                                               code:code
                                            success:^{
        if (success) success();
    } failure:^(NSError *error) {
        if (failure) failure(error);
    }];
}

- (void)resetPasswordByEmail:(NSString *)countryCode
                       email:(NSString *)email
                 newPassword:(NSString *)newPassword
                        code:(NSString *)code
                     success:(AuthSuccessBlock)success
                     failure:(AuthFailureBlock)failure {
    [[ThingSmartUser sharedInstance] resetPasswordByEmail:countryCode
                                                   email:email
                                             newPassword:newPassword
                                                    code:code
                                                 success:^{
        if (success) success();
    } failure:^(NSError *error) {
        if (failure) failure(error);
    }];
}

#pragma mark - 通用注册：邮箱/手机
/**
 * @param account 手机号或邮箱
 */
- (void)registerWithCountryCode:(NSString *)countryCode
                        account:(NSString *)account
                       password:(NSString *)password
                           code:(NSString *)code
                        success:(AuthSuccessBlock)success
                        failure:(AuthFailureBlock)failure {
    
    NSString *region = [self getDefaultRegionWithCountryCode:countryCode];
    
    [[ThingSmartUser sharedInstance] registerWithUserName:account
                                                   region:region
                                              countryCode:countryCode
                                                     code:code
                                                 password:password
                                                  success:^{
        if (success) success();
    } failure:^(NSError *error) {
        if (failure) failure(error);
    }];
}


@end
