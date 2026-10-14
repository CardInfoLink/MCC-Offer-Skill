# 兼容环境与脚本约定

## 支持环境

| 环境 | 脚本 | 运行时依赖 |
|---|---|---|
| Linux/macOS | `.sh` | POSIX Shell 和 `curl` |
| Git Bash/WSL | `.sh` | POSIX Shell 和 `curl` |
| Windows PowerShell | `.ps1` | Windows PowerShell 和 `curl.exe` |

本 Skill 不依赖 Python、Node、jq、包管理器或常驻服务。

## 退出码

- `0`：环境或接口调用成功；同步脚本可能返回 `SYNC_STATUS=CHANGED` 或 `SYNC_STATUS=UNCHANGED`。
- `10`：Shell 不受支持，仅环境检测使用。
- `11`：缺少 curl。
- `12`：配置目录不存在或不可写。
- `13`：网络或传输失败；保留本地缓存，后续重新尝试。
- `14`：接口、协议或配置写入失败；保留之前可用的文件。

## 脚本对应关系

| POSIX | PowerShell | 用途 |
|---|---|---|
| `env-check.sh` | `env-check.ps1` | 检查 Shell、curl、配置目录写入能力和可选网络连通性。 |
| `sync-config.sh` | `sync-config.ps1` | 处理新安装、当日首次同步和当天缓存路径。 |
| `api-call.sh` | `api-call.ps1` | 发送调用方组装的请求，并按事件 ID把请求/原始响应写入 `config/data/req/` 和 `config/data/res/`。 |
| `cleanup-data.sh` | `cleanup-data.ps1` | 按事件 ID删除处理完成后的请求/响应临时文件。 |

同步脚本按以下顺序解析服务端七段响应：状态、提示、地区、银行、标签、客户端编号、版本。请求失败时不得覆盖已有字典或本地状态。
