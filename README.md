# vim-gitlab

[![Build Status](https://travis-ci.org/syngan/vim-alarm.png?branch=master)](https://travis-ci.org/syngan/vim-alarm)

vim-gitlab is a vim client for GitLab

* c.f. https://github.com/thinca/vim-github
* c.f. http://d.hatena.ne.jp/thinca/20100701/1277994373


GitLab を vim から参照・変更するプラグインです.
- 現状 issues のみに対応
- GitLab は 6-1-stable 以下でも動作しますが Web ブラウザで表示した時の `issue #x` の数字と, gitlab.vim で表示される数値が一致しません.
(API が対応していないため)
    - c.f. https://github.com/gitlabhq/gitlabhq/commit/02693b72a4240a9d94246e590775a66eb48c55ed
    - https://github.com/gitlabhq/gitlabhq/tree/master/doc/api

> ## id vs iid
>
> When you work with API you may notice two similar fields in api entites: id and iid.
> The main difference between them is scope. Example:
>
> Issue
>   id: 46
>   iid: 5
>
>   * id - is uniq across all Issues table. It used for any api calls.
>   * iid - is uniq only in scope of single project. When you browse issues or merge requests with Web UI - you see iid.
>
>   So if you want to get issue with api you use `http://host/api/v3/.../issues/:id.json`
>   But when you want to create a link to web page - use  `http:://host/project/issues/:iid.json`

- thinca さんの vim-github を元にコピー＆修正で作成しています.

# Install

```vim
NeoBundleLazy 'syngan/vim-gitlab', {
    \ 'autoload' : {
    \ 'commands' : 'Gitlab'}}
```

- required
    - GitLab 6-2-stable
    - `+python` or `curl` or `wget` (`vital.vim` の `Web.HTTP` に依存)


# Config

以下のように変数 `g:gitlab_config` を定義します.
- `__name__` は任意に設定します.
- `url` はアクセスする GitLab の URL (必須)
    - e.g., https://hoge.com/apps/gitlab/
    - e.g., http://localhost:1192/
- `user`/`email` はログイン ID (必須)
- `password` はパスワード (任意)


```vim
g:gitlab_config['__name__'] = {
\    'url' : 'http://localhost/',
\    'user' : '',
\    'email' : 'admin@local.host',
\    'password' : 'optional',
\}
```
# Usage

下記のようにして, `g:gitlab_config` で定義した `__name__` にアクセスします.
`root/sandbox` はリポジトリ名.

```vim
:Gitlab __name__ issues root/sandbox
```

# Screenshot

## issues list
![Issues LIST](./img/issues_list.png)

## show issue #2
![Issues LIST](./img/issue2.png)

## add comment
![Issues LIST](./img/issue2c.png)

## show issues #2
![Issues LIST](./img/issue2c2.png)
