> 🌐 **语言**: [English →](../02-tool-system.md) | 中文

# 工具系统架构：42 个模块，一个接口

> **源文件**：`Tool.ts` (793 行 —— 接口定义), `tools.ts` (390 行 —— 注册中心), `tools/` (42+ 个目录)

## TL;DR

Claude Code 采取的每一项行动 —— 读取文件、运行 Bash、搜索网络、产生子智能体 —— 都通过一个统一的 `Tool` 接口。42 个以上的工具模块，每个都自包含在自己的目录中，并在启动时通过一套分层的过滤系统进行装配：功能开关 → 权限规则 → 模式限制 → 拒绝列表。

---

## 1. 工具接口：30+ 个方法，一份契约

Claude Code 中的每个工具都实现相同的 `Tool<Input, Output, Progress>` 类型。这是一个拥有 793 行定义的庞大接口，涵盖了：
- **标识 (Identity)**：名称、别名、搜索提示。
- **模式 (Schema)**：基于 Zod v4 的输入输出校验。
- **核心执行 (Execution)**：包含 `call()` 方法。
- **权限流水线 (Permission)**：输入验证、权限检查等。
- **行为标志 (Behavioral Flags)**：是否只读、并发安全、破坏性等。
- **UI 渲染 (UI Rendering)**：使用 React + Ink 渲染工具的使用、进度和结果消息。

### buildTool() 工厂模式
为了避免每个工具都必须手动实现 30 多个方法，Claude Code 使用了一个带有“失败即关闭（fail-closed）”默认值的工厂函数：
- `isConcurrencySafe` 默认为 `false`（串行执行）。
- `isReadOnly` 默认为 `false`（写操作，需要权限）。
- 这种防御性设计确保了如果开发者忘记声明某个属性，系统会选择最安全的行为。

---

## 2. 工具注册中心：静态数组与动态过滤

所有工具都在 `tools.ts` 中通过 `getAllBaseTools()` 注册。它返回一个扁平的数组 —— **不是**插件注册表，也不是复杂的索引，这种设计意在保持极简。

### 功能门控 (Feature-Gated) 工具
许多工具只有在特定的构建标志（Feature Flags）开启时才会出现：
- **ALWAYS**: BashTool, FileReadTool, AgentTool, WebSearchTool 等。
- **GATED**: 
  - `PROACTIVE` → SleepTool 
  - `AGENT_TRIGGERS` → Cron 相关工具
  - `COORDINATOR_MODE` → 协调模式相关工具
  - `WEB_BROWSER_TOOL` → 浏览器自动化工具
- **ENV-GATED**: `USER_TYPE=ant` 专属的 REPLTool, ConfigTool 等。

**编译时优化**：通过 `bun:bundle` 编译标志，未开启的功能代码会在构建阶段被物理剔除，从而减小二进制体积。

---

## 3. 工具分类

这 42+ 个工具主要分为 6 大功能类别：

1. **文件操作 (7 个工具)**：Read, Write, Edit, Glob, Grep, NotebookEdit, Snip。
2. **执行指令 (3-4 个工具)**：Bash, PowerShell, REPL, Sleep。
3. **智能体管理 (6 个工具)**：AgentTool, SendMessage, TaskStop, TeamCreate 等。
4. **外部集成 (5+ 个工具)**：WebFetch, WebSearch, WebBrowser, MCP 相关资源读取, LSP。
5. **工作流与计划 (8+ 个工具)**：PlanMode, Worktree, SkillTool, Task (Todo v2) 等。
6. **通知与监控 (4 个工具)**：MonitorTool, PushNotification 等。

---

## 4. 装配流水线 (Assembly Pipeline)

工具并不是直接从注册中心进入 LLM。它们会经过多级过滤流水线：
1. **拒绝规则过滤**：移除被明确禁用的工具。
2. **运行时检查**：调用 `isEnabled()`。
3. **模式过滤**：
   - **Simple 模式**：仅保留核心的 Bash 和文件读写工具。
   - **REPL 模式**：隐藏部分被 VM 封装的底层工具。
4. **MCP 工具合并**：将来自外部协议的工具与内置工具合并。

**缓存稳定性**：内置工具作为前缀并按名称排序，MCP 工具紧随其后。这种排序方式保证了即使添加或删除 MCP 工具，内置工具的 Prompt 缓存依然保持稳定，节省 API 成本。

---

## 5. 工具搜索：大工具集的延迟加载

当可用工具过多时（如 MCP 加载了数十个工具），`ToolSearchTool` 开启了延迟加载机制。模型通过关键词匹配发现工具，而不是在初始 Prompt 中加载全量定义，避免了上下文溢出。

---

## 6. 目录规范

每个工具都遵循一致的目录结构：
```
tools/BashTool/
├── BashTool.ts      # 实现逻辑 (buildTool({ ... }))
├── prompt.ts        # 面向 LLM 的描述文本
├── UI.tsx           # React+Ink 渲染组件
├── constants.ts     # 常量（如名称、限制）
└── utils.ts         # 辅助函数
```
对于像 `AgentTool` 这样的大型工具，结构会更复杂，包含内存管理、Worker 调度等独立模块。

---

## 7. 值得借鉴的设计模式

### 模式 1：行为标志优于能力类
不使用复杂的继承体系（如 `ReadOnlyTool` 类），而是使用基于输入的布尔方法标志。例如，`BashTool.isReadOnly()` 会根据命令内容（`ls` vs `rm`）动态返回结果。

### 模式 2：排序顺序决定缓存稳定性
通过确定的排序算法（内置工具顺序在前），确保了大规模部署下的显著 API 成本节约。

### 模式 3：完全自包含的模块化
每个工具目录包含一切：实现、Prompt、UI 和测试。工具之间互不交叉，保证了独立的可测试性和可维护性。

---

## 总结

| 维度 | 细节 |
|--------|--------|
| **接口定义** | 单一 `Tool` 类型，30+ 方法，高内聚性 |
| **注册机制** | 扁平数组，极简设计，无复杂容器 |
| **装配规则** | 3 层过滤：构建标志、环境变量、运行时上下文 |
| **模式校验** | 强制 Zod 校验，运行时安全保证 |
| **默认倾向** | “失败即关闭”工厂设计，默认最严权限 |
