#!/bin/sh
# Retire the pre-native 03:23 updater only after a working native Mihomo subscription exists.
set -eu
[ "$(id -u)" = 0 ] || { echo '请使用 root 运行' >&2; exit 1; }
BACK=/root/mu300-linux-vpn-mihomo-enhance-backup
CRON=/etc/crontabs/root
PREF=/etc/mu300/mihomo-selector-selections.json
OLD_NODE=/etc/mu300/mihomo-selected-node
[ -r "$BACK/installed-version" ] || { echo '请先安装 mu300-linux-vpn-mihomo-enhance' >&2; exit 1; }
[ -r "$CRON" ] && grep -Fq 'mu300-vpn subscription refresh --due' "$CRON" || {
    echo '未找到原生订阅定时刷新任务，停止清理' >&2; exit 1; }
if ! mu300-vpn subscription list --json 2>/dev/null |
   jq -e 'any(.[]; .format=="mihomo" and (.profiles|type=="array" and length>0))' >/dev/null; then
    echo '未找到已导入完整 YAML 的原生 Mihomo 订阅；保留旧定时更新器。' >&2
    exit 1
fi
umask 077
T=$(mktemp -d /tmp/mu300-legacy-clean.XXXXXX)
trap 'rm -rf "$T"' EXIT HUP INT TERM
# Preserve pre-v3 node preference before removing single-profile store.
if [ -s "$OLD_NODE" ]; then
    n=$(head -n 1 "$OLD_NODE")
    if [ -n "$n" ]; then
        if [ -r "$PREF" ]; then cp "$PREF" "$T/pref"; else printf '[]\n' > "$T/pref"; fi
        jq -e 'type=="array"' "$T/pref" >/dev/null 2>&1 || {
            echo '节点选择记录不是有效 JSON 数组，拒绝清理旧选择' >&2; exit 1; }
        jq --arg n "$n" 'if any(.[]; .profile=="mihomo" and .group=="三毛机场")
            then . else . + [{profile:"mihomo",group:"三毛机场",node:$n}] end' \
            "$T/pref" > "$T/prefnew"
        cp "$T/prefnew" "$PREF" && chmod 600 "$PREF"
    fi
fi
# Preserve cron snapshot for diagnosis, but never copy token URL.
if [ ! -e "$BACK/legacy-cron-before-cleanup" ]; then
    cp -p "$CRON" "$BACK/legacy-cron-before-cleanup"
fi
if [ -f /root/mu300-mihomo-refresh.sh ] && [ ! -f "$BACK/legacy-refresh-script" ]; then
    cp -p /root/mu300-mihomo-refresh.sh "$BACK/legacy-refresh-script"
fi
awk 'index($0,"/root/mu300-mihomo-refresh.sh")==0 {print}' "$CRON" > "$T/cron"
cp "$T/cron" "$CRON" && chmod 600 "$CRON"
rm -f /root/mu300-mihomo-refresh.sh \
      /etc/mu300/mihomo-subscription.url \
      /etc/mu300/mihomo-auto-update.enabled "$OLD_NODE"
# Update the verification stamp for the installed file touched here.
if [ -r "$BACK/installed.sha256" ]; then
    grep -v "  $CRON\$" "$BACK/installed.sha256" > "$T/sums" || true
    sha256sum "$CRON" >> "$T/sums"
    cp "$T/sums" "$BACK/installed.sha256"
fi
[ ! -x /etc/init.d/cron ] || /etc/init.d/cron restart
echo '清理完成：旧独立更新脚本、03:23 cron、旧订阅 URL 和标记均已删除。'
echo '原生订阅、原生定时刷新、Mihomo 节点控制和网络设置未修改。'
