#!/bin/zsh
# QuickFind 搜索核心 v1.1
# 用法: quickfind-core.sh <关键词> [quick|deep] [--limit N]
#   输出: 匹配文件的绝对路径，每行一条（已去重、已排除 node_modules/.git/缓存）
#   quick  只查 Spotlight 索引，全盘 0.1–0.3 秒
#   deep   在快搜结果之外，用 find 直扫索引盲区（点目录、~/Library、Homebrew、家目录、全部外接卷）
# 选项:
#   --limit N    最多输出 N 条（也支持 --limit=N / QUICKFIND_LIMIT 环境变量）
#   -h, --help   显示本说明
# 环境变量:
#   QUICKFIND_LIMIT=N       同 --limit
#   QUICKFIND_EXTRA_DIRS    深搜时追加的目录，冒号分隔，如 "$HOME/Downloads:/data"
#   QUICKFIND_FIND_DEPTH    深搜直扫深度，默认 7
# 由 QuickFind.app（GUI）与 DSH skill 调用，位置参数保持向后兼容。

KEY="$1"
[[ $# -gt 0 ]] && shift

MODE="quick"
LIMIT="${QUICKFIND_LIMIT:-0}"
DEPTH="${QUICKFIND_FIND_DEPTH:-7}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    deep)       MODE="deep" ;;
    quick|fast) MODE="quick" ;;
    --limit)    shift; LIMIT="${1:-0}" ;;
    --limit=*)  LIMIT="${1#*=}" ;;
    -h|--help)
      cat <<'USAGE'
QuickFind 搜索核心 —— macOS 双引擎文件名搜索
用法: quickfind-core.sh <关键词> [quick|deep] [--limit N]

  quick  只查 Spotlight 索引，全盘 0.1–0.3 秒（含已建索引的外接盘）
  deep   快搜结果 + find 直扫索引盲区（点目录、~/Library、Homebrew、家目录 4 层、全部外接卷）

选项:
  --limit N   最多输出 N 条
  -h, --help  本说明

环境变量:
  QUICKFIND_LIMIT      同 --limit
  QUICKFIND_EXTRA_DIRS 深搜追加目录，冒号分隔，如 "$HOME/Downloads:/data"
  QUICKFIND_FIND_DEPTH 深搜直扫深度，默认 7

输出: 每行一个绝对路径，已去重、已排除 node_modules/.git/缓存
USAGE
      exit 0 ;;
    -*)  echo "quickfind-core: 未知参数 $1（-h 看用法）" >&2; exit 2 ;;
    *)   echo "quickfind-core: 多余参数 $1（关键词只取第一个，-h 看用法）" >&2; exit 2 ;;
  esac
  shift
done

if [[ -z "$KEY" ]]; then
  echo "用法: quickfind-core.sh <关键词> [quick|deep] [--limit N]   （-h 看完整说明）" >&2
  exit 2
fi

[[ "$LIMIT" == <-> ]] || LIMIT=0
[[ "$DEPTH" == <-> ]] || DEPTH=7

export PATH=/usr/bin:/bin:/usr/sbin:/sbin

TMP=$(mktemp -t qf)
trap 'rm -f "$TMP"' EXIT

# ---------- 引擎 A：Spotlight 索引（约 0.2–0.3 秒）----------
# mdfind 默认搜全部已索引卷，含外接硬盘；这不是限制在本机系统盘
mdfind -name "$KEY" 2>/dev/null >> "$TMP"

# ---------- 引擎 B：直扫 Spotlight 不管的盲区（仅深搜时启用）----------
if [[ "$MODE" == "deep" ]]; then
  # B1. 点开头的隐藏目录 + Library 里索引不到的角 + Homebrew
  DIRS=(
    "$HOME/.config" "$HOME/.local" "$HOME/.ssh" "$HOME/.npm" "$HOME/.cache"
    "$HOME/.zsh" "$HOME/.vim" "$HOME/.oh-my-zsh"
    "$HOME/Library/Application Support"
    "/opt/homebrew" "/usr/local"
  )
  # 追加目录（冒号分隔）
  if [[ -n "$QUICKFIND_EXTRA_DIRS" ]]; then
    for d in ${(s.:.)QUICKFIND_EXTRA_DIRS}; do
      [[ -d "$d" ]] && DIRS+=("$d")
    done
  fi
  for d in "${DIRS[@]}"; do
    [[ -d "$d" ]] || continue
    find "$d" -maxdepth "$DEPTH" -iname "*${KEY}*" 2>/dev/null >> "$TMP"
  done

  # B2. 家目录整体补扫一层（含隐藏点目录，深度 4 封顶防卡）
  find "$HOME" -maxdepth 4 -iname "*${KEY}*" 2>/dev/null >> "$TMP"

  # B3. 外接卷直扫：即便某个盘没建索引（或用 FAT/exFAT 格式根本不支持索引），也能搜到
  for v in /Volumes/*/; do
    [[ -d "$v" ]] || continue
    vname=$(basename "$v")
    [[ "$vname" == "Macintosh HD" ]] && continue          # 系统盘，索引已覆盖
    [[ "$vname" == "com.apple."* ]] && continue            # 系统伪卷
    find "$v" -maxdepth 6 -iname "*${KEY}*" 2>/dev/null >> "$TMP"
  done
fi

# ---------- 去重 + 噪音过滤（+ 可选条数上限）----------
if [[ "$LIMIT" -gt 0 ]]; then
  sort -u "$TMP" \
    | grep -v -E '/(node_modules|\.git|Caches|\.Spotlight-V100|\.Trashes|\.fseventsd|\.Trash|\.TemporaryItems)/' \
    | grep -v -E '\.(download|part|tmp)$' \
    | head -n "$LIMIT"
else
  sort -u "$TMP" \
    | grep -v -E '/(node_modules|\.git|Caches|\.Spotlight-V100|\.Trashes|\.fseventsd|\.Trash|\.TemporaryItems)/' \
    | grep -v -E '\.(download|part|tmp)$'
fi
