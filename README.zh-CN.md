# Open Filmly

[English](README.md) · [简体中文](README.zh-CN.md)

Open Filmly 是一个本地优先、自托管的开源 **AI-native Personal Media OS（AI 原生个人媒体操作系统）**。它连接你拥有的文件、文件中的内容、你的观看历史，以及你希望对媒体库执行的操作。

> **Open Filmly 1.0 愿景：面向私人影视库的开源 AI 原生个人媒体操作系统。**

![Open Filmly 首页](docs/screenshots/home.png)

![Open Filmly 电视剧详情](docs/screenshots/tv-detail.png)

## 产品愿景

传统媒体库的链路通常是：

```text
文件 → 元数据 → 海报 → 播放
```

Open Filmly 希望把它推进为：

```text
文件 → AI 理解 → 语义索引 → 个人记忆 → AI Agent → 播放
```

这意味着媒体库不再只是文件列表，而会逐步理解影片中的人物、场景、地点、事件、对白、情绪、主题和时间轴；同时记住你与内容的关系，并帮助你对媒体库采取行动。用户可以用自然语言寻找内容、询问当前剧情，并直接跳转到匹配的时间点。

Open Filmly 的核心原则：

- **本地优先**：媒体文件、索引和观看记忆默认留在用户自己的设备与存储中。
- **渐进式 AI**：先把字幕、搜索和观看辅助做好，再扩展到推荐与自动化管理。
- **时间轴优先**：每个理解结果都尽量关联具体片段、截图和播放位置。
- **无剧透交互**：AI Companion 只基于用户已经看到的内容回答问题。
- **用户可控**：AI 提供建议和操作预览，不擅自移动、删除或改写用户的媒体文件。

## AI 路线图：未来 3–6 个月

路线图围绕三个最能体现产品差异的能力展开：**AI 字幕、Ask Filmly、无剧透 AI Companion**。

| 优先级 | 方向 | 用户体验 | 计划产出 |
| --- | --- | --- | --- |
| P0 | AI 字幕 | 语音识别、中文字幕、翻译、校准、纠错和双语显示 | 本地/可选云端 ASR、字幕时间轴编辑、专有名词与上下文修正 |
| P0 | Ask Filmly | 用自然语言搜索影片、对白、人物和场景，并跳转到时间点 | Cmd/Ctrl + K 入口、语义检索、时间段结果、截图与一键播放 |
| P1 | AI Companion | 看片时问“他是谁”“前面发生了什么”“这里为什么这样说” | 当前进度感知、上下文问答、无剧透边界、回看相关片段 |
| P1 | AI 合集与推荐 | “赛博朋克但不沉重”“今晚两小时看什么” | 基于媒体内容、观看历史和当前意图生成可编辑合集 |
| P2 | Personal Film Memory | 回顾自己看过什么、喜欢什么、在哪些片段停留过 | 观看记忆、主题回顾、跨设备同步与隐私控制 |
| P2 | Media Agent | 批量生成字幕、整理重复文件、检查画质和长期未观看内容 | 可预览任务计划、批处理队列、可撤销的文件管理操作 |

### 第一阶段：把看片体验做好

AI 字幕是最直接的入口。目标不是简单接入语音识别，而是让字幕真正适合观看：

- 自动识别语音、生成字幕并校准时间轴
- 翻译成中文或其他目标语言，支持双语显示
- 根据影片上下文统一人名、地名和专有名词
- 识别片头、片尾、前情提要、广告和彩蛋，提供智能跳过
- 在播放器中解释文化梗和字幕译法，同时避免剧透

### 第二阶段：Ask Filmly

用户不必记得片名或文件名，可以直接描述想找的内容：

```text
找那个男主角在雨里等女主角的电影
找所有关于 AI 失控的影片
找我收藏里出现纽约夜景的片段
找 Nolan 电影里关于时间的对白
```

结果应当包含影片、场景、时间轴、截图和匹配理由，并支持点击后直接播放。Ask Filmly 将成为 Open Filmly 的核心入口，而不是传统媒体库搜索框的附属功能。

### 第三阶段：AI Companion

AI Companion 关注观看过程中的即时疑问：

```text
他是谁？
这个东西之前出现过吗？
为什么他生气？
前面发生了什么？
```

回答必须结合当前播放位置，只使用用户已经看过的内容。例如用户暂停在某个角色第一次出现的片段，AI 应该解释其已知身份和前文关联，而不能泄露后续剧情。

## 当前能力

- 电影、电视剧、动漫、综艺、演唱会、纪录片等媒体分类
- TMDB 元数据、海报、背景图、演员与分集信息
- 最近播放、续播进度、收藏、全局搜索与自动扫描
- 电视剧按季 Tab 展示，使用 16:9 分集剧照卡片
- 本地目录、SMB、WebDAV、Emby 和 Jellyfin 媒体来源
- 资源库管理：添加、编辑、导入和删除网络资源，并区分本地下载与远程来源
- 跨设备数据库导入/导出，覆盖安装时保留现有数据
- 数字文件名剧集识别、旁车文件清理、重复剧集修复和同剧重复卡片合并
- **Media Intelligence Layer**：本地字幕旁车入库、场景分段、离线语义索引
- **Ask Filmly / Cmd+K**：自然语言搜索标题、对白与场景时间点
- **AI Companion**：无剧透问答、依据时间轴回看、智能跳过片头/片尾
- **Filmly Conversations**：持久会话库、可预览 Agent 计划、Spotlight 命令面板
- macOS VLCKit 3.7.3、Windows libVLC 与 iOS / Android MobileVLCKit / libVLC 原生播放
- 硬件解码、音轨、字幕轨道、外挂字幕、播放缓冲、进度拖动、倍速、音量、上下集与自动连播
- macOS / Windows 窗口拖动、双击最大化、全屏和桌面键盘快捷键
- 窄屏底部导航、移动端双击手势与沉浸式播放交互

## 平台状态

| 平台 | 状态 | 说明 |
| --- | --- | --- |
| macOS | 可运行 | 使用 VLCKit 3.7.3 原生播放器与沙盒数据库 |
| Windows | 可运行 | 使用 Windows Runner 与 libVLC 原生播放器 |
| iOS | 可运行 | iOS Runner、系统文件导入、MobileVLCKit 播放与数据库迁移 |
| Android | 可运行 | Android Runner、系统文件导入与 libVLC 播放 |

## 技术方向

### 媒体理解层

导入视频后，逐步建立以下结构化信息：

```text
影片
├── 人物与人物关系
├── 场景、地点与事件
├── 对白与字幕时间轴
├── 情绪、主题与关键概念
└── 截图、向量索引与可播放时间点
```

实现上会优先采用可替换、可本地运行的组件：语音转录、字幕翻译、视觉理解、向量索引和可选的远程大模型。没有 AI 服务时，基础媒体库和播放器仍然完整可用。

### Agent 安全边界

任何会影响文件或媒体库的自动化操作都遵循：

1. 先分析并展示计划
2. 允许用户预览和修改范围
3. 执行前明确确认
4. 保留备份或提供撤销路径

## 开发

```bash
flutter pub get
flutter run -d macos
# Windows 主机：flutter run -d windows
# iOS：flutter run -d <ios-device-id>
# Android：flutter run -d <android-device-id>
```

质量检查：

```bash
flutter analyze lib
flutter test $(ls test/*.dart | grep -v integration_smb_real | grep -v ui_automation)
flutter build macos --release
flutter build apk --debug
flutter build ios --simulator
```

环境依赖测试：

- `integration_smb_real_test.dart` 需要可访问的局域网 SMB 服务。
- `ui_automation_test.dart` 需要正在运行的应用和 Flutter VM Service。

## 参与路线图

当前最适合贡献的方向：

- AI 字幕流水线：ASR、翻译、时间轴校准和字幕编辑
- 多模态索引：对白、画面、截图与播放时间点的统一数据模型
- Ask Filmly：自然语言检索、结果解释和时间轴跳转
- AI Companion：当前进度感知和无剧透上下文窗口
- 本地模型适配：让用户可以在不上传视频的情况下运行核心 AI 能力
- 跨平台体验：保持 macOS、Windows、iOS 和 Android 的能力一致，同时尊重端特性

## 技术栈

- UI：Flutter、Material 3
- 状态管理：Riverpod
- 路由：`go_router`
- 播放：VLCKit 3.7.3（macOS）/ libVLC（Windows、Android）/ MobileVLCKit（iOS）
- 数据库：Drift / SQLite
- 网络媒体：SMB Range 代理、WebDAV、Emby / Jellyfin
- 桌面窗口：`window_manager` + macOS / Windows 原生窗口桥接

---

Open Filmly 的终点不是“再做一个 Plex、Jellyfin 或播放器”，而是成为覆盖你所拥有媒体的 AI 原生个人媒体操作系统：让私人影视库真正变得可理解、可询问、可记忆、可行动。
