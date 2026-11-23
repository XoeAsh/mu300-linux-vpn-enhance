# Enable node selection only at runtime, after stock config generation and validation.
$0 == "drv_start() { exec \"$BIN\" run -c \"$RUN/config.json\" --disable-color; }" {
    print "drv_start() {"
    print "    if singbox_raw && [ -n \"${ACTIVE:-}\" ] &&"
    print "       /usr/libexec/mu300-mihomo-selector prepare-sing-box \"$RUN\" \"$ACTIVE\" \"$$\" \"$BIN\"; then"
    print "        exec \"$BIN\" run -c \"$RUN/sing-box-controlled.json\" --disable-color"
    print "    fi"
    print "    exec \"$BIN\" run -c \"$RUN/config.json\" --disable-color"
    print "}"
    count++; next
}
{ print }
END {
    if (count!=1) {
        print "Unsupported sing-box driver; no changes installed" > "/dev/stderr"; exit 65
    }
}
