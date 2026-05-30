# 部署流程

AI 改完代码主动执行. 不签名; **本地编译通过**是发版前置门禁 (不运行 app), 通过后推 `v*` tag, Actions 编译 + 打包 + 发布.

## TL;DR

1. 本地 `xcodebuild ... clean build` MUST 通过 (不运行 app)
2. 改 `MARKETING_VERSION` + `CHANGELOG.md` 新版段, 版本一致
3. commit + annotated tag (`-a -m`) + push branch + tag
4. 等 Actions → Release 出现 `JJIce-macos.zip` + `checksums.txt`

## 1. 本地编译 (前置门禁)

```bash
xcodebuild -scheme JJIce -configuration Release CODE_SIGNING_ALLOWED=NO clean build
```

MUST 编译通过才进入后续步骤 — 把错误挡在本地, MUST NOT 等 Actions 才暴露. 不运行 app, 功能由人类手测 `.app`.

## 2. 写版本

- 版本号: 默认递增 PATCH (第三位); 新功能 → MINOR; 不兼容 → MAJOR.
- `MARKETING_VERSION` (Release/Debug 配置) MUST 与 tag 一致: tag = `v` + MARKETING_VERSION (如 `0.0.1` → `v0.0.1`). Actions 第一步用 `xcodebuild -showBuildSettings` 提取并校验, 不一致直接 fail.
- `CHANGELOG.md` 顶部新增 `## [X.Y.Z] - YYYY-MM-DD` 段并列改动, 底部补对比链接. 只写面向用户的精简摘要; commit 详情由 Actions `generate_release_notes` 自动汇总到 Release.

## 3. 发布

```bash
git add .
git commit -m "release: vX.Y.Z"
git tag -a vX.Y.Z -m "vX.Y.Z"
git push origin <branch> vX.Y.Z
```

> 用 annotated tag (`-a -m`) 而非 lightweight: 兼容 `tag.gpgsign=true` (开启时 lightweight tag 被强制升级为 signed 但缺 message → fail).

## 4. amend 修上版 bug

AI 自主识别 "刚发版的 bug, 不发新版" 场景 (信号: 反馈指向刚 push 的 tag / 改动极小仅修缺陷 / 语气暗示上版延续如 "刚那个" "刚发的"). 此时:

> **commit + tag 必须同步更新**: amend 后 commit hash 变了, 远程 tag 仍指旧 hash → Release artifact 与 HEAD 分离. 只 force push commit 不够, 必须删远程 tag 后重打, 否则 Actions 不会重跑.

```bash
git commit -a --amend --no-edit
git tag -d vX.Y.Z
git push origin :refs/tags/vX.Y.Z
git tag -a vX.Y.Z -m "vX.Y.Z"
git push --force-with-lease origin <branch>
git push origin vX.Y.Z
```
