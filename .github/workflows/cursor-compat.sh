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

WITNESS="$PROBE_DIR/AlreadyOpen.app"
ditto "$APP" "$WITNESS"
plutil -replace CFBundleIdentifier -string studio.papercursor.runner-witness "$WITNESS/Contents/Info.plist"
codesign --sign - --force "$WITNESS"

wait_for_output() {
  for attempt in $(seq 1 18); do
    if [[ -s "$1" ]]; then break; fi
    sleep 1
  done
  cat "$1"
}

trap 'touch "$PROBE_DIR/stop"' EXIT
open -W -n "$WITNESS" --args --warm-witness "$PROBE_DIR/before.txt" "$PROBE_DIR/recheck" "$PROBE_DIR/applied.txt" &
WITNESS_OPEN_PID=$!
wait_for_output "$PROBE_DIR/before.txt"
grep -q '^foreground=true$' "$PROBE_DIR/before.txt"
if grep -q 'matches=true$' "$PROBE_DIR/before.txt"; then exit 1; fi

open -W -n "$APP" --args --owner "$PROBE_DIR/owner.txt" "$PROBE_DIR/stop" &
OWNER_OPEN_PID=$!
wait_for_output "$PROBE_DIR/owner.txt"
grep -q '^applied=true$' "$PROBE_DIR/owner.txt"
open "$WITNESS"
touch "$PROBE_DIR/recheck"
wait_for_output "$PROBE_DIR/applied.txt"
wait "$WITNESS_OPEN_PID"
touch "$PROBE_DIR/stop"
wait "$OWNER_OPEN_PID"
grep -q '^foreground=true$' "$PROBE_DIR/applied.txt"
grep -q -F -x "$(grep '^pid=' "$PROBE_DIR/before.txt")" "$PROBE_DIR/applied.txt"
[[ "$(grep -c 'matches=true$' "$PROBE_DIR/applied.txt")" == 3 ]]
