# AGENTS

macOS 状态栏图标管理 app (Swift + AppKit, 仅最新 macOS). 工程总览 → [README.md](./README.md); 发布流程 → [deploy.md](./deploy.md); 文档写法 → [llm-doc-style.md](./llm-doc-style.md).

## 工作模式 (AI-only)

- 代码 / 构建 / 部署 / 发布 全部由 Claude Code 或 Codex 执行
- 设计决策 (架构 / 选型 / 命名 / 依赖) 以 AI 判断为准, MUST NOT 强行套人类惯例
- 禁止过度设计: 无明确需求时取最简有效方案, MUST NOT 引入不必要的抽象 / 配置 / 依赖 / 复杂度
- 非必要 MUST NOT 反问, 直接决策执行 (deploy / 技术抉择 / 文档同步 / 版本号 / changelog)
- 用户角色 = 触发者 + 验收者 (功能测试由人类完成); MUST NOT 拉人类进设计回路

## 构建与发布硬约束

- 不做任何代码签名 (`CODE_SIGNING_ALLOWED=NO`); 分发后靠 `xattr` 去 quarantine 绕过 Gatekeeper
- 改完代码 MUST 本地编译通过 (`xcodebuild ... clean build`, 不运行 app) 才能推 tag; 把错误挡在本地, MUST NOT 等 Actions 才暴露编译失败
- 无自动化测试 / 不运行 app; 功能由人类手测; Actions 侧再编译一次仅作冗余保险
- 仅支持最新 macOS; MUST NOT 为旧系统兼容增加分支

## 文档约束

- 全部文档 (README / CHANGELOG / deploy / AGENTS / 注释) MUST 简洁精炼, 重点突出, 零冗余
- 写法规范 → [llm-doc-style.md](./llm-doc-style.md); 审稿时 MUST 对照"反模式"段
- 能一行不写两行, 能列表不写段落; 宁可信息密度过载, MUST NOT 废话填充
