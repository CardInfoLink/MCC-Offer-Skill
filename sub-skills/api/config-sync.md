# 配置同步接口

## 作用

同步 `config/` 下的纯数据和本地客户端状态。该接口不下发 `sub-skills/`、`scripts/` 或 AI 提示词。

## 调用

- Method: `POST`
- Path: `/api/offer/config`
- 脚本：`scripts/sync-config.sh` 或 `scripts/sync-config.ps1`

POSIX：

```sh
REQUEST_ID="config-$(date +%Y%m%d%H%M%S)-$$"
sh scripts/sync-config.sh \
  --config-dir config \
  --base-url "$API_BASE_URL" \
  --request-id "$REQUEST_ID"
```

PowerShell：

```powershell
$requestId = 'config-' + (Get-Date).ToString('yyyyMMddHHmmss') + '-' + $PID
& .\scripts\sync-config.ps1 `
  -ConfigDir .\config `
  -BaseUrl $apiBaseUrl `
  -RequestId $requestId
```

同步脚本会在标准输出返回 `SYNC_REQUEST_ID` 和 `SYNC_RESPONSE_FILE`。AI 应根据响应文件路径读取服务端原始七段响应；日常激活不需要 AI 自己判断是否联网，脚本根据 `LOCAL_LAST_SYNC_DATE` 自己决定是否请求服务端。

## 请求

```json
{
  "clientId": "",
  "configVersion": ""
}
```

- 新安装两个字段都为空；服务端签发新的 client ID。
- 已安装客户端带上 `LOCAL_CLIENT_ID` 和 `LOCAL_CONFIG_VERSION`。
- `LOCAL_LAST_SYNC_DATE` 只由脚本本地判断，不发送给服务端。

## 七段响应

响应为纯文本，使用 `=.==.=` 分隔，固定 7 段：

1. 状态码：`S000000` 或 `F000000`
2. 提示或错误说明
3. `regions.txt` 全量内容
4. `banks.txt` 全量内容
5. `tags.txt` 全量内容
6. client ID
7. 最新版本号

成功且某一内容为 `无` 时，保留对应本地文件；失败时所有本地文件保持不变。

## 本地落盘规则

- 只允许替换 `config/regions.txt`、`config/banks.txt`、`config/tags.txt`。
- 只允许更新 `client.conf` 中的 `LOCAL_*` 状态和显式传入的 API origin。
- 使用临时文件替换，不能先清空旧文件。
- 同步成功后向上层返回 `SYNC_STATUS=CHANGED` 或 `SYNC_STATUS=UNCHANGED`。
