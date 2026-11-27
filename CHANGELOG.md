# Changelog

## 0.2.2

- Clear stale DNS redirection when the VPN is turned off, including when the stock cleanup skips work while the engine or tunnel interface is still stopping.

## 0.2.1

- Add sing-box JSON subscriptions and retain the detected format when refreshing.
- Try sing-box JSON, Mihomo YAML, and then the default response for new automatic subscriptions.
- Switch sing-box selector nodes from the LuCI Overview and remember the choice per profile.
- Keep the built-in English, Simplified Chinese, and Turkish interface.
- Use the original subscription manager's refresh behavior and remove enhancement-owned files on uninstall.
- Start the sing-box controller on OpenWrt systems without od and report when the active profile has no manual selector.
