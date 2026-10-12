# Rails 7.2 の既定値への追随

- 版: Rails 7.1.6 → 7.2.4（Ruby 3.3.12）
- Step: 5（ブランチ `upgrade/step5-rails72`）/ PR: （PR 作成後に記入）
- 記録のルールは [README.md](README.md)

## 一覧

| ID | 項目 | 種類 | 対象 | 扱い |
|---|---|---|---|---|
| DEF-7.2-01 | OP の注釈の rake を、annotaterb の雛形にする | 周辺 gem の雛形（annotaterb 4.25.0） | OP | 追随（RuboCop に合わせて書き方を直す） |
| DEF-7.2-02 | OP に `.annotaterb.yml` を足し、旧 rake の 2 つの値を引き継ぐ | 周辺 gem の雛形（annotaterb 4.25.0） | OP | 追随（2 つの値は旧 rake のまま） |
| DEF-7.2-03 | 「Redirected to」のログで、クエリの値に filter_parameters がかかる | Rails の既定値 | OP | 追随 |
| DEF-7.2-04 | development の Server-Timing に `start_transaction.active_record` が増える | Rails の既定値 | 3 アプリ（development） | 追随 |
| DEF-7.2-05 | 7.1 で非推奨になった 4 つの設定が、`load_defaults 7.1` から外れる | Rails の既定値 | 3 アプリ | 追随（何もしない） |
| DEF-7.2-06 | `active_record.sqlite3_production_warning` がなくなる | Rails の既定値 | 3 アプリ | 追随 |
| DEF-7.2-07 | `ActionController::Base.default_protect_from_forgery` のクラスの値がなくなる | Rails の内部の整理 | RP・OP | 追随 |
| DEF-7.2-08 | `ActionController::API` に Caching と RateLimiting が入る | Rails の既定値 | RS | 追随 |
| DEF-7.2-09 | test 環境の Active Job のアダプターが、設定の値でも `:test` になる | Rails の既定値 | 3 アプリ（test） | 追随 |
| DEF-7.2-10 | Active Storage の 2 つの既定の変化（inline で返す画像の種類、Attachment の inverse_of） | Rails の既定値 | 3 アプリ | 追随 |

## 周辺 gem（Step 5）

Step 5 で、Rails 7.2.4 の前に annotate 3.2.0 を annotaterb 4.25.0 に置き換えたときの、gem の雛形への追随。置き換える理由と範囲は [PLAN.md](../PLAN.md) の Step 5 と [LOG.md](../LOG.md) の Step 5。RP は annotate を使っていなかったので、annotaterb に置き換えずに外した（雛形への追随ではないので、ここには項目を立てない。LOG.md の Step 5 の「作業計画からの変更点」）。

### DEF-7.2-01: OP の注釈の rake を、annotaterb の雛形にする

- 種類: 周辺 gem の雛形（annotate 3.2.0 → annotaterb 4.25.0。開発の道具）/ 対象: OP
- 何が変わるか: `lib/tasks/auto_annotate_models.rake` を消し、`bin/rails g annotate_rb:install` が作る `lib/tasks/annotate_rb.rake` にする
  - 前: annotate の generator の出力。`require 'annotate'`、`task :set_annotation_options` の中で全設定を `Annotate.set_defaults` に渡し、`Annotate.load_tasks`。Step 0-e で `task` の行に `rubocop:disable Metrics/BlockLength, Rails/RakeEnvironment` を付けていた
  - 後: development で、環境変数 `ANNOTATERB_SKIP_ON_DB_TASKS` がなければ、`require 'annotate_rb'` して `AnnotateRb::Core.load_rake_tasks` を呼ぶだけ。設定は rake に書かず、`.annotaterb.yml`（DEF-7.2-02）から読む。`task` のブロックがないので、2 つの `rubocop:disable` は要らなくなる
  - 雛形との違い: RuboCop の `Style/FrozenStringLiteralComment`・`Style/StringLiterals` に合わせて、マジックコメントを足し、2 つの文字列をシングルクォートにした。旧 rake も Step 0-e で同じ形に直していた。ファイルの先頭に理由のコメントを書いた
- なぜ: annotate 3.2.0 は `activerecord < 8.0` で Rails 8 に対応しないので、後継の annotaterb に置き換える（PLAN.md の 7 章）。annotaterb は旧 rake の設定も環境変数の設定も読まない（MIGRATION_GUIDE.md）。旧 rake の `require 'annotate'` は、残すと annotaterb がアプリの rake を読んだときに `LoadError` になる（試して起きた）
- 3 アプリへの影響: development の `db:migrate` の後に注釈を付ける動きは同じ（E2E 用の DB で `db:migrate --trace` を流し、`Annotating models` が出て、注釈の差分は出なかった）。test・CI では読まれない（`Rails.env.development?`）。annotaterb には Railtie がなく、rake のタスクはこの rake からだけ読まれる（`annotaterb-4.25.0/lib/annotate_rb/core.rb` の `load_rake_tasks`）
- 扱い: 追随（書き方だけ RuboCop に合わせる）
- 出典: `annotaterb-4.25.0/lib/generators/annotate_rb/install/install_generator.rb`・`annotaterb-4.25.0/lib/generators/annotate_rb/hook/templates/annotate_rb.rake`・`annotaterb-4.25.0/lib/annotate_rb/core.rb`、annotaterb の MIGRATION_GUIDE.md（v4.25.0）。Rails ガイドに該当の節はない（gem の雛形）
- コミット: OP（`replace annotate with annotaterb`）

### DEF-7.2-02: OP に `.annotaterb.yml` を足し、旧 rake の 2 つの値を引き継ぐ

- 種類: 周辺 gem の雛形（annotaterb 4.25.0。開発の道具）/ 対象: OP
- 何が変わるか: `bin/rails g annotate_rb:install` が、gem の既定値をすべて書き出した `.annotaterb.yml` を作る。旧 rake の値と既定値で違う 2 つを、旧 rake の値にした（`hide_limit_column_types`: 空 → `integer,bigint,boolean`、`hide_default_column_types`: 空 → `json,jsonb,hstore`）。2 行の上に、引き継ぐ理由のコメントを書いた。ほかの値（`position_in_*: before`、`classified_sort`、`show_indexes`、`show_foreign_keys`、`with_comment`、`exclude_tests: false`、`exclude_fixtures: false` など）は、旧 rake と同じ
- なぜ: annotaterb は設定を yml と引数だけから読み、2 つの既定値が annotate の旧 rake と違う（`annotaterb-4.25.0/lib/annotate_rb/options.rb` の `hide_default_column_types`・`hide_limit_column_types`）
- 3 アプリへの影響: 今の `users` の列には 2 つの設定が効く型がなく、既定値のままでも、2 つの値を引き継いで `annotaterb models --force` で書き直させても、`app/models/user.rb`・`test/fixtures/users.yml` の注釈は同じだった（E2E 用の DB）。引き継ぐのは、今後の列の追加で注釈の出し方を変えないため
- 扱い: 追随（2 つの値は旧 rake のまま）
- 出典: `annotaterb-4.25.0/lib/generators/annotate_rb/config/config_generator.rb`・`annotaterb-4.25.0/lib/annotate_rb/options.rb`、annotaterb の MIGRATION_GUIDE.md（v4.25.0）。Rails ガイドに該当の節はない（gem の雛形）
- コミット: OP（`replace annotate with annotaterb`）

## Rails 7.2.4 の lock（rails-lock）

Rails を 7.1.6 → 7.2.4 にしたとき（`load_defaults` は 7.1 のまま）に起きた、Rails の既定値の変化。応答と E2E のスナップショットは変わらず、`scripts/compare-config` の設定の値（3 アプリの test・development）、development だけのヘッダー、テストのログで見つけた。

### DEF-7.2-03: 「Redirected to」のログで、クエリの値に filter_parameters がかかる

- 種類: Rails の既定値（ログ）/ 対象: OP（RP・RS のリダイレクト先には、伏せる名前のクエリがない）
- 何が変わるか: `Redirected to http://localhost:3781/auth/my_op/callback?code=<AUTH_CODE>` が `...?code=[FILTERED]` になる。OP のテストのログで、`code=` のある「Redirected to」行の 72 行がすべて `[FILTERED]` になった（7.1.6 では、それまでの 6,431 行がすべて生の値）。応答の Location ヘッダーは変わらない
- なぜ: リダイレクト先の URL のクエリに入った秘密の値がログに残らないように、`filter_redirect` に当たらない URL でも、クエリの値ごとに `filter_parameters` をかけるようにした（rails/rails#51131。`actionpack-7.2.4/lib/action_dispatch/http/filter_redirect.rb` の `parameter_filtered_location`）。専用の設定はない
- 3 アプリへの影響: ログの出力だけ。OP のアプリが足した `:code`（PLAN.md の 3 章の 2 の境目 7）がここにも効き、Step 0-a で Rails 6.1 の制約で残ることを許容していた認可コードがログに出なくなる。RP・RS の「Redirected to」行は変わらない（RP のテストのログで確かめた）
- 扱い: 追随
- 出典: rails/rails#51131、`actionpack-7.2.4/CHANGELOG.md` の 7.2.0 の節。Rails ガイドに該当の節はない
- コミット: RS・RP・OP（`update Rails to 7.2.4`）

### DEF-7.2-04: development の Server-Timing に `start_transaction.active_record` が増える

- 種類: Rails の既定値（通知のイベント）/ 対象: 3 アプリの development（トランザクションを通る応答。今回は RP のトップ）
- 何が変わるか: RP のトップの Server-Timing に、`start_transaction.active_record;dur=…` が `transaction.active_record` の前に増える。RS の `/apples/show`（401）と OP の discovery・ログイン画面のヘッダーは同じ（E2E 用の DB で Puma に通して比べた）
- なぜ: トランザクションとセーブポイントの始まりに、新しい通知のイベントを出すようにした（`activerecord-7.2.4/CHANGELOG.md` の「Define the new Active Support notification event `start_transaction.active_record`」。rails/rails の commit 6a05a39199）。development の Server-Timing は ActiveSupport::Notifications のイベントを並べるので、項目が増える（DEF-7.1-08 と同じ仕組み）
- 3 アプリへの影響: development のヘッダーだけ。test の応答（スナップショット）には出ない
- 扱い: 追随
- 出典: 上の CHANGELOG。Rails ガイドに該当の節はない
- コミット: RS・RP・OP（`update Rails to 7.2.4`）

### DEF-7.2-05: 7.1 で非推奨になった 4 つの設定が、`load_defaults 7.1` から外れる

- 種類: Rails の既定値 / 対象: RS・RP・OP。1 つの変更（7.1 の非推奨の振る舞いの削除）で起きたので 1 項目にまとめた
- 何が変わるか: `active_record.commit_transaction_on_non_local_return`（true）、`active_record.allow_deprecated_singular_associations_name`（false）、`action_controller.allow_deprecated_parameters_hash_equality`（false）、`active_job.use_big_decimal_serializer`（true）が設定の値から消える。`ActionController::Parameters.allow_deprecated_parameters_hash_equality` と `ActiveJob.use_big_decimal_serializer` は nil になる
- なぜ: 7.2 で、古い振る舞い（ブロックを `return` などで抜けたときのロールバック、単数の関連を複数形の名前で参照すること、`Parameters` と Hash の比較、BigDecimal の古いシリアライザ）を削除し、新しい振る舞いに固定した。切り替えの設定は非推奨になり、`load_defaults 7.1` から外れた（`railties-7.2.4/lib/rails/application/configuration.rb`）
- 3 アプリへの影響: 3 アプリは `load_defaults 7.1` で既に新しい振る舞いで、固定された振る舞いはその値と同じ。設定を書いていないので、非推奨の警告も出ない（`RUBYOPT=-W:deprecated` の比較で前後同じ）
- 扱い: 追随（何もしない）
- 出典: `activerecord-7.2.4/CHANGELOG.md`・`actionpack-7.2.4/CHANGELOG.md`・`activejob-7.2.4/CHANGELOG.md` の 7.2.0 の節の「Deprecate `Rails.application.config....`」。Rails ガイド v7.2 の「Ruby on Rails 7.2 リリースノート」の 5.2「非推奨化」（Action Pack）・8.2「非推奨化」（Active Record）。Active Job の分はリリースノートにない
- コミット: RS・RP・OP（`update Rails to 7.2.4`）

### DEF-7.2-06: `active_record.sqlite3_production_warning` がなくなる

- 種類: Rails の既定値 / 対象: RS・RP・OP
- 何が変わるか: 設定の値から `config.active_record.sqlite3_production_warning = true` が消える
- なぜ: production で SQLite を使うときの警告をやめた。設定は効かず、書いてあれば消して非推奨の警告を出す（`activerecord-7.2.4/CHANGELOG.md` の「Remove warning message when running SQLite in production, but leave it unconfigured.」、`activerecord-7.2.4/lib/active_record/railtie.rb:202`）
- 3 アプリへの影響: 警告は production だけで、動作保証の外。設定は書いていない
- 扱い: 追随
- 出典: 上の CHANGELOG とソース。Rails ガイドに該当の節はない
- コミット: RS・RP・OP（`update Rails to 7.2.4`）

### DEF-7.2-07: `ActionController::Base.default_protect_from_forgery` のクラスの値がなくなる

- 種類: Rails の内部の整理 / 対象: RP・OP（書き出しは 3 アプリ）
- 何が変わるか: 設定の値の書き出しから `ActionController::Base.default_protect_from_forgery = true` が消える。`config.action_controller.default_protect_from_forgery = true` は残る
- なぜ: 使われていないクラスのアクセサーを消した（rails/rails#49426、7.2.0）。CSRF の対策は、railtie が config の値を見て `protect_from_forgery with: :exception` を呼ぶ形のまま（`actionpack-7.2.4/lib/action_controller/railtie.rb` の `action_controller.request_forgery_protection`）
- 3 アプリへの影響: RP・OP で `ActionController::Base.forgery_protection_strategy` が `Exception`、`ApplicationController` に `verify_authenticity_token` があることを確かめた。RP の CSRF の失敗のテストと E2E も通る
- 扱い: 追随（変化は書き出しの道具にだけ出る）
- 出典: rails/rails#49426。Rails ガイドに該当の節はない
- コミット: RS・RP・OP（`update Rails to 7.2.4`）

### DEF-7.2-08: `ActionController::API` に Caching と RateLimiting が入る

- 種類: Rails の既定値 / 対象: RS（`ApplicationController < ActionController::API`）。書き出しは 3 アプリ
- 何が変わるか: `ActionController::API.cache_store`（NullStore）と `ActionController::API.perform_caching`（false）が設定の値に出る
- なぜ: 7.2 の新機能の `rate_limit`（rails/rails#50490）を `ActionController::API` にも入れた。`rate_limit` はキャッシュを使うので、API のコントローラーでも動くように Caching を足した（rails/rails#52825）
- 3 アプリへの影響: RS はキャッシュも `rate_limit` も使わない。キャッシュは NullStore、`perform_caching` は false。RS の応答（スナップショット、development のヘッダー）は同じ
- 扱い: 追随
- 出典: rails/rails#50490・#52825、`actionpack-7.2.4/lib/action_controller/api.rb` の `MODULES`。Rails ガイドに該当の節はない
- コミット: RS・RP・OP（`update Rails to 7.2.4`）

### DEF-7.2-09: test 環境の Active Job のアダプターが、設定の値でも `:test` になる

- 種類: Rails の既定値（テストだけ）/ 対象: RS・RP・OP の test
- 何が変わるか: test 環境の `config.active_job.queue_adapter` が `:async` → `:test`、`ActiveJob::Base.queue_adapter` が AsyncAdapter → TestAdapter になる。development は `:async` のまま
- なぜ: 7.1 までは、設定のアダプターとテストのアダプターが、テストによって食い違っていた。7.2 で、設定がなければどのテストでも TestAdapter を使うように揃えた（rails/rails#48585）
- 3 アプリへの影響: 3 アプリはジョブを使わない（`perform_later`・`deliver_later` はなく、devise もメールをその場で送る）
- 扱い: 追随
- 出典: rails/rails#48585、`activejob-7.2.4/CHANGELOG.md` の 7.2.0 の節。Rails ガイド v7.2 の「Rails アップグレードガイド」の 2.1「active_job.queue_adapterコンフィグがすべてのテストで尊重されるようになった」
- コミット: RS・RP・OP（`update Rails to 7.2.4`）

### DEF-7.2-10: Active Storage の 2 つの既定の変化（inline で返す画像の種類、Attachment の inverse_of）

- 種類: Rails の既定値 / 対象: RS・RP・OP（Active Storage は読み込まれているが使っていない）。どちらも Active Storage の中だけの変化なので 1 項目にまとめた
- 何が変わるか: `config.active_storage.content_types_allowed_inline` の先頭に `image/webp`・`image/avif` が増える（rails/rails#50265）。`ActiveStorage::Attachment#blob` に `inverse_of: :attachments` が付く（rails/rails#50800）
- なぜ: 新しい画像の形式をブラウザでそのまま表示できるようにした。Active Record の inverse の不具合を直す前に、それに頼っていた Active Storage の関連を直した
- 3 アプリへの影響: Active Storage のテーブルも添付もない（DEF-7.1-18 でマイグレーションを採用していない）
- 扱い: 追随
- 出典: rails/rails#50265・#50800、`activestorage-7.2.4/lib/active_storage/engine.rb`・`activestorage-7.2.4/app/models/active_storage/attachment.rb`。Rails ガイドに該当の節はない
- コミット: RS・RP・OP（`update Rails to 7.2.4`）
