#!/bin/bash
# Usage: ./install.sh [uninstall]
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
label=com.user.plateau
plist="$HOME/Library/LaunchAgents/$label.plist"
bin="$HOME/.local/bin/plateau"

launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
if [ "${1:-}" = uninstall ]; then rm -f "$plist" "$bin"; echo "uninstalled"; exit 0; fi

mkdir -p "$(dirname "$bin")" "$(dirname "$plist")"
swiftc -O "$here/plateau.swift" -o "$bin"
cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$label</string>
  <key>ProgramArguments</key><array><string>$bin</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
</dict></plist>
PLIST
launchctl bootstrap "gui/$(id -u)" "$plist"
echo "installed: greyscale now follows video playback"
