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
| DEF-7.2-11 | `config/application.rb` の `%w(assets tasks)` → `%w[assets tasks]` | Rails の雛形 | RS・OP | 追随 |
| DEF-7.2-12 | development で、ビューにファイル名の注釈を付ける | Rails の雛形 | 3 アプリ（development） | 追随 |
| DEF-7.2-13 | メーラーの `default_url_options` を development・test に書く | Rails の雛形 | 3 アプリ | 追随 |
| DEF-7.2-14 | test.rb から `config.public_file_server.enabled = true` を消す | Rails の雛形 | 3 アプリ（test） | 追随 |
| DEF-7.2-15 | 環境のファイルのコメントと書き方 | Rails の雛形 | 3 アプリ | 追随 |
| DEF-7.2-16 | `filter_parameter_logging.rb` に `:email` が増える | Rails の雛形 | 3 アプリ | 追随 |
| DEF-7.2-17 | production.rb の雛形 | Rails の雛形 | 3 アプリ（production） | 追随 |
| DEF-7.2-18 | `config/puma.rb` の雛形（port は残す） | Rails の雛形 | 3 アプリ | 追随（port は残す） |
| DEF-7.2-19 | `bin/setup` の `APP_NAME` と puma-dev のコメント | Rails の雛形 | 3 アプリ | 追随 |
| DEF-7.2-20 | `bin/rubocop`・`bin/brakeman` | Rails の雛形 | 3 アプリ | 採用しない |
| DEF-7.2-21 | `public/406-unsupported-browser.html`・`icon.png`・`icon.svg` | Rails の雛形 | RP・OP | 採用しない |
| DEF-7.2-22 | Active Job の enqueue を、コミットの後に遅らせるかをアダプターに任せる | Rails の既定値（`load_defaults 7.2`） | 3 アプリ | 追随 |
| DEF-7.2-23 | Active Storage が WebP を画像として扱う | Rails の既定値（`load_defaults 7.2`） | 3 アプリ | 追随 |
| DEF-7.2-24 | PostgreSQL のアダプターが、手で書いたクエリの日付を Date にする | Rails の既定値（`load_defaults 7.2`） | 3 アプリ | 追随 |
| DEF-7.2-25 | マイグレーションのファイル名のタイムスタンプを検証する | Rails の既定値（`load_defaults 7.2`） | 3 アプリ | 追随 |
| DEF-7.2-26 | YJIT を有効にする | Rails の既定値（`load_defaults 7.2`） | 3 アプリ | 追随 |

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

## `app:update` の雛形（rails-app-update）

3 アプリで `yes a | bin/rails app:update`（Rails 7.2.4）を流し、`scripts/restore-app-config` で独自設定を戻した後の差分。RP の `config/application.rb` の `autoload_lib_once` と inflector（DEF-7.1-10）と、3 アプリの `config/puma.rb` の `port` は、道具の一覧になく雛形に上書きされたので、人間に確かめて戻し、道具の一覧に足した（LOG.md の Step 5）。`new_framework_defaults_7_2.rb` は、すべてコメントのまま足し、rails-defaults で扱う。`active_storage:update` のマイグレーション 3 本（RS）は、DEF-7.0-14 のとおり消した。差分を当てた状態で、3 アプリの検査と E2E が通り、応答と E2E のスナップショット、警告、development だけのヘッダーは変わらなかった。設定の値で変わったのは DEF-7.2-12・13・16 の値だけ。

### DEF-7.2-11: `config/application.rb` の `%w(assets tasks)` → `%w[assets tasks]`

- 種類: Rails の雛形 / 対象: RS・OP（RP は `autoload_lib_once` の行を残すので HEAD のまま）
- 何が変わるか: `config.autoload_lib(ignore: %w(assets tasks))` の配列の書き方が `%w[assets tasks]` になる
- なぜ: 新しいアプリに rubocop-rails-omakase を入れたのに合わせて、雛形を `%w[]` の書き方にした（rails/rails#50486）
- 3 アプリへの影響: 書き方だけ
- 扱い: 追随
- 出典: rails/rails#50486、`railties-7.2.4/lib/rails/generators/rails/app/templates/config/application.rb.tt`。Rails ガイドに該当の節はない
- コミット: RS・OP（`apply the Rails 7.2 app:update templates`）

### DEF-7.2-12: development で、ビューにファイル名の注釈を付ける

- 種類: Rails の雛形 / 対象: 3 アプリの development（ビューを描くのは RP・OP）
- 何が変わるか: `config.action_view.annotate_rendered_view_with_filenames = true` が有効になり、development の HTML に `<!-- BEGIN app/views/... -->`・`<!-- END ... -->` のコメントが入る（OP のログイン画面で 6 個、RP のトップで 4 個）。最初のコメントは `<!DOCTYPE html>` の前に入る
- なぜ: 開発中に、どのテンプレートが描いたかを分かりやすくするため、新しいアプリの development で既定にした（rails/rails#50436）
- 3 アプリへの影響: 画面に描かれる文字は同じで、HTML のコメントが増えるだけ。E2E（development で動く）は通った。DOCTYPE の前のコメントは、HTML の仕様では標準モードの判定を変えない（WHATWG HTML の「The "initial" insertion mode」）。test・本番では無効
- 扱い: 追随
- 出典: rails/rails#50436、Rails ガイド v7.2 の「Rails アプリケーションを設定する」の `config.action_view.annotate_rendered_view_with_filenames` の項
- コミット: RS・RP・OP（`apply the Rails 7.2 app:update templates`）

### DEF-7.2-13: メーラーの `default_url_options` を development・test に書く

- 種類: Rails の雛形 / 対象: RS・RP・OP
- 何が変わるか: development に `config.action_mailer.default_url_options = { host: "localhost", port: 3000 }`、test に `{ host: "www.example.com" }` が入る
- なぜ: メールの中で URL を作ると host がなくて落ちていたので、雛形に書くようにした（rails/rails#51191）
- 3 アプリへの影響: 3 アプリともメールを送らない（OP の devise は `database_authenticatable`・`registerable`・`validatable` だけ）。port 3000 はアプリのポートと違うが、使われない
- 扱い: 追随（雛形のまま）
- 出典: rails/rails#51191。Rails ガイドに該当の節はない
- コミット: RS・RP・OP（`apply the Rails 7.2 app:update templates`）

### DEF-7.2-14: test.rb から `config.public_file_server.enabled = true` を消す

- 種類: Rails の雛形 / 対象: 3 アプリの test
- 何が変わるか: test.rb の `config.public_file_server.enabled = true` の行がなくなる
- なぜ: `public_file_server.enabled` の既定が true になったので、雛形に書かなくなった（rails/rails#49851・#49852）
- 3 アプリへの影響: 設定の値は true のまま（`scripts/compare-config` で確かめた）
- 扱い: 追随
- 出典: rails/rails#49851・#49852。Rails ガイドに該当の節はない
- コミット: RS・RP・OP（`apply the Rails 7.2 app:update templates`）

### DEF-7.2-15: 環境のファイルのコメントと書き方

- 種類: Rails の雛形 / 対象: 3 アプリの development・test
- 何が変わるか: コメントの文末に句点を付けた（rails/rails#51677）。`action_mailer.perform_caching` に説明のコメントを足した（#52215）。`public_file_server.headers` を 1 行にした。development に `apply_rubocop_autocorrect_after_generate!` のコメントの行を足した（#50506）。空行を 1 つ消した
- 3 アプリへの影響: 書き方とコメントだけ
- 扱い: 追随
- 出典: rails/rails#51677・#52215・#50506。Rails ガイドに該当の節はない
- コミット: RS・RP・OP（`apply the Rails 7.2 app:update templates`）

### DEF-7.2-16: `filter_parameter_logging.rb` に `:email` が増える

- 種類: Rails の雛形 / 対象: RS・RP・OP
- 何が変わるか: 伏せる対象に `:email` が加わる（`:passw` の次）。アプリが足した `:code` とコメントは、道具で戻した
- なぜ: メールアドレスも個人情報として、既定で伏せるため（rails/rails#49600）
- 3 アプリへの影響: ログのパラメーターと `ActiveRecord::Base.filter_attributes`（`inspect` の表示）で、`email` を含む名前の値が `[FILTERED]` になる（OP のログインの `user[email]`、RP の `OpUser#email` など）。応答と DB は変わらない（PLAN.md の 3 章の 2 の境目 7）
- 扱い: 追随
- 出典: rails/rails#49600。Rails ガイドに該当の節はない
- コミット: RS・RP・OP（`apply the Rails 7.2 app:update templates`）

### DEF-7.2-17: production.rb の雛形

- 種類: Rails の雛形 / 対象: 3 アプリの production（動作保証の外。雛形に追従するだけ）
- 何が変わるか: `/up` を `force_ssl` のリダイレクトから外す例のコメント（rails/rails#51680）、`action_mailer.perform_caching` のコメント、`config.active_record.attributes_for_inspect = [ :id ]`（#52801）が入る
- 扱い: 追随
- 出典: rails/rails#51680・#52801。Rails ガイドに該当の節はない
- コミット: RS・RP・OP（`apply the Rails 7.2 app:update templates`）

### DEF-7.2-18: `config/puma.rb` の雛形（port は残す）

- 種類: Rails の雛形 / 対象: RS・RP・OP
- 何が変わるか: コメントを書き直し、threads の既定を 5 → 3（`RAILS_MAX_THREADS` で変えられる）にした。development の `worker_timeout 3600`、`environment`、`pidfile` の既定（`tmp/pids/server.pid`）の行を消し、pidfile は `PIDFILE` があるときだけ書く。`port` は、アプリの値（3782・3781・3780）を雛形の書き方（`ENV.fetch("PORT", 3780)`）にし、理由のコメントを付けて残した
- なぜ: Puma の既定の設定を、平均的な Rails アプリに合わせて見直した（rails/rails#50669。threads の 3 も含む）。production では pidfile を作らない（#50644）。development の pid は Rails が渡すので、雛形から消した（commit 57a69167f0）
- 3 アプリへの影響: development のサーバーのスレッドが 5 → 3 になる。応答の中身は変わらない。`worker_timeout` は workers を使うときだけ効く（使っていない）。環境は `rails s` が渡す。pid は `rails s` が development で `tmp/pids/server.pid` を渡し（`railties-7.2.4/lib/rails/commands/server/server_command.rb` の `pid`）、E2E は `-P tmp/pids/e2e_server.pid` を付ける。port は、`-p` を付けない `rails s`（README）で使われる（同ファイルの `user_supplied_options` と `puma-8.0.2/lib/rack/handler/puma.rb`）ので、雛形の 3000 にすると URL が変わる（業務的な挙動）。残した
- 扱い: 追随（port は残す）
- 出典: rails/rails#50669・#50644、上の 2 つのソース。Rails ガイドに該当の節はない
- コミット: RS・RP・OP（`apply the Rails 7.2 app:update templates`）

### DEF-7.2-19: `bin/setup` の `APP_NAME` と puma-dev のコメント

- 種類: Rails の雛形 / 対象: RS・RP・OP
- 何が変わるか: `APP_NAME` の定数と、puma-dev の設定のコメントアウトされた例が入る。`# path to your application root.` のコメントがなくなる
- なぜ: puma-dev の設定を提案するため（rails/rails#51088・#51273）
- 3 アプリへの影響: コメントアウトされた例と定数だけで、`bin/setup` の処理は同じ
- 扱い: 追随
- 出典: rails/rails#51088・#51273。Rails ガイドに該当の節はない
- コミット: RS・RP・OP（`apply the Rails 7.2 app:update templates`）

### DEF-7.2-20: `bin/rubocop`・`bin/brakeman`

- 種類: Rails の雛形（新しいファイル）/ 対象: RS・RP・OP
- 何が変わるか: Gemfile に rubocop・brakeman があるので、`app:update` が 2 つの binstub を作る（`railties-7.2.4/lib/rails/commands/app/update_command.rb`）
- なぜ: 新しいアプリに rubocop-rails-omakase と brakeman を入れた（rails/rails#50486・#50507）
- 3 アプリへの影響: 採用しないので、ない
- 扱い: 採用しない（作られたファイルを消した）。`scripts/check-apps` と CI は `bundle exec rubocop`・`bundle exec brakeman` で流していて、使う場所がない。`bin/brakeman` は `--ensure-latest` を付け、最新でない brakeman では失敗するので、公開から 2 週間待つ決まりと食い違う。使わない入口を足さない（PLAN.md の 3 章の 2 の境目 5）。次の `app:update` でもまた作られる
- 出典: rails/rails#50486・#50507
- コミット: なし

### DEF-7.2-21: `public/406-unsupported-browser.html`・`icon.png`・`icon.svg`

- 種類: Rails の雛形（新しいファイル）/ 対象: RP・OP（RS は API なので作られない）
- 何が変わるか: `app:update` が 3 つのファイルを作る
- なぜ: 406 のページは、`allow_browser` で古いブラウザを止めたときに返す（rails/rails#51545）。アイコンは、新しいアプリのレイアウトと PWA が使う（#50526）
- 3 アプリへの影響: RP・OP は `allow_browser` を使わず、レイアウトもアイコンを参照しない
- 扱い: 採用しない（使っていない機能のファイル。境目 5。作られたファイルを消した）
- 出典: rails/rails#51545・#50526
- コミット: なし

## `load_defaults 7.2`（`new_framework_defaults_7_2.rb`）

`new_framework_defaults_7_2.rb` の 5 項目を、グループごとに有効にした（グループと順番は人間が決めた: 1 使っていない機能 → 2 マイグレーション → 3 YJIT）。各グループで、前後に `scripts/compare-config` で 3 アプリの test・development の値を書き出して比べた。設定しないと書き出しに出ない値は、前の書き出しの前に `scripts/lib/dump_config.rb` に足した（`70d77d1`）。

### DEF-7.2-22: Active Job の enqueue を、コミットの後に遅らせるかをアダプターに任せる

- 種類: Rails の既定値（`load_defaults 7.2`。グループ 1）/ 対象: RS・RP・OP
- 何が変わるか: `config.active_job.enqueue_after_transaction_commit = :default`。`perform_later` を Active Record のトランザクションの中で呼んだとき、コミットの後まで遅らせるかを、キューのアダプターが決める。設定の値の比較: `ActiveJob::Base.enqueue_after_transaction_commit` が `:never` → `:default`（3 アプリ・test と development）
- なぜ: コミットの前にジョブが動き、まだ保存されていないレコードを読めずに失敗するのを防ぐため（rails/rails#51426）
- 3 アプリへの影響: ジョブを使わない（`perform_later`・`deliver_later` はない）。検査と E2E は通り、スナップショットの差分はない
- 扱い: 追随
- 出典: rails/rails#51426、Rails ガイド v7.2 の「Rails アプリケーションを設定する」の 3.15.5「config.active_job.enqueue_after_transaction_commit」と 3.1.1「ターゲットバージョン7.2のデフォルト値」
- コミット: RS・RP・OP（`enable the unused Rails 7.2 framework defaults`）

### DEF-7.2-23: Active Storage が WebP を画像として扱う

- 種類: Rails の既定値（`load_defaults 7.2`。グループ 1）/ 対象: RS・RP・OP
- 何が変わるか: `config.active_storage.web_image_content_types` に `image/webp` が加わり、WebP の変換の結果を PNG にせず WebP のまま返す。設定の値の比較: `ActiveStorage.web_image_content_types` に `image/webp` が増えた（3 アプリ・test と development）
- なぜ: ブラウザが広く WebP に対応したため（`activestorage-7.2.4/CHANGELOG.md` の「Add `image/webp` to `config.active_storage.web_image_content_types` when `load_defaults "7.2"` is set.」。rails/rails の commit f3e3f82e7d）
- 3 アプリへの影響: Active Storage を使わない（DEF-7.1-18）
- 扱い: 追随
- 出典: 上の CHANGELOG、Rails ガイド v7.2 の「Rails アプリケーションを設定する」の 3.17.6「config.active_storage.web_image_content_types」
- コミット: RS・RP・OP（`enable the unused Rails 7.2 framework defaults`）

### DEF-7.2-24: PostgreSQL のアダプターが、手で書いたクエリの日付を Date にする

- 種類: Rails の既定値（`load_defaults 7.2`。グループ 1）/ 対象: RS・RP・OP
- 何が変わるか: `config.active_record.postgresql_adapter_decode_dates = true`。PostgreSQL の `select_value("select '2024-01-01'::date")` が String ではなく Date を返す。設定の値の比較: config の値だけ（pg がなく、アダプターを読めない）
- なぜ: 手で書いたクエリでも日付を Ruby の型にするため（rails/rails#51763）
- 3 アプリへの影響: SQLite で、PostgreSQL のアダプターを読み込まない
- 扱い: 追随
- 出典: rails/rails#51763、Rails ガイド v7.2 の「Rails アプリケーションを設定する」の 3.8.55「config.active_record.postgresql_adapter_decode_dates」
- コミット: RS・RP・OP（`enable the unused Rails 7.2 framework defaults`）

### DEF-7.2-25: マイグレーションのファイル名のタイムスタンプを検証する

- 種類: Rails の既定値（`load_defaults 7.2`。グループ 2）/ 対象: RS・RP・OP（マイグレーションがあるのは RP・OP）
- 何が変わるか: `config.active_record.validate_migration_timestamps = true`。マイグレーションのファイルを読むとき（`db:migrate`、development の未実行のマイグレーションの検査、`db:migrate:status`）に、ファイル名のタイムスタンプが今（UTC）より 1 日以上先なら `ActiveRecord::InvalidMigrationTimestampError` になる（`timestamped_migrations` が有効なときだけ。`activerecord-7.2.4/lib/active_record/migration.rb` の `migrations`・`migrations_status`・`valid_migration_timestamp?`）。設定の値の比較: `ActiveRecord.validate_migration_timestamps` が false → true（3 アプリ・test と development）
- なぜ: 先の日付のマイグレーションがあると、後から作ったマイグレーションの順番が狂うのを防ぐため（rails/rails#50400）
- 3 アプリへの影響: RP の 2 本（2021-08-13）と OP の 5 本（最も新しいのは `20261011134937`）は、どれも今より前の日付。RS にはマイグレーションがない。E2E（development のサーバーは要求のたびに未実行のマイグレーションを検査する。起動で `db:drop` → `db:setup`）と、E2E 用の DB での RP・OP の `db:migrate:status`・`db:migrate`（OP は注釈の hook も）が通った
- 扱い: 追随
- 出典: rails/rails#50400、Rails ガイド v7.2 の「Rails アプリケーションを設定する」の 3.8.14「config.active_record.validate_migration_timestamps」
- コミット: RS・RP・OP（`validate migration timestamps`）
- 補足: 確かめるために流した `db:migrate` が schema.rb を書き出し、OP は見出しが `Schema[7.1]` → `Schema[7.2]` に、RP は Rails 6.1 の形 → 7.2 の形（`Schema[7.2]`、datetime の `precision: 6` を省く、空行）に書き換わった。この設定の変化ではない（DEF-7.1-51 と同じ書き出しの仕組み）ので戻した。次に RP・OP でマイグレーションを流すと、同じ差分が出る

### DEF-7.2-26: YJIT を有効にする

- 種類: Rails の既定値（`load_defaults 7.2`。グループ 3）/ 対象: RS・RP・OP（development・test。E2E と手動確認のサーバーも development）
- 何が変わるか: `config.yjit = true`。Rails の起動の最後（`Rails::Application::Finisher` の `enable_yjit`）で `RubyVM::YJIT.enable` が呼ばれる（Ruby 3.3 からの、実行の途中で有効にする方法）。`RubyVM::YJIT.enable` がない Ruby では何もしない（`railties-7.2.4/lib/rails/application/finisher.rb`）。設定の値の比較: `config.yjit` と `RubyVM::YJIT.enabled?` が false → true（3 アプリ・test と development）
- なぜ: Ruby 3.3 の YJIT は Rails アプリで大きな性能の改善があるので、既定で有効にした（rails/rails#49947・#51894）。メモリの限られた環境では false にする（雛形のコメント）
- 3 アプリへの影響: 手元の Ruby 3.3.12 は YJIT 付きでビルドされている（`RbConfig::CONFIG["YJIT_SUPPORT"]` が yes）。検査と E2E の件数、スナップショット、警告、development だけのヘッダーは前後で同じで、`scripts/check-console` で `rails c` も動いた。実行の速さとメモリの使い方だけが変わる。CI（setup-ruby のビルド済みの Ruby）で YJIT が使えるかは、push の後に確かめる（使えなければ Rails が飛ばす）
- 扱い: 追随
- 出典: rails/rails#49947・#51894、`railties-7.2.4/lib/rails/application/finisher.rb`、Rails ガイド v7.2 の「Rails アプリケーションを設定する」の 3.2.62「config.yjit」
- コミット: RS・RP・OP（`enable YJIT`）
