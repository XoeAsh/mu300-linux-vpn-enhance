#!/bin/sh
# Standalone enhancement for the stock MU300 LuCI panel and VPN module.
# No VPN, network, routing or firewall restart. Read README before installing.
set -eu
[ "$(id -u)" = 0 ] || { echo '请使用 root 安装' >&2; exit 1; }
HERE=$(CDPATH= cd "$(dirname "$0")" && pwd)
VERSION=$(cat "$HERE/VERSION")
STATE=/root/.mu300-linux-vpn-enhance
VIEW=/www/luci-static/resources/view/mu300
MOD=/www/luci-static/resources/mu300
MENU=/usr/share/luci/menu.d/luci-app-mu300.json
ACL=/usr/share/rpcd/acl.d/luci-app-mu300-mihomo-select.json
SELECTOR=/usr/libexec/mu300-mihomo-selector
RPC=/usr/libexec/rpcd/mu300mselect
VPN_RPC=/usr/libexec/rpcd/mu300vpn
I18N=/usr/lib/lua/luci/i18n
CAT_ZH=$I18N/mu300-vpn-enhance.zh-cn.lmo
CAT_TR=$I18N/mu300-vpn-enhance.tr.lmo
CLI=$(readlink -f "$(command -v mu300-vpn)")
DRIVER=$(dirname "$CLI")/../lib/vpn/mihomo.sh
SB_DRIVER=$(dirname "$CLI")/../lib/vpn/sing-box.sh
SUB_TARGET=$VIEW/vpn-subscriptions-enhance.js
OV_TARGET=$VIEW/vpn-overview-enhance.js
MOD_TARGET=$MOD/mselect_overview_enhance.js

if [ -d "$STATE" ]; then
    if [ -e "$STATE/uninstall-in-progress" ]; then
        echo "发现未完成的卸载，请重试 sh $STATE/uninstall.sh" >&2; exit 1
    fi
    if [ -r "$STATE/installed-version" ]; then
        INSTALLED=$(cat "$STATE/installed-version")
        if [ "$INSTALLED" = "$VERSION" ]; then
            echo "增强包已安装：$INSTALLED"; exit 0
        fi
        echo "检测到已安装的增强包。请先运行 sh $STATE/uninstall.sh。" >&2; exit 1
    fi
    echo "安装尚未完成。请运行 sh $STATE/uninstall.sh 清除本次安装。" >&2; exit 1
fi
for cmd in jq curl awk sha256sum jsonfilter mktemp; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "缺少依赖：$cmd" >&2; exit 1; }
done
curl -V | grep -q UnixSockets || { echo 'curl 缺少 UnixSockets 支持' >&2; exit 1; }
for f in "$CLI" "$DRIVER" "$SB_DRIVER" "$VPN_RPC" "$MENU" "$VIEW/vpn-overview.js" "$VIEW/vpn-subscriptions.js" \
         "$HERE/i18n/mu300-vpn-enhance.zh-cn.lmo" "$HERE/i18n/mu300-vpn-enhance.tr.lmo"; do
    [ -r "$f" ] || { echo "缺少必要文件：$f" >&2; exit 1; }
done
for f in "$OV_TARGET" "$SUB_TARGET" "$MOD_TARGET" "$ACL" "$SELECTOR" "$RPC" "$CAT_ZH" "$CAT_TR" \
         /run/mu300-vpn/mihomo-control.sock /run/mu300-vpn/sing-box-controlled.json \
         /run/mu300-vpn/sing-box-selector-owner; do
    if [ -e "$f" ] || [ -L "$f" ]; then
        echo "检测到已有文件，将保留现状。请先检查 $f" >&2; exit 1
    fi
done
for f in "$CLI" "$DRIVER" "$SB_DRIVER" "$VPN_RPC" "$MENU"; do
    if [ -L "$f" ]; then
        echo "检测到符号链接，将保留现状。请先检查 $f" >&2; exit 1
    fi
done

umask 077
TMP=$(mktemp -d /tmp/mu300-enhance.XXXXXX)
trap 'rm -rf "$TMP"' EXIT
trap 'exit 1' HUP INT TERM

# 1. Native subscriptions and LuCI input validation.
awk -v base="$HERE/snippets/" -f "$HERE/scripts/patch-native-cli.awk" "$CLI" > "$TMP/cli"
sh -n "$TMP/cli"
awk -f "$HERE/scripts/patch-subscription-rpc.awk" "$VPN_RPC" > "$TMP/vpn-rpc"
sh -n "$TMP/vpn-rpc"

# 2. Local node controllers for Mihomo and sing-box.
awk -f "$HERE/scripts/patch-mihomo-driver.awk" "$DRIVER" > "$TMP/driver"
sh -n "$TMP/driver"
awk -f "$HERE/scripts/patch-sing-box-driver.awk" "$SB_DRIVER" > "$TMP/sb-driver"
sh -n "$TMP/sb-driver"

# 3. Apply the view patches to the stock routes.
jq -e '."admin/vpn/mu300-overview".action.path=="mu300/vpn-overview" and
       ."admin/vpn/mu300-subscriptions".action.path=="mu300/vpn-subscriptions"' "$MENU" >/dev/null || {
    echo '安装需要原版 LuCI VPN 页面。' >&2; exit 1; }
awk -v base="$HERE/snippets/" -f "$HERE/scripts/patch-subscription-view.awk" \
    "$VIEW/vpn-subscriptions.js" > "$TMP/subscriptions.js"
awk -f "$HERE/scripts/patch-stock-overview.awk" "$VIEW/vpn-overview.js" > "$TMP/overview.js"

jq '."admin/vpn/mu300-overview".action.path="mu300/vpn-overview-enhance" |
    ."admin/vpn/mu300-subscriptions".action.path="mu300/vpn-subscriptions-enhance"' \
    "$MENU" > "$TMP/menu.json"
jq -e '."admin/vpn/mu300-overview".action.path=="mu300/vpn-overview-enhance" and
    ."admin/vpn/mu300-subscriptions".action.path=="mu300/vpn-subscriptions-enhance"' \
    "$TMP/menu.json" >/dev/null

# 4. Save the originals privately so uninstall can put them back.
mkdir "$STATE"
_new=
trap '
    [ -z "$_new" ] || rm -f "$_new"
    rm -f "$STATE/installing-pid"
    [ -f "$STATE/uninstall-ready" ] || rm -rf "$STATE"
    rm -rf "$TMP"
' EXIT
printf '%s\n' "$$" > "$STATE/installing-pid"
mkdir "$STATE/files"
: > "$STATE/installed.sha256"
: > "$STATE/originals"
backup() {
    mkdir -p "$STATE/files${1%/*}"
    cp -p "$1" "$STATE/files$1"
    printf '%s\n' "$1" >> "$STATE/originals"
}
for f in "$CLI" "$DRIVER" "$SB_DRIVER" "$VPN_RPC" "$MENU"; do backup "$f"; done
cp "$HERE/uninstall.sh" "$STATE/uninstall.sh"
chmod 700 "$STATE/uninstall.sh"
: > "$STATE/uninstall-ready"

# 5. Install staged files; menu route is changed last.
install_file() {
    _src=$1 _dst=$2 _mode=$3
    mkdir -p "${_dst%/*}"
    _new="$_dst.enhance.$$"
    cp "$_src" "$_new" && chmod "$_mode" "$_new" && mv -f "$_new" "$_dst" || return 1
    _new=
}
install_managed() {
    _original="$STATE/files$2"
    if [ -f "$_original" ]; then
        [ -f "$2" ] && [ ! -L "$2" ] && cmp -s "$2" "$_original"
    else
        [ ! -e "$2" ] && [ ! -L "$2" ]
    fi || { echo "检测到 $2 在准备期间发生变更，该文件已保留。" >&2; exit 1; }
    _sum=$(sha256sum "$1")
    printf '%s  %s\n' "${_sum%% *}" "$2" >> "$STATE/installed.sha256"
    install_file "$@"
}
install_managed "$TMP/cli" "$CLI" 755
install_managed "$TMP/driver" "$DRIVER" 644
install_managed "$TMP/sb-driver" "$SB_DRIVER" 644
install_managed "$TMP/vpn-rpc" "$VPN_RPC" 755
install_managed "$HERE/assets/mu300-mihomo-selector" "$SELECTOR" 700
install_managed "$HERE/assets/mu300mselect" "$RPC" 700
install_managed "$HERE/assets/luci-app-mu300-mihomo-select.json" "$ACL" 644
install_managed "$HERE/assets/mselect_overview_enhance.js" "$MOD_TARGET" 644
install_managed "$HERE/i18n/${CAT_ZH##*/}" "$CAT_ZH" 644
install_managed "$HERE/i18n/${CAT_TR##*/}" "$CAT_TR" 644
install_managed "$TMP/overview.js" "$OV_TARGET" 644
install_managed "$TMP/subscriptions.js" "$SUB_TARGET" 644
install_managed "$TMP/menu.json" "$MENU" 644
mu300-vpn version >/dev/null 2>&1 || echo '警告：mu300-vpn version 命令自检失败；请检查 CLI' >&2
rm -f /tmp/luci-indexcache* /var/luci-indexcache* 2>/dev/null || true
rm -rf /tmp/luci-modulecache /var/luci-modulecache 2>/dev/null || true
[ ! -x /etc/init.d/rpcd ] || /etc/init.d/rpcd restart
[ ! -x /etc/init.d/uhttpd ] || /etc/init.d/uhttpd restart
printf '%s\n' "$VERSION" > "$STATE/installed-version.new"
mv -f "$STATE/installed-version.new" "$STATE/installed-version"
printf '\nmu300-linux-vpn-enhance %s 安装完成。\n' "$VERSION"
echo '原生订阅：支持 sing-box JSON、Mihomo YAML 和分享链接。'
echo 'VPN 概览：支持 Mihomo 和 sing-box 的手动节点选择。'
echo "检查：sh $HERE/audit.sh"
echo "卸载：sh $STATE/uninstall.sh"
