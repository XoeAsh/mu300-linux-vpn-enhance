#!/bin/sh
# Read-only verification, never outputs URLs or credentials.
set -u
STATE=/root/.mu300-linux-vpn-enhance
MENU=/usr/share/luci/menu.d/luci-app-mu300.json
printf 'Project: mu300-linux-vpn-enhance\n'
if [ -f "$STATE/uninstall-in-progress" ]; then
    printf 'Installation: uninstall interrupted\n'
elif [ -r "$STATE/installed-version" ]; then
    printf 'Installed version: %s\n' "$(cat "$STATE/installed-version")"
elif [ -d "$STATE" ]; then
    printf 'Installation: interrupted\n'
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
        "Native Mihomo subscriptions: " + ([.[]|select(.format=="mihomo")]|length|tostring),
        "Native sing-box subscriptions: " + ([.[]|select(.format=="sing-box")]|length|tostring)' || true
fi
if command -v ubus >/dev/null 2>&1; then
    ubus call mu300mselect get '{}' 2>/dev/null |
        jq -c '{ok,online,type,reason,groups: (.groups|length)}' || true
fi
[ ! -s "$STATE/installed.sha256" ] || sha256sum -c "$STATE/installed.sha256" 2>/dev/null
