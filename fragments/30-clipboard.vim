" ── 30 系统剪贴板 provider（Wayland / X11 / macOS）────
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

" 给 :VimConfigCheck / :VimConfigFix 用的全局查询入口（脚本内 s:ClipBackend 不跨文件）
function! VimConfigClipBackendName() abort
  if has('clipboard') || !has('clipboard_provider')
    return ''
  endif
  try
    let l:backend = s:ClipBackend()
  catch
    return ''
  endtry
  return empty(l:backend) ? '' : get(l:backend, 'name', '')
endfunction
