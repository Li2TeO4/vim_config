" ── 50 LSP（vim-lsp + vim-lsp-settings）─────────────────
" 下面的 LSP 配置需要 timers/lambda/json_encode/job；最小 Vim 会整段跳过
if g:vim_config_has_lsp
" vim-lsp-settings 的 lazyload 会在 VimEnter 才挂 FileType 钩子，
" 导致 vim 启动时直接打开的第一个文件错过 server 注册；实测开关对启动耗时无影响，这里关掉。
let g:lsp_settings_lazyload = 0

" schema 校验开关（只影响 JSON/YAML/TOML 的 schema，不影响补全和 LSP 服务）
let g:vim_config_schema_validation = 1
function! s:SchemaEnabled() abort
  return get(g:, 'vim_config_schema_validation', 1)
endfunction

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
" 更多 Linux 配置文件相关
let g:lsp_settings_filetype_xml        = 'lemminx'
let g:lsp_settings_filetype_systemd    = 'systemd-lsp'
let g:lsp_settings_filetype_cmake      = 'cmake-language-server'
let g:lsp_settings_filetype_lua        = 'sumneko-lua-language-server'
let g:lsp_settings_filetype_terraform  = 'terraform-ls'
let g:lsp_settings_filetype_fish       = 'fish-lsp'
" 构建相关配置（server 按需装：缺少时只有对应文件类型受影响）
let g:lsp_settings_filetype_bzl        = 'starpls'
let g:lsp_settings_filetype_just       = 'just-lsp'

" 这些配置文件的 filetype Vim 核心识别不到或和 server 期望不一致，这里补齐
augroup my_extra_config_filetypes
  autocmd!
  autocmd BufNewFile,BufRead *.service,*.socket,*.timer,*.mount,*.target,*.path,*.slice,*.scope,*.automount,*.swap,*.device if empty(&l:filetype) | setlocal filetype=systemd | endif
  autocmd BufNewFile,BufRead *.tfvars setlocal filetype=terraform
  " Vim 会把 *.star 认成 starlark，但 vim-lsp-settings 只有 bzl 键；
  " 统一成 bzl 后 starpls 才能正常注册
  autocmd BufNewFile,BufRead *.star if &l:filetype ==# 'starlark' || empty(&l:filetype) | setlocal filetype=bzl | endif
augroup END

" JSON LS 必须显式下发 validate.enable，否则不会产生诊断；
" 这里同时复用 vim-lsp-settings 自带的 SchemaStore 目录，不丢校验能力。
function! s:JsonWorkspaceConfig(name, key) abort
  let l:schemas = []
  if s:SchemaEnabled()
    let l:schemas = exists('*lsp_settings#utils#load_schemas') ? lsp_settings#utils#load_schemas(a:name) : []
    let l:schemas += [{'fileMatch': ['/vim-lsp-settings/settings.json', '/.vim-lsp-settings/settings.json'], 'url': 'https://mattn.github.io/vim-lsp-settings/local-schema.json'}]
  endif
  " 只关 schema 关联，不关 validate.enable；这样 JSON 语法诊断仍然保留
  return {'json': {'format': {'enable': v:true}, 'validate': {'enable': v:true}, 'schemas': l:schemas}}
endfunction

" taplo 0.10 的默认 catalog 会抓远程 SchemaStore（慢且与下面重复），
" 这里置空 catalogs，改用本地缓存的 SchemaStore schema。
function! s:TaploInitOptions(name, key) abort
  let l:enabled = s:SchemaEnabled()
  " catalogs 置空：taplo 0.10 默认会抓 SchemaStore catalog，既慢又和下面重复；
  " associations 优先用本地缓存，没有缓存则回退到远程 URL（换机器不用准备文件）；
  " 项目里的 taplo.toml 仍会正常读取
  let l:schema = {
  \ 'enabled': l:enabled,
  \ 'catalogs': [],
  \ 'links': v:false,
  \}
  if l:enabled
    let l:schema['associations'] = {
    \ '^(.*(/|\\)Cargo\.toml|Cargo\.toml)$': VimConfigSchemaUri('cargo.json', 'https://json.schemastore.org/cargo.json'),
    \ '^(.*(/|\\)pyproject\.toml|pyproject\.toml)$': VimConfigSchemaUri('pyproject.json', 'https://json.schemastore.org/pyproject.json'),
    \ '^(.*(/|\\)\.?rustfmt\.toml|rustfmt\.toml)$': VimConfigSchemaUri('rustfmt.json', 'https://json.schemastore.org/rustfmt.json'),
    \ '^(.*(/|\\)rust-toolchain(\.toml)?|rust-toolchain(\.toml)?)$': VimConfigSchemaUri('rust-toolchain.json', 'https://json.schemastore.org/rust-toolchain.json'),
    \}
  else
    let l:schema['associations'] = {}
  endif
  return {
  \ 'activationStatus': v:true,
  \ 'schema': l:schema,
  \}
endfunction

function! s:TaploWorkspaceConfig(name, key) abort
  return {'evenBetterToml': s:TaploInitOptions(a:name, a:key)}
endfunction

" YAML 里 docker-compose 的官方 schema 指向 raw.githubusercontent；本地有缓存
" 就换成本地 file://（快、离线也能校验），没有则保留远程 URL（正常网络够用）。
function! s:YamlWorkspaceConfig(name, key) abort
  let l:enabled = s:SchemaEnabled()
  let l:schemas = {}
  if l:enabled
    let l:schemas = exists('*lsp_settings#utils#load_schemas_map') ? lsp_settings#utils#load_schemas_map(a:name) : {}
    if filereadable(VimConfigSchemaPath('compose-spec.json'))
      let l:local_compose = VimConfigSchemaUri('compose-spec.json', '')
      for [l:url, l:patterns] in items(l:schemas)
        if l:url =~# 'raw\.githubusercontent\.com/compose-spec/compose-go/'
          call remove(l:schemas, l:url)
          let l:schemas[l:local_compose] = l:patterns
          break
        endif
      endfor
    endif
  endif
  " schemaStore.enable 是 yaml-language-server 的开关：关闭后连内置 SchemaStore 也停用；
  " yaml.validate 保持 true，所以 YAML 语法诊断仍然保留
  return {'yaml': {'format': {'enable': v:true}, 'validate': v:true,
  \ 'schemas': l:schemas, 'schemaStore': {'enable': l:enabled}}}
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

" fish-lsp：vim-lsp-settings 暂无 fish 配置，这里手动注册
" （Arch 有 fish-lsp 包，启动命令是 fish-lsp start）
function! s:FishCmd(exe, server_info) abort
  if empty(a:exe)
    return []
  endif
  return [a:exe, 'start']
endfunction
function! s:RegisterFishServer() abort
  let l:exe = exists('*lsp_settings#exec_path') ? lsp_settings#exec_path('fish-lsp') : (executable('fish-lsp') ? 'fish-lsp' : '')
  call lsp#register_server({
  \ 'name': 'fish-lsp',
  \ 'cmd': function('s:FishCmd', [l:exe]),
  \ 'allowlist': ['fish'],
  \ 'workspace_config': {},
  \ })
endfunction

augroup my_fish_server
  autocmd!
  autocmd User lsp_setup call s:RegisterFishServer()
augroup END

" kdl-lsp：vim-lsp-settings 暂无 KDL 配置；Arch 有 kdl-lsp 包，
" 常用于 Zellij 等工具的 KDL 配置文件
function! s:KdlCmd(exe, server_info) abort
  if empty(a:exe)
    return []
  endif
  return [a:exe]
endfunction
function! s:RegisterKdlServer() abort
  let l:exe = exists('*lsp_settings#exec_path') ? lsp_settings#exec_path('kdl-lsp') : (executable('kdl-lsp') ? 'kdl-lsp' : '')
  call lsp#register_server({
  \ 'name': 'kdl-lsp',
  \ 'cmd': function('s:KdlCmd', [l:exe]),
  \ 'allowlist': ['kdl'],
  \ 'workspace_config': {},
  \ })
endfunction

augroup my_kdl_server
  autocmd!
  autocmd User lsp_setup call s:RegisterKdlServer()
augroup END


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

function! s:RecomputeSchemaConfig(name) abort
  if a:name ==# 'vscode-json-language-server'
    return s:JsonWorkspaceConfig(a:name, 'workspace_config')
  elseif a:name ==# 'yaml-language-server'
    return s:YamlWorkspaceConfig(a:name, 'workspace_config')
  elseif a:name ==# 'taplo-lsp'
    return s:TaploWorkspaceConfig(a:name, 'workspace_config')
  endif
  return {}
endfunction

" <leader>ls：只开关 schema 校验（JSON/YAML/TOML 的 schema 关联），
" 不停 LSP server、不影响补全；需要在配置文件里临时关掉 schema 红线时用
function! s:ToggleSchemaValidation() abort
  let g:vim_config_schema_validation = s:SchemaEnabled() ? 0 : 1
  let l:enabled = g:vim_config_schema_validation
  let l:updated = 0
  if exists('*lsp#get_server_info')
    for l:name in ['vscode-json-language-server', 'yaml-language-server', 'taplo-lsp']
      let l:info = lsp#get_server_info(l:name)
      if empty(l:info)
        continue
      endif
      let l:config = s:RecomputeSchemaConfig(l:name)
      if empty(l:config)
        continue
      endif
      " 直接替换成完整 dict，避免原来的 Funcref 让 lsp#update_workspace_config 拒绝工作；
      " 空 schemas 需要整体替换才能清掉旧的 map
      let l:info['workspace_config'] = l:config
      let l:info['_workspace_config_sent'] = v:false
      if exists('*lsp#is_server_running') && lsp#is_server_running(l:name)
        try
          call lsp#update_workspace_config(l:name, {})
          let l:updated += 1
        catch
          " 更新失败也不影响全局开关；server 下次启动会读到新配置
        endtry
      endif
    endfor
  endif
  echo printf('Schema 校验：%s（补全 / LSP 服务不受影响%s）',
        \ l:enabled ? '开启' : '关闭',
        \ l:updated > 0 ? '，已通知运行中的 server' : '')
endfunction

command! LspCompletionToggle call s:ToggleLspCompletion()
command! LspServiceToggle call s:ToggleLspService()
command! LspSchemaToggle call s:ToggleSchemaValidation()
nnoremap <leader>lc <Cmd>LspCompletionToggle<CR>
nnoremap <leader>lx <Cmd>LspServiceToggle<CR>
nnoremap <leader>ls <Cmd>LspSchemaToggle<CR>
endif  " g:vim_config_has_lsp
