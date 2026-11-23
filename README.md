# mu300-linux-vpn-mihomo-enhance

面向 [dikeckaan/mu300-linux](https://github.com/dikeckaan/mu300-linux) / [mu300-linux-vpn](https://github.com/dikeckaan/mu300-linux-vpn) 的独立增强层，整合历史 v1–v6 补丁，以 **v6 精简 Overview** 为最终交互形态。

> 适用对象：MU300 / ZTE F50 上使用 `mu300-vpn` 的 LuCI 管理系统。基于已经验证过的 MU300 VPN 2.0.4 系列源码锚点。上游更新后若源码结构不符，安装程序会拒绝盲目替换；并非适用于所有 OpenWrt 固件。

## 功能

- **原生订阅优先完整 YAML**：原生 VPN → 订阅的「自动识别」和「Mihomo YAML」模式，通过 `ClashMeta/1.19.0` 请求机场订阅；返回有效完整 YAML 时创建一份 Mihomo 配置，而不是拆成数个独立节点。机场仍然返回分享链接时，`auto` 继续使用分享链接模式。既有已记录为 links 的 auto 订阅继续按原方式刷新，防止数据迁移时删除节点。
- **沿用系统原生定时更新**：每条订阅独立设置间隔，`subscription refresh --due` 定期检查；相同 Mihomo YAML 不重复重启隧道，导入/校验失败不会假报成功。
- **Overview 节点选择**：自动识别当前 Mihomo 配置中的 `Selector`（即 YAML 的 `select`）策略组，切换立即生效；按配置和策略组分别保存选择。非 Mihomo / VPN 离线时卡片仍存在，但下拉框禁用且说明原因。仅保留「策略组、节点、刷新」和必要提示，**没有**历史「订阅与更新」段落与「当前选择」冗余文字。
- **本地控制接口**：Mihomo 仅开启 `/run/mu300-vpn/mihomo-control.sock` Unix Socket（原系统运行目录 root-only），不另开远程 TCP 管理端口；LuCI RPC 权限只允许 `get`/`set`。
- **旧版更新器退役**：只有在存在成功导入的原生 Mihomo 订阅时，删除旧 `/root/mu300-mihomo-refresh.sh`、它的 cron、专用 URL 和开关文件。没有成功迁移时保留旧逻辑，待迁移完成后用 `cleanup-legacy.sh` 单独清理。
- **中文化**：原 VPN Overview 常用状态和说明文字的中文翻译。

### 不做什么

- 不重置、上传或自动公开机场订阅 URL、YAML、账号令牌、节点私钥。
- 不修改路由表、网口、桥接、kill switch、防火墙或现有活动配置。
- 安装时不启动/停止/重启 VPN；只刷新 cron、rpcd、uhttpd 管理服务。
- **新装驱动补丁需要下次 Mihomo 进程启动才会生效**；安装时不会为此强制重启 VPN。
- 不把 `url-test` / `fallback` 当作手动选择组；仅显示 Mihomo API 中 `type=Selector` 的组。

## 安装

首先备份设备配置，并确保 LAN/USB 管理连接正常，避免在运行中的 VPN 切换时失联。可下载本仓库的打包发行版，并将 `.tar.gz` 文件传到路由器。

Windows PowerShell（路由器缺少 SFTP Server，所以使用 **`scp -O`**）：

```powershell
scp -O "C:\Users\<你的用户名>\Desktop\mu300-linux-vpn-mihomo-enhance-v1.0.0.tar.gz" root@192.168.77.1:/tmp/
```

F50 SSH：

```sh
tar -xzf /tmp/mu300-linux-vpn-mihomo-enhance-v1.0.0.tar.gz -C /tmp/
sh /tmp/mu300-linux-vpn-mihomo-enhance/install.sh
sh /tmp/mu300-linux-vpn-mihomo-enhance/audit.sh
```

若从 GitHub 克隆该仓库，进入仓库目录执行 `sh install.sh` 即可。

**v6 设备升级**：不用卸载 v1–v6。安装器根据当前菜单路由选择当前 Overview，生成独立 `vpn-overview-enhance.js`；原 v4 下载核心检测已存在时不会二次打补丁，原生订阅不会被重复创建。安装成功后对新增订阅和原有 `Mihomo` 配置均继续生效。

**原版设备新装**：安装器对原生 CLI、Mihomo driver、Overview 和订阅页面执行一次精确锚点补丁。如版本不匹配，拒绝继续而不会强行套用。

## 迁移与清理

1. 到 **VPN → 订阅**，添加机场订阅，选择「完整 Clash/Mihomo YAML」或「自动识别」。先确认新条目的格式显示 `mihomo`，配置文件数量 `1`，并验证配置文件与网络正常。
2. 在 **VPN → 配置文件** 选用新的 Mihomo 配置。切换活动配置可能触发 VPN 重启，请确认有可靠的本地管理路径再操作。
3. 若安装时尚未成功导入原生订阅，随后执行 `sh cleanup-legacy.sh`。此脚本会检查已导入 YAML 的原生订阅以及原生 cron，满足条件才删除独立旧脚本。
4. 以后只在 **VPN → 订阅** 管理多个机场和各自的更新周期。

**注意**：新的原生订阅生成新的配置 ID，不会自动把旧 `mihomo` 配置 ID 改成原生订阅。旧本地 YAML/配置文件不会自动删除。

## 检查与恢复

```sh
sh audit.sh
ubus call mu300mselect get '{}'
mu300-vpn subscription list --json | jq '[.[]|{id,name,type,format,count,interval,profiles}]'
```

查看接口或订阅列表不需要透露完整订阅 URL。勿在 issue、公开日志、截图中包含访问令牌。

安装前的 CLI、Mihomo 驱动、LuCI 菜单/页面、RPC/ACL 及 cron 备份位于 `/root/mu300-linux-vpn-mihomo-enhance-backup/`。回滚：

```sh
sh /root/mu300-linux-vpn-mihomo-enhance-backup/uninstall.sh
```

如果管理员之后手动更改了增强包管理的文件，回滚会拒绝覆盖；核对差异后可选择 `--force`。**旧专用订阅 URL 删除后不会恢复**。原生订阅、用户 YAML 和节点选择数据不会因为回滚被删除。已存在的旧历史备份目录不会自动清理。

## 结构

```
install.sh                  # 单次安装；识别上游原版 / 已安装 v1–v6
cleanup-legacy.sh          # 原生订阅已验证后清理独立旧更新器
audit.sh                   # 不泄漏订阅 URL 的只读检查
uninstall.sh               # 恢复安装前文件
assets/                    # v6 最终 UI / selector / RPC / ACL
scripts/                   # 针对原生源码的精确锚点补丁
snippets/                  # 原生订阅 UA、格式检查、更新及 LuCI 文案
tests/run.sh               # 构建机上的语法、锚点及重复补丁保护检查
```

## 兼容性和许可证

此项目是增强/补丁层，不是原版 MU300 固件或 VPN 引擎的分发包。相关上游源码及许可证以其原项目为准；本仓库不包含订阅服务、商业节点或任何用户凭据。新安装后的实时效果需要在目标硬件上验证，尤其是下一次 Mihomo 启动后的 Unix Socket 行为。
