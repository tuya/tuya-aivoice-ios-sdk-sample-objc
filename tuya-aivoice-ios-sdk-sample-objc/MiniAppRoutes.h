//
//  MiniAppRoutes.h
//  tuya-aivoice-ios-sdk-sample-objc
//
//  小程序路由常量：AppID 与快捷入口 URL
//

#ifndef MiniAppRoutes_h
#define MiniAppRoutes_h

/*
 MARK: AIVoice 小程序路由
 小程序的快捷入口路由
*/


#pragma mark - 小程序 App ID

/// AI笔记 小程序 App ID
#define kMiniAppIdAINote       @"tyylldwlb8411tg8u2"
/// AI翻译 小程序 App ID
#define kMiniAppIdAITranslate  @"ty0u9m1s5ea1k71m2h"

#pragma mark - AI笔记 快捷入口 URL

/// 录音
#define kMiniAppURLAINoteLiveRecording             @"thingSmart://miniApp?url=godzilla%3A%2F%2Ftyylldwlb8411tg8u2%2Fpages%2Fhome%2Findex%3FmodeKey%3DliveRecording"
/// 同声传译
#define kMiniAppURLAINoteSimultaneousInterpretation @"thingSmart://miniApp?url=godzilla%3A%2F%2Ftyylldwlb8411tg8u2%2Fpages%2Fhome%2Findex%3FmodeKey%3DsimultaneousInterpretation"
/// 实时转写
#define kMiniAppURLAINoteRealTimeRecording         @"thingSmart://miniApp?url=godzilla%3A%2F%2Ftyylldwlb8411tg8u2%2Fpages%2Fhome%2Findex%3FmodeKey%3DrealTimeRecording"

#pragma mark - AI翻译 快捷入口 URL

/// 同声传译
#define kMiniAppURLAITranslateSimultaneous         @"thingSmart://miniApp?url=godzilla%3A%2F%2Fty0u9m1s5ea1k71m2h%2Fpages%2Fsimultaneous%2Findex"
/// 对话翻译
#define kMiniAppURLAITranslateFaceToFace           @"thingSmart://miniApp?url=godzilla%3A%2F%2Fty0u9m1s5ea1k71m2h%2Fpages%2FFaceToFace%2Findex"

#endif /* MiniAppRoutes_h */
