# Open Filmly 下一里程碑方案：爆米花式分类导航 + 收尾 WIP

> 作者：Grok（方案 + 执行）
> 审阅方：Claude Code `claude-fable-5`
> 日期：2026-07-11
> 仓库：`/Users/xiaoyu/code/open-filmly-flutter` · 分支 `feat/flutter-refactor`
> 目标产品对标：网易爆米花（Mac）全功能媒体库

---

## 0. 现状摘要

### 已具备（HEAD `fca4808` + 进度文档）
- Flutter + media_kit 本地/SMB/WebDAV/Emby 播放
- Drift 库、TMDB+Gemini 刮削、剧集层级、收藏、全局搜索、自动扫描
- 爆米花风格浅色 UI、透明标题栏、富播放器
- 85+ 测试通过；macOS release 可构建

### 工作区未提交改动（半成品，~400 行）
| 改动 | 问题 |
|------|------|
| 侧栏新增 动漫/综艺/演唱会/纪录片/其他 | 路由全绑 `MediaType.unknown`，页面几乎空 |
| 去掉侧栏「收藏」「来源」 | 路由仍在，首页有入口，但导航完整性下降 |
| 播放器三区双击（快退/全屏/快进） | 合理，可保留 |
| 标题栏双击最大化 | 合理，可保留 |
| 侧栏搜索框占位 + 底部账号行 | 合理，可保留 |
| SMB 预填/size>0 判断 | 合理，但留了 `print` 调试日志 |
| LibraryPage `customTitle` | 只有标题，无真实分类过滤 |

### 与爆米花的关键差距（本轮只做能闭环的）
1. **媒体分类导航是空壳**（最高优先）
2. WIP 调试噪声与测试未对齐
3. 低优先延后：l10n、PiP、自动更新、Win/Linux 打包

---

## 1. 设计决策

### 1.1 不扩展 `MediaType` 枚举
`MediaType { movie, tv, unknown }` 表示**文件结构语义**（单文件电影 vs 剧集），继续用于扫描/分集。

**库浏览分类**用独立层：

```dart
enum LibraryShelf {
  recent,      // 最近观看
  movie,       // 电影（排除动画等已归入细分的可选策略：见下）
  tv,          // 电视剧（排除动画）
  anime,       // 动漫
  variety,     // 综艺
  concert,     // 演唱会
  documentary, // 纪录片
  other,       // 其它/未匹配细分
}
```

### 1.2 分类规则（纯函数，查询时计算，**零 DB 迁移**）

优先级从高到低：

1. **路径启发**（导入未刮削也能分）
   路径/文件夹名含：`动漫|Anime|动画` → anime；`综艺|Variety` → variety；
   `演唱会|Concert|Live` → concert；`纪录片|Documentary|纪录` → documentary

2. **TMDB genres + 语言启发**（`Media.genres` + details 里 original_language 若有）
   - genres 含 Animation/动画 **且**（日语/韩语 或 路径/标题含 anime/番）→ anime
   - genres 含 Documentary/纪录 → documentary
   - genres 含 Reality / Talk Show / 真人秀 / 脱口秀 → variety
   - genres 含 Music/音乐 **且** 标题/路径含 concert/live/演唱会 → concert

3. **回落**
   - `MediaType.tv` → tv
   - `MediaType.movie` → movie
   - else → other

**电影/电视剧页策略（推荐）**：
- `/movies`：`type==movie` 且 **不是** anime/documentary/concert
- `/tv`：`type==tv` 且 **不是** anime/variety
- 细分页：按 shelf 匹配
- `/other`：未进 movie/tv/细分的 residual，或 `type==unknown`

这样不会出现「动画电影既在电影又在动漫」的双挂（爆米花通常是互斥分区）。

### 1.3 侧栏信息架构（对齐爆米花）

```
[Logo Open Filmly]
[搜索框 → GlobalSearch]
媒体库
  首页
  最近观看
  电影
  电视剧
  动漫
  综艺
  演唱会
  纪录片
  其他
────────
[头像/名]  [设置⚙]
```

- **收藏**：保留 `/favorites`；首页「我的收藏」货架 + 全局搜索可进；本轮不把收藏塞回主列表（与爆米花一致：收藏常在账号/二级）。
- **来源**：保留 `/sources`；首页空态与设置内入口；本轮不占侧栏主位。

若审阅方认为必须侧栏可见「收藏/来源」，备选：底部账号区增加「收藏」「媒体库来源」两个小入口图标。

### 1.4 实现落点（文件）

| 文件 | 变更 |
|------|------|
| `lib/data/models/library_shelf.dart` | **新建** enum + 匹配规则 + 路径/genre 关键字 |
| `lib/data/models/media_library_query.dart` | 增加可选 `LibraryShelf? shelf`；`type` 改为可选 |
| `lib/data/repositories/media_repository.dart` | `browse` 支持 shelf 过滤 |
| `lib/providers/data_providers.dart` | provider 透传 shelf |
| `lib/features/library/library_page.dart` | 用 shelf 或 type 构造 query |
| `lib/core/router/app_router.dart` | 各分类路由绑真实 shelf |
| `lib/features/shell/app_shell.dart` | 保留 WIP UI；nav 与路由一致 |
| `lib/features/config/smb_browser_page.dart` | 去掉 print；保留 size>0 / 预填修复 |
| `lib/features/player/player_page.dart` | 保留三区手势（已 import WindowChannel） |
| `test/library_shelf_test.dart` | **新建** 分类规则单测 |
| `test/ui_automation_test.dart` | 适配新侧栏文案/键 |

**不做**：schema 迁移、category 列、l10n、PiP、自动更新、跨平台打包。

---

## 2. 执行步骤（DAG）

```
A. 落地 LibraryShelf 分类器 + 单测
        ↓
B. MediaLibraryQuery / Repository / Provider 支持 shelf
        ↓
C. LibraryPage + Router 接真过滤
        ↓
D. 收尾 shell/player/smb WIP（去 print、对齐 nav）
        ↓
E. 更新 ui_automation + 全量 test/analyze
        ↓
F. release 构建 + 桌面 Open Filmly.app 更新（可选）
        ↓
G. 更新 ~/Documents/open-filmly-flutter-progress.md
```

### 验收标准
1. 侧栏点「动漫」等不再是空的 unknown 列表；有 genre/路径命中的条目正确出现
2. 电影/电视剧与细分互斥（同一部动画不会同时占满电影+动漫）
3. `flutter analyze` 无 error；`flutter test` 全绿
4. 无生产 `print` 调试日志
5. 收藏页、来源页仍可从首页/设置到达

---

## 3. 风险与回退

| 风险 | 缓解 |
|------|------|
| 用户库 genre 为空导致细分全空 | 路径启发 + other 兜底；设置里仍有全库搜索 |
| 中英 genre 名不一致 | 关键字同时覆盖中英文 TMDB 常见写法 |
| UI 测试硬编码侧栏文案 | 一并改 automation keys |
| 未提交 diff 与方案冲突 | 在现有 WIP 上增量改，不 reset |

回退：仅回退 `library_shelf` + query 相关提交；shell 视觉 WIP 可独立保留。

---

## 4. 请审阅方重点反馈

1. **互斥分区** vs **可重叠**（动画同时出现在电影+动漫）——方案默认互斥，是否同意？
2. **收藏/来源**是否必须回侧栏？还是首页+设置足够？
3. **零迁移纯函数分类** vs **落库 category 列**——方案默认零迁移，量大时是否要落库？
4. 本轮范围是否过大/过小？是否应先只做 anime+documentary 两个最常见细分？
5. 有无遗漏的爆米花核心体验（本轮必须做的）？

---

## 5. 审阅结论区（由 Claude fable-5 填写）

- 结论：`APPROVE_WITH_CHANGES`
- 必改项：
  1. `LibraryShelf.recent` 移出分类枚举（最近观看走播放进度）
  2. 不依赖 `original_language`（scraper 未存该字段）；anime 靠 genres+路径/标题
  3. genre 关键字用 zh-CN 实际值
  4. 分类器单值化：每条 media 只归一个 shelf
- 建议项：底部账号行加收藏/来源小图标；清理 print；路径表使用仓库根目录相对路径
- 签字：claude-fable-5 · 2026-07-11

## 6. 执行记录（Grok · 2026-07-11）

已按审阅必改落地：
- 新增 `lib/data/models/library_shelf.dart` + `test/library_shelf_test.dart`
- Query/Repo/Provider/LibraryPage/Router 接 shelf
- 侧栏分类路由绑定真实 shelf；底部账号行收藏/来源/设置图标
- 去掉 SMB debug print；首页 featured 电影/剧集改 exclusive shelf
- 单元测试（排除 real SMB / ui_automation 环境依赖）全绿
