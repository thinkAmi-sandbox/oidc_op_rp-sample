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

- ブランチ / PR: `upgrade/step0b-access-token-expiry` / [#11](https://github.com/thinkAmi-sandbox/oidc_op_rp-sample/pull/11)
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

## Step 0-c: E2E と OP の応答のスナップショット（2026-10-07）

- ブランチ / PR: `upgrade/step0c-e2e-baseline` / [#12](https://github.com/thinkAmi-sandbox/oidc_op_rp-sample/pull/12)
- バージョン: 変更なし（Ruby 3.1.7 / Rails 6.1.7.10）。E2E 用に Node 24.21.0 を mise で固定

### 作業計画からの変更点

計画の段階で調べた事実をもとに、PLAN.md の 0-c から次のように変えた（作業計画として承認済み）。

| 項目 | PLAN.md の当初の記述 | 実際 | 理由 |
|---|---|---|---|
| 署名鍵 | E2E の準備で毎回生成 | `jwtRS256.key` がなければ生成し、あれば手動確認用の鍵を使う | 鍵のパスは `Rails.root.join('jwtRS256.key')` に固定（`rails_open_id_provider/config/initializers/doorkeeper_openid_connect.rb`）。毎回生成すると手動確認用の鍵を上書きし、避けるには OP のコードの変更が必要になる。`kid` と `n` は比較で伏せるので、共用しても結果は変わらない |
| 環境変数のファイル | `.env_e2e_template` のような名前 | `.env_e2e` | コピーして使うひな形ではなく、E2E がそのまま読んで渡すため |
| テスト用ユーザー | 1 人 | シナリオごとに 1 人（4 人） | doorkeeper は同じアプリ・ユーザー・scope の未 revoke のトークンがあると同意画面を省く（LOG.md の Step 0-b「遭遇した問題」2）。共用すると、同意画面の有無が実行順や単独実行で変わる |
| リソース取得 | りんごの情報が表示される | E2E から RS を直接呼んで確かめる | RP の introspection 画面は RS の応答を表示せず、標準出力に `puts` するだけ（`rails_relying_party_of_backend/app/controllers/introspections_controller.rb`）。画面に出すのは RP が revoke した後のアクセストークン |
| 起動スクリプト | アプリごとに 3 本 | `e2e/scripts/start-server.sh` の 1 本 | 中身がほぼ同じため、引数（`op` / `rp` / `rs`）で分けた |
| 最小の起動確認の spec | スナップショットに吸収 | `e2e/tests/servers.spec.ts` として残す | 起動の失敗が分かりやすい。RS がトークンなしのリクエストを 401 で拒否することは、ほかのシナリオでは確かめていない |

計画になかった作業:

- RP の `.env_template` の `ISSUER_OF_MY_OP=my_op` を `http://localhost:3780` に直した。RP の独自ストラテジーは ID トークンの `iss` をこの値と比べるので、ひな形のままでは検証に失敗する（手元の `.env` は正しい値だった）
- `.public-safety-allow` に、`.env_e2e` のダミーの secret の除外を追加した（人間が承認）。`oauth-param` ルールはキー名で判定するため、ダミー値かどうかを区別できない。除外の範囲は `oauth-param` ルール、RP / RS の `.env_e2e`、値が `e2e-dummy-` で始まる行だけ。同じファイルに本物らしい値を書くと検出されることを確認した

### 判断

- `rails_open_id_provider/jwtRS256.key.example` と `.pub.example` は削除した（PLAN.md 14 章の未決事項）。中身は BEGIN 行・`...`・END 行の 3 行だけのプレースホルダーで、最初のコミットから変わっておらず、どこからも参照されていなかった。「準備」の節で「コミット済みのサンプル秘密鍵」と書いたのは実態と違っていた
- `.claude/launch.json`（手動確認用に 3 アプリを起動する Claude Code の設定）はコミットし、E2E の起動設定とはまとめなかった。E2E は E2E 用の DB と環境変数を渡し、Playwright が起動と停止を管理するので、目的が違う。同じポートを使うので同時には動かせない
- PR は分けず 1 つにした（人間の判断）。区別はコミットの単位でつける

### E2E の構成

- 3 アプリは development 環境のまま起動し、`DATABASE_URL=sqlite3:db/e2e.sqlite3` で E2E 専用の DB に切り替える。起動のたびに OP / RP は `db:drop db:setup`、RS は `db:drop db:create`（RS には `schema.rb` もマイグレーションもない）
  - Rails 6.1 は `DATABASE_URL` があると、development での `db:drop` などで test DB を対象にしない（`activerecord-6.1.7.10/lib/active_record/tasks/database_tasks.rb:500`）
  - 起動スクリプトは、`DATABASE_URL` に `e2e` が含まれないときは `db:drop` の前に止まる
- RP / RS の環境変数は `.env_e2e` を Playwright の設定で読み、`webServer.env` で渡す。dotenv 2.7.6 は既存の環境変数を上書きしないので、手元の `.env` より優先される。Playwright 1.63.0 は `webServer.env` を `process.env` と合わせて渡す
- ポートは手動確認用と同じ 3780〜3782（issuer や RS の URL がコードに固定されているため）。`reuseExistingServer: false` にして、手動確認用のサーバーが動いているときに、その DB へ E2E を流さないようにした。Playwright は 200〜403 の応答を起動済みとみなすので、トークンなしでは 401 を返す RS も起動待ちに使える
- テストは 1 つずつ流す（`workers: 1`）。3 アプリは 1 プロセスずつで、DB は sqlite のため
- スナップショットの取得と、リソース取得・トークン失効のシナリオでは、E2E 自身が `my_op` 用 RP のクライアントとして認可コードフローを行う（RP と同じく scope `openid`、nonce、PKCE S256）。RP のコールバック URL へのリダイレクトは `page.route` で横取りするので、RP 本体には認可コードが届かない。introspect は RS と同じく、RS のクライアントのクライアントクレデンシャルのトークンを付けて呼ぶ
- OP の応答のスナップショットは、Playwright の `toMatchSnapshot` で `e2e/baseline/` に保存する（`snapshotPathTemplate` でプラットフォーム名を付けない）。`updateSnapshots: "none"` にして、スナップショットがないときに黙って作らないようにした。項目の順番の違いを差分にしないよう、キーは並べ替えて保存する
- 伏せた値は `<TIMESTAMP:number>` のように JSON の型を残す。gem の更新で `sub` が数値になるなど、型が変わったことを差分として検出するため。認可コードフローの 6 つの応答は `expect.soft` で比べ、最初の差分で止まらずにすべて報告する

### 導入したもの

| もの | バージョン | 備考 |
|---|---|---|
| Node.js | 24.21.0 | `e2e/mise.toml`。初回は `e2e/` で `mise trust` |
| `@playwright/test` | 1.63.0 | ブラウザは Chromium（Chrome for Testing 153.0.8010.12）だけ |
| `@types/node` | 24.19.1 | Node のメジャーに合わせる |
| `oxlint` | 1.87.0 | |
| `oxlint-tsgolint` | 7.0.2003 | 型情報を使うモード |
| `oxfmt` | 0.72.0 | `printWidth: 100` を明示 |
| `eslint-plugin-playwright` | 2.12.1 | oxlint の JS プラグイン（アルファ版）で読み込む |
| `eslint` | 10.12.0 | `eslint-plugin-playwright` の必須の peer dependency なので、npm が自動で入れる。直接は使わないが、JS プラグインで問題が出たときの切り替え先になるので、`--legacy-peer-deps` で外さずに lockfile に残した |

`e2e/.npmrc` に `save-exact=true` を置き、バージョンを `^` なしで固定した。

### oxlint / oxfmt の確認

- わざと違反を入れた spec で、次の指摘が出ることを確かめてから削除した
  - `await` の付け忘れ: `typescript(no-floating-promises)`（型情報を使うモード）と `playwright(missing-playwright-await)`
  - `test.only`: `playwright(no-focused-test)`
  - `page.waitForTimeout`: `playwright(no-wait-for-timeout)`
  - Web ファーストでないアサーション（`expect(await locator.isVisible()).toBe(true)`）: `playwright(prefer-web-first-assertions)`
- `options.denyWarnings` を有効にしたので、警告だけでも終了コードは 1 になる。違反がなければ 0
- JS プラグインでは、プラグインの設定（`recommended`）を継承できない。`eslint-plugin-playwright` の `flat/recommended` のルールを `.oxlintrc.json` に書き写した
- oxlint は違反がないと何も出力しない。`--format=json` で、4 ファイルを 147 ルールで検査していることを確認した
- oxfmt は `e2e/baseline/` を対象外にした。整形でスナップショットの書式が変わり、比較が失敗するのを防ぐため

### 遭遇した問題

1. Playwright はスナップショットのファイル名の `_` を `-` に置き換える（`id_token_header.json` が `id-token-header.json` になった）。コードの側の名前もファイル名に揃えた
2. ポートが使われていて、discovery の URL が 404 などを返すとき（別のサーバーが使っているとき）は、OP の起動が `Errno::EADDRINUSE`（`Address already in use - bind(2) for "127.0.0.1" port 3780`）で失敗し、テストは流れない。discovery の URL が 200 を返すとき（手動確認用の OP が動いているとき）は、Playwright が起動スクリプトを呼ぶ前に「is already used, make sure that nothing is running on the port/url」で止まる。discovery に 200 を返すダミーのサーバーで確認した

### 確認結果

- E2E: 10 passed。2 回続けて流して両方通る（DB の作り直しの確認）。spec を 1 つずつ単独で流しても通る（実行順に依存しないことの確認）
- スナップショットとの比較: `expires_in` を書き換えると差分（60 と 600）で失敗し、ファイルがないと「A snapshot doesn't exist」で失敗する
- スナップショットの内容: discovery の issuer は `http://localhost:3780`、署名アルゴリズムは RS256。JWKS は `kty: RSA`、`alg: RS256`、`use: sig`、`e: AQAB`。ID トークンの項目は `aud`・`exp`・`iat`・`iss`・`nonce`・`sub`（`email` は userinfo だけに入る）で、`exp - iat` は 120。トークン応答の `expires_in` は 600、`refresh_token` はなし。introspect の `exp - iat` は 600、revoke 後は `{"active": false}` だけ
- 手動確認用の環境は変わっていない: 作業の前後で、OP / RP の development DB の件数と、3 アプリの development DB・`jwtRS256.key`・RP / RS の `.env` のハッシュが一致する
- 3 アプリとも `bin/rails runner` で起動する（Rails 6.1.7.10、Ruby 3.1.7）。`bin/rails s` は E2E の起動で確認
- oxlint・oxfmt・安全チェック: 指摘なし
- minitest・RuboCop・bundler-audit・brakeman は 0-d で導入するため未実施

### コードレビュー（`/code-review`）

| 指摘 | 対応 |
|---|---|
| 伏せる値のプレースホルダーに型がなく、`sub` が文字列から数値になるような変化を検出できない | プレースホルダーに型を残した（`<USER_ID:string>`、`<TIMESTAMP:number>` など）。スナップショットを作り直した |
| 伏せるキーの判定に `in` 演算子を使っていて、`constructor` などの `Object.prototype` のキーにも一致する | `Object.hasOwn` に変えた |
| 認可コードフローのスナップショットの比較が 1 つのテストにまとまっていて、最初の差分で止まる。CLAUDE.md の「1 テスト 1 振る舞い」にも反する | 6 つの比較を `expect.soft` にして、差分をすべて報告するようにした。スナップショットを 2 つ書き換えて、両方が報告されることを確認した。応答は 1 回の認可から得るものなので、「認可コードフローの応答がスナップショットと一致する」を 1 つの振る舞いとし、テストは分けなかった |
| ログアウトのシナリオの `toHaveURL`（RP のトップページ）が、遷移の前から満たされていて何も確かめていない | 削除した。遷移の後にしか出ない flash の表示で確かめている |
| seeds のパスワードがトップレベルの定数で、同じプロセスで 2 回読むと警告が出る | ローカル変数にした。同じプロセスで 2 回読み込んで、警告が出ず、重複も作られないことを確認した |
| OP がエラーで戻したとき、認可コードがないという失敗しか出ず、原因が分からない | 対応しない。不正な scope で試すと、doorkeeper 5.5.2 はコールバックへリダイレクトせずにエラー画面を出し、その画面は失敗時に Playwright が保存するページの内容（`error-context.md`）に残った。コールバックにエラーが付いて戻るのは同意画面で Deny を押したときで、E2E では押さない |
| ダミーの client_id / secret・ユーザー・パスワードが seeds、`.env_e2e`、`e2e/support/users.ts` に重複している | 対応しない。seeds が E2E のファイルを読むと、OP が `e2e/` に依存する。食い違えばログインやトークンの取得で E2E が失敗するので、気づける |
| `e2e/tests/servers.spec.ts` の discovery の確認が、スナップショットの比較と重複している | 対応しない。起動の失敗が分かりやすい確認として残すと決めた（「作業計画からの変更点」） |
| introspect のたびに RS のクライアントでトークンを取り直している | 対応しない。RS と同じ呼び方を再現するためで、E2E 用の DB は毎回作り直す |

## Step 0-d-1: 静的解析と脆弱性チェックの導入（2026-10-07）

- ブランチ / PR: `upgrade/step0d-lint-audit-tests` / [#13](https://github.com/thinkAmi-sandbox/oidc_op_rp-sample/pull/13)
- バージョン: 変更なし（Ruby 3.1.7 / Rails 6.1.7.10）

### 作業計画からの変更点

計画の段階で調べた事実をもとに、PLAN.md の 0-d から次のように変えた（作業計画として承認済み）。

| 項目 | PLAN.md の当初の記述 | 実際 | 理由 |
|---|---|---|---|
| PR の単位 | 0-d で 1 PR | 0-d-1（静的解析と脆弱性チェック）と 0-d-2（minitest）の 2 PR | bundler-audit の無視リストが 1 アプリ 93〜94 件になり、理由を添えた一覧だけでレビューの量が大きい。テストとはレビューの観点も違う |
| bundler-audit の既存の advisory | 0-a で残した nokogiri と json-jwt の 2 件を無視リストに入れる | 1 アプリ 93〜94 件（20〜21 gem）をすべて無視リストに入れ、gem ごとに解消する時期を書いた | 下の「bundler-audit」 |
| RS の既存のテスト | 0-d のテストに含める | 0-d-1 の最初のコミットで「トークンなしは 401」に直した | 下の「遭遇した問題」1。テストが通らない状態でコミットしないため、最初に直した |

### 導入したもの

| gem | バージョン | 備考 |
|---|---|---|
| rubocop | 1.91.0 | 3 アプリとも development / test グループに `require: false`。rubocop 系はバージョンを固定 |
| rubocop-minitest | 0.41.0 | |
| rubocop-rails | 2.38.0 | |
| brakeman | 7.1.1 | 8.x は Ruby 3.1 では入らない |
| bundler-audit | 0.9.3 | advisory DB は `~/.local/share/ruby-advisory-db` |

- 依存として lock に新しく入った gem は 13 個（rubocop-ast、parser、prism、json など）。3 アプリとも Gemfile.lock の既存の行は変わっていない
- rubocop は json に依存する。そのままでは json 3.0.2 が lock に入り、アプリが今使っている Ruby 3.1.7 の default gem の json 2.6.1 が置き換わる。0-a と同じ一時固定で 2.6.1 にして、固定は外した（PLAN.md 7 章に追記）

### RuboCop

- リポジトリ直下の `.rubocop.yml` を各アプリの `.rubocop.yml` が継承し、各アプリは自分の `.rubocop_todo.yml` を持つ
- 直下の設定ファイルのパスは直下からの相対になるので、対象外は `**/config/**/*` の形で書き、`inherit_mode: merge: [Exclude]` で既定の除外（`vendor/**` など）も残した。各アプリの `vendor/bundle` に gem があるため。`rubocop --list-target-files` で、`config/`・`bin/`・`db/`・`vendor/` が対象外になっていることを確認した
- 既存の違反は `--auto-gen-config --no-exclude-limit` で凍結した。既定の上限（15 ファイル）を超えたルールは `Enabled: false` になり、新しいコードも検査されなくなるため。生成した todo に `Enabled: false` はない。新しいファイルを置くと検査されることを確認した

| アプリ | 凍結した違反 |
|---|---|
| RS | 38 件（13 ファイル、10 ルール） |
| RP | 58 件（18 ファイル、10 ルール） |
| OP | 68 件（12 ファイル、9 ルール） |

- 3 アプリとも Gemfile に `Bundler/OrderedGems` などの既存の違反がある。gem は既存の `group :development, :test` に足し、新しい `Bundler/DuplicatedGroup` を作らないようにした（RP と OP の `Bundler/DuplicatedGroup` は、annotate 用の 2 つ目の `group :development` による既存のもの）

### bundler-audit

- 無視リストは各アプリの `.bundler-audit.yml`。gem ごとのコメントに解消する時期、各行のコメントに修正版を書いた。1 行消すと、その advisory が報告されることを確認した
- 件数は RS 93、RP 93、OP 94。nokogiri と sqlite3 は lock の 2 つのプラットフォームの分だけ二重に報告されるが、無視リストには 1 回だけ書いた
- 解消する時期の内訳

  | 区分 | gem | 解消する時期 |
  |---|---|---|
  | Rails 6.1 系に修正版がない | actionpack | Step 1（7.0.8.7） |
  | | activerecord、activestorage の CVE-2025-24293 | Step 3（7.1.5.2） |
  | | actionview、activesupport、activestorage の残り | Step 5（7.2.3.1 / 7.2.3.2） |
  | Ruby や Rails の制約がある | concurrent-ruby | 1.3.5 以上は Rails 6.1 で起動しない（Step 0-a の gem ごとの対応）。Rails 7.0.8.7 の `active_support/logger_thread_safe_level.rb` も `logger` を require せず、require するのは 7.1.0 から。Step 3 の後 |
  | | devise（OP） | 修正版は 5.x だけで、5.x は Rails 7.0 以上が必要（railties >= 7.0）。Step 1 の後 |
  | | nokogiri | 1.19 系は Ruby 3.2 以上が必要。Step 2 |
  | | sqlite3 | 修正版は 2.x だけ。Step 5 |
  | 0-f で上げる予定のもの | oauth2、jwt、json-jwt（OP） | 0-f（PLAN.md 7 章のとおり） |
  | | doorkeeper（OP） | 修正版は 5.6.6 以上。doorkeeper-openid_connect 1.8.0 が doorkeeper 5.6 未満を要求するので、0-f で一緒に上げる |
  | Rails 6.1・Ruby 3.1 のまま上げられる | rack（2.2.23）、puma（5.6.9）、loofah（2.25.2）・crass（1.0.7）・rails-html-sanitizer（1.7.1）、websocket-driver（0.8.2）、globalid（1.0.1）、mail（2.9.1）、msgpack（1.8.2）、faraday（RP・RS、1.10.6）、bcrypt（OP、3.1.22） | 0-d-3（下の「判断」） |

- 「Rails 6.1・Ruby 3.1 のまま上げられる」は、Gemfile と lock のコピーで `bundle lock --update <gem> --conservative` を実行し、修正版以上に解決できることで確かめた（起動とテストはしていない）。rails-html-sanitizer は単独では loofah を据え置くため 1.4.3 止まりで、loofah・crass と一緒なら 1.7.1 になる。mail は logger、websocket-driver は base64 が新しく lock に入る
- 計画の段階で GitHub の advisory DB を照会した結果（24 gem・約 96 件）と、gem の顔ぶれはほぼ同じだった

### brakeman

- 3 アプリとも警告は同じ 3 件で、brakeman の既定の無視ファイル `config/brakeman.ignore` に `note` を付けて入れた
  - Ruby 3.1 のサポート終了（EOLRuby）と Rails 6.1 のサポート終了（EOLRails）: このアップグレードで解消する
  - rails-html-sanitizer の CVE-2022-32209（SanitizeConfigCve、Weak）: bundler-audit でも報告されるもの
- `config/` は RuboCop の対象外だが、`brakeman.ignore` は Ruby のコードではないので影響しない

### 判断

- Rails 6.1・Ruby 3.1 のまま上げられる gem は、脆弱性の修正だけのサブステップ 0-d-3 を新設して上げる（人間の判断）。0-d-2（minitest）の後、0-e の前に行う
  - 選択肢は「0-d-3 を新設する」と「0-f の周辺 gem の更新に含める」だった。Claude の見立ては新設で、理由は、rack と puma は外部からの入力を直接受けること、0-f は oauth2 や doorkeeper のような壊れやすいメジャー更新が中心で、混ぜると修正が遅れることだった
  - 名前は、LOG.md から何度も参照されている 0-e・0-f の番号を振り直さないよう、0-d-3 にした
  - 上げる先の版、default gem の置き換え（mail が logger、websocket-driver が base64 を lock に入れる）の扱いなどは、0-d-3 の着手時に調べて決める（PLAN.md の 0-d-3）

### 遭遇した問題

1. RS の既存のテスト（`rails_resource_server/test/controllers/apples_controller_test.rb`）は、トークンなしで `apples/show` を呼んで 200 を期待していて、401 で落ちていた（`1 runs, 1 failures`）。テストは、トークンを確かめる `before_action` を持つ `ApplesController` と同じコミットで追加された、ジェネレーターの生成物のままで、追加された時点から通っていなかった。テストは現在の挙動を記録するものなので、401 を期待するように直した。トークンが有効・無効の場合は introspect を WebMock で差し替える必要があるので、0-d-2 で書く
2. RS の `test/test_helper.rb` の `parallelize(workers: :number_of_processors)` のままでは、`bin/rails test` が終わらなかった（ワーカーのプロセスが消え、親プロセスが待ち続けた。3 分以上止まったので止めた）。`PARALLEL_WORKERS=1` では 0.03 秒で終わる。テストの件数が少なく、並列にする必要がないので `parallelize` の行を消した
3. `rubocop --auto-gen-config` は、各アプリの `.rubocop.yml` の `inherit_from` を `.rubocop_todo.yml` → `../.rubocop.yml` の順に書く。この順では、todo の Rails のルールを rubocop-rails のプラグインを読む前に読むので、`Error: Rails cops have been extracted to the rubocop-rails gem.` で止まる。直下の設定 → todo の順に直した

### 確認結果

- RuboCop: 3 アプリとも `no offenses detected`
- bundler-audit: 3 アプリとも `No vulnerabilities found`（無視リスト込み）
- brakeman: 3 アプリとも `Security Warnings: 0`、`Ignored Warnings: 3`
- minitest: RS 1 runs、0 failures。OP と RP にはまだテストがない（0-d-2 で追加する）
- E2E: gem を追加した各コミットの前に流して、どれも 10 passed
- 3 アプリとも `bin/rails runner` で起動し、development で RuboCop を読み込まない（`defined?(RuboCop)` が nil）。json は 2.6.1 のまま
- 手動確認用の環境は変わっていない: 作業の前後で、3 アプリの development DB・`jwtRS256.key`・RP / RS の `.env` のハッシュが一致する。RS の `db/test.sqlite3` は、計画の段階で RS のテストを流したときに作られた（gitignore 対象）

### コードレビュー（`/code-review`）

| 指摘 | 対応 |
|---|---|
| concurrent-ruby の解消時期を「Step 1（Rails 7.0）の後」としたが、Rails 7.0.8.7 の `activesupport-7.0.8.7/lib/active_support/logger_thread_safe_level.rb` も `logger` を require しない（require するのは 7.1.0 から）。1.3.5 以上は Rails 7.0 でも起動しない | 3 アプリの無視リスト、本ファイル、PLAN.md 7 章を「Step 3 の後」に直した。rails/rails の v7.0.8.7 と v7.1.0 のタグで、該当ファイルを見比べて確かめた |
| 「依存として lock に新しく入った gem は 20 個」は誤り。増えた spec は 18 個で、直接足した 5 個を除くと 13 個 | 13 個に直した |
| 0-d-1 の最初のコミットで書き換えた RS のテストの違反が、`.rubocop_todo.yml` に既存の違反として凍結されていた | テストを違反なしの書き方にし、todo を作り直した。`test/test_helper.rb` は生成物から行を消しただけなので、凍結に残した |
| PLAN.md の 0-d-2 に、まだない `.env.test` などを現在形で書いていた | 「予定:」と書き、`.public-safety-allow` への追記は承認を得てから行うこと、承認されない場合の代案も書いた |

## Step 0-d-2: minitest（2026-10-07）

- ブランチ / PR: `upgrade/step0d2-minitest` / [#14](https://github.com/thinkAmi-sandbox/oidc_op_rp-sample/pull/14)
- バージョン: 変更なし（Ruby 3.1.7 / Rails 6.1.7.10）

### 作業計画からの変更点

計画は前のセッションで承認済み。作業中に分かった事実をもとに、次のように変えた。

| 項目 | 計画 | 実際 | 理由 |
|---|---|---|---|
| RP の ID トークンの検証に失敗したとき | 例外になる（クラスをテストで確かめる） | `/auth/failure?message=...&strategy=my_op` へリダイレクトし、例外は `env['omniauth.error']` に残る。テストはリダイレクト・例外のクラス・セッションにユーザーがないことを確かめる | 下の「記録した挙動」1 |
| OP の「他クライアントのトークン」の 2 本 | RS のトークン（introspection scope あり）の場合と、introspection scope のない別アプリの資格情報の場合 | RS のトークンの場合は、有効なトークンのテストを兼ねた | RS と同じく、introspect のテストはすべて RS のトークンで問い合わせるため、同じリクエストのテストが 2 本になる |
| RP のテスト | 計画の項目 | 「認可要求のパラメーター（scope `openid`・nonce・PKCE S256）」と「トークン要求の `code_verifier` が `code_challenge` に対応すること」を追加 | 0-f の omniauth-oauth2 / oauth2 の更新で変わりやすい |
| RS のテスト | トークン要求と、introspect に `token` が渡ること | トークン要求の本文に client_id・client_secret が入ること（oauth2 1.4.7 の既定の `auth_scheme` は `:request_body`）も確かめる | 0-f の oauth2 の更新で既定値が変わる（PLAN.md 7 章） |
| OP の ID トークンの署名の検証 | 指定なし | json-jwt 1.14.0 の `JSON::JWT.decode` に、OP の JWKS から作った `JSON::JWK::Set` を渡す | OP には jwt gem がなく、json-jwt は doorkeeper-openid_connect の依存で入っている。CVE-2023-51774 は残るが、テストで OP 自身の JWKS を使うだけなので影響しない |
| RS の `test/test_helper.rb` | `fixtures :all` を書かない | 生成物の `fixtures :all`（fixture のファイルはない）を消し、違反なしに書き直して `.rubocop_todo.yml` から外した | 0-d-1 で凍結した 3 ルールの件数も合わせて減らした |

### 導入したもの

| gem | バージョン | 備考 |
|---|---|---|
| simplecov | 0.22.0 | 3 アプリとも test グループに `require: false`。1.x は Ruby 3.2 以上が必要 |
| webmock | 3.26.4 | 同上。外部への HTTP 通信はすべて遮断する |

- 依存として lock に新しく入った gem は 9 個（simplecov-html 0.13.2、simplecov_json_formatter 0.1.4、docile 1.4.1、addressable 2.9.0、public_suffix 6.0.2、crack 1.0.1、hashdiff 1.2.1、rexml 3.4.4、bigdecimal 3.1.1）。3 アプリとも Gemfile.lock の既存の行は変わっていない
- crack は bigdecimal に依存する。そのままでは bigdecimal 4.1.3 が lock に入り、Ruby 3.1.7 の default gem の 3.1.1 が置き換わる。0-a・0-d-1 と同じ一時固定で 3.1.1 にして、固定は外した
- rexml は Ruby 3.1.7 では default gem ではなく bundled gem（3.3.9）なので、3.4.4 が lock に入っても default gem の置き換えにはならない

### テストの土台

- 各アプリの `test/test_helper.rb` は、先頭で `SimpleCov.start 'rails'`、`config/environment` と `rails/test_help` の後に `webmock/minitest`。`parallelize` は書かない（Step 0-d-1「遭遇した問題」2）
- テストは `DISABLE_SPRING=1 bin/rails test` で流す。spring 経由ではアプリが SimpleCov より先に読み込まれ、起動時に読まれる `lib/omniauth/strategies/my_op.rb` などのカバレッジが取れない
- RP と OP には `test/` ディレクトリがなかったので、新しく作った。共通の手順は各アプリの `test/support/` のモジュールにまとめ、`test_helper.rb` で読み込む
- RP / RS のテスト用の環境変数は、ダミーの値の `.env.test` をコミットして渡す。RP の独自ストラテジーはクラス本体で `OIDC_PROVIDER_HOST` を、initializer で client_id / secret を、どちらも起動時に読むので、`test_helper.rb` で ENV を設定しても間に合わない
  - dotenv-rails 2.7.6 は test 環境で `.env.test` を `.env` より先に読み、先に読んだ値が勝つ。足りない変数は手元の `.env` から入ってしまうので、RP は 6 つ、RS は 3 つの変数をすべて書いた。test 環境で `.env.test` の値が読まれることを `bin/rails runner` で確かめた
  - 各アプリの `.gitignore` は `.env.*` を無視するので、末尾に `!.env.test` を足した
  - `CLIENT_SECRET_*=test-dummy-...` は安全チェックの `oauth-param` ルールで検出されるので、`.public-safety-allow` に RP / RS の `.env.test` の `=test-dummy-` を含む行の除外を追加した（人間が承認）。同じファイルに本物らしい値を書くと検出されることを確かめた
- OP だけ fixtures を使う。ユーザー 1 人と、`db/seeds.rb` と同じ 3 つの Doorkeeper アプリケーション。secret は `SecureRandom` で毎回作り、パスワードは `test_helper.rb` のダミーの定数から `Devise::Encryptor.digest` で作る
- OP は起動時に `jwtRS256.key` を読むので、手動確認用の鍵をそのまま使う。テストは鍵の中身に依存せず、JWKS を OP 自身から取って ID トークンを検証する。鍵がない環境（CI）での扱いは「仕上げ」で決める（PLAN.md）
- テスト環境の `config.active_support.deprecation` を `:raise` にした。切り替える前に、3 アプリのテストの出力に ActiveSupport の非推奨警告がないことを確かめた。thor 1.1.0 の `DidYouMean::SPELL_CHECKERS` の警告（Step 0-a）は Ruby が出すもので、`:raise` の対象にならない

### テストの構成

| アプリ | 件数 | 内容 |
|---|---|---|
| RS | 7 | `apples/show`: Authorization ヘッダーなし・`Bearer ` だけは 401。introspect が `active: true` なら 200 でりんごの情報、`active: false` や introspect 自体が 401 なら 401。トークン要求（`grant_type=client_credentials`、`scope=introspection`、本文の client_id・secret）と、introspect に渡すもの（`token` と RS のトークン） |
| RP | 16 | 独自ストラテジーの実際の流れ（`POST /auth/my_op` → リダイレクト先の `state` でコールバック）。OP の token・userinfo・JWKS を WebMock で差し替え、ID トークンはテスト内で作った RSA 鍵で署名し、JWKS も同じ鍵から作る。認可要求、PKCE、ログイン、`OpUser` の作成、ID トークンの検証失敗 6 本、トップ・ログアウト、introspection 用 RP のコールバック |
| OP | 17 | discovery、JWKS（`n` が設定した鍵と一致）、Devise のログイン、認可コードフロー（同意画面、認可コード、トークン応答、ID トークン）、userinfo、introspect（有効、10 分ちょうど、10 分 1 秒、revoke 済み、別アプリの資格情報）、revoke |

- テスト名は E2E と同じく日本語。1 テストのアサーションは 3 つまで（rubocop-minitest の `Minitest/MultipleAssertions`）なので、複数の値は 1 つの `assert_equal` にハッシュでまとめた
- テストの中のトークンや secret はリテラルで書かず、doorkeeper が発行した値か `SecureRandom` の値を変数で渡す（安全チェックの `oauth-param` ルール）
- 新しいテストは違反なしで書き、`.rubocop_todo.yml` は作り直していない

### 記録した挙動

計画の段階の見込みと違ったものを含む。どれも現在の挙動として記録し、コードは変えていない。

1. RP の ID トークンの検証に失敗すると、omniauth 2.0.4 が例外を rescue する（`omniauth-2.0.4/lib/omniauth/strategy.rb:196` の `rescue StandardError` → `fail!`）。`FailureEndpoint` は `RACK_ENV` が `development` のときだけ例外を外へ出し（`omniauth-2.0.4/lib/omniauth/failure_endpoint.rb:20`、既定の `failure_raise_out_environments` は `['development']`）、それ以外では `/auth/failure?message=<例外のメッセージ>&strategy=my_op` へリダイレクトする。RP は `/auth/failure` を `/` へリダイレクトする。RP の `test/test_helper.rb` で `RACK_ENV` を `test` に固定しているので、テストではリダイレクトになる（下の「コードレビュー」）

   | ID トークン | 例外（`env['omniauth.error']`） |
   |---|---|
   | nonce が認可要求のものと違う | `JWT::VerificationError` |
   | `kid` が JWKS にない | `JWT::VerificationError` |
   | JWKS にない鍵で署名されている | `JWT::VerificationError` |
   | `iss` が違う | `JWT::InvalidIssuerError` |
   | `aud` が違う | `JWT::InvalidAudError` |
   | 有効期限（発行から 120 秒）を過ぎた | `JWT::ExpiredSignature` |

2. OP に、introspection scope のない別アプリ（my_op 用 RP）の資格情報を Basic で付けて、RS のトークンを introspect すると、エラーではなく 200 で `{"active": false}` が返る。doorkeeper 5.5.2 は、クライアントの資格情報で認可されたときは `allow_token_introspection`（OP の設定では「同じアプリなら可」）が偽なら `active: false` を返す
3. OP の Devise のログインは、誤ったパスワードに 200 とフラッシュ（`Invalid Email or password.`）で応える（Devise 4.8.0）。正しいパスワードでは `/` へリダイレクトする（OP には `/` のルーティングはない）
4. OP の期限切れの判定は、0-b で書いたとおり `現在時刻 > created_at + expires_in`。発行から 10 分ちょうどは `active: true`、10 分 1 秒は `active: false`。introspect に使う RS のトークンは、時刻を進めた後に取る。同じ時刻に取ると、境目で RS のトークン自体が期限切れになるため

### 壊すと落ちることの確認

確かめた後は元に戻し、`git diff` が空であることを確かめた。

| 変更 | 落ちたテスト |
|---|---|
| OP の `access_token_expires_in` を 11 分にする | 10 分 1 秒で `active: false`、トークン応答の `expires_in`、introspect の有効期間 |
| OP の `access_token_expires_in` を 10 分より 1 秒短くする | 10 分ちょうどで `active: true`、トークン応答の `expires_in`、introspect の有効期間 |
| RP の `verify_nonce!` を素通りにする | nonce が違うときのテストだけ |
| RS で `active: false` を通す（401 にしない） | `active: false` のときのテストだけ |

### カバレッジ

| アプリ | 行カバレッジ | 備考 |
|---|---|---|
| RS | 57.5%（23 / 40） | `app/controllers/apples_controller.rb` は全行。通っていないのは生成物の基底クラス（channel・job・mailer・`ApplicationRecord`） |
| RP | 88.1%（104 / 118） | `lib/omniauth/strategies/my_op.rb` と各コントローラー・`OpUser` は全行。通っていないのは生成物の基底クラス |
| OP | 30.0%（6 / 20） | OP の挙動の大部分は `config/initializers/` の doorkeeper / doorkeeper-openid_connect の設定ブロックにあり、SimpleCov の `rails` プロファイルは `config/` を対象外にする。OP の数字はテストの範囲を表さない |

### 遭遇した問題

1. RP の独自ストラテジーの検証失敗は、計画では「例外になる」と見込んでいたが、テストでは何も raise されなかった。omniauth のログに `Authentication failure!` が出ていたことから gem を調べ、「記録した挙動」1 の仕組みが分かった。development で起動したときに `RACK_ENV` がどうなり、例外が外へ出るかは確かめていない
2. テストファイルが 1 つもないと、`bin/rails test` は `test_helper.rb` を読まないので、`coverage/` も作られない（RP・OP の土台のコミットの時点）

### 確認結果

- minitest: RS 7 runs、RP 16 runs、OP 17 runs、0 failures。`:raise` にした後も同じ
- E2E: 各コミットの前に流して、どれも 10 passed
- RuboCop: 3 アプリとも `no offenses detected`。bundler-audit: 3 アプリとも `No vulnerabilities found`（無視リスト込み）。brakeman: 3 アプリとも `Security Warnings: 0`
- 安全チェック: 各コミットで指摘なし
- 手動確認用の環境は変わっていない: 作業の前後で、3 アプリの development DB・`jwtRS256.key`・RP / RS の `.env` のハッシュが一致する。RP と OP の `db/test.sqlite3` はテストで新しく作られた（gitignore 対象）

### コードレビュー（`/code-review`）

| 指摘 | 対応 |
|---|---|
| RP の ID トークンの検証失敗のテストは、`RACK_ENV` が `development` だと例外が外へ出て、記録したリダイレクトにならない | `RACK_ENV=development` を付けて流すと 6 errors になることを確かめた。RP の `test/test_helper.rb` で `RACK_ENV` を `test` に固定し、同じ条件で通ることを確かめた |
| OP の `issue_tokens` が `application:` を受け取るのに、認可要求は既定のアプリ（my_op）で作っていて、別のアプリを渡すと認可コードとトークン要求のアプリが食い違う | 認可要求にも渡すように直した。introspection 用 RP を渡してトークンが取れることを一時的なテストで確かめた（今は渡すテストはない） |
| RP のログアウトのテストが、ログインできていることを確かめていないので、ログインが黙って失敗しても通る | ログアウトの前にセッションのユーザーがあることを確かめるようにした |
| RP の PKCE のテストで `code_verifier` が送られないと、比較の失敗ではなく `TypeError` になる | 送られないときは空文字列として比べ、比較の失敗になるようにした |
| RP / RS の `.gitignore` のコメントが「`.env.test` の値はすべて `test-dummy-` で始まる」としているが、`OIDC_PROVIDER_HOST` などは違う | client_id と secret がダミーだと書き直した |
| `.public-safety-allow` の除外は、行のどこかに `=test-dummy-` があれば効くので、本物の secret の行の後ろに書いたコメントでも素通りする | 対応しない。0-c で承認された `.env_e2e` の除外と同じ形で、除外の条件を変えるには人間の承認が必要 |
| SimpleCov の `rails` プロファイルは `config/` を対象外にするので、OP の挙動のある initializer のカバレッジが取れない | 対応しない。この Step では計測の仕組みを入れるところまでとし、0-e でカバレッジを見るときに必要なら決める |
| RS のテストで `stub_token_request` を 5 本で繰り返している | 対応しない。準備・実行・確認の順で、各テストの準備をテストの中に見えるようにしておく |

## Step 0-d-3: 脆弱性のある gem の更新（2026-10-07）

- ブランチ / PR: `upgrade/step0d3-security-updates` / [#15](https://github.com/thinkAmi-sandbox/oidc_op_rp-sample/pull/15)
- バージョン: 変更なし（Ruby 3.1.7 / Rails 6.1.7.10）

### 作業計画で決めたこと

PLAN.md の 0-d-3 で「着手時の調査で決める」とした 4 点は、次のとおり作業計画に入れて承認を得た。

| 論点 | 決めたこと | 理由 |
|---|---|---|
| 上げる先 | 修正版を含むマイナー系列の最新。マイナーはまたがない | パッチ版の追加の修正（rack 2.2.24、msgpack 1.8.3〜1.8.5 のメモリ安全性の修正）は取り込み、機能追加やフォーマットの変更は入れない。globalid は `--conservative` だと 1.4.0 になる（1.2.0 で SignedGlobalID の生成フォーマットが変わる）ので、一時固定で 1.0.1 にした |
| default gem | logger は 1.5.0、base64 は 0.1.1 に一時固定 | Ruby 3.1.7 の default gem と同じ版。json（0-d-1）・bigdecimal（0-d-2）と同じく、アプリが読む版を変えない |
| puma の新しい advisory | 5.6.9 に上げ、新しく対象に入る 2 件を無視リストに入れる | 下の「puma」 |
| PR | 1 つ | PLAN.md 4 章のとおり。区別はコミットでつける |

- default gem については、0-a で mail 2.8.1 を入れたときに、`date 3.5.1`・`timeout 0.6.1`・`net-protocol 0.4.0` が lock に入り、Ruby 3.1.7 の default gem（3.2.2 / 0.2.0 / 0.1.2）を置き換えていたことが分かった（0-a では記録していなかった）。0-d-3 では直近の json・bigdecimal の扱いに揃え、0-a の分は変えていない

### gem ごとの対応

gem ごとに RS → RP → OP の順で `bundle lock --update <gem> --conservative` を実行し、アプリごとにコミットした（24 コミット）。3 アプリとも Gemfile は変わっていない。

| gem | バージョン | アプリ | 解消した advisory | 対応 |
|---|---|---|---|---|
| rack | 2.2.3 → 2.2.24 | 3 アプリ | 32 件 | |
| puma | 5.4.0 → 5.6.9 | 3 アプリ | 6 件 | 新しく 2 件が対象に入る（下の「puma」） |
| loofah / crass / rails-html-sanitizer | 2.12.0 / 1.0.6 / 1.3.0（RS は 1.4.1）→ 2.25.2 / 1.0.7 / 1.7.1 | 3 アプリ | 4 / 4 / 6 件 | 1 組で更新。brakeman の SanitizeConfigCve（CVE-2022-32209）が出なくなったので、`config/brakeman.ignore` から消した |
| websocket-driver | 0.7.5 → 0.8.2 | 3 アプリ | 4 件 | base64 0.1.1 が lock に入る |
| globalid | 0.5.2 → 1.0.1 | 3 アプリ | 1 件 | 一時固定 |
| mail | 2.8.1 → 2.9.1 | 3 アプリ | 1 件 | logger 1.5.0 が lock に入る |
| msgpack | 1.4.5 → 1.8.5 | 3 アプリ | 1 件 | bootsnap 1.7.7 の要求は `~> 1.0` |
| faraday | 1.7.0 → 1.10.6 | RS・RP | 2 件 | faraday-multipart 1.2.0・faraday-retry 1.0.4 が lock に入る（1.9 で multipart と retry が別 gem になった）。oauth2 1.4.7 の要求（`< 2.0`）は満たす |
| bcrypt | 3.1.16 → 3.1.22 | OP | 1 件 | advisory は JRuby の実装だけが対象 |

- 一時固定は、0-a・0-d-1・0-d-2 と同じく Gemfile に `gem '<名前>', '<版>'` を足して `bundle lock` → 外して `bundle lock` → `git diff` で Gemfile が戻り、lock に意図しない `-    ` の行がないことを確かめた
- 無視リストの件数は RS 93 → 34、RP 93 → 34、OP 94 → 36（puma の 2 件を足した後）。残りは Rails・nokogiri・sqlite3・concurrent-ruby・0-f で上げる gem・puma の新しい 2 件
- advisory DB（2026-10-06 時点）と照らし合わせると、上げた先の版で報告されるのは puma の 2 件だけ

### puma

- 5.6.9 にすると、5.4.0 では対象外だった 2 件の対象に入る。どちらも 5.5.0 で入った PROXY protocol v1 の対応の不具合で、`unaffected_versions` は `< 5.5.0`、修正版は 7.2.1 / 8.0.2 だけ
  - CVE-2026-47736: PROXY protocol v1 の行を読むバッファーに上限がなく、メモリを使い尽くされる
  - CVE-2026-47737: keep-alive の接続で PROXY protocol のヘッダーを繰り返し受け付け、`REMOTE_ADDR` を偽装される
- どちらも非既定の `set_remote_address proxy_protocol: :v1` を設定したときだけ影響する。3 アプリの `config/puma.rb` には設定がない
- 既存の 6 件を解消できることを優先し、2 件は無視リストに入れた（コメントに上の理由と、7.2.1 以上で解消することを書いた）。代案は 5.4.0 に据え置いて 7.2.1 以上に直接上げることだった

### CHANGELOG で確かめたこと

サブエージェントで CHANGELOG とタグ間のソースの差分を読んだ。アプリの挙動に関わりうるものだけを残す。

| gem | 内容 | アプリへの影響 |
|---|---|---|
| rack 2.2.x | 2.2.14 以降、クエリのパラメーター数（既定 4096）と本文（既定 4MB）、multipart のパート数・ヘッダーなどに上限が入った。超えると `Rack::QueryParser::QueryLimitError` | Rails 6.1 はこの例外を `ActionController::BadRequest` に変換しない（`actionpack-6.1.7.10/lib/action_dispatch/http/request.rb` が rescue するのは `ParameterTypeError` と `InvalidParameterError` だけ）ので、超えたときは 500 になる（下の「コードレビュー」）。OIDC の通常の通信では届かない |
| puma 5.5〜5.6 | 5.5.1 から `APP_ENV` を `RACK_ENV` / `RAILS_ENV` より優先する。ヘッダーの行末の LF 単独を受け付けない | 手元のシェルに `APP_ENV` はない |
| rails-html-sanitizer 1.6〜1.7 | HTML4 / HTML5 の名前空間ができたが、Rails 6.1 では HTML4 の sanitizer のまま。警告は出ない | OP の `rails_open_id_provider/app/views/doorkeeper/applications/index.html.erb` が `simple_format(application.redirect_uri)` を使う（下の「確認結果」） |
| websocket-driver 0.8 | バイナリフレームの受信が Array から String に変わる。0.8.1 でリクエスト行とヘッダーの合計を 32K に制限 | ActionCable の実チャネルはない |
| globalid 1.0.1 | ReDoS の修正と fixture のヘルパーだけ | ActiveJob・SignedGlobalID は使っていない |
| mail 2.9 | ヘッダー名 `Mime-Version` → `MIME-Version`。SMTP の設定処理の書き直し（`tls` / `ssl` と starttls を併記すると `ArgumentError`） | ヘッダー名の大文字小文字は区別されない。ActionMailer 6.1 の SMTP の既定値は併記にあたらない |
| faraday 1.8〜1.10 | `url_encoded.rb`・`utils.rb`・`adapter/net_http.rb` は 1.7.0 と差分なし。非推奨の警告は環境変数 `FARADAY_DEPRECATE` がないと出ない。1.10.5 は `//` で始まる URL、1.10.6 は decode 時のネストの深さ（100）だけが対象 | アプリは絶対 URL とハッシュの本文で呼ぶだけ |
| bcrypt 3.1.17〜3.1.22 | 既存の `$2a$` のハッシュはそのまま照合できる。3.1.19 で `hash_secret` の第 3 引数が非推奨 | Devise 4.8.0 は第 3 引数を渡さない |

### 確認結果

- minitest: 各コミットの前に流して、どれも RS 7 runs、RP 16 runs、OP 17 runs、0 failures（非推奨警告は `:raise` のまま）
- E2E: 各コミットの前に流して、どれも 10 passed
- RuboCop: 3 アプリとも `no offenses detected`。bundler-audit: 3 アプリとも `No vulnerabilities found`（無視リスト込み）。brakeman: 3 アプリとも `Security Warnings: 0`、`Ignored Warnings: 2`
- gem ごとの追加の確認
  - rails-html-sanitizer（OP）: seeds の 3 つの redirect_uri に `simple_format` をかけた出力が、上げる前と同じ
  - websocket-driver（RS）: development で起動した RS の `/cable` に WebSocket のハンドシェイクを送ると、上げる前と同じく 101 と ActionCable の `{"type":"welcome"}` が返る
  - mail（OP）: ActionMailer で組み立てたメッセージ（送信はしない）のヘッダーは、`Mime-Version` が `MIME-Version` になった以外は同じ
  - logger / base64: 3 アプリとも `bin/rails runner` で logger 1.5.0、base64 0.1.1 が読み込まれる
  - msgpack（RS）: 空のディレクトリを `BOOTSNAP_CACHE_DIR` にして `bin/rails runner` を 2 回起動し、bootsnap がキャッシュを書いて読めることを確かめた
  - faraday（RS・RP）: `FARADAY_DEPRECATE=warn` を付けてテストを流しても、Faraday の非推奨の警告は出ない
  - bcrypt（OP）: 3.1.16 で作ったハッシュが 3.1.22 で照合できる（正しい値で真、違う値で偽）
- 3 アプリとも `bin/rails runner` で起動する。`bin/rails s` は E2E の起動で確認し、Puma 5.6.9 で起動する
- 手動確認用の環境は変わっていない: 作業の前後で、3 アプリの development DB・`jwtRS256.key`・RP / RS の `.env` のハッシュが一致する

### 遭遇した問題

1. websocket-driver の確認で RS を起動したとき、ブラウザペインが開いた `/favicon.ico` の 404 の処理中に、Step 0-b と同じ finalizer の警告（`ThreadError: can't be called from trap context`、`listen-3.7.0/lib/listen/fsm.rb:80`）が出た。0-b では OP（listen 3.6.0）で観測したもので、RS は listen 3.7.0。0-d-3 で上げた gem とは経路が違い、0-f で listen を更新するときに確認する
2. Devise の reset password のメールを組み立てて mail の前後を比べようとしたが、OP には Devise の recoverable のルーティングがないため、テンプレートが `edit_password_url` で `NoMethodError` になった。ActionMailer で直接組み立てたメッセージで比べた

### コードレビュー（`/code-review`）

| 指摘 | 対応 |
|---|---|
| `.bundler-audit.yml` の先頭のコメントが「Step 0-d で凍結した既存の advisory」のままで、0-d-3 で足した puma の 2 件に合わない | 「Step 0-d-1 で凍結した既存の advisory と、Step 0-d-3 の puma の更新で新しく対象に入った advisory」に直した（3 アプリ） |
| 末尾の websocket-driver の項目を消したときに、直前の空行が残り、3 アプリの `.bundler-audit.yml` の末尾が空行 2 つになっている | 末尾の空行を消した |
| rack の上限を超えたときに 500 になるという記述が、確かめていない見込みのまま | test 環境の OP の `/oauth/token` に `Rack::MockRequest` で POST し、パラメーター 2 個では doorkeeper が 400、4097 個では `Rack::QueryParser::QueryLimitError` で 500 になることを確かめた。セキュリティの修正による変化として受け入れ、テストは足していない |
| logger・base64（と 0-d-1 の json、0-d-2 の bigdecimal）を Ruby 3.1.7 の default gem の版に固定したが、Ruby を上げたときに合わせ直す手順がない。そのままでは、Step 2 以降も lock の古い版が読まれ、新しい Ruby の default gem と食い違う | 人間の判断で、PLAN.md 8 章の 4（Ruby を上げる場合）に「新しい Ruby の default gem の版に一時固定で合わせ直す。default gem でなくなったものは 7 章の表に従う」を足した。7 章の表の 4 つの行の時期も「未定」から「Ruby を上げる各 Step で合わせ直す」に変えた。Ruby 3.4 で bundled gem になる base64・bigdecimal は、既存の「base64 / bigdecimal / mutex_m など」の行に従う |

## Step 0-e: 既存コードの RuboCop 違反の修正（2026-10-07）

- ブランチ / PR: `upgrade/step0e-rubocop-violations` / PR は未作成
- バージョン: 変更なし（Ruby 3.1.7 / Rails 6.1.7.10）

### 着手時の件数

todo を外し、直下の `.rubocop.yml` だけで数え直した件数は、凍結時と同じ RS 31・RP 58・OP 68 だった。

### 作業計画で決めたこと

PLAN.md の 0-e で「着手時の調査で決める」とした論点は、次のとおり作業計画に入れて承認を得た。

| 論点 | 決めたこと | 理由 |
|---|---|---|
| todo にある `app/`・`lib/`・`test/` の外のファイル | `Gemfile`・`Rakefile` は直す。`config.ru` は直下の `.rubocop.yml` で対象外にする | `config.ru` は `rails app:update` で上書きされる（`railties-6.1.7.10/lib/rails/generators/rails/app/app_generator.rb` の `config_when_updating` が `configru` を呼ぶ）。`Rakefile` と `Gemfile` は上書きされない |
| Rails/Output（RS 4・RP 14） | `puts` のまま残し、`rubocop:disable` / `enable` で囲んで理由を書く | 下の「Rails/Output」 |
| テストが通っていない生成物の基底クラス | 先に eager load のテストを足し、その後でマジックコメントを足す | PLAN.md の「先にテストを足すか Layout 系だけ」に従う |
| Style/FrozenStringLiteralComment | 安全でない自動修正（`-A`）で全ファイルに足す | 下の「マジックコメント」 |
| Rails/HttpStatus（RS） | 自動修正で `401` → `:unauthorized` | Rack が `:unauthorized` を 401 に変換する。RS のテストが 3 つの分岐をすべて確かめている |
| Rails/RakeEnvironment・Metrics/BlockLength（OP の annotate の rake） | `task` の行に `rubocop:disable` を付ける | 下の「annotate の rake」 |
| Bundler/OrderedGems・Bundler/DuplicatedGroup | 並べ替え、RP/OP の 2 つ目の `group :development` の annotate を 1 つ目に移す | 下の「Gemfile」 |
| Metrics（RS 2・RP 3） | メソッドを分けず、`def` の行に `rubocop:disable` を付けて理由を書く | 分割の正しさはテストに頼ることになる。該当箇所は 0-f の oauth2・omniauth-oauth2・jwt の更新で書き換わりうる。OIDC の流れを 1 か所で読めるサンプルの形を残す。既定の上限は新しいコードに効いたまま |
| Style/Documentation（18） | 直下の `.rubocop.yml` で無効にする | 11 件は生成物の基底クラス・空のヘルパー。残りもクラス名と中のコメントで足りる |
| RP の `my_op.rb` の空の `client_id_of_my_op(provider_name)` | 消さずに 1 行にする（Style/EmptyMethod） | どこからも呼ばれていない private メソッドだが、消すのは違反の修正の範囲を超える |
| PR とコミット | PR は 1 つ。コミットは「ルール（分類）× アプリ」で RS → RP → OP | PLAN.md 2 章・4 章 |
| `.git-blame-ignore-revs` | 見た目だけのコミット（文字列の引用符・シンボルの配列・空のメソッド・空白・Gemfile の並べ替え）だけを登録する | マジックコメント・ステータスの記法・クラスの入れ子・`rubocop:disable` の追加は、意味が変わりうるか、判断の記録なので登録しない |

### 進め方

- 各コミットで、直した違反の分だけ `.rubocop_todo.yml` から消した。`--auto-gen-config` は継承の順番を書き換えるので使わず（Step 0-d-1「遭遇した問題」3）、直下の設定だけで数え直した結果から、直し終えたファイル・ルールを消して件数を書き直す使い捨てのスクリプトで行った
- todo が空になったアプリから、ファイルを消して `.rubocop.yml` の `inherit_from` を `../.rubocop.yml` だけにした
- 各コミットの前に、そのアプリの RuboCop・minitest と E2E を流した。Gemfile を変えたコミットでは、lock と依存の一覧も確かめた（下の「Gemfile」）

### テストの追加

- 3 アプリに `test/eager_load_test.rb`（`Rails.application.eager_load!` が例外を出さない）を足した。テストの環境は `eager_load = false` なので、どのテストからも使われない生成物の基底クラス（`application_cable/channel.rb`・`connection.rb`、`application_job.rb`、`application_mailer.rb`、RS の `application_record.rb`）は読み込まれず、カバレッジも 0 だった
- 足した後の行カバレッジは 3 アプリとも 100%（RS 33 行、RP 112 行、OP 14 行）。分母が 0-d-2 の記録（RS 40・RP 118・OP 20）より小さいのは、読み込まれなかったファイルの行を SimpleCov が自前で数えていたため
- 100% のうち、クラス本体・`def` の行・`devise` や `before_action` のようなマクロの行は、読み込むだけで通ったことになる。以降の Step で「テストが通っていない箇所」を SimpleCov で探すときは、メソッドの中の行で判断する
- ActiveSupport の `assert_nothing_raised` はアサーションの件数を増やさないので、テストの件数（runs）だけが 1 ずつ増えた

### マジックコメント

- 対象のファイルに、リテラルの文字列を破壊的に変更するコード（`<<`・`gsub!`・`concat`・`force_encoding` など）はなかった。式展開した文字列は Ruby 3.0 から凍結されないので、RP の不正なトークン（`"#{access_token}_bad"`）なども影響しない
- `--only` を付けて自動修正したので、マジックコメントの直後の空行が入らず、Layout/EmptyLineAfterMagicComment が新しく出た。同じコミットで直した
- OP の `app/models/user.rb` は、annotate がスキーマのコメントを先頭に書くファイル。annotate 3.1.1 は書き直すときにマジックコメントを先頭に残し、空行を挟んでスキーマのコメントを書く（`annotate-3.1.1/lib/annotate/annotate_models.rb:536`）ので、今回の配置と食い違わない

### Rails/Output

- RP の introspection 画面は RS の応答を表示せず、`puts` で標準出力に出すだけ（Step 0-c）。RP の独自ストラテジーも、JWKS と nonce の比較を `puts` で出している。RS も introspect の応答を `puts` で出している
- 自動修正（`-A`）は `Rails.logger.debug` に変える。`rails s` は development のとき logger の出力を標準出力にも出す（`railties-6.1.7.10/lib/rails/commands/server/server_command.rb` の `log_to_stdout?`）ので端末には同じ文字列が出るが、`log/development.log` にも残り（nonce や JWKS を含む）、`rails test` の出力には出なくなる
- 出力先が変わるので、アップグレード中は `puts` のまま残した。logger への変更は、epic を main に取り込んだ後の改善として扱う

### Gemfile

- RS は `dotenv-rails` を `faraday` の前に移した。RP・OP は、自動修正が `listen` を rack-mini-profiler の説明コメントの下に入れ、コメントと gem の対応が崩れた。RuboCop はコメントを区切りとして扱う（`TreatCommentsAsGroupSeparators`）ので、コメントのない `listen` と、2 つ目の `group :development` から移した `annotate` を、1 つ目の `group :development` の先頭に置いた
- 3 アプリとも、`bundle lock --local` で Gemfile.lock の差分がなく、依存の一覧（名前・グループ・プラットフォーム・要求・`require:`）が作業の前と同じことを確かめた
- 変わるのは `Bundler.require` が gem を読む順番だけ。dotenv-rails が `.env` を読むのは `before_configuration`（`dotenv-rails-2.7.6/lib/dotenv/rails.rb:75`）で、`config/application.rb` の `Bundler.require` の後なので、読む順番は環境変数に影響しない。development で annotate・listen・rack-mini-profiler が読み込まれることも確かめた

### annotate の rake（OP）

- `lib/tasks/auto_annotate_models.rake` は annotate の生成物で、development のときだけ読まれる。テストの対象外なので、作業の前後で `set_annotation_options` を実行した後の annotate の設定値（ENV）を比べ、同じであることを確かめた
- Rails/RakeEnvironment に従って `:environment` を足すと、`annotate_models`（annotate 3.1.1 では `:set_annotation_options` と `:environment` に依存する）を実行したときに、設定値を入れる前にアプリが読み込まれる順に変わる。Step 5 で annotaterb に置き換えるときにこのファイルを見直すので（PLAN.md の Step 5）、`rubocop:disable` を付けて残した
- Layout/HashAlignment（45 件）は空白だけの変更（`git diff -w` で差分なし）

### 確認結果

- RuboCop: 3 アプリとも `.rubocop_todo.yml` なしで `no offenses detected`。`--list-target-files` に `config.ru` が出ない。12 行のメソッドを `--stdin` で渡すと Metrics/MethodLength と Rails/Output が出る（新しいコードは既定の上限で検査される）
- minitest: RS 8 runs、RP 17 runs、OP 18 runs、0 failures（eager load のテストを 1 本ずつ足した）
- E2E: 各コミットの前に流して、どれも 10 passed
- bundler-audit: 3 アプリとも `No vulnerabilities found`（無視リスト込み）。brakeman: 3 アプリとも `Security Warnings: 0`、`Ignored Warnings: 2`
- 3 アプリとも `bin/rails zeitwerk:check` が通り、`bin/rails runner` で起動する。`bin/rails s` は E2E の起動で確認
- `.git-blame-ignore-revs` を有効にして `git blame` すると、引用符を直した `Rakefile` の行や、移した `annotate` の行が元のコミットに戻る
- 手動確認用の環境は変わっていない: 作業の前後で、3 アプリの development DB・`jwtRS256.key`・RP / RS の `.env` のハッシュが一致する

### コードレビュー（`/code-review`）

| 指摘 | 対応 |
|---|---|
| `.git-blame-ignore-revs` が効くのは、この PR を epic にマージコミットで取り込んだときだけ。その決まりはファイルのコメントにしかない。git 2.49 の `git blame` は ignore のファイルにある未知のハッシュを黙って無視するので、squash や rebase で取り込んでもエラーにならず、ignore だけが効かなくなる | 人間の判断で、CLAUDE.md の「ブランチと PR」の行を「epic への PR の取り込みも、epic → main の取り込みも、マージコミットで行う」に直した。これまでの PR もマージコミットで取り込んでいて、運用は変わらない。ファイルのコメントは CLAUDE.md を指すようにした |
| eager load のテストの `assert_nothing_raised` は、アサーションの件数に入らない | 対応しない。Rails 7.0 の Testing ガイド（Testing Eager Loading）の例と同じ書き方 |
| 同じプロセスで eager load すると、後に流れるテストでは定数がすべて読み込み済みになり、autoload の漏れが隠れうる | 対応しない。ガイドの例も同じプロセスで動かす。ファイル名と定数名の食い違いは、このテスト自体と `bin/rails zeitwerk:check` で見つかる |
| 行カバレッジ 100% は、読み込むだけで通る行を含む | 「テストの追加」に、以降の Step ではメソッドの中の行で判断することを書き足した |
| RS の `gsub('Bearer ', '')` は `Bearer ` の接頭辞を確かめないので、`Basic` などのヘッダーの値もそのまま introspect に渡る | 対応しない。元からの挙動で、アップグレード中は変えない。epic を main に取り込んだ後の改善として扱う |
