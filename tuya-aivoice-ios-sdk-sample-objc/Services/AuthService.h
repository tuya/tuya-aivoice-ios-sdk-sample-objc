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

@interface AuthService : NSObject

+ (instancetype)sharedInstance;

/**
 * 发送验证码
 * @param userName 手机号或邮箱
 * @param countryCode 国家码，如 "86" 或 "1"
 * @param type 验证码类型，1: 注册验证码
 * @param success 成功回调
 * @param failure 失败回调
 */
- (void)sendVerifyCodeWithUserName:(NSString *)userName
                             region:(NSString *)region
                        countryCode:(NSString *)countryCode
                               type:(NSInteger)type
                            success:(AuthSuccessBlock)success
                            failure:(AuthFailureBlock)failure;

/**
 * 手机号注册
 * @param countryCode 国家码
 * @param phoneNumber 手机号
 * @param password 密码
 * @param code 验证码
 * @param success 成功回调
 * @param failure 失败回调
 */
- (void)registerByPhone:(NSString *)countryCode
             phoneNumber:(NSString *)phoneNumber
                password:(NSString *)password
                    code:(NSString *)code
                 success:(AuthSuccessBlock)success
                 failure:(AuthFailureBlock)failure;

/**
 * 手机号登录
 * @param countryCode 国家码
 * @param phoneNumber 手机号
 * @param password 密码
 * @param success 成功回调
 * @param failure 失败回调
 */
- (void)loginByPhone:(NSString *)countryCode
         phoneNumber:(NSString *)phoneNumber
            password:(NSString *)password
             success:(AuthSuccessBlock)success
             failure:(AuthFailureBlock)failure;

@end

NS_ASSUME_NONNULL_END
