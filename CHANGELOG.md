```When Editing
本文档作用: 面向使用者的发版记录; 唯一 changelog 文件, MUST NOT 拆分开发者版本
遵循 AGENTS.md 文档编写规范
- 写: 新功能 / 行为修复 / 体验 / 安全 / 安装迁移
- MUST NOT 写: 文件路径 / 函数名 / 依赖包名 / 重构细节
- 单条 ≤ 2 行, 单版本 ≤ 5 条; 段落: Added / Changed / Fixed / Removed / Security
- 无用户可感知变化 → 占位: `跟随版本同步发布`
- 顶部保留 `## [Unreleased]`; 每版底部补对比链接
```

# Changelog

[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) + [SemVer](https://semver.org/).

## [Unreleased]

## [0.5.0] - 2026-07-31

### Fixed

- App 现在带签名, 修复「登录启动」注册失败; 覆盖安装升级不再吊销已授权的登录启动。
- 「登录启动」默认开启若首次失败, 下次启动会重试, 不再一次失败即永久放弃。

## [0.4.6] - 2026-07-31

### Removed

- 安装脚本不再支持自定义安装目录与版本, 固定安装 latest 版本到 `/Applications`。

## [0.4.5] - 2026-07-31

跟随版本同步发布

## [0.4.4] - 2026-07-31

### Changed

- Moved the install script to `scripts/install.sh`. Use the updated one-liner in the README; the old `install.sh` URL no longer resolves.

## [0.4.3] - 2026-07-23

### Changed

- Renamed the project to `jj-ice` (repository, app bundle, bundle identifier, release asset). Existing settings and Launch at Login reset on first launch of this version.

## [0.4.2] - 2026-05-31

### Changed

- Updated user-facing copy. App behavior is unchanged.

## [0.4.1] - 2026-05-31

### Fixed

- Fixed the arrow context menu opening in a clipped scroll mode.

## [0.4.0] - 2026-05-31

### Changed

- Restored the divider + arrow layout.

## [0.3.1] - 2026-05-31

### Fixed

- Kept the arrow visible after collapsing menu bar items.

## [0.3.0] - 2026-05-31

### Added

- Added a Help menu item.

### Changed

- Enabled Launch at Login by default on first launch.
- Removed the duplicate collapse action from the context menu.

## [0.2.0] - 2026-05-31

### Changed

- Simplified the menu bar control to a single arrow.

## [0.1.1] - 2026-05-31

### Fixed

- Fixed launch showing no menu bar items.

## [0.1.0] - 2026-05-31

### Added

- Added menu bar item collapse and restore.
- Added collapsed state persistence and optional Launch at Login.

## [0.0.2] - 2026-05-31

### Added

- Added the app icon.

## [0.0.1] - 2026-05-31

### Added

- Added the install script.

[Unreleased]: https://github.com/yigegongjiang/jj-ice/compare/v0.5.0...HEAD
[0.5.0]: https://github.com/yigegongjiang/jj-ice/compare/v0.4.6...v0.5.0
[0.4.6]: https://github.com/yigegongjiang/jj-ice/compare/v0.4.5...v0.4.6
[0.4.5]: https://github.com/yigegongjiang/jj-ice/compare/v0.4.4...v0.4.5
[0.4.4]: https://github.com/yigegongjiang/jj-ice/compare/v0.4.3...v0.4.4
[0.4.3]: https://github.com/yigegongjiang/jj-ice/compare/v0.4.2...v0.4.3
[0.4.2]: https://github.com/yigegongjiang/jj-ice/compare/v0.4.1...v0.4.2
[0.4.1]: https://github.com/yigegongjiang/jj-ice/compare/v0.4.0...v0.4.1
[0.4.0]: https://github.com/yigegongjiang/jj-ice/compare/v0.3.1...v0.4.0
[0.3.1]: https://github.com/yigegongjiang/jj-ice/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/yigegongjiang/jj-ice/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/yigegongjiang/jj-ice/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/yigegongjiang/jj-ice/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/yigegongjiang/jj-ice/compare/v0.0.2...v0.1.0
[0.0.2]: https://github.com/yigegongjiang/jj-ice/compare/v0.0.1...v0.0.2
[0.0.1]: https://github.com/yigegongjiang/jj-ice/releases/tag/v0.0.1
