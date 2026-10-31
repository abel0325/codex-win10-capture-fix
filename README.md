# Codex Windows 10 Capture Fix

[English](README.en.md) · 实验性、可回退、精确 SHA-256 匹配

用于修复特定 Windows 10 / Codex Computer Use 组件中“能识别窗口，但截图报 `FrameArrived timed out` 或 `window capture timed out`”的问题。

**目前仅支持下表这一份 Sky 0.7.13 原生程序。不是通用修复工具，不是 OpenAI 官方更新。**

| 项目 | 值 |
|---|---|
| 实测系统 | Windows 10 22H2，build 19045 |
| 实测 Desktop | 26.1027.3384.0 |
| Sky | 0.7.13 |
| 原件 SHA-256 | `49C7F43DA0C2A9DBCADFB0C993058147018BF7C1D0FDE4360DE11ACE2C98F45D` |
| 补丁后 SHA-256 | `25A8CD31B5BC44C387CBF53EC3FE4CD314B5FCAC0D8D84201F444F1B2DB10FAB` |

## 实测结果

修复前，空白记事本截图在约 5.3 秒后超时。修复后，前置记事本截图 108ms；动态测试窗口连续 10 次截图成功，83–116ms；重新创建截图进程后截图 202ms。动态画面的帧号与时钟确实改变。

**遮挡窗口有已知限制**：后台记事本曾返回遮挡它的画面，因此请前置目标窗口并目视确认。没有验证输入操作、Windows 重启、睡眠恢复或长期稳定性。详见 [验证记录](docs/VALIDATION.md)。

## 使用

需要 Windows PowerShell 5.1（`powershell.exe`，随 Windows 提供）。本工具不需要管理员权限，不修改 Codex 配置或网络代理。首次构建、安装或回退需从 GitHub 下载固定版本依赖；下载后校验完整 SHA-256，并缓存在 `%LOCALAPPDATA%\CodexWin10CaptureFix`。默认检查不联网。

下载本仓库 ZIP 并解压，在项目目录执行：

```powershell
# 1. 只读检查：应显示 original-patchable 或 patched
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Fix-Capture.ps1

# 2. 安装；先关闭其他正在运行的 Computer Use 任务
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Fix-Capture.ps1 -Action Install

# 3. 需要时回退
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Fix-Capture.ps1 -Action Rollback
```

若发现多份 runtime，工具会停止，使用 `-HelperPath "完整路径"` 明确选择。不要选择 `WindowsApps` 中的原始安装包。遇到 `unsupported` 就停止；不要改掉校验条件，版本号相同并不表示文件相同。

安装会结束所选路径的截图 helper 进程；请通过正常 Computer Use 工具重新建立会话。它不启动 helper EXE、不使用私有协议、不自动测试或操作任何业务窗口。

原件备份保存在 `%USERPROFILE%\.codex\backups\computer-use-helper\<desktop>-sky-0.7.13-49C7F43D\codex-computer-use.exe.original`，回退前再次校验。补丁会使原厂数字签名失效，Codex 后续更新可能覆盖修改；更新后重新检查，不对未知新版强行应用。

## 原理与来源

参考项目 [codex-windows-fast-patch-skill](https://github.com/chen0416ccc-cpu/codex-windows-fast-patch-skill) 的线程修复方案：让 `FrameArrived` 回调尽快返回，把图像处理交给独立 MTA 工作线程，并维护委托引用和 Windows x64 异常展开记录。

本项目提供独立编写的安装适配层、精确文件配置、测试和文档。**补丁引擎来自原作者，不是本项目原创。** 上游未声明许可证，本仓库不重新分发其脚本或机器码，不给上游代码重新授予 MIT 许可。安装时仅从原始来源下载固定提交、核验内容后在本地适配。来源、贡献与许可边界见 [NOTICE](NOTICE.md)。

本机的静态分析和截图结果支持此修复有效；并未动态证明每一台出现相同错误的电脑都存在同一种死锁。上游 worker 的初始化失败和超时取消路径也未完整验收。

## 开发与测试

不含原厂或修改后的 EXE，不自动下载原厂程序。用自己保留的精确原件运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Test-Fix.ps1 -OriginalPath "你的原件备份完整路径"

# 仅离线构建候选文件，不修改运行中的 helper；输出必须不存在
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Fix-Capture.ps1 -Action Build -OriginalPath "原件备份路径" -OutputPath "候选文件路径.exe"
```

测试只处理临时副本，检查候选哈希、原件不变、安装、重复安装、备份、回退及未知输入拒绝。文件测试通过不等于真实截图通过。运行时验收应使用自己的空白测试窗口，不使用私人聊天或业务资料。

反馈请只提供系统版本、完整 helper 哈希、错误文字及脱敏测试结果；不要上传 EXE、密码、Token、Cookie 或私人截图。
