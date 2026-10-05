" ── 00 基础设置（选项/编码/缩进/显示）──────────────────
syntax on
set encoding=utf-8
set number
set relativenumber
" 当前行的绝对行号要用 CursorLineNr 高亮，必须开 cursorline；
" cursorlineopt=number 只高亮行号，不给整行铺底色（配合透明背景）
set cursorline
set cursorlineopt=number

" 缩进：统一真实 Tab（宽度 4）
set tabstop=4
set shiftwidth=4
set softtabstop=4
set noexpandtab
set autoindent

" 窗口分隔：竖向分隔线用更明显的 │（默认 | 太细，分屏边界看不清）
set fillchars=vert:│,fold:-,eob:~,lastline:@
