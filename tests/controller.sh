#!/bin/sh
# Reproduce a device without od, with a fake engine and isolated profile files.
set -eu
ROOT=$1 T=$2
RUN=$T/controller-run
STORE=$T/controller-store
STATE=$T/controller-state
PROFILE=$STORE/profiles/fixture
mkdir -p "$RUN" "$PROFILE" "$STATE" "$T/controller-bin"
sed "s|/run/mu300-vpn|$RUN|g; s|/etc/mu300/vpn|$STORE|g; s|/root/.mu300-linux-vpn-enhance|$STATE|g" \
    "$ROOT/assets/mu300-mihomo-selector" > "$T/controller"
printf '#!/bin/sh\nexit 127\n' > "$T/controller-bin/od"
printf '#!/bin/sh\ntest "$1" = check\n' > "$T/controller-bin/engine"
chmod +x "$T/controller" "$T/controller-bin/od" "$T/controller-bin/engine"
export PATH="$T/controller-bin:$PATH"
printf "TYPE='sing-box'\n" > "$PROFILE/meta"
printf 'fixture\n' > "$STORE/active"
printf '{"outbounds":[{"type":"urltest","tag":"Auto"}]}\n' > "$PROFILE/config.json"
"$T/controller" get | jq -e '.type == "sing-box" and .reason == "no-selector" and .online == false' >/dev/null
cp "$PROFILE/config.json" "$RUN/config.json"
if "$T/controller" prepare-sing-box "$RUN" fixture "$$" "$T/controller-bin/engine"; then
    echo 'Unexpected controller started without a manual group' >&2; exit 1
fi
[ ! -e "$RUN/sing-box-controlled.json" ]

printf '%s\n' '{"outbounds":[{"type":"selector","tag":"Choice","outbounds":["A","B"]}]}' > "$PROFILE/config.json"
cp "$PROFILE/config.json" "$RUN/config.json"
"$T/controller" get | jq -e '.reason == "" and .online == false' >/dev/null
"$T/controller" prepare-sing-box "$RUN" fixture "$$" "$T/controller-bin/engine"
jq -e '.experimental.clash_api |
    (.external_controller | startswith("127.0.0.1:")) and (.secret | length == 64)' \
    "$RUN/sing-box-controlled.json" >/dev/null
echo 'PASS: sing-box controller startup without od and explicit status for profiles without selectors.'
