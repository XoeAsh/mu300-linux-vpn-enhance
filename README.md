# mu300-linux-vpn-enhance

<img width="426" height="256" alt="sc_zh" src="https://github.com/user-attachments/assets/cf0cbb02-0429-49a5-bb1b-2e9e7140578d" />

**简体中文** · [English](README.en.md) · [Türkçe](README.tr.md)

为 MU300 / ZTE F50 的原版 LuCI VPN 页面添加完整配置订阅和节点选择。当前版本为 **0.2.1**，安装基线为原版 `mu300-vpn v2.0.4`。[mu300-linux](https://github.com/dikeckaan/mu300-linux) · [mu300-linux-vpn](https://github.com/dikeckaan/mu300-linux-vpn)

## 功能

- **完整配置订阅。** 支持 sing-box 1.14 JSON、Mihomo YAML 和分享链接。订阅刷新由原版管理，已记录的格式和刷新设置会沿用。
- **本机节点选择。** 在 VPN 概览切换 Mihomo 的 `select` 组或 sing-box 的 `selector` 组，选择按配置和代理组保存。Mihomo 使用 Unix Socket，sing-box 使用带令牌的环回接口。
- **三语界面。** 跟随 LuCI 的简体中文、英语和土耳其语设置，其他语言使用英文文案。

## 版本与验证环境

| 项目 | 基线或验证版本 |
| --- | --- |
| 设备和界面 | MU300 / ZTE F50，原版 mu300-linux LuCI |
| VPN 模块 | mu300-vpn v2.0.4 |
| Mihomo | v1.19.32 |
| sing-box | v1.14.1 |

表中引擎版本是 `mu300-vpn v2.0.4` 的上游构建版本。本增强包使用设备上由原版管理的引擎。在 SSH 中运行 `mu300-vpn engines --json` 可查看设备的实际安装情况。

sing-box 的导入、连接和节点选择已在 F50 上验证。Mihomo 的 Unix Socket 节点读取、切换和重启恢复在 Linux x86_64 上用 v1.19.32 验证，F50 的 Mihomo 路径待实测。

## 安装

以下步骤使用 Windows PowerShell。先通过 USB 或局域网连接设备，准备好 root 登录方式。如果管理地址不同，把命令中的 `192.168.77.1` 换成设备的实际地址。重新安装前，使用已有增强包自带的卸载脚本。

### 1. 下载到电脑

下载 `mu300-linux-vpn-enhance-0.2.1.tar.gz`，保存到 Windows 的 **下载** 文件夹。保留压缩包，稍后在设备上解压。[下载 v0.2.1](https://github.com/xoeash/mu300-linux-vpn-enhance/archive/refs/tags/v0.2.1.tar.gz) · [发布页面](https://github.com/xoeash/mu300-linux-vpn-enhance/releases/tag/v0.2.1)

### 2. 从 Windows 上传，再登录设备

打开 **PowerShell**，逐行执行。等 `scp` 上传完成后，再执行 `ssh` 登录。

```powershell
Set-Location "$env:USERPROFILE\Downloads"
scp -O ".\mu300-linux-vpn-enhance-0.2.1.tar.gz" root@192.168.77.1:/tmp/
ssh root@192.168.77.1
```

出现密码提示时输入设备的 root 密码，输入过程没有字符回显。若出现 SSH 主机密钥提示，先通过可信的设备终端核对指纹。登录后会看到类似 `root@mu300:~#` 的提示符。

### 3. 在设备端解压和安装

在刚打开的 SSH 终端复制下面整段。每一步成功才会继续下一步。

```sh
tar -xzf /tmp/mu300-linux-vpn-enhance-0.2.1.tar.gz -C /tmp &&
cd /tmp/mu300-linux-vpn-enhance-0.2.1 &&
sh install.sh &&
sh audit.sh
```

看到 `Installed version: 0.2.1` 后，在浏览器重新打开 LuCI 的 VPN 页面。节点控制接口会在 VPN 下次启动时生效。安装器会先检查原版文件结构，遇到不兼容的版本会在修改系统文件前退出。

## 使用

### 订阅

在 **VPN → 订阅 → 添加** 输入订阅链接。新建的 **自动识别** 依次尝试 sing-box JSON、Mihomo YAML 和分享链接，实际格式取决于服务商返回的内容。已有订阅继续按已识别的格式刷新。如需为现有分享链接订阅尝试完整配置，请新建一条订阅。

如果服务商提供对应格式的专用链接，可直接选 **完整 sing-box JSON** 或 **完整 Clash/Mihomo YAML**。完整文件导入成一条 VPN 配置，保留其中的节点和策略组。

### 节点选择

启用目标配置后，在 **VPN → 概览 → 代理节点选择** 选择手动组和节点。通过文件导入的完整配置也适用。若面板提示没有手动代理组，请检查 Mihomo 配置是否含 `select` 组，或 sing-box 配置是否含 `selector` 组。

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
