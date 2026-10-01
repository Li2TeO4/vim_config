" ── 配置来源标记（install.sh / update.sh 识别用，勿删）────
" vim_config-managed: https://github.com/Li2TeO4/vim_config
let g:vim_config_managed = 'Li2TeO4/vim_config'

" ── 基础 ──────────────────────────────────────────────
syntax on
set encoding=utf-8
set number
set relativenumber
" 当前行的绝对行号要用 CursorLineNr 高亮，必须开 cursorline；
" cursorlineopt=number 只高亮行号，不给整行铺底色（配合透明背景）
set cursorline
set cursorlineopt=number

" 缩进：统一真实 Tab（宽度 4）
set tabstop=4
set shiftwidth=4
set softtabstop=4
set noexpandtab
set autoindent

" 窗口分隔：竖向分隔线用更明显的 │（默认 | 太细，分屏边界看不清）
set fillchars=vert:│,fold:-,eob:~,lastline:@

" ── 环境路径 / 可移植性帮助函数 ────────────────────────
" 常见的用户级可执行目录补进 PATH（去重；Linux / macOS / Win 都可用）
function! s:PrependPath(dir) abort
  if empty(a:dir) || !isdirectory(a:dir)
    return
  endif
  let l:sep = has('win32') ? ';' : ':'
  if index(split($PATH, l:sep), a:dir) < 0
    let $PATH = a:dir . l:sep . $PATH
  endif
endfunction
call s:PrependPath(expand('~/.local/bin'))
call s:PrependPath(expand('~/bin'))
call s:PrependPath($XDG_BIN_HOME)

" LSP 插件运行所需特性：缺任何一项就整套跳过，保证最小 Vim 也能用
let s:has_lsp = has('timers') && has('lambda') && exists('*json_encode') && (has('job') || has('channel'))

" 用户数据目录（schema 缓存），遵循 XDG；本地没有缓存时自动回退远程 URL
let s:data_home = empty($XDG_DATA_HOME) ? expand('~/.local/share') : $XDG_DATA_HOME
let s:schema_dir = s:data_home . '/vim-schemas'
function! s:SchemaPath(name) abort
  return s:schema_dir . '/' . a:name
endfunction
function! s:SchemaUri(name, remote) abort
  let l:path = s:SchemaPath(a:name)
  if !filereadable(l:path)
    return a:remote
  endif
  let l:uri_path = substitute(l:path, '\\', '/', 'g')
  return 'file://' . substitute(l:uri_path, ' ', '%20', 'g')
endfunction

" ── 键位 ──────────────────────────────────────────────
let mapleader = " "

nnoremap ww :w<CR>
nnoremap <leader>wq :wq<CR>
nnoremap <leader>q  :q<CR>
nnoremap <leader>Q  :q!<CR>
nnoremap <S-H>      ^
nnoremap <S-L>      $

" 普通模式窗口间移动（对应 nvim 的 <C-hjkl>）
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

inoremap jk <Esc>
inoremap <C-h> <Left>
inoremap <C-j> <Down>
inoremap <C-k> <Up>
inoremap <C-l> <Right>
inoremap <C-o> <Esc>o

" 终端模式：jk/Esc 退出输入；Ctrl+hjkl 直接切窗口（不用先退 normal）
if has('terminal')
  tnoremap <Esc> <C-\><C-n>
  tnoremap jk    <C-\><C-n>
  tnoremap <C-h> <C-\><C-n><C-w>h
  tnoremap <C-j> <C-\><C-n><C-w>j
  tnoremap <C-k> <C-\><C-n><C-w>k
  tnoremap <C-l> <C-\><C-n><C-w>l
endif

" Y/P 走系统剪贴板（原先只写了 "+ 寄存器，但没有可用 provider，实际抓不到）
nnoremap Y "+yy
vnoremap Y "+y
nnoremap P "+P
vnoremap P "+P

" ── 系统剪贴板 provider（Wayland / X11 / macOS）──────
" Vim 自带 +clipboard 的机器直接用内建实现；只有 -clipboard 但带
" +clipboard_provider 时（本机 Arch vim）才用外部工具桥接。
" 注意：不设 clipboard=unnamedplus，普通 y/p 仍走 Vim 内部寄存器。
if has('clipboard_provider') && !has('clipboard')
  function! s:DetectClipBackend() abort
    " copy 命令必须重定向 stdout/stderr 到 /dev/null：
    " wl-copy / xclip / xsel 写完剪贴板后会 fork 一个常驻进程继续持有 selection，
    " 该子进程若继承 Vim 的 stdout pipe，Vim 的 system() 会一直等 pipe EOF，
    " 表现为大写 Y 复制“卡死”（剪贴板其实已经写成功）。
    if !empty($WAYLAND_DISPLAY) && executable('wl-copy') && executable('wl-paste')
      return {'name': 'wl-clipboard', 'copy': 'wl-copy >/dev/null 2>&1', 'paste': 'wl-paste --no-newline'}
    endif
    if !empty($DISPLAY) && executable('xclip')
      return {'name': 'xclip', 'copy': 'xclip -selection clipboard >/dev/null 2>&1', 'paste': 'xclip -selection clipboard -o'}
    endif
    if !empty($DISPLAY) && executable('xsel')
      return {'name': 'xsel', 'copy': 'xsel --clipboard --input >/dev/null 2>&1', 'paste': 'xsel --clipboard --output'}
    endif
    if executable('pbcopy') && executable('pbpaste')
      return {'name': 'pbcopy', 'copy': 'pbcopy >/dev/null 2>&1', 'paste': 'pbpaste'}
    endif
    return {}
  endfunction

  let s:clip_backend = {}
  function! s:ClipBackend() abort
    if empty(s:clip_backend)
      let s:clip_backend = s:DetectClipBackend()
    endif
    return s:clip_backend
  endfunction

  function! s:ClipAvailable() abort
    return !empty(s:ClipBackend())
  endfunction

  " 行wise 保留结尾换行、字符wise 不保留，保证粘贴时寄存器类型正确
  function! s:ClipCopy(reg, type, lines) abort
    let l:backend = s:ClipBackend()
    if empty(l:backend)
      return
    endif
    let l:text = join(a:lines, "\n")
    if a:type =~# '^V'
      let l:text .= "\n"
    endif
    call system(l:backend['copy'], l:text)
  endfunction

  function! s:ClipPaste(reg) abort
    let l:backend = s:ClipBackend()
    if empty(l:backend)
      return ['', []]
    endif
    " wl-paste 需要 --no-newline，否则会无条件补一个换行，导致
    " 单行字符wise 内容被误判成 linewise（xclip/xsel/pbpaste 是精确输出）
    let l:raw = system(l:backend['paste'])
    if v:shell_error != 0
      return ['', []]
    endif
    if l:raw =~# "\n$"
      return ['V', split(l:raw[0:-2], "\n", 1)]
    endif
    return ['v', split(l:raw, "\n", 1)]
  endfunction

  let s:sysclip = {}
  let s:sysclip.available = function('s:ClipAvailable')
  let s:sysclip.copy = { '+': function('s:ClipCopy'), '*': function('s:ClipCopy') }
  let s:sysclip.paste = { '+': function('s:ClipPaste'), '*': function('s:ClipPaste') }
  let v:clipproviders['sysclip'] = s:sysclip
  if stridx(&clipmethod, 'sysclip') < 0
    set clipmethod^=sysclip
  endif
endif

" 下面的 LSP 配置需要 timers/lambda/json_encode/job；最小 Vim 会整段跳过
if s:has_lsp
" ── LSP（vim-lsp + vim-lsp-settings）─────────────────
" settings 的初始化延迟到 VimEnter，避免拖慢启动；vim-lsp 本身很轻
let g:lsp_settings_lazyload = 1

" 新版 vscode-json-language-server 只走 pull 诊断，必须声明该 capability
let g:lsp_diagnostics_pull_enabled = 1

" 自动补全（asyncomplete + asyncomplete-lsp）：
" 默认输入时自动弹出；completeopt 由 LSP buffer 自己设，别让插件改
let g:asyncomplete_auto_popup = 1
let g:asyncomplete_auto_completeopt = 0

" 每种文件类型固定 server，避免自动挑选到没装的
let g:lsp_settings_filetype_json       = 'vscode-json-language-server'
let g:lsp_settings_filetype_jsonc      = 'vscode-json-language-server'
let g:lsp_settings_filetype_yaml       = 'yaml-language-server'
let g:lsp_settings_filetype_toml       = 'taplo-lsp'
let g:lsp_settings_filetype_sh         = 'bash-language-server'
let g:lsp_settings_filetype_dockerfile = 'docker-langserver'
let g:lsp_settings_filetype_markdown   = 'marksman'
let g:lsp_settings_filetype_vim        = 'vim-language-server'

" JSON LS 必须显式下发 validate.enable，否则不会产生诊断；
" 这里同时复用 vim-lsp-settings 自带的 SchemaStore 目录，不丢校验能力。
function! s:JsonWorkspaceConfig(name, key) abort
  let l:schemas = exists('*lsp_settings#utils#load_schemas') ? lsp_settings#utils#load_schemas(a:name) : []
  let l:schemas += [{'fileMatch': ['/vim-lsp-settings/settings.json', '/.vim-lsp-settings/settings.json'], 'url': 'https://mattn.github.io/vim-lsp-settings/local-schema.json'}]
  return {'json': {'format': {'enable': v:true}, 'validate': {'enable': v:true}, 'schemas': l:schemas}}
endfunction

" taplo 0.10 的默认 catalog 会抓远程 SchemaStore（慢且与下面重复），
" 这里置空 catalogs，改用本地缓存的 SchemaStore schema。
function! s:TaploInitOptions(name, key) abort
  " catalogs 置空：taplo 0.10 默认会抓 SchemaStore catalog，既慢又和下面重复；
  " associations 优先用本地缓存，没有缓存则回退到远程 URL（换机器不用准备文件）；
  " 项目里的 taplo.toml 仍会正常读取
  return {
  \ 'activationStatus': v:true,
  \ 'schema': {
  \   'enabled': v:true,
  \   'catalogs': [],
  \   'links': v:false,
  \   'associations': {
  \     '^(.*(/|\\)Cargo\.toml|Cargo\.toml)$': s:SchemaUri('cargo.json', 'https://json.schemastore.org/cargo.json'),
  \     '^(.*(/|\\)pyproject\.toml|pyproject\.toml)$': s:SchemaUri('pyproject.json', 'https://json.schemastore.org/pyproject.json'),
  \     '^(.*(/|\\)\.?rustfmt\.toml|rustfmt\.toml)$': s:SchemaUri('rustfmt.json', 'https://json.schemastore.org/rustfmt.json'),
  \     '^(.*(/|\\)rust-toolchain(\.toml)?|rust-toolchain(\.toml)?)$': s:SchemaUri('rust-toolchain.json', 'https://json.schemastore.org/rust-toolchain.json'),
  \   },
  \ },
  \}
endfunction

function! s:TaploWorkspaceConfig(name, key) abort
  return {'evenBetterToml': s:TaploInitOptions(a:name, a:key)}
endfunction

" YAML 里 docker-compose 的官方 schema 指向 raw.githubusercontent；本地有缓存
" 就换成本地 file://（快、离线也能校验），没有则保留远程 URL（正常网络够用）。
function! s:YamlWorkspaceConfig(name, key) abort
  let l:schemas = exists('*lsp_settings#utils#load_schemas_map') ? lsp_settings#utils#load_schemas_map(a:name) : {}
  if filereadable(s:SchemaPath('compose-spec.json'))
    let l:local_compose = s:SchemaUri('compose-spec.json', '')
    for [l:url, l:patterns] in items(l:schemas)
      if l:url =~# 'raw\.githubusercontent\.com/compose-spec/compose-go/'
        call remove(l:schemas, l:url)
        let l:schemas[l:local_compose] = l:patterns
        break
      endif
    endfor
  endif
  return {'yaml': {'format': {'enable': v:true}, 'validate': v:true, 'schemas': l:schemas}}
endfunction

" YAML：settings 插件会对 workspace_config 做 merge，把 catalog 里 compose 的
" 原始 raw URL 再加回来，和本地 schema 重复；所以下面禁用它，改由自定义注册。
let g:lsp_settings = {
\ 'vscode-json-language-server': {'workspace_config': function('s:JsonWorkspaceConfig')},
\ 'yaml-language-server': {'disabled': v:true},
\ 'taplo-lsp': {
\   'initialization_options': function('s:TaploInitOptions'),
\   'workspace_config': function('s:TaploWorkspaceConfig'),
\ },
\}

" YAML server：自己注册（同名），workspace_config 直接用 s:YamlWorkspaceConfig，
" 不走 settings 插件的 merge，避免 compose schema 远程/本地重复
function! s:YamlCmd(exe, server_info) abort
  return [a:exe, '--stdio']
endfunction
function! s:RegisterYamlServer() abort
  let l:exe = exists('*lsp_settings#exec_path') ? lsp_settings#exec_path('yaml-language-server') : ''
  if empty(l:exe)
    let l:exe = 'yaml-language-server'
  endif
  call lsp#register_server({
  \ 'name': 'yaml-language-server',
  \ 'cmd': function('s:YamlCmd', [l:exe]),
  \ 'allowlist': ['yaml'],
  \ 'workspace_config': s:YamlWorkspaceConfig('yaml-language-server', 'workspace_config'),
  \ })
endfunction

augroup my_yaml_server
  autocmd!
  autocmd User lsp_setup call s:RegisterYamlServer()
augroup END

" Schema 校验说明：
"   JSON → vim-lsp-settings 自带 SchemaStore 目录（1117 条），按文件名自动匹配
"   YAML → 同上；docker-compose 本地缓存存在时优先本地，否则远程
"   TOML → cargo / pyproject / rustfmt / rust-toolchain；文件内也可写 #:schema
"   本地缓存目录：$XDG_DATA_HOME/vim-schemas（缺省 ~/.local/share/vim-schemas）
"   换新机器后可执行 :LspFetchSchemas 一次性拉取缓存（不执行也能用，走远程）
"   补充自定义 schema（会与目录合并）：
" let g:lsp_settings['yaml-language-server'].schemas = [{'fileMatch': ['myconf.yml'], 'url': 'https://example.com/myconf.json'}]

" 可选：把常用 schema 缓存到本地（新机器执行一次；失败不影响远程回退）
function! s:FetchSchemas() abort
  if !executable('curl') && !executable('wget')
    echo 'LspFetchSchemas: 需要 curl 或 wget'
    return
  endif
  call mkdir(s:schema_dir, 'p')
  let l:files = [
  \ ['cargo.json', 'https://json.schemastore.org/cargo.json'],
  \ ['pyproject.json', 'https://json.schemastore.org/pyproject.json'],
  \ ['rustfmt.json', 'https://json.schemastore.org/rustfmt.json'],
  \ ['rust-toolchain.json', 'https://json.schemastore.org/rust-toolchain.json'],
  \ ['compose-spec.json', 'https://cdn.jsdelivr.net/gh/compose-spec/compose-go@master/schema/compose-spec.json'],
  \ ]
  let l:failed = 0
  for [l:name, l:url] in l:files
    if filereadable(s:SchemaPath(l:name))
      continue
    endif
    if executable('curl')
      call system(['curl', '-fsSL', '--connect-timeout', '10', '--max-time', '60', '-o', s:SchemaPath(l:name), l:url])
    else
      call system(['wget', '-q', '-O', s:SchemaPath(l:name), l:url])
    endif
    if v:shell_error != 0
      let l:failed += 1
      silent! call delete(s:SchemaPath(l:name))
      echo 'LspFetchSchemas: 下载失败 ' . l:name
    else
      echo 'LspFetchSchemas: 已缓存 ' . l:name
    endif
  endfor
  echo 'schema 缓存目录: ' . s:schema_dir . (l:failed ? ('（失败 ' . l:failed . ' 个）') : '')
endfunction
command! LspFetchSchemas call s:FetchSchemas()

" ── LSP 键位（参考 nvim 习惯；仅在 LSP attach 的 buffer 生效）────
function! s:IsPumVisible() abort
  return exists('*pumvisible') && pumvisible()
endfunction

function! s:CompleteConfirm(fallback) abort
  if s:IsPumVisible()
    let l:selected = exists('*complete_info') ? complete_info().selected : -1
    if l:selected == -1
      return "\<C-n>\<C-y>"  " 未选中任何项时先选第一项再确认
    endif
    return "\<C-y>"
  endif
  return a:fallback
endfunction

function! s:OnLspBufferEnabled() abort
  " 手动触发（<C-x><C-o>）用 vim-lsp 自带 omnifunc；自动弹出由 asyncomplete 负责
  setlocal omnifunc=lsp#complete
  setlocal completeopt=menuone,noinsert  " 第一项默认选中，Tab/回车直接确认

  " 跳转 / 查看（对应 nvim 的 gd / gD / <leader>D / <leader>ra / [d / ]d）
  nmap <buffer> gd         <plug>(lsp-definition)
  nmap <buffer> gD         <plug>(lsp-declaration)
  nmap <buffer> <leader>D  <plug>(lsp-type-definition)
  nmap <buffer> <leader>ra <plug>(lsp-rename)
  nmap <buffer> K          <plug>(lsp-hover)
  nmap <buffer> [d         <plug>(lsp-previous-diagnostic)
  nmap <buffer> ]d         <plug>(lsp-next-diagnostic)
  nmap <buffer> <leader>ds <plug>(lsp-document-diagnostics)

  " 补全：Alt+j/k 上下选择，Tab / 回车确认
  inoremap <expr> <buffer> <A-j> <SID>IsPumVisible() ? "\<C-n>" : ''
  inoremap <expr> <buffer> <A-k> <SID>IsPumVisible() ? "\<C-p>" : ''
  " 有些终端把 Alt+j/k 发成 ESC 前缀（Vim 本构建无 modifyOtherKeys），
  " 补一层序列映射；只在补全菜单可见时生效，菜单不在时保持原有的 ESC+j/k 行为
  inoremap <expr> <buffer> <Esc>j <SID>IsPumVisible() ? "\<C-n>" : "\<Esc>j"
  inoremap <expr> <buffer> <Esc>k <SID>IsPumVisible() ? "\<C-p>" : "\<Esc>k"
  inoremap <expr> <buffer> <Tab> <SID>CompleteConfirm("\<Tab>")
  inoremap <expr> <buffer> <CR>  <SID>CompleteConfirm("\<CR>")
endfunction

augroup my_lsp_keymaps
  autocmd!
  autocmd User lsp_buffer_enabled call s:OnLspBufferEnabled()
augroup END

" ── LSP 开关 ──────────────────────────────────────────
" <leader>lc：开关自动补全（关闭后不再自动弹出，手动 <C-x><C-o> 不受影响）
function! s:ToggleLspCompletion() abort
  let g:asyncomplete_auto_popup = !get(g:, 'asyncomplete_auto_popup', 1)
  if !g:asyncomplete_auto_popup && s:IsPumVisible()
    call feedkeys("\<C-e>", 'n')
  endif
  echo printf('LSP 补全：%s', g:asyncomplete_auto_popup ? '开启（输入时自动弹出）' : '关闭（不再自动弹出）')
endfunction

" <leader>lx：开关整个 LSP 服务（停止所有 server，诊断/schema 校验一并清空）
let s:lsp_service_enabled = 1
function! s:ToggleLspService() abort
  if !exists('*lsp#disable')
    echo 'LSP 服务开关：vim-lsp 尚未加载（插件可能还没装好）'
    return
  endif
  if s:lsp_service_enabled
    let s:lsp_service_enabled = 0
    if s:IsPumVisible() | call feedkeys("\<C-e>", 'n') | endif
    for l:name in lsp#get_server_names()
      call lsp#stop_server(l:name)
    endfor
    call lsp#disable()
    silent! call lsp#internal#diagnostics#state#_reset()
    echo 'LSP：已关闭（所有 server 已停止，诊断/schema 校验已清空；再按一次开启）'
  else
    let s:lsp_service_enabled = 1
    call lsp#enable()
    echo 'LSP：已开启（将在当前及已加载文件上重新启动 server）'
  endif
endfunction

command! LspCompletionToggle call s:ToggleLspCompletion()
command! LspServiceToggle call s:ToggleLspService()
nnoremap <leader>lc <Cmd>LspCompletionToggle<CR>
nnoremap <leader>lx <Cmd>LspServiceToggle<CR>
endif  " s:has_lsp

" ── 插件（vim-plug 自举 + 缺失自动安装）───────────────
function! s:BootstrapPlug() abort
  let l:plug = expand('~/.vim/autoload/plug.vim')
  if !empty(glob(l:plug))
    return
  endif
  call mkdir(fnamemodify(l:plug, ':h'), 'p')
  let l:urls = [
  \ 'https://cdn.jsdelivr.net/gh/junegunn/vim-plug@master/plug.vim',
  \ 'https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim',
  \ ]
  if executable('curl')
    for l:url in l:urls
      silent! call delete(l:plug)
      call system(['curl', '-fsSL', '--connect-timeout', '10', '--max-time', '60', '-o', l:plug, l:url])
      if filereadable(l:plug) && getfsize(l:plug) > 10000
        return
      endif
    endfor
  elseif executable('wget')
    for l:url in l:urls
      silent! call delete(l:plug)
      call system(['wget', '-q', '-O', l:plug, l:url])
      if filereadable(l:plug) && getfsize(l:plug) > 10000
        return
      endif
    endfor
  endif
  if empty(glob(l:plug)) && executable('git')
    " 最后兜底：git clone（GitHub raw 不通时，git + 代理往往可行）
    let l:tmp = tempname()
    call system(['git', 'clone', '--depth', '1', '-q', 'https://github.com/junegunn/vim-plug.git', l:tmp])
    if filereadable(l:tmp . '/plug.vim')
      call writefile(readfile(l:tmp . '/plug.vim', 'b'), l:plug, 'b')
    endif
    if isdirectory(l:tmp)
      silent! call delete(l:tmp, 'rf')
    endif
  endif
  if empty(glob(l:plug))
    echohl WarningMsg | echomsg 'vim-plug 自举失败：请手动安装 https://github.com/junegunn/vim-plug' | echohl None
  endif
endfunction
call s:BootstrapPlug()

if filereadable(expand('~/.vim/autoload/plug.vim'))
  call plug#begin('~/.vim/plugged')
  Plug 'tpope/vim-surround'             " 快速处理成对符号
  Plug 'farmergreg/vim-lastplace'       " 记录上次打开位置
  if s:has_lsp
    Plug 'prabirshrestha/vim-lsp'         " LSP 客户端
    Plug 'mattn/vim-lsp-settings'         " LSP server 自动配置（含 SchemaStore 目录）
    Plug 'prabirshrestha/asyncomplete.vim'    " 自动补全框架
    Plug 'prabirshrestha/asyncomplete-lsp.vim' " vim-lsp 补全源
  endif
  Plug 'catppuccin/vim', { 'as': 'catppuccin' } " 主题：catppuccin（nvim 同款）
  call plug#end()

  " 插件目录缺失时，启动完成后自动补装并重新加载 vimrc（首次到新机器可用）
  let s:required_plugins = ['vim-surround', 'vim-lastplace', 'catppuccin']
  if s:has_lsp
    let s:required_plugins += ['vim-lsp', 'vim-lsp-settings', 'asyncomplete.vim', 'asyncomplete-lsp.vim']
  endif
  let s:missing_plugins = filter(copy(s:required_plugins), '!isdirectory(expand("~/.vim/plugged/") . v:val)')
  if !empty(s:missing_plugins)
    let s:myvimrc = empty($MYVIMRC) ? expand('~/.vimrc') : $MYVIMRC
    autocmd VimEnter * PlugInstall --sync | execute 'source' fnameescape(s:myvimrc)
  endif
endif

" ── 主题：catppuccin Mocha（对齐 nvim 的 NvChad catppuccin）────
" catppuccin/vim 需要 termguicolors；老终端不支持真彩色时走它的 cterm 回退
if has('termguicolors') && (has('gui_running') || $COLORTERM =~? 'truecolor\|24bit' || &t_Co >= 256)
  set termguicolors
endif

" 插件可能还没装上（首次自举 + PlugInstall 尚未完成）：找不到配色就跳过，
" 等 VimEnter 里自动安装并重新 source vimrc 后再应用
if !empty(globpath(&rtp, 'colors/catppuccin_mocha.vim'))
  colorscheme catppuccin_mocha

  " ── 透明背景（对应 nvim chadrc 的 transparency = true）────
  " 组清单参考 NvChad base46 的 glassy、statusline、tabufline 三处
  hi Normal       guibg=NONE ctermbg=NONE
  hi NormalNC     guibg=NONE ctermbg=NONE
  hi NormalFloat  guibg=NONE ctermbg=NONE
  hi Folded       guibg=NONE ctermbg=NONE
  hi CursorLine   guibg=NONE ctermbg=NONE
  hi WinBar       guibg=NONE ctermbg=NONE
  hi WinBarNC     guibg=NONE ctermbg=NONE

  " 补全/悬浮菜单：底色透明，选中项保留 surface 色以便区分
  hi Pmenu        guibg=NONE ctermbg=NONE
  hi PmenuBorder  guibg=NONE ctermbg=NONE
  hi PmenuExtra   guibg=NONE ctermbg=NONE
  hi PmenuKind    guibg=NONE ctermbg=NONE
  hi Popup        guibg=NONE ctermbg=NONE
  hi PopupTitle   guibg=NONE ctermbg=NONE

  " 标签栏保持透明；状态栏保留 catppuccin 自带底色：
  " 横向分屏的分隔就是上层窗口的状态栏，透明的话上下窗口边界会看不见
  hi TabLine      guibg=NONE ctermbg=NONE
  hi TabLineFill  guibg=NONE ctermbg=NONE
  hi TabLineSel   guibg=NONE ctermbg=NONE

  " 竖向分隔线加粗 lavender 色，分屏关系更清楚（配合 fillchars=vert:│）
  hi VertSplit    guifg=#b4befe ctermfg=147 gui=bold cterm=bold guibg=NONE ctermbg=NONE

  " ── 行号 / 注释色：搬 nvim chadrc 的 hl_override ────────
  " 相对行号（LineNr）与当前行绝对行号（CursorLineNr）
  hi LineNr       guifg=#6c7086 ctermfg=59  guibg=NONE ctermbg=NONE
  hi CursorLineNr guifg=#b4befe ctermfg=147 gui=bold cterm=bold guibg=NONE ctermbg=NONE
  " 注释：斜体 + #7f849c
  " （@comment 是 Neovim treesitter 组，本机 Vim 定义它会报 W18，故只用 Comment）
  hi Comment      guifg=#7f849c ctermfg=102 gui=italic cterm=italic term=italic
endif

" ── 换机自检 ──────────────────────────────────────────
" :VimConfigCheck 检查特性/插件/LSP server/schema 缓存/剪贴板/外部命令，
" 结果列在临时窗口里，并给出缺失项的补装提示
function! s:CheckExec(cmd) abort
  try
    let l:path = lsp_settings#exec_path(a:cmd)
    if !empty(l:path)
      return l:path
    endif
  catch
  endtry
  return executable(a:cmd) ? a:cmd : ''
endfunction

function! s:ConfigCheckLines() abort
  let l:lines = []
  call add(l:lines, 'Vim 配置换机自检  (' . strftime('%Y-%m-%d %H:%M') . ')')
  call add(l:lines, repeat('=', 58))
  call add(l:lines, '')

  " Vim 与关键特性
  let l:features = []
  for [l:name, l:ok] in [
  \ ['timers', has('timers')],
  \ ['lambda', has('lambda')],
  \ ['json', exists('*json_encode')],
  \ ['job/channel', has('job') || has('channel')],
  \ ['termguicolors', has('termguicolors')],
  \ ['clipboard_provider', has('clipboard_provider')],
  \ ['pumvisible', exists('*pumvisible')],
  \ ['complete_info', exists('*complete_info')],
  \ ]
    call add(l:features, l:name . ':' . (l:ok ? 'OK' : 'NO'))
  endfor
  call add(l:lines, '[Vim] v' . v:version . '  ' . join(l:features, ' '))
  call add(l:lines, '[LSP可用] ' . (s:has_lsp ? '是' : '否（已跳过 LSP 配置）'))
  call add(l:lines, '[来源] ' . get(g:, 'vim_config_managed', '未标记（不受 install/update 脚本管理）'))
  call add(l:lines, '')

  " 插件
  call add(l:lines, '[插件]')
  let l:plugin_specs = [
  \ ['vim-plug', expand('~/.vim/autoload/plug.vim'), 'file'],
  \ ['vim-surround', expand('~/.vim/plugged/vim-surround'), 'dir'],
  \ ['vim-lastplace', expand('~/.vim/plugged/vim-lastplace'), 'dir'],
  \ ['catppuccin', expand('~/.vim/plugged/catppuccin'), 'dir'],
  \ ]
  if s:has_lsp
    let l:plugin_specs += [
    \ ['vim-lsp', expand('~/.vim/plugged/vim-lsp'), 'dir'],
    \ ['vim-lsp-settings', expand('~/.vim/plugged/vim-lsp-settings'), 'dir'],
    \ ['asyncomplete.vim', expand('~/.vim/plugged/asyncomplete.vim'), 'dir'],
    \ ['asyncomplete-lsp.vim', expand('~/.vim/plugged/asyncomplete-lsp.vim'), 'dir'],
    \ ]
  endif
  let l:plugin_line = []
  let l:missing_plugins = []
  for [l:name, l:path, l:kind] in l:plugin_specs
    let l:ok = l:kind ==# 'file' ? filereadable(l:path) : isdirectory(l:path)
    call add(l:plugin_line, l:name . ':' . (l:ok ? 'OK' : '缺'))
    if !l:ok
      call add(l:missing_plugins, l:name)
    endif
  endfor
  call add(l:lines, '  ' . join(l:plugin_line, '  '))
  if !empty(l:missing_plugins)
    call add(l:lines, '  -> 缺 ' . len(l:missing_plugins) . ' 个：执行 :PlugInstall，或直接重启让自举自动安装')
  endif
  call add(l:lines, '')

  " LSP server
  call add(l:lines, '[LSP server]')
  if !s:has_lsp
    call add(l:lines, '  当前 Vim 缺少 timers/lambda/json/job 之一，已跳过 LSP 配置')
  else
    let l:server_specs = [
    \ ['json/jsonc', 'vscode-json-language-server'],
    \ ['yaml', 'yaml-language-server'],
    \ ['toml', 'taplo-lsp'],
    \ ['sh', 'bash-language-server'],
    \ ['dockerfile', 'docker-langserver'],
    \ ['markdown', 'marksman'],
    \ ['vim', 'vim-language-server'],
    \ ]
    let l:missing_servers = []
    for [l:ft, l:cmd] in l:server_specs
      let l:path = s:CheckExec(l:cmd)
      call add(l:lines, printf('  %-12s %-28s %s', l:ft, l:cmd, empty(l:path) ? '缺失' : 'OK  ' . l:path))
      if empty(l:path)
        call add(l:missing_servers, l:cmd)
      endif
    endfor
    if !empty(l:missing_servers)
      call add(l:lines, '  -> 缺 ' . len(l:missing_servers) . ' 个：打开对应类型文件后执行 :LspInstallServer，或用系统包管理器安装')
    endif
    call add(l:lines, '  shellcheck（可选，bash 诊断增强）: ' . (empty(s:CheckExec('shellcheck')) ? '缺失' : 'OK'))
  endif
  call add(l:lines, '')

  " schema 缓存
  call add(l:lines, '[Schema 缓存] ' . s:schema_dir)
  let l:schema_files = ['cargo.json', 'pyproject.json', 'rustfmt.json', 'rust-toolchain.json', 'compose-spec.json']
  let l:schema_line = []
  let l:schema_ok = 0
  for l:name in l:schema_files
    let l:ok = filereadable(s:SchemaPath(l:name))
    if l:ok
      let l:schema_ok += 1
    endif
    call add(l:schema_line, l:name . ':' . (l:ok ? 'OK' : '缺'))
  endfor
  call add(l:lines, '  ' . join(l:schema_line, '  ') . '   (' . l:schema_ok . '/' . len(l:schema_files) . ')')
  if l:schema_ok < len(l:schema_files)
    call add(l:lines, '  -> 可执行 :LspFetchSchemas 补齐；不补也能用，会自动回退远程 schema')
  endif
  call add(l:lines, '')

  " 剪贴板
  call add(l:lines, '[剪贴板]')
  if has('clipboard')
    call add(l:lines, '  Vim 自带 +clipboard，内建寄存器可用')
  elseif has('clipboard_provider')
    if exists('*s:ClipBackend') && !empty(s:ClipBackend())
      call add(l:lines, '  外部桥接可用：' . s:ClipBackend()['name'])
    else
      call add(l:lines, '  Y/P 的 "+ 寄存器当前不可用；安装 wl-clipboard 或 xclip/xsel 后重开 Vim')
    endif
  else
    call add(l:lines, '  当前 Vim 无 +clipboard / +clipboard_provider，Y/P 无法访问系统剪贴板')
  endif
  call add(l:lines, '')

  " 外部命令 / 主题 / PATH
  let l:cmds = []
  for l:cmd in ['curl', 'wget', 'git', 'node', 'npm']
    call add(l:cmds, l:cmd . ':' . (executable(l:cmd) ? 'OK' : '无'))
  endfor
  call add(l:lines, '[外部命令] ' . join(l:cmds, '  '))
  call add(l:lines, '[主题] colors_name=' . string(get(g:, 'colors_name', '')) . '  termguicolors=' . &termguicolors)
  call add(l:lines, '[PATH] ' . (stridx($PATH, expand('~/.local/bin')) >= 0 ? '包含 ~/.local/bin' : '未包含 ~/.local/bin'))
  call add(l:lines, '')
  call add(l:lines, '补装入口：插件 :PlugInstall；LSP server :LspInstallServer；schema :LspFetchSchemas')
  call add(l:lines, '也可以执行 :VimConfigFix 尝试一键自动修复')
  call add(l:lines, '按 q 关闭本窗口')
  return l:lines
endfunction

" 把行列表显示在指定名称的只读临时窗口里（VimConfigCheck / VimConfigFix 共用）
function! s:ShowScratch(name, lines) abort
  let l:buf = bufnr(a:name)
  if l:buf != -1 && bufexists(l:buf)
    execute 'botright sbuffer' l:buf
  else
    botright new
    silent! execute 'file' fnameescape(a:name)
  endif
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted
  setlocal modifiable
  silent! %delete _
  call setline(1, a:lines)
  setlocal nomodifiable
  normal! gg
endfunction

function! s:ConfigCheck() abort
  call s:ShowScratch('VimConfigCheck', s:ConfigCheckLines())
endfunction

" ── LSP server 安装（安全包装）────────────────────────
" 原版 :LspInstallServer 会直接在“当前窗口”term_start，光标会被带进安装终端，
" 不容易退出。这里改成：在下方新窗口里跑安装，启动后立刻把光标还给原窗口。
function! s:InstallServerSafe(ft, name) abort
  let l:origin_tab = tabpagenr()
  let l:origin_win = win_getid()
  let l:before_wins = winnr('$')
  let l:started = 0
  try
    " Vim 的 term_start() 默认会自己新开窗口放终端；这里不额外开窗口，
    " 安装启动后马上把焦点还给原窗口即可，避免“光标被带进安装终端”。
    call lsp_settings#install_server(a:ft, a:name)
  catch
    echo 'LspInstallServer 启动失败: ' . v:exception
  endtry
  if winnr('$') > l:before_wins || &l:buftype ==# 'terminal'
    let l:started = 1
    " 顺手把安装终端里的行号/cursorline 关掉，输出更干净
    setlocal nonumber norelativenumber nocursorline nolist
  endif
  if tabpagenr() != l:origin_tab
    execute 'tabnext' l:origin_tab
  endif
  call win_gotoid(l:origin_win)
  if l:started
    echo '安装终端在新窗口里运行；jk/Esc 退出终端输入，Ctrl+hjkl 切换窗口'
  endif
  return l:started
endfunction

function! s:SafeLspInstallServer(bang, name) abort
  if empty(&l:filetype)
    echo 'LspInstallServer: 当前 buffer 没有 filetype，先打开对应类型文件'
    return
  endif
  call s:InstallServerSafe(&l:filetype, a:name)
endfunction

" 等所有 VimEnter 初始化（含 vim-lsp-settings 注册命令）结束后再覆盖命令
function! s:OverrideLspInstallCommand(...) abort
  if empty(globpath(&rtp, 'autoload/lsp_settings.vim'))
    return
  endif
  if exists('*lsp_settings#complete_install')
    command! -bang -nargs=? -complete=customlist,lsp_settings#complete_install LspInstallServer call s:SafeLspInstallServer(<bang>0, <q-args>)
  else
    command! -bang -nargs=? LspInstallServer call s:SafeLspInstallServer(<bang>0, <q-args>)
  endif
endfunction

if s:has_lsp
  augroup my_lsp_install_override
    autocmd!
    autocmd VimEnter * call timer_start(0, function('s:OverrideLspInstallCommand'))
  augroup END
endif

" ── 一键修复 ──────────────────────────────────────────
" :VimConfigFix 会尽量自动补齐：vim-plug 插件、catppuccin 主题、schema 缓存；
" 缺失的 LSP server 会调用安全包装的安装器（后台终端异步安装）。
function! s:ConfigFix() abort
  let l:log = []
  let l:actions = 0
  let l:need_restart = 0
  call add(l:log, 'Vim 配置一键修复  ' . strftime('%Y-%m-%d %H:%M'))
  call add(l:log, repeat('=', 58))
  call add(l:log, '')

  " 1) 插件
  let l:plugin_specs = [
  \ ['vim-plug', expand('~/.vim/autoload/plug.vim'), 'file'],
  \ ['vim-surround', expand('~/.vim/plugged/vim-surround'), 'dir'],
  \ ['vim-lastplace', expand('~/.vim/plugged/vim-lastplace'), 'dir'],
  \ ['catppuccin', expand('~/.vim/plugged/catppuccin'), 'dir'],
  \ ]
  if s:has_lsp
    let l:plugin_specs += [
    \ ['vim-lsp', expand('~/.vim/plugged/vim-lsp'), 'dir'],
    \ ['vim-lsp-settings', expand('~/.vim/plugged/vim-lsp-settings'), 'dir'],
    \ ['asyncomplete.vim', expand('~/.vim/plugged/asyncomplete.vim'), 'dir'],
    \ ['asyncomplete-lsp.vim', expand('~/.vim/plugged/asyncomplete-lsp.vim'), 'dir'],
    \ ]
  endif
  let l:missing_plugins = []
  let l:missing_lsp_plugin = 0
  for [l:name, l:path, l:kind] in l:plugin_specs
    let l:ok = l:kind ==# 'file' ? filereadable(l:path) : isdirectory(l:path)
    if !l:ok
      call add(l:missing_plugins, l:name)
      if l:name =~# 'vim-lsp\|asyncomplete'
        let l:missing_lsp_plugin = 1
      endif
    endif
  endfor

  if empty(l:missing_plugins)
    call add(l:log, '[插件] 已齐全')
  elseif exists(':PlugInstall')
    call add(l:log, '[插件] 缺失：' . join(l:missing_plugins, ', '))
    call add(l:log, '[插件] 执行 :PlugInstall --sync ...')
    try
      execute 'PlugInstall --sync'
      call add(l:log, '[插件] 安装流程结束')
      let l:actions += 1
      if l:missing_lsp_plugin
        let l:need_restart = 1
        call add(l:log, '[插件] LSP 相关插件是本次补装的，需要重启 Vim 才会加载')
      endif
    catch
      call add(l:log, '[插件] 安装出错：' . v:exception)
    endtry
  else
    call add(l:log, '[插件] 缺失但 vim-plug 不可用：检查网络/curl/git 后重启 Vim 让自举重试')
  endif
  call add(l:log, '')

  " 2) 主题
  if !empty(globpath(&rtp, 'colors/catppuccin_mocha.vim'))
    if get(g:, 'colors_name', '') !=# 'catppuccin_mocha'
      silent! colorscheme catppuccin_mocha
      call add(l:log, '[主题] 已重新应用 catppuccin_mocha')
      let l:actions += 1
    else
      call add(l:log, '[主题] catppuccin_mocha 正常')
    endif
  else
    call add(l:log, '[主题] 配色缺失，请先补齐插件（:PlugInstall 或重启自动安装）')
  endif
  call add(l:log, '')

  " 3) schema 缓存
  let l:schema_files = ['cargo.json', 'pyproject.json', 'rustfmt.json', 'rust-toolchain.json', 'compose-spec.json']
  let l:missing_schema = []
  for l:name in l:schema_files
    if !filereadable(s:SchemaPath(l:name))
      call add(l:missing_schema, l:name)
    endif
  endfor

  if empty(l:missing_schema)
    call add(l:log, '[Schema] 缓存完整 (' . len(l:schema_files) . '/' . len(l:schema_files) . ')')
  elseif !executable('curl') && !executable('wget')
    call add(l:log, '[Schema] 缺失但 curl/wget 不可用，无法自动下载：' . join(l:missing_schema, ', '))
  else
    call add(l:log, '[Schema] 缺失：' . join(l:missing_schema, ', ') . '，执行 :LspFetchSchemas ...')
    try
      call s:FetchSchemas()
      call add(l:log, '[Schema] 下载流程结束')
      let l:actions += 1
    catch
      call add(l:log, '[Schema] 下载出错：' . v:exception)
    endtry
  endif
  call add(l:log, '')

  " 4) LSP server
  if !s:has_lsp
    call add(l:log, '[LSP] 当前 Vim 缺少 timers/lambda/json/job，已跳过；请安装完整版 Vim')
  else
    let l:server_specs = [
    \ ['json', 'vscode-json-language-server'],
    \ ['yaml', 'yaml-language-server'],
    \ ['toml', 'taplo-lsp'],
    \ ['sh', 'bash-language-server'],
    \ ['dockerfile', 'docker-langserver'],
    \ ['markdown', 'marksman'],
    \ ['vim', 'vim-language-server'],
    \ ]
    let l:missing_servers = []
    for [l:ft, l:cmd] in l:server_specs
      if empty(s:CheckExec(l:cmd))
        call add(l:missing_servers, [l:ft, l:cmd])
      endif
    endfor

    if empty(l:missing_servers)
      call add(l:log, '[LSP server] 已齐全')
    elseif l:need_restart
      call add(l:log, '[LSP server] 有缺失，但 LSP 插件刚补装；请重启 Vim 后再执行 :VimConfigFix')
    elseif !has('terminal')
      call add(l:log, '[LSP server] 有缺失，但当前 Vim 无 +terminal，无法自动安装；请手动安装')
    elseif !empty(globpath(&rtp, 'autoload/lsp_settings.vim'))
      for [l:ft, l:cmd] in l:missing_servers
        if s:InstallServerSafe(l:ft, l:cmd)
          call add(l:log, printf('[LSP] 已启动安装：%s（%s）', l:cmd, l:ft))
          let l:actions += 1
        else
          call add(l:log, printf('[LSP] 启动安装失败：%s', l:cmd))
        endif
      endfor
      call add(l:log, '[LSP] 安装器在后台终端异步运行；完成后建议重启 Vim，再 :VimConfigCheck')
    else
      call add(l:log, '[LSP server] 缺失：' . join(map(copy(l:missing_servers), 'v:val[1]'), ', '))
      call add(l:log, '[LSP server] vim-lsp-settings 不可用，请手动安装或用 :LspInstallServer')
    endif
  endif
  call add(l:log, '')

  " 5) 剪贴板 / 显示
  if has('clipboard')
    call add(l:log, '[剪贴板] Vim 内建 +clipboard 可用')
  elseif has('clipboard_provider')
    if exists('*s:ClipBackend') && !empty(s:ClipBackend())
      call add(l:log, '[剪贴板] 外部桥接可用：' . s:ClipBackend()['name'])
    else
      call add(l:log, '[剪贴板] 不可用，无法自动装包；请安装 wl-clipboard（Wayland）或 xclip/xsel（X11）')
    endif
  else
    call add(l:log, '[剪贴板] 当前 Vim 无 clipboard 支持，无法修复')
  endif
  if has('termguicolors') && (has('gui_running') || $COLORTERM =~? 'truecolor\|24bit' || &t_Co >= 256) && !&termguicolors
    set termguicolors
    call add(l:log, '[显示] 已启用 termguicolors')
    let l:actions += 1
  endif
  call add(l:log, '')

  " 6) 修复后重新自检
  call add(l:log, '──── 修复后自检（异步安装可能尚未完成）────')
  call extend(l:log, s:ConfigCheckLines())
  call s:ShowScratch('VimConfigFix', l:log)
  echo printf('VimConfigFix：执行了 %d 项修复/安装动作，结果见 VimConfigFix 窗口', l:actions)
endfunction

command! VimConfigCheck call s:ConfigCheck()
command! VimConfigFix call s:ConfigFix()
