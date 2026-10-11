# Rails 7.1 の既定値への追随

- 版: Rails 7.0.10 → 7.1.6（Ruby 3.2.11）
- Step: 3（ブランチ `upgrade/step3-rails71`）/ PR: （PR 作成後に記入）
- 記録のルールは [README.md](README.md)

## 一覧

| ID | 項目 | 種類 | 対象 | 扱い |
|---|---|---|---|---|
| DEF-7.1-01 | puma が応答ヘッダー名を小文字で返す | 周辺 gem の既定値（puma 8.0.2） | 3 アプリ | 追随 |
| DEF-7.1-02 | puma の keep-alive の既定値が変わる | 周辺 gem の既定値（puma 8.0.2） | 3 アプリ | 追随 |
| DEF-7.1-03 | puma の既定の bind のアドレスが IPv6 になる | 周辺 gem の既定値（puma 8.0.2） | 3 アプリ | 追随（実際の bind は変わらない） |
| DEF-7.1-04 | リダイレクトの応答が本文を返さない | Rails の既定値 | RP・OP | 追随 |
| DEF-7.1-05 | ルーティングの `redirect` の Content-Type に charset が付く | Rails の既定値 | RP | 追随 |
| DEF-7.1-06 | activerecord-session_store 2.3.0 の変化（SameSite の既定ほか） | 周辺 gem の既定値（activerecord-session_store 2.3.0） | RP | 追随 |
| DEF-7.1-07 | puma を通した応答に Content-Length が付く | Rails の既定値 | 3 アプリ | 追随 |
| DEF-7.1-08 | development の Server-Timing に `transaction.active_record` が増える | Rails の既定値 | 3 アプリ（development） | 追随 |
| DEF-7.1-09 | rack-mini-profiler の高度なデバッグ機能が、development で既定で無効になる | 周辺 gem の既定値（rack-mini-profiler 5.0.0） | RP・OP | 追随 |
| DEF-7.1-10 | `config.autoload_lib(ignore: %w(assets tasks))` | `app:update` の雛形 | RS・OP（RP は採用しない） | 追随 |
| DEF-7.1-11 | `cache_classes` が `enable_reloading` になる | `app:update` の雛形 | 3 アプリ | 追随 |
| DEF-7.1-12 | development・test で `raise_on_missing_callback_actions = true` | `app:update` の雛形 | 3 アプリ | 追随 |
| DEF-7.1-13 | test の `show_exceptions` が `:rescuable` になる | `app:update` の雛形 | 3 アプリ | 追随 |
| DEF-7.1-14 | development で `active_job.verbose_enqueue_logs = true` | `app:update` の雛形 | 3 アプリ | 追随 |
| DEF-7.1-15 | production.rb の雛形 | `app:update` の雛形 | 3 アプリ | 追随 |
| DEF-7.1-16 | コメントと書き方だけの変化 | `app:update` の雛形 | 3 アプリ | 追随 |
| DEF-7.1-17 | `bin/setup` の `system!` が例外で止まる | `app:update` の雛形 | 3 アプリ | 追随 |
| DEF-7.1-18 | `active_storage:update` のマイグレーション | `app:update` の雛形 | 3 アプリ | 採用しない |

## 周辺 gem（Step 3）

Step 3 で、Rails 7.1 にする前と直後に上げる周辺 gem で起きた、gem の既定値・雛形の変化。上げた版と順番は [PLAN.md](../PLAN.md) の Step 3。

### DEF-7.1-01: puma が応答ヘッダー名を小文字で返す

- 種類: 周辺 gem の既定値（puma 6.6.1 → 8.0.2）/ 対象: RS・RP・OP（puma で動かす development。E2E と手動確認で使う）
- 何が変わるか: puma が返す応答のヘッダー名が、すべて小文字になる（`X-Frame-Options: SAMEORIGIN` → `x-frame-options: SAMEORIGIN`、`Content-Type` → `content-type` など）。値と順番は同じ。test 環境のアプリを puma に直接通し、RS の `/apples/show`（401）と OP の discovery（200）の生の応答を前後で比べて確かめた
- なぜ: puma 7.0.0 の破壊的な変更（puma#3704。元は #3305、報告は #3250）。それまで puma は `Content-Length` などの一部のヘッダーの名前の書き方を自分で決めていて、ヘッダーを小文字で持つ Rack 3 のアプリでは、アプリが返した形と食い違った。常に小文字にそろえた
- 3 アプリへの影響: HTTP のヘッダー名は大文字と小文字を区別しない（RFC 9110 の 5.1）。RP・RS は OP・RS の応答を faraday で読み、`Faraday::Utils::Headers` は名前を小文字にそろえて引く（`faraday-2.14.4/lib/faraday/utils/headers.rb:52`）。アプリのコードは応答のヘッダーを読まない（RS が読む `Authorization` はリクエストのヘッダー）。minitest の応答のスナップショットは puma を通らないので同じ。E2E は通った
- 扱い: 追随
- 出典: puma の History.md の 7.0.0（Breaking changes）、puma#3305・#3250。Rails の外の gem なので、Rails ガイドに該当の節はない
- コミット: RS・RP・OP（`update puma to 8.0.2`）

### DEF-7.1-02: puma の keep-alive の既定値が変わる

- 種類: 周辺 gem の既定値（puma 6.6.1 → 8.0.2）/ 対象: RS・RP・OP（development）
- 何が変わるか: `config/puma.rb` を読み込んだ後の値で、`persistent_timeout`（接続を開けておく秒数）が 20 → 65、`max_keep_alive`（1 つの接続で受ける要求の上限）が nil → 999。ほかの値（threads・workers・`worker_timeout` など）は同じ（6.6.1 と 8.0.2 で書き出して比べた）
- なぜ: puma 7.0.0 で、ロードバランサーのアイドルのタイムアウト（AWS ALB の既定は 60 秒）より短いと、閉じかけの接続に要求が来て 502 になることがあるので 65 秒にした（#3378）。7.0 で入った keep-alive の扱いの上限を、nginx の既定（1000）にならって 999 にした（#3719）
- 3 アプリへの影響: 同じ接続を使い回す時間と回数だけが変わり、応答の中身は変わらない。`config/puma.rb` はどちらも設定していない。production は動作保証の外
- 扱い: 追随（`config/puma.rb` に古い値を書かない）
- 出典: puma の History.md の 7.0.0、puma#3378・#3719
- コミット: RS・RP・OP（`update puma to 8.0.2`）

### DEF-7.1-03: puma の既定の bind のアドレスが IPv6 になる

- 種類: 周辺 gem の既定値（puma 6.6.1 → 8.0.2）/ 対象: RS・RP・OP
- 何が変わるか: puma の設定だけで見ると、bind が `tcp://0.0.0.0:<ポート>` → `tcp://[::]:<ポート>`（IPv6 のインターフェースがあるとき）
- なぜ: puma 8.0.0 の破壊的な変更（puma#3847）
- 3 アプリへの影響: ない。`bin/rails s` は development で host に `localhost` を渡し（`railties-7.0.10/lib/rails/commands/server/server_command.rb:219`）、Rack handler は host があると bind を消して作り直す（`puma-8.0.2/lib/rack/handler/puma.rb:96`）ので、puma の既定の bind は使われない。`.claude/launch.json` も E2E の `e2e/scripts/start-server.sh` も `bin/rails s` で起動する
- 扱い: 追随（何もしない）
- 出典: puma の History.md の 8.0.0、上の 2 つのソースの行
- コミット: RS・RP・OP（`update puma to 8.0.2`）

## Rails 7.1.6 にしたときの変化（`load_defaults` によらないもの）

Gemfile の rails を `~> 7.1.6` にしただけで（`load_defaults 7.0` のまま）、応答のスナップショットに出た変化。

### DEF-7.1-04: リダイレクトの応答が本文を返さない

- 種類: Rails の既定値 / 対象: RP・OP（RS はリダイレクトしない）
- 何が変わるか: 301・302 の応答の本文 `<html><body>You are being <a href="...">redirected</a>.</body></html>` が空になる。ステータス・`Location`・ほかのヘッダーは同じ。コントローラーの `redirect_to`（OP 11 件: devise のログイン・ログアウト・登録・編集、doorkeeper の認可エンドポイントから RP のコールバックへ。RP 3 件: ログイン・ログアウト・introspection のコールバック）と、ルーティングの `redirect`（RP の `/auth/failure`）の両方
- なぜ: 今のブラウザはこの HTML を表示せず、送る分だけ無駄になる。HTML は W3C の検証でエラーになり（doctype・title がない）、サイト全体の適合性の検査で誤った指摘の原因になる（rails/rails#44554、7.1.0）
- 3 アプリへの影響: ブラウザも faraday も `Location` を見て進むので、画面の遷移・リダイレクト先・アプリ間のやり取りは変わらない。本文を読むコードはない。E2E（ログイン、OP の認可からの戻り、introspection の流れ）は Rails 7.1.6 で通った。応答のスナップショットを作り直した
- 扱い: 追随
- 出典: rails/rails#44554、`actionpack-7.1.6/CHANGELOG.md`（「Make `redirect_to` return an empty response body.」）、`actionpack-7.1.6/lib/action_dispatch/routing/redirection.rb`。Rails ガイド v7.1 の「Rails 7.1 リリースノート」と「Rails アップグレードガイド」に該当の節はない
- コミット: RP・OP（`update rails to 7.1.6`）

### DEF-7.1-05: ルーティングの `redirect` の Content-Type に charset が付く

- 種類: Rails の既定値 / 対象: RP（`config/routes.rb` の `/auth/failure` の `redirect('/')` だけ）
- 何が変わるか: `content-type: text/html` → `text/html; charset=UTF-8`
- なぜ: ペネトレーションテストで charset のない応答を指摘され、OWASP ASVS の 14.4.1（text/* の応答には安全な文字コードを書く）に合わせた（rails/rails#47758、7.1.0。CHANGELOG にはない）
- 3 アプリへの影響: 本文は空で、ブラウザは `Location` へ進むだけなので、表示は変わらない。コントローラーの `redirect_to` の Content-Type は前からこの形
- 扱い: 追随
- 出典: rails/rails#47758、`actionpack-7.1.6/lib/action_dispatch/routing/redirection.rb`。Rails ガイドに該当の節はない
- コミット: RP（`update rails to 7.1.6`）

### DEF-7.1-07: puma を通した応答に Content-Length が付く

- 種類: Rails の既定値 / 対象: RS・RP・OP（puma で動かすすべての環境）
- 何が変わるか: 本文の長さが前もって分からなかった応答が、`transfer-encoding: chunked` から `content-length: <長さ>` で返るようになる。RS の `/apples/show`（401）が `content-length: 1`（本文は前と同じ空白 1 文字）になった。ほかに比べた応答（RP のトップ、OP の discovery とログイン画面）は、前から Content-Length が付いていた
- なぜ: Rack 3 の仕様に合わせて、Rails の応答の本文（`ActionDispatch::Response::RackBody`）が `to_ary` を持つようになった（rails/rails#47092）。puma は、本文が `to_ary` に応じると長さを計って Content-Length を付ける
- 3 アプリへの影響: 同じ本文を、長さを先に示して送るだけ。RS の 401 を読む RP（faraday）とブラウザは、どちらの形も扱える。minitest の応答のスナップショットは puma を通らないので変わらない。development のアプリを `Puma::Server` に直接通し、Rails 7.0.10 と 7.1.6（どちらも puma 8.0.2）で比べた
- 扱い: 追随
- 出典: rails/rails#47092、`actionpack-7.1.6/lib/action_dispatch/http/response.rb`（`RackBody#to_ary`）、`puma-8.0.2/lib/puma/response.rb`。Rails ガイドに該当の節はない
- コミット: RS・RP・OP（`update rails to 7.1.6`）。比べたのはコミットの後で、解説への返事もコミットの後にもらった

### DEF-7.1-08: development の Server-Timing に `transaction.active_record` が増える

- 種類: Rails の既定値 / 対象: DB に書く要求（比べた中では RP のトップ。セッションの行を作る）。development だけ（`config.server_timing = true`）
- 何が変わるか: `server-timing` に `transaction.active_record;dur=...` が 1 つ増える
- なぜ: Active Record 7.1 で、トランザクションの通知 `transaction.active_record` が増えた。Server-Timing は通知を集めて出すので、自動で増える
- 3 アプリへの影響: development の計測のヘッダーだけで、業務的な挙動ではない
- 扱い: 追随
- 出典: `activerecord-7.1.6/CHANGELOG.md`（`transaction.active_record` の通知の項）。Rails ガイドに該当の節はない
- コミット: RS・RP・OP（`update rails to 7.1.6`）。比べたのはコミットの後で、解説への返事もコミットの後にもらった

### DEF-7.1-06: activerecord-session_store 2.3.0 の変化

- 種類: 周辺 gem の既定値（activerecord-session_store 2.2.0 → 2.3.0。Rails 7.1.6 と同じコミットで上げた）/ 対象: RP
- 何が変わるか（入れた 2.2.0 と 2.3.0 の `lib` の差分。generator の雛形は同じ）
  - セッション Cookie の `same_site` の既定を `request.cookies_same_site_protection` から取る。Rails 7.1 は、Cookie に `same_site: nil` があると SameSite を付けなくなり（actionpack 7.1 の CHANGELOG「Allow opting out of the `SameSite` cookie attribute」）、2.2.0 では rack 2.2 の `Rack::Session::Abstract::Persisted` が `same_site: nil` を入れるので、SameSite が消えていた。2.3.0 で 7.0 と同じ `SameSite=Lax` になる
  - セッションのデータが変わっておらず新しくもないときは、DB に書かない。同じ要求の中で読んだセッションの行を使い回す
  - 公開のセッション ID の文字コードが壊れていたら使わない。`secure_session_only` のオプションが増えた（既定は false で、今と同じ）
  - `session_id` 以外の列名を使うと非推奨の警告を出す（RP は `session_id` の列）。deprecator を `app.deprecators` に登録する
- なぜ: 2.3.0 で Rails 7.0 のサポートをやめ、Rails の CookieStore に合わせて SameSite の既定を入れた（コミット 121f9ff7。rails/rails#45501）
- 3 アプリへの影響: Set-Cookie は Rails 7.0 のときと同じ。データが変わらないときは、2.2.0 でも Active Record が変更なしとして UPDATE を出さなかった見込みで、DB に入るデータは変わらない。RP の sessions のテストは通った
- 扱い: 追随。Rails 7.1.6 の直後の予定だったが、Rails 7.1.6 だけでは SameSite が消えるので、同じコミットで上げた（人間が判断。CLAUDE.md の「gem が新しい Rails に未対応のとき」の ①）
- 出典: activerecord-session_store の GitHub の v2.3.0 のリリース、コミット 121f9ff7、`activerecord-session_store-2.3.0/lib/action_dispatch/session/active_record_store.rb`、`activerecord-session_store-2.3.0/lib/active_record/session_store/session.rb`、`actionpack-7.1.6/lib/action_dispatch/middleware/cookies.rb`、`rack-2.2.24/lib/rack/session/abstract/id.rb`。Rails ガイドに該当の節はない
- コミット: RP（`update rails to 7.1.6`）

### DEF-7.1-09: rack-mini-profiler の高度なデバッグ機能が、development で既定で無効になる

- 種類: 周辺 gem の既定値（rack-mini-profiler 4.0.1 → 5.0.0）/ 対象: RP・OP（development だけ）
- 何が変わるか: `Rack::MiniProfiler.config.enable_advanced_debugging_tools` が、development で true → false になる。4.0.1 の railtie は `c.enable_advanced_debugging_tools = Rails.env.development?` で有効にしていて、5.0.0 でこの行がなくなった（5.0.0 で `bin/rails runner` から読むと false）。使えなくなるのは、環境変数やメモリーの中身を画面に出す機能（`?pp=env`、`?pp=analyze-memory` など）。バッジ、基本の機能、`x-miniprofiler-*` のヘッダー、`__profilin` の Cookie は変わらない。5.0.0 の railtie が使う `Rails.env.local?` は Rails 7.1 から使え、development で true なので、`authorization_mode` は `:allow_all` のまま
- なぜ: development でも、外から届くアドレスで起動したり（`-b 0.0.0.0`）、トンネルで公開したりすると、環境変数やメモリーの中身が他人に見える。README は既定で無効と書いていたのに、railtie が development で有効にしていた食い違いを、安全な側に直した（rack-mini-profiler#645）
- 3 アプリへの影響: 開発用の道具の機能が減るだけで、業務的な挙動ではない。RP の `.env` には OP のクライアントの secret があり、OP には署名鍵があるので、無効のほうが安全。3 アプリとも rack-mini-profiler の initializer を持たず、generator の雛形は 4.0.1 と同じ。development のアプリを `Puma::Server` に通して、前後で応答ヘッダーとバッジの `<script>` の属性が同じことを確かめた
- 扱い: 追随（有効にする設定は足さない）
- 出典: rack-mini-profiler#645、`rack-mini-profiler-5.0.0/CHANGELOG.md`、v4.0.1 と v5.0.0 の `lib/mini_profiler_rails/railtie.rb`、`rack-mini-profiler-5.0.0/lib/mini_profiler/config.rb`。README の設定の表は「Defaults to `true` in development.」のまま残っていて、コードと合っていない。Rails の外の gem なので、Rails ガイドに該当の節はない
- コミット: RP・OP（`update rack-mini-profiler to 5.0.0`）

## `app:update` の雛形

`bin/rails app:update`（Rails 7.1.6）を 3 アプリで全上書きで流し、`scripts/restore-app-config` でアプリの独自設定（test の `deprecation = :raise`、`filter_parameter_logging.rb` のコメントと `:code`）を戻した後の差分。差分は人間が確かめた。設定の値の比較（3 アプリの test・development）で変わったのは、DEF-7.1-12〜14 の値だけ。`app:update` が一度作って同じ実行の中で消したファイル（`assets.rb` など）は、前後ともないので差分にならない。

### DEF-7.1-10: `config/application.rb` に `config.autoload_lib(ignore: %w(assets tasks))`

- 種類: `app:update` の雛形 / 対象: RS・OP（採用）、RP（採用しない）
- 何が変わるか: `lib` が autoload・eager load の対象になる（`assets`・`tasks` を除く）。RS の `lib` は `tasks/.keep` だけ、OP の `lib` は `assets/.keep` と `tasks/`（annotate の rake）だけで、読み込まれる Ruby のファイルはない。test で `Rails.autoloaders.main.dirs` に `lib` が入り、`lib/tasks`（OP は `lib/assets` も）が無視されることを確かめた
- なぜ: Rails 7.1 の新しいアプリは `lib` を autoload する（rails/rails#49032）
- 3 アプリへの影響: RS・OP は読み込むファイルがなく、`zeitwerk:check` は通った。RP は採用すると `lib/omniauth/strategies/my_op.rb` が `Omniauth::Strategies::MyOp` として読まれ、`zeitwerk:check` と eager load のテストが `NameError: uninitialized constant Omniauth::Strategies::MyOp` で落ちる。RP は、次のコミットで `autoload_lib_once` と inflector にする（PLAN.md の Step 3 の案 B）
- 扱い: RS・OP は追随。RP は採用しない（`autoload_lib_once` に置き換える）
- 出典: rails/rails#49032、`railties-7.1.6/CHANGELOG.md`、Rails ガイド v7.1 の「Rails アップグレードガイド」の 2.3「config.autoload_libとconfig.autoload_lib_onceについて」
- コミット: RS・OP（`apply rails app:update for Rails 7.1`）

### DEF-7.1-11: `config.cache_classes` が `config.enable_reloading` になる

- 種類: `app:update` の雛形 / 対象: 3 アプリ（development・test・production）
- 何が変わるか: `cache_classes = false/true` が `enable_reloading = true/false` になる。`enable_reloading` は `!cache_classes` を表す同じ設定で、値は変わらない
- なぜ: リロードするかどうかをそのまま表す名前にした（rails/rails#44870）
- 3 アプリへの影響: ない
- 扱い: 追随
- 出典: rails/rails#44870、`railties-7.1.6/CHANGELOG.md`（「Define `config.enable_reloading` to be `!config.cache_classes`」）
- コミット: RS・RP・OP（`apply rails app:update for Rails 7.1`）

### DEF-7.1-12: development・test で `raise_on_missing_callback_actions = true`

- 種類: `app:update` の雛形 / 対象: 3 アプリ（development・test）
- 何が変わるか: `before_action` などの `only:`・`except:` が、ないアクションを指すとエラーになる
- なぜ: 名前の打ち間違いでコールバックが黙って効かないことを防ぐ（rails/rails#43487）
- 3 アプリへの影響: 3 アプリのコントローラーに `only:`・`except:` はない。devise・doorkeeper のコントローラーを含め、minitest と E2E は通った
- 扱い: 追随
- 出典: rails/rails#43487、`actionpack-7.1.6/CHANGELOG.md`（「Allow raising an error when a callback's only/unless symbols aren't existing methods.」）
- コミット: RS・RP・OP（`apply rails app:update for Rails 7.1`）

### DEF-7.1-13: test の `show_exceptions` が `false` から `:rescuable` になる

- 種類: `app:update` の雛形 / 対象: 3 アプリ（test）
- 何が変わるか: テストの中で、`ActiveRecord::RecordNotFound` のような応答に変えられる例外は、例外のまま上がらずに 404 などの応答になる。ほかの例外は今と同じく上がる。7.1 で非推奨になった `false` の値もなくなる
- なぜ: テストでも本番に近い応答を確かめられるようにした（rails/rails#45867）
- 3 アプリへの影響: 例外を期待するテストはない（`assert_raises` を使っていない）。minitest は通った
- 扱い: 追随
- 出典: rails/rails#45867、`actionpack-7.1.6/CHANGELOG.md`、Rails ガイド v7.1 の「Rails アップグレードガイド」の 2.13「コントローラーテスト、結合テスト、システムテストの例外処理方法が新しくなった」
- コミット: RS・RP・OP（`apply rails app:update for Rails 7.1`）

### DEF-7.1-14: development で `active_job.verbose_enqueue_logs = true`

- 種類: `app:update` の雛形 / 対象: 3 アプリ（development）
- 何が変わるか: ジョブを積んだときに、呼び出し元の行をログに出す
- なぜ: どこからジョブが積まれたかをログで分かるようにした（rails/rails#47839）
- 3 アプリへの影響: ジョブを使っていないので出ない
- 扱い: 追随
- 出典: rails/rails#47839、`activejob-7.1.6/CHANGELOG.md`
- コミット: RS・RP・OP（`apply rails app:update for Rails 7.1`）

### DEF-7.1-15: production.rb の雛形

- 種類: `app:update` の雛形 / 対象: 3 アプリ（production。動作保証の外で、雛形に追従するだけ）
- 何が変わるか: `force_ssl = true` が有効（#47852）。ログは常に STDOUT（#47138。`RAILS_LOG_TO_STDOUT` と `log_formatter` の行が消える）。ログのレベルは `RAILS_LOG_LEVEL`（#47143）。`public_file_server.enabled` の行がコメントになり既定の有効のままになる（#47137）。`assume_ssl`（#47139）と `config.hosts` の例（#47447）のコメントが増える。`require_master_key` の説明などのコメントが変わる
- なぜ: Rails 7.1 で、コンテナや PaaS で動かす前提の既定にした
- 3 アプリへの影響: development と test には効かない
- 扱い: 追随
- 出典: rails/rails#47852・#47138・#47143・#47137・#47139・#47447、`railties-7.1.6/CHANGELOG.md`（「Enable force_ssl=true in production by default」）
- コミット: RS・RP・OP（`apply rails app:update for Rails 7.1`）

### DEF-7.1-16: コメントと書き方だけの変化

- 種類: `app:update` の雛形 / 対象: 下のとおり
- 何が変わるか（値は変わらない）: `filter_parameter_logging.rb` の説明（3 アプリ。#49347。`:code` と日本語のコメントは戻した）、RS の `cors.rb` の「AJAX」→「Ajax」、RP・OP の CSP の例の `style-src`（#46141）、RP・OP の permissions policy の例のブロック引数 `f` → `policy` と見出しのコメント（#44144）、`consider_all_requests_local` の空白、test.rb の eager load・reloading の説明（#46648 ほか）
- なぜ: 雛形の説明と例の更新
- 3 アプリへの影響: ない
- 扱い: 追随
- 出典: rails/rails#49347・#46141・#44144・#46648
- コミット: RS・RP・OP（`apply rails app:update for Rails 7.1`）

### DEF-7.1-17: `bin/setup` の `system!` が `system(*args, exception: true)` になる

- 種類: `app:update` の雛形 / 対象: 3 アプリ
- 何が変わるか: コマンドが失敗したとき、`abort` の独自のメッセージの代わりに、Ruby の例外（失敗したコマンドと終了コード）で止まる
- なぜ: 失敗の原因を分かりやすくした（rails/rails#46064）
- 3 アプリへの影響: 失敗したときのメッセージの形だけ。E2E・CI は `bin/setup` を使わない
- 扱い: 追随
- 出典: rails/rails#46064
- コミット: RS・RP・OP（`apply rails app:update for Rails 7.1`）

### DEF-7.1-18: `active_storage:update` のマイグレーション

- 種類: `app:update` の雛形 / 対象: 3 アプリ
- 何が変わるか: `active_storage:update` が Active Storage のマイグレーションを 3 本足す（`add_service_name_to_active_storage_blobs`、`create_active_storage_variant_records`、`remove_not_null_on_active_storage_blobs_checksum`）
- なぜ: Active Storage を使うアプリのテーブルを、新しい版に合わせるため
- 3 アプリへの影響: 3 アプリとも Active Storage を使っていない（テーブルもない）
- 扱い: 採用しない（Step 1 と同じ扱い。`scripts/restore-app-config` が消す）
- 出典: `railties-7.1.6/lib/rails/tasks/framework.rake`（`app:update` が `active_storage:update` を流す）
- コミット: なし
