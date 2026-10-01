#!/usr/bin/env bash
#
# language-server-add.sh
# 用系统包管理器补充缺失的 LSP server（已有系统/用户级可执行文件的会跳过）。
#
# 用法:
#   ./language-server-add.sh [--yes] [--dry-run] [--list] [--manager NAME]
#
#   --yes, -y       不交互确认（Arch 会加 --noconfirm）
#   --dry-run, -n   只打印计划和将执行的命令，不实际安装
#   --list          列出当前包管理器对应的 server/包名映射
#   --manager NAME  强制指定包管理器：pacman/apt/dnf/zypper/apk/brew
#
set -euo pipefail

# 与 .vimrc 的探测保持一致：用户级安装目录也在 PATH 里
export PATH="$HOME/.local/bin:$HOME/bin:${PATH:-/usr/bin:/bin}"

ASSUME_YES=0
DRY_RUN=0
LIST_ONLY=0
MGR_OVERRIDE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes)       ASSUME_YES=1 ;;
    -n|--dry-run)   DRY_RUN=1 ;;
    --list)         LIST_ONLY=1 ;;
    --manager)      MGR_OVERRIDE="${2:-}"; shift ;;
    -h|--help)
      sed -n '3,13p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "未知参数: $1" >&2; exit 2 ;;
  esac
  shift
done

detect_manager() {
  if command -v pacman >/dev/null 2>&1; then echo pacman
  elif command -v apt-get >/dev/null 2>&1; then echo apt
  elif command -v dnf >/dev/null 2>&1; then echo dnf
  elif command -v zypper >/dev/null 2>&1; then echo zypper
  elif command -v apk >/dev/null 2>&1; then echo apk
  elif command -v brew >/dev/null 2>&1; then echo brew
  else echo unknown; fi
}

MGR="${MGR_OVERRIDE:-$(detect_manager)}"

# 权限前缀（brew 不需要；其余系统包管理器需要 root）
SUDO=()
if [[ "$MGR" != "brew" && "$MGR" != "unknown" && "$EUID" -ne 0 ]]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO=(sudo)
  elif command -v doas >/dev/null 2>&1; then
    SUDO=(doas)
  else
    echo "错误: 安装系统包需要 root/sudo/doas 权限" >&2
    exit 1
  fi
fi

run_with_sudo() {
  if (( ${#SUDO[@]} )); then "${SUDO[@]}" "$@"; else "$@"; fi
}

# 找可执行文件：PATH + vim-lsp-settings 的 servers 目录
resolve_cmd() {
  local c="$1"
  if command -v "$c" >/dev/null 2>&1; then
    command -v "$c"
    return 0
  fi
  local d="$HOME/.local/share/vim-lsp-settings/servers"
  if [[ -d "$d" ]]; then
    if [[ -x "$d/$c" ]]; then echo "$d/$c"; return 0; fi
    local hit
    hit="$(find "$d" -maxdepth 3 -type f -name "$c" -perm -u+x 2>/dev/null | head -n1 || true)"
    if [[ -n "$hit" ]]; then echo "$hit"; return 0; fi
  fi
  return 1
}

have_cmd() { resolve_cmd "$1" >/dev/null 2>&1; }

# key|显示名|期望的命令|备选命令（可空）
SERVERS=(
  "json|JSON|vscode-json-language-server|vscode-json-languageserver"
  "yaml|YAML|yaml-language-server|"
  "toml|TOML|taplo-lsp|taplo"
  "bash|Bash|bash-language-server|"
  "dockerfile|Dockerfile|docker-langserver|"
  "markdown|Markdown|marksman|"
  "vim|Vim script|vim-language-server|"
  "xml|XML|lemminx|"
  "systemd|systemd|systemd-lsp|"
  "cmake|CMake|cmake-language-server|"
  "lua|Lua|sumneko-lua-language-server|lua-language-server"
  "terraform|Terraform|terraform-ls|"
  "fish|Fish|fish-lsp|"
  "bzl|Bazel/Starlark|starpls|"
  "just|just|just-lsp|"
  "kdl|KDL|kdl-lsp|"
)

# 各系统包管理器对应的包名；查不到就返回空，脚本会跳过并给出提示
pkg_for() {
  local key="$1"
  case "$MGR:$key" in
    pacman:json)       echo vscode-json-languageserver ;;
    pacman:yaml)       echo yaml-language-server ;;
    pacman:toml)       echo taplo-cli ;;
    pacman:bash)       echo bash-language-server ;;
    pacman:dockerfile) echo dockerfile-language-server ;;
    pacman:markdown)   echo marksman ;;
    pacman:vim)        echo vim-language-server ;;
    pacman:xml)        echo lemminx ;;
    pacman:systemd)    echo systemd-lsp ;;
    pacman:cmake)      echo cmake-language-server ;;
    pacman:lua)        echo lua-language-server ;;
    pacman:terraform)  echo terraform-ls ;;
    pacman:fish)       echo fish-lsp ;;
    pacman:just)       echo just-lsp ;;
    pacman:kdl)        echo kdl-lsp ;;

    pacman:shellcheck) echo shellcheck ;;

    apt:json)          echo vscode-json-languageserver ;;
    apt:yaml)          echo yaml-language-server ;;
    apt:toml)          echo taplo ;;
    apt:bash)          echo bash-language-server ;;
    apt:dockerfile)    echo dockerfile-language-server ;;
    apt:markdown)      echo marksman ;;
    apt:vim)           echo vim-language-server ;;
    apt:xml)           echo lemminx ;;
    apt:systemd)       echo systemd-lsp ;;
    apt:cmake)         echo cmake-language-server ;;
    apt:lua)           echo lua-language-server ;;
    apt:terraform)     echo terraform-ls ;;
    apt:fish)          echo fish-lsp ;;
    apt:just)           echo just ;;

    apt:shellcheck)    echo shellcheck ;;

    dnf:json)          echo vscode-json-languageserver ;;
    dnf:yaml)          echo yaml-language-server ;;
    dnf:toml)          echo taplo ;;
    dnf:bash)          echo bash-language-server ;;
    dnf:dockerfile)    echo dockerfile-language-server ;;
    dnf:markdown)      echo marksman ;;
    dnf:vim)           echo vim-language-server ;;
    dnf:xml)           echo lemminx ;;
    dnf:systemd)       echo systemd-lsp ;;
    dnf:cmake)         echo cmake-language-server ;;
    dnf:lua)           echo lua-language-server ;;
    dnf:terraform)     echo terraform-ls ;;
    dnf:fish)          echo fish-lsp ;;
    dnf:just)           echo just ;;

    dnf:shellcheck)    echo shellcheck ;;

    zypper:json)       echo vscode-json-languageserver ;;
    zypper:yaml)       echo yaml-language-server ;;
    zypper:toml)       echo taplo ;;
    zypper:bash)       echo bash-language-server ;;
    zypper:dockerfile) echo dockerfile-language-server ;;
    zypper:markdown)   echo marksman ;;
    zypper:vim)        echo vim-language-server ;;
    zypper:xml)        echo lemminx ;;
    zypper:systemd)    echo systemd-lsp ;;
    zypper:cmake)      echo cmake-language-server ;;
    zypper:lua)        echo lua-language-server ;;
    zypper:terraform)  echo terraform-ls ;;
    zypper:fish)       echo fish-lsp ;;
    zypper:just)        echo just ;;

    zypper:shellcheck) echo shellcheck ;;

    apk:json)          echo vscode-json-languageserver ;;
    apk:yaml)          echo yaml-language-server ;;
    apk:toml)          echo taplo ;;
    apk:bash)          echo bash-language-server ;;
    apk:dockerfile)    echo dockerfile-language-server ;;
    apk:markdown)      echo marksman ;;
    apk:vim)           echo vim-language-server ;;
    apk:xml)           echo lemminx ;;
    apk:systemd)       echo systemd-lsp ;;
    apk:cmake)         echo cmake-language-server ;;
    apk:lua)           echo lua-language-server ;;
    apk:terraform)     echo terraform-ls ;;
    apk:fish)          echo fish-lsp ;;
    apk:just)           echo just ;;

    apk:shellcheck)    echo shellcheck ;;

    brew:json)         echo vscode-json-languageserver ;;
    brew:yaml)         echo yaml-language-server ;;
    brew:toml)         echo taplo ;;
    brew:bash)         echo bash-language-server ;;
    brew:dockerfile)   echo dockerfile-language-server ;;
    brew:markdown)     echo marksman ;;
    brew:vim)          echo vim-language-server ;;
    brew:xml)          echo lemminx ;;
    brew:systemd)      echo systemd-lsp ;;
    brew:cmake)        echo cmake-language-server ;;
    brew:lua)          echo lua-language-server ;;
    brew:terraform)    echo terraform-ls ;;
    brew:fish)         echo fish-lsp ;;
    brew:just)          echo just ;;

    brew:shellcheck)   echo shellcheck ;;

    *) echo "" ;;
  esac
}

manual_note() {
  case "$1" in
    bzl) echo "无系统包；请在 bzl 文件里用 :LspInstallServer，或手动下载 starpls" ;;
    fish) echo "需要手动安装（Arch: fish-lsp 包；其他系统找上游发布包或用编辑器安装脚本）" ;;
    just) echo "可用 :LspInstallServer 安装" ;;
    kdl) echo "通过 :LspInstallServer 装不了；Arch 用 kdl-lsp 包，其他系统请手动编译安装" ;;
    *) echo "" ;;
  esac
}

pkg_note() {
  case "$MGR:$1" in
    pacman:lemminx) echo "需要 java-runtime，pacman 会自动安装这个依赖（体积较大）" ;;
    *) echo "" ;;
  esac
}

pkg_available() {
  local pkg="$1"
  [[ -n "$pkg" ]] || return 1
  case "$MGR" in
    pacman) pacman -Si "$pkg" >/dev/null 2>&1 ;;
    apt)    apt-cache show "$pkg" >/dev/null 2>&1 ;;
    dnf)    dnf -q list --available "$pkg" >/dev/null 2>&1 ;;
    zypper) zypper --quiet --non-interactive search --match-exact "$pkg" >/dev/null 2>&1 ;;
    apk)    apk search -x -e "$pkg" >/dev/null 2>&1 ;;
    brew)   brew info "$pkg" >/dev/null 2>&1 ;;
    *)      return 1 ;;
  esac
}

if (( LIST_ONLY )); then
  echo "当前包管理器: $MGR"
  printf '%-10s %-32s %s\n' "键" "server 命令" "系统包名"
  printf '%-10s %-32s %s\n' "----" "------------------------------" "--------"
  for row in "${SERVERS[@]}"; do
    IFS='|' read -r key label cmd alt <<<"$row"
    pkg="$(pkg_for "$key")"
    printf '%-10s %-32s %s\n' "$key" "$cmd" "${pkg:-（无对应包）}"
  done
  printf '%-10s %-32s %s\n' "shellcheck" "shellcheck（可选）" "$(pkg_for shellcheck)"
  exit 0
fi

if [[ "$MGR" == "unknown" ]]; then
  echo "未能识别系统包管理器。请使用 Vim 内的 :VimConfigFix / :LspInstallServer 安装，"
  echo "或手动安装后用 :VimConfigCheck 确认。"
  exit 0
fi

echo "== 系统包管理器补充 LSP server =="
echo "包管理器: $MGR"
echo "PATH 额外包含: $HOME/.local/bin, $HOME/bin"
echo

declare -a PLAN_PKGS=()
declare -a PLAN_KEYS=()
declare -a PLAN_CMDS=()
declare -a PLAN_NOTES=()

add_pkg() {
  local pkg="$1"
  local existing
  for existing in "${PLAN_PKGS[@]}"; do
    [[ "$existing" == "$pkg" ]] && return 0
  done
  PLAN_PKGS+=("$pkg")
}

for row in "${SERVERS[@]}"; do
  IFS='|' read -r key label cmd alt <<<"$row"
  if resolved="$(resolve_cmd "$cmd")"; then
    echo "[$label] 已存在: $cmd -> $resolved"
    continue
  fi
  if [[ -n "$alt" ]] && resolved="$(resolve_cmd "$alt")"; then
    echo "[$label] 已存在备选命令: $alt -> $resolved（稍后补 $cmd 兼容软链）"
    continue
  fi
  pkg="$(pkg_for "$key")"
  if [[ -z "$pkg" ]]; then
    note="$(manual_note "$key")"
    if [[ -n "$note" ]]; then
      echo "[$label] 缺失：$note"
      PLAN_NOTES+=("$label: $note")
    else
      echo "[$label] 缺失，但 $MGR 没有配置对应包，请用 :VimConfigFix / :LspInstallServer"
      PLAN_NOTES+=("$label: 无系统包，建议 :VimConfigFix / :LspInstallServer")
    fi
    continue
  fi
  if ! pkg_available "$pkg"; then
    echo "[$label] 缺失，包 '$pkg' 在当前源中不可用（可能需要先配置额外仓库）"
    PLAN_NOTES+=("$label: $pkg 当前源不可用，建议 :LspInstallServer")
    continue
  fi
  echo "[$label] 缺失 -> 计划安装系统包: $pkg"
  pkg_note_text="$(pkg_note "$pkg")"
  [[ -n "$pkg_note_text" ]] && echo "      注意: $pkg_note_text"
  add_pkg "$pkg"
  PLAN_KEYS+=("$key")
  PLAN_CMDS+=("$cmd")
done

# “shellcheck” 是可选的 bash 诊断增强，缺失也一并装
if ! have_cmd shellcheck; then
  pkg="$(pkg_for shellcheck)"
  if [[ -n "$pkg" ]] && pkg_available "$pkg"; then
    echo "[Bash 增强] shellcheck 缺失 -> 计划安装: $pkg"
    add_pkg "$pkg"
  else
    echo "[Bash 增强] shellcheck 缺失（可选，跳过）"
  fi
fi

echo
if (( ${#PLAN_PKGS[@]} == 0 )); then
  echo "没有需要通过系统包管理器安装的项。"
else
  echo "计划安装系统包: ${PLAN_PKGS[*]}"
fi
if (( ${#PLAN_NOTES[@]} > 0 )); then
  echo "需要手动处理:"
  printf '  - %s\n' "${PLAN_NOTES[@]}"
fi

if (( ${#PLAN_PKGS[@]} == 0 )); then
  :
elif (( DRY_RUN )); then
  echo "[dry-run] 将执行: $MGR install ${PLAN_PKGS[*]}"
else
  if (( ! ASSUME_YES )); then
    read -r -p "继续安装? [y/N] " ans
    case "$ans" in
      y|Y|yes|YES) ;;
      *) echo "已取消"; exit 1 ;;
    esac
  fi
  case "$MGR" in
    pacman)
      flags=(-S --needed)
      (( ASSUME_YES )) && flags+=(--noconfirm)
      run_with_sudo pacman "${flags[@]}" "${PLAN_PKGS[@]}"
      ;;
    apt)    run_with_sudo apt-get install -y "${PLAN_PKGS[@]}" ;;
    dnf)    run_with_sudo dnf install -y "${PLAN_PKGS[@]}" ;;
    zypper) run_with_sudo zypper --non-interactive install "${PLAN_PKGS[@]}" ;;
    apk)    run_with_sudo apk add "${PLAN_PKGS[@]}" ;;
    brew)   brew install "${PLAN_PKGS[@]}" ;;
  esac
fi

# 包名和配置期望的命令名不一致时补兼容软链
if (( DRY_RUN )); then
  echo "[dry-run] 安装后会检查并补 taplo-lsp / vscode-json-language-server / sumneko-lua-language-server 兼容软链"
else
  mkdir -p "$HOME/.local/bin"
  if command -v taplo >/dev/null 2>&1 && ! command -v taplo-lsp >/dev/null 2>&1; then
    ln -sf "$(command -v taplo)" "$HOME/.local/bin/taplo-lsp"
    echo "已补兼容软链: taplo-lsp -> $(command -v taplo)"
  fi
  if command -v vscode-json-languageserver >/dev/null 2>&1 \
     && ! command -v vscode-json-language-server >/dev/null 2>&1; then
    ln -sf "$(command -v vscode-json-languageserver)" "$HOME/.local/bin/vscode-json-language-server"
    echo "已补兼容软链: vscode-json-language-server -> $(command -v vscode-json-languageserver)"
  fi
  # vim-lsp-settings 认的名字是 sumneko-lua-language-server，Arch 包二进制叫 lua-language-server
  if command -v lua-language-server >/dev/null 2>&1 \
     && ! command -v sumneko-lua-language-server >/dev/null 2>&1; then
    ln -sf "$(command -v lua-language-server)" "$HOME/.local/bin/sumneko-lua-language-server"
    echo "已补兼容软链: sumneko-lua-language-server -> $(command -v lua-language-server)"
  fi
fi

# 最终确认
echo
echo "== 检查结果 =="
missing=0
for row in "${SERVERS[@]}"; do
  IFS='|' read -r key label cmd alt <<<"$row"
  if resolved="$(resolve_cmd "$cmd")"; then
    printf '%-12s OK   %s\n' "$label" "$resolved"
  elif [[ -n "$alt" ]] && resolved="$(resolve_cmd "$alt")"; then
    printf '%-12s OK   %s（备选命令；软链可能需重开 shell 生效）\n' "$label" "$resolved"
  else
    printf '%-12s 缺失 %s\n' "$label" "$cmd"
    missing=1
  fi
done
if ! have_cmd shellcheck; then
  echo "（可选）shellcheck 仍缺失，不影响 LSP 本体"
fi

echo
echo "完成。启动 vim 后执行 :VimConfigCheck 确认；"
echo "用户级安装方式仍可用 :VimConfigFix / :LspInstallServer。"
exit $missing
