#!/bin/bash
#
# build_and_run.sh
# -----------------------
# 构建 SelectStat，并将其打包为标准 .app bundle 后启动。
#
# 为什么需要这个脚本：
#   Swift Package Manager 默认产出"裸"可执行文件。
#   macOS 不把它当正经 App —— 状态栏图标可能不显示、
#   Accessibility 授权丢失、TCC 行为异常。
#   把可执行文件包成 .app bundle 即可解决。
#
# 用法：
#   cd ~/Documents/选区字数工具/SelectStat
#   chmod +x build_and_run.sh    # 仅首次需要
#   ./build_and_run.sh
#
# 退出 App：菜单栏"字数"图标 → 退出

set -e

cd "$(dirname "$0")"

echo "==> [1/4] 编译 SelectStat..."
swift build -c debug

BIN_DIR=$(swift build -c debug --show-bin-path)
EXEC="$BIN_DIR/SelectStat"

if [ ! -f "$EXEC" ]; then
  echo "❌ 编译产物未找到: $EXEC"
  exit 1
fi

APP_DIR="build/SelectStat.app"
echo "==> [2/4] 打包 .app bundle 到 $APP_DIR ..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"
cp "$EXEC" "$APP_DIR/Contents/MacOS/SelectStat"
chmod +x "$APP_DIR/Contents/MacOS/SelectStat"

# Info.plist —— 关键的 bundle 元数据
cat > "$APP_DIR/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.local.SelectStat</string>
    <key>CFBundleName</key>
    <string>SelectStat</string>
    <key>CFBundleDisplayName</key>
    <string>选区字数</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>SelectStat</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "==> [3/4] 在 LaunchServices 注册..."
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
if [ -x "$LSREGISTER" ]; then
  "$LSREGISTER" -f "$APP_DIR" 2>/dev/null || true
fi

# 固定代码签名身份 —— 避免每次 build 后 TCC 认为是「新的 App」
echo "==> [3.5] 固定代码签名身份..."
codesign --force --deep --sign - --identifier com.local.SelectStat "$APP_DIR" 2>/dev/null
codesign --force --sign - --identifier com.local.SelectStat --options runtime --preserve-metadata=identifier,entitlements "$APP_DIR/Contents/MacOS/SelectStat" 2>/dev/null || true
echo "    ✓ 签名身份已固化为 com.local.SelectStat"

# 先杀掉任何残留的旧实例
killall SelectStat 2>/dev/null || true

echo "==> [4/4] 启动 $APP_DIR ..."
open "$APP_DIR"

echo
echo "✅ 启动完成。"
echo "   → 看屏幕右上角菜单栏，找'字数'图标"
echo "   → 第一次会跳出辅助功能授权面板，照着勾上即可"
echo "   → 退出方式：菜单栏'字数'图标 → 退出"
