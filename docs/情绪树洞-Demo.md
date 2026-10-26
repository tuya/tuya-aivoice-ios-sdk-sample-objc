# 情绪树洞 iOS Demo

入口：登录后底部「树洞」Tab。

## 已实现

- 三个本地角色预览，各自保留当前页面内的消息。
- 按住录音、音量波形、计时、上滑取消；少于 0.7 秒取消，最长 60 秒后自动进入校对。
- 松开后试听、系统中文语音转写、文字校对、重录与确认发送。
- 转写权限拒绝、服务不可用或超时时，仍可补充文字或保留语音。
- 文字输入切换、快捷话题、键盘避让、录音回放、当前角色清空。
- 离开页面、切后台、音频中断或耳机断开时停止录音与回放。

## 当前边界

智能体尚未接入，发送操作仅把消息保留在页面内，状态为「待发送」，不会产生模拟 AI 回复。退出登录、释放页面或结束 App 后不保留消息；临时录音随页面释放删除。

语音输入使用 `AVAudioRecorder`，允许系统蓝牙 HFP 输入，页面显示实际输入设备。转写暂用 Apple `SFSpeechRecognizer`（中文），可能依赖网络及 Apple 服务器，与玩具智能体无关。真实耳机路由、收音质量和系统识别效果需在真机确认。

## 智能体配置预留

`EmotionChatViewController.agentConfiguration` 提供以下字段，当前默认留空，不发起云端会话：

| 字段 | 用途 |
| --- | --- |
| `deviceId` | 耳机激活后获得的 devId |
| `solutionCode` | 后续确认的 AI 方案编码 |
| `roleIds` | 本地角色键 autumn / ocean / sunshine 对应的云端角色 ID |

玩具项目 `aipt_fsrrvthmqwao` 未作为耳机配置写入默认值。

## 验证

- 主工程：`xcodebuild -workspace tuya-aivoice-ios-sdk-sample-objc.xcworkspace -scheme tuya-aivoice-ios-sdk-sample-objc -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build`
- 交互测试：`tuya-aivoice-ios-sdk-sample-objcTests/EmotionChatViewControllerTests.m`；共享 scheme 已包含测试 target，可在 Xcode 使用 Test。当前 Pods 的模拟器架构设置沿用工程配置。
- 在独立模拟器宿主中运行相同页面及服务源码，验证角色隔离、空输入、取消与短录音、转写竞态、失败保留语音、文字校对、自动结束后松手，以及校对区的键盘布局。测试中的录音和转写使用替身，不采集真实麦克风。
