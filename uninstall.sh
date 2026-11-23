#!/bin/sh
# Restore exact pre-install executable/UI files; leave profiles and subscriptions intact.
set -eu
[ "$(id -u)" = 0 ] || { echo '请使用 root 执行' >&2; exit 1; }
BACK=/root/mu300-linux-vpn-mihomo-enhance-backup
[ -r "$BACK/installed-version" ] && [ -r "$BACK/manifest" ] || {
    echo "找不到完整安装备份：$BACK" >&2; exit 1; }
if [ "${1:-}" != '--force' ]; then
    sha256sum -c "$BACK/installed.sha256" >/dev/null || {
        echo '增强包管理的文件在安装后发生过变化。为避免覆盖其他修改，已拒绝回滚。' >&2
        echo '请核对差异后，确需覆盖时使用 sh uninstall.sh --force' >&2; exit 1; }
fi
# Only files added by this project are removed; leave native subscription data untouched.
for f in /www/luci-static/resources/view/mu300/vpn-overview-enhance.js \
         /www/luci-static/resources/view/mu300/vpn-subscriptions-enhance.js \
         /www/luci-static/resources/mu300/mselect_overview_enhance.js \
         /www/luci-static/resources/mu300/vpn_overview_cn_enhance.js \
         /usr/libexec/mu300-mihomo-selector /usr/libexec/rpcd/mu300mselect \
         /usr/share/rpcd/acl.d/luci-app-mu300-mihomo-select.json; do
    rm -f "$f"
done
while IFS= read -r f; do
    [ -f "$BACK/files$f" ] || continue
    mkdir -p "${f%/*}"
    tmp="$f.uninstall.$$"
    cp -p "$BACK/files$f" "$tmp" && mv -f "$tmp" "$f"
done < "$BACK/manifest"
# If the installer created a file where none existed, don't keep the orphan.
# The original cron may not have existed on a minimal upstream image.
if ! grep -Fxq /etc/crontabs/root "$BACK/manifest"; then
    rm -f /etc/crontabs/root
fi
for f in /usr/libexec/mu300-mihomo-selector /usr/libexec/rpcd/mu300mselect \
         /usr/share/rpcd/acl.d/luci-app-mu300-mihomo-select.json; do
    grep -Fxq "$f" "$BACK/manifest" || rm -f "$f"
done
rm -f /tmp/luci-indexcache* /var/luci-indexcache* 2>/dev/null || true
rm -rf /tmp/luci-modulecache /var/luci-modulecache 2>/dev/null || true
[ ! -x /etc/init.d/cron ] || /etc/init.d/cron restart
[ ! -x /etc/init.d/rpcd ] || /etc/init.d/rpcd restart
[ ! -x /etc/init.d/uhttpd ] || /etc/init.d/uhttpd restart
ARCHIVE="$BACK.uninstalled.$(date +%s)"
mv "$BACK" "$ARCHIVE"
echo '已还原安装前的 CLI、Mihomo driver、LuCI 和 RPC 文件。'
echo '订阅、YAML、配置选择和网络未更改。已清理的旧订阅 URL 不会恢复。'
echo "历史备份保留：$ARCHIVE"
echo '注意：如果安装前有旧的 03:23 cron，回滚可能恢复那条任务，但其旧 URL 不会恢复。'
