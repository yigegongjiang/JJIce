# JJIce

macOS 状态栏图标管理工具 — 隐藏/展示状态栏图标, 缓解图标过多导致的拥挤.

仅支持最新 macOS, 不上架 App Store, 不做签名. 极简单一职责.

## 功能

- 部分图标隐藏, 部分保持展示
- 设置页列出当前所有状态栏图标, 分上下两栏: 上 = 展示区, 下 = 隐藏区
- 拖拽管理: 上 → 下 即隐藏, 下 → 上 即恢复
- 所有管理在 App 内页拖拽完成, 不直接操作系统状态栏

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

发版前本地 MUST 编译通过 (上述 `xcodebuild`); 无自动化测试, 不运行 app, 功能由人工验证.

## 发布

推 `v*` tag 触发 `.github/workflows/release.yml`: 编译 → 打包 `JJIce-macos.zip` → 发 GitHub Release. 步骤 → [deploy.md](./deploy.md).
