//
//  CountryModel.m
//  AIVoiceDemo
//

#import "CountryModel.h"

static NSString * const kLastSelectedCountryCodeKey = @"AIVoiceDemo.LastSelectedCountryCode";

@interface CountryModel ()

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *englishName;
@property (nonatomic, copy) NSString *countryCode;
@property (nonatomic, copy) NSString *isoCode;

@end

@implementation CountryModel

+ (instancetype)countryWithName:(NSString *)name
                    englishName:(NSString *)englishName
                    countryCode:(NSString *)countryCode
                        isoCode:(NSString *)isoCode {
    CountryModel *country = [[CountryModel alloc] init];
    country.name = name;
    country.englishName = englishName;
    country.countryCode = countryCode;
    country.isoCode = isoCode;
    return country;
}

- (NSString *)flag {
    // ISO 国家码的两个字母映射到 Regional Indicator Symbol，即国旗 emoji
    NSString *upper = self.isoCode.uppercaseString;
    if (upper.length != 2) {
        return @"";
    }
    NSMutableString *flag = [NSMutableString string];
    for (NSUInteger i = 0; i < upper.length; i++) {
        unichar c = [upper characterAtIndex:i];
        if (c < 'A' || c > 'Z') {
            return @"";
        }
        UTF32Char base = 0x1F1E6 + (c - 'A');
        [flag appendString:[[NSString alloc] initWithBytes:&base
                                                    length:sizeof(base)
                                                  encoding:NSUTF32LittleEndianStringEncoding]];
    }
    return flag;
}

- (NSString *)displayText {
    return [NSString stringWithFormat:@"%@ %@ +%@", self.flag, self.name, self.countryCode];
}

- (NSString *)compactText {
    return [NSString stringWithFormat:@"%@ +%@", self.flag, self.countryCode];
}

@end

#pragma mark - CountryGroup

@interface CountryGroup ()

@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSArray<CountryModel *> *countries;

@end

@implementation CountryGroup

+ (instancetype)groupWithTitle:(NSString *)title countries:(NSArray<CountryModel *> *)countries {
    CountryGroup *group = [[CountryGroup alloc] init];
    group.title = title;
    group.countries = countries;
    return group;
}

@end

#pragma mark - Repository

@implementation CountryModel (Repository)

+ (NSArray<CountryGroup *> *)allGroups {
    static NSArray<CountryGroup *> *groups = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CountryModel *(^c)(NSString *, NSString *, NSString *, NSString *) =
        ^CountryModel *(NSString *name, NSString *en, NSString *code, NSString *iso) {
            return [CountryModel countryWithName:name englishName:en countryCode:code isoCode:iso];
        };

        groups = @[
            [CountryGroup groupWithTitle:@"中国" countries:@[
                c(@"中国", @"China", @"86", @"CN"),
                c(@"中国香港", @"Hong Kong", @"852", @"HK"),
                c(@"中国澳门", @"Macao", @"853", @"MO"),
                c(@"中国台湾", @"Taiwan", @"886", @"TW"),
            ]],
            [CountryGroup groupWithTitle:@"亚太" countries:@[
                c(@"新加坡", @"Singapore", @"65", @"SG"),
                c(@"马来西亚", @"Malaysia", @"60", @"MY"),
                c(@"泰国", @"Thailand", @"66", @"TH"),
                c(@"印度尼西亚", @"Indonesia", @"62", @"ID"),
                c(@"越南", @"Vietnam", @"84", @"VN"),
                c(@"菲律宾", @"Philippines", @"63", @"PH"),
                c(@"日本", @"Japan", @"81", @"JP"),
                c(@"韩国", @"South Korea", @"82", @"KR"),
                c(@"印度", @"India", @"91", @"IN"),
                c(@"澳大利亚", @"Australia", @"61", @"AU"),
                c(@"新西兰", @"New Zealand", @"64", @"NZ"),
            ]],
            [CountryGroup groupWithTitle:@"美洲" countries:@[
                c(@"美国", @"United States", @"1", @"US"),
                c(@"加拿大", @"Canada", @"1", @"CA"),
                c(@"墨西哥", @"Mexico", @"52", @"MX"),
                c(@"巴西", @"Brazil", @"55", @"BR"),
                c(@"阿根廷", @"Argentina", @"54", @"AR"),
                c(@"智利", @"Chile", @"56", @"CL"),
            ]],
            [CountryGroup groupWithTitle:@"欧洲" countries:@[
                c(@"英国", @"United Kingdom", @"44", @"GB"),
                c(@"德国", @"Germany", @"49", @"DE"),
                c(@"法国", @"France", @"33", @"FR"),
                c(@"意大利", @"Italy", @"39", @"IT"),
                c(@"西班牙", @"Spain", @"34", @"ES"),
                c(@"葡萄牙", @"Portugal", @"351", @"PT"),
                c(@"荷兰", @"Netherlands", @"31", @"NL"),
                c(@"比利时", @"Belgium", @"32", @"BE"),
                c(@"瑞士", @"Switzerland", @"41", @"CH"),
                c(@"奥地利", @"Austria", @"43", @"AT"),
                c(@"爱尔兰", @"Ireland", @"353", @"IE"),
                c(@"瑞典", @"Sweden", @"46", @"SE"),
                c(@"挪威", @"Norway", @"47", @"NO"),
                c(@"丹麦", @"Denmark", @"45", @"DK"),
                c(@"芬兰", @"Finland", @"358", @"FI"),
                c(@"波兰", @"Poland", @"48", @"PL"),
                c(@"捷克", @"Czechia", @"420", @"CZ"),
                c(@"希腊", @"Greece", @"30", @"GR"),
                c(@"匈牙利", @"Hungary", @"36", @"HU"),
                c(@"罗马尼亚", @"Romania", @"40", @"RO"),
                c(@"俄罗斯", @"Russia", @"7", @"RU"),
                c(@"土耳其", @"Türkiye", @"90", @"TR"),
            ]],
            [CountryGroup groupWithTitle:@"中东与非洲" countries:@[
                c(@"阿联酋", @"United Arab Emirates", @"971", @"AE"),
                c(@"沙特阿拉伯", @"Saudi Arabia", @"966", @"SA"),
                c(@"以色列", @"Israel", @"972", @"IL"),
                c(@"埃及", @"Egypt", @"20", @"EG"),
                c(@"南非", @"South Africa", @"27", @"ZA"),
                c(@"尼日利亚", @"Nigeria", @"234", @"NG"),
            ]],
        ];
    });
    return groups;
}

+ (NSArray<CountryModel *> *)allCountries {
    static NSArray<CountryModel *> *countries = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableArray *all = [NSMutableArray array];
        for (CountryGroup *group in [self allGroups]) {
            [all addObjectsFromArray:group.countries];
        }
        countries = [all copy];
    });
    return countries;
}

+ (CountryModel *)defaultCountry {
    return [self countryWithCountryCode:@"86"] ?: [self allCountries].firstObject;
}

+ (CountryModel *)countryWithCountryCode:(NSString *)countryCode {
    if (countryCode.length == 0) {
        return nil;
    }
    for (CountryModel *country in [self allCountries]) {
        if ([country.countryCode isEqualToString:countryCode]) {
            return country;
        }
    }
    return nil;
}

+ (CountryModel *)lastSelectedCountry {
    NSString *code = [[NSUserDefaults standardUserDefaults] stringForKey:kLastSelectedCountryCodeKey];
    return [self countryWithCountryCode:code] ?: [self defaultCountry];
}

+ (void)saveLastSelectedCountry:(CountryModel *)country {
    if (country.countryCode.length == 0) {
        return;
    }
    [[NSUserDefaults standardUserDefaults] setObject:country.countryCode forKey:kLastSelectedCountryCodeKey];
}

@end
