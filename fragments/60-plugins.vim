" ── 60 插件（vim-plug 自举 + 缺失自动安装）──────────────
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
  Plug 'tpope/vim-commentary'           " 快速注释（gcc / gc）
  if g:vim_config_has_lsp
    Plug 'prabirshrestha/vim-lsp'         " LSP 客户端
    Plug 'mattn/vim-lsp-settings'         " LSP server 自动配置（含 SchemaStore 目录）
    Plug 'prabirshrestha/asyncomplete.vim'    " 自动补全框架
    Plug 'prabirshrestha/asyncomplete-lsp.vim' " vim-lsp 补全源
  endif
  Plug 'catppuccin/vim', { 'as': 'catppuccin' } " 主题：catppuccin（nvim 同款）
  call plug#end()

  " 插件目录缺失时，启动完成后自动补装并重新加载 vimrc（首次到新机器可用）
  let s:required_plugins = ['vim-surround', 'vim-lastplace', 'vim-commentary', 'catppuccin']
  if g:vim_config_has_lsp
    let s:required_plugins += ['vim-lsp', 'vim-lsp-settings', 'asyncomplete.vim', 'asyncomplete-lsp.vim']
  endif
  let s:missing_plugins = filter(copy(s:required_plugins), '!isdirectory(expand("~/.vim/plugged/") . v:val)')
  if !empty(s:missing_plugins)
    let s:myvimrc = empty($MYVIMRC) ? get(g:, 'vim_config_vimrc', expand('~/.config/vim/vimrc')) : $MYVIMRC
    autocmd VimEnter * PlugInstall --sync | execute 'source' fnameescape(s:myvimrc)
  endif
endif
