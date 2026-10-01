# vim_config

> 面向“改配置文件”场景的轻量 Vim 配置：启动快、支持 LSP + Schema 校验、
> Catppuccin Mocha 主题，并带一键安装、一键修复、配置更新和换机自检脚本。
>
> 写代码用 Neovim（配置在 `~/.config/nvim`）；这份配置只服务于用 Vim 改
> json/yaml/toml/shell/dockerfile/markdown/vim script 等文件的场景。

---

## 目录

- [特性](#特性)
- [仓库结构](#仓库结构)
- [环境要求](#环境要求)
- [一键安装](#一键安装)
- [首次启动与首次使用](#首次启动与首次使用)
- [更新配置](#更新配置)
- [换机自检](#换机自检)
- [一键修复](#一键修复)
- [键位速查](#键位速查)
- [LSP 与 Schema 校验](#lsp-与-schema-校验)
- [主题](#主题)
- [可移植性设计](#可移植性设计)
- [常见问题](#常见问题)
- [卸载与恢复](#卸载与恢复)
- [维护本仓库](#维护本仓库)
- [第三方组件](#第三方组件)

---

## 特性

- **轻量启动**：不打开对应类型的文件就不会启动 LSP server，实测启动约 20–40ms。
- **LSP**：`vim-lsp` + `vim-lsp-settings`，覆盖 json/jsonc、yaml、toml、bash、
  dockerfile、markdown、vim script。
- **自动补全**：`asyncomplete.vim` + `asyncomplete-lsp.vim`，Alt+j/k 选择，
  Tab/回车确认。
- **Schema 校验**：
  - JSON / YAML 使用 `vim-lsp-settings` 自带的 SchemaStore 目录（1000+ 条），
    按文件名自动匹配，也支持文件内 `$schema`；
  - TOML 使用 taplo，本地缓存了 Cargo / pyproject / rustfmt / rust-toolchain 的
    schema；
  - docker-compose 使用本地 `compose-spec.json`。
- **主题**：官方 `catppuccin/vim`，Mocha 配色 + 透明背景，行号 / 注释颜色对齐
  Neovim 那边的配置。
- **系统剪贴板**：`Y` / `P` 走系统剪贴板，Wayland / X11 / macOS 自动探测；
  复制命令做了 stdout/stderr 重定向，避免 `wl-copy`/`xclip` fork 常驻进程导致 `Y` 卡住。
- **可移植**：XDG 路径、`vim-plug` 自举、缺插件自动安装、schema 本地优先 /
  远程回退、最小 Vim 自动跳过 LSP。
- **换机自检**：`:VimConfigCheck` 一次列出特性、插件、server、schema、剪贴板等
  状态和补装入口。
- **一键修复**：`:VimConfigFix` 自动补插件和 schema，并调用 vim-lsp-settings
  安装缺失的 LSP server。

---

## 仓库结构

```
vim_config/
├── install.sh        # 一键安装：备份原配置 + 部署 vimrc/schema + 装插件
├── update.sh         # 更新：校验归属后 git pull，再同步 vimrc/schema
├── vimrc             # 主配置，安装后放到 ~/.vimrc
├── schemas/          # 本地 schema 缓存（TOML 常用文件 + docker-compose）
│   ├── cargo.json
│   ├── pyproject.json
│   ├── rustfmt.json
│   ├── rust-toolchain.json
│   └── compose-spec.json
└── README.md
```

配置里带有来源标记（**不要删除**，安装/更新脚本靠它识别归属）：

```vim
" vim_config-managed: https://github.com/Li2TeO4/vim_config
let g:vim_config_managed = 'Li2TeO4/vim_config'
```

---

## 环境要求

| 项 | 说明 |
|---|---|
| Vim | 推荐 9.x（本配置在 Vim 9.2 上开发验证）；Vim 8 若带 `+timers +lambda +job` 等也可用 |
| git | 安装/更新、插件管理 |
| curl / wget | `vim-plug` 自举、`:LspFetchSchemas` 下载 schema |
| node / npm | 部分 LSP server 的安装方式（`vscode-json-language-server`、`yaml-language-server`、`vim-language-server` 等），也可用系统包管理器 |
| 剪贴板 | 可选：Wayland 的 `wl-clipboard`，X11 的 `xclip` / `xsel`，macOS 自带 `pbcopy/pbpaste` |
| 终端 | 建议支持真彩色；不支持时 catppuccin 会走 cterm 回退 |

> 如果 Vim 缺少 `timers/lambda/json_encode/job` 中的任何一项，配置会自动跳过
> 整段 LSP 设置，只保留基础编辑、主题和剪贴板逻辑，不会报错。

---

## 一键安装

```bash
git clone git@github.com:Li2TeO4/vim_config.git ~/code/vim_config
cd ~/code/vim_config
./install.sh
```

没有配置 SSH key 时可以用 HTTPS：

```bash
git clone https://github.com/Li2TeO4/vim_config.git ~/code/vim_config
```

### install.sh 行为

1. **检测原配置**：如果 `~/.vimrc` 已存在且不是本仓库管理的配置，先备份为
   `~/.vimrc.bak.<时间戳>-<PID>`；如果已经是本仓库的配置，则不重复备份。
2. **安装 vimrc**：`vimrc` → `~/.vimrc`。
3. **安装 schema 缓存**：`schemas/*.json` → `$XDG_DATA_HOME/vim-schemas`
   （缺省 `~/.local/share/vim-schemas`）。
4. **安装插件**：默认执行 `vim ... -c 'PlugInstall --sync'`；网络异常时不会
   中断安装，只会提示稍后重试。

可选参数：

```bash
./install.sh --no-plugins   # 只装配置和 schema，插件留到首次启动 vim 时自动装
```

---

## 首次启动与首次使用

```bash
vim
```

首次启动会：

1. 如果没有 `~/.vim/autoload/plug.vim`，自动从 jsdelivr / GitHub raw / wget /
   git clone 多级回退下载 vim-plug；
2. 如果插件目录缺失，VimEnter 时自动执行 `:PlugInstall` 并重新加载配置。

进入 Vim 后建议先自检；缺东西可以直接跑一键修复：

```vim
:VimConfigCheck   " 看缺什么
:VimConfigFix     " 能自动补的自动补
```

会打开一个只读窗口（按 `q` 关闭），列出缺什么。补装入口：

| 缺什么 | 怎么补 |
|---|---|
| vim-plug 插件 | `:PlugInstall`（或重启让它自动装） |
| LSP server | 打开对应类型文件后执行 `:LspInstallServer`，或用系统包管理器安装 |
| 本地 schema 缓存 | `:LspFetchSchemas`（不补也能用，会回退远程 schema） |
| 剪贴板工具 | 安装 `wl-clipboard` 或 `xclip`/`xsel` |

### 安装 LSP server 示例

server 本体不在本仓库里，需要按机器单独安装。最省事的方式是用
`vim-lsp-settings`：

```bash
vim foo.json          # 先打开一个该类型的文件
:LspInstallServer     # 安装当前 filetype 对应的 server
```

覆盖的文件类型：

| filetype | server |
|---|---|
| json / jsonc | `vscode-json-language-server` |
| yaml | `yaml-language-server` |
| toml | `taplo-lsp` |
| sh | `bash-language-server`（可选 `shellcheck` 增强诊断） |
| dockerfile | `docker-langserver` |
| markdown | `marksman` |
| vim | `vim-language-server` |

也可以手动安装；`vim-lsp-settings` 会自动在 `~/.local/share/vim-lsp-settings/servers`
和 `$PATH` 里找可执行文件。

> 本配置把 `:LspInstallServer` 做了安全包装：安装终端会开在**新窗口**里，
> 启动后光标立即回到原窗口，不再被带进终端。终端里按 `jk`/`Esc` 退出输入模式，
> `Ctrl+hjkl` 切换窗口，Terminal-Normal 下 `:q` 关闭安装窗口。
> `:VimConfigFix` 安装 server 时也走同一条安全路径。

---

## 更新配置

更新脚本会先确认当前 `~/.vimrc` 就是本仓库安装的配置，再拉取 GitHub 最新提交：

```bash
cd ~/code/vim_config
./update.sh
```

### update.sh 行为

1. **归属检查**：`~/.vimrc` 必须同时包含 `vim_config-managed:` 标记和
   `g:vim_config_managed` 变量；否则直接退出，不做任何修改。
2. **仓库干净检查**：仓库有未提交改动时退出，避免覆盖本地修改。
3. `git pull --ff-only` 拉取最新提交。
4. 同步 `vimrc`：如果当前文件和仓库不一致，先备份
   `~/.vimrc.bak.<时间戳>-<PID>` 再覆盖；如果一致则跳过。
5. 同步 `schemas/` 到 XDG 数据目录。
6. 默认执行 `:PlugInstall --sync` 补齐/更新插件，`--no-plugins` 可跳过。

如果输出“当前 ~/.vimrc 不是本仓库管理的配置”，说明当前文件没有来源标记：
不要用 `update.sh` 覆盖它；先备份/恢复，或重新运行 `install.sh`。

---

## 换机自检

```vim
:VimConfigCheck
```

自检窗口包含：

- **Vim 特性**：`timers`、`lambda`、`json`、`job/channel`、`termguicolors`、
  `clipboard_provider`、`pumvisible`、`complete_info`；
- **LSP 可用性**：是否启用了 LSP 配置；
- **插件**：vim-plug、主题、surround、lastplace、vim-lsp、vim-lsp-settings、
  asyncomplete 等是否齐全；
- **LSP server**：每种 filetype 的 server 能否解析到路径；
- **schema 缓存**：5 个本地 schema 的完整度；
- **剪贴板**：当前用哪个后端（wl-clipboard / xclip / xsel / pbcopy / 内建 / 不可用）；
- **外部命令**：curl、wget、git、node、npm；
- **主题 / PATH**：当前配色、`termguicolors`、`~/.local/bin` 是否在 PATH；
- **来源**：`g:vim_config_managed` 标记。

---

## 一键修复

```vim
:VimConfigFix
```

`VimConfigFix` 会尽量自动处理：

| 项目 | 自动修复方式 |
|---|---|
| 缺失插件 | `:PlugInstall --sync` |
| 主题未生效 | 重新执行 `colorscheme catppuccin_mocha` |
| schema 缓存缺失 | 调用 `:LspFetchSchemas` 下载 |
| LSP server 缺失 | 调用 vim-lsp-settings 安装器，在后台终端异步安装 |
| 剪贴板工具缺失 | 无法自动装系统包，只给出提示 |
| Vim 特性不足 | 无法修复，提示需要完整版 Vim |

修复动作和修复后的自检结果会显示在 `VimConfigFix` 窗口（按 `q` 关闭）。
LSP server 是异步安装的，建议装完后重启 Vim 再 `:VimConfigCheck` 确认。

---

## 键位速查

`<leader>` = 空格。

### 基础编辑

| 按键 | 模式 | 功能 |
|---|---|---|
| `jk` | i | 退出插入模式 |
| `<C-h/j/k/l>` | i | 插入模式方向键 |
| `<C-o>` | i | 插入模式向下新开一行 |
| `<S-H>` / `<S-L>` | n | 跳到行首 / 行尾 |
| `<C-h/j/k/l>` | n | 窗口间移动（对应 nvim） |
| `ww` | n | 保存 |
| `<leader>wq` | n | 保存退出 |
| `<leader>q` / `<leader>Q` | n | 退出 / 强制退出 |
| `Y` / `P` | n / v | 整行/选中内容进系统剪贴板；从系统剪贴板粘贴 |
| `<Tab>` / `<CR>` | i | 补全菜单可见时确认当前项，否则普通 Tab / 回车 |

> 普通 `y` / `p` 仍走 Vim 内部寄存器；只有大写 `Y` / `P` 走系统剪贴板。

### 窗口 / 终端

| 按键 | 模式 | 功能 |
|---|---|---|
| `<C-h/j/k/l>` | n | 在窗口间移动 |
| `<C-h/j/k/l>` | t | 终端输入模式下直接切到对应窗口 |
| `jk` / `<Esc>` | t | 退出终端输入模式（Terminal-Normal），之后可用 `:q` 关闭 |

竖向窗口分隔线使用 `fillchars=vert:│` + 加粗的 lavender `VertSplit`；
横向窗口之间的分隔就是状态栏，保留了 catppuccin 自带的底色，方便看清分屏关系。

### LSP（仅在 LSP attach 的 buffer 生效）

| 按键 | 功能 |
|---|---|
| `gd` | 跳转定义 |
| `gD` | 跳转声明 |
| `<leader>D` | 跳转类型定义 |
| `<leader>ra` | 重命名 |
| `K` | 悬浮文档 |
| `[d` / `]d` | 上一个 / 下一个诊断 |
| `<leader>ds` | 诊断列表（loclist） |

### 补全

| 按键 | 功能 |
|---|---|
| `<A-j>` / `<A-k>` | 补全菜单下一项 / 上一项 |
| `<Tab>` / `<CR>` | 确认当前补全项 |
| `<C-x><C-o>` | 手动触发补全（omnifunc） |
| `<Esc>j` / `<Esc>k` | Alt 键的 ESC 前缀兜底，仅补全菜单可见时生效 |

补全默认输入时自动弹出；不需要弹出时按 `<leader>lc` 关掉。

### LSP 开关

| 按键 | 功能 |
|---|---|
| `<leader>lc` | 开关自动补全（关闭后不再自动弹出，手动 `<C-x><C-o>` 不受影响） |
| `<leader>lx` | 开关整个 LSP 服务：停掉所有 server，清空诊断 / schema 校验；再按恢复 |

对应命令：`:LspCompletionToggle`、`:LspServiceToggle`。

### 常用命令

| 命令 | 功能 |
|---|---|
| `:VimConfigCheck` | 换机自检 |
| `:VimConfigFix` | 一键修复（插件/schema 自动补，缺失 server 调安装器） |
| `:LspFetchSchemas` | 下载/补齐 5 个本地 schema 缓存 |
| `:LspInstallServer` | 为当前文件类型安装 LSP server |
| `:LspUninstallServer <name>` | 卸载指定 server |
| `:PlugInstall` / `:PlugUpdate` / `:PlugClean` | vim-plug 安装 / 更新 / 清理插件 |
| `:messages` | 查看启动或 LSP 报错 |

---

## LSP 与 Schema 校验

### JSON / YAML

使用 `vim-lsp-settings` 自带的 SchemaStore 目录（1000+ 条），按文件名自动匹配，
例如 `package.json`、`tsconfig.json`、`docker-compose.yml`、GitHub Actions 等；
也支持在文件里直接声明：

```json
{ "$schema": "https://json.schemastore.org/package.json", "name": "..." }
```

```yaml
# yaml-language-server: $schema=https://json.schemastore.org/github-workflow.json
```

> 远程 schema 需要网络；网络受限时，本地有缓存的 schema（下方）会优先用本地。

### TOML

- 本地缓存并关联：`Cargo.toml`、`pyproject.toml`、`rustfmt.toml`、
  `rust-toolchain.toml`；
- 项目里的 `taplo.toml` / `.taplo.toml` 仍会正常读取；
- 单文件里可以写 `#:schema <url 或本地路径>`。

### docker-compose

优先使用本地 `schemas/compose-spec.json`；本仓库的 YAML server 是单独注册的，
避免 vim-lsp-settings 默认合并逻辑把远程地址再带回来造成重复校验。

### 本地 schema 缓存

- 目录：`$XDG_DATA_HOME/vim-schemas`，缺省 `~/.local/share/vim-schemas`；
- `install.sh` 会自动复制仓库里的 `schemas/`；
- 也可执行 `:LspFetchSchemas` 重新下载；
- 缓存缺失时 TOML 和 compose 会自动回退远程 URL。

### 追加自定义 schema

```vim
" 在 ~/.vimrc 里追加（YAML 示例，会与自带目录合并）
let g:lsp_settings['yaml-language-server'].schemas = [
\ {'fileMatch': ['myconf.yml', '**/myconf/*.yml'],
\  'url': 'https://example.com/myconf.schema.json'},
\ ]
```

JSON 对应 `g:lsp_settings['vscode-json-language-server'].schemas`。

---

## 主题

- 使用官方 `catppuccin/vim`，配色 `catppuccin_mocha`（对应 Neovim 侧的
  NvChad catppuccin）;
- 透明背景：`Normal`、`Pmenu`、`TabLine` 等组背景设为 `NONE`；
- 状态栏保留 catppuccin 自带底色（active `#11111b` / inactive `#181825`），
  因为横向分屏的分隔就是状态栏，透明会让上下窗口边界消失；
- 竖向分隔线使用 `fillchars=vert:│` + 加粗的 `VertSplit`（`#b4befe`），
  分屏关系更清楚；
- 行号颜色对齐 Neovim：
  - 相对行号 `LineNr`：`#6c7086`
  - 当前行绝对行号 `CursorLineNr`：`#b4befe` + bold（由 `cursorline` +
    `cursorlineopt=number` 驱动）
- 注释 `Comment`：`#7f849c` + italic；
- 终端不支持真彩色时，不会强制 `termguicolors`，走 catppuccin 的 cterm 回退。

想换回实心 Mocha 背景，把主题段里 `hi Normal guibg=NONE` 改成
`guibg=#1e1e2e` 即可。

---

## 可移植性设计

- **路径**：schema 用 XDG 数据目录，可执行目录自动补 `~/.local/bin`、`~/bin`、
  `$XDG_BIN_HOME`，不写死用户名或绝对路径。
- **vim-plug 自举**：`~/.vim/autoload/plug.vim` 不存在时自动下载：
  有 curl 时依次尝试 jsdelivr、GitHub raw；否则用 wget；最后 `git clone` 兜底。
- **缺插件自动安装**：启动时发现插件目录缺失，VimEnter 自动 `:PlugInstall` 并
  重新加载 vimrc。
- **特性守卫**：Vim 缺少 LSP 所需特性时整段跳过，最小构建也能正常启动。
- **剪贴板多后端**：Wayland / X11 / macOS 自动探测；Vim 自带 `+clipboard` 时
  不接管。
- **Schema 本地优先、远程回退**：换机器没有缓存时也能工作。
- **版本兼容判断**：`complete_info()`、`pumvisible()`、`termguicolors`、
  `colorscheme` 等都有存在性检查。

---

## 常见问题

**Q：第一次启动很慢？**
首次需要下载 vim-plug、插件或 LSP server。之后正常打开配置文件在几十毫秒级别。

**Q：某个文件没有补全 / 没有诊断？**
先 `:VimConfigCheck` 看对应 server 是否缺失；缺则打开该类型文件后
`:LspInstallServer`。也可以检查 `:messages`。

**Q：不想用补全了？**
`<leader>lc` 关闭自动弹出；再按恢复。补全关掉不影响诊断。

**Q：想彻底停掉 LSP / schema 校验？**
`<leader>lx`：停掉所有 server、清空诊断和 schema 校验；再按恢复。

**Q：缺插件 / server / schema，不想手动一个个装？**
`:VimConfigFix` 一键处理：插件走 `:PlugInstall`，schema 走 `:LspFetchSchemas`，
缺失的 LSP server 会调用 vim-lsp-settings 安装器。装完按提示重启 Vim 再自检。

**Q：大写 Y 复制会卡住？**
已在 clipboard provider 里修复：复制命令会把 stdout/stderr 重定向到
`/dev/null`，避免 `wl-copy`/`xclip` fork 出来的常驻进程让 Vim 的 `system()`
一直等 pipe EOF。更新配置后即可生效。

**Q：`:LspInstallServer` / `:VimConfigFix` 安装时窗口乱跳、退不出来？**
已修复：安装终端现在开在新窗口，焦点启动后立刻回到原窗口；终端里 `jk`/`Esc`
退出输入模式，`Ctrl+hjkl` 切窗口，Terminal-Normal 下 `:q` 关闭安装窗口。

**Q：Alt+j/k 没反应？**
部分终端把 Alt 发成 ESC 前缀，配置里已经用 `<Esc>j/k` 做了兜底，但只在补全
菜单可见时生效。如果你的终端支持 Alt 键协议，直接用 `<A-j>/<A-k>` 即可。

**Q：`Y` / `P` 访问不了系统剪贴板？**
- Wayland：安装 `wl-clipboard`；
- X11：安装 `xclip` 或 `xsel`；
- 其他：确保 Vim 有 `+clipboard` 或 `+clipboard_provider`。
可在 `:VimConfigCheck` 的 `[剪贴板]` 一节确认当前后端。

**Q：颜色不好看 / 透明失效？**
确认终端支持真彩色（`$COLORTERM` 包含 `truecolor`/`24bit`，或 256 色以上）。
不支持时 Vim 会走 256 色回退，透明效果取决于终端背景。

**Q：`update.sh` 说当前不是本仓库配置？**
说明 `~/.vimrc` 里没有 `vim_config-managed:` 标记。如果是你手动换掉的配置，
不要用 update 覆盖；需要的话恢复备份或重新 `./install.sh`。

**Q：schema 校验要联网吗？**
JSON/YAML 的 SchemaStore 目录按需远程拉取；TOML 和 docker-compose 优先用本地
缓存。完全离线时，可在文件里写相对/绝对 `$schema` / `#:schema` 指向本地文件。

---

## 卸载与恢复

1. 恢复原配置（如果有备份）：

   ```bash
   ls ~/.vimrc.bak.*
   cp ~/.vimrc.bak.<时间戳> ~/.vimrc
   ```

2. 删除本配置生成的文件：

   ```bash
   rm -f ~/.vimrc
   rm -rf ~/.local/share/vim-schemas          # 或 $XDG_DATA_HOME/vim-schemas
   rm -rf ~/.vim/plugged ~/.vim/autoload/plug.vim
   ```

3. LSP server 是独立安装的，用 `:LspUninstallServer <name>` 或系统包管理器卸载。

> 执行第 2 步前确认没有其他 Vim 配置共用 `~/.vim` 下的文件。

---

## 维护本仓库

配置的“源文件”是仓库里的 `vimrc`；本机安装后实际生效的是 `~/.vimrc`。

- 如果直接在 `~/.vimrc` 里改了配置，同步回仓库：

  ```bash
  cp ~/.vimrc ~/code/vim_config/vimrc
  cd ~/code/vim_config
  git add vimrc && git commit -m "update vimrc" && git push
  ```

- 如果在仓库里改了 `vimrc` 并已提交/推送：
  - 其他机器：运行 `./update.sh` 拉取并同步；
  - 当前机器立即生效：`cp ~/code/vim_config/vimrc ~/.vimrc`
    （`update.sh` 要求仓库无未提交改动，未提交时不会执行）。

- 更新本地 schema 缓存后，如需随仓库分发，把 `~/.local/share/vim-schemas/*.json`
  复制回 `schemas/` 再提交。

---

## 第三方组件

本仓库的 `vimrc` 会按需安装/使用以下开源项目：

| 组件 | 用途 |
|---|---|
| [vim-plug](https://github.com/junegunn/vim-plug) | 插件管理（在 `.vimrc` 中自举） |
| [vim-lsp](https://github.com/prabirshrestha/vim-lsp) | LSP 客户端 |
| [vim-lsp-settings](https://github.com/mattn/vim-lsp-settings) | LSP server 自动配置与安装 |
| [asyncomplete.vim](https://github.com/prabirshrestha/asyncomplete.vim) | 自动补全框架 |
| [asyncomplete-lsp.vim](https://github.com/prabirshrestha/asyncomplete-lsp.vim) | vim-lsp 补全源 |
| [catppuccin/vim](https://github.com/catppuccin/vim) | 主题 |
| [vim-surround](https://github.com/tpope/vim-surround) | 成对符号编辑 |
| [vim-lastplace](https://github.com/farmergreg/vim-lastplace) | 记住上次编辑位置 |

`schemas/` 目录中的 JSON schema 来自
[SchemaStore](https://www.schemastore.org/) 及其指向的上游项目，仅作为本地缓存
随仓库分发；如上游 schema 有更新，可用 `:LspFetchSchemas` 重新拉取。

LSP server 本体（如 `vscode-json-language-server`、`yaml-language-server`、
`taplo-lsp`、`marksman` 等）由各自的发行方提供，不在本仓库内。
