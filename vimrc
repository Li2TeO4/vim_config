" ── 配置来源标记（install.sh / update.sh 识别用，勿删）────
" vim_config-managed: https://github.com/Li2TeO4/vim_config
let g:vim_config_managed = 'Li2TeO4/vim_config'

" 配置目录（默认 ~/.config/vim），fragments/ 里是拆分后的各段配置
let g:vim_config_dir = expand('<sfile>:p:h')
let g:vim_config_vimrc = expand('<sfile>:p')
let g:vim_config_readme = g:vim_config_dir . '/README.md'

" 把配置目录和旧的 ~/.vim 加进 runtimepath：
"   - 配置目录：以后可以放 autoload/ 等 Vim runtime 文件
"   - ~/.vim：继续复用已有的 vim-plug（autoload/plug.vim）和插件目录（plugged/）
for s:dir in [g:vim_config_dir, expand('~/.vim')]
  if isdirectory(s:dir) && index(split(&runtimepath, ','), s:dir) < 0
    execute 'set runtimepath^=' . fnameescape(s:dir)
  endif
endfor

" 顺序固定：先基础/路径/schema，再键位/UI，然后 LSP、插件、主题、自检/修复
if isdirectory(g:vim_config_dir . '/fragments')
  for s:file in [
  \ 'fragments/00-options.vim',
  \ 'fragments/10-paths.vim',
  \ 'fragments/15-schema.vim',
  \ 'fragments/20-keymaps.vim',
  \ 'fragments/30-clipboard.vim',
  \ 'fragments/40-scrollpad.vim',
  \ 'fragments/50-lsp.vim',
  \ 'fragments/60-plugins.vim',
  \ 'fragments/70-theme.vim',
  \ 'fragments/80-check.vim',
  \ 'fragments/90-fix.vim',
  \ ]
    execute 'source' fnameescape(g:vim_config_dir . '/' . s:file)
  endfor
else
  echohl WarningMsg
  echomsg 'vim_config: 找不到 ' . g:vim_config_dir . '/fragments，请重新运行 install.sh'
  echohl None
endif
