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
- perl で日本語を含むパターンを置換するときは `perl -Mutf8 -CSD` にする。`-CSD` だけではスクリプトの中の日本語が UTF-8 として読まれず、置換が何も当たらないまま正常に終わる（Step 0-g）

## 確認のコマンド

各アプリのディレクトリで実行する。

| 確認 | コマンド | 期待する結果 |
|---|---|---|
| RuboCop | `mise exec -- bundle exec rubocop` | `no offenses detected` |
| minitest | `mise exec -- bin/rails test` | 0 failures。RP の出力の `Authentication failure!` は想定どおり（ID トークンの検証失敗のテスト） |
| minitest（CI と同じ eager load あり） | `CI=1 mise exec -- bin/rails test` | 上と同じ件数で 0 failures。Step 1（Rails 7.0 の雛形）から、test 環境は `ENV["CI"]` があると eager load する（DEF-7.0-08） |
| 応答のスナップショット（Step 1-b-2） | minitest に含まれる。作り直すときは `UPDATE_SNAPSHOTS=1 mise exec -- bin/rails test`（ファイルを指定して絞れる）の後に `git status --short -- test/snapshots` と `git diff -- test/snapshots`（新しいファイルは `git diff` に出ない） | 差分がない。差分が出たら下の「応答のスナップショット」 |
| Zeitwerk | `mise exec -- bin/rails zeitwerk:check` | `All is good!` |
| 起動 | `mise exec -- bin/rails runner 'puts Rails.version'` | |
| 起動の途中の読み込み | `ANTI_MANNER=1 RAILS_ENV=test mise exec -- bin/rails runner 1`。`CI=1` 付きと、development（`DATABASE_URL=sqlite3:db/e2e.sqlite3` を付けて手動確認用の DB に触らない）でも | `✅Congratulations!` で終了コード 0。検出できる範囲は下の「設定の値と応答の比較」 |
| bundler-audit | `mise exec -- bundle exec bundle-audit check` | `No vulnerabilities found`（無視リスト込み） |
| brakeman | `mise exec -- bundle exec brakeman --no-pager -q` | `Security Warnings: 0`、`Ignored Warnings: 2` |
| E2E | `e2e/` で `mise exec -- npm test` | 約 10 秒で 10 passed。手動確認用のサーバーが動いていると起動に失敗する |

CI（`.github/workflows/ci.yml`）も同じコマンドを流す（起動の途中の読み込みは test と development の両方）。違いは、OP の署名鍵をジョブの中で作ること、bundler-audit に `--update` を付けて advisory のデータベースの最新を使うこと、E2E を mise なしで流すこと。

## CI の結果を読む

- push と PR の作成は人間が行う。AI は `gh` で結果を読む
- 実行の一覧: `gh run list --branch <ブランチ> --workflow CI`
- ジョブとステップの結果: `gh run view <run-id>`。失敗したステップのログだけを見るときは `gh run view <run-id> --log-failed`
- bundler-audit だけが落ちたときは、CI が取った advisory のデータベースに新しい advisory が入った可能性が高い（CI は `--update` を付けて最新を使う。手元は `bundle-audit update` を流すまで古いまま）。CLAUDE.md の「脆弱性が公表されている gem の修正だけは即時に行ってよい」に従い、上げるか、無視リストに入れるかを人間に確かめる。変更と関係のない PR でも落ちる
- E2E が失敗したときは、artifact `e2e-failure` にレポート・トレースと 3 アプリのログがある（`gh run download <run-id> -n e2e-failure -D <scratchpad のディレクトリ>`）。中のトークンは CI の使い捨てのものだが、LOG.md に貼るときは公開物の記載ルールに従う
- 手元で mise なしの経路（CI と同じ）を試すときは、`env -i HOME="$HOME" LANG=ja_JP.UTF-8 PATH="$(mise where ruby@3.1.7)/bin:$(mise where node@24.21.0)/bin:/usr/bin:/bin"` の下で `npm test` を流す（Step 0-g）

## gem の更新

- `bundle update <gem> --conservative` で上げ、`git diff -U0 Gemfile.lock | grep -E '^[-+]    [a-z]'` で、変わった gem を毎回見る
- lock に入れた default gem（json・bigdecimal・logger・base64・cgi）と concurrent-ruby 1.1.9 が動いていないことを確かめる。理由と見直す時期は PLAN.md の 7 章・8 章
- default gem を置き換える依存が入るときは、一時固定する。Gemfile に `gem '<名前>', '<版>'` を足して `bundle update` → 行を消して `bundle lock --local` → `git diff` で Gemfile が戻り、lock に意図しない変化がないことを確かめる
- 一時固定が要るかは、epic の lock と Gemfile を scratchpad にコピーし、`BUNDLE_GEMFILE` をそのコピーに向けて `bundle lock --update <gem> --conservative` を実行すると分かる（gem は入れず、依存の解決だけを行う）
  - コピーの前後を `diff` で比べるときは、行頭の記号が `< ` / `> ` の 2 文字になるので、`grep -E '^[<>]     [a-z]'`（空白 5 つ）で gem の行を拾う。`git diff` 用の `^[-+]    [a-z]`（空白 4 つ）では何も拾えず、変化がないように見える
- lock にない gem を足すときは `bundle lock --update <gem>` が使えない（`Could not find gem`）。Gemfile に足して `bundle lock`（入れるときは `bundle install`）を実行する。版の制約がないと最新のメジャー版が入るので、一時固定する（Step 0-f-3 の jwt）
- advisory が今の版でも対象かは、`ignore: []` だけの YAML を作り、`bundle-audit check --config <ファイル>` に渡すと分かる
- Rails のマイナーを上げるときは、Gemfile の rails を変えて `bundle lock` するだけで、`--conservative` を付けても周辺の gem（jwt・devise・doorkeeper-openid_connect など）まで動く。lock のコピーで、旧 lock の gem をすべて Gemfile に `= 版` で固定し、Rails の構成 gem だけを外して解決させると、どうしても動く gem が分かる（Step 1。解決できない gem は Bundler のエラーに名前が出るので、その gem だけ固定を外して繰り返す）。その lock をアプリに持ち込み、Gemfile を戻して `bundle lock` すれば、過去の一時固定と同じ結果になる
- gem の依存と Ruby の要件は、`https://rubygems.org/api/v2/rubygems/<gem>/versions/<版>.json` で確かめられる。`.gem` のサイズは `https://rubygems.org/downloads/<gem>-<版>.gem` への HEAD リクエストの `content-length`
- Gemfile に gem を足す・動かすときは Bundler/OrderedGems に気をつける。RuboCop はコメントを区切りとして扱い（`TreatCommentsAsGroupSeparators`）、自動修正はコメントと gem の対応を崩すことがある（LOG.md の Step 0-e「Gemfile」）
- 理由付きの `rubocop:disable` が残っている（RS `apples_controller.rb`、RP `introspections_controller.rb`・`my_op.rb`、OP の annotate の rake）。そのコードを書き換えたら、disable が要らなくなっていないか確かめる（`Lint/RedundantCopDisableDirective`）

## 設定の値と応答の比較（Rails を上げる Step）

- `new_framework_defaults_*.rb` の設定は、有効にする前後で `rails runner` から実際の値を書き出して比べる。設定ファイルの値ではなく、クラスに入った値（`ActiveRecord::Base.partial_inserts` など）を読む。`on_load` の中で値が入る設定があるので、読む前に `ActionView::Base`・`ActionController::Base`・`ActionDispatch::Request`・`ActiveRecord::Base` などを読み込んでおく。test と development の両方で比べる（development だけで使う gem が、起動の途中にクラスを読み込むことがある。Step 1 の web-console）
- 非推奨のメソッドの値を読むと、test 環境の `deprecation = :raise` で例外になる。`ActiveSupport::Deprecation.silence { ... }` で包む
- 起動の途中に読み込まれた部品は、`require "./config/application"` の後と、`Rails.application.initializer("probe", before: :load_config_initializers) { ... }` を足して `Rails.application.initialize!` した後に、`ActiveSupport.instance_variable_get(:@loaded)` で値のある名前を見ると分かる。誰が読み込んだかは、`ActiveSupport.on_load(:active_record) { puts caller }` を先に仕込むと分かる（Step 1）
- 起動の途中の読み込みは、Step 1-b-1 から a-nti_manner_kick_course で検出する（上の「確認のコマンド」。CI でも流す）。見つけると `on_load(:active_record)` などの名前と疑わしい行を出して終了コード 1 で止まる。疑わしい行が gem の中を指すときは、`ANTI_MANNER_DEBUG=1` でスタックトレース全部を出し、アプリの行を探す（Step 1 の RP の serializer の設定は `activerecord-session_store-2.1.0/lib/active_record/session_store/session.rb` を指し、全部を出すと `config/application.rb` の行が出た）
  - 検出できるのは、`config/application.rb`、`Bundler.require` で gem を require するとき、`config/environments/*.rb`、Rails 自身の initializer まで。gem の検査は Rails の各フレームワークの initializer の直後で終わるので、ほかの gem の initializer（web-console など）と `config/initializers/*.rb` は検出できない。監視の一覧に `action_dispatch_request` もない。これらで設定が効かなくなっていないかは、上の値の比較（有効にする前後で、test と development の値を書き出す）で確かめる。上の `@loaded` の確かめ方は `config/initializers` を読む直前の時点を見るので、`config/initializers` の中での読み込みは見えない。どこで読み込まれたかは `on_load { puts caller }` で探す
  - `ANTI_MANNER` を付けたまま、ほかのコマンド（`bin/rails test` など）を流さない。gem が起動の途中で終了コード 0 で終えるので、何も検査せずに成功したように見える
- 応答の前後比較は、Step 1-b-2 から各アプリの minitest の応答のスナップショット（下の「応答のスナップショット」）で行う。使い捨ての統合テストは要らない。test 環境では出ない development だけのヘッダー（`Server-Timing`、rack-mini-profiler・web-console のもの）と CSRF のトークンは、Rails を上げる Step で development のアプリの応答を `curl` で見る（Step 1 と同じ）

## 応答のスナップショット（Step 1-b-2）

- 各アプリの `test/integration/response_snapshot*_test.rb` が、応答のステータス・ヘッダー・本文を `test/snapshots/responses/<名前>.txt` と比べる。伏せる処理は `test/support/response_snapshot_helper.rb`（3 アプリで同じ内容。直したら 3 つとも同じにする。CI の `rails` ジョブが、ほかのアプリのものと `diff` で比べる）
- 伏せるのは、実行ごとに変わる値だけ。ヘッダーの `X-Request-Id`・`X-Runtime`、本文から決まる `ETag`・`Content-Length`（値だけ。ヘッダーがあるかどうかは比べる）、Cookie の値、クエリと hidden field の `code`・`state`・`nonce`・`code_challenge`、JSON の `access_token`・`refresh_token`・`id_token` と JWKS の `n`・`kid`。名前で決め、文字列の形では伏せない。OP のトークン系のテストは `travel_to` で時刻を固定し、`created_at`・`iat`・`exp` も比べる
- 知らない値が毎回変わるようになると、伏せずに落ちる。そのときは伏せる名前を足す前に、その値が本当に毎回変わるもの（トークンなど）かを確かめる。伏せる名前を足すと、その値の変化は見えなくなる
- 落ちたら、まず差分を読み、変化の理由（Rails・gem の版、設定）を確かめる。PLAN.md の 3 章の 2 の A なら、項目ごとに解説して人間の返事をもらってから `UPDATE_SNAPSHOTS=1 mise exec -- bin/rails test` で作り直し、変化を起こしたコミットにスナップショットも入れる。B なら作り直さずに止まって確かめる
- ファイルがないときは失敗する（`UPDATE_SNAPSHOTS` を付けたときだけ作る。CI では作らない）。テストを消したり名前を変えたりしたときは、使われなくなったファイルを手で消す
- スナップショットは公開物。作り直したら `scripts/check-public-safety --files <ファイル>` を流し、トークンや JWT の形の値（`grep -E 'eyJ|[A-Za-z0-9_-]{32,}'`）が残っていないことを見る

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

## コミット

- `git rm` で消したファイルはステージされたままになる。ほかのファイルをパスで `git add` してコミットしても、ステージ済みの削除が一緒に入る（Step 1 で docs のコミットに入ってしまい、push 前に作り直した）。ファイルを消すときは、作業ツリーで消して、コミットするときにパスでステージする
- アプリごとにコミットするときは、ほかのアプリの変更を `git stash push -u -- <ディレクトリ>` で退避し、そのアプリの変更だけで minitest と E2E を流してからコミットする
