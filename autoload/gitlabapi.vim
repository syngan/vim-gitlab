scriptencoding utf-8

let s:save_cpo = &cpo
set cpo&vim

let s:VITAL = vital#of('vim-gitlab') " {{{
let s:HTTP = s:VITAL.import('Web.HTTP')
let s:JSON = s:VITAL.import('Web.JSON') " }}}

function! gitlabapi#session(url, id, email, password) " {{{
  let data = {}
  let data.login = a:id
  let data.email = a:email
  let data.password = a:password

  try
    let ret = s:HTTP.post(a:url . '/session', data)
    if ret.status == 201
      return {'success' : 1, 'content' : s:JSON.decode(ret.content)}
    else
      return {'success' : 0, 'status' : ret.status}
    endif
  catch
    return {'success' : 0, 'status' : -1, 'msg' : v:exception}
  endtry
endfunction " }}}

function! gitlabapi#token(url, id, email, password) " {{{
  let url = a:url . '/api/v3'
  let ret = gitlabapi#session(url, a:id, a:email, a:password)
  if ret.success
    return {'url' : url, 'token' : ret.content.private_token}
  else
    throw s:throw_error({'url' : a:url}, "login", ret)
  endif
endfunction " }}}

function! s:throw_error(session, api, ret) " {{{

  let msg = a:ret.status
  if a:ret.status == 400
    let msg .= ": Bad Request"
  elseif a:ret.status == 401
    let msg .= ": Unauthrorized"
  elseif a:ret.status == 403
    let msg .= ": Forbidden"
  elseif a:ret.status == 404
    let msg .= ": Not Found"
  elseif a:ret.status == 405
    let msg .= ": Method Not Allowed"
  elseif a:ret.status == 409
    let msg .= ": Conflict"
  elseif a:ret.status == 500
    let msg .= ": Server Error"
  endif

  return 'gitlab: ' . a:api . ' failed: status=' . msg . ' at ' . a:session.url
endfunction " }}}

function! gitlabapi#project_id(session, path, name)  " {{{
  let prjs = gitlabapi#projects(a:session)
  if type(prjs) != type([])
    let prjs = [prjs]
  endif
  for p in prjs
    if p.path == a:name && p.namespace.path == a:path
      return p.id
    endif
  endfor

  return -1
endfunction " }}}

function! gitlabapi#projects(session, ...) " {{{
  let url = a:session.url . '/projects'
  if a:0 > 0
    let url .= '/' . a:1
  endif

  let data = {'page' : 1, 'per_page' : 100, 'private_token' : a:session.token}
  let headers = {}

  let ret = s:HTTP.get(url, data, headers)
  if ret.status == 200
    let js = s:JSON.decode(ret.content)
    if type(js) == type([])
      return js
    else
      return [js]
    endif
  else
    throw s:throw_error(a:session, "projects", ret)
  endif
endfunction " }}}


function! gitlabapi#connect(session, method, url, data) " {{{
  let url = a:session.url . a:url
  let a:data.private_token = a:session.token
  let headers = {}

"  call vimconsole#log("gitlabapi#connect: url=" . a:url)

  if a:method == 'GET'
    let ret = s:HTTP.get(url, a:data, headers)
  else
    let ret = s:HTTP.request(a:method, url, {"data" : a:data})
  endif
  if ret.status == 200 || ret.status == 201
    let js = s:JSON.decode(ret.content)
    if type(js) == type([])
      return js
    else
      return [js]
    endif
  endif
  throw s:throw_error(a:session, "", ret)
endfunction " }}}

function! gitlabapi#issues(session, page, per_page, ...) " {{{
  if a:0 == 0
    let url = '/issues'
  else
    let url = '/projects/' . a:1 . '/issues'
  endif
  let data = {'page' : a:page, 'per_page' : a:per_page}

  return gitlabapi#connect(a:session, url, data)
endfunction " }}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set et ts=2 sts=2 sw=2 tw=0 foldmethod=marker commentstring=\ "\ %s:
