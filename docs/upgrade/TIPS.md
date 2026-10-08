# アップグレード作業のコツ

コマンドの実行や確認の手順で、これまでの Step でつまずいたこと・使えたやり方をまとめる。作業のルールは [CLAUDE.md](../../CLAUDE.md)、計画と進捗は [PLAN.md](PLAN.md)、Step ごとの記録は [LOG.md](LOG.md) を参照する。

## コマンドの実行

- Ruby は mise で管理している。各アプリのディレクトリで `mise exec -- <コマンド>` のように実行する。リポジトリ直下で `ruby` を実行すると、macOS 標準の Ruby 2.6 が使われる
- `ruby -r<gem>` は Bundler を通さないと lock の gem を読めない。`mise exec -- bundle exec ruby ...` で実行する
- spring は Step 0-f-1 で削除した。`DISABLE_SPRING` は不要
- シェルは zsh。変数に入れたコマンドや複数のパスは単語に分割されないので、`${=var}` で展開する。`git add` に渡すときは `git diff --name-only -z ... | xargs -0 git add --` のようにする
- Claude Code の Bash の作業ディレクトリは、呼び出しの間で変わっていることがある。ファイルを作る・書き換えるコマンドは、絶対パスで書くか、同じ呼び出しの中で `cd` してから実行する
- 一時ファイルはセッションの scratchpad に置き、`/tmp` は使わない（`/tmp` は `/private/tmp` へのシンボリックリンク）
- 日本語を含む `ruby -e` や `sed` には `LC_ALL=ja_JP.UTF-8` を付ける。日本語を含むファイルを Ruby で読み書きするときは `encoding: 'UTF-8'` を指定する

## 確認のコマンド

各アプリのディレクトリで実行する。

| 確認 | コマンド | 期待する結果 |
|---|---|---|
| RuboCop | `mise exec -- bundle exec rubocop` | `no offenses detected` |
| minitest | `mise exec -- bin/rails test` | 0 failures。RP の出力の `Authentication failure!` は想定どおり（ID トークンの検証失敗のテスト） |
| Zeitwerk | `mise exec -- bin/rails zeitwerk:check` | `All is good!` |
| 起動 | `mise exec -- bin/rails runner 'puts Rails.version'` | |
| bundler-audit | `mise exec -- bundle exec bundle-audit check` | `No vulnerabilities found`（無視リスト込み） |
| brakeman | `mise exec -- bundle exec brakeman --no-pager -q` | `Security Warnings: 0`、`Ignored Warnings: 2` |
| E2E | `e2e/` で `mise exec -- npm test` | 約 10 秒で 10 passed。手動確認用のサーバーが動いていると起動に失敗する |

## gem の更新

- `bundle update <gem> --conservative` で上げ、`git diff -U0 Gemfile.lock | grep -E '^[-+]    [a-z]'` で、変わった gem を毎回見る
- lock に入れた default gem（json・bigdecimal・logger・base64・cgi）と concurrent-ruby 1.1.9 が動いていないことを確かめる。理由と見直す時期は PLAN.md の 7 章・8 章
- default gem を置き換える依存が入るときは、一時固定する。Gemfile に `gem '<名前>', '<版>'` を足して `bundle update` → 行を消して `bundle lock --local` → `git diff` で Gemfile が戻り、lock に意図しない変化がないことを確かめる
- 一時固定が要るかは、epic の lock と Gemfile を scratchpad にコピーし、`BUNDLE_GEMFILE` をそのコピーに向けて `bundle lock --update <gem> --conservative` を実行すると分かる（gem は入れず、依存の解決だけを行う）
  - コピーの前後を `diff` で比べるときは、行頭の記号が `< ` / `> ` の 2 文字になるので、`grep -E '^[<>]     [a-z]'`（空白 5 つ）で gem の行を拾う。`git diff` 用の `^[-+]    [a-z]`（空白 4 つ）では何も拾えず、変化がないように見える
- advisory が今の版でも対象かは、`ignore: []` だけの YAML を作り、`bundle-audit check --config <ファイル>` に渡すと分かる
- gem の依存と Ruby の要件は、`https://rubygems.org/api/v2/rubygems/<gem>/versions/<版>.json` で確かめられる。`.gem` のサイズは `https://rubygems.org/downloads/<gem>-<版>.gem` への HEAD リクエストの `content-length`
- Gemfile に gem を足す・動かすときは Bundler/OrderedGems に気をつける。RuboCop はコメントを区切りとして扱い（`TreatCommentsAsGroupSeparators`）、自動修正はコメントと gem の対応を崩すことがある（LOG.md の Step 0-e「Gemfile」）
- 理由付きの `rubocop:disable` が残っている（RS `apples_controller.rb`、RP `introspections_controller.rb`・`my_op.rb`、OP の annotate の rake）。そのコードを書き換えたら、disable が要らなくなっていないか確かめる（`Lint/RedundantCopDisableDirective`）

## 手動確認用の環境

- 手動確認用のローカル環境（各アプリの development DB、`.env`、OP の署名鍵）は gitignore 対象。作業の前後で、次のファイルのハッシュが一致することを `shasum` で確かめる
  - `rails_open_id_provider/db/development.sqlite3`、`rails_relying_party_of_backend/db/development.sqlite3`、`rails_resource_server/db/development.sqlite3`
  - `rails_open_id_provider/jwtRS256.key`
  - `rails_relying_party_of_backend/.env`、`rails_resource_server/.env`
- RP のトップページを開くと、セッションの行が増えて development DB が変わる。OP の discovery と、トークンなしでの RS へのリクエストは DB を変えない
- `.claude/launch.json` の設定で、3 アプリをプレビューから起動できる。プレビューは起動時にトップページを開くので、RP は手動確認のとき以外はプレビューで起動しない
- development のアプリを `rails runner` から `Rack::MockRequest` で呼ぶときは、`HTTP_HOST` に `localhost:<ポート>` を渡す（ないと HostAuthorization に 403 で止められる）。手動確認用の DB を変えないよう、`DATABASE_URL=sqlite3:db/e2e.sqlite3` を付ける
- ユーザーの資格情報は `rails_open_id_provider/tmp/manual_check_user.txt` にある。値をチャットやドキュメントに出さない。ブラウザでのログインと同意は人間が行う
- ブラウザペインが画面に出ていないと、AI からは表示できない（`tabs_context` が「hidden」と返す）。手動確認を頼む前に、人間にペインを開いてもらう
- プレビューのサーバーの標準出力は `preview_logs` で読む。`search` は部分一致で、正規表現は使えない
- 手動確認でログインすると、RP と OP の development DB に行が増えてハッシュが変わる。手動確認の直前にハッシュが作業前と一致することを確かめ、前後の件数を読み取り専用の `sqlite3 -readonly` で数えて記録する（Step 0-f-2）。以降の基準は手動確認の後のハッシュ

## LOG.md の書き方

- 確かめたことだけを書く。推測や、前後を比べていない「変わらない」は書かない（Step 0-f-1 のコードレビュー）
- サブエージェントの調査の結果は、自分で確かめてから書く。確かめていないものは、確かめていないと書く
