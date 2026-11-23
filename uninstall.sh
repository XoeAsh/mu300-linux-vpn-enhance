#!/bin/sh
# Restore exact pre-install executable/UI files; leave profiles and subscriptions intact.
set -eu
[ "$(id -u)" = 0 ] || { echo '请使用 root 执行' >&2; exit 1; }
BACK=/root/mu300-linux-vpn-enhance-backup
missing_backup() { echo "找不到可用于回滚的备份：$BACK" >&2; exit 1; }
[ -s "$BACK/manifest" ] && [ -f "$BACK/rollback-ready" ] || missing_backup
if [ -r "$BACK/installing-pid" ]; then
    pid=$(cat "$BACK/installing-pid")
    case $pid in
        ''|0|*[!0-9]*) ;;
        *) if kill -0 "$pid" 2>/dev/null; then
               echo '安装仍在运行，请等安装结束后再回滚。' >&2; exit 1
           fi ;;
    esac
fi
if [ -r "$BACK/installed-version" ] && [ ! -e "$BACK/rollback-in-progress" ] &&
   [ "${1:-}" != '--force' ]; then
    sha256sum -c "$BACK/installed.sha256" >/dev/null || {
        echo '增强包管理的文件在安装后发生过变化。为避免覆盖其他修改，已拒绝回滚。' >&2
        echo '请核对差异后，确需覆盖时使用 sh uninstall.sh --force' >&2; exit 1; }
fi
while IFS= read -r f; do
    [ -f "$BACK/files$f" ] || { echo "备份缺少文件：$f" >&2; exit 1; }
done < "$BACK/manifest"
: > "$BACK/rollback-in-progress"
while IFS= read -r f; do
    mkdir -p "${f%/*}"
    tmp="$f.uninstall.$$"
    cp -p "$BACK/files$f" "$tmp" && mv -f "$tmp" "$f"
done < "$BACK/manifest"
# Remove managed files that did not exist before installation.
for f in /www/luci-static/resources/view/mu300/vpn-overview-enhance.js \
         /www/luci-static/resources/view/mu300/vpn-subscriptions-enhance.js \
         /www/luci-static/resources/mu300/mselect_overview_enhance.js \
         /usr/lib/lua/luci/i18n/mu300-vpn-enhance.zh-cn.lmo \
         /usr/lib/lua/luci/i18n/mu300-vpn-enhance.tr.lmo \
         /usr/libexec/mu300-mihomo-selector /usr/libexec/rpcd/mu300mselect \
         /etc/crontabs/root \
         /usr/share/rpcd/acl.d/luci-app-mu300-mihomo-select.json; do
    grep -Fxq "$f" "$BACK/manifest" || rm -f "$f"
done
rm -f /tmp/luci-indexcache* /var/luci-indexcache* 2>/dev/null || true
rm -rf /tmp/luci-modulecache /var/luci-modulecache 2>/dev/null || true
[ ! -x /etc/init.d/cron ] || /etc/init.d/cron restart
[ ! -x /etc/init.d/rpcd ] || /etc/init.d/rpcd restart
[ ! -x /etc/init.d/uhttpd ] || /etc/init.d/uhttpd restart
ARCHIVE="$BACK.uninstalled.$(date +%s).$$"
mv "$BACK" "$ARCHIVE"
echo '已还原安装前的 CLI、Mihomo driver、LuCI 和 RPC 文件。'
echo '原生订阅、YAML、配置选择和网络未更改。'
echo "历史备份保留：$ARCHIVE"
