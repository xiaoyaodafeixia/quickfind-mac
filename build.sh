#!/bin/bash
# QuickFind 打包：从源码构建自包含的 QuickFind.app
# 用法: ./build.sh          产物: ./dist/QuickFind.app
# 只需系统自带工具（osacompile / PlistBuddy / codesign），无需 Xcode 项目、无需联网。
set -euo pipefail
cd "$(dirname "$0")"

SRC="src/QuickFind.applescript"
CORE="src/quickfind-core.sh"
OUT="dist/QuickFind.app"

command -v osacompile >/dev/null 2>&1 || {
  echo "缺少 osacompile：请先安装 Xcode 命令行工具（xcode-select --install）"; exit 1; }

mkdir -p dist
rm -rf "$OUT"
osacompile -o "$OUT" "$SRC"

# osacompile 会默认塞进 10 条用不到的隐私权限声明（麦克风/相机/通讯录/日历/相册/Siri/HomeKit/AppleMusic/提醒事项/系统管理）。
# 一个找文件的工具不该声称要这些权限，逐条删掉（键不存在则跳过）。
PLIST="$OUT/Contents/Info.plist"
for k in NSAppleMusicUsageDescription NSCalendarsUsageDescription NSCameraUsageDescription \
         NSContactsUsageDescription NSHomeKitUsageDescription NSMicrophoneUsageDescription \
         NSPhotoLibraryUsageDescription NSRemindersUsageDescription NSSiriUsageDescription \
         NSSystemAdministrationUsageDescription; do
  /usr/libexec/PlistBuddy -c "Delete :$k" "$PLIST" 2>/dev/null || true
done

# 搜索核心必须拷进 app 内（app 运行时调的是 Contents/Resources 里那份，不拷就跑不起来）
cp "$CORE" "$OUT/Contents/Resources/quickfind-core.sh"
chmod +x "$OUT/Contents/Resources/quickfind-core.sh"

# ad-hoc 签名，本机自用足够；对外分发请换成 Developer ID
codesign --force --deep --sign - "$OUT" 2>/dev/null

echo "✅ 构建完成: $OUT"
echo "   安装: ./install.sh"
