# Rails 7.0 の既定値への追随

- 版: Rails 6.1.7.10 → 7.0.10（Ruby 3.1.7）
- Step: 1（ブランチ `upgrade/step1-rails70`）/ PR: （PR 作成後に記入）
- 記録のルールは [README.md](README.md)

## 一覧

| ID | 項目 | 種類 | 対象 | 扱い |
|---|---|---|---|---|
| DEF-7.0-01 | 生成するファイルの引用符が二重引用符になる | `app:update` の雛形 | 3 アプリ | 追随 |
| DEF-7.0-02 | RS の `config/application.rb` が `require "rails/all"` になる | `app:update` の雛形 | RS | 追随 |
| DEF-7.0-03 | `# require "sprockets/railtie"` の行が消える | `app:update` の雛形 | RP・OP | 追随 |
| DEF-7.0-04 | development の `config.server_timing = true` | `app:update` の雛形 | 3 アプリ | 追随 |
| DEF-7.0-05 | development の `config.file_watcher`（EventedFileUpdateChecker）が消える | `app:update` の雛形 | 3 アプリ | 追随 |
| DEF-7.0-06 | listen を Gemfile から外す | Gemfile の雛形 | 3 アプリ | 追随 |
| DEF-7.0-07 | test の `config.cache_classes = true` | `app:update` の雛形 | 3 アプリ | 追随 |
| DEF-7.0-08 | test の `config.eager_load = ENV["CI"].present?` | `app:update` の雛形 | 3 アプリ | 追随 |
| DEF-7.0-09 | production の `report_deprecations` と、DB の切り替えのコメント | `app:update` の雛形 | 3 アプリ | 追随 |
| DEF-7.0-10 | `filter_parameter_logging.rb` の先頭のコメント | `app:update` の雛形 | 3 アプリ | 追随（独自の部分は残す） |
| DEF-7.0-11 | `content_security_policy.rb` のコメントの例 | `app:update` の雛形 | RP・OP | 追随 |
| DEF-7.0-12 | `config/initializers/new_framework_defaults_7_0.rb` | `app:update` の雛形 | 3 アプリ | 追随 |
| DEF-7.0-13 | `db/schema.rb` の `ActiveRecord::Schema[6.1]` | `app:update` | RP・OP | 追随 |
| DEF-7.0-14 | Active Storage のマイグレーション | `app:update`（`active_storage:update`） | 3 アプリ | 採用しない |
| DEF-7.0-15 | `stylesheet_link_tag` の `<link>` の属性の並び | Rails のヘルパーの出力 | RP・OP | 追随 |
| DEF-7.0-16 | `action_dispatch.cookies_serializer = :json` | `load_defaults`（グループ 1） | 3 アプリ | 追随 |
| DEF-7.0-17 | `action_controller.wrap_parameters_by_default = true` | `load_defaults`（グループ 1） | 3 アプリ | 追随 |
| DEF-7.0-18 | `active_support.remove_deprecated_time_with_zone_name = true` | `load_defaults`（グループ 1） | 3 アプリ | 追随 |
| DEF-7.0-19 | `active_support.use_rfc4122_namespaced_uuids = true` | `load_defaults`（グループ 1） | 3 アプリ | 追随 |
| DEF-7.0-20 | `action_mailer.smtp_timeout = 5` | `load_defaults`（グループ 1） | 3 アプリ | 追随 |
| DEF-7.0-21 | `active_storage.video_preview_arguments` | `load_defaults`（グループ 1） | 3 アプリ | 追随 |
| DEF-7.0-22 | `active_storage.variant_processor = :vips` | `load_defaults`（グループ 1） | 3 アプリ | 追随 |
| DEF-7.0-23 | `active_storage.multiple_file_field_include_hidden = true` | `load_defaults`（グループ 1） | 3 アプリ | 追随 |
| DEF-7.0-24 | `action_dispatch.return_only_request_media_type_on_content_type = false` | `load_defaults`（グループ 1） | 3 アプリ | 追随 |
| DEF-7.0-25 | `active_record.automatic_scope_inversing = true` | `load_defaults`（グループ 1） | 3 アプリ | 追随 |
| DEF-7.0-26 | `active_support.executor_around_test_case = true` | `load_defaults`（グループ 2） | 3 アプリ | 追随 |
| DEF-7.0-27 | `active_record.verify_foreign_keys_for_fixtures = true` | `load_defaults`（グループ 2） | 3 アプリ | 追随 |
| DEF-7.0-28 | `active_record.partial_inserts = false` | `load_defaults`（グループ 3） | 3 アプリ | 追随 |
| DEF-7.0-29 | `active_support.hash_digest_class = OpenSSL::Digest::SHA256` | `load_defaults`（グループ 3） | 3 アプリ | 追随 |
| DEF-7.0-30 | `active_support.disable_to_s_conversion = true` | `load_defaults`（グループ 3。`config/application.rb`） | 3 アプリ | 追随 |
| DEF-7.0-31 | `active_support.cache_format_version = 7.0` | `load_defaults`（グループ 3。`config/application.rb`） | 3 アプリ | 追随 |
| DEF-7.0-32 | `action_controller.raise_on_open_redirects = true` | `load_defaults`（グループ 4） | 3 アプリ | 追随 |
| DEF-7.0-33 | `action_dispatch.default_headers`（`X-XSS-Protection: 0`） | `load_defaults`（グループ 5） | 3 アプリ | 追随 |
| DEF-7.0-34 | `action_view.button_to_generates_button_tag = true` | `load_defaults`（グループ 6） | 3 アプリ | 追随 |
| DEF-7.0-35 | `action_view.apply_stylesheet_media_default = false` | `load_defaults`（グループ 7） | 3 アプリ | 追随 |
| DEF-7.0-36 | `active_support.key_generator_hash_digest_class = OpenSSL::Digest::SHA256` | `load_defaults`（グループ 8） | 3 アプリ | 追随 |

`load_defaults` の設定は、`new_framework_defaults_7_0.rb` で 1 グループずつ有効にした（グループの順は [PLAN.md](../PLAN.md) の Step 1）。

## `app:update` の雛形

### DEF-7.0-01: 生成するファイルの引用符が二重引用符になる

- 種類: `app:update` の雛形 / 対象: 3 アプリ
- 何が変わるか: `bin/rails`・`bin/setup`・`config/boot.rb`・各環境のファイル・`inflections.rb`・`cors.rb`（RS）などの文字列が `'` から `"` になる
- なぜ: Rails 7.0 で、生成するファイルの引用符を二重引用符にそろえた
- 3 アプリへの影響: 文字列の書き方だけで、動作は同じ
- 扱い: 追随
- 出典: [rails/rails#41080](https://github.com/rails/rails/pull/41080)、[rails/rails#41733](https://github.com/rails/rails/pull/41733)。Rails ガイドに該当の節はない
- コミット: RS `e363c55`、RP `8ca0c8c`、OP `8be19a1`（`apply rails app:update for Rails 7.0`）

### DEF-7.0-02: RS の `config/application.rb` が `require "rails/all"` になる

- 種類: `app:update` の雛形 / 対象: RS
- 何が変わるか: フレームワークごとの `require` が `require "rails/all"` 1 行になる
- なぜ: 6.1 では Sprockets も `rails/all` の一部だったので、Sprockets を外した RS は個別の require になっていた。7.0 で Sprockets が `rails/all` から外れ、`railties-7.0.10/lib/rails/generators/app_base.rb` の `include_all_railties?` から `:skip_sprockets` がなくなったので、RS は「すべてのフレームワークを使う」扱いになった
- 3 アプリへの影響: `railties-7.0.10/lib/rails/all.rb` の一覧は、今の RS の require と同じフレームワーク（`active_model/railtie` は `active_record/railtie` が読み込む）。`bin/rails runner` で前後を比べ、railtie の顔ぶれとミドルウェアの並びは同じで、Active Job・Global ID・Action Cable の initializer が走る順番だけが変わった。minitest・E2E・応答の比較は同じ
- 扱い: 追随
- 出典: [rails/rails#43261](https://github.com/rails/rails/pull/43261)。Rails ガイドに該当の節はない（関連: [アップグレードガイド v7.0](https://railsguides.jp/v7.0/upgrading_ruby_on_rails.html)「2.3 Sprocketsへの依存がオプショナルになった」）
- コミット: RS `e363c55`

### DEF-7.0-03: `# require "sprockets/railtie"` の行が消える

- 種類: `app:update` の雛形 / 対象: RP・OP
- 何が変わるか: `config/application.rb` のコメントアウトされた `# require "sprockets/railtie"` の行がなくなる
- なぜ: 7.0 で Sprockets が任意の依存になり、雛形のフレームワークの一覧から外れた
- 3 アプリへの影響: コメントの行なので動作は同じ。3 アプリとも Sprockets を読み込んでいない（sprockets-rails を Gemfile に足さなかった理由は PLAN.md の Step 1）
- 扱い: 追随
- 出典: [rails/rails#43261](https://github.com/rails/rails/pull/43261)、[アップグレードガイド v7.0](https://railsguides.jp/v7.0/upgrading_ruby_on_rails.html)「2.3 Sprocketsへの依存がオプショナルになった」、[7.0 リリースノート](https://railsguides.jp/v7.0/7_0_release_notes.html)「3.3 主な変更点」（Railties）
- コミット: RP `8ca0c8c`、OP `8be19a1`

### DEF-7.0-04: development の `config.server_timing = true`

- 種類: `app:update` の雛形 / 対象: 3 アプリ
- 何が変わるか: development でミドルウェア `ActionDispatch::ServerTiming` が積まれ（`railties-7.0.10/lib/rails/application/default_middleware_stack.rb`）、応答に `Server-Timing` ヘッダーが付く。リクエストの間の `ActiveSupport::Notifications` のイベント（`sql.active_record` など）の合計時間を、イベント名ごとに出す
- なぜ: Rails 7.0 で Server Timing のミドルウェアが入り、新しいアプリでは development だけで有効にするようになった。開発中に、サーバー側の処理時間の内訳をブラウザの開発者ツールで見るため
- 3 アプリへの影響: test 環境には出ないので、minitest と応答の比較は同じ。E2E と手動確認は development で動くのでヘッダーが付くが、E2E はヘッダーを見ていない
- 扱い: 追随（当初は「アップグレードに必要ないので採用しない」案も検討したが、Rails の既定値には追随すると決めた。PLAN.md の 3 章の 2）
- 出典: [rails/rails#36289](https://github.com/rails/rails/pull/36289)、[W3C Server Timing](https://www.w3.org/TR/server-timing/)。v7.0 版の設定ガイドには項目がないので、最新版の [Rails アプリケーションを設定する](https://railsguides.jp/configuring.html)「`config.server_timing`」
- コミット: RS `e363c55`、RP `8ca0c8c`、OP `8be19a1`

### DEF-7.0-05: development の `config.file_watcher`（EventedFileUpdateChecker）が消える

- 種類: `app:update` の雛形 / 対象: 3 アプリ
- 何が変わるか: `config.file_watcher = ActiveSupport::EventedFileUpdateChecker` の行がなくなり、development の変更の検知が既定の `ActiveSupport::FileUpdateChecker`（リクエストのたびにファイルの更新時刻を見る）になる
- なぜ: Rails 7.0 は、listen を使うファイル監視を既定で設定しなくなった。PR の説明では、SSD の今のコンピューターでは、イベント駆動の監視による速さの差がほとんどないため
- 3 アプリへの影響: `bin/rails runner` で `config.file_watcher` が `ActiveSupport::FileUpdateChecker` になったことを確かめた。RS で `app/controllers/apples_controller.rb` の更新時刻だけを変えると、再読み込みの検知が `false` → `true` になった。コードを変えると次のリクエストで反映される点は同じ。Step 0-b から出ていた finalizer の警告（`ThreadError: can't be called from trap context`）の原因の処理がなくなる
- 扱い: 追随（listen は DEF-7.0-06 で外す）
- 出典: [rails/rails#42985](https://github.com/rails/rails/pull/42985)、[設定ガイド v7.0](https://railsguides.jp/v7.0/configuring.html)「3.2.20 `config.file_watcher`」。警告は LOG.md の Step 0-b「遭遇した問題」・Step 0-f-1「listen の finalizer の警告」、[guard/listen#565](https://github.com/guard/listen/issues/565)
- コミット: RS `e363c55`、RP `8ca0c8c`、OP `8be19a1`

### DEF-7.0-06: listen を Gemfile から外す

- 種類: Gemfile の雛形 / 対象: 3 アプリ
- 何が変わるか: development グループの `gem 'listen', '~> 3.3'` を外す（RS は development グループごと）。lock から listen 3.10.1 と、その依存の rb-fsevent 0.11.0・rb-inotify 0.10.1・ffi 1.15.3 が消える。ほかの gem の版は変わらない
- なぜ: DEF-7.0-05 で、listen を使う唯一の設定がなくなった（`git grep` で確認）。Rails 7.0 の Gemfile の雛形にも listen はない
- 3 アプリへの影響: minitest・RuboCop・E2E は同じ。`Listen` 定数は読み込まれない。CI で ffi 1.15.3 をソースからビルドしていた（LOG.md の Step 0-g「CI の結果」）のがなくなる。無視リストに、外れる gem の advisory はない
- 扱い: 追随
- 出典: [rails/rails#42985](https://github.com/rails/rails/pull/42985)
- コミット: RS `b50e055`、RP `93f3bfa`、OP `c740f47`（`remove listen`）

### DEF-7.0-07: test の `config.cache_classes = true`

- 種類: `app:update` の雛形 / 対象: 3 アプリ
- 何が変わるか: test.rb の `config.cache_classes` が `false` → `true` になり、`config.action_view.cache_template_loading = true` の行が消える（`cache_classes` が `true` なら同じ値になる）
- なぜ: 6.1 の雛形は、Spring で同じプロセスを使い回すことを前提に `false` にしていた。Rails 7.0 で Spring が既定から外れたので `true` に戻った（雛形のコメントも「Spring を使うなら false にする」）
- 3 アプリへの影響: テストの実行中はコードを読み直さない。Spring は Step 0-f-1 で外してあるので、雛形の前提と合う。minitest は同じ件数で通った
- 扱い: 追随
- 出典: [rails/rails#42997](https://github.com/rails/rails/pull/42997)、[設定ガイド v7.0](https://railsguides.jp/v7.0/configuring.html)「3.2.6 `config.cache_classes`」、[アップグレードガイド v7.0](https://railsguides.jp/v7.0/upgrading_ruby_on_rails.html)「2.2 spring gem」
- コミット: RS `e363c55`、RP `8ca0c8c`、OP `8be19a1`

### DEF-7.0-08: test の `config.eager_load = ENV["CI"].present?`

- 種類: `app:update` の雛形 / 対象: 3 アプリ
- 何が変わるか: test.rb の `config.eager_load` が `false` → `ENV["CI"].present?` になる
- なぜ: Rails 7.0 で、CI ではアプリのコードをすべて読み込んでからテストするようにした。手元では一部のテストだけを速く流し、CI では読み込みの漏れや副作用を見つけるため
- 3 アプリへの影響: GitHub Actions は環境変数 `CI` を常に `true` にするので、CI の minitest は eager load ありになる。手元で `CI=1` を付けて 3 アプリの minitest を流し、同じ件数で通った
- 扱い: 追随
- 出典: [rails/rails#43508](https://github.com/rails/rails/pull/43508)、GitHub Docs の「[Variables reference](https://docs.github.com/en/actions/reference/workflows-and-actions/variables)」（既定の環境変数 `CI`）、[設定ガイド v7.0](https://railsguides.jp/v7.0/configuring.html)「3.2.13 `config.eager_load`」（CI で有効にする理由はガイドにない）
- コミット: RS `e363c55`、RP `8ca0c8c`、OP `8be19a1`

### DEF-7.0-09: production の `report_deprecations` と、DB の切り替えのコメント

- 種類: `app:update` の雛形 / 対象: 3 アプリ
- 何が変わるか: production.rb の `deprecation = :notify`・`disallowed_deprecation = :log`・`disallowed_deprecation_warnings = []` が `report_deprecations = false` 1 行になる。DB の接続を切り替える設定のコメントの塊（`database_selector` など）が消える
- なぜ: 前者は、本番で非推奨警告の処理そのものを止められる設定が 7.0 で入り、雛形がそれを使うようにした。後者は、DB・シャードの切り替えの設定が、新しいアプリでは `bin/rails g active_record:multi_db` で別の initializer に生成されるようになった
- 3 アプリへの影響: production だけで、動作保証の対象外
- 扱い: 追随（production.rb は雛形に追従するだけ）
- 出典: [rails/rails#42913](https://github.com/rails/rails/pull/42913)、[rails/rails#43796](https://github.com/rails/rails/pull/43796)、[設定ガイド v7.0](https://railsguides.jp/v7.0/configuring.html)「3.14.13 `config.active_support.report_deprecations`」、[複数のデータベース v7.0](https://railsguides.jp/v7.0/active_record_multiple_databases.html)「4 ロールの自動切り替えを有効にする」
- コミット: RS `e363c55`、RP `8ca0c8c`、OP `8be19a1`

### DEF-7.0-10: `filter_parameter_logging.rb` の先頭のコメント

- 種類: `app:update` の雛形 / 対象: 3 アプリ
- 何が変わるか: 先頭のコメントが、伏せる対象の書き方を `ActiveSupport::ParameterFilter` の文書へ案内する文言になる
- なぜ: Rails 側で、雛形のコメントを書き直した
- 3 アプリへの影響: コメントだけ。`app:update` で消えた、アプリが足した `:code` と日本語のコメント（Step 0-a）は戻した（定義の境目の 4・7）
- 扱い: 雛形のコメントに追随し、独自の部分は残す
- 出典: [rails/rails#44139](https://github.com/rails/rails/pull/44139)、[設定ガイド v7.0](https://railsguides.jp/v7.0/configuring.html)「3.2.21 `config.filter_parameters`」
- コミット: RS `e363c55`、RP `8ca0c8c`、OP `8be19a1`

### DEF-7.0-11: `content_security_policy.rb` のコメントの例

- 種類: `app:update` の雛形 / 対象: RP・OP
- 何が変わるか: コメントの例が、`Rails.application.configure` の中に書く形と、import map と Turbo に合う nonce の例になる
- なぜ: Rails 7.0 の既定の JavaScript（import map と Turbo）に合う CSP の例に変えた
- 3 アプリへの影響: すべてコメントで、CSP は今も設定していない
- 扱い: 追随
- 出典: [rails/rails#43227](https://github.com/rails/rails/pull/43227)、[rails/rails#42999](https://github.com/rails/rails/pull/42999)、[セキュリティガイド v7.0](https://railsguides.jp/v7.0/security.html)「9.1 Content Security Policyヘッダー」
- コミット: RP `8ca0c8c`、OP `8be19a1`

### DEF-7.0-12: `config/initializers/new_framework_defaults_7_0.rb`

- 種類: `app:update` の雛形 / 対象: 3 アプリ
- 何が変わるか: 新しい既定値をすべてコメントにした initializer が足される
- なぜ: `app:update` は、新しい既定値を 1 つずつ有効にできるよう、このファイルを足す
- 3 アプリへの影響: 足した時点ではすべてコメントで、動作は同じ
- 扱い: 追随。グループごとに有効にし、最後に `load_defaults 7.0` にして消す
- 出典: `railties-7.0.10/lib/rails/generators/rails/app/templates/config/initializers/new_framework_defaults_7_0.rb.tt`、[アップグレードガイド v7.0](https://railsguides.jp/v7.0/upgrading_ruby_on_rails.html)「1.4 アップデートタスク」「1.5 フレームワークのデフォルトを設定する」、[設定ガイド v7.0](https://railsguides.jp/v7.0/configuring.html)「3.1.1 ターゲットバージョン7.0のデフォルト値」
- コミット: RS `e363c55`、RP `8ca0c8c`、OP `8be19a1`

### DEF-7.0-13: `db/schema.rb` の `ActiveRecord::Schema[6.1]`

- 種類: `app:update`（`railties-7.0.10/lib/rails/generators/rails/app/app_generator.rb` の `db_when_updating`）/ 対象: RP・OP（RS には schema.rb がない）
- 何が変わるか: `ActiveRecord::Schema.define` が `ActiveRecord::Schema[6.1].define` になる
- なぜ: 7.0 では、版のない `ActiveRecord::Schema.define` は 7.0 の規則で読み込まれ、精度を指定していない datetime の列が新しい DB では `precision: 6` で作られる。それを防ぐため、`app:update` がその schema.rb を書いた版（6.1）を付ける
- 3 アプリへの影響: E2E の起動（`db:drop db:setup`）で作る DB の列の定義が、今と同じになる。手動確認用の DB には触れない。7.0 のまま `db:migrate` をすると `Schema[7.0]` に書き換わり、datetime の精度の差分が出る
- 扱い: 追随
- 出典: [rails/rails#44356](https://github.com/rails/rails/pull/44356)、[rails/rails#44286](https://github.com/rails/rails/pull/44286)、[アップグレードガイド v7.0](https://railsguides.jp/v7.0/upgrading_ruby_on_rails.html)「2.15 Active RecordのスキーマダンプにRailsのバージョンが含まれるようになった」
- コミット: RP `8ca0c8c`、OP `8be19a1`

### DEF-7.0-14: Active Storage のマイグレーション

- 種類: `app:update`（`update:active_storage`）/ 対象: 3 アプリ
- 何が変わるか: `db/migrate/` に `*.active_storage.rb` が 3 本（`add_service_name_to_active_storage_blobs`・`create_active_storage_variant_records`・`remove_not_null_on_active_storage_blobs_checksum`）写される
- なぜ: `app:update` は `update:active_storage` も流し、Active Storage を使うアプリ向けのマイグレーションを写す（`railties-7.0.10/lib/rails/tasks/framework.rake` の `update`、`activestorage-7.0.10/lib/tasks/activestorage.rake` の `update`）
- 3 アプリへの影響: 3 アプリとも Active Storage を使っていない（テーブルもない）。採用すると未実行のマイグレーションになり、手動確認用の DB に `db:migrate` が要る
- 扱い: 採用しない（定義の境目の 5「使っていない機能を動かし始めるもの」）。写されたファイルは消した
- 出典: [アップグレードガイド v7.0](https://railsguides.jp/v7.0/upgrading_ruby_on_rails.html)「1.4 アップデートタスク」
- コミット: なし（`app:update` のコミットに含めなかった）

## Rails のヘルパーの出力

### DEF-7.0-15: `stylesheet_link_tag` の `<link>` の属性の並び

- 種類: Rails のヘルパーの出力 / 対象: RP・OP
- 何が変わるか: `<link rel="stylesheet" media="..." href="..." />` が `<link rel="stylesheet" href="..." media="..." />` になる。RP のレイアウト（`media: 'all'` を明示）と、OP の doorkeeper のレイアウト（既定の `media="screen"`）の両方
- なぜ: Rails 7.0 で、`stylesheet_link_tag` が既定で `media="screen"` を付けないこともできるようになり（`config.action_view.apply_stylesheet_media_default`。Step 1 のグループ 7 で有効にする）、`tag_options` の最初のハッシュから `media` がなくなった。`media` は後から入るので `href` の後になる。6.1 は最初のハッシュの 2 番目に `"media" => "screen"` があり、渡した `media:` はその位置の値を上書きしていた（`actionview-6.1.7.10` と `actionview-7.0.10` の `lib/action_view/helpers/asset_tag_helper.rb` の `stylesheet_link_tag`）
- 3 アプリへの影響: 属性の値は同じで、並びだけが違う。ブラウザの解釈は同じ。Rails 7.0.10 にしたコミットで起き、応答の前後比較で見つけた
- 扱い: 追随
- 出典: [rails/rails#41215](https://github.com/rails/rails/pull/41215)、[rails/rails#41472](https://github.com/rails/rails/pull/41472)、[設定ガイド v7.0](https://railsguides.jp/v7.0/configuring.html)「3.11.19 `config.action_view.apply_stylesheet_media_default`」（並びが変わることそのものはガイドにない）
- コミット: RP `a6e2bdf`、OP `8715abf`（`update rails to 7.0.10`）

## `load_defaults`（`new_framework_defaults_7_0.rb`）

グループ 1 は、3 アプリとも該当の処理を通らないか、既に同じ値のもの。グループ 2 は、テストのときだけ効くもの。グループ 3 は、SQL や内部の処理だけが変わるもの。グループ 4 は、今のリダイレクトが対象にならないもの。グループ 5〜7 は、応答のヘッダーや HTML が変わるもの（1 つずつ有効にして、そのたびに応答を書き出して比べた）。グループ 8 は、既存の Cookie が読めなくなるもの（ブラウザで手動確認した）。どのグループも、有効にする前後で、`bin/rails runner`（test 環境）から実際の値と、関連の `inverse_of` を書き出して比べた。値を読む前に `ActionView::Base` などのクラスを読み込む（`on_load` の中で値が入る設定があるため）。

RP では、グループ 1・2 を有効にした時点で、一部の設定（DEF-7.0-24・25・27）が効かなかった。原因と対応は、すぐ下の「補足: RP で設定が効かなかった理由（フレームワークの早い読み込み）」。

### 補足: RP で設定が効かなかった理由（フレームワークの早い読み込み）

既定値への追随の項目ではないが、`new_framework_defaults_*.rb` の設定が効くかどうかに関わるので、ここに残す。

- **起きたこと**: RP だけ、`new_framework_defaults_7_0.rb` で有効にした `return_only_request_media_type_on_content_type`（DEF-7.0-24）・`automatic_scope_inversing`（DEF-7.0-25）・`verify_foreign_keys_for_fixtures`（DEF-7.0-27）・`partial_inserts`（グループ 3）の値が変わらなかった。`disable_to_s_conversion`（グループ 3）は、一時的に `load_defaults 7.0` にしても効かなかった
- **原因**: 起動の途中（`initialize!` より前）に、フレームワークのクラスが読み込まれていた。Rails は、各フレームワークの設定を `ActiveSupport.on_load` のフックや railtie の initializer で写す。クラスが既に読み込まれていると、`config/initializers` を読む前に写し終えるので、`new_framework_defaults_*.rb` の設定が黙って無視される。`disable_to_s_conversion` は、`initialize!` の最初に環境変数 `RAILS_DISABLE_DEPRECATED_TO_S_CONVERSION` を立て（`railties-7.0.10/lib/rails/application/bootstrap.rb`）、その後で読み込まれる core_ext に古い `to_s(:形式)` を読ませない仕組みなので、core_ext が先に読まれていると `load_defaults 7.0` でも効かない
  - `config/application.rb` の末尾の `ActiveRecord::SessionStore::Session.serializer = :json` が、`ActiveRecord::Base` と Active Support の core_ext を読み込んでいた。activerecord-session_store の README が「`config/application.rb` の末尾に」書く例を載せていて、RP はそれに沿っていた
  - activerecord-session_store 自身が、`Bundler.require` の時点で `ActionDispatch::Request` を読み込む（`activerecord-session_store-2.1.0/lib/action_dispatch/session/active_record_store.rb` の `require 'action_dispatch/middleware/session/abstract_store'`。2.3.0 でも同じ）
- **確かめ方**: `config/application.rb` を読み終えた時点と、`config/initializers` を読む直前（`before: :load_config_initializers` の initializer）で、`ActiveSupport` が読み込み済みとして記録している部品を書き出した。対応の前の RP は `active_record` と `action_dispatch_request` が読み込み済みで、RS・OP は `before_configuration`・`before_initialize`・`i18n` だけ
- **対応**: serializer の設定を `config/initializers/session_store.rb` に移し、`ActiveSupport.on_load(:active_record)` の中で設定するようにした（RP `77c26df`）。セッションは前と同じく JSON で保存される（`{"value":{...}}` の形を、test 環境の DB と E2E 用の DB で確かめた）。これで `ActiveRecord::Base` は起動の途中で読み込まれなくなり、DEF-7.0-25・27 は RP でもこのコミットから効く
- **残ること**: `ActionDispatch::Request` は gem が読み込むので、RP では DEF-7.0-24 が `load_defaults 7.0` にしたときに効く（`load_defaults` は `config/application.rb` の中で値を決めるので、フックがすぐ走っても新しい値が写る）。gem を直すのは epic の範囲外
- **同じ問題の報告**
  - Rails: [rails/rails#31285](https://github.com/rails/rails/issues/31285)（gem が `on_load` の外で `ActiveRecord::Base` を参照すると、`new_framework_defaults.rb` が効かない）、[rails/rails#46277](https://github.com/rails/rails/issues/46277)（`config/application.rb` で `ActiveRecord::Base` を参照すると、initializer の `verify_foreign_keys_for_fixtures` が効かない）、[rails/rails#50133](https://github.com/rails/rails/issues/50133)（同じ原因の issue のまとめ）
  - Rails の対策: [rails/rails#56201](https://github.com/rails/rails/pull/56201)「Load hook guard」（2026-02-11 に main へ。早い読み込みを警告・例外にする仕組み）。8.1.4 までのリリースには含まれていない（GitHub の比較で確かめた）
  - activerecord-session_store: [README](https://github.com/rails/activerecord-session_store#configuration)（`config/application.rb` の末尾に書く例）、[rails/activerecord-session_store#142](https://github.com/rails/activerecord-session_store/issues/142)（`ActiveSupport.on_load(:active_record)` の中で `serializer = :json` を設定する例）、[rails/activerecord-session_store#143](https://github.com/rails/activerecord-session_store/pull/143)（gem が `ActiveRecord::Base` を早く読み込まないようにした変更の続き）
  - ブログ: Arkency「[I do not blindly trust setting things in new_framework_defaults initializers anymore](https://blog.arkency.com/i-do-not-blindly-trust-setting-things-in-new-framework-defaults-initializers-anymore/)」（2025-06-10。Rails 7.1 で、gem が `ActiveRecord::Base` を早く読み込んだため `new_framework_defaults_7_1.rb` の設定が効かなかった例）
  - Rails ガイド: v7.0 版には該当の節がないので、最新版の [Rails アプリケーションを設定する](https://railsguides.jp/configuring.html)「6 読み込みフック」（`ActiveRecord::Base` などを不注意に読み込むと、Rails との暗黙の取り決めに違反する）
- **後の Step への申し送り**: `new_framework_defaults_*.rb` を有効にするたびに、上の確かめ方で、起動の途中に読み込まれる部品が増えていないかを見る。gem を上げたときも同じ

### DEF-7.0-16: `action_dispatch.cookies_serializer = :json`

- 種類: `load_defaults`（グループ 1）/ 対象: 3 アプリ
- 何が変わるか: RP・OP は既に `:json`（`config/initializers/cookies_serializer.rb`）で変わらない。RS は未設定（Marshal）→ `:json`
- なぜ: 新しいアプリの既定を、initializer のファイルではなく `load_defaults` で持つようにした。JSON は Marshal より安全
- 3 アプリへの影響: RS は API 専用で、Cookie のミドルウェアがない（`bin/rails middleware`）
- 扱い: 追随。`cookies_serializer.rb` は `load_defaults 7.0` にするときに消す
- 出典: [rails/rails#42538](https://github.com/rails/rails/pull/42538)、[設定ガイド v7.0](https://railsguides.jp/v7.0/configuring.html)「3.10.1 `config.action_dispatch.cookies_serializer`」
- コミット: （コミット後に記入）

### DEF-7.0-17: `action_controller.wrap_parameters_by_default = true`

- 種類: `load_defaults`（グループ 1）/ 対象: 3 アプリ
- 何が変わるか: 設定値が `false` → `true`。JSON の params を包む設定（`ActionController::Base._wrapper_options`・`ActionController::API._wrapper_options`）は前後とも `format: [:json]` で同じ
- なぜ: 新しいアプリで `wrap_parameters.rb` を生成しないよう、同じ処理を既定値にした
- 3 アプリへの影響: 3 アプリの `config/initializers/wrap_parameters.rb` と同じ処理なので変わらない
- 扱い: 追随。`wrap_parameters.rb` は `load_defaults 7.0` にするときに消す
- 出典: [rails/rails#43237](https://github.com/rails/rails/pull/43237)、[設定ガイド v7.0](https://railsguides.jp/v7.0/configuring.html)「3.9.19 `config.action_controller.wrap_parameters_by_default`」
- コミット: （コミット後に記入）

### DEF-7.0-18: `active_support.remove_deprecated_time_with_zone_name = true`

- 種類: `load_defaults`（グループ 1）/ 対象: 3 アプリ
- 何が変わるか: `ActiveSupport::TimeWithZone.name` の上書き（`"Time"` を返す）がなくなり、Ruby 本来の名前を返す
- なぜ: 6.1 で非推奨にした古い上書きを外す。7.1 では既定でなくなる
- 3 アプリへの影響: アプリと gem で `TimeWithZone.name` を呼ぶところはない。呼ぶと test 環境の `deprecation = :raise` で例外になる（値を書き出すスクリプトで確かめた）ので、呼ばれればテストで気づける
- 扱い: 追随
- 出典: [rails/rails#41938](https://github.com/rails/rails/pull/41938)、[設定ガイド v7.0](https://railsguides.jp/v7.0/configuring.html)「3.14.14 `config.active_support.remove_deprecated_time_with_zone_name`」
- コミット: （コミット後に記入）

### DEF-7.0-19: `active_support.use_rfc4122_namespaced_uuids = true`

- 種類: `load_defaults`（グループ 1）/ 対象: 3 アプリ
- 何が変わるか: `Digest::UUID.use_rfc4122_namespaced_uuids` が `false` → `true`
- なぜ: 文字列で名前空間を渡したときの UUID v3・v5 を RFC 4122 どおりにする
- 3 アプリへの影響: `Digest::UUID.uuid_v3`・`uuid_v5` の呼び出しはない。fixtures の id は Rails の定数の名前空間を使うので影響しない
- 扱い: 追随
- 出典: [rails/rails#37682](https://github.com/rails/rails/pull/37682)、[設定ガイド v7.0](https://railsguides.jp/v7.0/configuring.html)「3.14.16 `config.active_support.use_rfc4122_namespaced_uuids`」
- コミット: （コミット後に記入）

### DEF-7.0-20: `action_mailer.smtp_timeout = 5`

- 種類: `load_defaults`（グループ 1）/ 対象: 3 アプリ
- 何が変わるか: `ActionMailer::Base.smtp_settings` に `open_timeout: 5`・`read_timeout: 5` が入る
- なぜ: SMTP サーバーが応答しないときに、既定でいつまでも待たないようにする
- 3 アプリへの影響: メールを送るところはない（OP の devise もメールのモジュールを使っていない）
- 扱い: 追随
- 出典: コミット [rails/rails@52db7f2](https://github.com/rails/rails/commit/52db7f2ef3)（issue [rails/rails#42089](https://github.com/rails/rails/issues/42089)）、[設定ガイド v7.0](https://railsguides.jp/v7.0/configuring.html)「3.13.4 `config.action_mailer.smtp_timeout`」
- コミット: （コミット後に記入）

### DEF-7.0-21: `active_storage.video_preview_arguments`

- 種類: `load_defaults`（グループ 1）/ 対象: 3 アプリ
- 何が変わるか: 動画のプレビューを作るときの ffmpeg の引数が、最初のフレームを使うものから、場面の切り替わりを見てフレームを選ぶものになる
- なぜ: 黒いことが多い最初のフレームより、内容の分かるプレビューにするため
- 3 アプリへの影響: Active Storage を使っていない
- 扱い: 追随
- 出典: [rails/rails#42471](https://github.com/rails/rails/pull/42471)、[アップグレードガイド v7.0](https://railsguides.jp/v7.0/upgrading_ruby_on_rails.html)「2.13 ActiveStorageの動画プレビュー画像生成」、[設定ガイド v7.0](https://railsguides.jp/v7.0/configuring.html)「3.17.21 `config.active_storage.video_preview_arguments`」
- コミット: （コミット後に記入）

### DEF-7.0-22: `active_storage.variant_processor = :vips`

- 種類: `load_defaults`（グループ 1）/ 対象: 3 アプリ
- 何が変わるか: `ActiveStorage.variant_processor` が `:mini_magick` → `:vips`
- なぜ: libvips のほうが速く、メモリも少ない
- 3 アプリへの影響: 画像の変換（variant）を作るところがないので、ruby-vips も要らない
- 扱い: 追随
- 出典: [rails/rails#42744](https://github.com/rails/rails/pull/42744)、[アップグレードガイド v7.0](https://railsguides.jp/v7.0/upgrading_ruby_on_rails.html)「2.14 Active Storageのデフォルトのバリアントプロセッサが `:vips`に変更」、[設定ガイド v7.0](https://railsguides.jp/v7.0/configuring.html)「3.17.1 `config.active_storage.variant_processor`」
- コミット: （コミット後に記入）

### DEF-7.0-23: `active_storage.multiple_file_field_include_hidden = true`

- 種類: `load_defaults`（グループ 1）/ 対象: 3 アプリ
- 何が変わるか: `ActionView::Helpers::FormHelper.multiple_file_field_include_hidden` が `false` → `true`。`file_field` に `multiple: true` を付けると hidden field も出す
- なぜ: `has_many_attached` で、空のまま送ったときに「すべて外す」を伝えられるようにする
- 3 アプリへの影響: `file_field` を使う画面はない。値は `on_load(:action_view)` の中で入る（`activestorage-7.0.10/lib/active_storage/engine.rb` の `action_view.configuration`）
- 扱い: 追随
- 出典: [rails/rails#43511](https://github.com/rails/rails/pull/43511)、[設定ガイド v7.0](https://railsguides.jp/v7.0/configuring.html)「3.17.22 `config.active_storage.multiple_file_field_include_hidden`」
- コミット: （コミット後に記入）

### DEF-7.0-24: `action_dispatch.return_only_request_media_type_on_content_type = false`

- 種類: `load_defaults`（グループ 1）/ 対象: 3 アプリ
- 何が変わるか: `ActionDispatch::Request#content_type` が、メディアタイプだけでなく、Content-Type ヘッダーの値（charset など）をそのまま返す。RS・OP は `true` → `false`。RP は `load_defaults 7.0` にしたときに変わる（一時的に `load_defaults 7.0` にして確かめた。下の「補足」）
- なぜ: Rack や他のフレームワークと同じく、ヘッダーの値をそのまま返すようにする
- 3 アプリへの影響: アプリと主な gem（devise・doorkeeper・omniauth・activerecord-session_store）に `request.content_type` の呼び出しはない。doorkeeper は `media_type` を使う
- 扱い: 追随
- 出典: コミット [rails/rails@8405513](https://github.com/rails/rails/commit/8405513071)、[アップグレードガイド v7.0](https://railsguides.jp/v7.0/upgrading_ruby_on_rails.html)「2.9 `ActionDispatch::Request#content_type`が Content-Typeヘッダーをそのまま返すようになった」、[設定ガイド v7.0](https://railsguides.jp/v7.0/configuring.html)「3.10.19 `config.action_dispatch.return_only_request_media_type_on_content_type`」
- コミット: （コミット後に記入）

### DEF-7.0-25: `active_record.automatic_scope_inversing = true`

- 種類: `load_defaults`（グループ 1）/ 対象: 3 アプリ
- 何が変わるか: scope 付きの関連にも `inverse_of` を自動で推定する。RS・OP は `false` → `true`。RP はグループ 1 の時点では変わらず、`77c26df` から `true`（下の「補足」）
- なぜ: scope 付きの関連でも、同じレコードを二重に読まないようにする
- 3 アプリへの影響: 推定された `inverse_of` は、3 アプリのモデル（OP の doorkeeper のモデルを含む）で前後とも同じ。doorkeeper の scope 付きの関連は `foreign_key:` を指定していて、推定の対象外（`doorkeeper-5.7.1/lib/doorkeeper/orm/active_record/mixins/application.rb`）
- 扱い: 追随
- 出典: [rails/rails#43358](https://github.com/rails/rails/pull/43358)、[設定ガイド v7.0](https://railsguides.jp/v7.0/configuring.html)「3.8.30 `config.active_record.automatic_scope_inversing`」
- コミット: （コミット後に記入）

### DEF-7.0-26: `active_support.executor_around_test_case = true`

- 種類: `load_defaults`（グループ 2）/ 対象: 3 アプリ
- 何が変わるか: `ActiveSupport::TestCase` に include されるものが、`ActiveSupport::CurrentAttributes::TestHelper`・`ActiveSupport::ExecutionContext::TestHelper` から `ActiveSupport::Executor::TestHelper` に替わる。テストケースごとに `Rails.application.executor.wrap` で包まれ、テストの中でも Active Record のクエリキャッシュが有効になる。`ActionController::TestCase.executor_around_each_request` も `nil` → `true`
- なぜ: テストを、実際のリクエストやジョブに近い条件で動かすため。本番ではリクエストごとに executor が走ってクエリキャッシュなどが有効になるが、6.1 の既定ではテストの中で無効だった
- 3 アプリへの影響: テストのときだけで、development・production は変わらない。同じテストの中で 2 回読んだ値がキャッシュされることがあるが、今のテストは、リクエストの前後で件数などを読む書き方（RP の `assert_difference 'OpUser.count'`、OP の `Doorkeeper::AccessGrant.last` など）も含めて、すべて同じ結果で通った（書き込みのたびにキャッシュが消える）。新しくテストを書くときは、このキャッシュがある前提になる
- 扱い: 追随
- 出典: [rails/rails#43550](https://github.com/rails/rails/pull/43550)、`activesupport-7.0.10/lib/active_support/railtie.rb` の `on_load(:active_support_test_case)`、[設定ガイド v7.0](https://railsguides.jp/v7.0/configuring.html)「3.14.17 `config.active_support.executor_around_test_case`」
- コミット: （コミット後に記入）

### DEF-7.0-27: `active_record.verify_foreign_keys_for_fixtures = true`

- 種類: `load_defaults`（グループ 2）/ 対象: 3 アプリ
- 何が変わるか: fixtures を入れた後に、外部キーの制約に違反していないかを確かめ、違反があればテストを失敗させる。RS・OP は `ActiveRecord.verify_foreign_keys_for_fixtures` が `false` → `true`。RP はグループ 2 の時点では変わらず、`77c26df` から `true`（下の「補足」）
- なぜ: SQLite・PostgreSQL などは、fixtures を入れる間は外部キーの検査を止めているので、壊れた fixtures でもテストが動いてしまう。入れた後に確かめて、早く気づけるようにする
- 3 アプリへの影響: fixtures があるのは OP だけ（`oauth_applications.yml`・`users.yml`）で、違反はなく、テストは通った。RP には fixtures がない
- 扱い: 追随
- 出典: [rails/rails#42674](https://github.com/rails/rails/pull/42674)、[設定ガイド v7.0](https://railsguides.jp/v7.0/configuring.html)「3.8.35 `config.active_record.verify_foreign_keys_for_fixtures`」
- コミット: （コミット後に記入）

### DEF-7.0-28: `active_record.partial_inserts = false`

- 種類: `load_defaults`（グループ 3）/ 対象: 3 アプリ
- 何が変わるか: INSERT 文に、値を渡していない列も含めて全部の列を書く。3 アプリとも `ActiveRecord::Base.partial_inserts` が `true` → `false`
- なぜ: 列の既定値を DB から安全に外せるようにするため。部分的な INSERT では、DB の既定値に頼る列があると既定値を外せない。以前の利点（列を消すときの事故を防ぐ）は、今は `ignored_columns` で安全にできる、と PR は説明している
- 3 アプリへの影響: OP は doorkeeper の 3 つのテーブルで INSERT の列が増えた（例: `oauth_access_tokens` に `refresh_token`・`revoked_at`・`previous_refresh_token`）。test 環境でレコードを作って読み直し、保存された値が前後で同じことを確かめた（`confidential: true`・`previous_refresh_token: ""` などは、DB の既定値と同じ値が入る）。RP の `op_users`・`sessions` はもともと全部の列を渡しているので、SQL も値も同じ。RS はテーブルがない
- 扱い: 追随
- 出典: [rails/rails#42769](https://github.com/rails/rails/pull/42769)、[設定ガイド v7.0](https://railsguides.jp/v7.0/configuring.html)「3.8.16 `config.active_record.partial_inserts`」
- コミット: （コミット後に記入）

### DEF-7.0-29: `active_support.hash_digest_class = OpenSSL::Digest::SHA256`

- 種類: `load_defaults`（グループ 3）/ 対象: 3 アプリ
- 何が変わるか: `ActiveSupport::Digest` のアルゴリズムが SHA1 → SHA256
- なぜ: SHA1 が使われているところを SHA256 にそろえるため
- 3 アプリへの影響: `ActiveSupport::Digest` を使うのは、Rails 自身の `fresh_when`・`stale?` の ETag、ビューのフラグメントキャッシュの digest、`relation.cache_key`、キャッシュストアだけで、3 アプリはどれも使っていない（lock の gem にも使うものはない）。応答の ETag は `Rack::ETag` が SHA256 で計算するもの（`rack-2.2.24/lib/rack/etag.rb`）。ETag を伏せずに応答を書き出して前後を比べ、変わったのは同じ設定でも毎回変わる 4 つ（CSRF のトークンなどを本文に含む OP の応答）だけだった
- 扱い: 追随
- 出典: [rails/rails#41043](https://github.com/rails/rails/pull/41043)、[アップグレードガイド v7.0](https://railsguides.jp/v7.0/upgrading_ruby_on_rails.html)「2.11 `ActiveSupport::Digest`で用いられるメッセージダイジェストクラスがSHA256に変更」、[設定ガイド v7.0](https://railsguides.jp/v7.0/configuring.html)「3.14.6 `config.active_support.hash_digest_class`」
- コミット: （コミット後に記入）

### DEF-7.0-30: `active_support.disable_to_s_conversion = true`

- 種類: `load_defaults`（グループ 3。雛形のコメントのとおり `config/application.rb` に書く）/ 対象: 3 アプリ
- 何が変わるか: Date・Time・Numeric・Array・Range などの `to_s(:形式)` の上書きを読み込まない。3 アプリとも `1000.to_s(:delimited)` が、非推奨の警告付きで動く状態から `TypeError` になる
- なぜ: Ruby 3.1 の、文字列の式展開を速くする最適化は、`to_s` を上書きしたクラスでは効かない。Rails は `to_s(:形式)` を非推奨にして `to_fs`（`to_formatted_s`）に移し、上書きをやめられるようにした。設定は `initialize!` の最初に環境変数 `RAILS_DISABLE_DEPRECATED_TO_S_CONVERSION` を立てる形で効く（`railties-7.0.10/lib/rails/application/bootstrap.rb`）
- 3 アプリへの影響: アプリ・テスト・lock の gem に `to_s(:形式)` の呼び出しはなく、Rails 7.0.10 にした後の development のログに非推奨の警告もない。RP は `77c26df`（上の「補足」）の後なので効く
- 扱い: 追随。`load_defaults 7.0` にするときに `config/application.rb` から消す
- 出典: [rails/rails#43772](https://github.com/rails/rails/pull/43772)、[設定ガイド v7.0](https://railsguides.jp/v7.0/configuring.html)「3.14.18 `config.active_support.disable_to_s_conversion`」
- コミット: （コミット後に記入）

### DEF-7.0-31: `active_support.cache_format_version = 7.0`

- 種類: `load_defaults`（グループ 3。雛形のコメントのとおり `config/application.rb` に書く）/ 対象: 3 アプリ
- 何が変わるか: `ActiveSupport::Cache` に保存するときの形式が 7.0 の形式になる（`ActiveSupport.cache_format_version` が 6.1 → 7.0）。6.1 のアプリはこの形式を読めない
- なぜ: 以前の形式は `Entry` オブジェクトを丸ごと Marshal で保存していて、1 件ごとの無駄が大きく、内部を変えると形式が壊れやすかった。速く小さい形式にした
- 3 アプリへの影響: `Rails.cache` を使っていない。development は `tmp/caching-dev.txt` がないので `:null_store`、test も `:null_store` で、保存されたキャッシュはない
- 扱い: 追随（6.1 に戻す予定はない）。`load_defaults 7.0` にするときに `config/application.rb` から消す
- 出典: [rails/rails#42025](https://github.com/rails/rails/pull/42025)、[アップグレードガイド v7.0](https://railsguides.jp/v7.0/upgrading_ruby_on_rails.html)「2.12 `ActiveSupport::Cache`の新しいシリアライズフォーマット」、[設定ガイド v7.0](https://railsguides.jp/v7.0/configuring.html)「3.14.9 `config.active_support.cache_format_version`」
- コミット: （コミット後に記入）

### DEF-7.0-32: `action_controller.raise_on_open_redirects = true`

- 種類: `load_defaults`（グループ 4）/ 対象: 3 アプリ
- 何が変わるか: `redirect_to`・`redirect_back_or_to` で、リクエストと違うホストへリダイレクトしようとすると、`allow_other_host: true` を付けない限り `ActionController::Redirecting::UnsafeRedirectError` にする。3 アプリとも `ActionController::Base.raise_on_open_redirects` が `false` → `true`
- なぜ: 利用者の入力をそのまま `redirect_to` に渡して外部のサイトへ誘導される「オープンリダイレクト」を、既定で防ぐため。外部へ送りたいときは `allow_other_host: true` で意図を明示する
- 3 アプリへの影響: 判定はホスト名だけで、ポートは見ない（`localhost:3780` から `localhost:3781` は同じホスト扱い。`actionpack-7.0.10/lib/action_controller/metal/redirecting.rb` の `_url_host_allowed?`）
  - OP: 認可の後に RP へ戻す doorkeeper のリダイレクトは `allow_other_host: true` を渡している（`doorkeeper-5.7.1/app/controllers/doorkeeper/authorizations_controller.rb`）。OP 独自の `redirect_to new_user_session_url`（`config/initializers/doorkeeper_openid_connect.rb`）は同じホスト。test 環境のホスト `www.example.com` から `localhost:3781` へのリダイレクトを確かめるテスト（同意・拒否）が通った
  - RP: `redirect_to` は `root_path`・`introspection_path` だけ。OP へのリダイレクトは omniauth が Rack の 302 で返すので対象外
  - RS: リダイレクトしない
- 扱い: 追随
- 出典: コミット [rails/rails@5e93cff](https://github.com/rails/rails/commit/5e93cff835)（PR を経ずに入ったコミット）、[設定ガイド v7.0](https://railsguides.jp/v7.0/configuring.html)「3.9.17 `config.action_controller.raise_on_open_redirects`」、[セキュリティガイド v7.0](https://railsguides.jp/v7.0/security.html)「4.1 リダイレクト」（オープンリダイレクトの危険。この設定そのものの説明はない）
- コミット: （コミット後に記入）

### DEF-7.0-33: `action_dispatch.default_headers`（`X-XSS-Protection: 0`）

- 種類: `load_defaults`（グループ 5）/ 対象: 3 アプリ
- 何が変わるか: Rails のコントローラーが返す応答の `X-XSS-Protection` が `1; mode=block` → `0`。ほかの既定のヘッダー（`X-Frame-Options`・`X-Content-Type-Options`・`X-Download-Options`・`X-Permitted-Cross-Domain-Policies`・`Referrer-Policy`）は同じ。書き出した応答で変わった数は RS 2/2、RP 4/5、OP 19/20。変わらなかった 2 つは Rails のコントローラーを通らない応答（RP の omniauth が返す認可要求の 302、OP の未ログインで devise の FailureApp が返す 302）で、前後ともこのヘッダーが付かない
- なぜ: このヘッダーが動かしていたブラウザの XSS Auditor は、主要なブラウザから取り除かれた（代わりは Content Security Policy）。古いブラウザでは Auditor がかえって脆弱性を生むことがあるので、OWASP は `0`（無効）を勧めている
- 3 アプリへの影響: 今のブラウザはこのヘッダーを見ないので、画面と動作は同じ。テスト・E2E はこのヘッダーを確かめていない
- 扱い: 追随
- 出典: [rails/rails#41769](https://github.com/rails/rails/pull/41769)、[OWASP Secure Headers Project](https://owasp.org/www-project-secure-headers/#x-xss-protection)、[セキュリティガイド v7.0](https://railsguides.jp/v7.0/security.html)「9 HTTPセキュリティヘッダー」、[設定ガイド v7.0](https://railsguides.jp/v7.0/configuring.html)「3.10.2 `config.action_dispatch.default_headers`」
- コミット: （コミット後に記入）

### DEF-7.0-34: `action_view.button_to_generates_button_tag = true`

- 種類: `load_defaults`（グループ 6）/ 対象: 3 アプリ
- 何が変わるか: `button_to` が、文字列を渡したときも `<input type="submit" value="...">` ではなく `<button type="submit">...</button>` を出す。書き出した応答で変わったのは OP の `/users/edit` の「Cancel my account」だけ（属性 `data-confirm`・`data-turbo-confirm` と送る先の `DELETE /users` は同じ）
- なぜ: 6.1 までは、文字列を渡すと `<input>`、ブロックを渡すと `<button>` になり、渡し方で要素が変わって紛らわしかった。`<button>` にそろえる
- 3 アプリへの影響: アプリのコードに `button_to` はなく、出るのは devise の gem のビュー（`devise-4.9.4/app/views/devise/registrations/edit.html.erb`）だけ。ボタンの文字・送る先・確認の属性が同じなので、「挙動を変えない」の定義の境目の 2（PLAN.md の 3 章）にあたる。テスト・E2E はこのページを開かない
- 扱い: 追随
- 出典: [rails/rails#40747](https://github.com/rails/rails/pull/40747)、[設定ガイド v7.0](https://railsguides.jp/v7.0/configuring.html)「3.11.18 `config.action_view.button_to_generates_button_tag`」（[アップグレードガイド v7.0](https://railsguides.jp/v7.0/upgrading_ruby_on_rails.html)「2.1 `ActionView::Helpers::UrlHelper#button_to`の振る舞いが変更された」は、保存済みのレコードを渡したときの HTTP メソッドの推論の話で、この設定とは別の変更）
- コミット: （コミット後に記入）

### DEF-7.0-35: `action_view.apply_stylesheet_media_default = false`

- 種類: `load_defaults`（グループ 7）/ 対象: 3 アプリ
- 何が変わるか: `stylesheet_link_tag` に `media` を渡さないとき、`media="screen"` を付けない。書き出した応答で変わったのは、doorkeeper のレイアウトを使う OP の 3 つ（同意画面・エラー画面・form_post）の `<link rel="stylesheet" href="/stylesheets/doorkeeper/application.css" />`。doorkeeper の管理画面のレイアウト（`app/views/layouts/doorkeeper/admin.html.erb`）も同じように変わる（書き出した応答には含めていない）
- なぜ: `media` を省いたときのブラウザの既定は `all`。古い既定の `screen` を付けると、印刷のときなどに CSS が当たらない
- 3 アプリへの影響: RP のレイアウトは `media: 'all'` を明示しているので変わらない。OP の CSS のファイルは `public/` になく、Sprockets も読み込んでいないので、前後とも 404 で見た目は変わらない。応答の `Link` ヘッダー（preload）も変わらない
- 扱い: 追随
- 出典: [rails/rails#41215](https://github.com/rails/rails/pull/41215)、[設定ガイド v7.0](https://railsguides.jp/v7.0/configuring.html)「3.11.19 `config.action_view.apply_stylesheet_media_default`」
- コミット: （コミット後に記入）

### DEF-7.0-36: `active_support.key_generator_hash_digest_class = OpenSSL::Digest::SHA256`

- 種類: `load_defaults`（グループ 8）/ 対象: 3 アプリ
- 何が変わるか: `secret_key_base` から、暗号化・署名の Cookie などの鍵を導くときのハッシュが SHA1 → SHA256。これまでの鍵で作った暗号化・署名の Cookie は読めなくなる
- なぜ: SHA1 は古いアルゴリズムで、セキュリティの監査で好まれない（PR の説明）。SHA256 にそろえる
- 3 アプリへの影響
  - OP: セッション Cookie は暗号化されたもの（`データ--IV--認証タグ` の 3 つの部分）。test 環境で、SHA1 の鍵で作った Cookie（中身は `session_id`・`user_return_to`・`flash`）を控え、この設定を有効にしてから読むと `nil` になった。ログイン済みのブラウザは一度ログアウトした状態になる（認可の途中の戻り先や flash も消える。開いたままのフォームを送ると CSRF の確認で失敗する）
  - RP: セッション Cookie は 32 文字の 16 進数（セッション ID だけ）で、署名も暗号化もない。セッションの中身は DB にあるので、ログインは続く
  - RS: Cookie を使わない
  - 鍵の生成を使うほかの仕組みは使っていない。devise の `token_generator`（パスワードの再設定などのトークン）は、OP で使っていないモジュール（devise は `database_authenticatable`・`registerable`・`validatable` だけ）のためのもの
  - 手動確認（ブラウザペイン）: この設定なしで RP からログインし、3 アプリを止めてこの設定を有効にして起動し直した。RP のログインは続き、RP の「Re Login」で OP のログイン画面が出た（OP のセッションが切れた）。もう一度ログインした後、RP のログインと introspection 用 RP の流れ（RS が 200・401・revoke の後に 401、introspect が `active: true` → `active: false`）は Step 0-f-3 と同じだった
- 扱い: 追随。移行用のコード（Cookie のローテーション）は書かない（PLAN.md の 3 章の 2 の境目の 6、12 章）
- 出典: [rails/rails#40770](https://github.com/rails/rails/pull/40770)、[アップグレードガイド v7.0](https://railsguides.jp/v7.0/upgrading_ruby_on_rails.html)「2.10 キージェネレータのメッセージダイジェストクラスがSHA256に変更」（ローテーションのコードの例がある）、[設定ガイド v7.0](https://railsguides.jp/v7.0/configuring.html)「3.14.7 `config.active_support.key_generator_hash_digest_class`」
- コミット: （コミット後に記入）
