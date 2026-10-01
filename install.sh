#!/usr/bin/env bash
#
# vim_config 一键安装脚本
#   ./install.sh [--no-plugins]
#
# 行为：
#   1. 检测 $HOME/.vimrc：如果不是本仓库管理的配置，先备份为 .vimrc.bak.<时间戳>
#   2. 安装仓库里的 vimrc -> $HOME/.vimrc
#   3. 安装本地 schema 缓存 -> $XDG_DATA_HOME/vim-schemas（缺省 ~/.local/share/vim-schemas）
#   4. 默认执行 :PlugInstall 安装/更新 vim-plug 插件（--no-plugins 可跳过）
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
      echo "  --no-plugins  只安装配置和 schema，不自动执行 :PlugInstall"
      exit 0
      ;;
    *) echo "未知参数: $arg" >&2; exit 2 ;;
  esac
done

if [[ ! -f "$SOURCE_VIMRC" ]]; then
  echo "错误: 找不到 $SOURCE_VIMRC" >&2
  exit 1
fi

# 配置来源钩子：update.sh 和 :VimConfigCheck 也依赖这一行
MARKER_LINE="$(grep -m1 '^" vim_config-managed:' "$SOURCE_VIMRC" || true)"
if [[ -z "$MARKER_LINE" ]]; then
  echo "错误: $SOURCE_VIMRC 缺少 vim_config-managed 标记，拒绝安装" >&2
  exit 1
fi

echo "== vim_config 安装 =="
echo "仓库: $REPO_DIR"
echo "目标: $TARGET_VIMRC"

# 1) 检测原配置并备份（已经由本仓库管理的不重复备份）
if [[ -e "$TARGET_VIMRC" || -L "$TARGET_VIMRC" ]]; then
  if grep -qF "$MARKER_LINE" "$TARGET_VIMRC" 2>/dev/null; then
    echo "[1/4] 现有配置已由本仓库管理，跳过备份"
  else
    BACKUP="${TARGET_VIMRC}.bak.$(date +%Y%m%d-%H%M%S)-$$"
    cp -a "$TARGET_VIMRC" "$BACKUP"
    echo "[1/4] 检测到原配置，已备份 -> $BACKUP"
  fi
else
  echo "[1/4] 未发现现有 $TARGET_VIMRC，无需备份"
fi

# 2) 安装 vimrc（先删后拷，兼容目标原本是软链接的情况）
rm -f "$TARGET_VIMRC"
cp "$SOURCE_VIMRC" "$TARGET_VIMRC"
echo "[2/4] 已安装 vimrc -> $TARGET_VIMRC"

# 3) 安装本地 schema 缓存
if compgen -G "$REPO_DIR/schemas/*.json" >/dev/null; then
  mkdir -p "$SCHEMA_DIR"
  cp "$REPO_DIR"/schemas/*.json "$SCHEMA_DIR"/
  echo "[3/4] 已安装 schema 缓存 -> $SCHEMA_DIR"
else
  echo "[3/4] 仓库中没有 schemas/*.json，跳过（之后可用 :LspFetchSchemas 拉取）"
fi

# 4) 可选：安装/更新 vim-plug 插件
if [[ "$WITH_PLUGINS" == 1 ]]; then
  if command -v vim >/dev/null 2>&1; then
    echo "[4/4] 安装/更新 vim-plug 插件（首次会下载插件，可能较慢）..."
    if vim -Nu "$TARGET_VIMRC" -i NONE --not-a-term -c 'PlugInstall --sync' -c 'qa!' </dev/null; then
      echo "[4/4] 插件安装完成"
    else
      echo "[4/4] 插件安装未完成，可稍后启动 vim 后执行 :PlugInstall"
    fi
  else
    echo "[4/4] 未找到 vim，跳过插件安装"
  fi
else
  echo "[4/4] --no-plugins：跳过插件安装（首次启动 vim 时配置会自动补装）"
fi

echo
echo "安装完成。启动 vim 后可执行 :VimConfigCheck 自检。"
