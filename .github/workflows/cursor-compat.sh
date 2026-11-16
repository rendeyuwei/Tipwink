set -eu
sw_vers
launchctl managername

PROBE_DIR=$(mktemp -d)
APP="$PROBE_DIR/CursorProbe.app"
mkdir -p "$APP/Contents/MacOS"
cp .github/workflows/cursor-compat.swift "$PROBE_DIR/main.swift"
cat > "$APP/Contents/Info.plist" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>studio.papercursor.runner-probe</string>
<key>CFBundleName</key><string>CursorProbe</string>
<key>CFBundleExecutable</key><string>CursorProbe</string>
<key>CFBundlePackageType</key><string>APPL</string>
</dict></plist>
XML
xcrun swiftc -swift-version 6 -default-isolation MainActor \
  "$PROBE_DIR/main.swift" Sources/CursorTheme.swift Sources/DesktopThemeEngine.swift \
  Sources/WindowServer.swift Sources/DesktopCatBlink.swift \
  -o "$APP/Contents/MacOS/CursorProbe"
codesign --sign - --force "$APP"
if [[ "${1:-}" == "--build-only" ]]; then exit 0; fi

trap 'touch "$PROBE_DIR/stop"' EXIT
open -W -n "$APP" --args --witness "$PROBE_DIR/before.txt"
cat "$PROBE_DIR/before.txt"
grep -q '^foreground=true$' "$PROBE_DIR/before.txt"
if grep -q 'matches=true$' "$PROBE_DIR/before.txt"; then exit 1; fi

open -W -n "$APP" --args --owner "$PROBE_DIR/owner.txt" "$PROBE_DIR/stop" &
OWNER_OPEN_PID=$!
for attempt in $(seq 1 18); do
  if [[ -s "$PROBE_DIR/owner.txt" ]]; then break; fi
  sleep 1
done
cat "$PROBE_DIR/owner.txt"
grep -q '^applied=true$' "$PROBE_DIR/owner.txt"
open -W -n "$APP" --args --witness "$PROBE_DIR/applied.txt"
cat "$PROBE_DIR/applied.txt"
touch "$PROBE_DIR/stop"
wait "$OWNER_OPEN_PID"
grep -q '^foreground=true$' "$PROBE_DIR/applied.txt"
[[ "$(grep -c 'matches=true$' "$PROBE_DIR/applied.txt")" == 3 ]]
