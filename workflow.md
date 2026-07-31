```When Editing
本文档作用: 工程工作流程 (可用工具 / 发布); MUST NOT 写工程说明 (→ README.md) / LLM 约束 (→ AGENTS.md)
遵循 AGENTS.md 文档编写规范
- 所有段落均为条件段, 根据工程实际决定保留或删除; 存在即为明确流程, MUST NOT 附加强度标记
- 发布内按顺序编号步骤; 顶部 TL;DR ≤ 5 行; 删除子段后重编号保持连续
- 风险点 / 不可逆操作用 `>` 引用块; 高危操作 MUST 标禁用条件
```

# 可用工具

- `gh` — 已登录
- `xcodebuild` — Xcode 命令行工具链

# 发布

代码变更完成后立即执行（= 需求交付的最后环节）。交付 = 预部署 + push。不签名; **本机预部署成功 = 唯一发版门禁**, MUST NOT 等人类验收 / 手测。

> push 成功 = 交付结束。MUST NOT 监听 / 轮询 / 验证 GitHub Actions 结果 (`gh run watch` / `gh run list` / 查 Release 产物)。

## TL;DR

依序执行：

1. 写版本：`MARKETING_VERSION` + `CHANGELOG.md` 同步编辑 (与 tag 一致)
2. 预部署：`bash scripts/install-local.sh`
3. 发布：commit + annotated tag (`-a -m`) + push branch + tag

## 1. 写版本

- 版本号: 默认递增 PATCH (第三位); 超大功能更新/调整 → MINOR; 禁止 → MAJOR（除非人类主动要求）。
- `jj-ice.xcodeproj/project.pbxproj` 的 `MARKETING_VERSION` (Debug + Release 两处) 与 tag 一致: tag = `v` + MARKETING_VERSION; 不一致 → 发版失败。
- `CHANGELOG.md` 顶部新增 `## [X.Y.Z] - YYYY-MM-DD` 段 + 底部补对比链接; 只写面向用户的精简摘要, 无 commit 细节。

## 2. 预部署

本机完成实际交付: Release 打包 + 装入 `/Applications`。

```bash
bash scripts/install-local.sh
```

脚本内含 Release 无签名编译, 成功 = 编译门禁通过 + 本机交付完成; 失败 → 修好重跑, MUST NOT 进入发布。不运行 app 验收, 功能由人类自行手测 `.app`, 不阻塞发版。

## 3. 发布

```bash
git add .
git commit -m "release: vX.Y.Z"
git tag -a vX.Y.Z -m "vX.Y.Z"
git push origin main vX.Y.Z
```

> annotated tag (`-a -m`) 而非 lightweight: 兼容 `tag.gpgsign=true` (开启时 lightweight tag 被强制升级为 signed 但缺 message → fail)。
