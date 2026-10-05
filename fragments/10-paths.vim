" ── 10 环境路径 + LSP 可用性判断 ──────────────────────
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
let g:vim_config_has_lsp = has('timers') && has('lambda') && exists('*json_encode') && (has('job') || has('channel'))
