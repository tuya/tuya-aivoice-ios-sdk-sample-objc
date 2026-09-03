# ThingPerfusionKit

AI 语音**灌流（Perfusion）调试组件**。用本地音频文件替换麦克风采集数据，
跑通 ASR / 翻译 / TTS 全链路，计算 **WER（词错误率）** 并导出 **HTML 测试报告**。

不依赖 ThingDebuggerAIBudsTool / ThingDebuggerBaseKit / ThingBaseDebugger / ThingOEMConfig。

---

## 安装

Podfile 中以本地路径依赖：

```ruby
pod 'ThingPerfusionKit', :path => '../Modules/ThingPerfusionKit'
```

只要灌流与评估能力、不要页面时，可只集成 Core：

```ruby
pod 'ThingPerfusionKit/Core', :path => '../Modules/ThingPerfusionKit'
```

| 子模块 | 内容 | 依赖 |
|---|---|---|
| `Core` | 灌流配置提供者、WAV 格式校验、WER 计算、报告生成（无 UI） | `ThingAudioRecordInterface`、`ThingModuleManager`、`ThingAnnotationFoundation` |
| `UI` | 开箱可用的灌流调试页（自带页面基类） | `Core` + UIKit / AVFAudio |

以上依赖均为 AI 语音业务包的既有传递依赖，**无需新增任何 pod**。

---

## 使用

### 直接用现成页面

```objc
#import <ThingPerfusionKit/ThingPerfusionViewController.h>

ThingPerfusionViewController *vc = [[ThingPerfusionViewController alloc] init];
vc.hidesBottomBarWhenPushed = YES;
[self.navigationController pushViewController:vc animated:YES];
```

页面使用宿主的系统导航栏，不干预导航栏风格。功能包括：选择灌流音频与参考答案、
ASR / 翻译 / TTS 开关、语言设置、实时过程渲染、WER 评估、报告导出。

### 只用能力，自己写界面

```objc
#import <ThingPerfusionKit/ThingPerfusionService.h>
#import <ThingPerfusionKit/ThingPerfusionAudioFileInfo.h>

// 1. 先校验格式，避免白跑一次
ThingPerfusionAudioFileInfo *info = [ThingPerfusionService audioFileInfoWithFileName:@"sample.wav"];
if (!info.isDecodable) {
    NSLog(@"%@", info.warning);   // 非 PCM，灌流不会有任何输出
    return;
}

// 2. 配置灌流（必须在 startRecording 之前写入，底层启动音频输入时回读）
ThingPerfusionService *service = [ThingPerfusionService sharedInstance];
service.perfusionEnabled = YES;
service.perfusionFileName = @"sample.wav";      // 已在灌流目录内
service.autoCloseFileWhenPerfusionEnd = YES;
service.didEndHandler = ^(NSString *fileName) {
    // 灌流文件读完，自行停止录音并收集结果
};

// 3. 照常开始录音（deviceId 用手机麦克风、audioSource = ThingSystemMic16KMono）

// 4. 结束后务必关闭，避免影响正常录音
[service reset];
```

文件管理接口：

```objc
+ [ThingPerfusionService importAudioFileFromURL:error:]      // 导入外部音频
+ [ThingPerfusionService availableAudioFileNames]            // 列出可用音频
+ [ThingPerfusionService importReferenceFileFromURL:error:]  // 导入参考答案
+ [ThingPerfusionService referenceTextWithFileName:]         // 读取参考答案
```

### 单独做 WER 评估

不依赖灌流，任意 ASR 结果都能算：

```objc
#import <ThingPerfusionKit/ThingPerfusionWERCalculator.h>

ThingPerfusionWERResult *r = [ThingPerfusionWERCalculator evaluateReference:refText
                                                                hypothesis:hypText];
NSLog(@"准确率 %.2f%% WER %.2f%% N=%lu S=%lu D=%lu I=%lu",
      r.accuracy * 100, r.wer * 100,
      (unsigned long)r.referenceCount, (unsigned long)r.substitutions,
      (unsigned long)r.deletions, (unsigned long)r.insertions);
```

---

## ⚠️ 音频格式要求（最容易踩的坑）

底层把文件内容当作 **16kHz / 16bit / 单声道的整型 PCM** 直接替换采集流，
**只支持整型 PCM 的 WAV**。格式不符时的典型表现是「灌流在跑，但一条 ASR 都没有」，
底层日志形如：

```
ThingAbstractVAD::replaceCaptureData WAV file info - Format: 3, Channels: 1, Sample Rate: 8000, Bits: 64
ThingAbstractVAD::replaceCaptureData unsupported audio format: 3 (only PCM supported)
```

`Format` 为 WAV 的 audioFormat 字段：**1 = 整型 PCM（唯一支持）**，3 = IEEE float。

转换命令（`afconvert` 为 macOS 自带）：

```bash
afconvert -f WAVE -d LEI16@16000 -c 1 输入.wav 输出.wav
```

```bash
ffmpeg -i 输入.wav -ar 16000 -ac 1 -c:a pcm_s16le 输出.wav
```

组件内建校验（`ThingPerfusionAudioFileInfo`），页面按三级处理：

| 情况 | 表现 |
|---|---|
| PCM / 16kHz / 单声道 / 16bit | 绿色 `✓`，正常开始 |
| PCM 但采样率、声道或位深不符 | 橙色警告，点开始时弹确认，可选「仍然开始」 |
| 非 PCM（IEEE float 等）或非 WAV | 红色，点开始时**直接拦截**并给出转换命令 |

---

## 灌流原理

底层 `ThingMicrophoneAudioInput` 启动音频输入时，通过
`[ThingModule serviceOfOptionalProtocol:@protocol(ThingAIBudsDebuggerProtocol)]`
向 App 侧回读配置，读到以下三项就把麦克风采集数据换成本地文件：

| 配置键 | 说明 |
|---|---|
| `ThingAIBudsSimulateConfigKey_PerfusionData` | 灌流开关 |
| `ThingAIBudsSimulateConfigKey_PerfusionFileName` | 灌流文件名（不含路径） |
| `ThingAIBudsSimulateConfigKey_PerfusionAutoCloseFile` | 文件读完是否自动收尾 |

组件通过 `ThingRegisterAPIAnnotation` 在编译期把 `ThingPerfusionConfigProvider`
写入 Mach-O 的 `_ThingMOV3_` 段，App 启动后由 `ThingMachRegister` 收集，底层即可查到，
**无需在启动代码里做任何注册**。

工作目录（组件已封装，无需手工处理）：

```
Documents/voiceRecord/automaticTest/audioFiles/    灌流音频
Documents/voiceRecord/automaticTest/references/    参考答案（txt）
Documents/voiceRecord/automaticTest/reports/       导出的报告
```

---

## WER 计算口径

`WER = (S + D + I) / N`，`准确率 = 1 − WER`（下限截到 0）。
S = 替换，D = 删除（参考有但没识别出来），I = 插入（识别多出来的），N = 参考词数。

**1. 文本归一化**（参考答案与识别结果套用同一套规则）

- 统一转小写、去首尾空白
- 标点**替换为空格**而非删除（直接删会把 `starkes.Kulturellen` 粘成一个词，凭空制造错误）
- 中文**逐字切分**，英文等按词切分
- 剔除语气词 `啊额呃嗯唉哎哦喔呵哈儿`
- 千分位还原：`40 000` → `40000`
- 数词归一化：`two` / `zwei` → `2`

**2. 编辑距离对齐**

Levenshtein 动态规划 + 回溯得到每个位置的操作；代价相同时优先判替换、其次删除。

> 本实现与团队现有的 `ASR_WER/WER.py` 口径一致，已用真实数据逐项对拍验证：
> `tuya.txt` N=875 S=73 D=165 I=14 WER=0.288000、
> `lvlian.txt` N=875 S=58 D=118 I=7 WER=0.209143，两端结果完全相同。

**逐句对比**：ASR 常把一句切成多段输出，报告用动态规划把识别分段**单调切分**后
分配给参考行，一行可合并的段数上限按「识别段数 ÷ 参考行数」自适应；
参考答案只有一行时不做对齐，全部识别内容归属该行。

> **固有限制**：一个识别分段不会被拆开分配给多个参考行。当 ASR 把多行参考合并成一段输出
> （识别段数 < 参考行数）时，必然有参考行分不到内容而被判为漏识，属于对齐口径造成的虚高。
> 报告在这种情况下会显示醒目告警。**全文 WER 不受此影响，任何情况下都以全文口径为准。**
> 想要准确的逐句结果，请让参考答案的分行与音频中的自然停顿一致。

---

## 测试报告

点「导出测试报告」生成 HTML 并落到 reports 目录，随后弹出系统分享面板
（AirDrop / 存到文件 / 邮件均可）。报告内容：

- 概览 KPI：准确率、WER、参考词数、错误合计、命中词数、灌流耗时
- 错误构成条（S / D / I 占比）
- 测试条件：音频、参考答案、时间、耗时、能力开关、语言、recordId、配置回读次数
- **逐句对比**：每行参考答案 vs 识别结果（差异高亮）+ 该行 N/S/D/I/WER，漏识行标红
- **全文逐词对比**：替换标红（悬停显示应为何词）、插入标黄、删除标绿
- 归一化后的参考与识别文本（实际参与计算的内容）
- 识别原文、翻译原文
- **计算方式**章节：公式、归一化 6 条规则、对齐方式与其限制

报告支持深色模式，无外部依赖，单文件可直接分享。

---

## 目录结构

```
ThingPerfusionKit/
├── ThingPerfusionKit.podspec
├── README.md
└── ThingPerfusionKit/Classes/
    ├── Core/
    │   ├── ThingPerfusionService.h/.m          灌流配置提供者 + 文件管理
    │   ├── ThingPerfusionAudioFileInfo.h/.m    WAV 格式校验
    │   ├── ThingPerfusionWERCalculator.h/.m    WER 计算
    │   ├── ThingPerfusionReportBuilder.h/.m    HTML 报告
    │   └── ThingPerfusionRecordBridge.h/.m     录音链路桥接
    └── UI/
        ├── ThingPerfusionViewController.h/.m       灌流调试页
        └── ThingPerfusionBaseViewController.h/.m   页面基类
```

---

## 注意事项

1. **音频格式**：见上文，最常见的失败原因。
2. **麦克风权限必需**：灌流虽替换采集数据，底层仍会拉起音频采集链路。
3. **需要登录态**：开始录音依赖账号 token。
4. **仅手机麦克风链路生效**：`audioSource` 必须是 `ThingSystemMic16KMono`（走 `ThingMicrophoneAudioInput`）；蓝牙/耳机输入链路不支持灌流。
5. **不要与 ThingDebuggerAIBudsTool 同时集成**：该工具会用同名协议注册自己的实现（优先级相同），会与本组件的 provider 互相顶掉。页面上的提供者类名显示为 `ThingPerfusionConfigProvider` 才是正常状态。
6. **自检**：页面显示配置提供者实现类名，并在开始灌流 3 秒后打印「底层回读灌流配置 N 次」。N 为 0 说明注册未生效，录的是真实麦克风；N > 0 但没有 ASR 输出，检查音频格式。
7. **参考答案**：UTF-8 txt，建议每行一句、与音频停顿一致。未选择参考答案时照常灌流，只是不计算 WER。
8. **收尾**：灌流结束后 `perfusionEnabled` 自动置为 NO，页面销毁时调用 `reset`，确保不影响正常录音。
