#!/bin/bash
set -e

APP_NAME="FileStash"
BUNDLE_ID="com.ray.FileStash"
VERSION="1.0.0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/.build"
RELEASE_BIN="${BUILD_DIR}/release/${APP_NAME}"
APP_BUNDLE="${SCRIPT_DIR}/${APP_NAME}.app"

echo "==> Building release binary..."
cd "${SCRIPT_DIR}"
swift build -c release

echo "==> Creating .app bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${RELEASE_BIN}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

echo "==> Writing Info.plist..."
cat > "${APP_BUNDLE}/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

echo "==> Generating app icon from SF Symbols..."
ICONSET_DIR="${BUILD_DIR}/AppIcon.iconset"
rm -rf "${ICONSET_DIR}"
mkdir -p "${ICONSET_DIR}"

SWIFT_SCRIPT="${BUILD_DIR}/generate_icon.swift"
cat > "${SWIFT_SCRIPT}" <<'SWIFT'
import AppKit

let args = CommandLine.arguments
let symbolName = args.count > 1 ? args[1] : "tray.and.arrow.up.fill"
let outputDir = args.count > 2 ? args[2] : "."

let size = NSSize(width: 1024, height: 1024)

let config = NSImage.SymbolConfiguration(pointSize: 700, weight: .regular)
    .applying(NSImage.SymbolConfiguration(hierarchicalColor: .systemBlue))

guard let symbolImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
    .withSymbolConfiguration(config) else {
    print("Failed to load SF Symbol")
    exit(1)
}

symbolImage.isTemplate = false

let composed = NSImage(size: size)
composed.lockFocus()
NSColor.systemBlue.setFill()
let rect = NSRect(origin: .zero, size: size)
NSBezierPath(roundedRect: rect, xRadius: 230, yRadius: 230).fill()

let aspectRatio = symbolImage.size.width / symbolImage.size.height
var drawSize = size
if aspectRatio > 1 {
    drawSize.height = size.width / aspectRatio
} else {
    drawSize.width = size.height * aspectRatio
}
let drawRect = NSRect(
    x: (size.width - drawSize.width) / 2,
    y: (size.height - drawSize.height) / 2,
    width: drawSize.width,
    height: drawSize.height
)
symbolImage.draw(in: drawRect)
composed.unlockFocus()

guard let tiffData = composed.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let pngData = bitmap.representation(using: .png, properties: [:]) else {
    print("Failed to convert image to PNG")
    exit(1)
}

let outputURL = URL(fileURLWithPath: outputDir).appendingPathComponent("icon_1024.png")
try pngData.write(to: outputURL)
print("Generated icon at \(outputURL.path)")
SWIFT

if swift "${SWIFT_SCRIPT}" "tray.and.arrow.up.fill" "${ICONSET_DIR}" > /dev/null 2>&1; then
    if [ -f "${ICONSET_DIR}/icon_1024.png" ]; then
        for size in 16 32 128 256 512; do
            sips -Z ${size} "${ICONSET_DIR}/icon_1024.png" --out "${ICONSET_DIR}/icon_${size}x${size}.png" > /dev/null 2>&1
            sips -Z $((size * 2)) "${ICONSET_DIR}/icon_1024.png" --out "${ICONSET_DIR}/icon_${size}x${size}@2x.png" > /dev/null 2>&1
        done
        rm "${ICONSET_DIR}/icon_1024.png"

        iconutil -c icns "${ICONSET_DIR}" -o "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
        /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "${APP_BUNDLE}/Contents/Info.plist" || true
        echo "    Icon generated successfully."
    fi
else
    echo "    (Icon generation skipped, using generic system icon)"
fi

rm -rf "${ICONSET_DIR}" "${SWIFT_SCRIPT}"

echo "==> Done!"
echo "    App bundle: ${APP_BUNDLE}"
echo ""
echo "You can now run:"
echo "    open '${APP_BUNDLE}'"
