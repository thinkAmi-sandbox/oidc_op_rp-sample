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
- なぜ: (a) は DEF-8.0-02 の不具合（rails/rails#58145）が 8.1.4 で直ったため（8-1-stable の #58147。initializer `action_controller.live_streaming_excluded_keys` の中身が `on_load(:action_controller_live)` に入った）。(b) は、8.1 で `ActiveModel::Error` に load hook が足され（#55347）、見えるようになっただけ。読み込みの時期は 8.0.5.1 と同じで、`active_record/errors.rb` の `UnknownAttributeError = ActiveModel::UnknownAttributeError` が、require の時点で `active_model/errors` を読む（load hook に `caller` を仕込んで確かめた）
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
