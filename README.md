# mu300-linux-vpn-enhance

面向 MU300 / ZTE F50 的功能补丁，提供独立的 Mihomo 控制模块。需要原版 [mu300-linux](https://github.com/dikeckaan/mu300-linux) 的 LuCI VPN 页面和 [mu300-linux-vpn](https://github.com/dikeckaan/mu300-linux-vpn) 模块。安装器以 VPN 模块 2.0.4 的源码结构为基准，检测到不兼容的页面或脚本时会在修改系统文件前退出。

## 功能

- **节点选择**。在 VPN 概览中选择当前 Mihomo 配置的手动代理组和节点。节点切换立即生效，选择按配置和代理组保存。VPN 离线时仍可查看状态。
- **原生订阅**。自动识别优先请求完整 Mihomo YAML，分享链接订阅继续按原格式刷新。YAML 内容相同时跳过重启，导入失败时向调用方返回错误。
- **本地控制**。Mihomo 通过 Unix Socket 提供控制接口。LuCI RPC 仅提供读取状态和切换节点。
- **三语界面**。新增界面随 LuCI 的语言设置使用简体中文、英语或土耳其语。其他语言下，新增文案使用英语。原版界面继续使用系统翻译。

## 安装

从 GitHub 下载源码并解压，将整个目录传到设备。在设备的 SSH 终端中进入该目录，以 root 执行以下命令。

```sh
sh install.sh
sh audit.sh
```

安装会重载 cron、rpcd 和 uhttpd 管理服务，并保留已有定时任务。Mihomo 的 Unix Socket 在 VPN 下次启动时生效。

在 LuCI 的 **系统 → 系统 → 语言和样式** 选择语言，保存设置并重新打开 VPN 概览。节点名和代理组名来自配置，按原名称显示。

## 检查与回滚

`sh audit.sh` 显示安装状态、菜单路由、订阅数量、本地控制状态与文件校验结果。分享输出时请勿附上订阅令牌。

若安装中断或需要卸载，使用本次安装备份中的脚本恢复原版文件。

```sh
sh /root/mu300-linux-vpn-enhance-backup/uninstall.sh
```

若回滚中断，重新执行同一条命令即可。安装成功后手动修改过的文件会触发校验保护，可以核对差异后加 `--force` 回滚。VPN 配置、订阅和节点偏好会保留。

## 开发

在开发机运行 `sh tests/run.sh` 可检查补丁、翻译和安装回滚。测试使用临时设备目录。

英语是源语言。简体中文和土耳其语的翻译源文件在 `i18n/`，使用 LuCI 的 `po2lmo` 编译运行时词库。

```sh
po2lmo i18n/zh-cn.po i18n/mu300-vpn-enhance.zh-cn.lmo
po2lmo i18n/tr.po i18n/mu300-vpn-enhance.tr.lmo
```
