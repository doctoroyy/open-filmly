# Open Filmly → Codex 交接文档

> 生成时间：2026-07-11
> 交接方：Grok（方案 + 执行）
> 审阅协作：Claude Code `claude-fable-5`（方案审阅，不写代码）
> 目标产品：对标 **网易爆米花** 的全平台媒体库（当前主攻 macOS Flutter）

请先读本文，再动代码。仓库里还有大量 **未提交** 工作区改动，不要 `git reset --hard`。

---

## 1. 项目定位（别走错仓库）

| 路径 | 状态 | 说明 |
|------|------|------|
| **`/Users/xiaoyu/code/open-filmly-flutter`** | **主线** | Flutter 重写，分支 `feat/flutter-refactor` |
| `/Users/xiaoyu/code/open-filmly` | 遗留 | 原 Electron 版；有 VLC 半成品 WIP，**用户已决定推翻迁移到 Flutter** |
| `~/Documents/open-filmly-flutter-progress.md` | 进度备忘 | 历史里程碑 + 本轮更新摘要 |
| `docs/plan-category-nav-and-wip.md` | 分类导航方案 | Claude fable-5 已 `APPROVE_WITH_CHANGES` 并已落地 |

**用户偏好（memory）**：卡死时倾向「完全推翻」而不是小修；范围要对齐网易爆米花（全平台 + 内嵌解码播放）。

---

## 2. 当前分支与提交状态

```text
仓库: /Users/xiaoyu/code/open-filmly-flutter
分支: feat/flutter-refactor
HEAD: fca4808  feat: implement manual metadata re-match and auto-compensation of episodes...
```

### 2.1 已提交（HEAD 及以前）

- Flutter + media_kit 本地 / SMB / WebDAV / Emby·Jellyfin 播放
- Drift 库、TMDB + Gemini 刮削、剧集层级、收藏、全局搜索、自动扫描
- 爆米花浅色 UI、透明标题栏、详情页 Hero、手动重新匹配元数据
- 详情路由 404 修复、脏标题清理、macOS `._` 垃圾文件去重

### 2.2 工作区未提交（本轮 Grok 改动，**必须保留**）

**新增：**

| 文件 | 作用 |
|------|------|
| `lib/data/models/library_shelf.dart` | 互斥媒体分类（电影/剧/动漫/综艺/演唱会/纪录/其他） |
| `lib/services/playback/external_subtitle_finder.dart` | 同目录外挂字幕扫描 |
| `test/library_shelf_test.dart` | 分类单测（zh-CN genre） |
| `test/external_subtitle_finder_test.dart` | 外挂字幕单测 |
| `docs/plan-category-nav-and-wip.md` | 分类导航方案 + 审阅结论 |
| `docs/HANDOFF_CODEX.md` | 本文 |

**重点修改：**

| 文件 | 改了什么 |
|------|----------|
| `lib/features/player/player_page.dart` | **播放体验大改**（见 §4） |
| `lib/features/shell/app_shell.dart` | 爆米花侧栏：分类导航、搜索占位、底栏收藏/来源/设置 |
| `lib/core/router/app_router.dart` | 分类路由绑 `LibraryShelf` |
| `lib/features/library/library_page.dart` | shelf / type 双模式浏览 |
| `lib/data/repositories/media_repository.dart` | `browse(shelf:)` 内存分类过滤 |
| `lib/features/library/media_detail_page.dart` | 剧集传 `showId`、单集续播 |
| `lib/features/config/smb_browser_page.dart` | 预填/size>0；去掉 debug print |
| 若干 test | 适配侧栏文案、多搜索图标、deep browse 补 DB override |

**建议提交策略（给 Codex）：**

1. 先 `git status` / `git diff` 确认无意外丢失
2. 可拆成两个 commit：
   - `feat(flutter): exclusive library shelves + popcorn sidebar`
   - `feat(flutter): player UX — buffering, external subs, episode chain`
3. **不要** force push；未要求则不要改 `main`

---

## 3. 架构速览

```text
lib/
├── main.dart / app.dart
├── core/router/app_router.dart      # go_router + ShellRoute
├── core/platform/window_channel.dart # macOS 全屏/最大化 MethodChannel
├── data/
│   ├── database/                    # Drift (media / episodes / config)
│   ├── models/                      # Media, Episode, LibraryShelf, PlaybackProgress
│   └── repositories/
├── features/
│   ├── shell/app_shell.dart         # 侧栏 + 启动自动扫描
│   ├── home/                        # Dashboard + 最近播放
│   ├── library/                     # 库页、详情、收藏
│   ├── player/player_page.dart      # 全屏播放器
│   ├── sources/                     # 来源管理
│   └── config/                      # 设置 + SMB/WebDAV/Emby 浏览器
├── services/
│   ├── library/                     # 扫描、导入、入口工厂、自动扫描
│   ├── metadata/                    # TMDB + Gemini
│   ├── playback/                    # PlaybackService / SourceResolver / 外挂字幕
│   ├── smb/ webdav/ emby/
└── providers/                       # Riverpod
```

**关键不变量：**

1. **`MediaType`** = 文件结构语义（`movie | tv | unknown`），扫描/分集用。
2. **`LibraryShelf`** = 侧栏互斥分区，**纯函数**从 path + zh-CN genres 计算，**无 DB 迁移**。
3. **媒体 id** 经常是真实路径（含 `/`、空格、中文）→ 详情路由必须是 `/media?id=<encode>`，禁止 path segment。
4. 剧集播放必须用 `MediaLibraryEntryFactory.episodePlayableMedia(episode, show)` 再走 `PlaybackSourceResolver`，否则 SMB/WebDAV 打不开。
5. 删除媒体前先删 `episodes`（外键）。

---

## 4. 播放器现状（刚做完，用户仍可能觉得「差一点」）

文件：`lib/features/player/player_page.dart`
封装：`lib/services/playback/playback_service.dart`（media_kit）

### 4.1 已具备

- 播放/暂停、进度拖动、缓冲条（`stream.buffer`）
- 缓冲中转圈、打开失败错误态（重试/返回）
- ±10s 跳转 + 中央 toast
- 音量滑条 + 点击静音；倍速 bottom sheet
- 内嵌音轨/字幕切换
- **外挂字幕**：本地同目录扫描，优先中文 tag
- **剧集**：`PlayerArgs.showId` → 拉 playlist；顶栏上/下集；播完 5s 自动下一集（可取消）
- 单集续播（详情页读 episode progress）
- 键盘：`Space` `←→` `↑↓` `F` `M` `N` `P` `[` `]` `Esc`
- 双击左右跳、中区双击全屏；标题栏双击最大化（shell）

### 4.2 明确未做 / 用户下一步可能要

| 优先级 | 项 | 备注 |
|--------|----|------|
| P0 | **真机手感打磨** | 用户原话：「只是能看」→ 跑 macOS release 自己点一遍剧集/电影/SMB |
| P0 | **SMB/HTTP 外挂字幕** | 现仅本地路径；代理 URL 需另路径（proxy 出 srt 或下载临时文件） |
| P1 | 内嵌字幕自动选中文 | 现主要对外挂优先 zh；内嵌 track language 可同样启发式 |
| P1 | 字幕样式 / 时间轴偏移 | media_kit/libmpv 属性 |
| P1 | 长按 2x、音量/亮度手势 | 桌面次要 |
| P2 | 画中画 PiP | 进度文档标过难 |
| P2 | 播放列表 UI（剧集列表侧栏） | 现在只有 N/P + 自动下一集 |
| P2 | 音频设备选择 / 循环 / AB 段 | 爆米花高级项 |

### 4.3 `PlayerArgs` 契约

```dart
PlayerArgs({
  required uri,
  required title,
  mediaId,          // 进度 key；剧集用 episode.id
  startAt,
  httpHeaders,
  showId,           // 非空 → 启用上下集 / 自动下一集
  showTitle,
})
```

详情页入口：`media_detail_page.dart` 的 `_playEpisode` / `_playMedia`。

---

## 5. 分类导航（已落地，注意互斥）

- 分类器：`LibraryShelfClassifier.classify(Media)`
- 规则优先级：路径关键字 → zh-CN genre（动画/纪录/真人秀/…）→ `MediaType`
- Claude 审阅强制要求：
  1. **不要**把「最近观看」放进 shelf enum（走 playback progress）
  2. **不要**依赖 `original_language`（scraper 未存）
  3. genre 关键字必须是 **zh-CN 实际值**
  4. 一条 media **只属于一个 shelf**

侧栏 IA：

```text
首页 / 最近观看 / 电影 / 电视剧 / 动漫 / 综艺 / 演唱会 / 纪录片 / 其他
底栏：收藏 · 来源 · 设置
```

---

## 6. 怎么跑

```bash
cd /Users/xiaoyu/code/open-filmly-flutter/app

# 依赖
flutter pub get

# 单元测试（排除环境依赖）
flutter test $(ls test/*.dart | grep -v integration_smb_real | grep -v ui_automation)

# 分析
flutter analyze

# macOS 开发
flutter run -d macos

# Release
flutter build macos --release
# 产物: build/macos/Build/Products/Release/open_filmly.app
# 用户桌面曾有: ~/Desktop/Open Filmly.app
```

**环境依赖测试（可失败，勿为修 CI 乱改业务）：**

- `test/integration_smb_real_test.dart` — 需要局域网 NAS
- `test/ui_automation_test.dart` — 需要已运行的 app + flutter_skill VM Service

用户真实库 DB 沙箱路径示例：

```text
~/Library/Containers/com.openfilmly.openFilmly/Data/Documents/open_filmly.sqlite
```

---

## 7. 协作约定（若继续双 AI）

- **Grok / 执行方**：出方案、改代码、跑测试
- **Claude fable-5**：只审方案（`claude -p ... --permission-mode plan`），默认 model 在 `~/.claude/settings.json`
- 用户语言：中文
- 包管理：Flutter 项目用 `flutter pub`；旧 Electron 树才是 pnpm

方案模板可参考：`docs/plan-category-nav-and-wip.md`。

---

## 8. 建议 Codex 接手顺序

### 立即（今天）

1. **阅读并保留工作区 diff**，不要覆盖未提交的 player / shelf。
2. `flutter test`（排除两个环境测）确认绿。
3. `flutter run -d macos` 人工验：
   - 本地电影 + 同目录 `.chs.srt`
   - 剧集 N/P + 播完连播
   - SMB 流是否缓冲/报错可读
4. 按用户反馈修 **播放手感** 的小问题（比开新功能重要）。
5. 用户同意后 **commit** 工作区（建议两 commit，见 §2.2）。

### 下一里程碑（播放体验 P0/P1）

1. SMB/HTTP 源外挂字幕策略
2. 内嵌字幕中文优先
3. 播放器内剧集列表面板（不必退出全屏）
4. 进度条章节/预览（可选）

### 再往后（产品完整度）

- l10n、自动更新（Sparkle / GitHub Releases）、Win/Linux 打包
- PiP

---

## 9. 雷区

| 雷 | 后果 |
|----|------|
| 用 `/media/:id` 路径参数 | GoException 404（id 含斜杠） |
| 剧集直接 `open(episode.id)` | 网络源播不了 |
| `deleteAll` 先删 media | 外键炸 |
| 扫进 macOS `._*` 文件 | 重复条目 |
| 分类用英文 genre 断言 | 刮削是 zh-CN，「动画」不是 `Animation` |
| 清空工作区 / 切回 Electron 主仓当主线 | 用户目标已是 Flutter |

---

## 10. 一句话状态

> **库浏览与分类已基本对齐爆米花壳子；播放从「能出画」升到了「有连播/外挂字幕/缓冲反馈」的可用层，但仍需真机打磨 + 网络源字幕 + 更完整的播放器次级能力。工作区未提交，请 Codex 先接管 diff、验证、提交，再按用户手感继续抠播放体验。**

---

## 11. 相关文档索引

| 文档 | 路径 |
|------|------|
| 进度长文 | `~/Documents/open-filmly-flutter-progress.md` |
| 分类方案 + 审阅 | `docs/plan-category-nav-and-wip.md` |
| 用户偏好 memory | `~/.claude/projects/-Users-xiaoyu-code-open-filmly/memory/user-prefers-bold-rewrites.md` |
| 旧 Electron CLAUDE.md | `/Users/xiaoyu/code/open-filmly/CLAUDE.md`（历史，非 Flutter 主线） |

**交接完成。Codex：从 `cd /Users/xiaoyu/code/open-filmly-flutter && git status` 开始。**
