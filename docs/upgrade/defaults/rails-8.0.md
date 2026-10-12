# Rails 8.0 の既定値への追随

- 版: Rails 7.2.4 → 8.0.5.1（Ruby 3.3.12）
- Step: 6（ブランチ `upgrade/step6-rails80`）/ PR: （PR 作成後に記入）
- 記録のルールは [README.md](README.md)

## 一覧

| ID | 項目 | 種類 | 対象 | 扱い |
|---|---|---|---|---|
| DEF-8.0-01 | `to_time_preserves_timezone = :zone` を先に取り込む | Rails の既定値（8.0） | 3 アプリ | 追随（`application.rb` に足し、rails-defaults で移す） |
| DEF-8.0-02 | Rails 8.0.5.1 の initializer が、起動の途中で `ActionController::Live`・`ActionDispatch::Response` を読み込む | Rails の既定値（読み込みの順番） | 3 アプリ | 追随（検査で、この 1 件だけを Step 7 まで許す） |
| DEF-8.0-03 | development・test の起動の時点で、ルーティングを描かなくなる | Rails の既定値 | 3 アプリ | 追随 |
| DEF-8.0-04 | SQLite のトランザクションが IMMEDIATE になり、待ち方が変わる | Rails の既定値 | 3 アプリ | 追随 |
| DEF-8.0-05 | Active Job の `enqueue_after_transaction_commit` が `:default` → `false` になる | Rails の既定値 | 3 アプリ | 追随 |
| DEF-8.0-06 | 7.2 で非推奨になった 2 つの設定が消える | Rails の既定値 | 3 アプリ | 追随（何もしない） |
| DEF-8.0-07 | `ActiveRecord::QueryLogs.tags_formatter` の値の形が変わる | Rails の内部の整理 | 3 アプリ | 追随 |
| DEF-8.0-08 | パラメーターの解析を Rails が自前で行い、Rack 2 との互換の設定が増える | Rails の既定値 | 3 アプリ | 追随 |
| DEF-8.0-09 | development で web-console のコンソールを常に許す IP に、IPv4 を IPv6 の形で表したループバックが増える | 周辺 gem の既定値（web-console 4.3.0） | RP・OP（development） | 追随 |
| DEF-8.0-10 | web-console のコンソールの閉じるボタンの文字が `x` → `×` になる | 周辺 gem の雛形（web-console 4.3.0） | RP・OP（development） | 追随 |
| DEF-8.0-11 | 環境のファイルのコメントと書き方 | Rails の雛形 | 3 アプリ | 追随 |
| DEF-8.0-12 | development の `cache_store` が、常に `:memory_store` になる | Rails の雛形 | 3 アプリ（development） | 追随 |
| DEF-8.0-13 | development で query log tags が有効になる | Rails の雛形 | 3 アプリ（development） | 追随 |
| DEF-8.0-14 | development・test の `disallowed_deprecation` の 2 行が消える | Rails の雛形 | 3 アプリ | 追随 |
| DEF-8.0-15 | test の `perform_caching = false` の 2 行が消える | Rails の雛形 | 3 アプリ（test） | 追随 |
| DEF-8.0-16 | test のメーラーの `default_url_options` の host が `www.example.com` → `example.com` | Rails の雛形 | 3 アプリ（test） | 追随 |
| DEF-8.0-17 | `filter_parameter_logging.rb` に `:cvv`・`:cvc` が増える | Rails の雛形 | 3 アプリ | 追随 |
| DEF-8.0-18 | `config/puma.rb` のコメント | Rails の雛形 | 3 アプリ | 追随 |
| DEF-8.0-19 | `config/puma.rb` の `plugin :solid_queue` | Rails の雛形（新しい構成） | 3 アプリ | 採用しない |
| DEF-8.0-20 | `bin/setup` が最後に `bin/dev` でサーバーを起動し、`bin/dev` が増える | Rails の雛形 | 3 アプリ | 追随 |
| DEF-8.0-21 | `bin/rubocop`・`bin/brakeman` | Rails の雛形 | 3 アプリ | 採用しない |
| DEF-8.0-22 | public のエラーページの作り直しと `400.html` の追加 | Rails の雛形 | RP・OP | 追随 |
| DEF-8.0-23 | `public/406-unsupported-browser.html`・`icon.png`・`icon.svg` | Rails の雛形 | RP・OP | 採用しない |
| DEF-8.0-24 | production.rb | Rails の雛形 | 3 アプリ | 追随 |

## Rails 8.0.5.1 の lock（rails-lock）

Rails を 7.2.4 → 8.0.5.1 にしたとき（`load_defaults` は 7.2 のまま）に起きた、Rails の既定値の変化。応答と E2E のスナップショット、`RUBYOPT=-W:deprecated` の警告、brakeman の結果（無視の項目を除く）、development だけのヘッダーは変わらず、`scripts/compare-config` の設定の値と読み込み済みの部品（3 アプリの test・development）、起動の途中の読み込みの検査、テストのログで見つけた。

### DEF-8.0-01: `to_time_preserves_timezone = :zone` を先に取り込む

- 種類: Rails の既定値（`load_defaults 8.0` の項目）/ 対象: RS・RP・OP
- 何が変わるか: `ActiveSupport.to_time_preserves_timezone` が `:offset` → `:zone` になる。`to_time` の戻り値が、受け手の UTC からのずれではなく、タイムゾーンを保つ
- なぜ: 8.0 は、値が `:zone` でないと非推奨の警告を出す（8.1 で常に `:zone` になる）。警告は、initializer `active_support.set_configs` が `config.active_support` の値を `ActiveSupport` に渡すところで出る（`activesupport-8.0.5.1/lib/active_support/railtie.rb:128`）。`load_defaults 7.2` のままだと 5.0 の節の `:offset`（`railties-8.0.5.1/lib/rails/application/configuration.rb:119`）が入り、test の `deprecation = :raise` で起動時に止まった（RS で確かめた。research では after_initialize で出る見込みとしていたが、それより前だった）
- 3 アプリへの影響: app・config・lib・test に `to_time` はない。`:zone` と `:offset` は表す時刻が同じで、差が出るのは夏時間をまたぐ計算だけ。応答と E2E のスナップショットは同じ
- 扱い: 追随。rails-lock のコミットで 3 アプリの `config/application.rb` に理由のコメント付きで足し、rails-defaults で `new_framework_defaults_8_0.rb` の同じ項目に移し、`load_defaults 8.0` で消す（PLAN.md の Step 6 の決めたことの 2）
- 出典: `activesupport-8.0.5.1/lib/active_support.rb` の `to_time_preserves_timezone=`、`railties-8.0.5.1/lib/rails/application/configuration.rb:119`・`:341`。Rails ガイド v8.0 の「Rails アプリケーションを設定する」の 3.14.18「config.active_support.to_time_preserves_timezone」
- コミット: RS・RP・OP（`update Rails to 8.0.5.1`）

### DEF-8.0-02: Rails 8.0.5.1 の initializer が、起動の途中で `ActionController::Live`・`ActionDispatch::Response` を読み込む

- 種類: Rails の既定値（読み込みの順番。8.0.5 からの不具合）/ 対象: RS・RP・OP
- 何が変わるか: initializer `action_controller.live_streaming_excluded_keys`（`actionpack-8.0.5.1/lib/action_controller/railtie.rb:34-36`）が `ActionController::Live` を読み込み、`live.rb` が `ActionDispatch::Response` を require して、`on_load(:action_dispatch_response)` が config/initializers より先に走る。`scripts/compare-config` で、`action_dispatch_response` が「config/initializers の直前」に読み込み済みになり、a-nti_manner_kick_course 0.5.0 が 3 アプリの test（`CI=1` を含む）・development で検出する
- なぜ: Live のアクションは別のスレッドで動き、要求のスレッドの実行状態を共有する。DB の接続先の切り替え（`connected_to`）が共有されて残る不具合（rails/rails#52906）への対処として、共有しないキーを選ぶ設定 `config.action_controller.live_streaming_excluded_keys`（既定は空）が足された（#56393。バグ修正として 8.0.5 に入った）。設定を渡す initializer が Live を読み込むことは、main で直され（#56558、2026-01。読み込みの整理として）、その後「config/initializers の `config.action_dispatch.default_headers` が効かない」不具合として報告されて（#58145、2026-07-17）、8-1-stable（#58147）と 8-0-stable（#58276、07-28）に backport された。8.0.5.1（07-29）はセキュリティ修正だけの版で、入っていない。8.1.4 は直っている
- 3 アプリへの影響: #58145 の実害は、config/initializers で `ActionDispatch::Response` に入る設定（`default_headers`・`default_charset`）を変えると効かないこと。3 アプリの config にこの 2 つを書いた箇所はなく、compare-config の値は前と同じ。Live も使っていない。8-0-stable の修正を一時的に `vendor/bundle` に当てると、3 アプリとも test・development で検出がなくなった（ほかの検出はない。当てたファイルは戻した）
- 扱い: 追随。自前のパッチと未リリースの版は使わず（保守ができなくなるため。人間が判断）、検査でこの 1 件だけを Step 7 まで許す。`scripts/check-load-hooks` が、`on_load(:action_dispatch_response)` と `actionpack-8.0.5.1/lib/action_controller/railtie.rb:35:` の両方に当たる検出だけを終了コード 0 にし、check-apps と CI から呼ぶ（別の検出は 1 になることを確かめた）。gem は最初の 1 件で止まるので、許した検出の後ろにある検出は見えない。Step 6 の各作業の前後で、compare-config の「読み込み済みの部品」が、この 1 件のほかに増えていないかを見て補う。Step 6 の間は、config/initializers で `default_headers`・`default_charset` を変えない
- 出典: rails/rails#52906・#56393・#56558・#58145・#58147・#58276、`actionpack-8.0.5.1/CHANGELOG.md` の 8.0.5 の節。Rails ガイドに該当の節はない
- コミット: 道具（`scripts/check-load-hooks`、check-apps、CI）、RS・RP・OP（`update Rails to 8.0.5.1`）

### DEF-8.0-03: development・test の起動の時点で、ルーティングを描かなくなる

- 種類: Rails の既定値 / 対象: RS・RP・OP（`eager_load = false` の環境）
- 何が変わるか: compare-config の「initialize! の後」に読み込み済みの部品から、`action_cable`・`action_cable_channel`・`after_routes_loaded` が消える。OP では `active_record`・`active_record_encryption`・`active_record_sqlite3adapter`・`devise_failure_app` と、モデルの `ApplicationRecord`・`User` も消える（`devise_for` がルーティングを描くときに User を読んでいた）
- なぜ: 大きなアプリの起動を速くするため、ルーティングを最初の要求（か url_helpers を使ったとき）まで描かないようにした。`eager_load = true` の環境（`CI=1` と production）は、今までどおり起動時に描く
- 3 アプリへの影響: minitest（`CI=1` を含む）・E2E・スナップショットは同じ。最初の要求でルーティングを描く
- 扱い: 追随
- 出典: rails/rails#52353、`railties-8.0.5.1/CHANGELOG.md` の「Defer route drawing to the first request, or when url_helpers are called」。Rails ガイドに該当の節はない
- コミット: RS・RP・OP（`update Rails to 8.0.5.1`）

### DEF-8.0-04: SQLite のトランザクションが IMMEDIATE になり、待ち方が変わる

- 種類: Rails の既定値 / 対象: RS・RP・OP（DB に書くのは RP・OP）
- 何が変わるか: アプリの書き込みのトランザクションが `begin transaction` → `BEGIN immediate TRANSACTION` になる（テストの transactional fixtures は `BEGIN deferred TRANSACTION`。RP・OP の test.log で確かめた）。`timeout` は `busy_timeout` ではなく `busy_handler_timeout=`（GVL を止めない待ち方）で扱われ、`SQLite3::BusyException` は `ActiveRecord::StatementTimeout` になる
- なぜ: 書き込みのロックを始めに取り、同時に書いたときの busy の例外を避けるため
- 3 アプリへの影響: DB の中身とファイルの形は変わらない。テスト・E2E は同じ。手動確認用の DB では verify の手動確認で見る
- 扱い: 追随
- 出典: rails/rails#50371・#51958、`activerecord-8.0.5.1/CHANGELOG.md` の「Use SQLite `IMMEDIATE` transactions when possible」「Replace `SQLite3::Database#busy_timeout` with `#busy_handler_timeout=`」、`activerecord-8.0.5.1/lib/active_record/connection_adapters/sqlite3/database_statements.rb` の `begin_db_transaction`。Rails ガイドに該当の節はない
- コミット: RS・RP・OP（`update Rails to 8.0.5.1`）

### DEF-8.0-05: Active Job の `enqueue_after_transaction_commit` が `:default` → `false` になる

- 種類: Rails の既定値 / 対象: RS・RP・OP
- 何が変わるか: `ActiveJob::Base.enqueue_after_transaction_commit` が `:default` → `false` になる。トランザクションの中で enqueue しても commit を待たない
- なぜ: 8.0 で、この設定をアプリ全体で使うのは非推奨になり（ジョブごとに設定する）、`load_defaults 7.2` の節から外れた。7.2 の `:default` は、アダプター（`AbstractAdapter` は true）に任せる値だった
- 3 アプリへの影響: ジョブを使わない（DEF-7.2-22）。設定も書いていないので、非推奨の警告も出ない
- 扱い: 追随
- 出典: rails/rails#53375、`activejob-8.0.5.1/lib/active_job/railtie.rb` の initializer `active_job.enqueue_after_transaction_commit`、`activejob-7.2.4/lib/active_job/queue_adapters/abstract_adapter.rb`。Rails ガイドに該当の節はない
- コミット: RS・RP・OP（`update Rails to 8.0.5.1`）

### DEF-8.0-06: 7.2 で非推奨になった 2 つの設定が消える

- 種類: Rails の既定値 / 対象: RS・RP・OP
- 何が変わるか: `ActiveJob.use_big_decimal_serializer` と `ActionController::Parameters.allow_deprecated_parameters_hash_equality` のメソッドがなくなる（compare-config には `NoMethodError` と出る）
- なぜ: DEF-7.2-05 で `load_defaults 7.1` から外れた設定を、8.0 で削除した
- 3 アプリへの影響: 設定を書いておらず、7.2 の時点で新しい振る舞いだった
- 扱い: 追随（何もしない）
- 出典: `activejob-8.0.5.1/CHANGELOG.md`・`actionpack-8.0.5.1/CHANGELOG.md` の 8.0.0 の節。Rails ガイド v8.0 の「Ruby on Rails 8.0 リリースノート」の 5.1「削除されたもの」（Action Pack）・12.1「削除されたもの」（Active Job）
- コミット: RS・RP・OP（`update Rails to 8.0.5.1`）

### DEF-8.0-07: `ActiveRecord::QueryLogs.tags_formatter` の値の形が変わる

- 種類: Rails の内部の整理 / 対象: RS・RP・OP（書き出しは 3 アプリ）
- 何が変わるか: `ActiveRecord::QueryLogs.tags_formatter` が、nil（使うときに formatter のオブジェクトを作る）から `:legacy` のシンボルになる
- なぜ: QueryLogs を速くするための作り直し
- 3 アプリへの影響: query log tags を有効にしていないので、SQL のログは同じ（development で有効にする雛形は rails-app-update で扱う）
- 扱い: 追随（変化は書き出しの道具にだけ出る）
- 出典: rails/rails#52392、`activerecord-8.0.5.1/lib/active_record/query_logs.rb`。Rails ガイドに該当の節はない
- コミット: RS・RP・OP（`update Rails to 8.0.5.1`）

### DEF-8.0-08: パラメーターの解析を Rails が自前で行い、Rack 2 との互換の設定が増える

- 種類: Rails の既定値 / 対象: RS・RP・OP
- 何が変わるか: `config.action_dispatch.strict_query_string_separator`・`config.action_dispatch.ignore_leading_brackets` が増える（どちらも nil）。nil のときは Rack 2 と同じ解析で、`;` 区切りのクエリと、名前の先頭の `[` を読み飛ばすときだけ非推奨の警告を出す
- なぜ: 8.0 でクエリとパラメーターの解析を Rails 側（`ActionDispatch::QueryParser`・`ParamBuilder`）に移し、Rack 2 のときの挙動を保った
- 3 アプリへの影響: rack は 2.2.24 のままで、解析の結果は同じ。OAuth・OIDC のパラメーターに `;` 区切りや先頭の `[` はなく、テスト・E2E で警告も出ていない
- 扱い: 追随
- 出典: rails/rails#53471、`actionpack-8.0.5.1/lib/action_dispatch/http/query_parser.rb`・`param_builder.rb`、`actionpack-8.0.5.1/CHANGELOG.md` の「Maintain Rack 2 parameter parsing behaviour」。Rails ガイドに該当の節はない
- コミット: RS・RP・OP（`update Rails to 8.0.5.1`）

補足: 書き出しに `config.action_dispatch.strict_freshness = false` が増える。8.0 で足された設定で、`load_defaults 8.0` で true になるので、rails-defaults で扱う

## 周辺 gem（Step 6）

web-console 4.2.1 → 4.3.0（RP・OP。railties・actionview `>= 8.0` なので Rails 8.0.5.1 の直後。作業計画の論点 4）で起きた変化。v4.2.1...v4.3.0 の `lib` の差分は、下の 2 つのほかに、Rails 8.1 より後で使う `WebConsole::Request#first_non_proxy` の追加（8.0.5.1 は従来の `filter_proxies` を使う）と、`source_location.rb` の Ruby 2.6 未満の分岐の削除だけ。railtie とミドルウェアの位置、`ActionDispatch::Request` の早い読み込み（IMP-009）は同じ。`scripts/compare-config` の設定の値と読み込み済みの部品（3 アプリの test・development）、`RUBYOPT=-W:deprecated` の警告、brakeman、development だけのヘッダーは、上げる前と同じ。generator の雛形はない。

### DEF-8.0-09: development で web-console のコンソールを常に許す IP に、IPv4 を IPv6 の形で表したループバックが増える

- 種類: 周辺 gem の既定値（web-console 4.3.0）/ 対象: RP・OP の development
- 何が変わるか: `WebConsole::Permissions::ALWAYS_PERMITTED_NETWORKS` が `127.0.0.0/8 ::1` → `127.0.0.0/8 ::1 ::ffff:127.0.0.0/104` になる
- なぜ: 二重スタックの環境では、localhost からの要求の送り元が `::ffff:127.0.0.1` の形で届くことがある。そのときも、`config.web_console.permissions` を足さずに例外画面のコンソールが出るようにした
- 3 アプリへの影響: development の例外画面のコンソールだけ。許すのはループバックだけで、外からの要求は許さない。3 アプリは `web_console.permissions` を設定していない。test・E2E・業務の画面には出ない
- 扱い: 追随
- 出典: rails/web-console#342、`web-console-4.3.0/CHANGELOG.markdown` の 4.3.0 の節、`web-console-4.3.0/lib/web_console/permissions.rb:8`。Rails ガイドに該当の節はない
- コミット: RP・OP（`update web-console to 4.3.0`）

### DEF-8.0-10: web-console のコンソールの閉じるボタンの文字が `x` → `×` になる

- 種類: 周辺 gem の雛形（web-console 4.3.0 のテンプレート）/ 対象: RP・OP の development
- 何が変わるか: `_inner_console_markup.html.erb` の閉じるボタンが `x` → `&times;` になる
- なぜ: 見た目の整理。CHANGELOG に項目はなく、v4.2.1...v4.3.0 の比較で見つけた
- 3 アプリへの影響: development の例外画面のコンソールの見た目だけで、アプリの画面ではない
- 扱い: 追随
- 出典: `web-console-4.3.0/lib/web_console/templates/_inner_console_markup.html.erb`（`web-console-4.2.1/` と比べた）。Rails ガイドに該当の節はない
- コミット: RP・OP（`update web-console to 4.3.0`）

## `app:update` の雛形（rails-app-update）

3 アプリで `yes a | bin/rails app:update`（Rails 8.0.5.1。DB は E2E 用）を流し、`scripts/restore-app-config` で独自設定を戻した後の差分。戻したのは test の `deprecation = :raise`、`config/puma.rb` の port、`filter_parameters` の `:code` とコメント、RP の `autoload_lib_once` と inflector で、戻せない項目は出なかった。戻す前の差分（`app:update` の直後）も控え、戻した設定の上の雛形のコメントが 7.2.4 から変わっていないことを確かめた（Step 5 のコードレビューの指摘。LOG.md の Step 5 の気づきの 19）。`config/application.rb` の雛形で、rails-lock で足した `to_time_preserves_timezone`（DEF-8.0-01）が消えたので、手で戻した（rails-defaults で移すまでの一時的な設定なので、道具の一覧には足していない）。`new_framework_defaults_8_0.rb` は、すべてコメントのまま足し、rails-defaults で扱う。`active_storage:update` のマイグレーション 3 本は、DEF-7.0-14 のとおり道具で消した。差分を当てた状態で、3 アプリの検査と E2E が通り、応答と E2E のスナップショット、警告、brakeman、development だけのヘッダー、`scripts/compare-config` の読み込み済みの部品は変わらなかった。設定の値で変わったのは DEF-8.0-12〜17 の値だけ。

### DEF-8.0-11: 環境のファイルのコメントと書き方

- 種類: Rails の雛形 / 対象: RS・RP・OP
- 何が変わるか: development.rb・test.rb のコメントの言い換え。`public_file_server.headers` のキーが小文字の `"cache-control"` になり、test は `max-age=3600` と数字で書く。test.rb の先頭の `require "active_support/core_ext/integer/time"` を消す。値は同じ
- なぜ: 環境のファイルを簡潔にし、ヘッダー名を HTTP/2 に合わせて小文字にした
- 3 アプリへの影響: 値は同じ。public のファイルを返す応答のヘッダー名の大文字・小文字だけが変わりうる。応答のスナップショットは同じ
- 扱い: 追随
- 出典: rails/rails#52999、rails/rails の commit `67302d8e8b`（Downcase cache-control in generated env files）・`44548856c4`。Rails ガイドに該当の節はない
- コミット: RS・RP・OP（`apply the Rails 8.0 app:update templates`）

### DEF-8.0-12: development の `cache_store` が、常に `:memory_store` になる

- 種類: Rails の雛形 / 対象: RS・RP・OP の development
- 何が変わるか: `tmp/caching-dev.txt` がないときの `:null_store` が `:memory_store` になる（`Rails.cache`、コントローラーとメーラーの cache_store）。`perform_caching = false` は残る
- なぜ: Rails 7.2 の `rate_limit` は `Rails.cache` を使うので、development でもそのまま試せるようにした
- 3 アプリへの影響: `Rails.cache`・`rate_limit`・`json.cache!` を使わない（lock の gem で `Rails.cache` を使うのは jbuilder の `cache!` だけ）。development の画面とヘッダーは同じ
- 扱い: 追随
- 出典: rails/rails#52434。Rails ガイドに該当の節はない
- コミット: RS・RP・OP（`apply the Rails 8.0 app:update templates`）

### DEF-8.0-13: development で query log tags が有効になる

- 種類: Rails の雛形 / 対象: RS・RP・OP の development
- 何が変わるか: `config.active_record.query_log_tags_enabled = true` になり、development のログの SQL に `/*application='…',controller='…',action='…'*/` のコメントが付く（形式は `load_defaults 7.1` の sqlcommenter。タグは `application`・`controller`・`action`・`job`）。有効にすると prepared statement を使わなくなる（`activerecord-8.0.5.1/lib/active_record/railtie.rb` の initializer `active_record.query_log_tags_config`）
- なぜ: SQL を、それを出したコードにたどれるようにした
- 3 アプリへの影響: development のログと SQL の実行のしかただけで、結果は同じ。test・E2E（development で動く）は同じ
- 扱い: 追随
- 出典: rails/rails の commit `e29ad0bcf7`、`railties-8.0.5.1/CHANGELOG.md` の「Enable query log tags by default on development env」。Rails ガイド v8.0 の「Rails アプリケーションを設定する」の 3.8.48〜3.8.50（query_log_tags）
- コミット: RS・RP・OP（`apply the Rails 8.0 app:update templates`）

### DEF-8.0-14: development・test の `disallowed_deprecation` の 2 行が消える

- 種類: Rails の雛形 / 対象: RS・RP・OP
- 何が変わるか: `config.active_support.disallowed_deprecation = :raise` と `disallowed_deprecation_warnings = []` の行が消える
- なぜ: 新しいアプリには非推奨がないので、既定の環境のファイルに出す必要がないとした
- 3 アプリへの影響: 禁止する警告の一覧が空なので、もともと効き目がなかった。test の `deprecation = :raise` は独自設定として残る
- 扱い: 追随
- 出典: rails/rails#51831。Rails ガイドに該当の節はない
- コミット: RS・RP・OP（`apply the Rails 8.0 app:update templates`）

### DEF-8.0-15: test の `perform_caching = false` の 2 行が消える

- 種類: Rails の雛形 / 対象: RS・RP・OP の test
- 何が変わるか: `ActionController::Base.perform_caching`・`ActionMailer::Base.perform_caching` が false → 既定の true になる（RP の test で runner で確かめた。`scripts/compare-config` は、設定の行が消えるとクラスの値も出さない）
- なぜ: test は `cache_store = :null_store` なので、キャッシュを有効にしても何も残らない。行を減らす整理
- 3 アプリへの影響: キャッシュは NullStore のままで何も保存されない。キャッシュを使っていない
- 扱い: 追随
- 出典: rails/rails#52999。Rails ガイドに該当の節はない
- コミット: RS・RP・OP（`apply the Rails 8.0 app:update templates`）

### DEF-8.0-16: test のメーラーの `default_url_options` の host が `www.example.com` → `example.com`

- 種類: Rails の雛形 / 対象: RS・RP・OP の test
- 何が変わるか: host の値とコメント。development の port 3000 は DEF-7.2-13 のまま
- なぜ: メーラーの既定の設定の整理
- 3 アプリへの影響: メールを送らない
- 扱い: 追随
- 出典: rails/rails#52513。Rails ガイドに該当の節はない
- コミット: RS・RP・OP（`apply the Rails 8.0 app:update templates`）

### DEF-8.0-17: `filter_parameter_logging.rb` に `:cvv`・`:cvc` が増える

- 種類: Rails の雛形 / 対象: RS・RP・OP
- 何が変わるか: ログと `inspect` で伏せる名前に `cvv`・`cvc` が増える（`filter_parameters`・`ActiveRecord::Base.filter_attributes`）。アプリの `:code` は末尾に戻した
- なぜ: カードのセキュリティコードを既定で伏せる
- 3 アプリへの影響: この名前のパラメーター・属性はない。ログだけ
- 扱い: 追随
- 出典: rails/rails の commit `53a52e3150`。Rails ガイドに該当の節はない
- コミット: RS・RP・OP（`apply the Rails 8.0 app:update templates`）

### DEF-8.0-18: `config/puma.rb` のコメント

- 種類: Rails の雛形 / 対象: RS・RP・OP
- 何が変わるか: `WEB_CONCURRENCY` の説明が増え、文の誤りが直る。port と threads の値は同じ
- なぜ: Puma 5 以上が `WEB_CONCURRENCY` を直接読むことを説明するため
- 3 アプリへの影響: なし
- 扱い: 追随
- 出典: rails/rails の commit `1e279be880`・`cda8c70c05`（`railties/lib/rails/generators/rails/app/templates/config/puma.rb.tt` の履歴）。Rails ガイドに該当の節はない
- コミット: RS・RP・OP（`apply the Rails 8.0 app:update templates`）

### DEF-8.0-19: `config/puma.rb` の `plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]`

- 種類: Rails の雛形（新しい構成）/ 対象: RS・RP・OP
- 何が変わるか: 環境変数があると、Solid Queue の supervisor を Puma の中で動かす 2 行（コメントと設定）が入る
- なぜ: 8.0 から、production の Active Job の既定が Solid Queue になった。`app:update` は `skip_solid` を渡さないので、この行が入る
- 3 アプリへの影響: solid_queue の gem はない
- 扱い: 採用しない（CLAUDE.md の新しい構成。2 行を消した）。Step 7 の `app:update` でもまた出る
- 出典: rails/rails#52804、`railties-8.0.5.1/lib/rails/generators/rails/app/templates/config/puma.rb.tt`
- コミット: なし（採用しない）

### DEF-8.0-20: `bin/setup` が最後に `bin/dev` でサーバーを起動し、`bin/dev` が増える

- 種類: Rails の雛形 / 対象: RS・RP・OP
- 何が変わるか: `bin/setup` から `APP_NAME` と `gem install bundler` を消し、最後の `bin/rails restart` を、`--skip-server` がなければ `exec "bin/dev"` にする。`bin/dev`（`exec "./bin/rails", "server", *ARGV`）が増える
- なぜ: 新しいアプリのサーバーの起動を `bin/dev` にそろえた（#52433、commit `7ed09d3a38`）。bundler は Ruby 2.6 から default gem なので入れる手順を外した（#52771）。サーバーを起動しない選択肢として `--skip-server` を足した（`e59153a0b6`）
- 3 アプリへの影響: `bin/setup` は README・E2E・CI・道具のどれからも使っていない。前からある `db:prepare` が development の DB に触れるので、手動確認用の DB があるうちは流さない。`bin/dev` は `rails server` と同じで、port は `config/puma.rb` の値
- 扱い: 追随（`bin/setup` が使うので `bin/dev` も足す）
- 出典: rails/rails#52433・#52771、rails/rails の commit `7ed09d3a38`・`e59153a0b6`・`ec48cfa9cc`。Rails ガイドに該当の節はない
- コミット: RS・RP・OP（`apply the Rails 8.0 app:update templates`）

### DEF-8.0-21: `bin/rubocop`・`bin/brakeman`

- 種類: Rails の雛形 / 対象: RS・RP・OP
- 何が変わるか: Step 5 と同じく、作成の提案が出る
- 3 アプリへの影響: 使う場所がない。`bin/brakeman` の `--ensure-latest` は 2 週間の決まりと食い違う
- 扱い: 採用しない（DEF-7.2-20 と同じ。作られたファイルを消した）
- 出典: DEF-7.2-20
- コミット: なし（採用しない）

### DEF-8.0-22: public のエラーページの作り直しと `400.html` の追加

- 種類: Rails の雛形 / 対象: RP・OP（RS は API なので作られない）
- 何が変わるか: `404.html`・`422.html`・`500.html` のマークアップと見た目が新しくなり、`400.html` が増える
- なぜ: エラーページの見た目の整理（#53045）。`400.html` は `params.expect` などで出る 400 の応答のため（#51674）
- 3 アプリへの影響: production だけで使われる。development と test は `consider_all_requests_local = true` でデバッグ用の画面が出る。応答と E2E のスナップショットは同じ
- 扱い: 追随
- 出典: rails/rails#53045・#51674。Rails ガイドに該当の節はない
- コミット: RP・OP（`apply the Rails 8.0 app:update templates`）

### DEF-8.0-23: `public/406-unsupported-browser.html`・`icon.png`・`icon.svg`

- 種類: Rails の雛形 / 対象: RP・OP
- 扱い: 採用しない（DEF-7.2-21 と同じ。`allow_browser` と PWA を使わない。作られたファイルを消した）
- 出典: DEF-7.2-21
- コミット: なし（採用しない）

### DEF-8.0-24: production.rb

- 種類: Rails の雛形 / 対象: RS・RP・OP
- 何が変わるか: `assume_ssl = true` を有効にし、logger を `ActiveSupport::TaggedLogging.logger(STDOUT)` にし、`silence_healthcheck_path = "/up"`・メーラーの `default_url_options`・SMTP のコメントを足し、public のファイルに 1 年のキャッシュを付け、コメントを整理する
- 3 アプリへの影響: 動作保証の外（雛形に追従するだけ。PLAN.md の 2 章）
- 扱い: 追随
- 出典: rails/rails#52999 など（`railties/lib/rails/generators/rails/app/templates/config/environments/production.rb.tt` の履歴）。Rails ガイドに該当の節はない
- コミット: RS・RP・OP（`apply the Rails 8.0 app:update templates`）
