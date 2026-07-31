```When Editing
本文档作用: 工程总览 (价值主张 / 使用 / 架构 / 结构); MUST NOT 写发布流程 (→ workflow.md) / LLM 约束 (→ AGENTS.md)
遵循 AGENTS.md 文档编写规范
- 章节按需增删, 只留项目真有的; 首行一行价值主张, MUST NOT 带 LLM 提示
- 短并列项用表格; 可执行步骤 fenced + `#` 注释同行
- NEVER 写「开发」段 (VibeCoding 不向人类解释 dev 命令)
```

# jj-ice

macOS 菜单栏折叠工具: 分隔符 + 箭头两个 status item, 一键隐藏 / 恢复分隔符左侧的图标.

## 使用

```bash
curl -fsSL https://raw.githubusercontent.com/yigegongjiang/jj-ice/main/scripts/install.sh | bash   # 装到 /Applications 并去 quarantine
```

- 手动装: 下载 [Releases](https://github.com/yigegongjiang/jj-ice/releases) 的 `jj-ice-macos.zip` → 拖 `/Applications` → `xattr -dr com.apple.quarantine /Applications/jj-ice.app`
- 按住 `Command` 拖动图标到分隔符左侧 = 归入可隐藏区; 右侧常驻
- 点箭头折叠 / 展开 (状态持久化); 右键箭头 = 登录启动 (默认开) / Help / About / Quit
- ad-hoc 签名, 未公证, App Store 外分发; 需 macOS 26+

## 架构

Swift 6 + AppKit, 纯 `NSStatusItem` 实现, 无私有 API. `autosaveName` 托管图标位置, `UserDefaults` 存折叠状态, `ServiceManagement` 管登录启动. 无第三方依赖.

折叠原理: 折叠时把分隔符 item 撑到 `max(10000, 最宽屏宽 + 200)` 并 `alphaValue = 0`, 左侧图标被挤出屏幕; 展开时回到 `variableLength`.

构建形态: SwiftPM executable, 无 xcodeproj / Storyboard / asset catalog; `.app` 由 `scripts/build-app.sh` 组装 (Info.plist + icns + ad-hoc 签名). universal (arm64 + x86_64) — macOS 26 仍覆盖部分 Intel 机型.

签名: ad-hoc (`codesign --sign -`), designated requirement 只钉 bundle identifier 不钉 cdhash. `SMAppService` 拒绝为无签名 bundle 注册登录项 → 签名是功能前提; 不钉 cdhash 则重装 / 升级不吊销用户已授权的登录项.

## 项目结构

- `Package.swift` — SwiftPM 清单: deployment target + `MainActor` 默认隔离
- `VERSION` — 版本单一信源; tag = `v` + 内容
- `Sources/jj-ice/` — 源码: `main.swift` (入口) / `AppDelegate.swift` / `StatusBarController.swift` (全部逻辑)
- `Resources/` — `Info.plist.in` (`@VERSION@` 占位 + `LSUIElement`) / `AppIcon.icns`
- `scripts/build-app.sh` — 构建 + 组装 `.app` + ad-hoc 签名; 本机与 CI 共用同一份
- `scripts/install-local.sh` — 本机预部署: 调 `build-app.sh` + 装入 `/Applications`
- `scripts/install.sh` — 一键安装脚本: 从 latest Release 下载 + 装入 `/Applications`; 无可配置项
- `make_icon.swift` — CoreGraphics 渲图 + `iconutil` 合成 `Resources/AppIcon.icns`
- `.github/workflows/release.yml` — `v*` tag 触发: 校验 `VERSION` → `build-app.sh` → 打 zip + checksums → 建 Release
