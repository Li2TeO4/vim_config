" ── 70 主题：catppuccin Mocha（对齐 nvim）───────────────
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
