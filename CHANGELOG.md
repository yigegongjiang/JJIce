# Changelog

[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) + [SemVer](https://semver.org/).

## [Unreleased]

## [0.2.0] - 2026-05-31

### Changed

- 移除分界竖线, 改为单箭头: 箭头本身即分界 — 左侧图标折叠隐藏 / 右侧常驻。折叠时箭头原地不动, 消除原先「竖线与箭头之间」的歧义缝隙

## [0.1.1] - 2026-05-31

### Fixed

- 安装后启动毫无反应、状态栏不出现图标: 纯代码 app 缺少 `main.swift` 入口, `@main` 未把 `AppDelegate` 挂到 `NSApp.delegate`, 致 `applicationDidFinishLaunching` 从不触发 (进程存活却零表现). 新增 `main.swift` 显式挂载 delegate 后修复

## [0.1.0] - 2026-05-31

### Added

- 菜单栏折叠: 点开关把分界线左侧图标一键收起 / 展开
- 折叠状态记忆; 可选开机自启

## [0.0.2] - 2026-05-31

### Added

- 应用图标: 冰蓝菜单栏主题 (白色胶囊 + 图标圆点 + 收纳 chevron), 呼应状态栏图标管理

## [0.0.1] - 2026-05-31

### Added

- 一键安装: `install.sh` 下载未签名 macOS 构建并装入 `/Applications`

[Unreleased]: https://github.com/yigegongjiang/JJIce/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/yigegongjiang/JJIce/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/yigegongjiang/JJIce/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/yigegongjiang/JJIce/compare/v0.0.2...v0.1.0
[0.0.2]: https://github.com/yigegongjiang/JJIce/compare/v0.0.1...v0.0.2
[0.0.1]: https://github.com/yigegongjiang/JJIce/releases/tag/v0.0.1
