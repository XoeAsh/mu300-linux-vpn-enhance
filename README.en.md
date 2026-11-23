# mu300-linux-vpn-enhance

<img width="607" height="386" alt="Screenshot of the LuCI VPN interface" src="https://github.com/user-attachments/assets/879cf902-01f0-48b1-ba88-15be7fb3b4a5" />

[简体中文](README.md) · **English** · [Türkçe](README.tr.md)

> Translated by ChatGPT. This translation has not been proofread.

Adds subscriptions that import complete configurations and node selection to the stock LuCI VPN pages on MU300 / ZTE F50 devices. Version **0.2.1** targets stock `mu300-vpn v2.0.4`. [mu300-linux](https://github.com/dikeckaan/mu300-linux) · [mu300-linux-vpn](https://github.com/dikeckaan/mu300-linux-vpn)

## Features

- **Full configuration subscriptions.** Supports sing-box 1.14 JSON, Mihomo YAML, and share links. The stock subscription manager handles refreshes using the saved format and refresh settings.
- **Local node selection.** Switch nodes in Mihomo `select` groups or sing-box `selector` groups from the VPN Overview. Selections are saved per profile and proxy group. Mihomo uses a Unix socket, and sing-box uses a token-authenticated loopback interface.
- **Three interface languages.** Follows the LuCI language settings for Simplified Chinese, English, and Turkish. The added controls use English for other language settings.

## Versions and test environment

| Component | Baseline or tested version |
| --- | --- |
| Device and interface | MU300 / ZTE F50, stock mu300-linux LuCI |
| VPN module | mu300-vpn v2.0.4 |
| Mihomo | v1.19.32 |
| sing-box | v1.14.1 |

The table lists the engine versions used in upstream `mu300-vpn v2.0.4` builds. This enhancement uses the engines managed by the stock firmware. Run `mu300-vpn engines --json` over SSH to see what your device has installed.

sing-box import, connection, and node selection have been tested on the F50. Mihomo v1.19.32 was tested on Linux x86_64 for reading and switching nodes over its Unix socket and restoring the saved selection after restart. Mihomo testing on the F50 is still pending.

## Installation

These steps use Windows PowerShell. Connect to the device via USB or your local network and have root access ready. Replace `192.168.77.1` in the commands if your device uses a different management address. Before reinstalling, run the uninstaller provided by your current installation.

### 1. Download the archive

Save `mu300-linux-vpn-enhance-0.2.1.tar.gz` in your Windows **Downloads** folder. Leave it compressed so you can extract it on the device. [Download v0.2.1](https://github.com/xoeash/mu300-linux-vpn-enhance/archive/refs/tags/v0.2.1.tar.gz) · [Release page](https://github.com/xoeash/mu300-linux-vpn-enhance/releases/tag/v0.2.1)

### 2. Upload from Windows and log in

Open **PowerShell** and run the commands one at a time. Wait for `scp` to finish uploading before you log in with `ssh`.

```powershell
Set-Location "$env:USERPROFILE\Downloads"
scp -O ".\mu300-linux-vpn-enhance-0.2.1.tar.gz" root@192.168.77.1:/tmp/
ssh root@192.168.77.1
```

Enter the device's root password if prompted. The terminal hides the characters as you type. If SSH prompts you about the host key, verify the fingerprint through a trusted device console first. Once you log in, you should see a prompt like `root@mu300:~#`.

### 3. Extract and install on the device

Paste the following block into the SSH terminal. Each command runs after the previous one succeeds.

```sh
tar -xzf /tmp/mu300-linux-vpn-enhance-0.2.1.tar.gz -C /tmp &&
cd /tmp/mu300-linux-vpn-enhance-0.2.1 &&
sh install.sh &&
sh audit.sh
```

Once you see `Installed version: 0.2.1`, reopen the LuCI VPN page in your browser. The node controller takes effect the next time the VPN starts. The installer checks the stock files first and exits before editing system files if it finds an incompatible version.

## Usage

### Subscriptions

Enter your subscription URL under **VPN → Subscriptions → Add**. For new subscriptions, **Detect (prefer full configurations)** tries sing-box JSON first, followed by Mihomo YAML and share links. The format depends on what the provider returns. Existing subscriptions refresh using their detected format. To try a full configuration for an existing share-link subscription, create a new subscription.

If your provider offers a URL for a specific format, choose **Full sing-box JSON** or **Full Clash/Mihomo YAML**. A complete file imports as one VPN profile and keeps its nodes and policy groups.

### Node selection

Activate your profile, then use **VPN → Overview → Proxy node selection** to choose a manual group and node. This also works for complete configurations imported from a file. If the panel reports that the profile has no manual groups, check for a `select` group in Mihomo or a `selector` group in sing-box.

To change the interface language, go to **System → System → Language and Style**, save your selection, and reopen the VPN Overview. Node and proxy group names are displayed as defined in the configuration.

## Checking and uninstalling

`sh audit.sh` reports installation status, menu routes, subscription counts, local control status, and file integrity checks. Remove any subscription tokens before sharing output.

If the enhanced node controller is active, connect locally so you can reach LuCI and stop the VPN. Then run the uninstaller over SSH.

```sh
sh /root/.mu300-linux-vpn-enhance/uninstall.sh
```

Uninstalling restores the stock files replaced during installation and removes the enhancement's interface, translation catalogs, node preferences, runtime files, and installation records. VPN configurations and subscriptions are retained, and imported sing-box profiles remain usable. If the script detects other changes to a stock file after installation, it identifies the file and pauses. If uninstallation is interrupted, run the same command again.

The uploaded archive and extracted directory are stored in `/tmp`, which is cleared when the device reboots.

## Development

Run `sh tests/run.sh` on your development machine to check subscription format fallback, patches, translations, installation, and uninstallation. The tests use a temporary directory to simulate the device.

English is the source language for the LuCI controls. The Simplified Chinese and Turkish translation files are in `i18n/`. Use LuCI's `po2lmo` to compile the runtime catalogs.

```sh
po2lmo i18n/zh-cn.po i18n/mu300-vpn-enhance.zh-cn.lmo
po2lmo i18n/tr.po i18n/mu300-vpn-enhance.tr.lmo
```
