" A vim client for Gitlab
" Author: syngan
"
" Original source is from https://github.com/thinca/vim-github
" An interface for Gitlab.
" Version: 0.1.0
" Author : thinca <thinca+vim@gmail.com>
" License: zlib License

let s:save_cpo = &cpo
set cpo&vim

let s:base_path = ''
let s:token = ''

" vital.vim {{{
let s:V = vital#of('vim-gitlab')
"let s:HTML = s:VITAL.import('Web.Html')
"let s:HTTP = s:VITAL.import('Web.Http')
"let s:LIST = s:VITAL.import('Data.List')
" }}}

let s:Base = {}  " {{{1
function! s:Base.new(...)
echomsg "new() " . (has_key(self, 'name') ? self.name : "")
  let obj = copy(self)
  if has_key(obj, 'initialize')
    call call(obj.initialize, a:000, obj)
  endif
  return obj
endfunction


" API  {{{1
let s:Gitlab = s:Base.new()
function! s:Gitlab.initialize(user)
  let self.user = a:user
endfunction

function! s:get_auth_token()
  let secret = ''
  if exists('g:gitlab#password')
    let password = g:gitlab#password
  else
    let password = inputsecret('Gitlab Password for '.g:gitlab#user.':')
  endif
  if len(password) > 0
	let secret = gitlabapi#token(s:domain, "admin", "admin@local.host", password)
  endif
  return secret
endfunction

function! s:Gitlab.connect(method, path, ...)
  let method = toupper(a:method)
  let path = a:path
  let params = {}
  let raw = 0
  for a in gitlab#flatten(a:000)
    if type(a) == type(0)
      let raw = a
    elseif type(a) == type('')
      let path .= '/' . a
    elseif type(a) == type({})
      call extend(params, a)
    endif
    unlet a
  endfor

  try
    if len(s:token) == 0
      let s:token = s:get_auth_token()
    endif
    let url = printf('https://%s%s%s', s:domain, s:base_path, path)
    if method == 'GET'
      let ret = s:http.get(url, params,
      \  {'Authorization': printf('token %s', s:token)})
    else
      let ret = s:http.post(url, s:json.encode(params),
      \  {'Authorization': printf('token %s', s:token), 'Content-Type': 'application/json'}, method)
    endif
    let res = ret.content
  catch
    let res = ''
  endtry

  return raw ? s:iconv(res, 'utf-8', &encoding) : s:json.decode(res)
endfunction

" UI  {{{1
let s:UI = s:Base.new()


" Features manager.  {{{1
let s:features = {}

function! gitlab#register(feature)
  let feature = extend(copy(s:UI), a:feature)
  let s:features[feature.name] = feature
endfunction


" Interfaces.  {{{1
function! gitlab#base()
  return s:Base.new()
endfunction

function! gitlab#connect(method, path, ...)
  return s:Gitlab.new(g:gitlab#user).connect(a:method, a:path, a:000)
endfunction

function! gitlab#flatten(list)
  let list = []
  for i in a:list
    if type(i) == type([])
      let list += gitlab#flatten(i)
    else
      call add(list, i)
    endif
    unlet! i
  endfor
  return list
endfunction

function! gitlab#get_text_on_cursor(pat)
  let line = getline('.')
  let pos = col('.')
  let s = 0
  while s < pos
    let [s, e] = [match(line, a:pat, s), matchend(line, a:pat, s)]
    if s < 0
      break
    elseif s < pos && pos <= e
      return line[s : e - 1]
    endif
    let s += 1
  endwhile
  return ''
endfunction

" /path/*/to/*  => splat: [first, second]
" /:feature/:user/:repos/#id
"
" :echo gitlab#parse_path("gitlab://Issue/hoge", "gitlab://:feauture/:param")
" regexp=gitlab://\([^/]*\)/\([^/]*\)
" ['gitlab://Issue/hoge', 'Issue', 'hoge', '', '', '', '', '', '', '']
" {'param': 'hoge', 'feauture': 'Issue'}
"
function! gitlab#parse_path(path, pattern)
  let placefolder_pattern = '\v%((::?|#)\w+|\*\*?)'
  let regexp = substitute(a:pattern, placefolder_pattern,
  \                       '\=s:convert_placefolder(submatch(0))', 'g')
  echo "regexp=" . regexp
  let matched = matchlist(a:path, '^' . regexp . '\m$')
  echo matched
  if empty(matched)
    return {}
  endif
  call remove(matched, 0)
  let ret = {}
  let splat = []
  for folder in s:scan_string(a:pattern, placefolder_pattern)
    let name = matchstr(folder, '\v^(::?|#)\zs\w+')
    if !empty(name)
      let ret[name] = remove(matched, 0)
    else
      call add(splat, remove(matched, 0))
    endif
  endfor
  if !empty(splat)
    let ret.splat = splat
  endif
  return ret
endfunction

function! s:convert_placefolder(placefolder)
  if a:placefolder ==# '**' || a:placefolder =~# '^::'
    let pat = '.*'
  elseif a:placefolder =~# '^#'
    let pat = '\d*'
  else
    let pat = '[^/]*'
  endif
  return '\(' . pat . '\)'
endfunction

function! s:scan_string(str, pattern)
  let list = []
  let pos = 0
  while 0 <= pos
    let matched = matchstr(a:str, a:pattern, pos)
    let pos = matchend(a:str, a:pattern, pos)
    if !empty(matched)
      call add(list, matched)
    endif
  endwhile
  return list
endfunction


" pseudo buffer. {{{1
function! gitlab#read(path)
echomsg "gitlab#read() path=" . a:path
  try
    let uri = gitlab#parse_path(a:path, 'gitlab://:user@:url/:feature/::param')
    if !exists('b:gitlab')
      if empty(uri)
        throw 'gitlab: Invalid path: ' . a:path
      endif
      if !has_key(s:features, uri.feature)
        throw 'gitlab: Specified feature is not registered: ' . uri.feature
      endif
echomsg "gitlab#read() call new"
      let b:gitlab = s:features[uri.feature].new('/' . uri.param)
    endif
    let &l:filetype = 'gitlab-' . uri.feature
    call b:gitlab.read()
  catch /^gitlab:/
    setlocal bufhidden=wipe
    echoerr v:exception
  endtry
endfunction

" Main commands.  {{{1
function! gitlab#invoke(argline)
  " The simplest implementation.
  try
    let [feat; args] = split(a:argline, '\s\+')
    if !has_key(s:features, feat)
      throw 'gitlab: Specified feature is not registered: ' . feat
    endif
    call s:features[feat].invoke(args)
  catch /^gitlab:/
    echohl ErrorMsg
    echomsg v:exception
    echohl None
  endtry
endfunction

function! gitlab#complete(lead, cmd, pos)
  let token = split(a:cmd, '\s\+', 1)
  let ntoken = len(token)
  if ntoken == 1
    return keys(s:features)
  elseif ntoken == 2
    return filter(keys(s:features), 'stridx(v:val, token[1]) == 0')
  elseif ntoken == 3
    return gitlab#{token[1]}#complete(a:lead, a:cmd, a:pos)
  else
    return []
  endif
endfunction

function! s:iconv(expr, from, to)
  if a:from ==# a:to || a:from == '' || a:to == ''
    return a:expr
  endif
  let result = iconv(a:expr, a:from, a:to)
  return result != '' ? result : a:expr
endfunction

function! s:system(args)
  let type = type(a:args)
  let args = type == type([]) ? a:args :
  \          type == type('') ? split(a:args) : []

  if g:gitlab#use_vimproc
    call gitlab#debug_log(args)
    return vimproc#system(args)
  endif

  if s:is_win
    let args[0] = s:cmdpath(args[0])
    let q = '"'
    let cmd = join(map(args,
    \   'q . substitute(escape(v:val, q), "[<>^|&]", "^\\0", "g") . q'),
    \   ' ')
  else
    let cmd = join(map(args, 'shellescape(v:val)'), ' ')
  endif
  call gitlab#debug_log(cmd)
  return system(cmd)
endfunction

function! s:cmdpath(cmd)
  " Search the fullpath of command for MS Windows.
  let full = glob(a:cmd)
  if a:cmd ==? full
    " Already fullpath.
    return a:cmd
  endif

  let extlist = split($PATHEXT, ';')
  if a:cmd =~? '\V\%(' . substitute($PATHEXT, ';', '\\|', 'g') . '\)\$'
    call insert(extlist, '', 0)
  endif
  for dir in split($PATH, ';')
    for ext in extlist
      let full = glob(dir . '\' . a:cmd . ext)
      if full != ''
        return full
      endif
    endfor
  endfor
  return ''
endfunction


" Debug.  {{{1
function! gitlab#debug_log(mes, ...)
  if !g:gitlab#debug
    return
  endif
  let mes = a:0 ? call('printf', [a:mes] + a:000) : a:mes
  if g:gitlab#debug_file == ''
    for m in split(mes, "\n")
      echomsg 'gitlab: ' . m
    endfor
  else
    let file = strftime(g:gitlab#debug_file)
    let dir = fnamemodify(file, ':h')
    if !isdirectory(dir)
      call mkdir(dir, 'p')
    endif
    execute 'redir >>' file
    silent! echo strftime('%c:') mes
    redir END
  endif
endfunction


" Options.  {{{1
if !exists('g:gitlab#debug')  " {{{2
  let g:gitlab#debug = 0
endif

if !exists('g:gitlab#debug_file')  " {{{2
  let g:gitlab#debug_file = ''
endif

" Register the default features. {{{1
function! s:register_defaults()
  let list = split(globpath(&runtimepath, 'autoload/gitlab/*.vim'), "\n")
  for name in map(list, 'fnamemodify(v:val, ":t:r")')
    try
      call gitlab#register(gitlab#{name}#new())
    catch /:E\%(117\|716\):/
    endtry
  endfor
endfunction

call s:register_defaults()


let &cpo = s:save_cpo
unlet s:save_cpo
