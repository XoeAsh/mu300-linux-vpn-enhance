# mu300-linux-vpn-enhance

面向 MU300 / ZTE F50 的功能补丁，提供 Mihomo 和 sing-box 节点控制。需要原版 [mu300-linux](https://github.com/dikeckaan/mu300-linux) 的 LuCI VPN 页面和 [mu300-linux-vpn](https://github.com/dikeckaan/mu300-linux-vpn) 模块。安装器以 VPN 模块 2.0.4 的源码结构为基准，检测到不兼容的页面或脚本时会在修改系统文件前退出。

## 功能

- **节点选择**。在 VPN 概览选择 Mihomo 的 `select` 组或 sing-box 的 `selector` 组。切换立即生效，选择按配置和代理组保存。
- **原生订阅**。新建自动订阅依次尝试 sing-box JSON、Mihomo YAML 和普通分享链接。您也可以指定完整 JSON 或 YAML。已有订阅按已记录的格式刷新，内容相同的完整配置跳过重启。
- **刷新入口**。订阅的手动刷新和自动刷新均由原版订阅管理负责，沿用各条订阅的刷新设置。
- **本地控制**。Mihomo 使用 Unix Socket。sing-box 的控制接口绑定本机环回地址，并使用每次启动生成的令牌。LuCI RPC 提供读取状态和切换节点。
- **三语界面**。新增界面随 LuCI 的语言设置使用简体中文、英语或土耳其语。其他语言下，新增文案使用英语。原版界面继续使用系统翻译。

## 安装测试版

以下步骤以 Windows PowerShell、设备地址 `192.168.77.1` 和原版 VPN 模块 `v2.0.4` 为例。电脑应能通过 USB 或局域网访问设备。若设备地址不同，把两条连接命令中的地址替换为实际地址。若设备上已有增强包，先运行该安装自带的卸载脚本。

### 1. 下载到电脑

下载 `mu300-linux-vpn-enhance-0.2.1-test.3.tar.gz`，保存到 Windows 的 **下载** 文件夹。保留压缩包，稍后在设备上解压。[下载测试版](https://github.com/xoeash/mu300-linux-vpn-enhance/archive/refs/tags/v0.2.1-test.3.tar.gz)

### 2. 从 Windows 上传，再登录设备

打开 **PowerShell**，逐行执行。前两行进入下载目录并把文件复制到设备的 `/tmp`。复制完成后，第三行打开设备的 SSH 终端。

```powershell
Set-Location "$env:USERPROFILE\Downloads"
scp -O ".\mu300-linux-vpn-enhance-0.2.1-test.3.tar.gz" root@192.168.77.1:/tmp/
ssh root@192.168.77.1
```

出现密码提示时输入设备的 root 密码。输入过程没有字符回显，输完按 Enter 即可。登录成功后会看到类似 `root@mu300:~#` 的提示符。若遇到 SSH 主机密钥提示，先通过可信的设备终端核对指纹，再接受新密钥。

### 3. 在设备端解压和安装

在刚打开的 SSH 终端复制下面整段。每一步成功才会继续下一步。

```sh
tar -xzf /tmp/mu300-linux-vpn-enhance-0.2.1-test.3.tar.gz -C /tmp &&
cd /tmp/mu300-linux-vpn-enhance-0.2.1-test.3 &&
sh install.sh &&
sh audit.sh
```

看到 `Installed version: 0.2.1` 后，重新打开 LuCI 的 VPN 页面。安装会重载 LuCI 的管理服务，节点控制接口在 VPN 下次启动时生效。

## 测试订阅和节点选择

1. 在 **VPN → 订阅** 新建一条自动订阅。若服务商提供直出 sing-box 1.14 JSON 的链接，可选 **完整 sing-box JSON** 来单独测试。
2. 导入成功后查看格式和配置数。完整 sing-box JSON 应导入为一条配置，包含供应商文件中的节点和策略组。服务端根据链接或客户端标识决定返回哪种格式。
3. 在方便切换 VPN 时启用这条配置，打开 **VPN → 概览**，在 **代理节点选择** 里切换一个 `selector` 组的节点。再次启动该配置后可核对保存的节点。

已通过文件导入的 sing-box 1.14 JSON 也可以直接用于测试节点选择。

在 LuCI 的 **系统 → 系统 → 语言和样式** 选择语言，保存设置并重新打开 VPN 概览。节点名和代理组名来自配置，按原名称显示。

## 检查与卸载

`sh audit.sh` 显示安装状态、菜单路由、订阅数量、本地控制状态与文件校验结果。分享输出时请勿附上订阅令牌。

如果当前启用了增强版节点控制，请先在能访问 LuCI 的本地连接上停止 VPN。然后通过 SSH 执行卸载。

```sh
sh /root/.mu300-linux-vpn-enhance/uninstall.sh
```

卸载会还原本次安装替换的原版文件，并清除增强包的界面、词库、节点偏好、运行文件和安装记录。原版 VPN 配置及订阅会保留，已导入的 sing-box 配置仍可使用。若脚本发现原版文件在安装后有其它修改，会指出文件并暂停卸载。若卸载中断，可以重新执行同一条命令。

上传的压缩包和解压目录位于 `/tmp`，设备重启时会清空。

## 开发

在开发机运行 `sh tests/run.sh` 可检查订阅格式回退、补丁、翻译及安装和卸载。测试使用临时设备目录。

英语是源语言。简体中文和土耳其语的翻译源文件在 `i18n/`，使用 LuCI 的 `po2lmo` 编译运行时词库。

```sh
po2lmo i18n/zh-cn.po i18n/mu300-vpn-enhance.zh-cn.lmo
po2lmo i18n/tr.po i18n/mu300-vpn-enhance.tr.lmo
```
