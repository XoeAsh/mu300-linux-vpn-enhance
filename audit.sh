#!/bin/sh
# Read-only verification, never outputs URLs or credentials.
set -u
BACK=/root/mu300-linux-vpn-mihomo-enhance-backup
MENU=/usr/share/luci/menu.d/luci-app-mu300.json
printf 'Project: mu300-linux-vpn-mihomo-enhance\n'
if [ -r "$BACK/installed-version" ]; then
    printf 'Installed version: %s\n' "$(cat "$BACK/installed-version")"
else
    echo 'Installed version: not installed'
fi
if [ -r "$MENU" ]; then
    jq -r '"Overview route: " + (."admin/vpn/mu300-overview".action.path//"missing"),
        "Subscriptions route: " + (."admin/vpn/mu300-subscriptions".action.path//"missing")' "$MENU"
fi
if command -v mu300-vpn >/dev/null 2>&1; then
    mu300-vpn subscription list --json 2>/dev/null | jq -r '
        "Native subscriptions: " + (length|tostring),
        "Native Mihomo subscriptions: " + ([.[]|select(.format=="mihomo")]|length|tostring)' || true
fi
if [ -r /etc/crontabs/root ]; then
    grep -Fq 'mu300-vpn subscription refresh --due' /etc/crontabs/root &&
        echo 'Native cron: present' || echo 'Native cron: missing'
    grep -Fq '/root/mu300-mihomo-refresh.sh' /etc/crontabs/root &&
        echo 'Legacy cron: present' || echo 'Legacy cron: absent'
fi
for f in /root/mu300-mihomo-refresh.sh /etc/mu300/mihomo-subscription.url \
         /etc/mu300/mihomo-auto-update.enabled; do
    [ ! -e "$f" ] || printf 'Legacy file still exists: %s\n' "$f"
done
if command -v ubus >/dev/null 2>&1; then
    ubus call mu300mselect get '{}' 2>/dev/null |
        jq -c '{ok,online,profile,type,groups: (.groups|length)}' || true
fi
[ ! -r "$BACK/installed.sha256" ] || sha256sum -c "$BACK/installed.sha256" 2>/dev/null
