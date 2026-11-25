#!/bin/bash
# QuickFind 安装：app → ~/Applications；若检测到 DSH（~/.dsh/skills），顺带同步 skill
set -euo pipefail
cd "$(dirname "$0")"

APP="dist/QuickFind.app"
[[ -d "$APP" ]] || ./build.sh

DEST="$HOME/Applications"
mkdir -p "$DEST"
rm -rf "$DEST/QuickFind.app"
cp -R "$APP" "$DEST/"
xattr -dr com.apple.quarantine "$DEST/QuickFind.app" 2>/dev/null || true
echo "✅ 已安装: $DEST/QuickFind.app"
echo "   在 Spotlight / Launchpad 搜 \"QuickFind\" 即可打开"

# 可选：同步 DSH skill（非 DSH 用户自动跳过）
if [[ -d "$HOME/.dsh/skills" ]]; then
  SK="$HOME/.dsh/skills/mac-file-search"
  mkdir -p "$SK/scripts"
  cp skill/SKILL.md "$SK/SKILL.md"
  cp src/quickfind-core.sh "$SK/scripts/quickfind-core.sh"
  chmod +x "$SK/scripts/quickfind-core.sh"
  echo "✅ 已同步 DSH skill: $SK"
fi
