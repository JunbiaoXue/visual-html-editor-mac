#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
app='build/网页可视化编辑器.app'
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
swiftc Sources/main.swift -o "$app/Contents/MacOS/Editor" -framework Cocoa -framework WebKit
codesign --force --deep --sign - "$app"
echo "已生成：$app"
