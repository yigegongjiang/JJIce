# JJIce

macOS 状态栏图标管理工具 — 隐藏/展示状态栏图标, 缓解图标过多导致的拥挤.

仅支持最新 macOS, 不上架 App Store, 不做签名. 极简单一职责.

## 功能

- 菜单栏放「分界竖线 + 折叠开关」两个图标
- 点开关折叠 → 分界线左侧图标收起到屏外; 再点展开复原
- 折叠状态自动记忆; 可设开机自启 (开关右键菜单)

## 用法

1. 首次: 按住 ⌘ 在菜单栏拖图标, 把要隐藏的拖到 JJIce 分界竖线**左侧**
2. 点折叠开关 (`‹` / `›`) 一键收起 / 展开
3. 右键开关: 折叠切换 / 开机启动 / 关于 / 退出

## 安装

构建未签名, 脚本会自动去除 quarantine 隔离属性后装入 `/Applications`:

```bash
curl -fsSL https://raw.githubusercontent.com/yigegongjiang/JJIce/main/install.sh | bash
```

可用 `VERSION` / `INSTALL_DIR` / `REPO` 覆写.

手动安装: 从 [Releases](https://github.com/yigegongjiang/JJIce/releases) 下载 `JJIce-macos.zip`, 解压拖入 `/Applications`, 首次打开前执行:

```bash
xattr -dr com.apple.quarantine /Applications/JJIce.app   # 未签名, 绕过 Gatekeeper
```

## 开发

```bash
open JJIce.xcodeproj                                      # Xcode 打开
xcodebuild -scheme JJIce -configuration Release \
  CODE_SIGNING_ALLOWED=NO clean build                     # 命令行编译 (无签名)
```

发版前本地 MUST 编译通过 (上述 `xcodebuild`) — 唯一发版门禁; 无自动化测试, 不运行 app, 功能由人类发版后手测.

## 发布

推 `v*` tag 触发 `.github/workflows/release.yml`: 编译 → 打包 `JJIce-macos.zip` → 发 GitHub Release. 步骤 → [deploy.md](./deploy.md).
