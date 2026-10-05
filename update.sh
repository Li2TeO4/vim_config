#!/usr/bin/env bash
#
# vim_config 更新脚本
#   ./update.sh [--no-plugins]
#
# 行为：
#   1. 检查 $XDG_CONFIG_HOME/vim/vimrc 是否本仓库管理的入口配置，
#      并确认旧位置（~/.vimrc、~/.vim/vimrc）没有抢占 XDG 配置
#   2. git pull --ff-only 拉取 GitHub 最新提交
#   3. 同步 vimrc、configs/、README.md（有变化时先备份当前配置目录）
#   4. 默认执行 :PlugInstall 补齐/更新插件（--no-plugins 可跳过）
#
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_VIMRC="$REPO_DIR/vimrc"
SOURCE_CONFIGS="$REPO_DIR/configs"
SOURCE_README="$REPO_DIR/README.md"

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/vim"
TARGET_VIMRC="$CONFIG_HOME/vimrc"
TARGET_CONFIGS="$CONFIG_HOME/configs"
TARGET_README="$CONFIG_HOME/README.md"

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
SCHEMA_DIR="$DATA_HOME/vim-schemas"

LEGACY_VIMRCS=("$HOME/.vimrc" "$HOME/.vim/vimrc")

WITH_PLUGINS=1
for arg in "$@"; do
  case "$arg" in
    --no-plugins) WITH_PLUGINS=0 ;;
    -h|--help)
      echo "用法: $0 [--no-plugins]"
      exit 0
      ;;
    *) echo "未知参数: $arg" >&2; exit 2 ;;
  esac
done

if [[ ! -f "$SOURCE_VIMRC" ]]; then
  echo "错误: 找不到 $SOURCE_VIMRC" >&2
  exit 1
fi
if [[ ! -d "$SOURCE_CONFIGS" ]]; then
  echo "错误: 找不到配置片段目录 $SOURCE_CONFIGS" >&2
  exit 1
fi

MARKER_LINE="$(grep -m1 '^" vim_config-managed:' "$SOURCE_VIMRC" || true)"
if [[ -z "$MARKER_LINE" ]]; then
  echo "错误: 仓库 vimrc 缺少 vim_config-managed 标记" >&2
  exit 1
fi

echo "== vim_config 更新 =="
echo "仓库: $REPO_DIR"
echo "配置目录: $CONFIG_HOME"

# 1) 当前系统配置归属检查，以及旧位置冲突检查
if [[ ! -e "$TARGET_VIMRC" && ! -L "$TARGET_VIMRC" ]]; then
  echo "检查失败：$TARGET_VIMRC 不存在，请先运行 install.sh"
  exit 1
fi
if ! grep -qF "$MARKER_LINE" "$TARGET_VIMRC" 2>/dev/null \
   || ! grep -q 'g:vim_config_managed' "$TARGET_VIMRC" 2>/dev/null; then
  echo "检查失败：当前 $TARGET_VIMRC 不是本仓库管理的配置，已退出，未做任何修改。"
  exit 1
fi
if [[ ! -d "$TARGET_CONFIGS" ]]; then
  echo "检查失败：$TARGET_CONFIGS 不存在，请先运行 install.sh 完成迁移。"
  exit 1
fi
for f in "${LEGACY_VIMRCS[@]}"; do
  if [[ -e "$f" || -L "$f" ]]; then
    echo "检查失败：检测到旧位置配置 $f，Vim 会优先读取它并忽略 XDG 配置。"
    echo "         请先运行 ./install.sh（会自动备份并移除旧配置），未做任何修改。"
    exit 1
  fi
done
echo "[1/5] 已确认当前 XDG 配置由本仓库管理，旧位置无冲突"

# 2) 拉取 GitHub 最新提交
cd "$REPO_DIR"
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "错误: $REPO_DIR 不是 git 仓库" >&2
  exit 1
fi
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "错误: 仓库存在未提交改动，已退出，避免覆盖本地修改" >&2
  exit 1
fi
BEFORE="$(git rev-parse --short HEAD)"
echo "[2/5] 拉取远端最新提交（当前 $BEFORE）..."
if ! git pull --ff-only; then
  echo "错误: git pull 失败（网络不可用或分支需要手动处理）" >&2
  exit 1
fi
AFTER="$(git rev-parse --short HEAD)"
echo "[2/5] 仓库已更新到 $AFTER"

# 3) 同步 vimrc / configs / README（有变化时先备份当前配置目录）
NEED_SYNC=0
if ! cmp -s "$SOURCE_VIMRC" "$TARGET_VIMRC"; then
  NEED_SYNC=1
fi
if ! diff -qr "$SOURCE_CONFIGS" "$TARGET_CONFIGS" >/dev/null 2>&1; then
  NEED_SYNC=1
fi
if [[ -f "$SOURCE_README" ]] && { [[ ! -f "$TARGET_README" ]] || ! cmp -s "$SOURCE_README" "$TARGET_README"; }; then
  NEED_SYNC=1
fi

if (( NEED_SYNC )); then
  BACKUP_DIR="${CONFIG_HOME}.bak.$(date +%Y%m%d-%H%M%S)-$$"
  cp -a "$CONFIG_HOME" "$BACKUP_DIR"
  rm -f "$TARGET_VIMRC"
  cp "$SOURCE_VIMRC" "$TARGET_VIMRC"
  rm -rf "$TARGET_CONFIGS"
  cp -a "$SOURCE_CONFIGS" "$TARGET_CONFIGS"
  if [[ -f "$SOURCE_README" ]]; then
    cp "$SOURCE_README" "$TARGET_README"
  fi
  echo "[3/5] 已同步 vimrc / configs / README（原配置备份 -> $BACKUP_DIR）"
else
  echo "[3/5] 配置文件已是最新，无需同步"
fi

# 兼容更早版本的 XDG 拆分布局：旧目录名是 fragments/
if [[ -d "$CONFIG_HOME/fragments" ]]; then
  rm -rf "$CONFIG_HOME/fragments"
  echo "[3/5] 已清理旧 fragments 目录 -> $CONFIG_HOME/fragments"
fi

# 4) 同步 schema 缓存
if compgen -G "$REPO_DIR/schemas/*.json" >/dev/null; then
  mkdir -p "$SCHEMA_DIR"
  cp "$REPO_DIR"/schemas/*.json "$SCHEMA_DIR"/
  echo "[4/5] 已同步 schema 缓存 -> $SCHEMA_DIR"
else
  echo "[4/5] 仓库中没有 schemas/*.json，跳过"
fi

# 5) 可选：补齐/更新插件
if [[ "$WITH_PLUGINS" == 1 ]] && command -v vim >/dev/null 2>&1; then
  echo "[5/5] 更新/补齐 vim-plug 插件..."
  if vim -Nu "$TARGET_VIMRC" -i NONE -es -c 'PlugInstall --sync' -c 'qa!' </dev/null; then
    echo "[5/5] 插件已同步"
  else
    echo "[5/5] 插件同步未完成，可稍后启动 vim 后执行 :PlugInstall"
  fi
else
  echo "[5/5] --no-plugins 或未找到 vim，跳过插件同步"
fi

echo
if [[ "$BEFORE" == "$AFTER" ]]; then
  echo "已是最新提交（$AFTER）。启动 vim 后可执行 :VimConfigCheck。"
else
  echo "更新完成：$BEFORE -> $AFTER。启动 vim 后可执行 :VimConfigCheck。"
fi
