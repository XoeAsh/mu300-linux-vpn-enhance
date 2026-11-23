index($0, "allowed \"${type:-auto}\" \047(auto|links|mihomo|dae)\047 ||") {
    sub(/auto\|links\|mihomo\|dae/, "auto|links|mihomo|sing-box|dae"); count++
}
{ print }
END {
    if (count!=1) {
        print "Unsupported LuCI VPN RPC structure; no changes installed" > "/dev/stderr"; exit 64
    }
}
