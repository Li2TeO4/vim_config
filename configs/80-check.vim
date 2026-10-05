" ── 80 换机自检（:VimConfigCheck）──────────────────────
" :VimConfigCheck 检查特性/插件/LSP server/schema 缓存/剪贴板/外部命令，
" 结果列在临时窗口里，并给出缺失项的补装提示
function! VimConfigCheckExec(cmd) abort
  try
    let l:path = lsp_settings#exec_path(a:cmd)
    if !empty(l:path)
      return l:path
    endif
  catch
  endtry
  return executable(a:cmd) ? a:cmd : ''
endfunction

function! VimConfigCheckLines() abort
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
  call add(l:lines, '[LSP可用] ' . (g:vim_config_has_lsp ? '是' : '否（已跳过 LSP 配置）'))
  call add(l:lines, '[来源] ' . get(g:, 'vim_config_managed', '未标记（不受 install/update 脚本管理）'))
  call add(l:lines, '')

  " 插件
  call add(l:lines, '[插件]')
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
  if !g:vim_config_has_lsp
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
    \ ['xml', 'lemminx'],
    \ ['systemd', 'systemd-lsp'],
    \ ['cmake', 'cmake-language-server'],
    \ ['lua', 'sumneko-lua-language-server'],
    \ ['terraform', 'terraform-ls'],
    \ ['fish', 'fish-lsp'],
    \ ['bzl', 'starpls'],
    \ ['just', 'just-lsp'],
    \ ['kdl', 'kdl-lsp'],
    \ ]
    let l:missing_servers = []
    for [l:ft, l:cmd] in l:server_specs
      let l:path = VimConfigCheckExec(l:cmd)
      call add(l:lines, printf('  %-12s %-30s %s', l:ft, l:cmd, empty(l:path) ? '缺失' : 'OK  ' . l:path))
      if empty(l:path)
        call add(l:missing_servers, l:cmd)
      endif
    endfor
    if !empty(l:missing_servers)
      call add(l:lines, '  -> 缺 ' . len(l:missing_servers) . ' 个：优先 :VimConfigFix；系统包安装用 ./language-server-add.sh')
    endif
    if empty(VimConfigCheckExec('lemminx')) && empty(VimConfigCheckExec('java'))
      call add(l:lines, '  提示：xml(lemminx) 需要 Java；Arch 执行 ./language-server-add.sh 会自动装 java-runtime')
    endif
    call add(l:lines, '  shellcheck（可选，bash 诊断增强）: ' . (empty(VimConfigCheckExec('shellcheck')) ? '缺失' : 'OK'))
  endif
  call add(l:lines, '')

  " schema 缓存
  call add(l:lines, '[Schema 缓存] ' . g:vim_config_schema_dir)
  let l:schema_files = ['cargo.json', 'pyproject.json', 'rustfmt.json', 'rust-toolchain.json', 'compose-spec.json']
  let l:schema_line = []
  let l:schema_ok = 0
  for l:name in l:schema_files
    let l:ok = filereadable(VimConfigSchemaPath(l:name))
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
    let l:clip_name = VimConfigClipBackendName()
    if !empty(l:clip_name)
      call add(l:lines, '  外部桥接可用：' . l:clip_name)
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
function! VimConfigShowScratch(name, lines) abort
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
  call VimConfigShowScratch('VimConfigCheck', VimConfigCheckLines())
endfunction

command! VimConfigCheck call s:ConfigCheck()
