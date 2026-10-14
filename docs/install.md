# 安装与激活

1. 将仓库根目录作为 Skill 包安装到平台规定的 Skill 目录，不要只复制 `sub-skills/` 或 `scripts/`。
2. 保留随版本发布的 `scripts/` 和 `sub-skills/`；运行时不会从服务端下载或覆盖它们。
3. 首次同步时通过 `--base-url`/`-BaseUrl`、`OFFER_SKILL_BASE_URL` 或 `config/client.conf` 中的 `API_BASE_URL` 提供服务端地址。
4. 执行与宿主环境匹配的环境检测，再执行同步脚本。每次 Skill 激活由同步脚本自己判断是否需要访问服务端。
5. 如果同步因网络失败返回 `UNCHANGED`，继续使用本地字典；如果本地也没有可用数据，应说明数据服务不可用，不要编造 Offer。
6. 业务接口调用后，根据脚本输出的 `REQUEST_FILE` 和 `RESPONSE_FILE` 读取 `config/data/req/`、`config/data/res/` 中的原始请求/响应，不要依赖窗口中是否保留了正文。
7. 完成响应解析、上下文保存和用户回复后，调用 `cleanup-data.sh` 或 `cleanup-data.ps1` 清理本次事件文件。

`config/client.conf` 随 Skill 默认提供，服务端地址和客户端状态首次为空，首次成功同步后由脚本回写。不要在仓库或同步文本中放入 API 密钥、Cookie、Bearer Token 或个人信息。
