#!/bin/bash
#
# Market Companion – LaunchAgent Installer
#
# Installs a macOS LaunchAgent that launches Market Companion
# at 6:30 AM and 1:00 PM Pacific Time for automated report generation.
#

set -euo pipefail

PLIST_NAME="com.marketcompanion.scheduler"
PLIST_PATH="$HOME/Library/LaunchAgents/${PLIST_NAME}.plist"
APP_PATH="/Applications/Market Companion.app"

# Check if the app exists in common locations
if [ ! -d "$APP_PATH" ]; then
    # Try the build directory
    DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData"
    APP_PATH=$(find "$DERIVED_DATA" -name "Market Companion.app" -type d -maxdepth 5 2>/dev/null | head -1)

    if [ -z "$APP_PATH" ]; then
        echo "Error: Market Companion.app not found."
        echo "Build the app in Xcode first, or copy it to /Applications."
        exit 1
    fi
fi

echo "Using app at: $APP_PATH"

# Create LaunchAgents directory if needed
mkdir -p "$HOME/Library/LaunchAgents"

# Write the plist
cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${PLIST_NAME}</string>

    <key>ProgramArguments</key>
    <array>
        <string>open</string>
        <string>-a</string>
        <string>${APP_PATH}</string>
        <string>--args</string>
        <string>--generate-report</string>
    </array>

    <key>StartCalendarInterval</key>
    <array>
        <!-- 6:30 AM Pacific (UTC-8 = 14:30, UTC-7 = 13:30) -->
        <!-- Using local time; macOS respects the system timezone -->
        <dict>
            <key>Hour</key>
            <integer>6</integer>
            <key>Minute</key>
            <integer>30</integer>
        </dict>
        <!-- 1:00 PM Pacific -->
        <dict>
            <key>Hour</key>
            <integer>13</integer>
            <key>Minute</key>
            <integer>0</integer>
        </dict>
    </array>

    <key>StandardOutPath</key>
    <string>${HOME}/Library/Logs/MarketCompanion/scheduler.log</string>

    <key>StandardErrorPath</key>
    <string>${HOME}/Library/Logs/MarketCompanion/scheduler-error.log</string>

    <key>RunAtLoad</key>
    <false/>

    <key>EnvironmentVariables</key>
    <dict>
        <key>TZ</key>
        <string>America/Los_Angeles</string>
    </dict>
</dict>
</plist>
EOF

# Create log directory
mkdir -p "$HOME/Library/Logs/MarketCompanion"

# Unload existing (if any)
launchctl unload "$PLIST_PATH" 2>/dev/null || true

# Load the agent
launchctl load "$PLIST_PATH"

echo ""
echo "✓ LaunchAgent installed successfully!"
echo "  Plist: $PLIST_PATH"
echo "  Schedule: 6:30 AM and 1:00 PM (system timezone)"
echo "  Logs: ~/Library/Logs/MarketCompanion/"
echo ""
echo "To verify:  launchctl list | grep marketcompanion"
echo "To remove:  ./uninstall.sh"
