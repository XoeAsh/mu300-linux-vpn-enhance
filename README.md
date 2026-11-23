# mu300-linux-vpn-enhance

面向 MU300 / ZTE F50 的功能补丁，提供 Mihomo 和 sing-box 节点控制。需要原版 [mu300-linux](https://github.com/dikeckaan/mu300-linux) 的 LuCI VPN 页面和 [mu300-linux-vpn](https://github.com/dikeckaan/mu300-linux-vpn) 模块。安装器以 VPN 模块 2.0.4 的源码结构为基准，检测到不兼容的页面或脚本时会在修改系统文件前退出。

## 功能

- **节点选择**。在 VPN 概览选择 Mihomo 的 `select` 组或 sing-box 的 `selector` 组。切换立即生效，选择按配置和代理组保存。
- **原生订阅**。新建自动订阅依次尝试 sing-box JSON、Mihomo YAML 和普通分享链接。您也可以指定完整 JSON 或 YAML。已有订阅按已记录的格式刷新，内容相同的完整配置跳过重启。
- **本地控制**。Mihomo 使用 Unix Socket。sing-box 的控制接口绑定本机环回地址，并使用每次启动生成的令牌。LuCI RPC 提供读取状态和切换节点。
- **三语界面**。新增界面随 LuCI 的语言设置使用简体中文、英语或土耳其语。其他语言下，新增文案使用英语。原版界面继续使用系统翻译。

## 安装

从 GitHub 预发行版下载安装包并解压，将整个目录传到设备。以原版系统为安装基线，在 SSH 终端进入该目录，以 root 执行以下命令。

```sh
sh install.sh
sh audit.sh
```

安装会重载 cron、rpcd 和 uhttpd 管理服务，并保留已有定时任务。节点控制接口在 VPN 下次启动时生效。

## 测试订阅和节点选择

1. 在 **VPN → 订阅** 新建一条自动订阅。若服务商提供直出 sing-box 1.14 JSON 的链接，可选 **完整 sing-box JSON** 来单独测试。
2. 导入成功后查看格式和配置数。完整 sing-box JSON 应导入为一条配置，包含供应商文件中的节点和策略组。服务端根据链接或客户端标识决定返回哪种格式。
3. 在方便切换 VPN 时启用这条配置，打开 **VPN → 概览**，在 **代理节点选择** 里切换一个 `selector` 组的节点。再次启动该配置后可核对保存的节点。

已通过文件导入的 sing-box 1.14 JSON 也可以直接用于测试节点选择。

在 LuCI 的 **系统 → 系统 → 语言和样式** 选择语言，保存设置并重新打开 VPN 概览。节点名和代理组名来自配置，按原名称显示。

## 检查与回滚

`sh audit.sh` 显示安装状态、菜单路由、订阅数量、本地控制状态与文件校验结果。分享输出时请勿附上订阅令牌。

若安装中断或需要卸载，使用本次安装备份中的脚本恢复原版文件。

```sh
sh /root/mu300-linux-vpn-enhance-backup/uninstall.sh
```

若回滚中断，重新执行同一条命令即可。安装成功后手动修改过的文件会触发校验保护，可以核对差异后加 `--force` 回滚。VPN 配置、订阅和节点偏好会保留。还原后的原版订阅需要增强包才能继续刷新 sing-box JSON，已导入的 sing-box 配置仍可使用。

## 开发

在开发机运行 `sh tests/run.sh` 可检查订阅格式回退、补丁、翻译和安装回滚。测试使用临时设备目录。

英语是源语言。简体中文和土耳其语的翻译源文件在 `i18n/`，使用 LuCI 的 `po2lmo` 编译运行时词库。

```sh
po2lmo i18n/zh-cn.po i18n/mu300-vpn-enhance.zh-cn.lmo
po2lmo i18n/tr.po i18n/mu300-vpn-enhance.tr.lmo
```
