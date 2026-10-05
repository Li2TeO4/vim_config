" ── 90 安全安装 LSP server + 一键修复（:VimConfigFix）──
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

if g:vim_config_has_lsp
  augroup my_lsp_install_override
    autocmd!
    " VimEnter 后用 timer 覆盖 vim-lsp-settings 定义的 :LspInstallServer，
    " 保证插件初始化完成后命令才被替换，走安全安装包装。
    autocmd VimEnter * call timer_start(0, function('s:OverrideLspInstallCommand'))
  augroup END
endif

" ── 一键修复 ──────────────────────────────────────────
" :VimConfigFix 会尽量自动补齐：vim-plug 插件、catppuccin 主题、schema 缓存；
" 缺失的 LSP server 会调用安全包装的安装器（后台终端异步安装）。
function! s:ServerManualHint(cmd) abort
  let l:hints = {
  \ 'fish-lsp': '运行 ./language-server-add.sh（Arch 包名 fish-lsp），或手动安装后重启 Vim',
  \ 'kdl-lsp': '运行 ./language-server-add.sh（Arch 包名 kdl-lsp），或手动安装后重启 Vim',
  \ 'lemminx': '需要 Java；Arch 可运行 ./language-server-add.sh（会装 lemminx + java-runtime），或先装 Java 再用 :LspInstallServer',
  \ 'starpls': '没有系统包，用 :LspInstallServer 从 GitHub release 安装，或手动安装后重启 Vim',
  \ 'just-lsp': '运行 ./language-server-add.sh（Arch 包名 just-lsp），或 :LspInstallServer',
  \ }
  return get(l:hints, a:cmd, '请手动安装')
endfunction

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
  \ ['vim-commentary', expand('~/.vim/plugged/vim-commentary'), 'dir'],
  \ ['catppuccin', expand('~/.vim/plugged/catppuccin'), 'dir'],
  \ ]
  if g:vim_config_has_lsp
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
    if !filereadable(VimConfigSchemaPath(l:name))
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
      call VimConfigFetchSchemas()
      call add(l:log, '[Schema] 下载流程结束')
      let l:actions += 1
    catch
      call add(l:log, '[Schema] 下载出错：' . v:exception)
    endtry
  endif
  call add(l:log, '')

  " 4) LSP server
  if !g:vim_config_has_lsp
    call add(l:log, '[LSP] 当前 Vim 缺少 timers/lambda/json/job，已跳过；请安装完整版 Vim')
  else
    let l:server_specs = [
    \ ['json', 'vscode-json-language-server', 1],
    \ ['yaml', 'yaml-language-server', 1],
    \ ['toml', 'taplo-lsp', 1],
    \ ['sh', 'bash-language-server', 1],
    \ ['dockerfile', 'docker-langserver', 1],
    \ ['markdown', 'marksman', 1],
    \ ['vim', 'vim-language-server', 1],
    \ ['xml', 'lemminx', executable('java') ? 1 : 0],
    \ ['systemd', 'systemd-lsp', 1],
    \ ['cmake', 'cmake-language-server', 1],
    \ ['lua', 'sumneko-lua-language-server', 1],
    \ ['terraform', 'terraform-ls', 1],
    \ ['fish', 'fish-lsp', 0],
    \ ['bzl', 'starpls', 1],
    \ ['just', 'just-lsp', 1],
    \ ['kdl', 'kdl-lsp', 0],
    \ ]
    let l:missing_servers = []
    for [l:ft, l:cmd, l:can_install] in l:server_specs
      if empty(VimConfigCheckExec(l:cmd))
        call add(l:missing_servers, [l:ft, l:cmd, l:can_install])
      endif
    endfor

    if empty(l:missing_servers)
      call add(l:log, '[LSP server] 已齐全')
    elseif l:need_restart
      call add(l:log, '[LSP server] 有缺失，但 LSP 插件刚补装；请重启 Vim 后再执行 :VimConfigFix')
    elseif !has('terminal')
      call add(l:log, '[LSP server] 有缺失，但当前 Vim 无 +terminal，无法自动安装；请手动安装')
    elseif !empty(globpath(&rtp, 'autoload/lsp_settings.vim'))
      let l:started_install = 0
      for [l:ft, l:cmd, l:can_install] in l:missing_servers
        if l:can_install == 0
          call add(l:log, printf('[LSP] %s 不自动安装：%s', l:cmd, s:ServerManualHint(l:cmd)))
          continue
        endif
        if s:InstallServerSafe(l:ft, l:cmd)
          call add(l:log, printf('[LSP] 已启动安装：%s（%s）', l:cmd, l:ft))
          let l:actions += 1
          let l:started_install = 1
        else
          call add(l:log, printf('[LSP] 启动安装失败：%s（%s）', l:cmd, s:ServerManualHint(l:cmd)))
        endif
      endfor
      if l:started_install
        call add(l:log, '[LSP] 安装器在后台终端异步运行；完成后建议重启 Vim，再 :VimConfigCheck')
      endif
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
    let l:clip_name = VimConfigClipBackendName()
    if !empty(l:clip_name)
      call add(l:log, '[剪贴板] 外部桥接可用：' . l:clip_name)
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
  call extend(l:log, VimConfigCheckLines())
  call VimConfigShowScratch('VimConfigFix', l:log)
  echo printf('VimConfigFix：执行了 %d 项修复/安装动作，结果见 VimConfigFix 窗口', l:actions)
endfunction

command! VimConfigFix call s:ConfigFix()
