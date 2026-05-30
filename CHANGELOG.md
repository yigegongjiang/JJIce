# Changelog

[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) + [SemVer](https://semver.org/).

## [Unreleased]

## [0.4.0] - 2026-05-31

### Changed

- 恢复分界竖线: 菜单栏重新显示「竖线 + 箭头」。竖线既是隐藏边界的可见参照, 也是折叠时撑开顶图标的执行项; 箭头独立常驻负责切换。0.2.0~0.3.1 的隐藏竖线 / 单箭头方案不再保留

## [0.3.1] - 2026-05-31

### Fixed

- 折叠后箭头消失、完全无法操作: v0.2.0 起让箭头自身撑宽顶出图标, 致箭头连同图标被挤出可见区。改为「隐形分隔项负责撑开 + 箭头独立常驻」, 箭头永远可见可点

## [0.3.0] - 2026-05-31

### Added

- 右键菜单新增「帮助」: 一键打开 GitHub 仓库页

### Changed

- 开机自启改为首次启动默认开启 (可在右键菜单关闭), 无需手动开启
- 右键菜单移除「折叠 / 展开」项: 该操作是左键点箭头的能力, 不在右键重复

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

[Unreleased]: https://github.com/yigegongjiang/JJIce/compare/v0.4.0...HEAD
[0.4.0]: https://github.com/yigegongjiang/JJIce/compare/v0.3.1...v0.4.0
[0.3.1]: https://github.com/yigegongjiang/JJIce/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/yigegongjiang/JJIce/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/yigegongjiang/JJIce/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/yigegongjiang/JJIce/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/yigegongjiang/JJIce/compare/v0.0.2...v0.1.0
[0.0.2]: https://github.com/yigegongjiang/JJIce/compare/v0.0.1...v0.0.2
[0.0.1]: https://github.com/yigegongjiang/JJIce/releases/tag/v0.0.1
