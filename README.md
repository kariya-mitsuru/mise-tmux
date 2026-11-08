# mise-tmux

tmux を [tmux/tmux](https://github.com/tmux/tmux) のリリース tarball からビルドする mise の tool plugin（vfox 形式の Lua）です。
既定では libevent もダウンロードして一緒にビルドし、インストール先に同梱します（rpath でリンク）。

## インストール

```sh
mise plugins install tmux https://github.com/kariya-mitsuru/mise-tmux
# 開発中はローカルにリンク
mise plugins link tmux ./mise-tmux
```

config に書いておけば `mise install` / `mise bootstrap` で自動的に入ります。

```toml
[plugins]
tmux = "https://github.com/kariya-mitsuru/mise-tmux"
```

## 使い方

```toml
[tools]
tmux = "latest"

# オプションを指定する場合
tmux = { version = "3.8", libevent_version = "system", configure_options = "--enable-utf8proc" }
```

リリース以外のブランチ・タグ・コミットは `ref:` を付けて指定できます（GitHub のソースアーカイブから `autogen.sh` を実行してビルド）。

```sh
mise install tmux@ref:master
mise install tmux@ref:<commit sha>
```

この場合は `autoconf`、`automake`、`bison` も必要です（optional として宣言）。
`ref:master` は1つのバージョンとして扱われ、master が進んでも自動では更新されません。最新にするには `mise install -f tmux@ref:master` で入れ直してください。

| オプション | 既定値 | 内容 | asdf 版での対応 |
| --- | --- | --- | --- |
| `configure_options` | `--disable-utf8proc` | tmux の configure 引数（指定すると既定値は置き換わる） | `TMUX_EXTRA_CONFIGURE_OPTIONS` |
| `libevent_version` | `2.1.12` | 同梱する libevent のバージョン。`system` にするとシステムの libevent を使う | なし（2.1.12 固定） |
| `libevent_configure_options` | `--disable-openssl` | libevent の configure 引数 | `LIBEVENT_EXTRA_CONFIGURE_OPTIONS` |
| `jobs` | `nproc` | `make -j` の並列数 | `ASDF_CONCURRENCY` |

既定値は mise-plugins/mise-tmux（asdf）と同じです。

## 依存パッケージ

C コンパイラ（`cc`）、`make`、`tar`、`pkg-config`、ncurses の開発パッケージ（pkg-config の `ncursesw`）が必要です。
これらは `metadata.lua` の `systemDependencies` に宣言してあり、インストール前に mise が確認します。
`libevent_version = "system"` の場合は libevent の開発パッケージも必要です（optional として宣言）。

## リリース日（minimum_release_age）

mise の `minimum_release_age`（既定 24h）のため、GitHub の tags Atom フィードから直近のタグのリリース日を取得しています。
取得範囲は既定で直近30日分（tmux はリリースが少ないので通常は1ページで済みます）で、`MISE_TMUX_DATE_WINDOW_DAYS` で変更できます。
