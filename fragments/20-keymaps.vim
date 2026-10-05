" ── 20 键位 ────────────────────────────────────────────
let mapleader = " "

nnoremap ww :w<CR>
nnoremap <leader>wq :wq<CR>
nnoremap <leader>q  :q<CR>
nnoremap <leader>Q  :q!<CR>
nnoremap <S-H>      ^
nnoremap <S-L>      $

" 快速注释：对齐 nvim 的 <leader>/（Comment.nvim toggle.linewise）
" 直接用 vim-commentary 的 <Plug>，避免 gcc/gc 映射在 noremap 规则下不被展开
nnoremap <leader>/ <Plug>CommentaryLine
xnoremap <leader>/ <Plug>Commentary

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

" 快速查看本配置的 README 使用说明（对齐 nvim 的 <leader>?）：
" 未打开时在新标签页打开；已打开则聚焦原窗口，只读查看
function! s:OpenReadme() abort
  let l:path = get(g:, 'vim_config_readme', '')
  if empty(l:path) || !filereadable(l:path)
    let l:path = expand('~/.config/vim/README.md')
  endif
  if !filereadable(l:path)
    let l:path = expand('~/code/vim_config/README.md')
  endif
  if !filereadable(l:path)
    echohl WarningMsg | echomsg '未找到 README.md：请先运行 install.sh / update.sh' | echohl None
    return
  endif

  let l:buf = bufnr(l:path)
  if l:buf != -1 && bufexists(l:buf)
    let l:wins = exists('*win_findbuf') ? win_findbuf(l:buf) : []
    if !empty(l:wins) && exists('*win_gotoid')
      call win_gotoid(l:wins[0])
    else
      execute 'tabnew'
      execute 'buffer' l:buf
    endif
  else
    execute 'tabnew' fnameescape(l:path)
  endif

  " 只读查看，防止误修改；并尽量去掉阅读时的 LSP 诊断干扰
  setlocal modifiable
  setlocal readonly nomodifiable
  let b:doc_readonly = 1
  if exists('*lsp#disable_diagnostics_for_buffer')
    silent! call lsp#disable_diagnostics_for_buffer()
  endif
endfunction

nnoremap <leader>? :call <SID>OpenReadme()<CR>

