# 兼容环境与脚本约定

## 支持环境

| 环境 | 脚本 | 运行时依赖 |
|---|---|---|
| Linux/macOS | `.sh` | POSIX Shell 和 `curl` |
| Git Bash/WSL | `.sh` | POSIX Shell 和 `curl` |
| Windows PowerShell | `.ps1` | Windows PowerShell 和 `curl.exe` |

本 Skill 不依赖 Python、Node、jq、包管理器或常驻服务。

## 退出码

- `0`：成功；`init` 可能带 `SYNC_STATUS=CHANGED` 或 `UNCHANGED`。
- `10`：Shell 不受支持（仅 `init`）。
- `11`：缺少 curl（仅 `init`）。
- `12`：配置目录不存在或不可写（仅 `init`）。
- `13`：网络或传输失败；保留本地缓存，后续重新尝试。
- `14`：接口、协议或配置写入失败，或字典缺失；保留之前可用的文件。

## 脚本对应关系

| POSIX | PowerShell | 用途 |
|---|---|---|
只有三个脚本：

| POSIX | PowerShell | 用途 |
|---|---|---|
| `init.sh` | `init.ps1` | 启动入口，会话开始运行一次：环境检查（Shell、curl、配置目录可写）+ 配置同步（脚本内的函数），输出 `READY=YES/NO`。同步不留请求/响应文件；首次安装不走“同日跳过”、失败不记今天；单次 10 秒、只试 1 次。 |
| `call.sh` | `call.ps1` | 发送调用方组装的业务请求，并按请求 ID 把请求/原始响应写入 `config/data/req/` 和 `config/data/res/`；自动带请求头 `X-Skill-Client-Id`（取自 `client.conf` 的 `LOCAL_CLIENT_ID`，24 位十六进制才带），服务端据此做埋点统计和转发链接的 `?client=`。 |
| `clean.sh` | `clean.ps1` | 按请求 ID 删除处理完成后的请求/响应临时文件。 |

`init` 的退出码：环境失败 10~12；首次安装同步失败 13（网络）/14（接口）；字典缺失 14；其他 0。`call` 的退出码：HTTP 2xx 为 0，网络或传输失败 13，HTTP 非 2xx 或参数错误 14。

`init` 按以下顺序解析服务端七段响应：状态、提示、地区、银行、标签、客户端编号、版本。请求失败时不得覆盖已有字典或本地状态。
