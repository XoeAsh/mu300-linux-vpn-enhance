#!/bin/sh
# Standalone enhancement for the stock MU300 LuCI panel and VPN module.
# No VPN, network, routing or firewall restart. Read README before installing.
set -eu
[ "$(id -u)" = 0 ] || { echo '请使用 root 安装' >&2; exit 1; }
HERE=$(CDPATH= cd "$(dirname "$0")" && pwd)
VERSION=$(cat "$HERE/VERSION")
BACK=/root/mu300-linux-vpn-enhance-backup
VIEW=/www/luci-static/resources/view/mu300
MOD=/www/luci-static/resources/mu300
MENU=/usr/share/luci/menu.d/luci-app-mu300.json
ACL=/usr/share/rpcd/acl.d/luci-app-mu300-mihomo-select.json
SELECTOR=/usr/libexec/mu300-mihomo-selector
RPC=/usr/libexec/rpcd/mu300mselect
CRON=/etc/crontabs/root
I18N=/usr/lib/lua/luci/i18n
CAT_ZH=$I18N/mu300-vpn-enhance.zh-cn.lmo
CAT_TR=$I18N/mu300-vpn-enhance.tr.lmo
CLI=$(readlink -f "$(command -v mu300-vpn)")
DRIVER=$(dirname "$CLI")/../lib/vpn/mihomo.sh
SUB_TARGET=$VIEW/vpn-subscriptions-enhance.js
OV_TARGET=$VIEW/vpn-overview-enhance.js
MOD_TARGET=$MOD/mselect_overview_enhance.js

if [ -d "$BACK" ]; then
    if [ -e "$BACK/rollback-in-progress" ]; then
        echo "发现未完成的回滚，请重试：sh $BACK/uninstall.sh" >&2; exit 1
    fi
    if [ -r "$BACK/installed-version" ]; then
        echo "增强包已安装：$(cat "$BACK/installed-version")"; exit 0
    fi
    echo "发现未完成的安装备份：$BACK，请先检查或回滚" >&2; exit 1
fi
for cmd in jq curl awk sha256sum jsonfilter mktemp; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "缺少依赖：$cmd" >&2; exit 1; }
done
curl -V | grep -q UnixSockets || { echo 'curl 缺少 UnixSockets 支持' >&2; exit 1; }
for f in "$CLI" "$DRIVER" "$MENU" "$VIEW/vpn-overview.js" "$VIEW/vpn-subscriptions.js" \
         "$HERE/i18n/mu300-vpn-enhance.zh-cn.lmo" "$HERE/i18n/mu300-vpn-enhance.tr.lmo"; do
    [ -r "$f" ] || { echo "缺少必要文件：$f" >&2; exit 1; }
done
[ ! -e "$OV_TARGET" ] && [ ! -e "$SUB_TARGET" ] && [ ! -e "$MOD_TARGET" ] || {
    echo '检测到同名增强版文件但没有完整安装记录；拒绝覆盖，请先排查' >&2; exit 1;
}

umask 077
TMP=$(mktemp -d /tmp/mu300-enhance.XXXXXX)
trap 'rm -rf "$TMP"' EXIT
trap 'exit 1' HUP INT TERM

# 1. Built-in subscription engine: prefer Clash YAML, avoid restart for identical YAML.
awk -v base="$HERE/snippets/" -f "$HERE/scripts/patch-native-cli.awk" "$CLI" > "$TMP/cli"
sh -n "$TMP/cli"

# 2. Mihomo Unix socket plus per-profile node selection persistence.
awk -f "$HERE/scripts/patch-mihomo-driver.awk" "$DRIVER" > "$TMP/driver"
sh -n "$TMP/driver"

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

# 4. Ensure the native scheduler is present while preserving existing entries.
if [ -r "$CRON" ]; then cp -p "$CRON" "$TMP/cron"; else : > "$TMP/cron"; fi
if ! awk -f "$HERE/scripts/has-native-cron.awk" "$TMP/cron"; then
    printf '\n17 * * * * %s subscription refresh --due >/dev/null 2>&1 # mu300-vpn subscriptions\n' "$CLI" >> "$TMP/cron"
fi

# 5. Back up the managed files, keeping the backup separate from profile data.
mkdir "$BACK"
trap '
    rm -f "$BACK/installing-pid"
    [ -f "$BACK/rollback-ready" ] || rm -rf "$BACK"
    rm -rf "$TMP"
' EXIT
printf '%s\n' "$$" > "$BACK/installing-pid"
mkdir "$BACK/files"
: > "$BACK/manifest"
backup() {
    [ -f "$1" ] || return 0
    mkdir -p "$BACK/files${1%/*}"
    cp -p "$1" "$BACK/files$1"
    printf '%s\n' "$1" >> "$BACK/manifest"
}
for f in "$CLI" "$DRIVER" "$MENU" "$ACL" "$SELECTOR" "$RPC" "$CRON" "$CAT_ZH" "$CAT_TR"; do backup "$f"; done
cp "$HERE/uninstall.sh" "$BACK/uninstall.sh"
chmod 700 "$BACK/uninstall.sh"
: > "$BACK/rollback-ready"

# 6. Install staged files; menu route is changed last.
install_file() {
    _src=$1 _dst=$2 _mode=$3
    mkdir -p "${_dst%/*}"
    _new="$_dst.enhance.$$"
    cp "$_src" "$_new" && chmod "$_mode" "$_new" && mv -f "$_new" "$_dst"
}
install_file "$TMP/cli" "$CLI" 755
install_file "$TMP/driver" "$DRIVER" 644
install_file "$HERE/assets/mu300-mihomo-selector" "$SELECTOR" 700
install_file "$HERE/assets/mu300mselect" "$RPC" 700
install_file "$HERE/assets/luci-app-mu300-mihomo-select.json" "$ACL" 644
install_file "$HERE/assets/mselect_overview_enhance.js" "$MOD_TARGET" 644
install_file "$HERE/i18n/${CAT_ZH##*/}" "$CAT_ZH" 644
install_file "$HERE/i18n/${CAT_TR##*/}" "$CAT_TR" 644
install_file "$TMP/overview.js" "$OV_TARGET" 644
install_file "$TMP/subscriptions.js" "$SUB_TARGET" 644
install_file "$TMP/cron" "$CRON" 600
install_file "$TMP/menu.json" "$MENU" 644

sha256sum "$CLI" "$DRIVER" "$MENU" "$ACL" "$SELECTOR" "$RPC" \
    "$SUB_TARGET" "$OV_TARGET" "$MOD_TARGET" "$CAT_ZH" "$CAT_TR" "$CRON" > "$BACK/installed.sha256"
mu300-vpn version >/dev/null 2>&1 || echo '警告：mu300-vpn version 命令自检失败；请检查 CLI' >&2
rm -f /tmp/luci-indexcache* /var/luci-indexcache* 2>/dev/null || true
rm -rf /tmp/luci-modulecache /var/luci-modulecache 2>/dev/null || true
[ ! -x /etc/init.d/cron ] || /etc/init.d/cron restart
[ ! -x /etc/init.d/rpcd ] || /etc/init.d/rpcd restart
[ ! -x /etc/init.d/uhttpd ] || /etc/init.d/uhttpd restart
printf '%s\n' "$VERSION" > "$BACK/installed-version.new"
mv -f "$BACK/installed-version.new" "$BACK/installed-version"
printf '\nmu300-linux-vpn-enhance %s 安装完成。\n' "$VERSION"
echo '原生订阅：优先请求完整 Mihomo YAML，并按原有刷新周期自动更新。'
echo 'Overview：只显示 Mihomo 节点选择卡片；离线或非 Mihomo 时禁用选择。'
echo "检查：sh $HERE/audit.sh"
echo "回滚：sh $BACK/uninstall.sh"
