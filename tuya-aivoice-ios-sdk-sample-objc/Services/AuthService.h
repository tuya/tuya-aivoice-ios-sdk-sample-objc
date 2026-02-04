//
//  AuthService.h
//  AIVoiceDemo
//
//  Created by Bacson on 2026/1/28.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^AuthSuccessBlock)(void);
typedef void(^AuthFailureBlock)(NSError *error);

/** 验证码类型（与涂鸦 SDK 一致） */
typedef NS_ENUM(NSInteger, AuthVerifyCodeType) {
    AuthVerifyCodeTypeRegister = 1,    // 注册
    AuthVerifyCodeTypeLogin = 2,      // 登录
    AuthVerifyCodeTypeResetPassword = 3  // 重置密码
};

@interface AuthService : NSObject

+ (instancetype)sharedInstance;

#pragma mark - 验证码

/**
 * 查询验证码服务可用地区
 * @param success 成功回调，返回可用地区信息
 * @param failure 失败回调
 */
- (void)getWhiteListWhoCanSendMobileCodeSuccess:(void(^)(NSString *regions))success
                                        failure:(AuthFailureBlock)failure;

/**
 * 发送验证码（手机号或邮箱通用）
 * @param userName 手机号或邮箱
 * @param region 地区，手机号可通过 getDefaultRegionWithCountryCode: 获取，邮箱可传 nil
 * @param countryCode 国家码，如 "86"
 * @param type 类型：AuthVerifyCodeTypeRegister / Login / ResetPassword
 */
- (void)sendVerifyCodeWithUserName:(NSString *)userName
                             region:(nullable NSString *)region
                        countryCode:(NSString *)countryCode
                               type:(AuthVerifyCodeType)type
                            success:(AuthSuccessBlock)success
                            failure:(AuthFailureBlock)failure;

/**
 * 校验验证码
 * @param type 与发送时一致：1 注册 2 登录 3 重置密码
 */
- (void)checkCodeWithUserName:(NSString *)userName
                        region:(nullable NSString *)region
                   countryCode:(NSString *)countryCode
                          code:(NSString *)code
                          type:(AuthVerifyCodeType)type
                       success:(void(^)(BOOL valid))success
                       failure:(AuthFailureBlock)failure;

/**
 * 获取默认 region（用于手机号发验证码）
 */
- (NSString *)getDefaultRegionWithCountryCode:(NSString *)countryCode;

#pragma mark - 手机号

- (void)registerByPhone:(NSString *)countryCode
             phoneNumber:(NSString *)phoneNumber
                password:(NSString *)password
                    code:(NSString *)code
                 success:(AuthSuccessBlock)success
                 failure:(AuthFailureBlock)failure;

- (void)loginByPhone:(NSString *)countryCode
         phoneNumber:(NSString *)phoneNumber
            password:(NSString *)password
             success:(AuthSuccessBlock)success
             failure:(AuthFailureBlock)failure;

/** 手机号 + 验证码登录 */
- (void)loginByPhoneWithCode:(NSString *)countryCode
                 phoneNumber:(NSString *)phoneNumber
                        code:(NSString *)code
                     success:(AuthSuccessBlock)success
                     failure:(AuthFailureBlock)failure;

- (void)resetPasswordByPhone:(NSString *)countryCode
                 phoneNumber:(NSString *)phoneNumber
                 newPassword:(NSString *)newPassword
                        code:(NSString *)code
                     success:(AuthSuccessBlock)success
                     failure:(AuthFailureBlock)failure;

#pragma mark - 邮箱

- (void)registerByEmail:(NSString *)countryCode
                  email:(NSString *)email
               password:(NSString *)password
                   code:(NSString *)code
                success:(AuthSuccessBlock)success
                failure:(AuthFailureBlock)failure;

- (void)loginByEmail:(NSString *)countryCode
               email:(NSString *)email
            password:(NSString *)password
             success:(AuthSuccessBlock)success
             failure:(AuthFailureBlock)failure;

/** 邮箱 + 验证码登录 */
- (void)loginByEmailWithCode:(NSString *)countryCode
                       email:(NSString *)email
                        code:(NSString *)code
                     success:(AuthSuccessBlock)success
                     failure:(AuthFailureBlock)failure;

- (void)resetPasswordByEmail:(NSString *)countryCode
                       email:(NSString *)email
                 newPassword:(NSString *)newPassword
                        code:(NSString *)code
                     success:(AuthSuccessBlock)success
                     failure:(AuthFailureBlock)failure;

#pragma mark - 通用注册：邮箱/手机

- (void)registerWithCountryCode:(NSString *)countryCode
                        account:(NSString *)account
                       password:(NSString *)password
                           code:(NSString *)code
                        success:(AuthSuccessBlock)success
                        failure:(AuthFailureBlock)failure;

@end

NS_ASSUME_NONNULL_END
