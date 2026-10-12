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
