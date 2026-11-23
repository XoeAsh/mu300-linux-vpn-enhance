#!/bin/sh
# mu300-linux-vpn-mihomo-enhance: one-step install for upstream MU300 VPN and v1-v6 deployments.
# No VPN, network, routing or firewall restart. Read README before installing.
set -eu
[ "$(id -u)" = 0 ] || { echo '请使用 root 安装' >&2; exit 1; }
HERE=$(CDPATH= cd "$(dirname "$0")" && pwd)
VERSION=$(cat "$HERE/VERSION")
BACK=/root/mu300-linux-vpn-mihomo-enhance-backup
VIEW=/www/luci-static/resources/view/mu300
MOD=/www/luci-static/resources/mu300
MENU=/usr/share/luci/menu.d/luci-app-mu300.json
ACL=/usr/share/rpcd/acl.d/luci-app-mu300-mihomo-select.json
SELECTOR=/usr/libexec/mu300-mihomo-selector
RPC=/usr/libexec/rpcd/mu300mselect
CRON=/etc/crontabs/root
CLI=$(readlink -f "$(command -v mu300-vpn)")
DRIVER=$(dirname "$CLI")/../lib/vpn/mihomo.sh
SUB_TARGET=$VIEW/vpn-subscriptions-enhance.js
OV_TARGET=$VIEW/vpn-overview-enhance.js
MOD_TARGET=$MOD/mselect_overview_enhance.js
CN_TARGET=$MOD/vpn_overview_cn_enhance.js

if [ -d "$BACK" ]; then
    if [ -r "$BACK/installed-version" ]; then
        echo "增强包已安装：$(cat "$BACK/installed-version")。无需重复安装。"; exit 0
    fi
    echo "发现未完成的安装备份：$BACK，请先检查或回滚" >&2; exit 1
fi
for cmd in jq curl awk sha256sum jsonfilter mktemp; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "缺少依赖：$cmd" >&2; exit 1; }
done
curl -V | grep -q UnixSockets || { echo 'curl 缺少 UnixSockets 支持' >&2; exit 1; }
for f in "$CLI" "$DRIVER" "$MENU" "$VIEW/vpn-overview.js" "$VIEW/vpn-subscriptions.js"; do
    [ -r "$f" ] || { echo "缺少必要文件：$f" >&2; exit 1; }
done
[ ! -e "$OV_TARGET" ] && [ ! -e "$SUB_TARGET" ] && [ ! -e "$MOD_TARGET" ] && [ ! -e "$CN_TARGET" ] || {
    echo '检测到同名增强版文件但没有完整安装记录；拒绝覆盖，请先排查' >&2; exit 1;
}

umask 077
TMP=$(mktemp -d /tmp/mu300-enhance.XXXXXX)
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

# 1. Built-in subscription engine: prefer Clash YAML, avoid restart for identical YAML.
# v4 already applied? Reuse it as-is instead of applying a second fragile source patch.
if grep -Fq 'mu300-native-mihomo-v4:' "$CLI"; then
    grep -Fq "ClashMeta/1.19.0" "$CLI" &&
    grep -Fq 'cmp -s "$3" "$PROFILES/$_hit/config.yaml"' "$CLI" &&
    grep -Fq 'mihomo YAML import/check failed' "$CLI" || {
        echo '现有 CLI 仅包含部分 v4 改动，拒绝覆盖' >&2; exit 1; }
    cp -p "$CLI" "$TMP/cli"
else
    awk -v base="$HERE/snippets/" -f "$HERE/scripts/patch-native-cli.awk" "$CLI" > "$TMP/cli" || exit 1
fi
sh -n "$TMP/cli"

# 2. Mihomo Unix socket plus per-profile node selection persistence.
if grep -Fq 'external-controller-unix: /run/mu300-vpn/mihomo-control.sock' "$DRIVER"; then
    grep -Fq '/usr/libexec/mu300-mihomo-selector restore' "$DRIVER" &&
    grep -Fq "dns external-controller-unix'" "$DRIVER" || {
        echo 'Mihomo driver 似乎仅部分打过补丁；拒绝覆盖' >&2; exit 1; }
    cp -p "$DRIVER" "$TMP/driver"
else
    awk -f "$HERE/scripts/patch-mihomo-driver.awk" "$DRIVER" > "$TMP/driver" || exit 1
fi
sh -n "$TMP/driver"

# 3. Native subscriptions page, already v4 or stock.
SUB_ROUTE=$(jq -r '."admin/vpn/mu300-subscriptions".action.path // empty' "$MENU")
case "$SUB_ROUTE" in
    mu300/vpn-subscriptions|mu300/vpn-subscriptions-v4) ;;
    *) echo "未知订阅页面路由：$SUB_ROUTE" >&2; exit 1 ;;
esac
SUB_SRC=$VIEW/${SUB_ROUTE#mu300/}.js
[ -r "$SUB_SRC" ] || { echo "缺少订阅页面 $SUB_SRC" >&2; exit 1; }
if grep -Fq '新订阅的自动识别优先' "$SUB_SRC"; then
    cp "$SUB_SRC" "$TMP/subscriptions.js"
else
    awk -v base="$HERE/snippets/" -f "$HERE/scripts/patch-subscription-view.awk" \
        "$SUB_SRC" > "$TMP/subscriptions.js" || exit 1
fi

grep -Fq '自动识别（优先完整 Mihomo YAML）' "$TMP/subscriptions.js" || {
    echo '订阅页面没有包含原生 YAML 增强说明' >&2; exit 1; }

# 4. Overview: reuse latest installed version; on stock apply a bounded overview patch.
OV_ROUTE=$(jq -r '."admin/vpn/mu300-overview".action.path // empty' "$MENU")
case "$OV_ROUTE" in
    mu300/vpn-overview|mu300/vpn-overview-v3|mu300/vpn-overview-v4|mu300/vpn-overview-v5|mu300/vpn-overview-v6) ;;
    *) echo "未知 Overview 路由：$OV_ROUTE" >&2; exit 1 ;;
esac
OV_SRC=$VIEW/${OV_ROUTE#mu300/}.js
[ -r "$OV_SRC" ] || { echo "缺少 Overview 文件 $OV_SRC" >&2; exit 1; }
if grep -Eq "^'require mu300\.mselect_overview.* as MS';$" "$OV_SRC"; then
    cp "$OV_SRC" "$TMP/overview.base.js"
else
    awk -f "$HERE/scripts/patch-stock-overview.awk" "$OV_SRC" > "$TMP/overview.base.js" || exit 1
fi
awk '
  /^\047require mu300\.mselect_overview.* as MS\047;$/ {print "\047require mu300.mselect_overview_enhance as MS\047;"; m++; next}
  /^\047require mu300\.vpn_overview_cn.* as CN\047;$/ {print "\047require mu300.vpn_overview_cn_enhance as CN\047;"; c++; next}
  {print}
  END {if(m!=1 || c!=1) {print "Overview module anchors not unique" > "/dev/stderr"; exit 1}}
' "$TMP/overview.base.js" > "$TMP/overview.js" || exit 1
grep -Fq 'MS.card(ms, function()' "$TMP/overview.js" || { echo 'Overview 缺少节点卡片入口' >&2; exit 1; }

jq '."admin/vpn/mu300-overview".action.path="mu300/vpn-overview-enhance" |
    ."admin/vpn/mu300-subscriptions".action.path="mu300/vpn-subscriptions-enhance"' \
    "$MENU" > "$TMP/menu.json"
jq -e '."admin/vpn/mu300-overview".action.path=="mu300/vpn-overview-enhance" and
    ."admin/vpn/mu300-subscriptions".action.path=="mu300/vpn-subscriptions-enhance"' \
    "$TMP/menu.json" >/dev/null

# 5. Cron: maintain native hourly scheduler; retire old standalone updater only after
# a native Mihomo subscription exists, to prevent loss of automatic refresh.
if [ -r "$CRON" ]; then cp -p "$CRON" "$TMP/cron"; else : > "$TMP/cron"; fi
if ! grep -Fq 'mu300-vpn subscription refresh --due' "$TMP/cron"; then
    printf '%s\n' '17 * * * * /opt/mu300/bin/mu300-vpn subscription refresh --due >/dev/null 2>&1 # mu300-vpn subscriptions' >> "$TMP/cron"
fi
NATIVE_OK=0
if mu300-vpn subscription list --json 2>/dev/null |
    jq -e 'any(.[]; .format=="mihomo" and (.profiles|type=="array" and length>0))' >/dev/null; then
    NATIVE_OK=1
fi
LEGACY_REMOVED=0
if [ "$NATIVE_OK" = 1 ]; then
    awk 'index($0, "/root/mu300-mihomo-refresh.sh")==0 {print}' "$TMP/cron" > "$TMP/cron.clean"
    mv "$TMP/cron.clean" "$TMP/cron"
    LEGACY_REMOVED=1
fi

# 6. Backup only touched files; do not copy subscription URL/credential stores.
mkdir "$BACK" && chmod 700 "$BACK"
mkdir "$BACK/files"
: > "$BACK/manifest"
backup() {
    [ -f "$1" ] || return 0
    mkdir -p "$BACK/files${1%/*}"
    cp -p "$1" "$BACK/files$1"
    printf '%s\n' "$1" >> "$BACK/manifest"
}
for f in "$CLI" "$DRIVER" "$MENU" "$ACL" "$SELECTOR" "$RPC" "$CRON"; do backup "$f"; done
for f in "$VIEW/vpn-overview.js" "$VIEW/vpn-overview-v3.js" \
         "$VIEW/vpn-overview-v4.js" "$VIEW/vpn-overview-v5.js" \
         "$VIEW/vpn-overview-v6.js" "$VIEW/vpn-mihomo-select.js" \
         "$MOD/mselect_overview.js" "$MOD/mselect_overview_v3.js" \
         "$MOD/mselect_overview_v4.js" "$MOD/mselect_overview_v5.js" \
         "$MOD/mselect_overview_v6.js" "$MOD/vpn_overview_cn.js" \
         "$MOD/vpn_overview_cn_v3.js" "$MOD/vpn_overview_cn_v5.js" \
         /usr/share/luci/menu.d/luci-app-mu300-mihomo-select.json; do backup "$f"; done
# Save old script only if retiring it. Intentionally never copy the old token URL.
if [ "$LEGACY_REMOVED" = 1 ]; then backup /root/mu300-mihomo-refresh.sh; fi
printf '%s\n' "$CLI" > "$BACK/cli-path"
printf '%s\n' "$DRIVER" > "$BACK/driver-path"
printf '%s\n' "$LEGACY_REMOVED" > "$BACK/legacy-removed"
cp "$HERE/uninstall.sh" "$BACK/uninstall.sh"
chmod 700 "$BACK/uninstall.sh"

# 7. Install staged files; menu route is changed last.
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
install_file "$HERE/assets/vpn_overview_cn_enhance.js" "$CN_TARGET" 644
install_file "$TMP/overview.js" "$OV_TARGET" 644
install_file "$TMP/subscriptions.js" "$SUB_TARGET" 644
install_file "$TMP/cron" "$CRON" 600
install_file "$TMP/menu.json" "$MENU" 644

# Retire unused assets only; never delete VPN profiles, native subscriptions or node selections.
rm -f "$VIEW/vpn-overview-v3.js" "$VIEW/vpn-overview-v4.js" \
      "$VIEW/vpn-overview-v5.js" "$VIEW/vpn-overview-v6.js" \
      "$VIEW/vpn-mihomo-select.js" "$MOD/mselect_overview.js" \
      "$MOD/mselect_overview_v3.js" "$MOD/mselect_overview_v4.js" \
      "$MOD/mselect_overview_v5.js" "$MOD/mselect_overview_v6.js" \
      "$MOD/vpn_overview_cn.js" "$MOD/vpn_overview_cn_v3.js" \
      "$MOD/vpn_overview_cn_v5.js" \
      /usr/share/luci/menu.d/luci-app-mu300-mihomo-select.json
if [ "$LEGACY_REMOVED" = 1 ]; then
    # A v1 selector used a single node file. Migrate it before deleting the file.
    OLD_NODE=/etc/mu300/mihomo-selected-node
    PREF=/etc/mu300/mihomo-selector-selections.json
    if [ -s "$OLD_NODE" ]; then
        _node=$(head -n 1 "$OLD_NODE")
        if [ -n "$_node" ]; then
            if [ -r "$PREF" ]; then cp "$PREF" "$TMP/oldprefs.json"; else printf '[]\n' > "$TMP/oldprefs.json"; fi
            if jq -e 'type=="array"' "$TMP/oldprefs.json" >/dev/null 2>&1; then
                jq --arg n "$_node" 'if any(.[]; .profile=="mihomo" and .group=="三毛机场")
                    then . else . + [{profile:"mihomo",group:"三毛机场",node:$n}] end' \
                    "$TMP/oldprefs.json" > "$TMP/newprefs.json"
                cp "$TMP/newprefs.json" "$PREF" && chmod 600 "$PREF"
            else
                echo '警告：旧节点选择记录未迁移；已保留其原文件以便手动处理' >&2
                # Retain only old preference file; native updater cleanup can still proceed.
            fi
        fi
    fi
fi
if [ "$LEGACY_REMOVED" = 1 ]; then
    rm -f /root/mu300-mihomo-refresh.sh /etc/mu300/mihomo-subscription.url \
          /etc/mu300/mihomo-auto-update.enabled
    [ ! -s /etc/mu300/mihomo-selected-node ] || \
        [ -r "$TMP/newprefs.json" ] || echo '提示：旧单节点偏好文件仍保留，需人工确认' >&2
    [ ! -r "$TMP/newprefs.json" ] || rm -f /etc/mu300/mihomo-selected-node
fi

# An old v1 preference is migrated only if it survived and has not yet been migrated.
# On v5/v6 this is normally already done; preserve the current per-profile preferences.
# The .json selection file itself is never erased.
sha256sum "$CLI" "$DRIVER" "$MENU" "$ACL" "$SELECTOR" "$RPC" \
    "$SUB_TARGET" "$OV_TARGET" "$MOD_TARGET" "$CN_TARGET" "$CRON" > "$BACK/installed.sha256"
printf '%s\n' "$VERSION" > "$BACK/installed-version"
mu300-vpn version >/dev/null 2>&1 || echo '警告：mu300-vpn version 命令自检失败；请检查 CLI' >&2
rm -f /tmp/luci-indexcache* /var/luci-indexcache* 2>/dev/null || true
rm -rf /tmp/luci-modulecache /var/luci-modulecache 2>/dev/null || true
[ ! -x /etc/init.d/cron ] || /etc/init.d/cron restart
[ ! -x /etc/init.d/rpcd ] || /etc/init.d/rpcd restart
[ ! -x /etc/init.d/uhttpd ] || /etc/init.d/uhttpd restart
printf '\nmu300-linux-vpn-mihomo-enhance %s 安装完成。\n' "$VERSION"
echo '原生订阅：优先请求完整 Mihomo YAML，并按原有刷新周期自动更新。'
echo 'Overview：只显示 Mihomo 节点选择卡片；离线或非 Mihomo 时禁用选择。'
if [ "$LEGACY_REMOVED" = 1 ]; then
    echo '已清除旧独立定时更新器、cron 和旧 URL。'
else
    echo '没有确认有效的原生 Mihomo 订阅：暂未清除可能存在的旧独立更新器。迁移后运行 cleanup-legacy.sh。'
fi
echo '未重启 VPN 或更改网络、防火墙、当前配置。'
echo "检查：sh $HERE/audit.sh"
echo "回滚：sh $BACK/uninstall.sh"
