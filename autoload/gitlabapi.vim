" 日本語ファイル
scriptencoding utf-8

let s:save_cpo = &cpo
set cpo&vim

let s:VITAL = vital#of('vim-gitlab')
let s:HTTP = s:VITAL.import('Web.HTTP')
let s:JSON = s:VITAL.import('Web.JSON')

function! gitlabapi#session(url, id, email, password)
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
endfunction

function! gitlabapi#token(url, id, email, password)
  let url = a:url . '/api/v3'
  let ret = gitlabapi#session(url, a:id, a:email, a:password)
  if ret.success
    return {'url' : url, 'token' : ret.content.private_token}
  else
    throw 'gitlabapi#token() failed, statu=' . ret.status
  endif
endfunction

function! s:throw_error(session, api, ret)
  return a:api . ' failed: status=' . a:ret.status . ' at ' . a:session.url
endfunction

function! gitlabapi#project_id(session, name) 
  let prjs = gitlabapi#projects(a:session)

  if type(prjs) == type([])
    for p in prjs
      if p.name == a:name
        return p.id
      endif
    endfor
  else
    if prjs.project_name == a:name
      return prjs.project_id
    endif
  endif

  return -1
endfunction

function! gitlabapi#projects(session, ...)
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
endfunction

function! gitlabapi#issues(session, ...)
  if a:0 == 0
    let url = a:session.url . '/issues'
  else
    let url = a:session.url . '/projects/' . a:1 . '/issues'
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
    echo ret.status . ", " . url
    throw s:throw_error(a:session, "issues", ret)
  endif
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set et ts=2 sts=2 sw=2 tw=0 foldmethod=marker commentstring=\ "\ %s:
