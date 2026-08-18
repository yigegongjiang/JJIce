```When Editing
本文档作用: 工程总览 (价值主张 / 使用 / 架构 / 结构); MUST NOT 写发布流程 (→ workflow.md) / LLM 约束 (→ AGENTS.md)
遵循 AGENTS.md 文档编写规范
- 章节按需增删, 只留项目真有的; 首行一行价值主张, MUST NOT 带 LLM 提示
- 短并列项用表格; 可执行步骤 fenced + `#` 注释同行
- NEVER 写「开发」段 (VibeCoding 不向人类解释 dev 命令)
```

# jj-ice

macOS 菜单栏工具: 一键折叠图标 (分隔符 + 箭头) + 常驻读数区 (上下行网速 / AirPods 电量).

## 使用

```bash
curl -fsSL https://raw.githubusercontent.com/yigegongjiang/jj-ice/main/scripts/install.sh | bash   # 装到 /Applications 并去 quarantine
```

- 手动装: 下载 [Releases](https://github.com/yigegongjiang/jj-ice/releases) 的 `jj-ice-macos.zip` → 拖 `/Applications` → `xattr -dr com.apple.quarantine /Applications/jj-ice.app`
- 按住 `Command` 拖动图标到分隔符左侧 = 归入可隐藏区; 右侧常驻
- 点箭头折叠 / 展开 (状态持久化); 右键箭头 = 唯一菜单入口: 网速开关 / AirPods 电量开关 (均默认开) / 登录启动 (默认开) / Help / About / Quit
- 网速两行 (上 = 上行 / 下 = 下行), 1s 刷新, 占宽 ~22pt; 只统计物理网卡 → VPN 开关不改变读数; 纯展示, 点击无反应 (开关在箭头右键菜单)
- AirPods 电量 `xx%`, 15s 刷新; 只读单只 (双耳同步耗电); 纯展示, 点击无反应; 显隐 = 开关 AND 已连接耳机 (网速只看开关): 未连接自动消失, 关开关连 15s 轮询一并停止
- ad-hoc 签名, 未公证, App Store 外分发; 需 macOS 26+

## 架构

Swift 6 + AppKit, 纯 `NSStatusItem` 实现, 无私有 API. `autosaveName` 托管图标位置, `UserDefaults` 存折叠状态, `ServiceManagement` 管登录启动. 无第三方依赖.

折叠原理: 折叠时把分隔符 item 撑到 `max(10000, 最宽屏宽 + 200)` 并 `alphaValue = 0`, 左侧图标被挤出屏幕; 展开时回到 `variableLength`.

三层分工 (新增读数 = 加一个 Section 子类 + controller 列表加一行):

<!-- prettier-ignore -->
| 层 | 目录 | 职责 |
| --- | --- | --- |
| 数据 | `Monitors/` | 读硬件值, 不碰 AppKit |
| 展示 | `Sections/` | 一个 `NSStatusItem` 的位置 / 刷新循环 / 显隐 / 绘制 |
| 编排 | `StatusBarController` | 分隔符 + 箭头 + sections 排布 + 聚合菜单 |

`StatusSection` 基类收拢公共骨架: 位置播种 / `Task` 刷新循环 / `UserDefaults` 显隐 / 取消竞态; 子类只重写 `refresh()` (返回 false = 无数据 → 自动隐藏) 与 `refreshInterval`.

- 新 section MUST 播种位置 0 (最右可用槽), 否则首次出现会落在分隔符左侧 = 被折叠隐藏
- 读数 section MUST NOT 挂 target / action: 点击无反应, 菜单唯一入口 = 右键箭头
- `autosaveName` 与显隐 `UserDefaults` key 一经发布即冻结: 改名 = 重置用户图标位置 / 静默重开已关读数
- 实测 AppKit 一旦 `isVisible = false` 就丢弃该 item 的 `NSStatusItem Preferred Position` 且永不回写 (反复隐藏 / 显示都不恢复) → 已播种的最右槽被交出, 读数可能重现在分隔符左侧。两处对策: `init` 里 NEVER 设 `isVisible = false` (交给首次 `refresh()`, 代价约 60ms 空图标); 每次由隐藏转显示前重新播种 (`StatusSection.setVisible`)

网速采样: `sysctl(CTL_NET, PF_LINK, NETLINK_GENERIC, IFMIB_IFDATA, <if_index>, IFDATA_GENERAL)` 取 `struct ifmibdata` 的 64 位 `if_data64` 计数器, 1s 差分.

- NEVER 用 `NET_RT_IFLIST2`: 内核对非 Apple 签名进程把计数器量化到 1 KiB 步进 + 4 GiB 回绕 (本机实测 en0 恰差 4294967296)
- NEVER 用 `getifaddrs`: 只暴露 32 位 `if_data`, 每 4 GiB 回绕
- 只累加 `en<数字>` + `IFT_ETHER` 接口: 隧道流量必经物理口, 再加 utun / ipsec 会双计并在 VPN 开关时跳变; bridge / vmenet / awdl / llw / ap / anpi / lo 同时被排除
- 计数器倒退 = 接口重建 → 只重设基线; 间隔 ≤ 0 或 > 5s (睡眠 / 定时器合并) → 只重设基线不出数; 接口消失即从基线剔除 (无增长)
- 渲染成 template `NSImage` 双行 → 自动跟随明暗菜单栏; 等宽字体 + 定宽 4 字符 (`999K` / `1.5M` / `1.4G`, 无箭头无 `/s`, kern -0.2) → 恒定 22pt, 读数变化不抖宽度; 行高取字体行高与 (菜单栏高 - 2) / 2 的较小值, 再压会裁字形

AirPods 采样: 子进程跑 `system_profiler SPBluetoothDataType -json` 解析 `device_connected`, 单次约 60ms (本机实测).

- NEVER 用私有 `IOBluetoothDevice` KVC (`BatteryPercentLeft` / `BatteryPercentCombined`) 或自行解码 BLE continuity 广播: 均无文档、跨版本变动, 后者还要蓝牙权限; 公共 API 无任何电量接口
- 只读 `device_connected` + `device_minorType ∈ {Headphones, Headset}`: 断连设备会移入 `device_not_connected` 并丢掉电量字段 → 结构上不可能显示过期读数; minorType 过滤挡掉同样上报电量的键鼠
- 取值优先 `Left` → `Right` → `Main` → `Single` (单驱动设备如 AirPods Max 只有后两者); 非 0–100 视为脏数据
- 子进程在 `Task.detached` 里跑 → 不卡主线程; 每条退出路径 `waitUntilExit()` 回收 (否则每轮攒一个 zombie); 10s 看门狗 `terminate()` 兜蓝牙栈卡死 → 退化成「无读数」而非永久冻结
- 15s 轮询: 电量分钟级才动 1%, 连接/断开表现为读数出现/消失; 无需监听 `IOBluetooth` 连接通知 (历史上有缺符号崩溃 + 连接失败也回调)

构建形态: SwiftPM executable, 无 xcodeproj / Storyboard / asset catalog; `.app` 由 `scripts/build-app.sh` 组装 (Info.plist + icns + ad-hoc 签名). universal (arm64 + x86_64) — macOS 26 仍覆盖部分 Intel 机型.

签名: ad-hoc (`codesign --sign -`), designated requirement 只钉 bundle identifier 不钉 cdhash. `SMAppService` 拒绝为无签名 bundle 注册登录项 → 签名是功能前提; 不钉 cdhash 则重装 / 升级不吊销用户已授权的登录项.

## 项目结构

- `Package.swift` — SwiftPM 清单: deployment target + `MainActor` 默认隔离
- `VERSION` — 版本单一信源; tag = `v` + 内容
- `Sources/jj-ice/` — 源码: `main.swift` (入口) / `AppDelegate.swift` / `StatusBarController.swift` (分隔符 + 箭头 + sections 排布 + 菜单)
- `Sources/jj-ice/Sections/` — 展示层: `StatusSection.swift` (基类) / `NetworkSpeedSection.swift` / `AirPodsBatterySection.swift`
- `Sources/jj-ice/Monitors/` — 数据层: `NetworkSpeedMonitor.swift` (接口 MIB 采样 → 速率) / `AirPodsBatteryMonitor.swift` (`system_profiler` → 电量)
- `Resources/` — `Info.plist.in` (`@VERSION@` 占位 + `LSUIElement`) / `AppIcon.icns`
- `scripts/build-app.sh` — 构建 + 组装 `.app` + ad-hoc 签名; 本机与 CI 共用同一份
- `scripts/install-local.sh` — 本机预部署: 调 `build-app.sh` + 装入 `/Applications`
- `scripts/install.sh` — 一键安装脚本: 从 latest Release 下载 + 装入 `/Applications`; 无可配置项
- `make_icon.swift` — CoreGraphics 渲图 + `iconutil` 合成 `Resources/AppIcon.icns`
- `.github/workflows/release.yml` — `v*` tag 触发: 校验 `VERSION` → `build-app.sh` → 打 zip + checksums → 建 Release
