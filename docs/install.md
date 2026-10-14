# 安装与激活

1. 将仓库根目录作为 Skill 包安装到平台规定的 Skill 目录，不要只复制 `sub-skills/` 或 `scripts/`。
2. 保留随版本发布的 `scripts/` 和 `sub-skills/`；运行时不会从服务端下载或覆盖它们。
3. 首次同步时通过 `--base-url`/`-BaseUrl`、`OFFER_SKILL_BASE_URL` 或 `config/client.conf` 中的 `API_BASE_URL` 提供服务端地址。
4. 运行与宿主环境匹配的 `init`（环境检查 + 配置同步合成一步），只看输出里的 `READY`。同一天已同步过的客户端不会再联网。
5. **首次安装必须同步成功**：`init` 返回 `READY=NO`（`FIRST_SYNC_FAILED`）时停止，不发业务请求，向用户说明初始化需要联网、请稍后重试；失败不会记成“今天已同步”，下次调用继续重试。已安装的客户端同步失败不阻断，沿用本地字典；本地字典缺失（`DICT_MISSING`）同样停止，不要编造 Offer。
6. 业务接口调用后，根据脚本输出的 `RESPONSE_FILE` 读取 `config/data/res/` 中的原始响应（`REQUEST_FILE` 仅用于复盘），不要依赖窗口中是否保留了正文。
7. 完成响应解析、上下文保存和用户回复后，调用 `clean.sh` 或 `clean.ps1` 清理本次请求的临时文件。

`config/client.conf` 随 Skill 默认提供，服务端地址和客户端状态首次为空，首次成功同步后由脚本回写。不要在仓库或同步文本中放入 API 密钥、Cookie、Bearer Token 或个人信息。
