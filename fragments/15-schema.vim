" ── 15 schema 缓存路径与下载（独立于 LSP 开关）──────────

" 用户数据目录（schema 缓存），遵循 XDG；本地没有缓存时自动回退远程 URL
let g:vim_config_data_home = empty($XDG_DATA_HOME) ? expand('~/.local/share') : $XDG_DATA_HOME
let g:vim_config_schema_dir = g:vim_config_data_home . '/vim-schemas'
function! VimConfigSchemaPath(name) abort
  return g:vim_config_schema_dir . '/' . a:name
endfunction

function! VimConfigSchemaUri(name, remote) abort
  let l:path = VimConfigSchemaPath(a:name)
  if !filereadable(l:path)
    return a:remote
  endif
  let l:uri_path = substitute(l:path, '\\', '/', 'g')
  return 'file://' . substitute(l:uri_path, ' ', '%20', 'g')
endfunction

" Schema 校验说明：
"   JSON → vim-lsp-settings 自带 SchemaStore 目录（1117 条），按文件名自动匹配
"   YAML → 同上；docker-compose 本地缓存存在时优先本地，否则远程
"   TOML → cargo / pyproject / rustfmt / rust-toolchain；文件内也可写 #:schema
"   本地缓存目录：$XDG_DATA_HOME/vim-schemas（缺省 ~/.local/share/vim-schemas）
"   换新机器后可执行 :LspFetchSchemas 一次性拉取缓存（不执行也能用，走远程）
"   补充自定义 schema（会与目录合并）：
" let g:lsp_settings['yaml-language-server'].schemas = [{'fileMatch': ['myconf.yml'], 'url': 'https://example.com/myconf.json'}]

" 可选：把常用 schema 缓存到本地（新机器执行一次；失败不影响远程回退）
function! VimConfigFetchSchemas() abort
  if !executable('curl') && !executable('wget')
    echo 'LspFetchSchemas: 需要 curl 或 wget'
    return
  endif
  call mkdir(g:vim_config_schema_dir, 'p')
  let l:files = [
  \ ['cargo.json', 'https://json.schemastore.org/cargo.json'],
  \ ['pyproject.json', 'https://json.schemastore.org/pyproject.json'],
  \ ['rustfmt.json', 'https://json.schemastore.org/rustfmt.json'],
  \ ['rust-toolchain.json', 'https://json.schemastore.org/rust-toolchain.json'],
  \ ['compose-spec.json', 'https://cdn.jsdelivr.net/gh/compose-spec/compose-go@master/schema/compose-spec.json'],
  \ ]
  let l:failed = 0
  for [l:name, l:url] in l:files
    if filereadable(VimConfigSchemaPath(l:name))
      continue
    endif
    if executable('curl')
      call system(['curl', '-fsSL', '--connect-timeout', '10', '--max-time', '60', '-o', VimConfigSchemaPath(l:name), l:url])
    else
      call system(['wget', '-q', '-O', VimConfigSchemaPath(l:name), l:url])
    endif
    if v:shell_error != 0
      let l:failed += 1
      silent! call delete(VimConfigSchemaPath(l:name))
      echo 'LspFetchSchemas: 下载失败 ' . l:name
    else
      echo 'LspFetchSchemas: 已缓存 ' . l:name
    endif
  endfor
  echo 'schema 缓存目录: ' . g:vim_config_schema_dir . (l:failed ? ('（失败 ' . l:failed . ' 个）') : '')
endfunction
command! LspFetchSchemas call VimConfigFetchSchemas()
