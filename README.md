# vim-gitlab

vim-gitlab is a vim client for GitLab

* c.f. https://github.com/thinca/vim-github
* c.f. http://d.hatena.ne.jp/thinca/20100701/1277994373


GitLab (の issues) を vim から参照・変更するプラグインです.

- gitlab は 6-1-stable 以下でも動作しますが issue #x の数字と表示される数値が一致しません.
(API が対応していないため)



# Install

- required 
-- gitlab 6-2-stable
-- +python or curl or wget

# config


```vim
g:gitlab_config['__name__'] = {
\	'url' : 'http://localhost/',
\	'user' : '',
\	'email' : 'admin@local.host',
\	'password' : 'optional',
\}
```

```vim
:Gitlab __name__ issues root/sandbox
```
