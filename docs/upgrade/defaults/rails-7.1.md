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
| DEF-7.1-19 | Active Record の暗号化の `hash_digest_class` が SHA256 になる | Rails の既定値（`new_framework_defaults_7_1.rb`） | 3 アプリ | 追随 |
| DEF-7.1-20 | SHA1 で暗号化したデータを読む予備の鍵を足さない | Rails の既定値（`new_framework_defaults_7_1.rb`） | 3 アプリ | 追随 |
| DEF-7.1-21 | `after_commit` などを、最後に保存したインスタンスで呼ぶ | Rails の既定値（`new_framework_defaults_7_1.rb`） | 3 アプリ | 追随 |
| DEF-7.1-22 | `before_committed!` を、トランザクションに入ったすべてのインスタンスで呼ぶ | Rails の既定値（`new_framework_defaults_7_1.rb`） | 3 アプリ | 追随 |
| DEF-7.1-23 | トランザクションのコールバックを、定義した順に呼ぶ | Rails の既定値（`new_framework_defaults_7_1.rb`） | 3 アプリ | 追随 |
| DEF-7.1-24 | 単数形の関連の名前を `where` に書くと、エラーにする | Rails の既定値（`new_framework_defaults_7_1.rb`） | 3 アプリ | 追随 |
| DEF-7.1-25 | `attr_readonly` の属性への代入を、エラーにする | Rails の既定値（`new_framework_defaults_7_1.rb`） | 3 アプリ | 追随 |
| DEF-7.1-26 | `serialize` が YAML を既定にしない | Rails の既定値（`new_framework_defaults_7_1.rb`） | 3 アプリ | 追随 |
| DEF-7.1-27 | モデルを Marshal するときの形式が 7.1 になる | Rails の既定値（`new_framework_defaults_7_1.rb`） | 3 アプリ | 追随 |
| DEF-7.1-28 | `has_secure_token` のトークンを `new` の時点で作る | Rails の既定値（`new_framework_defaults_7_1.rb`） | 3 アプリ | 追随 |
| DEF-7.1-29 | ジョブの引数の BigDecimal を、精度を保って直列化する | Rails の既定値（`new_framework_defaults_7_1.rb`） | 3 アプリ | 追随 |
| DEF-7.1-30 | キャッシュの有効期限の不正な値を、エラーにする | Rails の既定値（`new_framework_defaults_7_1.rb`） | 3 アプリ | 追随 |
| DEF-7.1-31 | query log tags の形式が SQLCommenter になる | Rails の既定値（`new_framework_defaults_7_1.rb`） | 3 アプリ | 追随 |
| DEF-7.1-32 | `ActionController::Parameters` を Hash と `==` で比べない | Rails の既定値（`new_framework_defaults_7_1.rb`） | 3 アプリ | 追随 |
| DEF-7.1-33 | SQLite の文字列の厳しいモード | Rails の既定値（`new_framework_defaults_7_1.rb`） | 3 アプリ | 追随 |
| DEF-7.1-34 | 必須の `belongs_to` の検証が、外部キーが変わったときだけ問い合わせる | Rails の既定値（`new_framework_defaults_7_1.rb`） | 3 アプリ | 追随 |
| DEF-7.1-35 | トランザクションのブロックを `return` などで抜けると、コミットする | Rails の既定値（`new_framework_defaults_7_1.rb`） | 3 アプリ | 追随 |
| DEF-7.1-36 | テストの HTML の読み方が HTML5 になる | Rails の既定値（`new_framework_defaults_7_1.rb`） | 3 アプリ（test） | 追随 |
| DEF-7.1-37 | `filter_parameters` を先に正規表現にまとめる | Rails の既定値（`new_framework_defaults_7_1.rb`） | 3 アプリ | 追随 |
| DEF-7.1-38 | 処理されなかった例外のログのレベルが ERROR になる | Rails の既定値（`new_framework_defaults_7_1.rb`） | 3 アプリ | 追随 |
| DEF-7.1-39 | 既定の応答ヘッダーから `X-Download-Options` がなくなる | Rails の既定値（`new_framework_defaults_7_1.rb`） | 3 アプリ | 追随 |
| DEF-7.1-40 | `MessageVerifier`・`MessageEncryptor` の既定の serializer が `:json_allow_marshal` になる | Rails の既定値（`new_framework_defaults_7_1.rb`） | 3 アプリ | 追随 |
| DEF-7.1-41 | メッセージのデータとメタデータをまとめて直列化する | Rails の既定値（`new_framework_defaults_7_1.rb`） | 3 アプリ（効くのは OP） | 追随 |
| DEF-7.1-42 | アプリの autoload のパスを `$LOAD_PATH` に入れない | Rails の既定値（`load_defaults 7.1`） | 3 アプリ | 追随 |
| DEF-7.1-43 | キャッシュの形式が 7.1 になる | Rails の既定値（`load_defaults 7.1`） | 3 アプリ | 追随 |
| DEF-7.1-44 | development・test のログを 100 MB で切り替える | Rails の既定値（`load_defaults 7.1`） | 3 アプリ（development・test） | 追随 |
| DEF-7.1-45 | Action View の sanitizer が HTML5 になる | Rails の既定値（`load_defaults 7.1`） | 3 アプリ | 追随 |
| DEF-7.1-46 | Action Text の sanitizer が HTML5 になる | Rails の既定値（`load_defaults 7.1`） | 3 アプリ | 追随 |

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

## `load_defaults`（`new_framework_defaults_7_1.rb`）

`new_framework_defaults_7_1.rb` の設定を、グループごとに有効にした。グループと順番は人間が決めた（[PLAN.md](../PLAN.md) の Step 3、[LOG.md](../LOG.md) の Step 3）。各グループで、前後に `scripts/compare-config` で 3 アプリの test・development の値を書き出して比べ、すべての設定が新しい値になったことを確かめた。`action_view.sanitizer_vendor`・`action_text.sanitizer_vendor`・`add_autoload_paths_to_load_path`・`cache_format_version`・`log_file_size` は、`new_framework_defaults_7_1.rb` では有効にせず、`load_defaults 7.1` に任せる（`load_defaults 7.1` にするときに値を確かめる）。`sanitizer_vendor` の行は、sprockets-rails を入れていないアプリでは initializer の時点で `Rails::HTML` がなく、`NameError` で起動しない（rails/rails#51246。Rails 7.1.6 の `load_defaults` の側は #51267 で直っている）

### グループ 1: 3 アプリが使っていない機能

有効にしても、3 アプリの検査と E2E がすべて通り、応答のスナップショットは同じだった。

### DEF-7.1-19: Active Record の暗号化の `hash_digest_class` が SHA256 になる

- 種類: Rails の既定値（`new_framework_defaults_7_1.rb` のグループ 1）/ 対象: RS・RP・OP
- 何が変わるか: `config.active_record.encryption.hash_digest_class = OpenSSL::Digest::SHA256`（SHA1 → SHA256）。設定の値の比較: ActiveRecord::Encryption.config.hash_digest_class が SHA1 → SHA256（3 アプリ・test と development）
- なぜ: Active Record の暗号化の鍵を作るダイジェストを、7.0 で SHA256 にした key generator とそろえる
- 3 アプリへの影響: `encrypts` を使っておらず、暗号化したデータもない
- 扱い: 追随
- 出典: activerecord の CHANGELOG（「Support decrypting data encrypted non-deterministically with a SHA1 hash digest.」）、Rails ガイド v7.1 の「Rails アプリケーションを設定する」の3.8.67「config.active_record.encryption.hash_digest_class」
- コミット: RS・RP・OP（`enable the unused-feature defaults of Rails 7.1`）

### DEF-7.1-20: SHA1 で暗号化したデータを読む予備の鍵を足さない

- 種類: Rails の既定値（`new_framework_defaults_7_1.rb` のグループ 1）/ 対象: RS・RP・OP
- 何が変わるか: `config.active_record.encryption.support_sha1_for_non_deterministic_encryption = false`。設定の値の比較: config の値だけ（読み出す口がない）（3 アプリ・test と development）
- なぜ: SHA1 で暗号化したデータがなければ、予備の鍵は要らない
- 3 アプリへの影響: 主鍵がないので、もともと予備の鍵は足されない（previous の数は前後とも 0）
- 扱い: 追随
- 出典: activerecord の CHANGELOG（同上）、Rails ガイド v7.1 の「Rails アプリケーションを設定する」の3.8.68「config.active_record.encryption.support_sha1_for_non_deterministic_encryption」
- コミット: RS・RP・OP（`enable the unused-feature defaults of Rails 7.1`）

### DEF-7.1-21: `after_commit` などを、最後に保存したインスタンスで呼ぶ

- 種類: Rails の既定値（`new_framework_defaults_7_1.rb` のグループ 1）/ 対象: RS・RP・OP
- 何が変わるか: `config.active_record.run_commit_callbacks_on_first_saved_instances_in_transaction = false`。設定の値の比較: ActiveRecord::Base の値が true → false（3 アプリ・test と development）
- なぜ: トランザクションの中で同じ行を複数のインスタンスで保存したとき、最新の状態で呼ぶ
- 3 アプリへの影響: `after_commit` などのコールバックは、アプリにも devise（confirmable を使っていない）・doorkeeper にもない
- 扱い: 追随
- 出典: activerecord の CHANGELOG（「Run transactional callbacks on the freshest instance to save a given record within a transaction.」）、Rails ガイド v7.1 の「Rails アプリケーションを設定する」の3.8.44
- コミット: RS・RP・OP（`enable the unused-feature defaults of Rails 7.1`）

### DEF-7.1-22: `before_committed!` を、トランザクションに入ったすべてのインスタンスで呼ぶ

- 種類: Rails の既定値（`new_framework_defaults_7_1.rb` のグループ 1）/ 対象: RS・RP・OP
- 何が変わるか: `config.active_record.before_committed_on_all_records = true`。設定の値の比較: ActiveRecord の値が false → true（3 アプリ・test と development）
- なぜ: 上と同じ考え方
- 3 アプリへの影響: 同上
- 扱い: 追随
- 出典: activerecord の CHANGELOG（「Hide changes to before_committed! callback behaviour behind flag.」）、Rails ガイド v7.1 の「Rails アプリケーションを設定する」の3.8.24
- コミット: RS・RP・OP（`enable the unused-feature defaults of Rails 7.1`）

### DEF-7.1-23: トランザクションのコールバックを、定義した順に呼ぶ

- 種類: Rails の既定値（`new_framework_defaults_7_1.rb` のグループ 1）/ 対象: RS・RP・OP
- 何が変わるか: `config.active_record.run_after_transaction_callbacks_in_order_defined = true`。設定の値の比較: ActiveRecord の値が false → true（3 アプリ・test と development）
- なぜ: 今までは定義の逆順だった。直感に合う順にした
- 3 アプリへの影響: 同上
- 扱い: 追随
- 出典: activerecord の CHANGELOG（「`after_commit` callbacks defined on models now execute in the correct order.」）、Rails ガイド v7.1 の「Rails アプリケーションを設定する」の3.8.46
- コミット: RS・RP・OP（`enable the unused-feature defaults of Rails 7.1`）

### DEF-7.1-24: 単数形の関連の名前を `where` に書くと、エラーにする

- 種類: Rails の既定値（`new_framework_defaults_7_1.rb` のグループ 1）/ 対象: RS・RP・OP
- 何が変わるか: `config.active_record.allow_deprecated_singular_associations_name = false`。設定の値の比較: ActiveRecord の値が true → false（3 アプリ・test と development）
- なぜ: 非推奨だった書き方をやめる
- 3 アプリへの影響: アプリの関連を `where` で引く書き方はない。テストは通った
- 扱い: 追随
- 出典: activerecord の CHANGELOG（「Add configurable deprecation warning for singular associations」）、Rails ガイド v7.1 の「Rails アプリケーションを設定する」の3.8.56
- コミット: RS・RP・OP（`enable the unused-feature defaults of Rails 7.1`）

### DEF-7.1-25: `attr_readonly` の属性への代入を、エラーにする

- 種類: Rails の既定値（`new_framework_defaults_7_1.rb` のグループ 1）/ 対象: RS・RP・OP
- 何が変わるか: `config.active_record.raise_on_assign_to_attr_readonly = true`。設定の値の比較: ActiveRecord の値が false → true（3 アプリ・test と development）
- なぜ: 黙って捨てていた代入を、すぐ分かるようにする
- 3 アプリへの影響: `attr_readonly` を使っていない
- 扱い: 追随
- 出典: activerecord の CHANGELOG（「Raise on assignment to readonly attributes」）、Rails ガイド v7.1 の「Rails アプリケーションを設定する」の3.8.43
- コミット: RS・RP・OP（`enable the unused-feature defaults of Rails 7.1`）

### DEF-7.1-26: `serialize` が YAML を既定にしない

- 種類: Rails の既定値（`new_framework_defaults_7_1.rb` のグループ 1）/ 対象: RS・RP・OP
- 何が変わるか: `config.active_record.default_column_serializer = nil`。設定の値の比較: ActiveRecord::Base の値が YAML → nil（3 アプリ・test と development）
- なぜ: YAML の暗黙の直列化をやめる
- 3 アプリへの影響: `serialize` を使っていない。RP のセッションは activerecord-session_store の JSON の serializer
- 扱い: 追随
- 出典: activerecord の CHANGELOG（「`ActiveRecord::Base.serialize` no longer uses YAML by default.」）、Rails ガイド v7.1 の「Rails アプリケーションを設定する」の3.8.45
- コミット: RS・RP・OP（`enable the unused-feature defaults of Rails 7.1`）

### DEF-7.1-27: モデルを Marshal するときの形式が 7.1 になる

- 種類: Rails の既定値（`new_framework_defaults_7_1.rb` のグループ 1）/ 対象: RS・RP・OP
- 何が変わるか: `config.active_record.marshalling_format_version = 7.1`。設定の値の比較: ActiveRecord の値が 6.1 → 7.1（3 アプリ・test と development）
- なぜ: 小さく速い形式にした
- 3 アプリへの影響: モデルを Marshal しない（キャッシュは null・memory だけ。RP のセッションは JSON）
- 扱い: 追随
- 出典: activerecord の CHANGELOG（「Introduce a more stable and optimized Marshal serializer for Active Record models.」）、Rails ガイド v7.1 の「Rails アプリケーションを設定する」の3.8.27
- コミット: RS・RP・OP（`enable the unused-feature defaults of Rails 7.1`）

### DEF-7.1-28: `has_secure_token` のトークンを `new` の時点で作る

- 種類: Rails の既定値（`new_framework_defaults_7_1.rb` のグループ 1）/ 対象: RS・RP・OP
- 何が変わるか: `config.active_record.generate_secure_token_on = :initialize`。設定の値の比較: ActiveRecord の値が :create → :initialize（3 アプリ・test と development）
- なぜ: 保存の前でもトークンを使えるようにした
- 3 アプリへの影響: `has_secure_token` を使っていない（doorkeeper のトークンは doorkeeper が作る）
- 扱い: 追随
- 出典: activerecord の CHANGELOG（「Change `has_secure_token` default to `on: :initialize`」）、Rails ガイド v7.1 の「Rails アプリケーションを設定する」の3.8.60
- コミット: RS・RP・OP（`enable the unused-feature defaults of Rails 7.1`）

### DEF-7.1-29: ジョブの引数の BigDecimal を、精度を保って直列化する

- 種類: Rails の既定値（`new_framework_defaults_7_1.rb` のグループ 1）/ 対象: RS・RP・OP
- 何が変わるか: `config.active_job.use_big_decimal_serializer = true`。設定の値の比較: ActiveJob の値が false → true（3 アプリ・test と development）
- なぜ: JSON を使うキューで値が変わる不具合を直した
- 3 アプリへの影響: ジョブを使っていない
- 扱い: 追随
- 出典: activejob の CHANGELOG（「Fix BigDecimal (de)serialization for adapters using JSON.」）、Rails ガイド v7.1 の「Rails アプリケーションを設定する」の3.15.11
- コミット: RS・RP・OP（`enable the unused-feature defaults of Rails 7.1`）

### DEF-7.1-30: キャッシュの有効期限の不正な値を、エラーにする

- 種類: Rails の既定値（`new_framework_defaults_7_1.rb` のグループ 1）/ 対象: RS・RP・OP
- 何が変わるか: `config.active_support.raise_on_invalid_cache_expiration_time = true`。設定の値の比較: ActiveSupport::Cache::Store の値が false → true（3 アプリ・test と development）
- なぜ: 不正な `expires_in` などを、すぐ分かるようにする
- 3 アプリへの影響: キャッシュに書かない（null・memory だけ）
- 扱い: 追随
- 出典: activesupport の CHANGELOG（「Add `raise_on_invalid_cache_expiration_time` config to `ActiveSupport::Cache::Store`」）、Rails ガイド v7.1 の「Rails アプリケーションを設定する」の3.14.22
- コミット: RS・RP・OP（`enable the unused-feature defaults of Rails 7.1`）

### DEF-7.1-31: query log tags の形式が SQLCommenter になる

- 種類: Rails の既定値（`new_framework_defaults_7_1.rb` のグループ 1）/ 対象: RS・RP・OP
- 何が変わるか: `config.active_record.query_log_tags_format = :sqlcommenter`。設定の値の比較: config の値だけ（formatter は前後とも未設定）（3 アプリ・test と development）
- なぜ: OpenTelemetry の SQLCommenter の形式にそろえた
- 3 アプリへの影響: query log tags を有効にしていないので、formatter は前後とも設定されない
- 扱い: 追随
- 出典: activerecord の CHANGELOG（「Update query log tags to use the SQLCommenter format by default.」）、Rails ガイド v7.1 の「Rails アプリケーションを設定する」の3.8.49
- コミット: RS・RP・OP（`enable the unused-feature defaults of Rails 7.1`）

### DEF-7.1-32: `ActionController::Parameters` を Hash と `==` で比べない

- 種類: Rails の既定値（`new_framework_defaults_7_1.rb` のグループ 1）/ 対象: RS・RP・OP
- 何が変わるか: `config.action_controller.allow_deprecated_parameters_hash_equality = false`。設定の値の比較: ActionController::Parameters の値が true → false（3 アプリ・test と development）
- なぜ: 7.0 で非推奨にした比べ方をやめる。Hash との比べ方は常に false になる
- 3 アプリへの影響: `params ==` の比べ方はアプリ・gem にない。テストは通った
- 扱い: 追随
- 出典: `actionpack-7.1.6/lib/action_controller/metal/strong_parameters.rb`、Rails ガイド v7.1 の「Rails アプリケーションを設定する」の3.9.21
- コミット: RS・RP・OP（`enable the unused-feature defaults of Rails 7.1`）

### グループ 2: DB の扱い

有効にしても、3 アプリの検査と E2E がすべて通り、応答のスナップショット（OP のトークン系は、DB に入ったトークンの項目も比べる）は同じだった。

### DEF-7.1-33: SQLite の文字列の厳しいモード

- 種類: Rails の既定値（`new_framework_defaults_7_1.rb` のグループ 2）/ 対象: RS・RP・OP
- 何が変わるか: `config.active_record.sqlite3_adapter_strict_strings_by_default = true`。SQL の中の二重引用符の文字列（`"abc"`）を、文字列として受け付けなくなる（識別子だけを表す）。設定の値の比較: `SQLite3Adapter.strict_strings_by_default` が false → true（3 アプリ・test と development）
- なぜ: SQLite は二重引用符の中身を識別子として探し、見つからなければ文字列として扱うので、列名の打ち間違いが黙って通る（存在しない列に索引を作れてしまう、など）
- 3 アプリへの影響: 3 アプリに生の SQL はなく、devise・doorkeeper の問い合わせも minitest・E2E で通った。E2E の起動の `db:setup`（schema の読み込み）も通った
- 扱い: 追随
- 出典: activerecord の CHANGELOG（「Enable strict strings mode for `SQLite3Adapter`.」）、Rails ガイド v7.1 の「Rails アプリケーションを設定する」の 3.8.53「config.active_record.sqlite3_adapter_strict_strings_by_default」、「Rails アップグレードガイド」の 2.6「SQLite3Adapterが文字列のstrictモードで設定されるようになった」
- コミット: RS・RP・OP（`enable the database defaults of Rails 7.1`）

### DEF-7.1-34: 必須の `belongs_to` の検証が、外部キーが変わったときだけ問い合わせる

- 種類: Rails の既定値（`new_framework_defaults_7_1.rb` のグループ 2）/ 対象: RS・RP・OP（効くのは OP）
- 何が変わるか: `config.active_record.belongs_to_required_validates_foreign_key = false`。必須の `belongs_to` を持つ行を更新するとき、外部キーの列が変わっていなければ、関連先があるかの SELECT をしない。設定の値の比較: `ActiveRecord.belongs_to_required_validates_foreign_key` が true → false
- なぜ: 変わっていない関連のために、更新のたびに余分な問い合わせをしていた
- 3 アプリへの影響: 必須の `belongs_to` は、doorkeeper-openid_connect の `OpenidRequest` の `belongs_to :access_grant` だけ（doorkeeper の `application` は `optional: true`。polymorphic な resource owner は使っていない）。`OpenidRequest` は作るときと消すときだけで更新しない。作るときは外部キーが変わるので、今までどおり確かめる。DB に入るデータは変わらない
- 扱い: 追随
- 出典: activerecord の CHANGELOG（「Avoid validating `belongs_to` association if it has not changed.」）、Rails ガイド v7.1 の「Rails アプリケーションを設定する」の 3.8.26「config.active_record.belongs_to_required_validates_foreign_key」
- コミット: RS・RP・OP（`enable the database defaults of Rails 7.1`）

### DEF-7.1-35: トランザクションのブロックを `return` などで抜けると、コミットする

- 種類: Rails の既定値（`new_framework_defaults_7_1.rb` のグループ 2）/ 対象: RS・RP・OP
- 何が変わるか: `config.active_record.commit_transaction_on_non_local_return = true`。`transaction do ... end` の中から `return`・`break`・`throw` で抜けたとき、ロールバックせずにコミットする（7.0 では非推奨の警告を出してロールバック）。設定の値の比較: `ActiveRecord.commit_transaction_on_non_local_return` が true になった
- なぜ: もともと例外のときだけロールバックしていた。Ruby 2.3 の `timeout` が `throw` を使うようになって途中のトランザクションがコミットされる問題が出たため、一時的にロールバックにしていた。`timeout` の側が直ったので、元の動きに戻した
- 3 アプリへの影響: アプリにトランザクションのブロックはない。doorkeeper の `grant.transaction do`（`doorkeeper-5.9.9/lib/doorkeeper/oauth/authorization_code_request.rb`）の中は `raise` だけで `return` はない。テストの出力に、ロールバックのときに出る非推奨の警告はない
- 扱い: 追随
- 出典: activerecord の CHANGELOG（「Bring back the historical behavior of committing transaction on non-local return.」）、Rails ガイド v7.1 の「Rails アプリケーションを設定する」の 3.8.42「config.active_record.commit_transaction_on_non_local_return」
- コミット: RS・RP・OP（`enable the database defaults of Rails 7.1`）

### グループ 3: テストだけ

### DEF-7.1-36: テストの HTML の読み方が HTML5 になる

- 種類: Rails の既定値（`new_framework_defaults_7_1.rb` のグループ 3）/ 対象: RS・RP・OP（test）
- 何が変わるか: `config.dom_testing_default_html_version = :html5`。`assert_select`・`assert_dom_equal` などが、応答の HTML を Nokogiri の HTML5 のパーサーで読む（今までは HTML4）。アプリの応答は変わらない。設定の値の比較: `Rails::Dom::Testing.default_html_version` が :html4 → :html5（3 アプリ・test と development）
- なぜ: 今のブラウザと同じ HTML5 の規則で、テストでも HTML を読むようにした（rails/rails#48682）
- 3 アプリへの影響: `assert_select` を使うのは RP の 3 ファイル（ログイン・introspection・セッション）と OP の 2 ファイル（認可エンドポイント・認可コードフロー）で、どれも通った。応答のスナップショットは本文を文字列で比べるので、パーサーに関係しない
- 扱い: 追随
- 出典: rails/rails#48682、`rails-dom-testing-2.3.0/README.md`、`rails-dom-testing-2.3.0/lib/rails/dom/testing/railtie.rb`、Rails ガイド v7.1 の「Rails アプリケーションを設定する」の 3.2.25「config.dom_testing_default_html_version」
- コミット: RS・RP・OP（`parse test HTML as HTML5 as in Rails 7.1`）

### グループ 4: ログ

`log_file_size` は、`new_framework_defaults_7_1.rb` では効かないので有効にせず、`load_defaults 7.1` に任せる（人間が判断）。initializer で有効にすると `config.log_file_size` は 100 MB になったが、ロガーは起動の早い段階の `initialize_logger` で作られる（`railties-7.1.6/lib/rails/application/bootstrap.rb`）ので、ログのファイルの上限は `Logger` の既定の 1 MB のままだった。

### DEF-7.1-37: `filter_parameters` を先に正規表現にまとめる

- 種類: Rails の既定値（`new_framework_defaults_7_1.rb` のグループ 4）/ 対象: RS・RP・OP
- 何が変わるか: `config.precompile_filter_parameters = true`。起動の時点で `filter_parameters` の並びを 1 つの正規表現にまとめる。設定の値の比較: RS・RP は `[:passw, ..., :code]` → `[/(?i:passw)|...|(?i:code)/]`。OP は doorkeeper が足す完全一致の正規表現も 1 つにまとまる。サンプルの値を伏せた結果（`code`・`code_verifier`・`client_secret`・`access_token`・`id_token`・`password` は `[FILTERED]`、`state`・`name` はそのまま）は前後で同じ
- なぜ: 伏せるたびに並びを 1 つずつ調べていたのを、先にまとめて速くした（rails/rails#46452・#48180）
- 3 アプリへの影響: ログで伏せる項目は同じ
- 扱い: 追随
- 出典: rails/rails#46452・#48180、`railties-7.1.6/CHANGELOG.md`（「Add `config.precompile_filter_parameters`」）、Rails ガイド v7.1 の「Rails アプリケーションを設定する」の 3.2.46「config.precompile_filter_parameters」
- コミット: RS・RP・OP（`enable the logging defaults of Rails 7.1`）

### DEF-7.1-38: 処理されなかった例外のログのレベルが FATAL から ERROR になる

- 種類: Rails の既定値（`new_framework_defaults_7_1.rb` のグループ 4）/ 対象: RS・RP・OP
- 何が変わるか: `config.action_dispatch.debug_exception_log_level = :error`。要求の処理中に捕まえられなかった例外を、`DebugExceptions` が ERROR のレベルでログに書く。設定の値の比較: env_config の値が 4（FATAL）→ 3（ERROR）
- なぜ: FATAL は「プログラムが止まる、扱えない誤り」のためのレベルで、`DebugExceptions` が扱っている例外には合わない（rails/rails#48575）
- 3 アプリへの影響: ログの行のレベルの表示だけ。ログのレベルを ERROR より上にしていないので、出る行も変わらない
- 扱い: 追随
- 出典: rails/rails#48575、Rails ガイド v7.1 の「Rails アプリケーションを設定する」の 3.10.2「config.action_dispatch.debug_exception_log_level」
- コミット: RS・RP・OP（`enable the logging defaults of Rails 7.1`）

### グループ 5（なし）・グループ 6: 応答のヘッダー

グループ 5（`action_view.sanitizer_vendor`）は `load_defaults 7.1` に任せたので、なくした。

### DEF-7.1-39: 既定の応答ヘッダーから `X-Download-Options` がなくなる

- 種類: Rails の既定値（`new_framework_defaults_7_1.rb` のグループ 6）/ 対象: RS・RP・OP（Rails が返すすべての応答）
- 何が変わるか: `config.action_dispatch.default_headers` の既定の値から `"X-Download-Options" => "noopen"` を除く。ほかの 5 つ（`X-Frame-Options`・`X-XSS-Protection`・`X-Content-Type-Options`・`X-Permitted-Cross-Domain-Policies`・`Referrer-Policy`）は同じ値のまま。すべての応答から `X-Download-Options: noopen` がなくなる。設定の値の比較: `ActionDispatch::Response.default_headers` から `X-Download-Options` が消えた（3 アプリ・test と development）。応答のスナップショットの差分は、この 1 行だけ（RS 3 件・RP 7 件・OP 40 件）
- なぜ: このヘッダーは Internet Explorer だけが使い、IE は 2022 年にサポートが終わった。Rails 7 は IE を十分にはサポートしていないので、既定から外した（rails/rails#43968）
- 3 アプリへの影響: IE 以外のブラウザ・faraday・Playwright はこのヘッダーを使わず、3 アプリのコードも読まない。ダウンロードさせるファイルを返す画面もない。画面・リダイレクト先・アプリ間のやり取りは変わらない。応答のスナップショットを作り直した
- 扱い: 追随
- 出典: rails/rails#43968、`railties-7.1.6/CHANGELOG.md`（「Remove default `X-Download-Options` header」）、Rails ガイド v7.1 の「Rails アプリケーションを設定する」の 3.10.3「config.action_dispatch.default_headers」
- コミット: RS・RP・OP（`drop X-Download-Options from the default headers`）

### グループ 7: Cookie・メッセージの形式

### DEF-7.1-40: `MessageVerifier`・`MessageEncryptor` の既定の serializer が `:json_allow_marshal` になる

- 種類: Rails の既定値（`new_framework_defaults_7_1.rb` のグループ 7）/ 対象: RS・RP・OP
- 何が変わるか: `config.active_support.message_serializer = :json_allow_marshal`。serializer を指定せずに作った `MessageVerifier`・`MessageEncryptor`（`Rails.application.message_verifier` など）が JSON で書き、読むときは古い Marshal の形式にも戻って読める。設定の値の比較: `ActiveSupport::Messages::Codec.default_serializer` が :marshal → :json_allow_marshal（3 アプリ・test と development）
- なぜ: Marshal は、署名の鍵が漏れたときに、細工したメッセージで任意のオブジェクトを復元させる攻撃の入り口になる。安全な JSON を既定にし、7.1 の間は古いメッセージも読めるようにした（rails/rails#47963。雛形のコメントでは、7.2 で `:json` だけになる予定）
- 3 アプリへの影響: 3 アプリのコードは `MessageVerifier`・`MessageEncryptor` を直接使わない。Cookie は別の設定の `cookies_serializer`（RP・OP は `:json`）で書くので、この設定の対象外
- 扱い: 追随
- 出典: rails/rails#47963、`activesupport-7.1.6/CHANGELOG.md`、`new_framework_defaults_7_1.rb` の雛形のコメント、Rails ガイド v7.1 の「Rails アプリケーションを設定する」の 3.14.9「config.active_support.message_serializer」
- コミット: RS・RP・OP（`enable the message format defaults of Rails 7.1`）

### DEF-7.1-41: 署名・暗号化したメッセージの中で、データとメタデータをまとめて直列化する

- 種類: Rails の既定値（`new_framework_defaults_7_1.rb` のグループ 7）/ 対象: RS・RP・OP（効くのは OP のセッション Cookie）
- 何が変わるか: `config.active_support.use_message_serializer_for_metadata = true`。`purpose` や有効期限のメタデータを、データと一緒に 1 回で直列化する（今までは、データを直列化した後でメタデータの封筒に入れて、もう一度直列化していた）。署名・暗号化した Cookie の中身の形式が変わる。設定の値の比較: `ActiveSupport::Messages::Metadata.use_message_serializer_for_metadata` が nil → true
- なぜ: 二重の直列化をやめて速くした（rails/rails#46848）
- 3 アプリへの影響: 対象は OP のセッション Cookie（Cookie store の暗号化 Cookie）だけ。RP のセッション Cookie は署名のない ID、RS は Cookie を使わず、3 アプリのコードに `cookies.signed`・`cookies.encrypted` はない。Rails 7.1.6 の OP の test で、同じ鍵・同じ用途の暗号化を設定の前後で作って読み合わせ、古い形式は新しい設定で読め、新しい形式も 7.1 では古い設定で読め、用途が違えばどちらも読めないことを確かめた。Rails 7.0 は新しい形式を読めない（雛形のコメント）ので、Rails 7.0 のブランチに戻すと、手動確認のブラウザの OP のログインが一度切れる。ローテーションのコードは入れない（DEF-7.0-36 と同じ考え方）。Rails 7.0 のときの OP の Cookie が 7.1 で読めることは、verify の手動確認で確かめる
- 扱い: 追随
- 出典: rails/rails#46848、`activesupport-7.1.6/lib/active_support/messages/metadata.rb`、`actionpack-7.1.6/lib/action_dispatch/middleware/cookies.rb`、`new_framework_defaults_7_1.rb` の雛形のコメント、Rails ガイド v7.1 の「Rails アプリケーションを設定する」の 3.14.10「config.active_support.use_message_serializer_for_metadata」
- コミット: RS・RP・OP（`enable the message format defaults of Rails 7.1`）

## `load_defaults 7.1`

3 アプリを `config.load_defaults 7.1` にし、`new_framework_defaults_7_1.rb` を消した。前後に `scripts/compare-config` で 3 アプリの test・development の値を書き出して比べると、違うのは `new_framework_defaults_7_1.rb` で有効にせずに `load_defaults 7.1` に任せた 5 つの設定（DEF-7.1-42〜46）だけで、6 つの書き出しで同じ違いだった。`new_framework_defaults_7_1.rb` で有効にしていた 22 の設定の値と、起動の途中に読み込み済みの部品は変わらない。5 つの設定が効く先を書き出すため、比べる前に `scripts/lib/dump_config.rb` に値を足した。3 アプリの検査と E2E の件数、応答のスナップショット、development の eager load の警告（0 件）は前と同じ。

7.1.6 の雛形の initializer は 7.0.10 と同じ 7 つで、7.1 で雛形から消えたものはない。雛形にない `config/initializers/backtrace_silencers.rb` は 3 アプリとも残す。`BACKTRACE` 環境変数でバックトレースの絞り込みを外す処理は `railties-7.1.6/lib/rails/backtrace_cleaner.rb` になく（railties が扱うのは 7.2 から）、このファイルだけが担う。Step 5 で見直す（DEF-7.0-37 の続き）。次の `app:update` で判断をし直さないよう、ファイルの先頭に残す理由のコメントを足した（人間が承認）。

### DEF-7.1-42: アプリの autoload のパスを `$LOAD_PATH` に入れない

- 種類: Rails の既定値（`load_defaults 7.1`）/ 対象: RS・RP・OP
- 何が変わるか: `config.add_autoload_paths_to_load_path` が true → false。`$LOAD_PATH` に入るアプリのディレクトリが、`app/*` の 7〜8 個と `lib`・`vendor` から、`lib`・`vendor` だけになる（設定の値の比較で確かめた）
- なぜ: Zeitwerk だけが autoloader になったので、autoload のパスを `$LOAD_PATH` に入れておく理由がなくなった。`$LOAD_PATH` が短くなると `require` が速くなり、bootsnap のキャッシュも小さくなる（rails/rails#44133）
- 3 アプリへの影響: アプリのコードの `require` はすべて gem か `test_helper` を読み（`test` は `bin/rails test` が `$LOAD_PATH` に足す）、`app/*` のファイルを `require` で読むものはない。RP の独自ストラテジーは once のローダーで読み（DEF-7.1-10）、`lib` は `$LOAD_PATH` に残る。`zeitwerk:check`・minitest・E2E が通った
- 扱い: 追随
- 出典: rails/rails#44133、`railties-7.1.6/CHANGELOG.md`（「No longer add autoloaded paths to `$LOAD_PATH`」）、Rails ガイド v7.1 の「Rails アプリケーションを設定する」の 3.2.1「config.add_autoload_paths_to_load_path」、「Rails アップグレードガイド」の 2.2「自動読み込みされるパスが$LOAD_PATHに含まれなくなった」
- コミット: RS・RP・OP（`switch to load_defaults 7.1`）

### DEF-7.1-43: キャッシュの形式が 7.1 になる

- 種類: Rails の既定値（`load_defaults 7.1`）/ 対象: RS・RP・OP
- 何が変わるか: `ActiveSupport::Cache.format_version` が 7.0 → 7.1。キャッシュストアの coder の serializer が `Marshal70WithFallback` → `Marshal71WithFallback` になり、legacy の形式を使わなくなる（設定の値の比較で確かめた）
- なぜ: ビューの断片のような素の文字列を、Marshal を通さずに保存して速くした。7.1 の形式でも、6.1・7.0 の形式で書いたエントリは読める（rails/rails#48122・#48660）
- 3 アプリへの影響: キャッシュストアは test・development とも `null_store`（development の `tmp/caching-dev.txt` は 3 アプリともない）で、何も保存しない。アプリのコードは `Rails.cache` を使っていない。`new_framework_defaults_7_1.rb` では効かない設定なので、`load_defaults` に任せた
- 扱い: 追随
- 出典: rails/rails#48122・#48660、`activesupport-7.1.6/CHANGELOG.md`（「A new `7.1` cache format is available」）、`activesupport-7.1.6/lib/active_support/cache.rb` の `default_serializer`、Rails ガイド v7.1 の「Rails アプリケーションを設定する」の 3.14.11「config.active_support.cache_format_version」
- コミット: RS・RP・OP（`switch to load_defaults 7.1`）

### DEF-7.1-44: development・test のログを 100 MB で切り替える

- 種類: Rails の既定値（`load_defaults 7.1`。`Rails.env.local?` のときだけ）/ 対象: RS・RP・OP（development・test）
- 何が変わるか: `config.log_file_size` が nil → 100 MB。ロガーを `ActiveSupport::Logger.new(ファイル, 1, 100 MB)` で作る。前はローテーションしない設定（`shift_age` が 0）で、ログは際限なく伸びていた。後は 100 MB を超えると `<環境>.log.0` に移し、1 世代だけ残す。設定の値の比較: ロガーの `shift_size` が 1048576 → 104857600（前の 1 MB は `shift_age` が 0 なので使われない値）
- なぜ: development・test のログが気づかないうちに大きくなるので、既定で上限を設けた（rails/rails#44888）
- 3 アプリへの影響: ログの中身は変わらない。今のログはどれも 100 MB 未満で、すぐには切り替わらない。ログは手動確認用の環境の守るファイルに入っていない。グループ 4 で、`new_framework_defaults_7_1.rb` では効かないと確かめて、`load_defaults` に任せた
- 扱い: 追随
- 出典: rails/rails#44888、`railties-7.1.6/CHANGELOG.md`（「Allow configuration of logger size for local and test environments」）、`railties-7.1.6/lib/rails/application/bootstrap.rb` の `initialize_logger`、Ruby 3.2.11 の `logger/log_device.rb`、Rails ガイド v7.1 の「Rails アプリケーションを設定する」の 3.2.40「config.log_file_size」
- コミット: RS・RP・OP（`switch to load_defaults 7.1`）

### DEF-7.1-45: Action View の sanitizer が HTML5 になる

- 種類: Rails の既定値（`load_defaults 7.1`）/ 対象: RS・RP・OP
- 何が変わるか: `config.action_view.sanitizer_vendor` が `Rails::HTML4::Sanitizer` → `Rails::HTML5::Sanitizer`。`sanitize`・`strip_tags`・`simple_format` などが、ブラウザと同じ HTML5 の規則で HTML を読む。設定の値の比較: `ActionView::Helpers::SanitizeHelper.sanitizer_vendor` と `ActionView::Base` の 3 つの sanitizer のクラスが HTML4 → HTML5
- なぜ: HTML4 のパーサーとブラウザの読み方の食い違いを、sanitizer を抜ける手口に使われないようにした（rails/rails#48293）。7.1.6 では、sprockets-rails のないアプリでも HTML5 が選ばれるように直っている（rails/rails#51267）
- 3 アプリへの影響: sanitizer を通るのは、OP の `rails_open_id_provider/app/views/doorkeeper/applications/index.html.erb` の `simple_format(application.redirect_uri)` だけ。応答のスナップショット（`oauth_applications.txt`。fixtures の 3 つの redirect_uri）は変わらない。手動確認用の DB の 3 つの値（`sqlite3 -readonly` で読んだ）と、`\r\n`・`&`・`<script>` を含む値の計 10 個で、`simple_format` の出力は HTML4 と HTML5 で同じだった（`\r\n` は sanitizer の段階では HTML5 が `\n` にそろえるが、`simple_format` も後で `\n` にそろえる）
- 扱い: 追随
- 出典: rails/rails#48293・#51267、`actionview-7.1.6/CHANGELOG.md`（「Add support for HTML5 standards-compliant sanitizers」）、`railties-7.1.6/CHANGELOG.md`（「Fix sanitizer vendor configuration in 7.1 defaults」）、Rails ガイド v7.1 の「Rails アプリケーションを設定する」の 3.11.21「config.action_view.sanitizer_vendor」
- コミット: RS・RP・OP（`switch to load_defaults 7.1`）

### DEF-7.1-46: Action Text の sanitizer が HTML5 になる

- 種類: Rails の既定値（`load_defaults 7.1`）/ 対象: RS・RP・OP
- 何が変わるか: `config.action_text.sanitizer_vendor` が HTML4 → HTML5。設定の値の比較: `ActionText::ContentHelper.sanitizer` が `Rails::HTML4::SafeListSanitizer` → `Rails::HTML5::SafeListSanitizer`
- なぜ: Action View と同じ理由で、Action Text の本文の表示にも HTML5 の sanitizer を使う（rails/rails#48522）
- 3 アプリへの影響: 3 アプリとも Action Text を読み込むが、`has_rich_text` もリッチテキストの表示もない
- 扱い: 追随
- 出典: rails/rails#48522、`actiontext-7.1.6/CHANGELOG.md`、`actiontext-7.1.6/lib/action_text/engine.rb`、Rails ガイド v7.1 の「Rails アプリケーションを設定する」の 3.18.2「config.action_text.sanitizer_vendor」
- コミット: RS・RP・OP（`switch to load_defaults 7.1`）
