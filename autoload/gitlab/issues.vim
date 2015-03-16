" Access to the Gitlab Issues.
" Author : syngan

" original source is:
" Access to the Github Issues.
" Version: 0.1.0
" Author : thinca <thinca+vim@gmail.com>
" License: zlib License

let s:save_cpo = &cpo
set cpo&vim

" Keep the issues.
let s:repos = {}

" Issues object " {{{
let s:Issues = gitlab#base()
let s:Issues.name = 'issues'

function! s:Issues.initialize(site, user, repos)
  let [self.site, self.user, self.repos] = [a:site, a:user, a:repos]
  let self.issues = []  " issues: Always sorted by issue number.
endfunction


function! s:Issues.getidx(number)
  let left = 0
  let right = len(self.issues) - 1
  while left <= right
    let mid = (left + right) / 2
    " echomsg "get(" . a:number . ") :" . left . "," . mid . "," . right . " : " . self.issues[mid].iid
    if self.issues[mid].iid > a:number
      let left = mid + 1
    elseif self.issues[mid].iid < a:number
      let right = mid - 1
    else
      return mid
    endif
  endwhile
  return -1
endfunction

function! s:Issues.get(number)
  let idx = self.getidx(a:number)
  if idx < 0
    " for c in range(len(self.issues))
    "   echomsg "issues[" . c . "]=" . self.issues[c].iid
    " endfor
    throw "unknown issue #" . a:number . " /" . len(self.issues)
  endif
  return self.issues[idx]
endfunction

function! s:Issues.set(number, val)
  let idx = self.getidx(a:number)
  if idx < 0
    throw "unknown issue #" . a:number
  endif
  let self.issues[idx] = a:val
endfunction


function! s:Issues.list()
  return copy(self.issues)
endfunction

function! s:Issues.comment_count(number)
  let comments = self.get(a:number).comments
  return type(comments) == type(0) ? comments : len(comments)
endfunction

function! s:get_issue_all(self)
  let issues = a:self.connect('GET', '/projects/:id/issues', {}, 1)
  return issues
endfunction

function! s:Issues.update_list()
  let open = s:get_issue_all(self)
  call map(open, 's:normalize_issue(v:val)')
  let self.issues = sort(open, s:func('order_by_number'))
endfunction

function! s:Issues.create_new_issue(title, body, labels)
   " title (required) - The title of an issue
   " description (optional) - The description of an issue
   " assignee_id (optional) - The ID of a user to assign issue
   " milestone_id (optional) - The ID of a milestone to assign issue
   " labels (optional) - Comma-separated label names for an issue
  let path = "/projects/:id/issues"
  let param = {'title' : a:title, 'description' : a:body}
  if len(a:labels) > 0
    let param.labels = a:labels
  endif
  let issue = self.connect('POST', path, param, 0)[0]
  call add(self.issues, s:normalize_issue(issue))
  let self.issues = sort(self.issues, s:func('order_by_number'))

  return issue
endfunction

function! s:Issues.update_issue(number, title, body, labels)
  " number: issue #ID: iid
  let issue = self.get(a:number)
  let path = "/projects/:id/issues/" . issue.id
  let param = {'title' : a:title, 'description' : a:body}
  if len(a:labels) > 0
    let param.labels = join(a:labels, ',')
  endif
  let resp = self.connect('PUT', path, param, 0)[0]
  let resp.comments = self.get(a:number).comments
"  let self.get(a:number) = res
"  let self.issues[self.rev_index[a:number]] = resp
  call self.set(a:number, resp)
endfunction

function! s:Issues.get_comment(number, id)
  let issue = self.get(a:number)
  let path = "/projects/:id/issues/" . issue.id . "/notes/" . a:id
  let param = {}
  let comment = self.connect('GET', path, param, 0)[0]
  if type(comment) == type([])
    return comment[0].body
  else
    return comment.body
  endif
endfunction

function! s:Issues.add_comment(number, id, comment)
  let issue = self.get(a:number)
  let path = "/projects/:id/issues/" . issue.id . "/notes"
  if a:id !=# 'new'
    let path .= '/' . a:id
  endif
  let param = {'body' : a:comment}
  let comment = self.connect('POST', path, param, 0)[0]
  if a:id ==# 'new'
    call add(self.get(a:number).comments, comment)
  else
    call self.fetch_comment(a:number, 1)
  endif
endfunction

function! s:Issues.fetch_comments(number, ...)
  let issue = self.get(a:number)
  let force = a:0 && a:1
  if force || !has_key(issue, 'comments') || type(issue.comments) == type(0)
    let id = issue.id
    let path = "/projects/:id/issues/" . id . "/notes"
    let issue.comments = self.connect('GET', path, {}, 0)
  endif
endfunction


function! s:Issues.close(number)
  let issue = self.get(a:number)
  let path = "/projects/:id/issues/" . issue.id
  let param = {'state_event' : 'close'}
  let resp = self.connect('PUT', path, param, 0)[0]
  let resp.comments = self.get(a:number).comments
  call self.set(a:number, resp)
endfunction

function! s:Issues.reopen(number)
  let issue = self.get(a:number)
  let path = "/projects/:id/issues/" . issue.id
  let param = {'state_event' : 'reopen'}
  let resp = self.connect('PUT', path, param, 0)[0]
  let resp.comments = self.get(a:number).comments
  call self.set(a:number, resp)
endfunction

function! s:Issues.connect(method, url, data, is_pagelist)

  let token = self.get_token()
  let proj_id = gitlabapi#project_id(token, self.user, self.repos)
  if proj_id < 0
    throw "project not found: " . self.user . "/" . self.repos
  endif

  let url = substitute(a:url, '/:id/', '/' . proj_id . '/', '')

  if a:is_pagelist
    let page = 1
    let resp = []
    while 1
      let a:data.per_page = 100
      let a:data.page = page
      let data = gitlabapi#connect(token, a:method, url, a:data)
      let resp += data
      if len(data) < 100
        break
      endif
      let page += 1
    endwhile

    return resp
  else
    let resp = gitlabapi#connect(token, a:method, url, a:data)
    return resp
  endif
endfunction

function! s:normalize_issue(issue)
  if !has_key(a:issue, 'iid')
    let a:issue.iid = a:issue.id
  endif
  if a:issue.state == 'reopened'
    let a:issue.state = 'opened'
  endif
  if !has_key(a:issue, 'title')
    let a:issue.title = "NO TITLE"
  endif
  return a:issue
endfunction

function! s:get_issue(site, user, repos)
  let key = a:user . '/' . a:repos
  if !has_key(s:repos, key)
    let issues = s:Issues.new(a:site, a:user, a:repos)
    call issues.update_list()
    let s:repos[key] = issues
  endif
  return s:repos[key]
endfunction
 " }}}

" UI object " {{{
let s:UI = {'name': 'issues'}

function! s:UI.initialize(site, path)
"echomsg "gitlab#issues iniaialize() start: " . a:path
  let pathinfo = gitlab#parse_path(a:path, '/:user/:repos/\?::path')
  if empty(pathinfo)
    throw 'gitlab: issues: Require the repository name.'
  endif

"  let path = pathinfo.path
  let self.site = a:site
  let self.path = split(pathinfo.path, '/')
  let self.type =
  \   get(self.path, -1, '') =~# '^\%(edit\|new\)$' ? 'edit' : 'view'
  if empty(self.path)
    let self.mode = 'list'
  elseif get(self.path, 1) is 'comment'
    let self.mode = 'comment'
  else
    let self.mode = 'issue'
  endif
  " number: 0 = list, 'new' = new, 1 or more = id
  let self.number = get(self.path, 0, 0)

  let self.issues = s:get_issue(a:site, pathinfo.user, pathinfo.repos)
  call self.update_issue_list()
endfunction

function! s:UI.update_issue_list()
  " Save the sorted list
"echomsg "gitlab#issues update_issue_list() start: " . len(self.issues)
  let list = sort(self.issues.list(), s:func('compare_list'))
  let self.issue_list = list
  let length = len(self.issue_list)
  let self.rev_index = {}
  " issues ID で index
  for i in range(length)
    let self.rev_index[list[i].iid] = i
  endfor
endfunction

" @vimlint(EVL102, 1, l:path)
function! s:UI.open(...)
  let base = [self.site, self.name, self.issues.user, self.issues.repos]

  let args = gitlab#flatten(a:000)
  let path = printf('gitlab://%s', join(base + args, '/'))
  let edit = get(args, -1, '') =~# '^\%(edit\|new\)$'
  " TODO: Opener is made customizable.
  let opener = edit || &l:filetype !=# 'gitlab-issues' ? 'new' : 'edit'
  execute opener '`=path`'
endfunction
" @vimlint(EVL102, 0, l:path)

function! s:UI.updated()
  if self.type ==# 'view' && self.mode ==# 'list'
    if exists('w:gitlab_issues_last_opened')
      call search('^\s*' . w:gitlab_issues_last_opened . ':', 'w')
      unlet w:gitlab_issues_last_opened
    endif
  endif
endfunction

function! s:UI.header()
  return printf('Gitlab Issues - %s/%s', self.issues.user, self.issues.repos)
endfunction

function! s:UI.view_list()
  return ['[[new issue]]'] +
  \ map(copy(self.issue_list), 'self.line_format(v:val)')
endfunction

function! s:UI.view_issue()
  call self.issues.fetch_comments(self.number)

  let self.issue = self.issues.get(self.number)
  let w:gitlab_issues_last_opened = self.number

  return ['[[edit]] ' . (self.issue.state ==# 'closed' ?
  \       '[[reopen]]' : '[[close]]')] + self.issue_layout(self.issue)
endfunction

function! s:UI.edit_issue()
  let text = ['[[POST]]']
  if self.number is 'new'
    let [title, labels, body] = ['', [], '']
  else
    let i = self.issues.get(self.number)
    let [title, labels, body] = [i.title, i.labels, i.description]
    let text += ['number: ' . self.number]
  endif
  let text += ['title: ' . title]
  call add(text, 'labels: ' . join(labels, ', '))
  return text + ['body:'] + split(body, '\r\?\n', 1)
endfunction

function! s:UI.edit_comment()
  " path= [number, 'comment', id, 'edit']
  if self.path[2] !=# 'new'
    let comment = self.issues.get_comment(self.number, self.path[2])
  else
    let comment = ''
  endif

  return ['[[POST]]',
        \ 'number: ' . self.number,
        \ 'id: ' . self.path[2],
        \ 'comment:', comment]
endfunction

function! s:UI.line_format(issue)
  return printf('%3d: %-8s| %s%s',
        \ a:issue.iid,
        \ a:issue.state,
  \      join(map(copy(a:issue.labels), '"[". v:val ."]"'), ''),
  \      substitute(a:issue.title, '\n', '', 'g'))
endfunction

function! s:UI.issue_layout(issue)
  let i = a:issue
  let lines = [
  \ i.iid . ': ' . i.title,
  \ 'user: ' . i.author.username,
  \ 'labels: ' . join(i.labels, ', '),
  \ 'created: ' . i.created_at,
  \ ]

  if i.created_at !=# i.updated_at
    let lines += ['updated: ' . i.updated_at]
  endif
  if has_key(i, 'closed_at') && i.closed_at != 0
    let lines += ['closed: ' . i.closed_at]
  endif
  if has_key(i, 'votes') && i.votes != 0
    let lines += ['votes: ' . i.votes]
  endif

  let lines += [''] + split(i.description, '\r\?\n') + ['', '']

"  \ '  ' . c.author.username . ' ' . c.created_at . ' [[EditNote' . c.id . ']]',
  for c in i.comments
    let lines += [
    \ '------------------------------------------------------------',
    \ '  ' . c.author.username . ' ' . c.created_at,
    \ '',
    \ ]
    let lines += map(split(c.body, '\r\?\n'), 'v:val')
    unlet c
  endfor

  let lines += ['', '', '[[add comment]]']

  return lines
endfunction
 " }}}

" Control. " {{{
function! s:UI.action()
  try
    call self.perform(gitlab#get_text_on_cursor('\[\[.\{-}\]\]'))
  catch /^gitlab:/
    echohl ErrorMsg
    echomsg v:exception
    echohl None
  endtry
endfunction

function! s:UI.perform(button)
"echomsg "gitlab#issues perform()" . has_key(self, "site")
  let button = a:button
  if self.mode ==# 'list'
    if button ==# '[[new issue]]'
      call self.open('new')
    else
      let number = matchstr(getline('.'), '^\s*\zs\d\+\ze\s*:')
      if number =~ '^\d\+$'
        call self.open(number)
      endif
    endif
  elseif self.mode ==# 'issue' && self.type ==# 'view'
    if button ==# '[[edit]]'
      call self.open(self.number, 'edit')
    elseif button ==# '[[close]]'
      call self.issues.close(self.number)
      call self.open(self.number)
    elseif button ==# '[[reopen]]'
      call self.issues.reopen(self.number)
      call self.open(self.number)
    elseif button ==# '[[add comment]]'
      call self.open(self.number, 'comment', 'new')
    elseif button =~# '\[\[EditNote[0-9]*\]\]'
      echo self.open(self.number, 'comment', substitute(button, '[^0-9]', '', 'g'), 'edit')
    endif
  elseif self.mode ==# 'issue' && self.type ==# 'edit'
    if button ==# '[[POST]]'
      let c = getpos('.')
      try
        let bodystart = search('^\cbody:', 'n')
        if !bodystart
          throw 'gitlab: issues: No body.'
        endif
        let body = join(getline(bodystart + 1, '$'), "\n")

        let titleline = search('^\ctitle:', 'Wn', bodystart)
        if !titleline
          throw 'gitlab: issues: No title.'
        endif
        let title = matchstr(getline(titleline), '^\w\+:\s*\zs.\{-}\ze\s*$')
        if title == ''
          throw 'gitlab: issues: Title is empty.'
        endif

        let labelsline = search('^\clabels:', 'Wn', bodystart)
        if labelsline
          let labels = filter(split(matchstr(getline(labelsline),
          \                   '^\w\+:\s*\zs.\{-}\ze\s*$'), '\s*,\s*'),
          \                   'v:val !~ "^\\s*$"')
        else
          let labels = []
        endif

        let numberline = search('^\cnumber:', 'Wn', bodystart)
        if numberline
          let number = matchstr(getline(numberline),
          \                     '^\w\+:\s*\zs.\{-}\ze\s*$')
          call self.issues.update_issue(number, title, body, labels)

        else
          let issue = self.issues.create_new_issue(title, body, labels)
          let number = issue.iid
        endif

      finally
        call setpos('.', c)
      endtry
    endif
  elseif self.mode ==# 'comment'
    if button ==# '[[POST]]'
      let c = getpos('.')
      try
        let commentstart = search('^\ccomment:', 'n')
        if !commentstart
          throw 'gitlab: issues: No comment.'
        endif
        let comment = join(getline(commentstart + 1, '$'), "\n")

        let numberline = search('^\cnumber:', 'Wn', commentstart)
        let number = matchstr(getline(numberline), '^\w\+:\s*\zs.\{-}\ze\s*$')


        let idline = search('^\cid:', 'Wn', commentstart)
        let id = matchstr(getline(idline), '^\w\+:\s*\zs.\{-}\ze\s*$')

        call self.issues.add_comment(number, id, comment)

      finally
        call setpos('.', c)
      endtry
    endif
  endif

  call self.update_issue_list()

  if self.type ==# 'edit' && button ==# '[[POST]]'
    close
  endif
endfunction

function! s:UI.reload()
  if self.mode ==# 'list'
    call self.issues.update_list()
    call self.update_issue_list()
    call self.open()
  elseif self.mode ==# 'issue' && self.type ==# 'view'
    let self.issue.comments = 0
    call self.open(self.issue.iid)
  endif
endfunction

function! s:UI.move(cnt)
  let idx = (has_key(self, 'issue') ? self.rev_index[self.issue.iid]
  \                                 : -1) + a:cnt
  let length = len(self.issue_list)
  if idx == -2  " <C-k> in issue list.
    let idx = length - 1
  endif
  if idx < 0 || length <= idx
    call self.open()
  else
    call self.open(self.issue_list[idx].iid)
  endif
endfunction

function! s:UI.read()
  let cursor = getpos('.')
  setlocal modifiable noreadonly
  let name = self.type . '_' . self.mode
"echo "UI.read(): " . name
  silent % delete _
  silent 0put =self.header()
  silent $put =self[name]()
  if self.type ==# 'view'
    setlocal nomodifiable readonly
  endif
  call setpos('.', cursor)
  call self.updated()
endfunction


function! s:UI.invoke(site, args)
  if empty(a:args)
    throw 'gitlab: issues: Require the repository name.'
  endif
  let repos = a:args[0]
  let path = repos =~# '/' ? split(repos, '/')[0 : 1]
  \                        : [g:gitlab_config[a:site].user, repos]
  if 2 <= len(a:args)
    call add(path, a:args[1])
  endif

  let ui = self.new(a:site, '/' . join(path, '/'))
  let ui.site = a:site
  call ui.open(path[2 :])
endfunction
 " }}}

" Misc.  " {{{
function! s:order_by_number(a, b)
  return a:b.id - a:a.id
endfunction

function! s:compare_list(a, b)
  " TODO: Be made customizable.
  if a:a.state ==# a:b.state
    return a:b.id - a:a.id
  else
    return a:a.state ==# 'opened' ? -1 : 1
  endif
endfunction

function! s:list_sub(a, b)
  " Difference of list (a - b)
  let a = copy(a:a)
  call map(reverse(sort(filter(map(copy(a:b), 'index(a, v:val)'),
  \                            '0 <= v:val'))), 'remove(a, v:val)')
  return a
endfunction

function! s:func(name)
  return function(matchstr(expand('<sfile>'), '<SNR>\d\+_\zefunc$') . a:name)
endfunction

function! gitlab#issues#new()
  return copy(s:UI)
endfunction

" }}}

" function! gitlab#issues#complete(lead, cmd, pos)"{{{
"   let token = split(a:cmd, '\s\+')
"   let ntoken = len(token)
"   if ntoken == 2
"     let res = gitlab#connect('/repos', 'show', g:gitlab#user)
"     return map(res.repositories, 'v:val.name')
"   else
"     return []
"   endif
" endfunction"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set et ts=2 sts=2 sw=2 tw=0 foldmethod=marker commentstring=\ "\ %s:
