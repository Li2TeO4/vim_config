#!/usr/bin/env bash
#
# vim_config 更新脚本
#   ./update.sh [--no-plugins]
#
# 行为：
#   1. 检查 $HOME/.vimrc 是否本仓库管理的配置（vim_config-managed 标记），
#      不是则直接退出，不做任何修改
#   2. git pull --ff-only 拉取 GitHub 最新提交
#   3. 同步 vimrc 和 schema 缓存（同步前会备份当前 vimrc）
#   4. 默认执行 :PlugInstall 补齐/更新插件（--no-plugins 可跳过）
#
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_VIMRC="$REPO_DIR/vimrc"
TARGET_VIMRC="$HOME/.vimrc"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
SCHEMA_DIR="$DATA_HOME/vim-schemas"

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

MARKER_LINE="$(grep -m1 '^" vim_config-managed:' "$SOURCE_VIMRC" || true)"
if [[ -z "$MARKER_LINE" ]]; then
  echo "错误: 仓库 vimrc 缺少 vim_config-managed 标记" >&2
  exit 1
fi

echo "== vim_config 更新 =="
echo "仓库: $REPO_DIR"

# 1) 当前系统配置归属检查（不是本仓库管理的配置就立即退出）
if [[ ! -e "$TARGET_VIMRC" && ! -L "$TARGET_VIMRC" ]]; then
  echo "检查失败：$TARGET_VIMRC 不存在，请先运行 install.sh"
  exit 1
fi
if ! grep -qF "$MARKER_LINE" "$TARGET_VIMRC" 2>/dev/null \
   || ! grep -q 'g:vim_config_managed' "$TARGET_VIMRC" 2>/dev/null; then
  echo "检查失败：当前 $TARGET_VIMRC 不是本仓库管理的配置，已退出，未做任何修改。"
  exit 1
fi
echo "[1/4] 已确认当前配置由本仓库管理"

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
echo "[2/4] 拉取远端最新提交（当前 $BEFORE）..."
if ! git pull --ff-only; then
  echo "错误: git pull 失败（网络不可用或分支需要手动处理）" >&2
  exit 1
fi
AFTER="$(git rev-parse --short HEAD)"
echo "[2/4] 仓库已更新到 $AFTER"

# 3) 同步 vimrc（当前文件与仓库不一致时先备份）
if cmp -s "$SOURCE_VIMRC" "$TARGET_VIMRC"; then
  echo "[3/4] vimrc 已是最新，无需同步"
else
  BACKUP="${TARGET_VIMRC}.bak.$(date +%Y%m%d-%H%M%S)-$$"
  cp -a "$TARGET_VIMRC" "$BACKUP"
  rm -f "$TARGET_VIMRC"
  cp "$SOURCE_VIMRC" "$TARGET_VIMRC"
  echo "[3/4] 已同步 vimrc（原文件备份 -> $BACKUP）"
fi

# 4) 同步 schema 缓存
if compgen -G "$REPO_DIR/schemas/*.json" >/dev/null; then
  mkdir -p "$SCHEMA_DIR"
  cp "$REPO_DIR"/schemas/*.json "$SCHEMA_DIR"/
  echo "[4/4] 已同步 schema 缓存 -> $SCHEMA_DIR"
else
  echo "[4/4] 仓库中没有 schemas/*.json，跳过"
fi

# 可选：补齐/更新插件
if [[ "$WITH_PLUGINS" == 1 ]] && command -v vim >/dev/null 2>&1; then
  echo "更新/补齐 vim-plug 插件..."
  if vim -Nu "$TARGET_VIMRC" -i NONE -es -c 'PlugInstall --sync' -c 'qa!' </dev/null; then
    echo "插件已同步"
  else
    echo "插件同步未完成，可稍后启动 vim 后执行 :PlugInstall"
  fi
fi

echo
if [[ "$BEFORE" == "$AFTER" ]]; then
  echo "已是最新提交（$AFTER）。启动 vim 后可执行 :VimConfigCheck。"
else
  echo "更新完成：$BEFORE -> $AFTER。启动 vim 后可执行 :VimConfigCheck。"
fi
