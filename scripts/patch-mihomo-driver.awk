# Add root-only Unix control socket to stock Mihomo driver and restore saved node.
$0 == "MIHOMO_OURS='routing-mark allow-lan bind-address tun dns'" {
    print "MIHOMO_OURS='routing-mark allow-lan bind-address tun dns external-controller-unix'"
    ours++; next
}
$0 == "routing-mark: $((MARK))" {
    print "external-controller-unix: /run/mu300-vpn/mihomo-control.sock"
    print
    socket++; next
}
$0 == "    echo \"tunnel up on $TUN (mihomo $MHPID)\"" {
    print
    print "    /usr/libexec/mu300-mihomo-selector restore >/dev/null 2>&1 || true"
    restore++; next
}
{ print }
END {
    if (ours!=1 || socket!=1 || restore!=1) {
        print "Unsupported Mihomo driver; no changes installed" > "/dev/stderr"; exit 63
    }
}
