" A vim client for Gitlab
" Author: syngan
"
" Original source is from https://github.com/thinca/vim-github
" An interface for Github.
" Version: 0.1.0
" Author : thinca <thinca+vim@gmail.com>
" License: zlib License



if exists('g:gitlab#loaded_gitlab')
  finish
endif

let g:gitlab#loaded_gitlab = 1

let s:save_cpo = &cpo
set cpo&vim

command! -nargs=+ -complete=customlist,gitlab#complete
\        Gitlab call gitlab#invoke(<q-args>)

augroup plugin-gitlab
  autocmd!
  autocmd BufReadCmd gitlab://* call gitlab#read(expand('<amatch>'))
augroup END

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set et ts=2 sts=2 sw=2 tw=0 foldmethod=marker commentstring=\ "\ %s:
