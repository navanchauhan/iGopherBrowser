#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="iGopherBrowserAdwaita"
PRODUCT="$APP_NAME"
BUNDLE="$ROOT/dist/$APP_NAME.app"
EXECUTABLE="$BUNDLE/Contents/MacOS/$APP_NAME"
ARGS=("$@")
GTK_THEME_VALUE="${GTK_THEME:-Adwaita}"
COLOR_SCHEME_VALUE="${OMNIUI_ADWAITA_COLOR_SCHEME:-system}"
GSK_RENDERER_VALUE="${GSK_RENDERER:-cairo}"

cd "$ROOT"

pkill -9 -f "$APP_NAME" >/dev/null 2>&1 || true

xcrun swift build --product "$PRODUCT"

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$ROOT/.build/debug/$PRODUCT" "$EXECUTABLE"

cat > "$BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>dev.omnikit.$APP_NAME</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

launchctl setenv GTK_THEME "$GTK_THEME_VALUE"
launchctl setenv OMNIUI_ADWAITA_COLOR_SCHEME "$COLOR_SCHEME_VALUE"
launchctl setenv GSK_RENDERER "$GSK_RENDERER_VALUE"

if ((${#ARGS[@]})); then
    /usr/bin/open -n "$BUNDLE" --args "${ARGS[@]}"
else
    /usr/bin/open -n "$BUNDLE"
fi

echo "Launched $BUNDLE"
echo "Adwaita env: GTK_THEME=$GTK_THEME_VALUE OMNIUI_ADWAITA_COLOR_SCHEME=$COLOR_SCHEME_VALUE GSK_RENDERER=$GSK_RENDERER_VALUE"
echo "Computer Use target: dev.omnikit.$APP_NAME"
