# Open Filmly

Open Filmly 是一个本地优先、自托管的影视媒体库客户端。Flutter 主工程直接位于仓库根目录，支持 macOS、Windows、iOS 与 Android，以及本地文件、SMB、WebDAV、Emby 与 Jellyfin 媒体来源。

![Open Filmly 首页](docs/screenshots/home.png)

![Open Filmly 电视剧详情](docs/screenshots/tv-detail.png)

## 当前能力

- 电影、电视剧、动漫、综艺、演唱会、纪录片等互斥媒体分类
- TMDB 元数据、海报、背景图、演员与分集信息
- 最近播放、续播进度、收藏、全局搜索与自动扫描
- 电视剧按季 Tab 展示，使用 16:9 分集剧照卡片
- 本地目录、SMB、WebDAV、Emby 和 Jellyfin 媒体库
- macOS VLCKit 3.7.3、Windows libVLC 与 iOS / Android MobileVLCKit / libVLC 原生播放，支持硬件解码、音轨、字幕轨道和外挂字幕
- 播放缓冲、进度拖动、倍速、音量、上下集与自动连播
- macOS / Windows 窗口拖动、双击最大化、全屏和桌面键盘快捷键
- 窄屏底部导航、移动端双击手势与沉浸式播放交互

## 平台状态

| 平台 | 状态 | 说明 |
| --- | --- | --- |
| macOS | 可运行 | 使用 VLCKit 3.7.3 原生播放器 |
| Windows | 可运行 | 使用 Windows Runner 与 libVLC 原生播放器 |
| iOS | 可运行 | iOS Runner、系统文件导入与 MobileVLCKit 播放；已在 iOS 26.5 模拟器完成构建和启动验证 |
| Android | 可运行 | Android Runner、系统文件导入与 libVLC 播放；已在 Android 16 模拟器验证 |

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

## 技术栈

- UI：Flutter、Material 3
- 状态管理：Riverpod
- 路由：`go_router`
- 播放：VLCKit 3.7.3（macOS）/ libVLC（Windows、Android）/ MobileVLCKit（iOS）
- 数据库：Drift / SQLite
- 网络媒体：SMB Range 代理、WebDAV、Emby / Jellyfin
- 桌面窗口：`window_manager` + macOS / Windows 原生窗口桥接
