//
//  CountryModel.h
//  AIVoiceDemo
//
//  国家/地区模型，用于登录注册时选择国家，免去手动输入国家码。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CountryModel : NSObject

/** 中文名称，如 "中国" */
@property (nonatomic, copy, readonly) NSString *name;
/** 英文名称，如 "China" */
@property (nonatomic, copy, readonly) NSString *englishName;
/** 国家码（不含 +），如 "86" */
@property (nonatomic, copy, readonly) NSString *countryCode;
/** ISO 3166-1 alpha-2，如 "CN"，用于生成国旗 */
@property (nonatomic, copy, readonly) NSString *isoCode;

/** 国旗 emoji，由 isoCode 生成 */
@property (nonatomic, copy, readonly) NSString *flag;
/** 列表展示文案，如 "🇨🇳 中国 +86" */
@property (nonatomic, copy, readonly) NSString *displayText;
/** 输入框旁展示的紧凑文案，如 "🇨🇳 +86" */
@property (nonatomic, copy, readonly) NSString *compactText;

+ (instancetype)countryWithName:(NSString *)name
                    englishName:(NSString *)englishName
                    countryCode:(NSString *)countryCode
                        isoCode:(NSString *)isoCode;

@end

/** 大区分组：一个大区下包含若干国家 */
@interface CountryGroup : NSObject

/** 大区名称，如 "欧洲" */
@property (nonatomic, copy, readonly) NSString *title;
@property (nonatomic, copy, readonly) NSArray<CountryModel *> *countries;

+ (instancetype)groupWithTitle:(NSString *)title countries:(NSArray<CountryModel *> *)countries;

@end

@interface CountryModel (Repository)

/** 按大区分组的国家列表（中国 / 亚太 / 美洲 / 欧洲 / 中东与非洲） */
+ (NSArray<CountryGroup *> *)allGroups;

/** 全部国家的平铺列表 */
+ (NSArray<CountryModel *> *)allCountries;

/** 默认国家（中国 +86） */
+ (CountryModel *)defaultCountry;

/** 按国家码查找，找不到返回 nil */
+ (nullable CountryModel *)countryWithCountryCode:(NSString *)countryCode;

/** 上次选择的国家，无记录时返回 defaultCountry */
+ (CountryModel *)lastSelectedCountry;

/** 记住本次选择的国家 */
+ (void)saveLastSelectedCountry:(CountryModel *)country;

@end

NS_ASSUME_NONNULL_END
