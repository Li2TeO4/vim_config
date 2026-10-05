" ── 40 非对称 scrolloff（移植自 nvim scrollpad.lua）────
" 下方始终保留 4 个视觉行；上方尽量保留 4 行，但光标到文件顶端时允许不足。
" Vim 没有原生非对称 scrolloff，这里在 CursorMoved/CursorMovedI 时调整 topline。
if exists('*getwininfo') && exists('*win_getid') && exists('*winsaveview') && exists('*winrestview')
  let s:scrollpad_below = 4
  let s:scrollpad_above = 4
  let s:scrollpad_min_height = 10
  let s:scrollpad_busy = 0

  " 某 buffer 行在窗口里占的视觉行数（按 wrap 折行估算）
  function! s:ScrollPadVisualLines(lnum) abort
    if !&l:wrap
      return 1
    endif
    let l:effw = winwidth(0)
    let l:info = getwininfo(win_getid())
    if !empty(l:info)
      let l:effw -= get(l:info[0], 'textoff', 0)
    endif
    if l:effw <= 0
      let l:effw = 1
    endif
    let l:len = strdisplaywidth(getline(a:lnum))
    if l:len <= 0
      return 1
    endif
    return (l:len + l:effw - 1) / l:effw
  endfunction

  " start 到 end（含）之间的视觉行总数
  function! s:ScrollPadCount(start, end) abort
    if a:start > a:end
      return 0
    endif
    let l:total = 0
    let l:lnum = a:start
    while l:lnum <= a:end
      let l:total += s:ScrollPadVisualLines(l:lnum)
      let l:lnum += 1
    endwhile
    return l:total
  endfunction

  function! s:ScrollPadAdjust(...) abort
    if s:scrollpad_busy
      return
    endif
    if &l:buftype !=# '' || &l:diff
      return
    endif
    " 窗口太小就交给原生滚动，避免 4+4 行保护占满窗口
    if winheight(0) <= s:scrollpad_min_height
      return
    endif

    let l:cursor = line('.')
    let l:topline = line('w0')
    if l:cursor <= 0 || l:topline <= 0
      return
    endif

    let s:scrollpad_busy = 1
    try
      let l:win_h = winheight(0)
      let l:cursor_vlines = s:ScrollPadVisualLines(l:cursor)
      " 光标上方 / 下方还各有多少可见视觉行（不含光标行）
      let l:above_available = s:ScrollPadCount(l:topline, l:cursor - 1)
      let l:below_available = l:win_h - (l:above_available + l:cursor_vlines)

      " 下方不足 PAD_BELOW：向下滚动，把光标抬到距底部 PAD_BELOW 行
      if l:below_available < s:scrollpad_below
        let l:target_above = l:win_h - s:scrollpad_below - l:cursor_vlines
        if l:target_above < 0
          let l:target_above = 0
        endif
        let l:new_topline = l:cursor
        let l:accumulated = 0
        while l:new_topline > 1
          let l:prev_vl = s:ScrollPadVisualLines(l:new_topline - 1)
          if l:accumulated + l:prev_vl > l:target_above
            break
          endif
          let l:accumulated += l:prev_vl
          let l:new_topline -= 1
        endwhile
        if l:new_topline != l:topline
          let l:view = winsaveview()
          let l:view.topline = l:new_topline
          call winrestview(l:view)
        endif
        return
      endif

      " 上方不足 PAD_ABOVE：向上滚动（到文件顶端时上面自然不足 4 行）
      if l:above_available < s:scrollpad_above && l:topline > 1
        let l:new_topline = l:cursor
        let l:accumulated = 0
        while l:new_topline > 1
          let l:prev_vl = s:ScrollPadVisualLines(l:new_topline - 1)
          if l:accumulated + l:prev_vl > s:scrollpad_above
            break
          endif
          let l:accumulated += l:prev_vl
          let l:new_topline -= 1
        endwhile
        if l:new_topline > 0 && l:new_topline < l:topline
          let l:view = winsaveview()
          let l:view.topline = l:new_topline
          call winrestview(l:view)
        endif
      endif
    finally
      let s:scrollpad_busy = 0
    endtry
  endfunction

  function! s:ScrollPadSchedule() abort
    if exists('*timer_start')
      call timer_start(0, function('s:ScrollPadAdjust'))
    else
      call s:ScrollPadAdjust()
    endif
  endfunction

  augroup my_scrollpad
    autocmd!
    autocmd CursorMoved,CursorMovedI * call s:ScrollPadAdjust()
    autocmd VimEnter,WinEnter,BufWinEnter,VimResized * call s:ScrollPadSchedule()
  augroup END

  " 完全由本模块接管，禁用原生 scrolloff
  set scrolloff=0
endif
