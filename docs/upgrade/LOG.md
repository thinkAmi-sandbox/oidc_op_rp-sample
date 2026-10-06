# アップグレード作業ログ

Step ごとの判断と、バージョン固有の知識を記録する。計画と進捗は [PLAN.md](PLAN.md) を参照する。

> 記録する前に、[CLAUDE.md](../../CLAUDE.md)「公開物への記載ルール」に沿って、ローカルのパス・トークン・秘密情報を置き換えること。
> スタックトレースは全文を貼らず、エラークラス・メッセージ・アプリ側の行（相対パス）・最初の gem の行だけを残す。

## 記録のテンプレート

```markdown
## Step X: <内容>（YYYY-MM-DD）

- ブランチ / PR: `upgrade/...` / <PR へのリンク>
- バージョン: Ruby a.b.c → x.y.z / Rails a.b.c → x.y.z

### 作業計画からの変更点

### `app:update` で採用したもの・戻したもの

| ファイル | 判断 | 理由 |
|---|---|---|

### 非推奨警告と対応

| 警告 | 対応 |
|---|---|

### gem ごとの対応

| gem | バージョン | 対応 |
|---|---|---|

### 意図的な仕様変更

### 遭遇した問題

（エラークラス・メッセージ・関係する行だけを残す）

### 確認結果

- minitest: OP xx runs / RP xx runs / RS xx runs、0 failures
- E2E: xx passed
- RuboCop / bundler-audit / brakeman / 安全チェック: 新しい指摘なし
```

## 準備: 計画と公開物の安全チェック（2026-10-06）

- ブランチ: `upgrade/prep-plan-and-safety`
- バージョン: 変更なし（Ruby 3.0.1 / Rails 6.1.4）

### 実施内容

- タグ `rails-6.1` を `main` に付け、`epic/rails-8.1-upgrade` を作成
- リポジトリ直下の `Gemfile` / `Gemfile.lock` を削除。最初のコミットで `rails new` を実行するために置かれたもので、各アプリはそれぞれの Gemfile を使っている
- `.gitignore` に `.DS_Store` を追加
- 公開物の安全チェックを追加
  - 検査本体 `scripts/check-public-safety` を 1 本にまとめ、git hooks（`.githooks/pre-commit`、`.githooks/commit-msg`）と Claude Code hooks（`.claude/settings.json`）の両方から呼ぶ
  - git hooks は誰が操作しても止められる最後の関門。Claude Code hooks は書いた直後の検出と、git hooks では見られない PR 本文の検査、`--no-verify` の阻止を担う
  - macOS 標準の Ruby でも動くよう、Ruby 2.6 の構文の範囲で書いた
- `CLAUDE.md`、`docs/upgrade/PLAN.md`、本ファイルを追加

### 判断

- `.public-safety-allow` に、`rails_open_id_provider/config/initializers/doorkeeper_openid_connect.rb` のコメント内にある鍵の書式例を登録した（鍵の中身は含まない誤検出）
- `rails_open_id_provider/jwtRS256.key.example` はコミット済みのサンプル秘密鍵で、安全チェックで検出される。今回は除外せず、扱いは Step 0-c で判断する
- ローカルに残っている過去の計画ブランチ `feature/rails_migration_plan` は参照せず、知見も取り込まない。過去の前提に引きずられるのを避けるため

### 遭遇した問題

- PR 本文（日本語）を安全チェックにかけたところ、`ArgumentError: invalid byte sequence in US-ASCII` で停止した
  - 原因: git hooks や Claude Code hooks は `LANG` 未設定で呼ばれることがあり、その場合 Ruby はファイル・標準入力・コマンドライン引数を US-ASCII として扱う
  - 影響: 日本語のコミットメッセージで commit-msg hook が修正案を出せずに停止していた（コミット自体は止まるので安全側ではある）。ファイル全体と差分の検査は UTF-8 として読み直していたので影響なし
  - 対応: ファイル・標準入力・引数・git の出力を明示的に UTF-8 として扱うよう修正。`LANG` を外した状態で、日本語のメッセージと PR 本文が検査できることを確認した

## Step 0-a: 起動できる状態に戻す（2026-10-06）

- ブランチ / PR: `upgrade/step0a-boot-ruby31` / [#10](https://github.com/thinkAmi-sandbox/oidc_op_rp-sample/pull/10)
- バージョン: Ruby 3.0.1 → 3.1.7 / Rails 6.1.4（RS は 6.1.4.1）→ 6.1.7.10
- 環境: macOS (arm64)、Apple clang 17、Ruby は mise（ruby-build）で Homebrew の OpenSSL 3 を使ってビルド

### 作業計画からの変更点

- 計画になかった gem の更新が必要になった。Ruby 3.1 そのものより、OpenSSL 3 と clang 17 が原因のものが多い（下の「gem ごとの対応」）
- 公開物の安全チェックに、認可コード・トークン・client_secret の値をキー名で検出するルール（`oauth-param`）を追加した。doorkeeper が発行するこれらの値は JWT ではないランダムな文字列で、既存の `jwt` ルールでは検出できないため
- OP の `filter_redirect` は追加しなかった（下の「ログへの出力」）

### mise での Ruby の選択

- mise は既定で `.ruby-version` を読まない（`idiomatic_version_file_enable_tools` が空）。利用者のグローバル設定に依存させないよう、各アプリに `mise.toml` を置いて有効にした
- プロジェクトの `mise.toml` は信頼されるまで読まれない。各アプリで初回に `mise trust` が必要
- mise は Ruby のバージョンについて Gemfile の `ruby` 指定も読み、`.ruby-version` より優先する。`.ruby-version` だけを 3.1.7 にした段階では 3.0.1 が選ばれ、3.0.1 の自動インストールが始まって失敗した。両方を同じ値に保つ
- Bundler 2.3.27（Ruby 3.1.7 付属）で lock を書き直すと、BUNDLED WITH は自動で 2.3.27 になる

### 非推奨警告と対応

| 警告 | 対応 |
|---|---|
| `Calling DidYouMean::SPELL_CHECKERS.merge!(error_name => spell_checker) has been deprecated`（起動時、3 アプリ） | 発生元は thor 1.1.0（railties 経由）。起動には影響しないので 0-f で対応（PLAN.md 7 章に追加） |

### gem ごとの対応

| gem | バージョン | 対応 |
|---|---|---|
| rails 一式 | 6.1.4 → 6.1.7.10 | `bundle lock --update rails --conservative` では上がらない（actionpack などが他の gem と共有されているため）。Rails の構成 gem をすべて並べて `--conservative` で更新した |
| mail | 2.7.1 → 2.8.1 | Ruby 3.1 で net-smtp などが標準 gem から外れたため。`--conservative` でも 2.9.1 になったので、一時的に Gemfile で固定して 2.8.1 にし、固定は外した（以下「一時固定」） |
| nokogiri | 1.12.3 → 1.18.10 | 1.12 系は Ruby 3.1 のネイティブ版がなく、ソースからのビルド（mini_portile2）に切り替わってしまう。Ruby 3.1 で使える最新版にした。1.19 系でしか直らない advisory は Step 2 で解消 |
| sqlite3 | 1.4.2 → 1.7.3 | C 拡張が clang 17 でビルドできない（`-Wincompatible-function-pointer-types`、`-Wint-conversion`）。1.4 系最新の 1.4.4 も同じ。1.5 系以降はネイティブ版があるので、0-f の目標だった 1.x 最新に前倒しした |
| nio4r | 2.5.8 → 2.5.9 | clang 17 でビルドできないため、同じマイナー内のパッチ版に一時固定で更新 |
| msgpack | 1.4.2 → 1.4.5 | 同上 |
| jwt（RP のみ） | 2.2.3 → 2.5.0 | 下の「遭遇した問題」1。一時固定で更新し、Gemfile は変えていない。0-f で 2.x 最新にして Gemfile に明記 |
| json-jwt（OP のみ） | 1.13.0 → 1.14.0 | 下の「遭遇した問題」2。依存の bindata は `--conservative` でも 3.0 系に上がるため、2.4.10 に一時固定して据え置いた |
| concurrent-ruby | 1.1.9（据え置き） | 1.3.5 以上と Rails 6.1 の組み合わせは `Logger` 未定義で起動しないため、更新しない |
| ffi / puma / bootsnap / byebug / racc / websocket-driver / bcrypt / bindex | 据え置き | Ruby 3.1.7 と clang 17 でビルドできることを 1 つずつ確認した |

`bundle lock --add-platform arm64-darwin` を実行すると、ローカル固有の `arm64-darwin-24` も追加されるため、`--remove-platform arm64-darwin-24` で外した。既存の `x86_64-darwin-19` は残した。

### 遭遇した問題

1. RP の ID トークン検証が OpenSSL 3 で失敗する（事前に再現して確認）
   - `OpenSSL::PKey::PKeyError: rsa#set_key= is incompatible with OpenSSL 3.0`
   - アプリ側: `rails_relying_party_of_backend/lib/omniauth/strategies/my_op.rb:103`（`JWT::JWK::RSA.import(key).public_key`）
   - gem 側: `jwt-2.2.3/lib/jwt/jwk/rsa.rb:87`（`set_key`）
   - jwt は 2.5.0 で OpenSSL 3 に対応した（jwt #496。ASN.1 の DER から鍵を作る実装に変更）
2. OP のトークンエンドポイントが 500 を返し、RP のログインが `OAuth2::Error` で失敗する
   - `OpenSSL::PKey::PKeyError: rsa#set_key= is incompatible with OpenSSL 3.0`
   - gem 側: `json-jwt-1.13.0/lib/json/jwk.rb:106`（`to_rsa_key` の `set_key`）。呼び出し元は `doorkeeper-openid_connect-1.8.0/lib/doorkeeper/openid_connect/id_token.rb:34`（ID トークンへの署名）
   - 署名の経路では JWK から RSA 鍵を組み立て直すため失敗する。discovery と JWKS は鍵から JWK を作る向きだけなので成功していて、事前の調査では見落としていた
   - json-jwt は 1.14.0 で OpenSSL 3 に対応した（json-jwt #100）。CVE-2023-51774（1.15.3.1 / 1.16.6 で修正）は残るが、OP は json-jwt で署名するだけで外から来た JWT を decode しないこと、ローカル専用であること、0-f で doorkeeper-openid_connect と一緒に外れる見込みであることから、1.14.0 に留めた
3. `bin/rails runner ... | tail` が終わらない
   - 初回に起動した spring サーバーが出力のパイプを開いたまま常駐するため、`tail` が終わらない。spring 2.1.1 は Ruby 3.1 で動く。確認でパイプを使うときは `DISABLE_SPRING=1` を付ける
4. RP のトップページが 500（`ActiveRecord::PendingMigrationError`）
   - クローン直後で DB を作っていなかっただけ。`bin/rails db:setup` で解消

### ログへの出力

- 3 アプリの `filter_parameters` に `:code` を追加した。`access_token`・`id_token`・`refresh_token`・`client_secret` は既存の `:token`・`:secret` の部分一致で対象済み。`code_verifier`・`code_challenge` も `:code` の部分一致で伏せられる
- 手動確認の後、3 アプリの `log/development.log` を安全チェックのルールで検査した。RP と RS は伏せられていない値なし。OP には次の 2 種類が残る。どちらもローカル専用のため許容し、公開物には安全チェックで混入を防ぐ
  - 「Redirected to」の行のクエリ（`code=<AUTH_CODE>`）。Rails 6.1〜7.1 はリダイレクト先に `filter_parameters` を適用しない（`actionpack-6.1.7.10/lib/action_dispatch/http/filter_redirect.rb`）。Rails 7.2 で適用されるようになるので、Step 5 で確認する
  - トークン要求の Parameters の `redirect_uri` の値。RP（omniauth-oauth2 1.7.1）がコールバック URL を `?code=<AUTH_CODE>&state=...` 付きのまま `redirect_uri` に入れて送るため、キー名で判定する `filter_parameters` では伏せられない。元からの挙動なので、アップグレード中は変えない

### 確認結果

- 3 アプリとも `bin/rails c` と `bin/rails s` が起動する（Rails 6.1.7.10、Puma 5.4.0、Ruby 3.1.7）
- OP の discovery は issuer `http://localhost:3780`、署名アルゴリズム RS256。JWKS は `kty: RSA`、`use: sig`、`alg: RS256`
- 手動確認（アプリ内ブラウザ、ローカルで作ったテスト用ユーザーと Doorkeeper アプリケーション 3 つ）
  - ログイン: RP → OP でログイン → 同意 → RP に戻り「ログインしました」とユーザーのメールアドレスが表示される（RP 側の nonce と ID トークンの検証も通過）
  - リソース取得: introspection 用 RP でログイン → RS の introspect が `active: true` → RS が 200 でりんごの情報を返す
  - 改ざんしたトークン: introspect が `active: false` → RS が 401
  - トークン失効: revoke が 200 → introspect が `active: false` → RS が 401
  - ログアウト: 「ログアウトしました」が表示され、ログインボタンに戻る
- minitest・E2E・RuboCop・bundler-audit・brakeman は 0-c / 0-d で導入するため未実施

### コードレビュー（`/code-review`）

| 指摘 | 対応 |
|---|---|
| `oauth-param` ルールが、introspection / revocation の `token=`、`Authorization: Bearer`、Ruby のシンボルキー（`code: "..."`）を見逃す | 検出対象に追加した |
| 検出時の表示に値の先頭 4 文字が出る | 値は表示しないようにした |
| `id_token=eyJ...` が jwt ルールと二重に報告される | `eyJ` で始まる値は jwt ルールに任せた |
| `mise.toml` のコメントが「`.ruby-version` が正本」と書いているが、mise は Gemfile を優先する | コメントを実際の挙動に合わせた |
| `:code` は部分一致なので `code_challenge_method` なども伏せられ、デバッグしにくい | 対応しない。計画で部分一致と決めており、伏せすぎる不便より漏れにくさを優先する |
- 安全チェック: `oauth-param` ルールの追加後、追跡しているファイル全体で新しい検出なし

## Step 0-b: アクセストークンの有効期限を 10 分にする（2026-10-06）

- ブランチ / PR: `upgrade/step0b-access-token-expiry` / （PR 作成後に追記）
- バージョン: 変更なし（Ruby 3.1.7 / Rails 6.1.7.10）

### 意図的な仕様変更

- OP のアクセストークンの有効期限を 1 分から 10 分にした（`rails_open_id_provider/config/initializers/doorkeeper.rb` の `access_token_expires_in`）
  - 理由: 一般的な長さに合わせる。1 分だと E2E のデバッグ中（Playwright の一時停止など）に期限切れになり、結果が不安定になる
  - トークン応答の `expires_in` が 60 から 600 になる。introspect の `exp` も発行から 600 秒後になる
- doorkeeper 5.5.2 ではこの値が認可コードフローとクライアントクレデンシャルフローの両方に使われる（`doorkeeper-5.5.2/lib/doorkeeper/oauth/authorization/token.rb:27`、`doorkeeper-5.5.2/lib/doorkeeper/oauth/client_credentials/issuer.rb:35`）。RS が introspection 用に取るトークンも 10 分になるが、RS はリクエストのたびに取り直すので挙動は変わらない
- 変えなかったもの
  - ID トークンの有効期限（doorkeeper-openid_connect の `expiration`）。未設定のままで、gem の既定値 120 秒（`doorkeeper-openid_connect-1.8.0/lib/doorkeeper/openid_connect/config.rb:126`）
  - 認可コードの有効期限（`authorization_code_expires_in`）。未設定のままで、doorkeeper の既定値 10 分
  - 変更前に発行されたトークンは、DB の `expires_in` が 60 のまま残るので、1 分で失効する
- RP と RS には、アクセストークンの `expires_at` や `exp` を見る処理がなく、アクセストークンの期限は OP の introspect だけで判断している。RP と RS のコードは変えていない
  - ID トークンの `exp` は、RP の独自ストラテジーが検証している（`rails_relying_party_of_backend/lib/omniauth/strategies/my_op.rb` の `verify_expiration: true`）。ID トークンの有効期限は変えていないので影響しない

### 期限切れの確認方法の変化

- `rails_relying_party_of_backend/app/controllers/introspections_controller.rb` に、コメントアウトされた期限切れの確認（`sleep 70` の後に RS を呼ぶ）がある。有効期限 1 分を前提にした手動確認の名残で、10 分にした後はコメントを外しても期限切れを再現できない
- 0-b ではコードを変えない（実行されないコードで、この Step の対象は OP の設定だけのため）。PLAN.md 0-d に次の 2 つを追加した
  - OP の introspect の期限切れのテストは、境目の 2 本（10 分ちょうどは有効、1 秒過ぎると無効）にして、10 分という値をテストに残す。doorkeeper 5.5.2 の判定は `Time.now.utc > created_at + expires_in`（`doorkeeper-5.5.2/lib/doorkeeper/models/concerns/expirable.rb:11`）で、ちょうどの時点はまだ有効
  - そのテストを追加する PR で、上のコメントアウトのコードを削除する。期限切れの判定は OP の minitest、`active: false` の拒否は RS の minitest、3 アプリの通しは E2E の revoke で置き換わる
- E2E では期限切れを待たない。`travel_to` は別プロセスの OP には効かず、10 分待つのも現実的でないため、0-c の計画どおり revoke で同じ経路（introspect が `active: false`）を確認する

### 遭遇した問題

1. 手動確認の途中で、OP のサーバーのログに finalizer の警告が 1 回出た（発生箇所はファイル監視の仕組みで、0-b で変えた doorkeeper の設定とは経路が異なる）
   - `warning: Exception in finalizer`、`ThreadError: can't be called from trap context`
   - gem 側: `activesupport-6.1.7.10/lib/active_support/evented_file_update_checker.rb:94`（finalizer）→ `listen-3.6.0/lib/listen/fsm.rb:80`（`Mutex#synchronize`）
   - development の `config.file_watcher` は `ActiveSupport::EventedFileUpdateChecker`（`rails_open_id_provider/config/environments/development.rb`）。このオブジェクトが GC されるときに finalizer が listen の `stop` を呼び、`stop` の中の `Mutex#synchronize` が finalizer の中では使えないため失敗する
   - finalizer の中の例外は警告になるだけで、リクエストの処理は止まらない。観測は 1 回だけで、どのリクエストの最中に出たかは特定していない。手動確認の流れはすべて期待どおりの結果だった
   - 0-a で出ていたかは記録がなく、比べる基準はない。listen を更新する 0-f で、出なくなるかを確認する（PLAN.md 7 章に追記）
2. 自動モードの Claude Code は、OP のログイン画面にテスト用ユーザーのパスワードを入力できなかった（安全判定で拒否される）。ログインと同意は人間が操作し、その後の確認を Claude Code が続けた
   - 同意画面は、同じアプリ・ユーザー・scope で revoke されていないトークンがあると省かれる（`doorkeeper-5.5.2/app/controllers/doorkeeper/authorizations_controller.rb:26` の `matching_token?`。期限切れかどうかは見ない）。0-a で同意済みの `my_op` 用 RP は同意画面が出ず、0-a の最後に revoke した introspection 用 RP は出た

### 確認結果

- OP の `bin/rails c` と `bin/rails s` が起動する。`Doorkeeper.config.access_token_expires_in` は 600、`Doorkeeper::OpenidConnect.configuration.expiration` は 120
- クライアントクレデンシャルフローで RS 用のトークンを取り、70 秒待ってから introspect した

  | | トークン応答の `expires_in` | 70 秒後の introspect |
  |---|---|---|
  | 変更前 | 60 | `active: false` |
  | 変更後 | 600 | `active: true`、`exp - iat = 600` |

- 手動確認（アプリ内ブラウザ。ログインと同意は人間が操作）
  - ログイン: RP → OP でログイン → RP に戻り「ログインしました」とユーザーのメールアドレスが表示される。発行されたトークンの DB 上の `expires_in` は 600
  - リソース取得: introspection 用 RP でログイン → 同意 → RS の introspect が `active: true`（`exp - iat = 600`）→ RS が 200 でりんごの情報を返す
  - 改ざんしたトークン: introspect が `active: false` → RS が 401
  - トークン失効: revoke が 200 → introspect が `active: false` → RS が 401
  - ログアウト: 「ログアウトしました」が表示され、ログインボタンに戻る
- minitest・E2E・RuboCop・bundler-audit・brakeman は 0-c / 0-d で導入するため未実施

### コードレビュー（`/code-review`）

| 指摘 | 対応 |
|---|---|
| 「RP と RS には `exp` を見る処理がない」とあるが、RP は ID トークンの `exp` を検証している | アクセストークンに限った記述だと分かるように直し、ID トークンの検証は影響しないことを追記した |
| finalizer の警告を「0-b と無関係」「そのリクエストも正常に終わった」と書いているが、どのリクエストかは確かめていない | 確かめた範囲（発生箇所、観測 1 回、0-a の基準なし）に合わせて書き直した |
| `doorkeeper.rb` のコメントに変更の経緯（以前は 1 分）まで書いていて、LOG.md やコミットメッセージと重複する | 今の意図（10 分にする理由）だけを残した |
| OP の設定変更のコミットメッセージが、まだない E2E を現在形で書いている | 対応しない。直前のコミットではなく、直すには履歴の書き換えが必要なため。E2E は 0-c で導入する計画で、記述の意図は本ファイルと PLAN.md で追える |
