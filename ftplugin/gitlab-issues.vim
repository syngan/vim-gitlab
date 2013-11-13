if exists("b:did_ftplugin") || !exists('b:gitlab')
  finish
endif

let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim


setlocal buftype=nofile noswapfile nobuflisted bufhidden=unload

nnoremap <buffer> <silent> <Plug>(gitlab-issues-action)
\        :<C-u>call b:gitlab.action()<CR>

silent! nmap <buffer> <unique> <CR> <Plug>(gitlab-issues-action)

if b:gitlab.type ==# 'view'
  setlocal nonumber nolist
  if b:gitlab.mode ==# 'list'
    setlocal nowrap
  endif
  nnoremap <buffer> <silent> <Plug>(gitlab-issues-issue-list)
  \        :<C-u>call b:gitlab.open()<CR>
  nnoremap <buffer> <silent> <Plug>(gitlab-issues-redraw)
  \        :<C-u>call b:gitlab.read()<CR>
  nnoremap <buffer> <silent> <Plug>(gitlab-issues-reload)
  \        :<C-u>call b:gitlab.reload()<CR>
  nnoremap <buffer> <silent> <Plug>(gitlab-issues-next)
  \        :<C-u>call b:gitlab.move(v:count1)<CR>
  nnoremap <buffer> <silent> <Plug>(gitlab-issues-prev)
  \        :<C-u>call b:gitlab.move(-v:count1)<CR>

  nmap <buffer> <BS> <Plug>(gitlab-issues-issue-list)
  nmap <buffer> <C-t> <Plug>(gitlab-issues-issue-list)
  nmap <buffer> r <Plug>(gitlab-issues-redraw)
  nmap <buffer> R <Plug>(gitlab-issues-reload)
  nmap <buffer> <C-r> <Plug>(gitlab-issues-reload)
  nmap <buffer> <C-l> <Plug>(gitlab-issues-next)
  nmap <buffer> <C-h> <Plug>(gitlab-issues-prev)

  augroup ftplugin-gitlab-issues
    autocmd! * <buffer>
    autocmd BufEnter <buffer> call b:gitlab.read()
  augroup END
endif


let &cpo = s:cpo_save
unlet s:cpo_save
