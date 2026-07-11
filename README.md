# CodexMeter

一枚常驻 macOS 的极简 Codex 用量小组件：在桌面上快速查看当前账户的剩余额度、重置时间与当天 token 用量。界面采用 SwiftUI + AppKit，使用系统材质呈现轻量毛玻璃效果，并提供平滑的状态与数值过渡。

> CodexMeter 是社区项目，不是 OpenAI 官方产品。它只在本机运行，但额度数据仍需由本机 Codex 通过 OpenAI 账户服务获取。

## 功能 / Features

- 显示 Codex 当前速率限制、可用比例与重置时间。
- 显示账户服务返回的当天 token 活动汇总。
- 三种窗口模式：
  - **始终置顶**：像小宠物一样悬浮于其他窗口之上。
  - **隐藏**：暂时收起组件，需要时再恢复。
  - **固定桌面**：停留在桌面层，作为低干扰的桌面组件。
- 原生 macOS 毛玻璃、圆角和细腻动效，支持浅色与深色外观。
- 菜单栏常驻；应用采用 `LSUIElement`，不会占用 Dock 空间。
- 本地构建、本地部署；没有自建服务器、广告或遥测。

## 数据从哪里来

CodexMeter 启动本机的 `codex app-server`，通过 stdio 上的 JSON-RPC 与它通信。初始化后主要读取两个官方 app-server 方法：

- `account/rateLimits/read`：账户速率限制、额度窗口与重置时间。
- `account/usage/read`：token 活动汇总与 daily buckets。

登录和 token 刷新由 Codex 自己管理。CodexMeter 不要求你把 API key 粘贴到组件中，也不会复制或保存 Codex 的认证文件。协议说明见 [OpenAI Codex app-server README](https://github.com/openai/codex/blob/main/codex-rs/app-server/README.md)。

## 架构

```text
SwiftUI 视图与动画
        │
AppKit 窗口/菜单栏控制 ── 置顶、隐藏、桌面层
        │
状态模型与定时刷新
        │
本机 codex app-server（JSON-RPC / stdio）
        │
account/rateLimits/read + account/usage/read
```

项目是一个 Swift Package：可执行 target 负责应用生命周期和窗口，`CodexMeterKit` 封装用量模型、app-server 客户端与可测试逻辑。Release 打包脚本将可执行文件、`Info.plist` 和 SwiftPM 编译后的资源 bundle 组装成标准 `.app`。

## 环境要求

- macOS 14 Sonoma 或更高版本。
- Xcode 26 或兼容的 Swift 6.2 工具链。
- 已安装可用的 Codex/ChatGPT 桌面客户端，或当前终端中的 Codex CLI 已登录 ChatGPT 账户。
- 首次读取用量时需要联网；界面和进程均在本机运行。

可先确认命令行登录状态：

```bash
codex login status
```

如果你的 Codex 版本没有该子命令，直接运行 `codex` 并按其提示完成登录即可。

## 构建与测试

```bash
cd ~/CodexMeter
swift test
./Scripts/build-app.sh
```

脚本固定使用 Release 配置。当 `/Applications/Xcode.app/Contents/Developer` 存在时，会将它设为 `DEVELOPER_DIR`；随后在 `~/Applications/CodexMeter.app` 创建本地应用包，并在系统支持时添加 ad-hoc 签名。

若希望把产物放在项目内的 `dist`：

```bash
DIST_DIR="$PWD/dist" ./Scripts/build-app.sh
```

开发模式可直接运行：

```bash
swift run CodexMeter
```

## 本地安装与运行

构建、安装并立即打开：

```bash
./Scripts/install-local.sh
```

只安装，不自动打开：

```bash
./Scripts/install-local.sh --no-open
open "$HOME/Applications/CodexMeter.app"
```

自定义安装目录同样使用 `DIST_DIR`：

```bash
DIST_DIR="$PWD/dist" ./Scripts/install-local.sh
```

更新时重新执行脚本即可；它只替换目标目录中的 `CodexMeter.app`。

## 隐私与安全

- 不包含第三方分析 SDK，不上传界面行为，也不运行项目自有的远程服务。
- 不读取、复制或打包 `.env`、API key、Codex 登录文件等秘密信息。
- app-server 使用你现有的 Codex 登录态向 OpenAI 请求账户用量；因此“本地部署”不等于离线统计。
- UI 只展示接口返回的额度/用量状态。请不要把它当作账单、发票或成本审计工具。
- 构建脚本仅复制 Release 可执行文件、Info.plist 与编译后的 SwiftPM `.bundle`，并尽可能进行本地 ad-hoc 签名。

## 已知限制

- 必须存在已登录且兼容的 Codex/ChatGPT 桌面应用，或当前 CLI 登录态；未登录、凭据过期或网络不可用时无法刷新。
- `account/usage/read` 和字段结构取决于本机 Codex 版本及账户类型；旧版本或部分账户可能不返回当天 token 汇总。
- “剩余额度”通常根据服务返回的使用比例换算，不代表一个固定、可精确扣减的 token 总池。
- “当天”采用账户服务返回的 daily bucket，其时区与结算边界可能和 Mac 本地午夜不同。
- 桌面固定模式使用 AppKit 窗口层级与 Spaces 行为进行模拟，**不是** WidgetKit 小组件扩展；它不会出现在 macOS 的“编辑小组件”图库中。
- 速率限制通知和轮询存在短暂延迟；最终口径以 Codex/OpenAI 账户页面为准。
- app-server 是随 Codex 演进的本地接口，升级 Codex 后若协议发生变化，可能需要同步更新本项目。

## 故障排查

**应用没有出现在 Dock 中**

这是预期行为。`Info.plist` 使用了 `LSUIElement`，CodexMeter 通过菜单栏和自身窗口交互。

**提示找不到 Codex 或一直显示未连接**

确认 Codex CLI 可执行文件位于 `PATH`，或 Codex/ChatGPT 桌面应用已安装并登录。然后退出 CodexMeter 并重新打开。

**Swift 使用了错误的开发者目录**

标准打包脚本会自动选择完整 Xcode。手动运行 Swift 命令时可执行：

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
swift test
```

## 参考资料

- [OpenAI Codex app-server README](https://github.com/openai/codex/blob/main/codex-rs/app-server/README.md)
- [Apple: LSUIElement](https://developer.apple.com/documentation/bundleresources/information-property-list/lsuielement)
- [Apple: NSWindow.Level.floating](https://developer.apple.com/documentation/appkit/nswindow/level-swift.struct/floating)
- [Apple: NSVisualEffectView](https://developer.apple.com/documentation/appkit/nsvisualeffectview)
- [Apple: WidgetKit](https://developer.apple.com/documentation/widgetkit)

## English quick start

CodexMeter is a local, community-built macOS 14+ usage companion for Codex. It reads rate-limit and daily token activity from your logged-in local `codex app-server`; it does not ask for or store your API key.

```bash
cd ~/CodexMeter
swift test
./Scripts/install-local.sh
```

The default bundle is `~/Applications/CodexMeter.app`. Set `DIST_DIR` to choose another destination. Desktop pinning is an AppKit window-level simulation rather than a native WidgetKit extension.

## License

[MIT](LICENSE)
