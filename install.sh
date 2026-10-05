#!/usr/bin/env bash
#
# vim_config 一键安装脚本
#   ./install.sh [--no-plugins]
#
# 安装布局（XDG）：
#   $XDG_CONFIG_HOME/vim/vimrc        入口文件
#   $XDG_CONFIG_HOME/vim/configs/   拆分后的配置片段
#   $XDG_CONFIG_HOME/vim/README.md    <leader>? 查看的说明文档
#   $XDG_DATA_HOME/vim-schemas/       schema 缓存
#
# 注意：Unix 下 Vim 只有在 ~/.vimrc 和 ~/.vim/vimrc 都不存在时才会读取
#       $XDG_CONFIG_HOME/vim/vimrc，所以脚本会先备份并移除这两个旧位置的文件。
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
if [[ ! -d "$SOURCE_CONFIGS" ]]; then
  echo "错误: 找不到配置片段目录 $SOURCE_CONFIGS" >&2
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
echo "配置目录: $CONFIG_HOME"

# 1) 处理旧位置：~/.vimrc 和 ~/.vim/vimrc 会优先于 XDG 配置，必须让位
for f in "${LEGACY_VIMRCS[@]}"; do
  if [[ -e "$f" || -L "$f" ]]; then
    BACKUP="${f}.bak.$(date +%Y%m%d-%H%M%S)-$$"
    cp -a "$f" "$BACKUP"
    rm -rf "$f"
    echo "[1/4] 旧配置已备份并移除: $f -> $BACKUP"
  fi
done

# 当前 XDG 配置不是本仓库管理时，先备份
if [[ -e "$TARGET_VIMRC" || -L "$TARGET_VIMRC" ]]; then
  if grep -qF "$MARKER_LINE" "$TARGET_VIMRC" 2>/dev/null; then
    echo "[1/4] 现有 XDG 配置已由本仓库管理，跳过备份"
  else
    BACKUP="${TARGET_VIMRC}.bak.$(date +%Y%m%d-%H%M%S)-$$"
    cp -a "$TARGET_VIMRC" "$BACKUP"
    echo "[1/4] 检测到原 XDG 配置，已备份 -> $BACKUP"
  fi
else
  echo "[1/4] 未发现现有 XDG 配置，无需备份"
fi

# 2) 安装入口 vimrc + configs + README
mkdir -p "$CONFIG_HOME"
rm -f "$TARGET_VIMRC"
cp "$SOURCE_VIMRC" "$TARGET_VIMRC"
rm -rf "$TARGET_CONFIGS"
cp -a "$SOURCE_CONFIGS" "$TARGET_CONFIGS"
# 兼容更早版本的 XDG 拆分布局：旧目录名是 fragments/
if [[ -d "$CONFIG_HOME/fragments" ]]; then
  rm -rf "$CONFIG_HOME/fragments"
  echo "[2/4] 已清理旧 fragments 目录 -> $CONFIG_HOME/fragments"
fi
if [[ -f "$SOURCE_README" ]]; then
  cp "$SOURCE_README" "$TARGET_README"
fi
echo "[2/4] 已安装入口 -> $TARGET_VIMRC"
echo "[2/4] 已安装片段 -> $TARGET_CONFIGS"
if [[ -f "$SOURCE_README" ]]; then
  echo "[2/4] 已安装说明 -> $TARGET_README"
fi

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
    if vim -Nu "$TARGET_VIMRC" -i NONE -es -c 'PlugInstall --sync' -c 'qa!' </dev/null; then
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
echo "安装完成："
echo "  配置入口: $TARGET_VIMRC"
echo "  配置片段: $TARGET_CONFIGS"
if [[ -f "$TARGET_README" ]]; then
  echo "  使用说明: $TARGET_README（Vim 里按 <leader>?）"
fi
echo "启动 vim 后可执行 :VimConfigCheck 自检。"
