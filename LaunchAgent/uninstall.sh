#!/bin/bash
#
# Market Companion – LaunchAgent Uninstaller
#

set -euo pipefail

PLIST_NAME="com.marketcompanion.scheduler"
PLIST_PATH="$HOME/Library/LaunchAgents/${PLIST_NAME}.plist"

if [ ! -f "$PLIST_PATH" ]; then
    echo "LaunchAgent not installed (${PLIST_PATH} not found)."
    exit 0
fi

# Unload
launchctl unload "$PLIST_PATH" 2>/dev/null || true

# Remove plist
rm -f "$PLIST_PATH"

echo "✓ LaunchAgent uninstalled."
echo "  Removed: $PLIST_PATH"
