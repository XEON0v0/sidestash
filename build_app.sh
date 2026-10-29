#!/bin/bash
set -e

APP_NAME="SideStash"
BUNDLE_ID="app.sidestash.SideStash"
VERSION="1.0.0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Optional overrides let build output and the bundle live outside the workspace.
BUILD_DIR="${SIDESTASH_BUILD_DIR:-${SCRIPT_DIR}/.build}"
APP_OUTPUT_DIR="${SIDESTASH_APP_DIR:-${SCRIPT_DIR}}"
APP_BUNDLE="${APP_OUTPUT_DIR}/${APP_NAME}.app"

SWIFT_BUILD_ARGS=(-c release --scratch-path "${BUILD_DIR}")
if [ -n "${SIDESTASH_SWIFTPM_CACHE:-}" ]; then
    SWIFT_BUILD_ARGS+=(--cache-path "${SIDESTASH_SWIFTPM_CACHE}")
fi

echo "==> Building release binary..."
cd "${SCRIPT_DIR}"
swift build "${SWIFT_BUILD_ARGS[@]}"
# Ask SwiftPM for the real product path; SWIFTPM_BUILD_DIR can override --scratch-path.
RELEASE_BIN="$(swift build "${SWIFT_BUILD_ARGS[@]}" --show-bin-path)/${APP_NAME}"

echo "==> Creating .app bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

echo "  Copying localization..."
cp -R "${SCRIPT_DIR}/Sources/SideStash/en.lproj" "${APP_BUNDLE}/Contents/Resources/"
cp -R "${SCRIPT_DIR}/Sources/SideStash/zh-Hans.lproj" "${APP_BUNDLE}/Contents/Resources/"

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
    <string>26.0</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>SideStash needs access to Finder to find the current Finder folder for moving stashed files.</string>
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

let outputDir = CommandLine.arguments.dropFirst().first ?? "."

let size = NSSize(width: 1024, height: 1024)
let canvasRect = NSRect(origin: .zero, size: size)

extension NSColor {
    convenience init(hex: Int, alpha: CGFloat = 1.0) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: alpha
        )
    }
}

func roundedPath(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func withShadow(color: NSColor, blur: CGFloat, offset: NSSize, draw: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = color
    shadow.shadowBlurRadius = blur
    shadow.shadowOffset = offset
    shadow.set()
    draw()
    NSGraphicsContext.restoreGraphicsState()
}

func fill(_ path: NSBezierPath, color: NSColor) {
    color.setFill()
    path.fill()
}

func stroke(_ path: NSBezierPath, color: NSColor, width: CGFloat) {
    color.setStroke()
    path.lineWidth = width
    path.stroke()
}

func drawTrafficLight(at center: NSPoint, color: NSColor) {
    let dotRect = NSRect(x: center.x - 10, y: center.y - 10, width: 20, height: 20)
    fill(NSBezierPath(ovalIn: dotRect), color: color)
}

func drawFolder(in rect: NSRect) {
    let backRect = NSRect(x: rect.minX + 8, y: rect.minY + 18, width: rect.width - 16, height: rect.height - 18)
    let backPath = roundedPath(backRect, radius: 28)
    fill(backPath, color: NSColor(hex: 0x61B7FF))

    let tabPath = NSBezierPath()
    tabPath.move(to: NSPoint(x: rect.minX + 14, y: rect.midY + 22))
    tabPath.line(to: NSPoint(x: rect.minX + 94, y: rect.midY + 22))
    tabPath.curve(
        to: NSPoint(x: rect.minX + 122, y: rect.midY + 46),
        controlPoint1: NSPoint(x: rect.minX + 104, y: rect.midY + 22),
        controlPoint2: NSPoint(x: rect.minX + 116, y: rect.midY + 32)
    )
    tabPath.line(to: NSPoint(x: rect.maxX - 22, y: rect.midY + 46))
    tabPath.curve(
        to: NSPoint(x: rect.maxX - 8, y: rect.midY + 32),
        controlPoint1: NSPoint(x: rect.maxX - 14, y: rect.midY + 46),
        controlPoint2: NSPoint(x: rect.maxX - 8, y: rect.midY + 40)
    )
    tabPath.line(to: NSPoint(x: rect.maxX - 8, y: rect.minY + 44))
    tabPath.line(to: NSPoint(x: rect.minX + 14, y: rect.minY + 44))
    tabPath.close()
    fill(tabPath, color: NSColor(hex: 0x8FD3FF))

    let frontPath = roundedPath(NSRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - 22), radius: 32)
    fill(frontPath, color: NSColor(hex: 0x2E94FF))

    let highlight = roundedPath(NSRect(x: rect.minX + 18, y: rect.minY + 64, width: rect.width - 36, height: 22), radius: 11)
    fill(highlight, color: NSColor.white.withAlphaComponent(0.22))
}

func drawFileChip(in rect: NSRect, tint: NSColor) {
    let chipPath = roundedPath(rect, radius: 28)
    fill(chipPath, color: tint)

    let iconRect = NSRect(x: rect.minX + 18, y: rect.minY + 18, width: 42, height: 52)
    let pagePath = NSBezierPath()
    pagePath.move(to: NSPoint(x: iconRect.minX + 8, y: iconRect.minY))
    pagePath.line(to: NSPoint(x: iconRect.maxX - 10, y: iconRect.minY))
    pagePath.line(to: NSPoint(x: iconRect.maxX, y: iconRect.minY + 12))
    pagePath.line(to: NSPoint(x: iconRect.maxX, y: iconRect.maxY))
    pagePath.line(to: NSPoint(x: iconRect.minX + 8, y: iconRect.maxY))
    pagePath.curve(
        to: NSPoint(x: iconRect.minX, y: iconRect.maxY - 8),
        controlPoint1: NSPoint(x: iconRect.minX + 3, y: iconRect.maxY),
        controlPoint2: NSPoint(x: iconRect.minX, y: iconRect.maxY - 3)
    )
    pagePath.line(to: NSPoint(x: iconRect.minX, y: iconRect.minY + 8))
    pagePath.curve(
        to: NSPoint(x: iconRect.minX + 8, y: iconRect.minY),
        controlPoint1: NSPoint(x: iconRect.minX, y: iconRect.minY + 3),
        controlPoint2: NSPoint(x: iconRect.minX + 3, y: iconRect.minY)
    )
    pagePath.close()
    fill(pagePath, color: NSColor.white.withAlphaComponent(0.92))

    let foldPath = NSBezierPath()
    foldPath.move(to: NSPoint(x: iconRect.maxX - 10, y: iconRect.minY))
    foldPath.line(to: NSPoint(x: iconRect.maxX - 10, y: iconRect.minY + 12))
    foldPath.line(to: NSPoint(x: iconRect.maxX, y: iconRect.minY + 12))
    foldPath.close()
    fill(foldPath, color: NSColor.white.withAlphaComponent(0.72))

    for index in 0..<2 {
        let lineRect = NSRect(x: rect.minX + 76, y: rect.minY + 46 - CGFloat(index * 18), width: rect.width - 102, height: 10)
        fill(roundedPath(lineRect, radius: 5), color: NSColor(hex: 0x1D4E89, alpha: 0.18))
    }
}

let composed = NSImage(size: size)
composed.lockFocus()

let backgroundRect = canvasRect.insetBy(dx: 36, dy: 36)
let backgroundPath = roundedPath(backgroundRect, radius: 220)
backgroundPath.addClip()
NSGradient(colors: [NSColor(hex: 0x0A7DFF), NSColor(hex: 0x25C7F2)])?.draw(in: backgroundPath, angle: 90)
fill(NSBezierPath(ovalIn: NSRect(x: 120, y: 610, width: 500, height: 240)), color: NSColor.white.withAlphaComponent(0.16))
fill(NSBezierPath(ovalIn: NSRect(x: 320, y: 40, width: 560, height: 260)), color: NSColor(hex: 0x0655C7, alpha: 0.18))

let drawerRect = NSRect(x: 560, y: 248, width: 284, height: 500)
withShadow(color: NSColor.black.withAlphaComponent(0.18), blur: 40, offset: NSSize(width: 0, height: -18)) {
    fill(roundedPath(drawerRect, radius: 66), color: NSColor(hex: 0xF5FBFF, alpha: 0.94))
}
stroke(roundedPath(drawerRect, radius: 66), color: NSColor.white.withAlphaComponent(0.48), width: 4)
fill(roundedPath(NSRect(x: drawerRect.minX + 18, y: drawerRect.maxY - 34, width: 48, height: 8), radius: 4), color: NSColor(hex: 0x1578F6, alpha: 0.18))
drawFileChip(in: NSRect(x: drawerRect.minX + 28, y: drawerRect.maxY - 150, width: drawerRect.width - 56, height: 88), tint: NSColor(hex: 0xE8F3FF))
drawFileChip(in: NSRect(x: drawerRect.minX + 28, y: drawerRect.maxY - 256, width: drawerRect.width - 56, height: 88), tint: NSColor(hex: 0xFFF0DB))
drawFileChip(in: NSRect(x: drawerRect.minX + 28, y: drawerRect.maxY - 362, width: drawerRect.width - 56, height: 88), tint: NSColor(hex: 0xE6FBF7))

let windowRect = NSRect(x: 128, y: 164, width: 548, height: 676)
withShadow(color: NSColor.black.withAlphaComponent(0.2), blur: 42, offset: NSSize(width: 0, height: -20)) {
    fill(roundedPath(windowRect, radius: 84), color: NSColor(hex: 0xFDFEFF, alpha: 0.98))
}

let windowClip = roundedPath(windowRect, radius: 84)
windowClip.addClip()
fill(NSBezierPath(rect: NSRect(x: windowRect.minX, y: windowRect.maxY - 102, width: windowRect.width, height: 102)), color: NSColor(hex: 0xF7FAFF))
fill(NSBezierPath(rect: NSRect(x: windowRect.minX, y: windowRect.minY, width: 156, height: windowRect.height)), color: NSColor(hex: 0xF1F7FF))
fill(roundedPath(NSRect(x: windowRect.minX + 186, y: windowRect.maxY - 196, width: 268, height: 24), radius: 12), color: NSColor(hex: 0xDCEBFB))
fill(roundedPath(NSRect(x: windowRect.minX + 186, y: windowRect.maxY - 242, width: 174, height: 16), radius: 8), color: NSColor(hex: 0xE7F1FC))
fill(roundedPath(NSRect(x: windowRect.minX + 34, y: windowRect.maxY - 188, width: 84, height: 18), radius: 9), color: NSColor(hex: 0xD1E6FF))
fill(roundedPath(NSRect(x: windowRect.minX + 34, y: windowRect.maxY - 224, width: 64, height: 14), radius: 7), color: NSColor(hex: 0xDEEEFF))
drawTrafficLight(at: NSPoint(x: windowRect.minX + 44, y: windowRect.maxY - 50), color: NSColor(hex: 0xFF655D))
drawTrafficLight(at: NSPoint(x: windowRect.minX + 78, y: windowRect.maxY - 50), color: NSColor(hex: 0xFFBD45))
drawTrafficLight(at: NSPoint(x: windowRect.minX + 112, y: windowRect.maxY - 50), color: NSColor(hex: 0x35C759))

drawFolder(in: NSRect(x: windowRect.minX + 194, y: windowRect.minY + 218, width: 248, height: 176))

fill(roundedPath(NSRect(x: windowRect.minX + 194, y: windowRect.minY + 150, width: 186, height: 18), radius: 9), color: NSColor(hex: 0xD7E8FB))
fill(roundedPath(NSRect(x: windowRect.minX + 194, y: windowRect.minY + 118, width: 134, height: 18), radius: 9), color: NSColor(hex: 0xE4EFFB))
fill(roundedPath(NSRect(x: windowRect.minX + 194, y: windowRect.minY + 86, width: 208, height: 18), radius: 9), color: NSColor(hex: 0xEAF3FD))

stroke(roundedPath(windowRect, radius: 84), color: NSColor.white.withAlphaComponent(0.58), width: 4)

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

if swift "${SWIFT_SCRIPT}" "${ICONSET_DIR}" > /dev/null 2>&1; then
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

# The linker's ad-hoc signature covers only the binary; sign the finished
# bundle so its resources and Info.plist are sealed too.
echo "==> Signing app bundle (ad-hoc)..."
codesign --force --sign - --identifier "${BUNDLE_ID}" "${APP_BUNDLE}"
codesign --verify --strict "${APP_BUNDLE}"

echo "==> Done!"
echo "    App bundle: ${APP_BUNDLE}"
echo ""
echo "You can now run:"
echo "    open '${APP_BUNDLE}'"
