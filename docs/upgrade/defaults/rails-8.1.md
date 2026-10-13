# Rails 8.1 の既定値への追随

- 版: Rails 8.0.5.1 → 8.1.4（Ruby 3.3.12）
- Step: 7（ブランチ `upgrade/step7-rails81`）/ PR: （PR 作成後に記入）
- 記録のルールは [README.md](README.md)

## 一覧

| ID | 項目 | 種類 | 対象 | 扱い |
|---|---|---|---|---|
| DEF-8.1-01 | `to_time_preserves_timezone` の設定のキーがなくなる | Rails の既定値 | 3 アプリ | 追随（何もしない） |
| DEF-8.1-02 | 開いたリダイレクトの設定が `raise_on_open_redirects` から `action_on_open_redirect` に変わる | Rails の既定値 | 3 アプリ | 追随 |
| DEF-8.1-03 | リダイレクトの新しい設定が 3 つ増える | Rails の既定値 | 3 アプリ | 追随 |
| DEF-8.1-04 | Active Record の新しい設定が 3 つ増える | Rails の既定値 | 3 アプリ | 追随 |
| DEF-8.1-05 | Active Storage の `multiple_file_field_include_hidden` のキーが書き出しに残る | Rails の内部の整理 | 3 アプリ | 追随 |
| DEF-8.1-06 | 起動の途中の読み込みの変化（Rails 自身） | Rails の既定値（読み込みの順番） | 3 アプリ | 追随（`scripts/check-load-hooks` の Rails 8.0.5.1 の組を消す） |
| DEF-8.1-07 | RP で、`ActionController::Base` が Bundler.require の途中で読み込まれる | Rails の既定値と周辺 gem（omniauth-rails_csrf_protection 2.0.1）の組み合わせ | RP | 追随（`scripts/check-load-hooks` でこの 1 件だけを許す） |
| DEF-8.1-08 | SQLite の真偽値を `TRUE`・`FALSE` で書く | Rails の既定値 | OP | 追随 |
| DEF-8.1-09 | actiontext が、Trix を action_text-trix から読む | Rails の依存 | 3 アプリ | 追随 |
| DEF-8.1-10 | development で、リダイレクトを呼んだ場所をログに出す | Rails の雛形 | 3 アプリ（development） | 追随 |
| DEF-8.1-11 | production.rb の SSL の 2 行がコメントになる | Rails の雛形 | 3 アプリ（production） | 追随（決まりどおり） |
| DEF-8.1-12 | `config/puma.rb` のコメント | Rails の雛形 | 3 アプリ | 追随 |
| DEF-8.1-13 | `config/puma.rb` の `plugin :solid_queue` | Rails の雛形（新しい構成） | 3 アプリ | 採用しない |
| DEF-8.1-14 | `content_security_policy.rb` に `content_security_policy_nonce_auto` のコメントが増える | Rails の雛形 | RP・OP | 追随 |
| DEF-8.1-15 | `bin/setup` に `--reset` が増える | Rails の雛形 | 3 アプリ | 追随 |
| DEF-8.1-16 | public のエラーページ（400・404・422・500） | Rails の雛形 | RP・OP | 追随 |
| DEF-8.1-17 | `bin/rubocop`・`bin/brakeman` | Rails の雛形 | 3 アプリ | 採用しない |
| DEF-8.1-18 | `bin/bundler-audit`・`config/bundler-audit.yml` | Rails の雛形 | 3 アプリ | 採用しない |
| DEF-8.1-19 | `bin/ci`・`config/ci.rb` | Rails の雛形（新しい構成） | 3 アプリ | 採用しない |
| DEF-8.1-20 | `public/406-unsupported-browser.html`・`icon.png`・`icon.svg` | Rails の雛形 | RP・OP | 採用しない |
| DEF-8.1-21 | Action View のテンプレートの依存を、Ruby のパーサーで追う | Rails の既定値（8.1） | 3 アプリ | 追随 |
| DEF-8.1-22 | 並べる列のないモデルで `first` などを呼ぶと例外にする | Rails の既定値（8.1） | 3 アプリ | 追随 |
| DEF-8.1-23 | `/` で始まらない相対パスへのリダイレクトを例外にする | Rails の既定値（8.1） | 3 アプリ | 追随（RP は `load_defaults 8.1` で入る） |
| DEF-8.1-24 | `render json:` で HTML の記号を書き換えなくなる | Rails の既定値（8.1） | 3 アプリ | 追随（RP は `load_defaults 8.1` で入る） |
| DEF-8.1-25 | JSON で U+2028・U+2029 を書き換えなくなる | Rails の既定値（8.1） | 3 アプリ | 追随（defaults のファイルからは効かないので、`load_defaults 8.1` で入る） |
| DEF-8.1-26 | hidden の input に `autocomplete="off"` を付けなくなる | Rails の既定値（8.1） | 3 アプリ（スナップショットが変わるのは OP） | 追随（OP の応答のスナップショットを作り直した） |
| DEF-8.1-27 | `load_defaults 8.1` にし、`new_framework_defaults_8_1.rb` を消す | Rails の既定値 | 3 アプリ | 追随 |
| DEF-8.1-28 | development・test で YJIT を切る | Rails の既定値（8.1） | 3 アプリ（development・test） | 追随 |
| DEF-8.1-29 | 起動のたびに、Active Storage が image_processing gem がないことをログに出す | Rails の既定値 | 3 アプリ | 追随（受け入れる。改善の候補は IMP-012） |

## Rails 8.1.4 の lock（rails-lock）

Rails を 8.0.5.1 → 8.1.4 にしたとき（`load_defaults` は 8.0 のまま）に起きた、Rails の既定値と依存の変化。前後で、`scripts/check-apps`（3 アプリと E2E）の 36 の検査がすべて通り、件数は同じ（RS 11・RP 33・OP 69 runs、E2E 10 passed）。応答と E2E のスナップショットの差分はない。`RUBYOPT=-W:deprecated` の警告、brakeman（チェックの数 79）、development だけのヘッダーも同じ。差分が出たのは `scripts/compare-config` の書き出しだけで、下の 9 項目がその全部。research の worktree で先に試した結果（PLAN.md の 6 章の Step 7、LOG.md の Step 7 の論点 1）とも同じ（worktree の書き出しにだけ、ActiveStorage などのモデルの関連付けの行がなかった。`vendor/bundle` をシンボリックリンクにした worktree のときだけの違いで、本体では前後とも出る）。

### DEF-8.1-01: `to_time_preserves_timezone` の設定のキーがなくなる

- 種類: Rails の既定値 / 対象: RS・RP・OP
- 何が変わるか: 書き出しから `config.active_support.to_time_preserves_timezone = :zone` と `ActiveSupport.to_time_preserves_timezone = :zone` が消える。`to_time` は常に `:zone` の動きになる
- なぜ: 8.0 で非推奨にした「`to_time` がシステムのローカル時刻を保つ」動きを、8.1 で消した（c79dc282d6）。設定すると非推奨の警告が出る
- 3 アプリへの影響: Step 6 で `:zone` にしてあり（DEF-8.0-01）、3 アプリの設定にこのキーはない。動きは変わらない
- 扱い: 追随（何もしない）
- 出典: activesupport の CHANGELOG（8.1.0「Remove deprecated support for `to_time` to preserve the system local time」）、`activesupport-8.1.4/lib/active_support.rb:124-137`
- コミット: Rails 8.1.4 の lock（RS・RP・OP）

### DEF-8.1-02: 開いたリダイレクトの設定が `raise_on_open_redirects` から `action_on_open_redirect` に変わる

- 種類: Rails の既定値 / 対象: RS・RP・OP
- 何が変わるか: `config.action_controller.raise_on_open_redirects = true` → `config.action_controller.action_on_open_redirect = :raise`（`ActionController::Base`・`ActionController::API`）
- なぜ: 他のホストへのリダイレクトを、例外だけでなく、ログや通知でも扱えるようにした（rails/rails#55496）。`load_defaults 7.0` が入れる値も新しい設定になった。古い設定を書いたアプリにだけ非推奨の警告を出す（新しく作ったアプリに出さないのは #55793）
- 3 アプリへの影響: どちらも「他のホストへのリダイレクトは例外」で同じ動き。3 アプリは古い設定を書いていない。OP の doorkeeper の RP へのリダイレクト（`allow_other_host`）も、E2E と応答のスナップショットで変わっていない
- 扱い: 追随
- 出典: actionpack の CHANGELOG（8.1.0）、`railties-8.1.4/lib/rails/application/configuration.rb:266`、`actionpack-8.1.4/lib/action_controller/railtie.rb:15,116-125`、`actionpack-8.1.4/lib/action_controller/metal/redirecting.rb:29-30`
- コミット: Rails 8.1.4 の lock（RS・RP・OP）

### DEF-8.1-03: リダイレクトの新しい設定が 3 つ増える

- 種類: Rails の既定値 / 対象: RS・RP・OP
- 何が変わるか: `config.action_controller.allowed_redirect_hosts = []`、`config.action_controller.action_on_path_relative_redirect = :log`、`config.action_dispatch.verbose_redirect_logs = false` が増える（`ActionController::Base`・`API`、`ActionDispatch` にも同じ値）
- なぜ: `hosts` の設定のホストへのリダイレクトを許す仕組み（#55420）、`/` で始まらない相対パスへのリダイレクトを見つける仕組み（#55308。既定はログ）、リダイレクトを呼んだ場所をログに出す仕組み（#52297）
- 3 アプリへの影響: 空の一覧・ログだけ・無効なので、動きは変わらない。アプリの `redirect_to` は RP の path ヘルパーだけ。`verbose_redirect_logs` は、`app:update` の development.rb の雛形に `true` が入る見込み（rails-app-update で扱う）
- 扱い: 追随
- 出典: actionpack の CHANGELOG（8.1.0「Add `action_dispatch.verbose_redirect_logs` setting」「Allow hosts redirects from `hosts` Rails configuration」）、上の PR
- コミット: Rails 8.1.4 の lock（RS・RP・OP）

### DEF-8.1-04: Active Record の新しい設定が 3 つ増える

- 種類: Rails の既定値 / 対象: RS・RP・OP
- 何が変わるか: `config.active_record.deprecated_associations_options = {mode: :warn, backtrace: false}`（`ActiveRecord.deprecated_associations_options` にも）、`config.active_record.query_log_tags_prepend_comment = false`、`config.active_record.use_legacy_signed_id_verifier = :generate_and_verify` が増える
- なぜ: 関連付けに `deprecated: true` を付けて使い道を見つける仕組み（#55285）、query log tags のコメントを SQL の前に付けられる設定（#54707）、signed ID の検証に `Rails.application.message_verifiers` を使えるようにする移行の設定（e4218ff31b）
- 3 アプリへの影響: `deprecated: true` の関連付けはない。query log tags は今と同じく SQL の後ろに付く（development で有効。DEF-8.0-13）。signed ID は使っていない（`:generate_and_verify` は今までと同じ動き）
- 扱い: 追随
- 出典: activerecord の CHANGELOG（8.1.0）、上の PR
- コミット: Rails 8.1.4 の lock（RS・RP・OP）

### DEF-8.1-05: Active Storage の `multiple_file_field_include_hidden` のキーが書き出しに残る

- 種類: Rails の内部の整理 / 対象: RS・RP・OP
- 何が変わるか: 書き出しに `config.active_storage.multiple_file_field_include_hidden = true` が出るようになる
- なぜ: 8.0.5.1 の Active Storage の engine は、after_initialize でこのキーを `delete` してから写していた。8.1.4 は `delete` しない
- 3 アプリへの影響: 写す先の値（`ActionView::Helpers::FormHelper.multiple_file_field_include_hidden`）は `true` のまま（runner で確かめた）で、書き出しの見え方が変わっただけ。ファイルを複数選ぶフォームもない
- 扱い: 追随
- 出典: `activestorage-8.0.5.1/lib/active_storage/engine.rb:176-184`、`activestorage-8.1.4/lib/active_storage/engine.rb:214-220`
- コミット: Rails 8.1.4 の lock（RS・RP・OP）

### DEF-8.1-06: 起動の途中の読み込みの変化（Rails 自身）

- 種類: Rails の既定値（読み込みの順番）/ 対象: RS・RP・OP
- 何が変わるか: (a) `action_dispatch_response` が、`config/initializers` の直前にも `initialize!` の後にも読み込まれなくなる。(b) `active_model_error` が、`config/application.rb` の後に読み込み済みと出る
- なぜ: (a) は DEF-8.0-02 の不具合（rails/rails#58145）が 8.1.4 で直ったため（8-1-stable の #58147。initializer `action_controller.live_streaming_excluded_keys` の中身が `on_load(:action_controller_live)` に入った）。(b) は、8.1 で `ActiveModel::Error` に load hook が足され（#55347）、見えるようになっただけ。8.1.4 では、`active_record/errors.rb` の `UnknownAttributeError = ActiveModel::UnknownAttributeError` が、require の時点で `active_model/errors` を読む（load hook に `caller` を仕込んで確かめた）。8.0.5.1 も同じ行（`activerecord-8.0.5.1/lib/active_record/errors.rb:444`）があるので、読み込みの時期は同じと見られる（8.0.5.1 には load hook がなく、流しては確かめていない。ソースを読んだ見立て）
- 3 アプリへの影響: (a) で、config/initializers に書く `ActionDispatch::Response` の設定が効くようになる（今のアプリにそういう設定はない）。RS・OP の起動の途中の読み込みの検査は、許す条件なしで通る。(b) は a-nti_manner_kick_course の監視の外で、`ActiveModel::Error.i18n_customize_full_message` の写し方が on_load に変わっただけ（値は `false` のまま）
- 扱い: 追随。`scripts/check-load-hooks` の Rails 8.0.5.1 の組は、3 アプリを上げ終えたら消す
- 出典: `actionpack-8.1.4/lib/action_controller/railtie.rb:36-40`、`activerecord-8.1.4/lib/active_record/errors.rb:451`、`activemodel-8.1.4/lib/active_model/error.rb:208`、`activemodel-8.1.4/lib/active_model/railtie.rb:23-27`、上の PR
- コミット: Rails 8.1.4 の lock（RS・RP・OP）と、`scripts/check-load-hooks` の 2 つのコミット

### DEF-8.1-07: RP で、`ActionController::Base` が Bundler.require の途中で読み込まれる

- 種類: Rails の既定値（`ActiveSupport::Configurable` の非推奨）と周辺 gem（omniauth-rails_csrf_protection 2.0.1）の組み合わせ / 対象: RP
- 何が変わるか: RP の書き出しで、`action_controller`・`action_controller_base` が `config/application.rb` の後に読み込み済みになる。a-nti_manner_kick_course が `on_load(:action_controller_base)` を `omniauth-rails_csrf_protection-2.0.1/lib/omniauth/rails_csrf_protection/token_verifier.rb:26` で検出する（test・`CI=1`・development）
- なぜ: Rails 8.1 は `ActiveSupport::Configurable` を非推奨にし（rails/rails#53970）、`ActionController::RequestForgeryProtection` は `config_accessor` から、include した側の `config` に任せる `delegate` の形になった。gem の Rails 8.1 用の分岐（2.0.0 の 2cf722b）は、`config` を `ActionController::Base.config` にしてから `RequestForgeryProtection` を include するので、`included` ブロックが `config` を呼んだ時点で Base が autoload される。gem の railtie は Bundler.require の中でこのファイルを読む。上流の cookpad/omniauth-rails_csrf_protection#33 は open で、2.0.1 が最新
- 3 アプリへの影響: RP の config/initializers に書いた action_controller の設定は Base に届かない（research の worktree で、`asset_host`・`per_form_csrf_tokens` を initializer に書いて確かめた。今の RP にそういう設定はない）。環境のファイルと `load_defaults` の値は届くので、RP の action_controller の値の変化は RS・OP と同じ。CSRF の判定は 8.0 と同じ設定を読み、RP のテストと E2E は通った。この gem を `require: false` にすると、検出は 0 件になる（後ろに隠れた検出はない）
- 扱い: 追随。gem はそのまま使い、`scripts/check-load-hooks` でこの 1 件だけを許す（LOG.md の Step 7 の論点 2）。直った版が出たら上げて、許す組を消す（docs/IMPROVEMENTS.md の IMP-009）。それまでは、RP の config/initializers に action_controller の設定を書かない
- 出典: 上のファイルと PR、`actionpack-8.1.4/lib/action_controller/metal/request_forgery_protection.rb:71-111`、LOG.md の Step 7 の論点 2
- コミット: `scripts/check-load-hooks` の最初のコミットと、Rails 8.1.4 の lock（RP）

### DEF-8.1-08: SQLite の真偽値を `TRUE`・`FALSE` で書く

- 種類: Rails の既定値 / 対象: OP（真偽値の列は `oauth_applications.confidential` だけ）
- 何が変わるか: SQL に真偽値を直接書くときに、`1`・`0` ではなく `TRUE`・`FALSE` になる。OP の test.log では、fixtures の INSERT が `'openid', 1,` → `'openid', TRUE,` に変わった
- なぜ: SQLite 3.23.0 から `TRUE`・`FALSE` を使えるので、それに合わせた（rails/rails#55015）。8.1 で SQLite の最低の版も 3.23.0 に上がった
- 3 アプリへの影響: SQLite では `TRUE` は整数の 1 なので、DB に入る値は同じ。アプリの書き込みはバインド変数なので、ログの形も変わらない。RS・RP には真偽値の列がない
- 扱い: 追随
- 出典: activerecord の CHANGELOG（8.1.0「Use `TRUE` and `FALSE` for SQLite queries with boolean columns」「Bump minimum supported SQLite to 3.23.0」）
- コミット: Rails 8.1.4 の lock（OP）

### DEF-8.1-09: actiontext が、Trix を action_text-trix から読む

- 種類: Rails の依存 / 対象: RS・RP・OP
- 何が変わるか: lock に action_text-trix 2.1.19 が増え、起動時に `Trix::Engine` が読み込まれる
- なぜ: Trix（リッチテキストのエディター）を、Rails に同梱する代わりに gem にして、Rails のリリースと別に上げられるようにした
- 3 アプリへの影響: engine がするのは、アセットパイプラインがあるときに `trix.js`・`trix.css` をプリコンパイルの対象に足すことだけで、3 アプリにはアセットパイプラインがないので何もしない。Action Text も使っていない
- 扱い: 追随
- 出典: actiontext の CHANGELOG（8.1.0「The Trix dependency is now satisfied by a gem, `action_text-trix`」）、`actiontext-8.1.4/lib/action_text/engine.rb:11`、`action_text-trix-2.1.19/lib/action_text/trix/engine.rb`
- コミット: Rails 8.1.4 の lock（RS・RP・OP）

## `app:update` の雛形（rails-app-update）

3 アプリで `yes a | bin/rails app:update`（DB は E2E 用）を流し、戻す前の差分を控えてから `scripts/restore-app-config` で独自設定を戻した（test の `deprecation = :raise`、puma の port、`filter_parameter_logging.rb` の `:code` とコメント、RP の `autoload_lib_once` と inflector、Active Storage のマイグレーション 3 本。戻せない項目はなかった。戻した設定の上の雛形のコメントは 8.0.5.1 から変わっていない）。`config/application.rb`（RS・OP）と `test.rb`・`filter_parameter_logging.rb` の雛形は 8.0.5.1 と同じで、戻した後の差分はない。前後で、`scripts/check-apps`（3 アプリと E2E）の 36 の検査がすべて通り、件数は同じ。応答と E2E のスナップショットの差分はない。development だけのヘッダーも同じ。設定の値で変わったのは、development の `verbose_redirect_logs` だけ。出典の雛形は `railties-8.1.4/lib/rails/generators/rails/app/templates/` の下、生成の条件は `railties-8.1.4/lib/rails/generators/rails/app/app_generator.rb:111-189`・`railties-8.1.4/lib/rails/commands/app/update_command.rb:63-84`（railsdiff/rails-new-output の v8.0.5.1...v8.1.4 とも一致）。

### DEF-8.1-10: development で、リダイレクトを呼んだ場所をログに出す

- 種類: Rails の雛形 / 対象: RS・RP・OP（development）
- 何が変わるか: development.rb に `config.action_dispatch.verbose_redirect_logs = true` が増え、ログの「Redirected to」の次の行に、リダイレクトを呼んだコードの場所が出る
- なぜ: `verbose_query_logs`・`verbose_enqueue_logs` と同じく、開発中にリダイレクトの出どころを追いやすくするため（rails/rails#52297。DEF-8.1-03 の設定を雛形で有効にした）
- 3 アプリへの影響: development のログだけ。compare-config の値の変化は、development の false → true だけ。OP の「Redirected to」行の `code=` の伏せ方は、verify の手動確認で見る
- 扱い: 追随
- 出典: actionpack の CHANGELOG（8.1.0「Add `action_dispatch.verbose_redirect_logs` setting」）、`development.rb.tt`
- コミット: `app:update` の雛形（RS・RP・OP）

### DEF-8.1-11: production.rb の SSL の 2 行がコメントになる

- 種類: Rails の雛形 / 対象: RS・RP・OP（production）
- 何が変わるか: `config.assume_ssl = true`・`config.force_ssl = true` がコメントになる。ほかは、コメントの句点と `bin/rails credentials:edit` の書き方だけ
- なぜ: 8.1.1 で、雛形が「Kamal を使わない（`skip_kamal`）ときだけ有効、Kamal を使うときはコメント」に分かれた。Kamal の既定の配備は SSL なしで動かすので、有効のままだとフォームの送信が Origin の不一致で失敗するため（rails/rails#56010）。`app:update` は `skip_kamal` を渡さないので、Kamal を使うアプリとして扱われる
- 3 アプリへの影響: production だけ。動作を保証するのは development・test だけで、production.rb は雛形に追従するだけにする（CLAUDE.md）。production で動かすなら、HTTPS へのリダイレクト・HSTS・secure な Cookie がなくなる
- 扱い: 追随（決まりどおり。`true` を残す案もあったが、人間が決まりどおりと判断した）
- 出典: `production.rb.tt:31-43`、#56010
- コミット: `app:update` の雛形（RS・RP・OP）

### DEF-8.1-12: `config/puma.rb` のコメント

- 種類: Rails の雛形 / 対象: RS・RP・OP
- 何が変わるか: `WEB_CONCURRENCY` に `auto` を渡せるという説明が増える（port は道具で戻した）
- 3 アプリへの影響: コメントだけ
- 扱い: 追随
- 出典: `puma.rb.tt`
- コミット: `app:update` の雛形（RS・RP・OP）

### DEF-8.1-13: `config/puma.rb` の `plugin :solid_queue`

- 種類: Rails の雛形（新しい構成）/ 対象: RS・RP・OP
- 何が変わるか: `plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]` とそのコメント（8.1 で句点が付いた）が入る
- 3 アプリへの影響: Solid Queue は使わない
- 扱い: 採用しない（DEF-8.0-19 と同じ。手で消した）
- 出典: `puma.rb.tt`（`skip_solid?` が偽のとき）
- コミット: なし

### DEF-8.1-14: `content_security_policy.rb` に `content_security_policy_nonce_auto` のコメントが増える

- 種類: Rails の雛形 / 対象: RP・OP
- 何が変わるか: nonce を `javascript_tag`・`javascript_include_tag`・`stylesheet_link_tag` に自動で付ける設定の説明（コメント）が増える
- 3 アプリへの影響: ファイルはすべてコメントで、CSP は有効にしていない（RS は API なので、このファイルがない）
- 扱い: 追随
- 出典: `content_security_policy.rb.tt`
- コミット: `app:update` の雛形（RP・OP）

### DEF-8.1-15: `bin/setup` に `--reset` が増える

- 種類: Rails の雛形 / 対象: RS・RP・OP
- 何が変わるか: `bin/setup --reset` のときだけ、`db:prepare` の後に `db:reset` を流す
- 3 アプリへの影響: 付けなければ今と同じ。付けると development の DB を作り直すので、RP・OP では手動確認用の DB が消える。RS は `db/schema.rb` がないので、`db:reset` の schema の読み込みで失敗する（コードレビューで分かった。流しては確かめていない）。DEF-8.0-20 と同じく、README の仕上げで手動確認用の環境と一緒に書く
- 扱い: 追随
- 出典: `bin/setup.tt`
- コミット: `app:update` の雛形（RS・RP・OP）

### DEF-8.1-16: public のエラーページ（400・404・422・500）

- 種類: Rails の雛形 / 対象: RP・OP
- 何が変わるか: タイトルの `’` → `'`、`min-height` の `100vh` → `100dvh`、ダークモードの色（rails/rails#55671）、空行の整理
- 3 アプリへの影響: production の例外画面だけで使う（development・test は詳しいエラー画面）。応答のスナップショットの差分はない
- 扱い: 追随（DEF-8.0-22 と同じ）
- 出典: `public/*.html`
- コミット: `app:update` の雛形（RP・OP）

### DEF-8.1-17: `bin/rubocop`・`bin/brakeman`

- 種類: Rails の雛形 / 対象: RS・RP・OP
- 3 アプリへの影響: 検査は `bundle exec` で `scripts/check-apps` と CI から流す
- 扱い: 採用しない（DEF-7.2-20・DEF-8.0-21 と同じ）
- コミット: なし

### DEF-8.1-18: `bin/bundler-audit`・`config/bundler-audit.yml`

- 種類: Rails の雛形（8.1 で新しい）/ 対象: RS・RP・OP
- 何が変わるか: bundler-audit を `--config config/bundler-audit.yml` で流す binstub と、その設定ファイル（雛形は `ignore: - CVE-THAT-DOES-NOT-APPLY` という見本の行）ができる。Gemfile に bundler-audit があると作られる（`update_command.rb` の `skip_bundler_audit`）
- 3 アプリへの影響: 3 アプリの無視リストは、bundler-audit の既定の場所（アプリ直下の `.bundler-audit.yml`）にあり、check-apps と CI は `bundle exec bundle-audit check` で流している。採用すると、無視リストが 2 か所になる
- 扱い: 採用しない（設定は `.bundler-audit.yml` の 1 か所にしておく）
- 出典: `bin/bundler-audit.tt`、`config/bundler-audit.yml.tt`、`app_generator.rb` の `config`・`config_when_updating`
- コミット: なし

### DEF-8.1-19: `bin/ci`・`config/ci.rb`

- 種類: Rails の雛形（新しい構成。8.1 の `ActiveSupport::ContinuousIntegration`）/ 対象: RS・RP・OP
- 何が変わるか: 手元で CI の手順（`bin/setup --skip-server`、`bin/rubocop`、`bin/bundler-audit`、`bin/brakeman`、`bin/rails test`、`db:seed:replant`）を順に流す仕組みができる
- 3 アプリへの影響: このリポジトリでは、同じ役目を `scripts/check-apps`（3 アプリと E2E）と GitHub Actions が持つ。`config/ci.rb` は採用しない binstub（17・18）を呼び、最初の `bin/setup` は development の DB に `db:prepare` を流す
- 扱い: 採用しない（CLAUDE.md の「`app:update` が提案する新しい構成は採用しない」）
- 出典: `bin/ci.tt`、`config/ci.rb.tt`
- コミット: なし

### DEF-8.1-20: `public/406-unsupported-browser.html`・`icon.png`・`icon.svg`

- 種類: Rails の雛形 / 対象: RP・OP（RS は API なので作られない）
- 扱い: 採用しない（DEF-7.2-21・DEF-8.0-23 と同じ）
- コミット: なし

## `load_defaults 8.1`（`new_framework_defaults_8_1.rb`）

`new_framework_defaults_8_1.rb` の 6 項目を、人間が決めたグループの順（1 内部の処理だけ → 2 リダイレクト → 3 JSON の書き方 → 4 hidden の autocomplete）に有効にした。各グループで、前後に `scripts/compare-config` で 3 アプリの test・development の値を書き出して比べた（前の書き出しを取る前に、クラスの値が書き出しに出ない値を `scripts/lib/dump_config.rb` に足した）。ガイドは「3.1.1 ターゲットバージョン8.1のデフォルト値」（https://railsguides.jp/v8.1/configuring.html ）。

### DEF-8.1-21: Action View のテンプレートの依存を、Ruby のパーサーで追う

- 種類: Rails の既定値（`load_defaults 8.1` の項目）/ 対象: RS・RP・OP
- 何が変わるか: `ActionView.render_tracker` が nil → `:ruby`。erb のテンプレートの依存（どの部分テンプレートを描くか）を、正規表現（`ERBTracker`）ではなく Ruby のパーサー（`RubyTracker`）で読む
- なぜ: 正規表現では見落としや誤りがあった依存の読み取りを、パーサーで正確にするため（rails/rails#55194）
- 3 アプリへの影響: この依存は、fragment cache（`cache` ヘルパー）のキーの digest を作るときだけ使う。3 アプリのビューは `cache` を使わず、キャッシュも有効にしていない（test は `:null_store`）。前後で、値の変化のほかに、書き出し・検査・スナップショット・`-W:deprecated` の警告・development だけのヘッダーは同じ。defaults のファイルからも効く（initializer `action_view.set_render_tracker` が、アプリの `load_config_initializers` より後に走る。research の worktree で確かめた）
- 扱い: 追随（グループ 1）
- 出典: `actionview-8.1.4/lib/action_view.rb:95-108`、`actionview-8.1.4/lib/action_view/railtie.rb:105-107`、ガイド「3.11.23 config.action_view.render_tracker」
- コミット: グループ 1（RS・RP・OP）

### DEF-8.1-22: 並べる列のないモデルで `first` などを呼ぶと例外にする

- 種類: Rails の既定値（`load_defaults 8.1` の項目）/ 対象: RS・RP・OP
- 何が変わるか: `ActiveRecord.raise_on_missing_required_finder_order_columns` が false → true。`order` がなく、モデルにも並べる列（`implicit_order_column`・`query_constraints`・主キー）がないときに、`first`・`second`・`last` などが例外になる（false のときは非推奨の警告。この設定は 8.2 で消える）
- なぜ: 並びの決まらない `first` は、DB によって違う行を返すため（rails/rails#54608）
- 3 アプリへの影響: 3 アプリのモデルにはすべて主キーがあるので、主キーで並べる今の動きのまま。アプリのコードに `first`・`last` はなく（RP の `find_by` は並びを使わない）、テスト（`Doorkeeper::AccessGrant.last` など）と E2E も通った
- 扱い: 追随（グループ 1）
- 出典: `activerecord-8.1.4/lib/active_record/relation/finder_methods.rb:661-673`、`activerecord-8.1.4/lib/active_record/railtie.rb:210-221`、ガイド「3.8.89 config.active_record.raise_on_missing_required_finder_order_columns」
- コミット: グループ 1（RS・RP・OP）

### DEF-8.1-23: `/` で始まらない相対パスへのリダイレクトを例外にする

- 種類: Rails の既定値（`load_defaults 8.1` の項目）/ 対象: RS・OP（RP は `load_defaults 8.1` で入る）
- 何が変わるか: `action_on_path_relative_redirect` が `:log` → `:raise`（`ActionController::Base`・`API`）。`redirect_to "example.com"` のように、スキームも `/` もない文字列へのリダイレクトが、警告のログではなく `ActionController::Redirecting::UnsafeRedirectError`（`PathRelativeRedirectError`）になる
- なぜ: こうした文字列は、ブラウザが相対パスとも他のホストとも解釈しうるので、開いたリダイレクトの穴になりうるため（rails/rails#55308）
- 3 アプリへの影響: アプリの `redirect_to` は RP の path ヘルパーだけで、OP のリダイレクト（devise・doorkeeper）は `/` で始まるパスか絶対 URL。`:log` のときも、3 アプリの test.log にこの警告は 1 件もなかった。前後で、値の変化のほかに、書き出し・検査・スナップショット・`-W:deprecated` の警告・development だけのヘッダーは同じ。RP は、defaults のファイルで有効にしても `ActionController::Base` に届かない（DEF-8.1-07）ので、理由のコメントを付けてコメントのまま残した
- 扱い: 追随（グループ 2）
- 出典: `actionpack-8.1.4/lib/action_controller/metal/redirecting.rb:20,31,217,328-343`、`actionpack-8.1.4/lib/action_controller/railtie.rb:16`、ガイド「3.9.19 config.action_controller.action_on_path_relative_redirect」
- コミット: グループ 2（RS・RP・OP。RP は理由のコメントだけ）

### DEF-8.1-24: `render json:` で HTML の記号を書き換えなくなる

- 種類: Rails の既定値（`load_defaults 8.1` の項目）/ 対象: RS・OP（RP は `load_defaults 8.1` で入る）
- 何が変わるか: `escape_json_responses` が true → false（`ActionController::Base`・`API`）。`render json:` が、`<`・`>`・`&` を `\u003c`・`\u003e`・`\u0026` に、U+2028・U+2029 を `\u2028`・`\u2029` に書き換えなくなる（callback 付きの JSONP と、文字列をそのまま渡したときは対象外）
- なぜ: JSON の応答を HTML に埋め込むわけではないので、書き換えは要らず、省けば速くなるため（rails/rails#54643・#54840。true を明示して代入すると非推奨の警告）
- 3 アプリへの影響: 3 アプリの JSON の応答（RS の API、OP の discovery・トークン・userinfo・JWKS など。OP は doorkeeper の `render json:`）は、`Content-Type: application/json` で返し、HTML に埋め込んでいない。今の応答のスナップショットに書き換えられた文字はなく、前後で差分もない。前後で、値の変化のほかに、書き出し・検査・`-W:deprecated` の警告・development だけのヘッダーは同じ。RP は、defaults のファイルで有効にしても `ActionController::Base` に届かない（DEF-8.1-07）ので、理由のコメントを付けてコメントのまま残した
- 扱い: 追随（グループ 3）
- 出典: `actionpack-8.1.4/lib/action_controller/metal/renderers.rb:31-44,171`、ガイド「3.9.24 config.action_controller.escape_json_responses」
- コミット: グループ 3（RS・RP・OP）

### DEF-8.1-25: JSON で U+2028・U+2029 を書き換えなくなる

- 種類: Rails の既定値（`load_defaults 8.1` の項目）/ 対象: RS・RP・OP
- 何が変わるか: `ActiveSupport.escape_js_separators_in_json` が true → false。`to_json` などが、LINE SEPARATOR（U+2028）・PARAGRAPH SEPARATOR（U+2029）を書き換えなくなる
- なぜ: この 2 文字は、ECMAScript 2019 から JavaScript の文字列の中で使えるようになり、今のブラウザでは問題にならないため（rails/rails#55800）
- 3 アプリへの影響: defaults のファイルで有効にしても、値は true のままだった（research の worktree で確かめた）。initializer `active_support.set_configs` が、config/initializers より前に `config.active_support` の値を写すため（8.0 の `to_time_preserves_timezone`（DEF-8.0-01）と同じ形）。`load_defaults 8.1` で入る。3 アプリの応答に、この 2 文字はない
- 扱い: 追随。3 アプリとも、defaults のファイルで理由のコメントを付けてコメントのまま残し、`load_defaults 8.1` で値を確かめる（グループ 3。LOG.md の Step 7 の論点 5）
- 出典: `activesupport-8.1.4/lib/active_support/railtie.rb:142-147`、`activesupport-8.1.4/lib/active_support/json/encoding.rb:11,93-98`、ガイド「3.14.23 config.active_support.escape_js_separators_in_json」
- コミット: グループ 3（RS・RP・OP。理由のコメントだけ）

### DEF-8.1-26: hidden の input に `autocomplete="off"` を付けなくなる

- 種類: Rails の既定値（`load_defaults 8.1` の項目）/ 対象: RS・RP・OP（応答のスナップショットが変わるのは OP）
- 何が変わるか: `ActionView::Base.remove_hidden_field_autocomplete` が false → true。Rails のヘルパーが作る hidden の input（`hidden_field_tag`、`form_tag`・`button_to` の `_method`・authenticity token・params、`f.hidden_field` など）から、`autocomplete="off"` が消える。値と name は変わらない
- なぜ: `autocomplete="off"` は、Firefox の「戻る・進むのキャッシュから戻したページで、hidden の値を別の値で上書きする」不具合への対策として付けていた（rails/rails#42610）。その後、この不具合は JavaScript で hidden の値（プロパティ）を書き換えたページでしか起きないと分かり（#55209 のコメント）、hidden の input に `autocomplete` の on・off を付けるのは HTML の仕様に反する（W3C の検証でエラーになる）ので、外した（#55336・#55634・#55989）
- 3 アプリへの影響: OP の応答のスナップショット 6 つ（`authorize_consent`・`authorize_form_post`・`authorize_form_post_deny`・`oauth_applications`・`users_edit`・`users_update_failure`）で、計 29 行の `autocomplete="off"` が消えた。ほかの差分はない。3 アプリのビューで JavaScript があるのは OP の form_post の画面だけで、フォームを送るだけで hidden の値は書き換えないので、元の Firefox の不具合の条件に当たらない。RS・RP の応答のスナップショットに hidden の input はなく、変わらない。E2E（同意画面と form_post を通る）も通った。前後で、値の変化のほかに、書き出し・`-W:deprecated` の警告・development だけのヘッダーは同じ
- 扱い: 追随（グループ 4）。OP の応答のスナップショットを `UPDATE_SNAPSHOTS=1` で作り直し、OP のコミットに入れた
- 出典: `actionview-8.1.4/lib/action_view/helpers/form_tag_helper.rb`・`url_helper.rb`・`tags/hidden_field.rb`、`actionview-8.1.4/lib/action_view/railtie.rb:80-87`、ガイド「3.11.22 config.action_view.remove_hidden_field_autocomplete」
- コミット: グループ 4（RS・RP・OP）

### DEF-8.1-27: `load_defaults 8.1` にし、`new_framework_defaults_8_1.rb` を消す

- 種類: Rails の既定値 / 対象: RS・RP・OP
- 何が変わるか: `config/application.rb` の `config.load_defaults` が 8.0 → 8.1。`new_framework_defaults_8_1.rb` を消した。前（グループ 4 の後）と比べて、書き出しで値が変わったのは、defaults のファイルからは効かなかったものだけ
  - 3 アプリ: `ActiveSupport.escape_js_separators_in_json` が true → false（DEF-8.1-25）
  - RP: `escape_json_responses` が true → false、`action_on_path_relative_redirect` が `:log` → `:raise`（`ActionController::Base`・`API`。DEF-8.1-23・24）
  - 3 アプリで有効にしてあったほかの項目は、同じ値のまま `load_defaults` から入る
- なぜ: `load_defaults 8.1` は `config/application.rb` の段階で値を入れるので、config/initializers より前に値を写す initializer（`active_support.set_configs`）にも、RP の早い読み込み（DEF-8.1-07）にも間に合う
- 3 アプリへの影響: 上の値と下の DEF-8.1-28 のほかは、書き出し（読み込み済みの部品を含む）・検査（36 の検査）・応答と E2E のスナップショット・`-W:deprecated` の警告・development だけのヘッダーとも同じ。3 アプリの応答に U+2028・U+2029 はなく、RP の `redirect_to` は path ヘルパーだけ。雛形から消えた initializer はない（3 アプリの initializer は、8.1.4 の雛形にあるものか、アプリの独自のものだけ）
- 扱い: 追随
- 出典: `railties-8.1.4/lib/rails/application/configuration.rb:343-367`
- コミット: `load_defaults 8.1`（RS・RP・OP）

### DEF-8.1-28: development・test で YJIT を切る

- 種類: Rails の既定値（`load_defaults 8.1` の項目。`new_framework_defaults_8_1.rb` の雛形にはない）/ 対象: RS・RP・OP（development・test。CI の test を含む）
- 何が変わるか: `config.yjit` が `true` → `!Rails.env.local?`（development・test で false）。Finisher の initializer `:enable_yjit` が YJIT を有効にしなくなり、`RubyVM::YJIT.enabled?` が true → false になる（production は true のまま）
- なぜ: development・test はコードの読み直しやメソッドの差し替え（モックなど）が多く、YJIT で速くならないことが多いため（rails/rails#53746）
- 3 アプリへの影響: 速さだけで、動きは変わらない。テストの件数と結果は同じで、OP のテストの時間は 0.56 秒 → 0.48 秒（1 回ずつの計測）。Step 5 で `load_defaults 7.2` から有効にした YJIT（DEF-7.2-26）を、development・test では切る形になる。手動確認の Puma の起動の出力は verify で見る
- 扱い: 追随
- 出典: `railties-8.1.4/lib/rails/application/configuration.rb:346-349`、`railties-8.1.4/lib/rails/application/finisher.rb:230-235`、ガイド「3.2.63 config.yjit」
- コミット: `load_defaults 8.1`（RS・RP・OP）

## verify で見つけたもの

### DEF-8.1-29: 起動のたびに、Active Storage が image_processing gem がないことをログに出す

- 種類: Rails の既定値 / 対象: RS・RP・OP（全環境のログ）
- 何が変わるか: 起動のたびに、Rails のログ（development.log・test.log など）に WARN が 1 行出る。「Generating image variants require the image_processing gem. Please add `gem "image_processing", "~> 1.2"` to your Gemfile or set `config.active_storage.variant_processor = :disabled`.」
- なぜ: 8.1 で、Active Storage の engine が after_initialize で画像の変換の部品（`ActiveStorage.variant_transformer`）を起動時に読むようになり、読めないときは警告を出す（rails/rails#55303。CHANGELOG は、警告を消すには `variant_processor = :disabled` にすると書く）。3 アプリの `variant_processor` は `load_defaults 7.0` の `:vips` で、image_processing gem がないので読めない。8.0.5.1 の engine は起動時に読まなかった
- 3 アプリへの影響: ログの 1 行だけで、例外にはならない。3 アプリは Active Storage を使っていない（RS は `rails/all`、RP・OP は `active_storage/engine` を require しているので読み込まれる）。Rails 8.1.4 にした rails-lock の時点から出ていたが、前後の比較の警告の数え方（`warning:`・`DEPRECATION` の行）には当たらず、verify の手動確認のサーバーの出力で気づいた
- 扱い: 追随（受け入れる。`variant_processor = :disabled` を足す案はとらず、使っていないフレームワークを読み込まないことを改善の候補にした。docs/IMPROVEMENTS.md の IMP-012。人間が判断）。TIPS.md の、手動確認のサーバーの出力の元からあるものの一覧に足した
- 出典: `activestorage-8.1.4/lib/active_storage/engine.rb:89-125`、`activestorage-8.0.5.1/lib/active_storage/engine.rb:91-105`、activestorage の CHANGELOG（8.1.0「Allow analyzers and variant transformer to be fully configurable」）、`railties-8.1.4/lib/rails/application/configuration.rb:255`
- コミット: なし（Rails 8.1.4 の lock から）
