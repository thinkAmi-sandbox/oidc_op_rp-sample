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
  - トークン要求の Parameters の `redirect_uri` の値。RP（omniauth-oauth2 1.7.1）がコールバック URL を `?code=<AUTH_CODE>&state=...` 付きのまま `redirect_uri` に入れて送るため、キー名で判定する `filter_parameters` では伏せられない。元からの挙動なので、アップグレード中は変えない（docs/IMPROVEMENTS.md の IMP-005）

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

- ブランチ / PR: `upgrade/step0e-rubocop-violations` / [#16](https://github.com/thinkAmi-sandbox/oidc_op_rp-sample/pull/16)
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
- 出力先が変わるので、アップグレード中は `puts` のまま残した。logger への変更は、epic を main に取り込んだ後の改善として扱う（docs/IMPROVEMENTS.md の IMP-003）

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
| RS の `gsub('Bearer ', '')` は `Bearer ` の接頭辞を確かめないので、`Basic` などのヘッダーの値もそのまま introspect に渡る | 対応しない。元からの挙動で、アップグレード中は変えない。epic を main に取り込んだ後の改善として扱う（docs/IMPROVEMENTS.md の IMP-004） |

## Step 0-f-1: spring の削除と、開発・テスト用などの gem の更新（2026-10-07）

- ブランチ / PR: `upgrade/step0f-gem-updates` / [#17](https://github.com/thinkAmi-sandbox/oidc_op_rp-sample/pull/17)
- バージョン: 変更なし（Ruby 3.1.7 / Rails 6.1.7.10）

### 作業計画で決めたこと

着手時に、0-f 全体（0-f-1〜0-f-3）を調べて作業計画を出し、承認を得た。`bundle outdated` を 3 アプリで確認し、PLAN.md 7 章の順で振り分けた。依存の範囲は rubygems の API と gemspec、挙動の変化は CHANGELOG とタグ間のソースで確かめた（サブエージェント）。

| 論点 | 決めたこと | 理由 |
|---|---|---|
| PR の単位 | 0-f-1（spring の削除、開発・テスト用などの gem）、0-f-2（RS・RP の oauth2 系）、0-f-3（OP の doorkeeper 系）の 3 つに分ける | 0-d と同じく、レビューの観点（クライアント側と OP 側）と量が違う |
| 上げる先 | Ruby 3.1・Rails 6.1 で使える最新の版。ただし doorkeeper は 5.7.1、doorkeeper-openid_connect は 1.8.9 で止める | doorkeeper-openid_connect 1.8.10 は CHANGELOG に「Drop support for Rails 6」とあり、doorkeeper は 5.8.1 で CI から Rails 6 を外した。5.7.1 / 1.8.9 は Rails 6 を外していない最後の組み合わせで、doorkeeper の advisory（5.6.6 で修正）も解消できる |
| 上げない gem | annotate（3.2.0 は注釈の出力が変わる。Step 5 で置き換える）、omniauth-rails_csrf_protection（2.0 の変化は Rails 8.1 だけ。Step 7）、sqlite3・rails | 時期は PLAN.md 7 章 |
| Ruby 3.2 以上が必要な版 | 上げない（byebug 13、web-console 4.3、rack-mini-profiler 5、brakeman 8、simplecov 1、doorkeeper-openid_connect 1.10.2 以上） | Step 2 の後 |
| 間接依存の gem | 上の更新で必要になったものしか動かさない（`--conservative`） | i18n・zeitwerk・minitest などは Rails を上げるときに動く |
| default gem を置き換える依存 | 一時固定する（cgi 0.3.7、0-f-2 の faraday-net_http 3.0.2） | json・bigdecimal・logger・base64 と同じく、アプリが読む版を変えない |
| 挙動が変わる更新 | 設定で元の挙動に固定する。テストや E2E で守られていない挙動は、gem を上げる前にテストを足す（0-f-2・0-f-3） | アップグレード中は挙動を変えない |
| discovery に `code_challenge_methods_supported` が増える（0-f-3） | 「意図的な仕様変更」として受け入れ、スナップショットを更新する | doorkeeper-openid_connect 1.8.3 以上は PKCE の列があると出し、設定で消すと PKCE も止まる |
| spring を消すときの `bin/` | `bin/spring`・`config/spring.rb` を消し、`bin/rails`・`bin/rake` を Rails 7.0 の雛形の形にする | Rails 7.0 の `app:update` は `bin/rails`・`bin/rake` を書き換えるが、`bin/spring` と `config/spring.rb` は消さない |
| ダウンロード | gem の名前・版・サイズを PR ごとにまとめて示し、承認を得た | CLAUDE.md の「人間との分担」 |

0-f-2・0-f-3 の調査の結果（oauth2 2.x の既定値、faraday-net_http の依存、doorkeeper-openid_connect の版ごとの違いなど）は、PLAN.md の 0-f と 7 章に書いた。

### gem ごとの対応

gem ごとに RS → RP → OP の順で `bundle update <gem> --conservative` を実行し、アプリごとにコミットした。

| gem | バージョン | アプリ | 対応 |
|---|---|---|---|
| spring | 2.1.1 → 削除 | 3 アプリ | 下の「spring の削除」 |
| byebug | 11.1.3 → 12.0.0 | 3 アプリ | メジャー更新。C 拡張は clang 17 でビルドできた |
| web-console | 4.1.0 → 4.2.1 | RP・OP | |
| listen | 3.6.0（RS は 3.7.0）→ 3.10.1 | 3 アプリ | logger が依存に入るが、lock の logger は 1.5.0 のまま。警告は下の「listen の finalizer の警告」 |
| rack-mini-profiler | 2.3.2 → 4.0.1 | RP・OP | メジャー更新。Gemfile を `~> 2.0` → `~> 4.0` |
| thor | 1.1.0 → 1.5.0 | 3 アプリ | `DidYouMean::SPELL_CHECKERS.merge!` の警告が出なくなった（Step 0-a） |
| bootsnap | 1.7.7 → 1.26.0 | 3 アプリ | |
| jbuilder | 2.11.2 → 2.13.0 | RP・OP | `.jbuilder` のビューはない |
| puma | 5.6.9 → 6.6.1 | 3 アプリ | メジャー更新。Gemfile を `~> 5.0` → `~> 6.0`。advisory 2 件は 6.6.1 も対象（下の「確認結果」） |
| dotenv / dotenv-rails | 2.7.6 → 3.2.0 | RS・RP | メジャー更新 |
| activerecord-session_store | 2.0.0 → 2.1.0 | RP | cgi 0.3.7 が lock に入る。一時固定しないと 0.5.2 が入り、Ruby 3.1.7 の default gem（0.3.7）を置き換える（lock のコピーで確かめた） |
| devise / responders | 4.8.0 / 3.0.1 → 4.9.4 / 3.1.1 | OP | advisory 2 件は 4.9.4 も対象（5.x でしか直らない）。無視リストのコメントの版を直した |

- 一時固定は、過去の Step と同じく Gemfile に `gem '<名前>', '<版>'` を足して lock → 外して lock した
- 作業の後の 3 アプリの lock を epic と比べ、変わったのは上の gem と cgi だけで、default gem（json 2.6.1・bigdecimal 3.1.1・logger 1.5.0・base64 0.1.1 など）と concurrent-ruby 1.1.9 が動いていないことを確かめた

### CHANGELOG で確かめたこと

アプリの挙動に関わりうるものだけを残す。

| gem | 内容 | アプリへの影響 |
|---|---|---|
| byebug 12 | 引数なしの `break` が今の行に止まる | アプリのコードは byebug を呼ばない |
| web-console 4.2 | Ruby 3.0 以上で `binding.eval` が動く。応答ヘッダーを小文字に | エラー画面だけに出る。E2E はエラー画面を開かない |
| rack-mini-profiler 3〜4 | 3.0 で snapshot の保存の API が変わり `snapshots_limit` が消えた。4.0 で応答ヘッダーが小文字（`x-miniprofiler-ids` など）。4.0.1 で Rack 2 に再び対応 | 設定はしていない。4.0.1 でも development のページに `<script id="mini-profiler">` が挿入され、応答ヘッダーは小文字になる（E2E 用の DB を指定した `rails runner` から、RP のトップと OP のログイン画面で確かめた。2.3.2 では確かめていない）。E2E はこの状態で通る |
| thor 1.2〜1.5 | 1.2.0 で `DidYouMean` の警告を出さない。1.2.2 で MD5 → SHA256、1.4.0 で YAML の遅延読み込み | `rails --help`・`rails g --help`・`rails routes` が警告なしで動く |
| bootsnap 1.8〜1.26 | Psych 4 対応、`Kernel.load` を装飾しない（classic autoloader だけに関係）、JSON のキャッシュの削除 | 空のキャッシュの場所を指定して 2 回起動し、1 回目に書いたキャッシュを 2 回目に使えることを確かめた |
| puma 6 | 標準の 8 つ以外の HTTP メソッドは 501。`PUMA_` で始まる環境変数。エラーの応答で Puma と名乗らない。Rack 2 のハンドラーは残る | `config/puma.rb` で使っている設定（threads・worker_timeout・port・environment・pidfile・tmp_restart）はすべて有効。`workers` は使っていない |
| dotenv 3 | 読むファイルの順番と、既にある環境変数を上書きしないことは同じ。テストのたびに ENV を戻す。引用符の中の `\n` を改行にしない。Rails のログに `[dotenv]` の行（読んだファイル、設定した変数名）を出す | 下の「dotenv」 |
| activerecord-session_store 2.1 | `session_class` を `class_attribute` に。Rack 3 に対応 | RP は `session_store :active_record_store` と JSON の serializer だけを使う。E2E のログインがセッションを使う |
| devise 4.9 / responders 3.1 | responders の `error_status`（既定 200）・`redirect_status`（既定 302）。devise は `config.responder` を設定しなければ従来の値を使う。`:turbo_stream` を navigational format に追加 | OP の `config/initializers/devise.rb` は `config.responder` を設定していない。`Devise.responder` の値は `:ok` / `:found` で、誤ったパスワードは今と同じく 200（OP のテスト） |

### spring の削除

- 3 アプリの Gemfile から spring を外し、`bin/spring` と `config/spring.rb` を消した。`bin/rails`・`bin/rake` の `load File.expand_path("spring", __dir__)` の行を消し、Rails 7.0 の雛形（`railties-7.0.8.7/lib/rails/generators/rails/app/templates/bin/rails.tt`・`rake.tt`）と同じ形にした
- `e2e/scripts/start-server.sh` と `.claude/launch.json` の `DISABLE_SPRING` を消した。LOG.md の過去の記録は変えていない。PLAN.md の 0-d-2 には、spring を消した後は `bin/rails test` だけでよいと書き足した
- `.claude/launch.json` の変更は E2E では確かめられないので、3 アプリを launch.json のコマンドで起動し、起動のログで Puma 6.6.1 であることを確かめた。OP の discovery は 200、トークンなしの RS は 401 を返した。RP は手動確認用の DB を変えないよう、リクエストを送っていない（RP のトップページを 1 回開くと、セッションの行が 1 件増えることを E2E 用の DB で確かめた）

### listen の finalizer の警告

- Step 0-b・0-d-3 で観測した `ThreadError: can't be called from trap context` は、listen 3.10.1 でも出る
- 再現の手順: `bin/rails runner` で `ActiveSupport::EventedFileUpdateChecker` を作って参照を外し、`Signal.trap('USR1') { GC.start }` を仕込んで自分に USR1 を送る。シグナルのハンドラーの中で GC が finalizer を呼び、listen の `stop` の `Mutex#synchronize` が失敗する。listen 3.6.0（更新前の OP）でも 3.10.1（更新後の RS）でも、同じ警告が出た
  - gem 側: `activesupport-6.1.7.10/lib/active_support/evented_file_update_checker.rb:93`（finalizer）→ `listen-3.10.1/lib/listen/fsm.rb:78`（`synchronize`）
- listen 側の issue（guard/listen#565）は未解決。Rails 側の issue（rails/rails#46785）は、Rails の main では出なかったというコメントの後、返事がないため bot が自動で閉じた（どの変更で出なくなったかは確かめていない）。Rails 7.0 の development.rb の雛形には `config.file_watcher` の行がない（Rails 6.1 の雛形は `EventedFileUpdateChecker`）。Step 1 の `app:update` の差分で、この行の扱いを判断する（PLAN.md 7 章）

### dotenv

- 上げる前と後で、`bin/rails runner` から次の 3 通りに、変数がどのファイル由来かを出して比べた（値は出していない）。RS は `CLIENT_ID_OF_RESOURCE_SERVER`、RP は `CLIENT_ID_OF_MY_OP` と `OIDC_PROVIDER_HOST`

  | 環境 | 結果（前後とも） |
  |---|---|
  | test | `.env.test` |
  | development | `.env` |
  | development で同じ名前の環境変数を渡す | 渡した値（E2E の `webServer.env` と同じ） |

- 3.x から、Rails のログ（`log/test.log`・`log/development.log`）に `[dotenv] Loaded .env.test`、`[dotenv] Set <変数名>`、テストのたびの `Saved a snapshot of ENV` が出る。`Set` の行に値が含まれないことを確かめた

### 遭遇した問題

1. development の Rails を `Rack::MockRequest` で呼ぶと、Host ヘッダーがないため `ActionDispatch::HostAuthorization` に 403（`Blocked host: localhost`）で止められた。`HTTP_HOST` に `localhost:<ポート>` を渡して確かめた
2. bundler-audit の advisory DB を更新しようとしたが、0-d-3 のときの DB（2026-10-06）が最新で、新しい advisory はなかった

### 確認結果

- minitest: 各コミットの前に流して、どれも RS 8 runs、RP 17 runs、OP 18 runs、0 failures（非推奨警告は `:raise` のまま）
- E2E: 各コミットの前に流して、どれも 10 passed
- RuboCop: 3 アプリとも `no offenses detected`。bundler-audit: 3 アプリとも `No vulnerabilities found`（無視リスト込み）。brakeman: 3 アプリとも `Security Warnings: 0`、`Ignored Warnings: 2`
- 3 アプリとも `bin/rails zeitwerk:check` が通り、`bin/rails runner` で起動する。`bin/rails s` は E2E の起動とプレビューで確認し、Puma 6.6.1 で起動する
- 無視リストを空にした bundler-audit で、puma 6.6.1 が CVE-2026-47736 / 47737、devise 4.9.4 が CVE-2026-32700 / 40295 の対象のままであることを確かめた
- 手動確認用の環境は変わっていない: 作業の前後で、3 アプリの development DB・`jwtRS256.key`・RP / RS の `.env` のハッシュが一致する

### コードレビュー（`/code-review`）

| 指摘 | 対応 |
|---|---|
| launch.json から OP・RS が Puma 6.6.1 で動くと書いているが、Puma の版を起動のログで確かめたのは OP だけ | RS も launch.json のコマンドで起動し、起動のログで Puma 6.6.1 を確かめた。RP と合わせて書き直した |
| rack-mini-profiler の挿入が「変わらない」と書いているが、2.3.2 では確かめていない | 4.0.1 で確かめたことだけを書いた |
| RP のトップページがセッションを DB に書くというのは推測 | E2E 用の DB で、トップページを 1 回開くとセッションの行が 1 件増えることを確かめた |
| gem 内のパスを `gem名-バージョン/` から書いていない（`railties-7.0.8.7` の `templates/bin/rails.tt`） | `railties-7.0.8.7/lib/rails/generators/rails/app/templates/bin/rails.tt` に直した |
| cgi 0.3.7 は lock にしか残らないので、`--conservative` を付けない `bundle update` で黙って 0.5.2 に変わる | 対応しない。json・bigdecimal・logger・base64 と同じ一時固定のやり方で、Ruby を上げる各 Step で合わせ直す（PLAN.md 8 章の 4）。default gem の版は gem を上げるたびに lock で確かめている |

## Step 0-f-2: RS・RP の oauth2 系の gem の更新（2026-10-08）

- ブランチ / PR: `upgrade/step0f2-oauth2` / [#18](https://github.com/thinkAmi-sandbox/oidc_op_rp-sample/pull/18)
- バージョン: 変更なし（Ruby 3.1.7 / Rails 6.1.7.10）

### 着手時に確かめ直したこと

PLAN.md の 0-f-2 にある版と事実を、作業計画の前に確かめ直した。

| 項目 | 結果 |
|---|---|
| 版（rubygems の API） | oauth2 2.0.25、omniauth-oauth2 1.9.0、omniauth 2.1.4、faraday 2.14.4、jwt の 2.x は 2.10.3 で、0-f-1 の調査と同じ。jwt は 3.3.0 が出ているが、3.x には上げない |
| 依存（API v2） | oauth2 2.0.25・omniauth-oauth2 1.9.0・omniauth 2.1.4・faraday 2.14.4・faraday-net_http 3.0.2・jwt 2.10.3 の依存は PLAN.md の表と同じ |
| advisory | ローカルの ruby-advisory-db は upstream の最新のコミットと同じ（2026-10-06）。GitHub Advisory Database でも、対象の gem と新しく入る gem に新しい advisory はない |
| lock の解決 | epic の lock のコピーに `BUNDLE_GEMFILE` を向けて `bundle lock` だけを実行し、gem ごとに変わる gem を事前に確かめた。faraday は faraday-net_http を一時固定しないと、`--conservative` では 2.0.0 で止まる |
| oauth2 2.0.25 のソース | `authorize_url` は `oauth/authorize`、`token_url` は `oauth/token`、`auth_scheme` は `:basic_auth` が既定。`:request_body` は本文に client_id・client_secret を足す（1.4.7 と同じ）。`AuthCode#get_token` は渡された `redirect_uri` をそのまま本文に入れる |
| omniauth-oauth2 1.9.0・omniauth 2.1.4 のソース | `build_access_token` は `redirect_uri: callback_url` を渡し、`callback_url` はクエリ付き（`full_host + callback_path + query_string`。omniauth 2.0.4 と同じ）。`callback_phase` は state を error より先に確かめ、`secure_compare` で比べる。`OAuth2::TimeoutError`・`OAuth2::ConnectionError` も `:timeout` として扱う |

### 作業計画で決めたこと

| 論点 | 決めたこと | 理由 |
|---|---|---|
| 版 | PLAN.md の版のまま | 上の「着手時に確かめ直したこと」 |
| RP に足すテスト | 2 本に分けて `test/integration/my_op_login_test.rb` に足し、gem を上げる前に単独でコミットする。(a) トークン要求は client_id と client_secret を本文で送り、Authorization ヘッダーを付けない、(b) トークン要求の `redirect_uri` は、認可要求の `redirect_uri` にコールバックのクエリ（code・state）が付いたもの | 本文で認証することは 1 つの振る舞いなので (a) は 1 本にまとめた。introspection 用の provider は同じストラテジーで client_id が違うだけなので足さない |
| `rubocop:disable` | RS `apples_controller.rb`・RP `my_op.rb` とも今のまま残す | 下の「`rubocop:disable`」 |
| ブラウザでの手動確認 | gem をすべて上げた後に 1 回。development DB は戻さず、変化を件数で記録する | 両方の流れは E2E が毎コミット確かめている。DB を戻すには上書きが要る |
| コミットの順番 | 0-f-1 と同じく gem ごとに RS → RP | RP のテストだけは、gem を上げる前に最初にコミットした |

### gem ごとの対応

| gem | バージョン | アプリ | 対応 |
|---|---|---|---|
| jwt | 2.2.3 → 2.10.3（RS）、2.5.0 → 2.10.3（RP） | RS・RP | RS は oauth2 1.4.7（`jwt < 3.0`）のうちに上げた。RP は Gemfile に明記した（`my_op.rb` が直接使う）。依存に base64 が入るが lock は 0.1.1 のまま |
| oauth2 | 1.4.7 → 2.0.25 | RS・RP | 下の「oauth2 2.x の既定値」。snaky_hash 2.0.7・version_gem 1.1.15・auth-sanitizer 0.2.3・anonymous_loader 0.1.3 が入る。RS は hashie 5.1.0 が入り、multi_json が外れる（RP は hashie 4.1.0 と multi_json が残る） |
| omniauth-oauth2 | 1.7.1 → 1.9.0 | RP | oauth2 と同時（1.7.1 は `oauth2 ~> 1.4`、1.9.0 は `>= 2.0.2`） |
| omniauth | 2.0.4 → 2.1.4 | RP | 依存が `rack >= 2.2.3` と logger になったが、lock は rack 2.2.24・logger 1.5.0・rack-protection 2.1.0 のまま |
| faraday / faraday-net_http | 1.10.6 / 1.0.1 → 2.14.4 / 3.0.2 | RS・RP | faraday-net_http を 3.0.2 に一時固定した。RP は faraday を Gemfile に明記した（JWKS の取得と introspection 画面で直接使う）。1.x の adapter 群・faraday-multipart・faraday-retry・multipart-post・ruby2_keywords が外れる |

- 一時固定は、過去の Step と同じく Gemfile に `gem 'faraday-net_http', '3.0.2'` を足して `bundle update` → 外して `bundle lock --local` → Gemfile が戻り、lock に 3.0.2 が残ることを確かめた
- 作業の後の RS・RP の lock を epic と比べ、変わったのは上の gem と、それに伴って入る・外れる gem だけで、default gem（json 2.6.1・bigdecimal 3.1.1・logger 1.5.0・base64 0.1.1、RP の cgi 0.3.7）と concurrent-ruby 1.1.9 が動いていないことを確かめた。`bin/rails runner` で読み込まれる net-http は 0.3.0.1、uri は 0.12.4（どちらも lock になく、Ruby 3.1.7 の default gem）
- OP の lock は変わっていない
- 上げた gem の advisory（jwt の CVE-2026-45363、oauth2 の CVE-2026-54603）は、その gem のコミットで `.bundler-audit.yml` から消した

### oauth2 2.x の既定値

設定を足す前にテストを流し、既定値の変化で何が変わるかを確かめてから、1.4.7 と同じ挙動に固定した。

| アプリ | 設定を足す前 | 足した設定 |
|---|---|---|
| RS | クライアントクレデンシャルの要求で、client_id と client_secret が本文から Authorization ヘッダー（Basic）に移り、既存のテストが落ちた | `OAuth2::Client.new` に `auth_scheme: :request_body`。`site` はパスなしなので、相対の `oauth/token` でも URL は同じ（テストが URL を確かめている） |
| RP | `site` が `/oauth/authorize` 付きなので、トークン要求の URL が `/oauth/authorize/oauth/token` になり、Authorization ヘッダー（Basic）が付いた。認可要求の URL のテストも落ちた | `client_options` に `authorize_url: '/oauth/authorize'`・`token_url: '/oauth/token'`（1.4.7 の既定値と同じ絶対パス）と `auth_scheme: :request_body`。`site` はそのまま |

- 応答の parse は `SnakyHash::StringKeyed`（Hash のサブクラス）になる。userinfo の応答で `sub`・`email` の読み方が変わらないことを確かめた
- `redirect_uri` は、更新の後もコールバックのクエリ付きのまま送られる（足したテスト (b)）

#### URL の既定値が相対パスになった経緯

oauth2 の CHANGELOG（2.0.0）と、GitHub の PR・issue で確かめた。

| 時期 | 出来事 |
|---|---|
| 2016 年・2018 年 | issue #245・#386: `site` にパスを含めても（例: `https://example.com/blog`）、`/oauth/token` のように `/` で始まる既定値が URL のパスを置き換え、`site` のパスが捨てられる。パスの下に OAuth のエンドポイントを置くサイト（WordPress など）につながらない |
| 2019 年 7 月 | PR #461: 先頭の `/` を外して `oauth/token` と設定すれば、`site` のパスの下につながること（Faraday の時点でできていた）をテストで示した |
| 2019 年 8 月（2.0.0 で公開） | PR #469: 設定を変えなくても動くよう、既定値を `oauth/authorize`・`oauth/token` にした。CHANGELOG では BREAKING の扱い |

- RP の `site`（`http://localhost:3780/oauth/authorize`）は、1.4.7 が `site` のパスを捨てていたので、本来は不要なパスが付いていても動いていた。明記した `authorize_url`・`token_url` は、この挙動を保つためのもの。`site` を `http://localhost:3780` に直すのは、epic を main に取り込んだ後の改善として扱う（docs/IMPROVEMENTS.md の IMP-006。`site` の値の経緯もそこに書いた）
- RS は `token_url` を明記しない（人間が判断）。RS の 4 つの環境ファイル（`.env`・`.env.test`・`.env_e2e`・`.env_template`）の `OIDC_PROVIDER_HOST` はどれも `http://localhost:3780` で、1.4.7 と 2.0.25 の既定値で同じ URL（`http://localhost:3780/oauth/token`）になる。違いが出るのはパス付きの `site` のときだけで、その場合は 1.4.7 の挙動が issue #245 の不具合にあたる（下の表。oauth2 1.4.7 と 2.0.25 の `OAuth2::Client#token_url` で確かめた）

  | `site` | 1.4.7 | 2.0.25 の既定値 | 2.0.25 で `token_url: '/oauth/token'` を明記 |
  |---|---|---|---|
  | `http://localhost:3780` | `http://localhost:3780/oauth/token` | 同じ | 同じ |
  | `http://localhost:3780/` | `http://localhost:3780/oauth/token` | 同じ | 同じ |
  | `http://example.test/op`（仮） | `http://example.test/oauth/token` | `http://example.test/op/oauth/token` | `http://example.test/oauth/token` |

  RS の introspect の要求は `OIDC_PROVIDER_HOST` に文字列で `/oauth/introspect` をつなぐので、仮の例ではトークンの要求と introspect の要求のパスがそろうのは既定値のほう

### テストの追加

- RP に 2 本を足した（上の「作業計画で決めたこと」）。RP は 17 runs → 19 runs
- 壊すと落ちることの確認: oauth2 1.4.7 のうちに、`client_options` に `auth_scheme: :basic_auth` を足すと (a) だけが落ち、`callback_url` からクエリを外すと (b) だけが落ちた。どちらも戻して通ることを確かめた
- oauth2 2.0.25 に上げて設定を足す前は、トークン要求のあるテスト 15 本（(a)・(b) を含む）が、WebMock に登録していない URL（`/oauth/authorize/oauth/token`）への要求でエラーになり、認可要求の URL のテスト 1 本が落ちた

### `rubocop:disable`

- RS `apples_controller.rb` の `validate_bearer_token`: disable を無視して測ると、AbcSize は 30.95/17 のまま、MethodLength は 19/10 → 20/10。disable は要るままで、理由（流れを 1 か所で読める）も変わらないので残した
- RP `my_op.rb`: 書き換えたのはクラス本体の `option :client_options` で、disable の範囲（`id_token_payload` の MethodLength、`fetch_public_keys`〜`verify_nonce!` の Rails/Output）の外。jwt・faraday の更新では中身を変えていない
- どちらも RuboCop（`Lint/RedundantCopDisableDirective` を含む）で指摘なし

### CHANGELOG・ソースで確かめたこと

アプリの挙動に関わりうるものだけを残す。

| gem | 内容 | アプリへの影響 |
|---|---|---|
| jwt 2.6〜2.10 | 2.10.0 で非推奨の警告が増えた。2.7.0 で文字列でない `kid` を拒む。2.10.3 は空の HMAC 鍵を拒む（advisory の修正） | テストの出力とサーバーの出力に非推奨の警告は出ない。ID トークンの検証のテスト 6 本は、同じ例外クラスで落ちる。RP は RS256 だけを使う |
| omniauth-oauth2 1.8〜1.9 | state の確認が error より先になった（1.7.2 から。PLAN.md の表の「1.8 で」を直した）。1.9.0 で state を `secure_compare` で比べ、セッションに state がないと NoMethodError。タイムアウトの rescue が増えた | エラーの経路（同意の拒否、state の不一致）はテストも E2E もなく、確かめていない |
| omniauth 2.1 | rack の要求を 2.2.3 以上に、`after_request_phase` の追加、test mode での `omniauth.origin` の扱い、`callback_path` の nil の修正 | RP は test mode と `after_request_phase` を使わない |
| faraday 2 | 既定の connection は url_encoded のミドルウェアと net_http の adapter。User-Agent が `Faraday v2.14.4` になる | アプリは `Faraday.get` / `Faraday.post` に URL・ハッシュ・ヘッダーを渡すだけ。`FARADAY_DEPRECATE=warn` を付けてテストを流しても、非推奨の警告は出ない |

### 手動確認

全部の gem を上げた後に、`.claude/launch.json` で 3 アプリを起動して確かめた（ログインと同意は人間が操作）。

- ログイン: RP → OP でログイン → RP に戻り「ログインしました」とユーザーのメールアドレスが表示される。OP のログで、トークン要求の本文に client_id と client_secret（`[FILTERED]`）があることを確かめた。同意画面は出ず、OP は認可要求に 302 で応えた
- introspection 用 RP: ログイン → 同意 → RS は正しいトークンで 200、`_bad` を付けたトークンで 401、revoke は 200、revoke の後は 401。RS の introspect は `active: true`（`exp - iat = 600`）→ `active: false` が 2 回。RS のクライアントクレデンシャルの要求も、本文に client_id と client_secret がある
- 3 アプリの `log/development.log` の手動確認の分と、RP・RS の標準出力（起動から停止まで通して読んだ）に、非推奨・警告・認証の失敗はない（既存の `/stylesheets/application.css` と `/favicon.ico` の 404 だけ）。RP の nonce はセッションと ID トークンで一致した。OP の標準出力は最後の部分しか残っておらず、その範囲にも警告はない
- 手動確認用の環境: 手動確認の直前に、3 アプリの development DB・`jwtRS256.key`・RP / RS の `.env` のハッシュが作業の前と一致することを確かめた。手動確認で、RP の development DB は `sessions` が 6 → 8 件（`op_users` は既存のユーザーのまま 1 件）、OP の development DB は `oauth_access_grants` が 5 → 7 件、`oauth_access_tokens` が 15 → 20 件（ログイン 1・introspection 用 1（revoke 済み）・RS のクライアントクレデンシャル 3）に増え、ハッシュが変わった。ほかのテーブルの件数と、RS の DB・鍵・`.env` のハッシュは変わっていない。DB は戻さず、以降の Step の基準は手動確認の後のハッシュにする

### 遭遇した問題

1. lock のコピーで事前に確かめたとき、`diff` の出力（行頭が `> ` の 2 文字）に `git diff` 用の正規表現（行頭が 1 文字）を使ったため、変化がないように見えた。空白の数を合わせてやり直した
2. ブラウザペインが画面に出ていない状態では、AI から表示できない。手動確認の前に、人間にペインを開いてもらった

### 確認結果

- minitest: 各コミットの前に流して、RS 8 runs、RP 19 runs（最初のコミットでテストを 2 本足した後の件数。0-f-1 の後は 17 runs）、0 failures（非推奨警告は `:raise` のまま）。OP は変えていない
- E2E: 各コミットの前に流して、どれも 10 passed
- RuboCop: RS・RP とも `no offenses detected`。bundler-audit: 3 アプリとも `No vulnerabilities found`（無視リスト込み）。無視リストを空にした bundler-audit で、jwt・oauth2・omniauth・faraday は報告されない。brakeman: 3 アプリとも `Security Warnings: 0`、`Ignored Warnings: 2`
- 3 アプリとも `bin/rails zeitwerk:check` が通り、`bin/rails runner` で起動する。`bin/rails s` は E2E の起動と launch.json で確認した。Puma の版を起動の出力で確かめたのは RS・RP（6.6.1）で、OP は起動の出力が残っておらず確かめていない（OP の gem はこの Step で変えていない）

### コードレビュー（`/code-review`）

| 指摘 | 対応 |
|---|---|
| RP・RS の標準出力に警告がないと書いているが、`preview_logs` の検索は部分一致で、正規表現で探した結果は 0 件だっただけ | 止めたサーバーの出力を起動から停止まで通して読み、RP・RS に警告・非推奨がないことを確かめた。OP は最後の部分しか残っていないことを書き足した |
| 3 アプリが Puma 6.6.1 で起動すると書いているが、この Step で版を見たのは RP だけ | RS も起動の出力で 6.6.1 を確かめた。OP は確かめていないと書いた |
| RP を 17 runs で流したと読めるが、テストを足すコミットが最初なので、gem を上げたどのコミットの前も 19 runs | 19 runs に直し、17 runs は 0-f-1 の後の件数だと書いた |
| `jwt` と `faraday` を Gemfile に版の制約なしで足したので、`--conservative` を付けない `bundle update` で jwt 3.x に上がる。faraday-net_http 3.0.2 の固定も lock にしかない | 対応しない。Gemfile のほかの gem も版の制約を書いていない。faraday-net_http は cgi などと同じ一時固定のやり方で、0-f-1 のコードレビューで同じ判断をした。gem を上げるたびに lock の差分を確かめている |
| テスト (a) はブロックの引数を `request` にして、統合テストの `request` を隠している。(b) は `token_request` | 対応しない。(a) は同じファイルの既存のテスト（code_verifier）と同じ書き方。(b) はブロックの外の `request`（コールバックの要求）を使うので名前を変えた |
| RS は `token_url` を明記せず、相対パスの既定値に頼っている。`OIDC_PROVIDER_HOST` をパス付きにすると 1.4.7 と違う URL に送る | 対応しない（人間が判断）。上の「URL の既定値が相対パスになった経緯」 |
| RS はリクエストのたびに `OAuth2::Client` を作り、クライアントクレデンシャルでトークンを取り直す | 対応しない。元からの挙動で、アップグレード中は変えない。epic を main に取り込んだ後の改善として扱う（docs/IMPROVEMENTS.md の IMP-007） |

## Step 0-f-3: OP の doorkeeper 系の gem の更新（2026-10-08）

- ブランチ / PR: `upgrade/step0f3-doorkeeper` / [#19](https://github.com/thinkAmi-sandbox/oidc_op_rp-sample/pull/19)
- バージョン: 変更なし（Ruby 3.1.7 / Rails 6.1.7.10）

### 着手時に確かめ直したこと

PLAN.md の 0-f-3 にある版と事実を、作業計画の前に確かめ直した。gem のソースは、0-f-1 で承認済みの `.gem`（doorkeeper 5.5.4・5.6.9・5.7.1、doorkeeper-openid_connect 1.8.9、jwt 2.10.3。版・サイズとも PLAN.md と同じ）を展開して読んだ。GitHub には `v1.8.9`・`v5.6.8`・`v5.6.9` のタグがない。

| 項目 | 結果 |
|---|---|
| 版（rubygems の API） | doorkeeper の 5.5・5.6・5.7 系の最新は 5.5.4・5.6.9・5.7.1、doorkeeper-openid_connect は Rails 6 を外していない 1.8.9 で、0-f-1 の調査と同じ。0-f-1 の後に doorkeeper 5.9.9・6.0.0.rc2、doorkeeper-openid_connect 1.10.2〜1.10.5・2.0.0 が出たが、どれも Ruby 3.2 以上か、Rails 6 を外した系列 |
| 依存（API v2） | doorkeeper-openid_connect 1.8.0〜1.8.10 の doorkeeper・json-jwt・jwt の要求と、doorkeeper 5.5.4・5.6.9・5.7.1 の `railties >= 5` は PLAN.md の表と同じ |
| advisory | GitHub Advisory Database で、doorkeeper・doorkeeper-openid_connect・jwt・json-jwt に、上げる先の版を対象とする新しい advisory はない。ローカルの ruby-advisory-db は 0-f-2 と同じ（2026-10-06） |
| lock の解決 | epic の lock のコピーに `BUNDLE_GEMFILE` を向けて `bundle lock` だけを実行した。何も固定しないと、`--conservative` を付けても doorkeeper-openid_connect は 1.10.1 になり、jwt 3.3.0 と ostruct 0.6.3 が入る。1.10.5 の CHANGELOG（#329）によると、1.9.0〜1.10.4 は doorkeeper 5.5 で起動時に NameError、5.6・5.7 で discovery が壊れる |

### PLAN の表から直したこと

0-f-1 の作業計画のときの調査（サブエージェント）のうち、ソースと CHANGELOG で確かめて違っていたもの。PLAN.md の 0-f-3 の表を直した。

| PLAN の記述 | 確かめた結果 |
|---|---|
| client_credentials の scope の確認が 5.5.3 から変わった | 5.6.0.rc2（#1558）。`doorkeeper-5.6.9/lib/doorkeeper/oauth/client_credentials/validator.rb` で `return true if @request.scopes.blank? && application_scopes.blank?` になった。RS は `scope=introspection` を送るので影響しない |
| トークン応答の `Cache-Control` が `no-store, no-cache` になる | gem は `no-store, no-cache` を返すが、Rails 6.1 が `no-store` にまとめる（`actionpack-6.1.7.10/lib/action_dispatch/http/cache.rb` の `merge_and_normalize_cache_control!`）ので、応答の値は変わらない。変わるのは `Pragma: no-cache` が消えること（5.6.6 #1644。5.8.0 #1712 で戻る）。下の「応答ヘッダーの前後比較」 |
| 独自の claim を先に混ぜる順番に変わった（#273）。使っていない経路の変化に `prompt=select_account`（#279）、`prompt=none` と `max_age`（#275） | どれも doorkeeper-openid_connect 1.10.0 の変更で、1.8.9 には入らない。`doorkeeper-openid_connect-1.8.0/lib/doorkeeper/openid_connect/id_token.rb` と 1.8.9 の差分は `as_jws_token`（json-jwt の `sign` → `::JWT.encode`。ヘッダーに `typ`・`kid` を明示）だけ |
| `pkce_code_challenge_methods` の既定値は今と同じ | 設定は 5.8.0（#1735）で入るもので、5.7.1 にはない。`doorkeeper-5.7.1/lib/doorkeeper/oauth/pre_authorization.rb` も、今と同じく `plain` か `S256` を受け付ける |

確かめて PLAN.md どおりだったもの: 同意画面を省く条件（5.6.6 #1646 で confidential のアプリだけになる。5.6.9・5.7.1 の `matching_token_for` は `include_expired: true` が既定）、`doorkeeper-5.7.1/lib/doorkeeper/models/concerns/expirable.rb` は 5.5.2 と同じ、マイグレーションは新しいものがない（doorkeeper の雛形は列の並びだけというサブエージェントの報告。doorkeeper-openid_connect の generators が 1.8.0 と 1.8.9 で同じことは自分で確かめた）、kid は json-jwt 1.14.0 も ruby-jwt の `JWT::JWK::Thumbprint` も RFC 7638 の thumbprint、ヘッダーの `typ` は 1.8.8 で戻った。doorkeeper 5.5.4 → 5.7.1 のソースの差分はサブエージェントで読み、要点（エラー画面のステータス、ヘッダー、client_credentials、同意画面を省く条件、form_post）は自分でソースで確かめた。

### 作業計画で決めたこと

| 論点 | 決めたこと | 理由 |
|---|---|---|
| 版 | PLAN.md の版のまま（doorkeeper 5.5.4 → 5.6.9 → 5.7.1、doorkeeper-openid_connect 1.8.9、jwt 2.10.3） | 上の「着手時に確かめ直したこと」 |
| 先に足すテスト | kid 2 本（JWKS の kid が署名鍵の RFC 7638 の thumbprint、ID トークンのヘッダーの kid が JWKS と同じ）、同意画面を省く条件 2 本（期限切れでも revoke されていないトークンがあれば省く、revoke 済みしかないと出す）、テストのない経路 3 本（form_post、エラー画面、同意の拒否）。gem を上げる前に 1 つのコミットにする | kid のテストは JWT のライブラリを使わずに書き、ライブラリが変わっても同じテストで前後を比べられるようにした。有効なトークンで省くことは E2E の logout が確かめている。confidential の条件（5.6.6）は、public のアプリがないので足さない |
| `JSON::JWT` の書き直し | gem を上げる前に ruby-jwt に書き直す。jwt を OP の Gemfile の test グループに明記する | json-jwt が署名した ID トークンで、書き直したテストが通ることを確かめられる。テストの変更と gem の変更が別のコミットになる。テストが直接使う gem なので明記した（RP と同じく版の制約は書かない） |
| 一時固定 | jwt 2.10.3、doorkeeper-openid_connect 1.8.9、doorkeeper 5.6.9 を一時固定で入れ、Gemfile に版の制約は残さない | 過去の Step と同じやり方。固定しないと jwt は 3.3.0、doorkeeper-openid_connect は 1.10.1、doorkeeper は 5.6.9 を飛ばして 5.7.1 になる |
| 意図的な仕様変更 | discovery の `code_challenge_methods_supported` に加えて、`/.well-known/oauth-authorization-server` とエラー画面のステータスも「意図的な仕様変更」にする。`Pragma` が消えることは記録だけにする | 下の「意図的な仕様変更」。`Pragma` は 0-f-1 で `Cache-Control` を記録だけにしたのと同じ扱い |
| E2E のスナップショットの更新 | doorkeeper-openid_connect 1.8.9 のコミットに含める | 分けると、どちらかのコミットで E2E が落ちる |
| 上書きしているビュー | 変えない。上げるたびに雛形と比べる | 今の HTML と挙動を保つ。新しい雛形に合わせるのは epic を main に取り込んだ後（docs/IMPROVEMENTS.md の IMP-008） |
| ブラウザでの手動確認 | gem をすべて上げた後に 1 回 | 各コミットで E2E を流している。手動確認用の DB に残るトークンで、同意画面を省く経路と出る経路の両方を確かめられる |

### gem ごとの対応

OP の gem を 1 つずつ上げ、そのたびにコミットした。RS・RP は変えていない。

| gem | バージョン | 対応 |
|---|---|---|
| jwt | なし → 2.10.3 | test グループに明記し、一時固定で入れた。依存の base64 は 0.1.1 のまま |
| doorkeeper | 5.5.2 → 5.5.4 | 固定不要（doorkeeper-openid_connect 1.8.0 が `< 5.6`）。5.5.3 の redirect_uri のクエリの拒否（#1528）は 5.5.4 で戻った（#1535） |
| doorkeeper-openid_connect | 1.8.0 → 1.8.9 | 一時固定。json-jwt・aes_key_wrap・bindata が外れた。`e2e/baseline/discovery.json` を更新し、json-jwt の CVE-2023-51774 を `.bundler-audit.yml` から消した |
| doorkeeper | 5.5.4 → 5.6.9 | 一時固定。エラー画面のテストの期待値を 400 に直した。CVE-2023-34246（5.6.6 で修正）を `.bundler-audit.yml` から消した |
| doorkeeper | 5.6.9 → 5.7.1 | 固定不要（doorkeeper-openid_connect 1.8.9 が `< 5.8`） |

- 一時固定は、過去の Step と同じく Gemfile に版を足して `bundle update`（jwt は `bundle install`）→ 外して `bundle lock --local` → Gemfile が戻り、lock に固定した版が残ることを確かめた。`bundle lock --update` は lock にない gem には使えない（`Could not find gem 'jwt'`）
- 作業の後の OP の lock を epic と比べ、変わったのは上の gem と、外れた 3 つだけ。default gem（json 2.6.1・bigdecimal 3.1.1・logger 1.5.0・base64 0.1.1 など）と concurrent-ruby 1.1.9 は動いていない
- doorkeeper の新しい設定（`force_pkce`、`revoke_previous_client_credentials_token`、`custom_access_token_attributes` など）はすべて既定で無効のまま

### 意図的な仕様変更

どれも gem の更新に伴うもので、設定では元に戻せない。RP・RS は使わない。

| 変化 | 前 | 後 | 版 | 確かめ方 |
|---|---|---|---|---|
| discovery に `code_challenge_methods_supported` が増える | なし | `["plain", "S256"]` | doorkeeper-openid_connect 1.8.3（#180）。`oauth_access_grants` に PKCE の列があると出す | E2E のスナップショット（`e2e/baseline/discovery.json` を更新）。差分はこの項目だけ |
| `/.well-known/oauth-authorization-server` が増える | ルートなし（test 環境では `ActionController::RoutingError`） | discovery と同じ応答を 200 で返す | doorkeeper-openid_connect 1.8.1（#152）。ルートは discovery と一緒に足され、これだけを外す設定はない | `bin/rails routes`、下の「応答ヘッダーの前後比較」 |
| 認可エンドポイントのエラー画面（登録されていない redirect_uri など）のステータス | 200 | エラーに応じて 400（`invalid_client`・`unauthorized_client` は 401） | doorkeeper 5.6.7（#1676）。`render :error, locals: {...}, status: pre_auth.error_response.status`。本文は同じ | OP のテスト「登録されていない redirect_uri では、エラーの説明を 400 で表示する」 |

### テストの追加

- OP に 7 本を足した（上の「作業計画で決めたこと」）。OP は 18 runs → 25 runs。JWKS の kid のテストは `discovery_test.rb`、ID トークンの kid と同意画面を省く条件は `authorization_code_flow_test.rb`、form_post・エラー画面・拒否は新しい `authorization_endpoint_test.rb`
- 壊すと落ちることの確認（doorkeeper 5.5.2 のうちに、`test/support/` に一時的なパッチを置いて流し、消した）
  - JWKS の kid を別の値にすると、kid の 2 本と、JWKS で ID トークンを検証するテストが落ちる
  - 期限切れのトークンを同意画面を省く判定から外す（5.6.0〜5.6.2 の挙動）と、期限切れのテストだけが落ちる
  - revoke 済みのトークンも判定に使うと、revoke 済みのテストだけが落ちる
  - `form_post.html.erb` を 5.7.1 の雛形と同じ `auth.body` にすると、form_post のテストだけが落ちる
- ruby-jwt に書き直したテスト: JWKS に別の公開鍵を同じ kid で出すと、`JWT::VerificationError` で落ちる。`JWT.decode` に JWKS を渡すので、kid で鍵を探すところも通る

### 応答ヘッダーの前後比較

更新の前（doorkeeper 5.5.2 / doorkeeper-openid_connect 1.8.0）と後（5.7.1 / 1.8.9）で、使い捨ての統合テストから OP の応答のステータスとヘッダーを書き出して比べた。対象は discovery・`oauth-authorization-server`・JWKS・同意画面・エラー画面・拒否・form_post・同意・トークン（成功・エラー）・userinfo（成功・エラー）・introspect（成功・エラー）・revoke。

| 応答 | 変化 |
|---|---|
| discovery | `Content-Length` が増えた（`code_challenge_methods_supported` の分）。ほかのヘッダーと Cookie は同じ |
| `oauth-authorization-server` | ルートなし → 200（discovery と同じヘッダー） |
| エラー画面 | 200 → 400。ステータスが 200 でなくなったので、`ETag` が付かず、`Cache-Control` が `max-age=0, private, must-revalidate` → `no-cache` |
| トークン（成功・エラー）、userinfo のエラー、introspect のエラー | `Pragma: no-cache` が消えた。`Cache-Control` は `no-store` のまま |

- discovery と userinfo のコントローラーの基底が `Doorkeeper::ApplicationController` から `ApplicationMetalController` に変わった（doorkeeper-openid_connect 1.8.2 #170）が、ヘッダーと Cookie に違いはない
- `Pragma` が消えた後も、RP・RS を通す E2E と手動確認は通る
- 追記（Step 1-b-3-2）: トークン要求の成功の応答の `Pragma: no-cache` は、doorkeeper 5.8.0（#1712）で戻った。エラーの応答には戻っていない。Step 1 で「挙動を変えない」の定義（PLAN.md の 3 章の 2）を決めた後なので、1-b-3-2 では、戻ることを記録だけにせず「意図的な仕様変更」として扱った（下の Step 1-b-3-2「意図的な仕様変更」の「`Pragma` の扱いの経緯」）

### ビュー・ロケールの比較

上げるたびに、`app/views/doorkeeper/**`・`app/views/layouts/doorkeeper/*` と `config/locales/doorkeeper*.en.yml` を、lock の gem の雛形と 1 ファイルずつ比べた。上書きしているビューとロケールは変えていない。

| 版 | 雛形と違うファイル |
|---|---|
| 5.5.4 / 1.8.0 | `authorizations/new.html.erb`（nonce の hidden field を 2 つ足した分。5.5.2 と同じ）、`doorkeeper.en.yml` |
| 5.6.9 / 1.8.9 | 上に加えて `authorizations/error.html.erb`（雛形は `local_assigns[:error_response]` を読む。5.6.6） |
| 5.7.1 / 1.8.9 | 上に加えて `authorizations/form_post.html.erb`（雛形はローカル変数 `auth` を読む。5.7.0 #1702） |

- 上書きしているビューはインスタンス変数（`@pre_auth`・`@authorize_response`）を読む。5.7.1 のコントローラーも両方をインスタンス変数に入れるので、表示は変わらない（足したテスト）。同意画面の hidden field の重複 ID は 5.6.0.rc1（#1552）で雛形からなくなったが、上書きしているビューには残る
- 上書きされていない雛形は、どの版にもない
- `doorkeeper.en.yml` は 5.5.2 の gem と同じ。5.5.4〜5.7.1 の gem の `en.yml` は互いに同じで、違いは 5.5.3 で増えた `forbidden_token.missing_scope` だけ（gem のロケールも読まれるので訳は欠けない）。`doorkeeper_openid_connect.en.yml` は 1.8.0・1.8.9 と同じ
- nonce の hidden field は 1.8.9 でも要る（`AuthorizationsExtension` が `pre_auth_param_fields` に `nonce` を足す。1.8.9 では `config.to_prepare` で prepend する）

### kid の値

- 手動確認用と同じ `jwtRS256.key` で、`Doorkeeper::OpenidConnect.signing_key_normalized[:kid]` を更新の前・doorkeeper-openid_connect 1.8.9 の後・全部上げた後に書き出し、3 つが一致することを確かめた（値は記録していない）
- E2E の ID トークンのヘッダーと JWKS のスナップショット（`typ`・`alg`・`kid` の型）にも差分はない

### 手動確認

全部の gem を上げた後に、`.claude/launch.json` で 3 アプリを起動して確かめた（同意は人間が操作）。

- ログイン（RP の my_op）: RP の「Re Login」から、OP のログイン画面も同意画面も出ずに RP に戻り、「ログインしました」とユーザーのメールアドレスが表示された。OP のログで `AuthorizationsController#new` が 302 を返した。手動確認用の DB には 0-f-2 のときの、期限切れで revoke されていないトークンがあり、それで同意画面が省かれた。RP の ID トークンの検証（JWKS の取得、nonce の比較）も通った
- introspection 用 RP: 前回のトークンが revoke 済みなので同意画面が出て、Authorize の後、RS は正しいトークンで 200、`_bad` を付けたトークンで 401、revoke は 200、revoke の後は 401。RS の introspect は `active: true`（`exp - iat = 600`）→ `active: false` が 2 回。0-f-2 と同じ
- サーバーの出力: `preview_logs` でエラーの行、`warning`、`DEPRECATION` を探した。RP・RS には何もなく、OP には既知の listen の finalizer の警告（Step 0-b・0-f-1。`listen-3.10.1/lib/listen/fsm.rb:78`）が 1 件だけ出た
- 手動確認用の環境: 作業の開始時に、件数が Step 0-f-2「手動確認」の後と同じこと（RP `sessions` 8・`op_users` 1、OP `oauth_access_grants` 7・`oauth_access_tokens` 20）を確かめてハッシュを控え、手動確認の直前に一致を確かめた。手動確認で、OP の development DB は `oauth_access_grants` が 7 → 9 件、`oauth_access_tokens` が 20 → 25 件（my_op 1・introspection 用 1（revoke 済み）・RS のクライアントクレデンシャル 3）に増えた。RP の development DB は `sessions` が 8 件のまま 1 行が更新された。どちらもハッシュが変わった。RS の DB・鍵・`.env` のハッシュは変わっていない。以降の Step の基準は手動確認の後のハッシュにする

### 遭遇した問題

1. lock のコピーで事前に確かめたとき、Gemfile のコピーを書き換える Ruby のワンライナーが日本語のコメントで `invalid byte sequence in US-ASCII` になり、コピーの Gemfile が壊れた。コピーを作り直し、`LC_ALL=ja_JP.UTF-8` を付けた perl で書き換えた（TIPS.md にある注意）
2. 応答ヘッダーを書き出すテストで、更新の前は `/.well-known/oauth-authorization-server` が `ActionController::RoutingError` になった（test 環境は例外を投げる）。ルートなしとして記録した

### 確認結果

- minitest: OP 25 runs、0 failures（非推奨警告は `:raise` のまま）。テストを 7 本足したコミット（この Step の 2 つ目）の後は、どのコミットの前も 25 runs。RS・RP は変えていない
- E2E: テストと gem のコミットの前に流して、どれも 10 passed（doorkeeper-openid_connect 1.8.9 のコミットは、スナップショットを更新した後）
- RuboCop: OP `no offenses detected`。bundler-audit: OP `No vulnerabilities found`（無視リスト込み）。無視リストを空にした bundler-audit で、doorkeeper・doorkeeper-openid_connect・jwt は報告されない。brakeman: OP `Security Warnings: 0`、`Ignored Warnings: 2`
- OP の `bin/rails zeitwerk:check` が通り、`bin/rails runner` で起動する。`bin/rails s` は E2E の起動と launch.json で確認し、Puma 6.6.1 で起動する
- テストとサーバーの出力に、jwt の非推奨の警告（`[DEPRECATION WARNING]`）は出ない

### コードレビュー（`/code-review`）

| 指摘 | 対応 |
|---|---|
| PLAN.md の「doorkeeper-openid_connect も 2.0 まで新しいマイグレーションはない」は、2.0.0 でマイグレーションが不要だとも読める。2.0.0.beta1 の CHANGELOG（#243）は `post_logout_redirect_uris` の列を必須にしている | 「1.8.9 まではない。2.0.0 は `post_logout_redirect_uris` の列を足すマイグレーションが必要」に直した |
| 上書きしている `form_post.html.erb`・`error.html.erb` が、doorkeeper の内部のインスタンス変数（`@authorize_response`・`@pre_auth`）を読み続けている。`local_assigns[:auth] \|\| @authorize_response` のように書けば、HTML を変えずにどの版でも動く | 対応しない。作業計画のとおり、この Step ではビューを変えない。足したテスト（form_post・エラー画面）が、doorkeeper を上げるたびにこの依存を確かめる。ビューを雛形に合わせるときに一緒に直す（docs/IMPROVEMENTS.md の IMP-008） |
| 確認結果の「最初のコミットでテストを 7 本足した」が事実と違う（最初のコミットは PR #18 のリンクの修正） | 「テストを 7 本足したコミット（この Step の 2 つ目）」に直した |
| 意図的な仕様変更の表の「前は 404」は確かめていない（確かめたのは test 環境の `ActionController::RoutingError` だけ） | 「ルートなし（test 環境では `ActionController::RoutingError`）」に直した |
| 新しく書いた LOG の行で、gem 内のファイルを `gem名-バージョン/` から書いていない（`id_token.rb`・`pre_authorization.rb`・`expirable.rb`） | `gem名-バージョン/` からのパスに直した |
| 確認結果の「E2E を各コミットの前に流した」は、docs だけのコミットにはあてはまらない | 「テストと gem のコミットの前に流した」に直した |
| `gem 'jwt'` に版の制約がないので、`bundle update jwt` で jwt 3.3.0 になり、doorkeeper-openid_connect 1.8.9 との組み合わせを確かめていない状態になる | 対応しない（作業計画で人間が判断）。RP と同じく、Gemfile のほかの gem にも版の制約は書いていない。PLAN.md 7 章の jwt と doorkeeper の行に、一時固定で入れたことを書いた |
| kid のテストで、`n` の base64url の計算が、同じファイルの既存のテストと重なっている | 対応しない。2 か所だけで、それぞれのテストを単独で読めるようにした |
| 足したテストの多くが `authorization_params(nonce: SecureRandom.hex(16), code_verifier: SecureRandom.urlsafe_base64(48))` を繰り返している | 対応しない。既存のテストと同じ書き方。ヘルパーに既定値を持たせると、既存のテストもすべて書き換わる |

## Step 0-g: CI（GitHub Actions）（2026-10-08）

- ブランチ / PR: `upgrade/step0g-ci` / [#20](https://github.com/thinkAmi-sandbox/oidc_op_rp-sample/pull/20)
- バージョン: 変更なし（Ruby 3.1.7 / Rails 6.1.7.10）

### 前倒しの判断

- PLAN.md では、CI を最後の「仕上げ」で設定する計画だった。Step 1（Rails 7.0）以降は `app:update` や `load_defaults` で変更が大きくなるので、Step 1 の前に前倒しした（人間の判断）。PR のたびに、手元と同じ検査がきれいな環境で流れることを確かめられる
- Dependabot は仕上げに残した。アップグレード中の「一度に上げるのは 1 つだけ」とぶつかるため
- PLAN.md の仕上げにあった「GitHub Actions」と「CI での OP の署名鍵の扱い」を 0-g に移した。10 章の完了条件に「CI が通る（Step 0-g 以降）」を足した（人間が承認）

### 作業計画で決めたこと

| 論点 | 決めたこと | 理由 |
|---|---|---|
| ジョブの分け方 | `rails`（3 アプリの matrix）・`e2e`・`public-safety` と、結果をまとめる `ci-result` | 検査の種類ごとに分けると、Ruby と bundle の準備をジョブの数だけ繰り返す。アプリごとなら準備は 1 回で、どのアプリのどの検査が落ちたかはステップで分かる。前の検査が失敗しても後の検査は流す。ブランチ保護で必須にするのを `ci-result` だけにすると、matrix の名前やジョブが変わってもブランチ保護を直さなくて済む |
| 動かす条件 | epic と main への PR と push、`workflow_dispatch` | `upgrade/*` への push でも動かすと PR と二重になる。paths で絞ると、ブランチ保護で必須にしたときに、動かなかった PR が止まる。`main` にはワークフローのファイルがないので、epic を取り込むまで `main` への push では動かない |
| ランナー | `ubuntu-24.04` に固定 | Ruby 3.1.7 のビルド済みのものは `ubuntu-26.04` にない。`ubuntu-latest` が 26.04 に移ると入らなくなる |
| Ruby | `ruby/setup-ruby` で各アプリの `.ruby-version` を読み、`bundler-cache: true` | 版の置き場所を増やさない。bundle の置き場所も手元と同じ各アプリの `vendor/bundle` になる |
| Node | `e2e/.node-version` を足し、`e2e/mise.toml` からも読ませる | `actions/setup-node` は `mise.toml` を読めない。アプリの `.ruby-version` と同じ形にして、版の置き場所を 1 つにする。mise ごと入れる `jdx/mise-action` は、アプリのディレクトリで mise が Ruby を入れようとするのを止める設定が要り、GitHub・ruby 以外の action が増えるので採らなかった |
| E2E の起動スクリプト | mise がなければ PATH の Ruby で動かす | CI には mise がない。手元の挙動は変わらない |
| lock のプラットフォーム | 3 アプリの lock に `x86_64-linux` を足す | setup-ruby は frozen で入れるので、lock にないプラットフォームでは入らない見込み。frozen を外すと CI が毎回 lock を解決し直し、手元と同じ版である保証がなくなる |
| OP の署名鍵 | CI の `rails` ジョブで、OP のときだけ、E2E の起動スクリプトと同じ方法で作る | アプリのコードを変えずに済む。テストは鍵の中身に依存しない（Step 0-d-2）。鍵をコミットするのは安全チェックの対象で、initializer でテスト時に作るのはアプリの変更になる |
| E2E のブラウザ | `--with-deps --only-shell chromium` で毎回入れる | 手元も headless shell で流れている。Playwright の CI の文書（playwright.dev の Continuous Integration）は、復元にかかる時間がダウンロードと同じくらいなので、ブラウザのバイナリのキャッシュを勧めていない |
| E2E が失敗したとき | レポート・トレースと 3 アプリの `log/development.log` を artifact に 7 日残す | リポジトリは public で、GitHub の文書は artifact の取得に要るのをリポジトリの読み取り権限としているので、誰でも取れるものとして扱う。中のトークンと Cookie は、CI の使い捨ての署名鍵と DB で作られたもので（鍵そのものは artifact に入れない）、ユーザーの資格情報は元からリポジトリにあるダミー |
| 安全チェック | 追跡中の全ファイルを `--files` で、PR（push は前後の範囲）のコミットメッセージを `--message` で検査する。PR のタイトル・本文は検査しない | 全ファイルが今は通るので、差分でなく全体を不変条件にできる。PR の本文を編集したときにも動かすには、全ジョブが流れ直さないよう別のワークフローが要る。本文は CLAUDE.md の手順で `--message` を通してから出している |
| action | コミットの SHA で固定し、版を行末のコメントに書く。公開から 2 週間以上たった版。`permissions` は `contents: read` だけ、checkout は `persist-credentials: false` | タグは付け替えられる。仕上げの Dependabot はこの形のまま更新できる |
| ブランチ保護 | epic と main で `ci-result` の通過を必須にする（設定は人間）。「ブランチを最新にすること」は必須にしない | epic に入る PR は 1 本ずつ |

### 作業の記録

| 対象 | 対応 |
|---|---|
| 3 アプリの `Gemfile.lock` | `bundle lock --add-platform x86_64-linux` をアプリごとに実行し、アプリごとにコミットした（RS → RP → OP） |
| `e2e/.node-version`・`e2e/mise.toml` | Node の版（24.21.0）を `.node-version` に移し、`mise.toml` は `idiomatic_version_file_enable_tools = ["node"]` だけにした |
| `e2e/scripts/start-server.sh` | mise があれば `mise exec --`、なければ PATH の Ruby で動かす。サーバーは今までどおり `exec` で起動する |
| `.github/workflows/ci.yml` | 上の「作業計画で決めたこと」のとおり |
| ドキュメント | PLAN.md（ロードマップ、PR の単位、0-g の節、仕上げ、10 章）、TIPS.md（CI の結果の読み方）、`e2e/README.md`（Node の版、CI） |

### lock の確かめ方

- `git diff -U0 Gemfile.lock` で増えたのは、3 アプリとも `nokogiri (1.18.10-x86_64-linux-gnu)` とその依存の `racc (~> 1.4)` の行、`sqlite3 (1.7.3-x86_64-linux)`、`PLATFORMS` の `x86_64-linux` だけ。消えた行はない
- `Bundler::LockfileParser` で前後の lock を読み、プラットフォームを除いた gem 名と版の組（RS 98・RP 110・OP 99）、`DEPENDENCIES`、`RUBY VERSION`、`BUNDLED WITH` が同じことを比べた。比べるスクリプトは、lock の puma の版を書き換えると違いを報告した
- 手元の `bundle check` が通り、3 アプリの検査と E2E は前と同じ結果

### E2E の起動スクリプトの確かめ方

- mise がある経路: 今までどおり `mise exec -- npm test` で 10 passed
- mise がない経路: `env -i` で PATH を mise の Ruby 3.1.7 と Node 24.21.0 の `bin` と `/usr/bin:/bin` だけにして `npm test` を流し、10 passed。署名鍵の生成は、手動確認用の鍵を動かさないよう、同じコマンドを scratchpad で mise なしに実行して確かめた（`BEGIN RSA PRIVATE KEY`、パーミッション 600）
- `.node-version` に移した後も、mise は `e2e/.node-version` から 24.21.0 を読む（`mise ls --current`）。`mise trust` のやり直しは要らなかった

### ワークフローの確かめ方（push の前）

- YAML として読めることを Ruby で確かめた。ジョブとステップの並びは計画どおり
- 安全チェックのコミットメッセージの部分を取り出し、PR・push・ブランチの新規作成（`before` が 0）・`workflow_dispatch` の 4 通りで流した。PR と push はこの Step のコミットを検査し、残りの 2 つは飛ばす。参照を動かさない一時的なコミット（`git commit-tree`）にホームディレクトリのパスを入れると、exit 1 で止まった
- 追跡中の全ファイルの検査は、ワークフローを足した後も通る

### 遭遇した問題

1. 鍵を作るステップの `run:` を 1 行で書いたところ、値の中の `perm: 0o600` の「`: `」で YAML の構文エラー（`mapping values are not allowed in this context`）になった。ブロックスカラー（`run: |`）にした
2. `start-server.sh` の最後を `exec run bin/rails server ...` にすると、`exec` はシェルの関数を実行できない。サーバーの起動だけは mise の有無で `exec` の行を書き分けた（書いている途中で気づき、コミットの前に直した）
3. ブランチを `git switch -c upgrade/step0g-ci origin/epic/rails-8.1-upgrade` で作ると、上流が `origin/epic/rails-8.1-upgrade` になり、引数なしの `git push` が epic に向かうおそれがあった。`git branch --unset-upstream` で外した
4. PLAN.md の表の行を `perl -CSD -i -pe` で置換しようとしたが、何も変わらずに正常に終わった。`-CSD` だけではスクリプトの中の日本語が UTF-8 として読まれない。`-Mutf8` を付けると当たることを確かめ、TIPS.md に書いた（置換は Edit で行った）

### CI の結果

PR #20 の最初の実行（head は `docs: record step 0-g and update the upgrade plan` のコミット）で、5 ジョブ（`rails` の 3 つ、`e2e`、`public-safety`）と `ci-result` が通った。全体は約 2 分。ログで次のことを確かめた。

- Ruby は 3.1.7（x86_64-linux）、Bundler は lock の `BUNDLED WITH` の 2.3.27。nokogiri は `1.18.10 (x86_64-linux-gnu)`、sqlite3 は `1.7.3 (x86_64-linux)` が入り、ffi 1.15.3 はソースからビルドできた
- minitest: OP 25 runs・RP 19 runs・RS 8 runs、0 failures。RuboCop は 3 アプリとも `no offenses detected`、`zeitwerk:check` は `All is good!`、brakeman は `Security Warnings: 0`・`Ignored Warnings: 2`
- bundler-audit は advisory のデータベースを取得し（2026-10-07 の版。手元は 2026-10-06 の版。どちらも 1261 件）、3 アプリとも `No vulnerabilities found`
- E2E: Node 24.21.0（`e2e/.node-version` から）、Chrome Headless Shell 153.0.8010.12 だけを入れて 10 passed。OP の署名鍵は起動スクリプトが作った
- 安全チェック: 追跡中の全ファイルと、PR の 9 コミットのメッセージ
- bundle のキャッシュは、最初の実行で保存された。`e2e` ジョブの RP・RS は、先に終わった `rails` ジョブが保存したキャッシュを復元した。npm のキャッシュも `actions/setup-node` が保存した

### コードレビュー（`/code-review`）

| 指摘 | 対応 |
|---|---|
| 「Playwright の CI の文書はブラウザのキャッシュを勧めていない」「artifact はサインインした誰でも取れる」を、この Step で出典を確かめずに書いている | 確かめて直した。Playwright の文書（Continuous Integration）は、復元にかかる時間がダウンロードと同じくらいなので、ブラウザのバイナリのキャッシュを勧めていない。GitHub の文書（ワークフローの artifact のダウンロード）は、取得に要るのをリポジトリの読み取り権限としており、サインインには触れていない。「誰でも取得できるものとして扱う」に直した |
| ワークフローのコメント「ブランチ保護で必須にするのはこのジョブだけ」が、まだ設定されていないブランチ保護を現在形で書いている（CLAUDE.md「まだ存在しないものを現在形で書かない」） | 「必須にする候補はこのジョブだけにして」に直した |
| TIPS.md の mise なしの E2E のコマンドに、確かめたときに付けた `LANG=ja_JP.UTF-8` がない | 足した |
| `e2e/README.md` の「中のトークン・Cookie・署名鍵は CI の使い捨て」が、artifact に署名鍵が入っているように読める | 「トークンと Cookie は CI の使い捨ての署名鍵と DB で作られたもの（鍵そのものは artifact に入れない）」に直した（LOG.md も同じ） |
| bundler-audit の `--update` で、新しい advisory が出ると、変更と関係のない PR でも CI が落ちる | 構成は変えない（作業計画で決めたこと）。落ちたときの手順を TIPS.md の「CI の結果を読む」に書いた |
| 署名鍵を作る 1 行が、ワークフローと `e2e/scripts/start-server.sh` で重なっている | 対応しない。1 行だけで、ワークフローのコメントで起動スクリプトと同じ方法だと書いている。共通にすると、E2E の起動スクリプトに鍵だけを作るモードを足すことになる |
| E2E がジョブの `timeout-minutes`（30 分）で打ち切られると、artifact が残らない | 対応しない。Playwright の起動待ちは 1 アプリ 120 秒、テストは 1 本 30 秒（既定）で、10 本が約 20 秒で終わるので、30 分に届く前に Playwright が失敗として終わる |
| `public-safety` が、ランナーのイメージに入っている Ruby（ubuntu-24.04 は 3.2.3）に依存している | 対応しない。スクリプトは Ruby 2.6 の構文の範囲で書いてあり、macOS 標準の Ruby でも動かしている。イメージから Ruby が外れたら setup-ruby に替える |
| advisory のデータベースを matrix の 3 ジョブで別々に取得している | 対応しない。1 回数秒で、取得した版はジョブのログ（`last updated`・`commit`）で分かる |

### ブランチ保護の設定

人間が GitHub の Settings → Rules → Rulesets で、ブランチのルールセット `upgrade-branches` を作った。設定の内容は `gh api` で読んで確かめた。

| 項目 | 設定 |
|---|---|
| 対象 | `epic/rails-8.1-upgrade` だけ（Active） |
| 必須のチェック | `ci-result`（提供元は GitHub Actions）。「ブランチを最新にすること」はオフ |
| PR | 必須。承認は 0 人、マージの方法はマージコミットだけ（CLAUDE.md の「マージコミットで取り込む」） |
| そのほか | ブランチの削除と force push を禁止 |
| 迂回 | リポジトリの管理者が、PR に限って迂回できる |

- 作業計画からの変更点: `main` は対象にしなかった（人間の判断）。`main` にはまだ `.github/workflows/ci.yml` がないので、`main` から切ったブランチの PR では CI が動かず、`ci-result` を必須にすると待ちのままになるため。epic を `main` に取り込んだ後（仕上げ）に、`main` をルールセットの対象に足す
- 設定の後、PR #20 で `ci-result` が必須のチェックとして扱われ（`gh pr checks 20 --required`）、通っていることを確かめた

## Step 1: Rails 7.0（2026-10-08〜2026-10-09）

- ブランチ / PR: `upgrade/step1-rails70` / [#21](https://github.com/thinkAmi-sandbox/oidc_op_rp-sample/pull/21)
- バージョン: Ruby 3.1.7（変更なし）/ Rails 6.1.7.10 → 7.0.10
- 追随した Rails の既定値は、項目ごとに [defaults/rails-7.0.md](defaults/rails-7.0.md) に記録した（DEF-7.0-01〜37）。このログには、判断の経緯と、項目に収まらないことを書く

### 作業計画で決めたこと

着手時に PLAN.md 8 章の手順で調べ（サブエージェント 3 つ: `new_framework_defaults_7_0.rb` の影響、アップグレードガイドと `app:update`、annotate）、作業計画を出して承認を得た。調べたことは PLAN.md の Step 1 の節に移した。

| 論点 | 決めたこと | 理由 |
|---|---|---|
| 上げる先 | 7.0.10 | 7.0 系の最新で、activesupport が `require "logger"` する修正（rails/rails#54264）が入り、concurrent-ruby を 1.3.5 以上にできる。代わりに activesupport が benchmark・securerandom・drb・mutex_m を依存に足したので、drb・mutex_m は Ruby 3.1.7 の default gem と同じ版、benchmark・securerandom は要件を満たす最小の版（どちらも 0.3.0）に一時固定した |
| sprockets-rails | Gemfile に足さない（当初の計画から変更） | 3 アプリとも `sprockets/railtie` を読み込んでいない。足すと `Bundler.require` で `sprockets-rails-3.2.2/lib/sprockets/rails.rb` が `sprockets/railtie` を読み込み、アセットパイプラインが有効になる |
| annotate | 3.2.0 に上げる（当初は「3.2.0 には上げない」） | 3.1.1 は `activerecord < 7.0` で、Rails 7.0 にできない。OP の注釈に関わる差分はない。annotaterb の 4.23 以上は CI で Ruby 3.3 以上だけを試すので、置き換えは Step 5 のまま |
| Rails 7.0 を必要とする周辺 gem | サブステップ 1-b（別の PR） | Rails と一緒に上げないと解決しない gem は annotate だけだった |
| concurrent-ruby | Step 1 の最後に上げる | advisory 3 件（CVE-2026-54904〜54906）の修正。Rails 7.0.10 なら起動する |
| `app:update` の差分 | アプリ独自の設定は戻し、雛形の変化には追随する。Active Storage のマイグレーションは採用しない | DEF-7.0-01〜14 |
| コミットと PR | 段階ごと・アプリごと（RS → RP → OP）、PR は 1 つ | PLAN.md 4 章 |

### 「挙動を変えない」の定義

`app:update` の差分を確かめていたとき、`server_timing = true`（DEF-7.0-04）を採用するかで、「挙動を変えない」の範囲を人間と決め直した。決めた定義は PLAN.md の 3 章の 2 と CLAUDE.md に書いた。

- Rails の既定値・雛形の変化（A）には追随する。追随しないと、版を上げるたびに古い既定値のままで問題がないかを確かめ続けることになり、セキュリティや性能の改善も取り込めない
- 各システムの業務的な挙動（B。画面の文字、URL・ルーティング、画面遷移、OP・RP・RS の間のやり取り、DB に入るデータ）は変えない。変えるときだけ「意図的な仕様変更」にする
- 知らないうちに追随されると認識がずれるので、A はコミットの前に項目ごとに「何が変わるか・なぜ・影響・提案」を出典（Rails の PR と、上げる先の版の日本語版 Rails ガイド）付きで解説し、返事をもらってからコミットする。振り返りやすいよう、Rails の版ごとのファイル（`docs/upgrade/defaults/`）に ID を振って残す
- Step 0 の判断は見直さない

この定義で、計画のときに「意図的な仕様変更」としていた `X-XSS-Protection`・`button_to`・`<link>` の `media`（DEF-7.0-33〜35）は、Rails の既定値への追随として扱った。Step 1 に「意図的な仕様変更」はない。

### 作業計画からの変更点

- drb 2.1.0 の依存として ruby2_keywords 0.0.5 が lock に入った（Ruby 3.1.7 の default gem と同じ版。計画のダウンロードの一覧になかったので、入れる前に人間が承認した）。default gem と同じ版の drb・mutex_m・ruby2_keywords は、`bundle install` でダウンロードされず、Ruby 3.1.7 の default gem がそのまま使われた
- `app:update` の後、listen を Gemfile から外した（DEF-7.0-06）
- RP の session_store の serializer の設定を、`config/application.rb` から `config/initializers/session_store.rb` の `ActiveSupport.on_load(:active_record)` に移した（RP `77c26df`）。下の「遭遇した問題」の 2
- ブラウザでの手動確認は、計画の「`load_defaults 7.0` の後に 1 回」から、Cookie の鍵の算出方式（グループ 8）の前後を比べられる時点に移した。`load_defaults 7.0` の後は、値の比較と自動の検査だけにした（人間が承認）
- concurrent-ruby は、計画の 1.3.7 ではなく 1.3.8（1.3 系の最新。1.3.7 からの変更は小さな改善 2 つ）にした（人間が承認）
- 追随した既定値の記録の置き場所として `docs/upgrade/defaults/` を作った（README.md と rails-7.0.md）

### gem ごとの対応

| gem | バージョン | アプリ | 対応 |
|---|---|---|---|
| annotate | 3.1.1 → 3.2.0 | RP・OP | Rails 6.1 のうちに上げた。E2E 用の DB で `annotate_models`（OP）・`annotate --models`（RP）を前後で流し、モデルと fixtures の注釈が同じことを確かめた（書き換わったファイルは戻した）。自動実行のフックはどちらも migrate・rollback 系だけ |
| rails 一式 | 6.1.7.10 → 7.0.10 | 3 アプリ | 上の一時固定。zeitwerk 2.4.2 → 2.6.18。sprockets・sprockets-rails が lock から外れた |
| benchmark・securerandom・drb・mutex_m・ruby2_keywords | なし → 0.3.0・0.3.0・2.1.0・0.1.1・0.0.5 | 3 アプリ | activesupport 7.0.10 と drb の依存 |
| listen（と rb-fsevent・rb-inotify・ffi） | 3.10.1 → 削除 | 3 アプリ | DEF-7.0-06 |
| concurrent-ruby | 1.1.9 → 1.3.8 | 3 アプリ | advisory 3 件を無視リストから消した |

- lock の解決は、lock のコピーで旧 lock の gem をすべて固定し、Rails の構成 gem だけを外して解決させ、その lock をアプリに持ち込む方法で行った（TIPS.md「gem の更新」）。何も固定しないと、`--conservative` を付けても jwt 3.3.0・devise 5.0.4・doorkeeper-openid_connect 1.10.1 などに動く
- lock に入れた default gem（json 2.6.1・bigdecimal 3.1.1・logger 1.5.0・base64 0.1.1、RP の cgi 0.3.7）は動いていない

### 遭遇した問題

1. `rails runner` で値を書き出すスクリプトが、値を読む前に `ActionView::Base` を読み込んでいなかったので、`on_load(:action_view)` の中で入る `multiple_file_field_include_hidden` が変わっていないように見えた。関係するクラスを先に読み込むようにして測り直した（TIPS.md）。同じスクリプトが非推奨の `TimeWithZone.name` を呼び、test 環境の `:raise` で止まったこともあった
2. RP だけ、`new_framework_defaults_7_0.rb` の一部の設定が効かなかった。`config/application.rb` の末尾の serializer の設定が、起動の途中で `ActiveRecord::Base` を読み込んでいたため（rails/rails#46277 と同じ）。一時的に `load_defaults 7.0` にして試すと、`disable_to_s_conversion` は `load_defaults 7.0` でも効かないことが分かった。ruby-jp の Scrapbox・Rails の issue・ブログを調べ、activerecord-session_store#142 の書き方（initializer の `ActiveSupport.on_load(:active_record)`）に移した（人間が判断）。詳しくは defaults/rails-7.0.md の「補足」
3. `load_defaults 7.0` の前後で development の値も比べると、OP の development でも `ActionDispatch::Request` が initializer より前に読み込まれていた（web-console 4.2.1 の initializer）。グループ 1 では test 環境の値しか比べていなかった。設定（DEF-7.0-24）を使うコードはないので挙動は変わらない。以降は test と development の両方で比べる（PLAN.md 12 章、TIPS.md）
4. `load_defaults 7.0` の docs のコミットに、`git rm` でステージ済みだった initializer の削除が入ってしまった。push の前に、作業ツリーはそのままでコミットだけを取り消し（`git reset HEAD~1`）、docs のファイルだけでコミットし直した（TIPS.md「コミット」）

### 手動確認

グループ 8（DEF-7.0-36）を有効にする前後で、`.claude/launch.json` から 3 アプリを起動してブラウザペインで確かめた（ログインと同意は人間が操作）。

- グループ 8 なしで RP からログイン → 3 アプリを止め、グループ 8 を有効にして起動し直す → RP のログインは続き、RP の「Re Login」で OP のログイン画面が出た（OP のセッション Cookie が読めなくなった）。もう一度ログインした後、RP のログインと introspection 用 RP の流れ（RS が 200・401・revoke の後に 401、introspect が `active: true`（`exp - iat = 600`）→ `active: false` が 2 回）は Step 0-f-3 と同じだった
- サーバーの出力に、エラー・`warn`・`DEPRECATION` はなく、Step 0-b から出ていた listen の finalizer の警告も出なかった。development の応答に `X-XSS-Protection: 0` と `Server-Timing` が付くことを `curl` で確かめた
- 手動確認用の環境: 作業の開始時に、件数が Step 0-f-3 の手動確認の後と同じことと、ハッシュが変わっていないことを確かめた。手動確認で、OP の development DB は `oauth_access_grants` が 9 → 12 件、`oauth_access_tokens` が 25 → 31 件（my_op 2・introspection 用 1（revoke 済み）・RS のクライアントクレデンシャル 3）、RP の development DB は `sessions` が 8 → 10 件に増え、どちらもハッシュが変わった。RS の DB・署名鍵・`.env`・各アプリの `tmp/development_secret.txt` は変わっていない。以降の基準は手動確認の後のハッシュ

### 確認結果

- minitest: RS 8 runs・RP 19 runs（コードレビューでテストを足した後は 20 runs）・OP 25 runs、0 failures（非推奨警告は `:raise`）。アプリやテストのコードのコミットの前に毎回流した。`CI=1`（eager load あり）でも同じ件数で通る
- E2E: 同じく毎回流して 10 passed。スナップショットの差分なし
- RuboCop（`TargetRailsVersion: 7.0`）: 3 アプリとも `no offenses detected`。bundler-audit: 3 アプリとも `No vulnerabilities found`（無視リストから CVE-2024-54133 と concurrent-ruby の 3 件を消した）。brakeman: 3 アプリとも `Security Warnings: 0`、`Ignored Warnings: 2`
- 3 アプリとも `bin/rails c` で Rails 7.0.10・`load_defaults 7.0`、`bin/rails s` は E2E と launch.json で起動、`zeitwerk:check` は `All is good!`
- 応答の前後比較（使い捨ての統合テスト）: Rails 7.0.10 にしたとき、`app:update` の後、各グループの後に、RS 2・RP 5・OP 20 の応答を書き出して比べた。変わったのは DEF-7.0-15・33〜35 の項目だけ
- `log/development.log` に非推奨警告はない

### CI の結果

PR #21 の最後の実行（head は `docs: record the code review of step 1` のコミット。PR #21 の実行はこの 1 回だけ）で、5 ジョブ（`rails` の 3 つ、`e2e`、`public-safety`）と `ci-result` が通った。全体は約 1 分半。ログで次のことを確かめた。

- minitest: RS 8 runs・RP 20 runs・OP 25 runs、0 failures（手元と同じ件数）。RuboCop は 3 アプリとも `no offenses detected`、`zeitwerk:check` は `All is good!`、bundler-audit は `No vulnerabilities found`、brakeman は `Security Warnings: 0`・`Ignored Warnings: 2`
- E2E: 10 passed
- 安全チェック: 追跡中の全ファイルと、PR の 57 コミットのメッセージ

### コードレビュー（`/code-review`）

| 指摘 | 対応 |
|---|---|
| RP のセッションを JSON で保存することを確かめるテストがなく、serializer の設定を `on_load` に移した変更（`77c26df`）が手動の確認だけで守られている | RP の `test/integration/sessions_test.rb` に「セッションは sessions テーブルに JSON で保存する」を足した。serializer を `:marshal` にしたときと、設定を消したときに `JSON::ParserError` で落ちることを確かめた。RP は 19 runs → 20 runs |
| PLAN.md の Step 1 の「調べたこと」の RP の行が「`load_defaults 7.0` で効く見込み」のままで、後で分かったことと食い違う | 行の末尾に、`disable_to_s_conversion` は `load_defaults 7.0` でも効かないと分かり、`77c26df` で移したことと、defaults/rails-7.0.md の「補足」への参照を足した |
| DEF-7.0-15 に「グループ 7 で有効にする」と未来形が残っている | 「グループ 7 で有効にした。DEF-7.0-35」に直した |
| TIPS.md の「確認のコマンド」に、CI と同じ条件（eager load あり）の minitest がない | `CI=1 mise exec -- bin/rails test` の行を足した |
| フレームワークの早い読み込みを、Step ごとの手作業で確かめる申し送りだけにしている | 対応しない（epic の範囲を超える）。CI で検出する案を、下の IMP-009 に含めた |
| gem（activerecord-session_store・web-console）の早い読み込みを「epic の範囲外」として見送ったが、IMPROVEMENTS.md に足す案を出していない（CLAUDE.md） | 人間の承認を得て、docs/IMPROVEMENTS.md に IMP-009 として足した |

## Step 1-b-1: 起動の途中の読み込みを CI で検出する（2026-10-09）

- ブランチ / PR: `upgrade/step1b-anti-manner` / [#22](https://github.com/thinkAmi-sandbox/oidc_op_rp-sample/pull/22)
- バージョン: Ruby 3.1.7・Rails 7.0.10（変更なし）。a-nti_manner_kick_course 0.5.0 を 3 アプリの development・test に足した

### 作業計画で決めたこと

Step 1 の後に、人間が「gem やアプリのコードが起動の途中で Rails の部品を読み込み、`new_framework_defaults_*.rb` の設定が黙って無視される」のを CI で毎回検出すると決め、a-nti_manner_kick_course を選んだ（参考: TechRacho「Rails: new_framework_defaultsの設定が反映されるタイミングを無邪気に信じてはいけない（翻訳）」、willnet さんのブログとスライド「What's a well-behaved Rails extension gem?」）。着手時に PLAN.md 8 章の手順で調べ、作業計画を出して承認を得た。調べたことは PLAN.md の Step 1-b-1 の節に移した。

| 論点 | 決めたこと | 理由 |
|---|---|---|
| PR の単位 | Step 1-b を 1-b-1（この作業）と 1-b-2（周辺 gem）に分ける | 検出を先に epic に入れておけば、1-b-2 で上げる gem が起動の途中で部品を読み込むようになったときに CI で分かる |
| Gemfile | 先頭（`ruby` の行の直後）に `gem 'a-nti_manner_kick_course', groups: %i[development test]` | README のとおり、ほかの gem より先に読ませる。`group` のブロックにすると、既にある development・test のブロックと重なって `Bundler/DuplicatedGroup` の指摘になる |
| CI | `rails` ジョブの `zeitwerk:check` の後に、test と development の 2 ステップ。`ANTI_MANNER` と `RAILS_ENV` はステップの `env` にだけ付ける | development だけの gem（web-console など）もあるので両方で流す。`ANTI_MANNER` があると gem が起動の途中で終了コード 0 で終えるので、ジョブ全体に付けると minitest などが何も検査せずに成功する |
| 外す時期 | Rails 8.2 以上（今回の目標の外）。epic の間は残す | Rails 8.2 の Load hook guard（rails/rails#56201）は既定が警告だけで、`eager_load` が true のときは見ない |

### 作業計画からの変更点

- Step 1 の後の事前の調べでは「Rails 8.2 の Load hook guard の一覧にも `action_dispatch_request` はない」としていた。着手時に確かめると、rails/rails#56201 のマージの時点では一覧にあり、rails/rails#56901（2026-02-27）で外れていた。今の main の一覧にないことは同じ
- 計画の「壊すと落ちることの確かめ方」の 3（OP の initializer で `ActionController::Base` を参照）が、検出されずに終了コード 0 で通った。gem の initializer `anti_manner` は `before: :eager_load!` しか指定がないので、Railtie の読み込みの順の位置、つまり Rails の各フレームワークの initializer の直後で検査を終える（OP の test では 217 個中 103 番目。アプリの `load_config_initializers` は 150 番目、`eager_load!` は 211 番目）。そのため、ほかの gem の initializer（web-console・devise・doorkeeper など）と `config/initializers/*.rb` は検出できない。Gemfile の末尾に置いても、アプリの `config/initializers` より前に終える点は変わらない
  - 人間に、①gem をこのまま使い、検出できない範囲は手で確かめる、②gem に加えて自前の検査（`after: :load_config_initializers` の initializer で確かめるスクリプト）を CI に足す、③自前の検査だけにする、を示し、①に決まった。Step 1 で起きた型（`config/application.rb` と gem の require）は検出でき、自前のコードを持たずに済むため
  - 検出できない範囲を、PLAN.md（Step 1-b-1 の「検出できる範囲」、12 章）・TIPS.md・defaults/rails-7.0.md の「補足」の申し送り・docs/IMPROVEMENTS.md の IMP-009 に書いた（IMP-009 の変更は作業計画で人間が承認）
- TIPS.md の「設定の値と応答の比較」で、`ActiveSupport.instance_variable_get(:@loaded)` の `@loaded` が抜けていたので直した

### gem ごとの対応

| gem | バージョン | アプリ | 対応 |
|---|---|---|---|
| a-nti_manner_kick_course | なし → 0.5.0 | 3 アプリ（development・test） | lock に増えたのは、この gem と依存 2 行（`activesupport >= 7.0.0`・`railties >= 7.0.0`）と DEPENDENCIES の 1 行だけ。ダウンロードした `.gem` の SHA-256 が rubygems.org の値と同じことを確かめた |

### 壊したときの確認

手元で一時的にコードを変えて `ANTI_MANNER=1 bin/rails runner 1` を流し、確かめた後で戻した（`git diff` が空なことを確かめた）。development は `DATABASE_URL=sqlite3:db/e2e.sqlite3` を付けた。

| アプリ | 一時的な変更 | 結果 |
|---|---|---|
| RS | `config/application.rb` の `Bundler.require` の次の行に `ActiveRecord::Base` | test・development とも終了コード 1。`on_load(:active_record)` と、疑わしい行として `config/application.rb:8` が出た |
| RP | `config/application.rb` の末尾に、Step 1 の `77c26df` で移す前の `ActiveRecord::SessionStore::Session.serializer = :json` | test・development とも終了コード 1、`on_load(:active_record)`。疑わしい行は gem の中（`activerecord-session_store-2.1.0/lib/active_record/session_store/session.rb:7`）を指し、`ANTI_MANNER_DEBUG=1` でスタックトレース全部を出すと `config/application.rb:40` の行があった |
| RS | `config/environments/test.rb`・`development.rb` の末尾に `ActiveRecord::Base`（コードレビューの後に足した確認） | それぞれの環境で終了コード 1、`on_load(:active_record)`。疑わしい行として `config/environments/test.rb:61`・`development.rb:66` が出た |
| OP | `config/initializers/` に `ActionController::Base` だけを書いた一時ファイル | test・development とも終了コード 0（検出できない。上の「作業計画からの変更点」） |
| OP | 同じ置き方で `ActionDispatch::Request` | test・development とも終了コード 0（監視の一覧にない） |

### 確認結果

- `ANTI_MANNER=1 bin/rails runner 1`: 3 アプリとも test（`CI=1` 付きも）・development で `✅Congratulations!`、終了コード 0
- minitest: RS 8 runs・RP 20 runs・OP 25 runs、0 failures。`CI=1`（eager load あり）でも同じ件数で通る。gem を足したアプリのコミットの前に毎回流した
- E2E: 同じく毎回流して 10 passed。スナップショットの差分なし
- RuboCop: 3 アプリとも `no offenses detected`（Gemfile も対象）。bundler-audit: `No vulnerabilities found`。brakeman: `Security Warnings: 0`、`Ignored Warnings: 2`。`zeitwerk:check` は `All is good!`
- `.github/workflows/ci.yml` は YAML として読め、`rails` ジョブのステップの順番と `env` が計画どおりなことを確かめた。CI での結果は下の「CI の結果」
- 手動確認用の環境: 作業の前と後で、9 ファイル（3 アプリの development DB、OP の署名鍵、RP・RS の `.env`、3 アプリの `tmp/development_secret.txt`）のハッシュが、Step 1 の手動確認の後と同じだった

### CI の結果

PR #22 の最初の実行（head は `docs: record the code review of step 1-b-1` のコミット）で、5 ジョブ（`rails` の 3 つ、`e2e`、`public-safety`）と `ci-result` が通った。全体は約 1 分。ログで次のことを確かめた。

- 新しい 2 ステップ（`起動の途中の読み込み（test）`・`（development）`）: 3 アプリとも、両方で `✅Congratulations!` が出た。`ANTI_MANNER` と `RAILS_ENV` がステップの `env` にあるのはこの 2 ステップだけ
- minitest: RS 8 runs・RP 20 runs・OP 25 runs、0 failures（手元と同じ件数）。RuboCop は 3 アプリとも `no offenses detected`、`zeitwerk:check` は `All is good!`、bundler-audit は `No vulnerabilities found`、brakeman は `Security Warnings: 0`・`Ignored Warnings: 2`
- E2E: 10 passed
- 安全チェック: 追跡中の全ファイルと、PR の 8 コミットのメッセージ

PR #22 の最後の実行（head は `docs: link the step 1-b-1 pull request and record its CI run` のコミット。PR の 9 コミット）も、6 ジョブとも通り、minitest・E2E の件数は上と同じだった（Step 1-b-2 の着手時に確かめた）。

### コードレビュー（`/code-review`）

| 指摘 | 対応 |
|---|---|
| TIPS.md に「検出できない範囲は、上の `@loaded` を書き出す方法で手で確かめる」と書いたが、その方法の probe は `config/initializers` を読む直前の時点を見るので、`config/initializers` の中での読み込みは見えない | 手での確認は、値の比較（有効にする前後で値を書き出す）を主にし、`@loaded` の方法では `config/initializers` の中が見えないことを TIPS.md と defaults/rails-7.0.md の申し送りに書いた |
| 検出できる範囲に `config/environments/*.rb` を入れたが、壊して試していない（initializer の順番からの推測） | RS で試した（上の「壊したときの確認」に足した） |
| Gemfile のコメントが検出の範囲を書かず、`config/initializers` も見ているように読める。ci.yml のコメントとも食い違う | 3 アプリのコメントに、`config/application.rb` と gem の require を検出し、ほかの gem の initializer と `config/initializers` は検出できないことを書いた |
| RS・RP の build コミットのメッセージが「before the initializers run」で、範囲が不正確 | push の前なので、人間の承認を得て、`docs: record the step 1-b-1 plan in the upgrade plan` の上に 3 つの build コミットを作り直し（Gemfile のコメントの修正も含めた）、ci と docs のコミットを cherry-pick し直した。作り直す前と後のツリーの差が Gemfile のコメント 3 か所だけなことを `git diff` で確かめた |
| 検出できない範囲の原因は、gem の initializer に `before: :eager_load!` しか指定がないこと。範囲を何か所にも書くより、gem に直す提案をするのが根本の対応 | 手元で試した（下）。人間の判断で、gem に提案（issue か PR）を送ることを docs/IMPROVEMENTS.md の IMP-009 の改善案に足した。送るかどうかは人間が判断し、送るときも人間が送る |
| 検出できる範囲の説明が、PLAN.md・TIPS.md・defaults/rails-7.0.md・IMPROVEMENTS.md・LOG.md・ci.yml の 7 か所にある | 対応しない。範囲の正本は PLAN.md の Step 1-b-1「調べたこと」の「検出できる範囲」で、ほかは要点とそこへの参照だけにしている |

gem の initializer の位置を変えたときの確かめ方: scratchpad のスクリプトで、`config/application` を require した後、gem の initializer `anti_manner` の `@options[:after]` を `:load_config_initializers` にしてから `Rails.application.initialize!` を呼んだ（gem もアプリも変えていない）。

- 検査は、OP の test で 217 個中 148 番目（アプリの `load_config_initializers` の直後）に移った。最初は `@after` を差し替えて位置が変わらず、Rails 7.0 の `Rails::Initializable::Initializer` が `before`・`after` を `@options` に持つと分かってやり直した
- 3 アプリとも、test・development で終了コード 0
- OP の `config/initializers/` に `ActionController::Base` だけを書いた一時ファイルを置くと、終了コード 1（`on_load(:action_controller_base)`、疑わしい行は一時ファイルの 1 行目）。`ActionDispatch::Request` は終了コード 0。一時ファイルは消した

## Step 1-b-2: 3 アプリの応答のスナップショットのテスト（2026-10-09）

- ブランチ / PR: `upgrade/step1b-response-snapshot` / [#23](https://github.com/thinkAmi-sandbox/oidc_op_rp-sample/pull/23)
- バージョン: Ruby 3.1.7・Rails 7.0.10（変更なし）。gem の追加・更新はない

### 作業計画で決めたこと

Step 1 で使い捨ての統合テストで行った応答の前後比較を、毎回の minitest と CI で流れるスナップショットのテストにすると、人間が決めた。着手時に PLAN.md 8 章の手順で調べ、作業計画を出して承認を得た。調べたことと決めたことの一覧は PLAN.md の Step 1-b-2 の節に移した。

| 論点 | 決めたこと | 理由 |
|---|---|---|
| 番号 | この作業を 1-b-2 とし、周辺 gem を 1-b-3 に移す | 1-b-1 と同じく、周辺 gem の更新で起きる変化を捉えるための下準備。Step 1-b-1 の節の「1-b-2（周辺 gem）」は当時の記録なので直さない |
| 対象の応答 | Step 1 の書き出し（OP 20・RP 5・RS 2）に足して、RS 3・RP 11・OP 26 | 足したのは、使っている経路のうち Step 1 で書き出していなかったもの（RS の `active: false`、RP の introspection 用 RP の流れと ID トークンの検証の失敗、OP のログイン成功・ユーザー登録画面・クライアントクレデンシャル・revoke の後の introspect・同意画面を省く認可要求）と、アプリが上書きしている doorkeeper の管理画面のビュー（`/oauth/applications`） |
| 伏せ方 | ヘッダー名・パラメーター名・hidden field の名前・JSON のキーで決める。時刻は `travel_to` で固定して比べる | Step 1 の道具は正規表現で `client_id`・`sub`・時刻まで伏せていた。伏せすぎると変化を見逃す |
| 更新 | `UPDATE_SNAPSHOTS=1`。ファイルがなければ失敗する | E2E のスナップショットの扱い（`--update-snapshots`、黙って作らない）にそろえる |
| development だけの差 | 扱わない | 開発用の道具が足すヘッダーで、業務的な挙動ではない。Rails を上げる Step で `curl` で見る |
| CI | 変えない | 既存の `bin/rails test` と、追跡中の全ファイルの安全チェックの対象に入る |

### 作業計画からの変更点

- OP のテストを 1 つのファイルにすると、26 テストで RuboCop の `Metrics/ClassLength`（136 行。上限 100）になった。`rubocop:disable` は付けず、既存の OP の統合テストと同じく領域ごとに 4 つのファイル（`response_snapshot_discovery_test.rb`・`_devise_`・`_authorization_`・`_token_`）に分けた。RS・RP は計画どおり `response_snapshot_test.rb` の 1 つ
- `travel_to` は、時刻が応答に出る OP のトークン系のテスト（`response_snapshot_token_test.rb`）だけに付けた。ほかの応答には時刻が出ない
- 計画では OP のテストから渡す nonce を固定値にするとしていたが、hidden field とクエリの `nonce` は名前で伏せるので、既存のヘルパーと同じく `SecureRandom` のままにした。RP の introspection 用 RP のコールバックの後の画面に flash で出るアクセストークンは、計画どおりテストの定数（固定のダミーの文字列）にして伏せていない

- コードレビューの後に、計画では変えないとしていた fixtures（`oauth_applications.yml` の `created_at`）と CI（ヘルパーが 3 アプリで同じかの `diff`）を変えた（どちらも人間が判断。下の「コードレビュー」）

### 伏せた値

| 置き換え | 何を伏せたか | 件数（RS / RP / OP） |
|---|---|---|
| `<REQUEST_ID>`・`<RUNTIME>` | `X-Request-Id`・`X-Runtime` の値 | 3 / 11 / 26 ずつ |
| `<CONTENT_LENGTH>`・`<ETAG>` | 本文から決まるヘッダーの値（ヘッダーがあるかどうかは比べる） | 3・1 / 11・4 / 26・16 |
| `<COOKIE>` | `Set-Cookie` の値（名前と属性は比べる） | 0 / 4 / 12 |
| `<STATE>`・`<NONCE>`・`<CODE_CHALLENGE>` | omniauth の認可要求のクエリ、OP の同意画面の hidden field | 0 / 4 ずつ / 0・2・2 |
| `<AUTH_CODE>` | doorkeeper の認可コード（Location・本文のリンク・form_post の hidden field） | 0 / 0 / 5 |
| `<ACCESS_TOKEN:string>`・`<ID_TOKEN:string>` | トークン応答の値 | 0 / 0 / 2・1 |
| `<MODULUS:string>`・`<KID:string>` | JWKS の `n`・`kid`（署名鍵は手元と CI で違う） | 0 / 0 / 1 ずつ |

伏せていないもの: トークン応答の `created_at`・`expires_in`、introspect の `exp`・`iat`（`travel_to` で固定）、`client_id`（fixtures・`.env.test` の固定のダミー）、userinfo の `sub`（fixtures のラベルから決まる ID）、Location の `redirect_uri`・`scope`・`code_challenge_method`、ヘッダーのほかの値。

### 実行ごとに同じになることの確認

- 3 アプリとも、`UPDATE_SNAPSHOTS=1` で作った後、seed を変えて 2〜3 回と `CI=1`（eager load あり）で流して 0 failures。もう一度 `UPDATE_SNAPSHOTS=1` で作り直して、前のファイルと `diff -r` で同じだった
- `/oauth/applications` は doorkeeper が `created_at` の順に並べる。最初は fixtures の作成時刻が 3 つとも同じで、並びが DB に任されていた（手元では毎回 ID の順だった）。コードレビューの後に、fixtures に 1 秒ずつずらした `created_at` を書いて並びを決めた（下の「コードレビュー」）
- トークン・JWT の形の値（`eyJ` と 32 文字以上の英数字）は、ヘッダー名（`x-permitted-cross-domain-policies`）にしか当たらなかった

### 壊したときの確認

手元で一時的に設定やコードを変えてスナップショットのテストを流し、確かめた後で戻した（`git diff` が空なことを確かめた）。

| アプリ | 一時的な変更 | 結果 |
|---|---|---|
| RS | `config/environments/test.rb` で `default_headers` の `X-XSS-Protection` を `1; mode=block` に | 3 件とも失敗（`x-xss-protection` の行の差分） |
| RS | スナップショットを 1 つ消す | 環境変数なしでは「スナップショット … がない」で失敗。`UPDATE_SNAPSHOTS=1` で前と同じ内容に作り直された |
| RP | レイアウトの `stylesheet_link_tag` から `media: 'all'` を外す | `<link>` を出す 4 件が失敗 |
| RP | 独自ストラテジーの `scope` を `openid profile` に | 認可要求の 1 件が失敗（Location を伏せすぎていない） |
| OP | `button_to_generates_button_tag = false` | `/users/edit` の 1 件が失敗（`<button>` → `<input>`） |
| OP | `apply_stylesheet_media_default = true` | doorkeeper のレイアウトを使う 4 件（同意画面・エラー画面・form_post・管理画面）が失敗 |
| OP | `access_token_expires_in` を 11 分に | トークン応答 2 件と introspect の 1 件が失敗（`expires_in`・`exp` を伏せていない） |
| OP | `cookies_same_site_protection = :strict` | `Set-Cookie` のある 12 件が失敗（Cookie の属性を伏せていない） |

### 確認結果

- minitest: RS 8 → 11 runs・RP 20 → 31 runs・OP 25 → 51 runs、0 failures。`CI=1` でも同じ件数で通る。アプリごとのコミットの前に流した
- E2E: アプリごとのコミットの前に流して 10 passed。スナップショットの差分なし
- RuboCop: 3 アプリとも `no offenses detected`。bundler-audit: `No vulnerabilities found`。brakeman: `Security Warnings: 0`、`Ignored Warnings: 2`。`zeitwerk:check` は `All is good!`。`ANTI_MANNER=1 bin/rails runner 1` は test・development で `✅Congratulations!`。`bin/rails runner` は 3 アプリとも 7.0.10
- 安全チェック: スナップショットのファイル・ヘルパー・テストを `--files` で、コミットのたびに hooks で検査して通った。`.public-safety-allow` への追記はない
- 3 つのヘルパー（`test/support/response_snapshot_helper.rb`）が同じ内容なことを `diff` で確かめた
- 手動確認用の環境: 作業の前と後で、9 ファイル（3 アプリの development DB、OP の署名鍵、RP・RS の `.env`、3 アプリの `tmp/development_secret.txt`）のハッシュが同じだった

### コードレビュー（`/code-review`）

| 指摘 | 対応 |
|---|---|
| ヘッダーの値を `to_s` で文字列にしていて、Rack 3（Step 3 の Rails 7.1 以降で入りうる）が `Set-Cookie` を配列で持つと、配列の inspect の形で書かれ、2 つ目の Cookie の値が伏せられない | 配列の値も 1 つずつ別の行にした（3 アプリのヘルパー） |
| hidden field を `<input type="hidden" name="...` の並びでしか見ておらず、属性の並びが変わると認可コードなどが伏せられない。そのまま `UPDATE_SNAPSHOTS=1` で作り直すと、安全チェックの `oauth-param` ルールでは拾えない形でファイルに残る | `<input>` のタグごとに `name` と `value` を見るようにした。並びを変えたタグでも伏せることを `bin/rails runner` で確かめた |
| JSON の本文を `JSON.pretty_generate` で書いていて、空の `{}` の整形が json の版で変わる（json 2.6.1 は 2 行）。Ruby を上げる Step で、応答が同じでもスナップショットが変わる | 空の `{}`・`[]` を 1 行にそろえた。OP の `revoke.txt` だけが `{}` に変わった |
| `application/json` で本文が空だと `JSON::ParserError` で止まり、`+json` の media type では JSON のキーを伏せない | 本文が空なら JSON として読まず、`+json` も JSON として扱うようにした |
| JWKS の `n`・`kid` を、JWKS 以外の JSON でも伏せていた（伏せすぎ） | `keys` の配列の中だけで伏せるようにした |
| 認証のない introspect のテストが、エラーの応答に出ないトークンのために認可コードフローを一通り流していた | 適当な文字列（`SecureRandom.hex`）を渡すようにした。スナップショットは変わらない |
| TIPS.md の作り直しの手順が `git diff -- test/snapshots` だけで、新しいファイル（未追跡）が見えない | `git status --short` も見るように直した |
| `/oauth/applications` は `created_at` の順に並べるが、fixtures の 3 つのアプリの `created_at` が同じで、並びが DB に任されていた（sqlite3 2.x などで変わりうる） | 人間に、①fixtures に固定の `created_at` を書く、②変えずに申し送る、を示し、①に決まった。seeds と同じ順に 1 秒ずつずらした時刻を書いた。fixtures の `created_at` を使うほかのテストはない。my_op の時刻を一時的に後ろにずらすと、このスナップショットが落ちることを確かめた |
| 同じ内容のヘルパーを 3 アプリにコピーしていて、手での `diff` でしか同じことを確かめていない | 人間に、CI に `diff` のステップを足す・何もしない・リポジトリ直下のファイルを `require_relative` で読む、を示し、CI に足すことに決まった。`rails` ジョブの RuboCop の後に、自分のヘルパーをほかのアプリのものと `diff -u` で比べるステップを足した。ワークフローのそのステップのスクリプトを手元で各アプリのディレクトリで流し、3 つが同じなら通り、1 つを変えると 3 アプリとも落ち、1 つを消すとそのアプリが落ちることを確かめた |

コードレビューの後も、3 アプリの minitest を seed を変えて 2 回と `CI=1` で流して 0 failures（件数は上と同じ）、主な壊したときの確認（OP の `SameSite`・`<link>` の `media`）で前と同じ件数が落ちること、RuboCop・E2E（10 passed）・安全チェックが通ることを確かめた。

## Step 1-b-3-1: Rails 7.0 を必要とする周辺 gem（RP の gem・jbuilder・devise）（2026-10-09）

- ブランチ / PR: `upgrade/step1b-rails70-gems` / [#24](https://github.com/thinkAmi-sandbox/oidc_op_rp-sample/pull/24)
- バージョン: Ruby 3.1.7・Rails 7.0.10（変更なし）。jbuilder 2.13.0 → 2.15.1（RP・OP）、activerecord-session_store 2.1.0 → 2.2.0・omniauth-rails_csrf_protection 1.0.0 → 1.0.2（RP）、devise 4.9.4 → 5.0.4（OP）
- 追随した gem の既定値・雛形は、[defaults/rails-7.0.md](defaults/rails-7.0.md) の「周辺 gem（Step 1-b-3）」に記録した（DEF-7.0-38〜42）

### スキル化の計画の見直し

着手の前に、Step 1 の後に人間と振り返った結果を、PLAN.md の 13 章（スキル化の計画）に反映した（人間が承認）。振り分けの基準（スキル・リポジトリのスクリプト・PLAN.md などの文書）を決め、当初の rails-minor を 4 つの作業に分け、既定値への追随の解説と記録を独立した作業にした。スキルを作るのは、1-b-3 と Step 2 を手作業で通した後にした。あわせて、10 章の完了条件に、これまで Step ごとに行っていた確認（`CI=1` の minitest、起動の途中の読み込みの検査、無視リストを空にした bundler-audit、lock の default gem の版、手動確認用の環境のハッシュ）を足し、5 章のロードマップにスキル化の行を足した。

### 作業計画で決めたこと

着手時に PLAN.md 8 章の手順で調べ（サブエージェント 3 つ: doorkeeper 系、devise、RP の gem と jbuilder）、作業計画を出して承認を得た。調べたことと決めたことの一覧は PLAN.md の Step 1-b-3 の節に移した。

| 論点 | 決めたこと | 理由 |
|---|---|---|
| 上げる先 | Ruby 3.1.7・Rails 7.0.10 で使える最新（doorkeeper は 5.9.9、doorkeeper-openid_connect は 1.10.1） | 0-f と同じ方針。doorkeeper は GHSA-h5m9-42h9-vcq6（revoke の認可の不備。`< 5.9.1`）を直すため 5.9.x まで上げる。この advisory は ruby-advisory-db になく、bundler-audit は検出しない（GitHub の doorkeeper のリポジトリの advisory で確かめた） |
| PR の分け方 | 1-b-3-1（RP の gem・jbuilder・devise）と 1-b-3-2（doorkeeper 系）の 2 つ | doorkeeper は 4 段あり、OP・RP・RS の間のやり取りの変化（B）の確認がまとまって出る。ほかの gem と混ぜると、スナップショットの差分が読みにくくなる |
| 一時固定 | omniauth-rails_csrf_protection 1.0.2（固定しないと 2.0.1）。1-b-3-2 では doorkeeper-openid_connect 1.8.11 と ostruct 0.5.2 | 2.x は Rails 8.1 向けの変更（Step 7）。ostruct は Ruby 3.1.7 の default gem と同じ版にする |
| activerecord-session_store 2.2.0 で DB に入る JSON の文字列が変わる | A として扱う（DEF-7.0-38） | 読み戻す値は同じで、escape の形だけが変わる |
| gem の generator の雛形 | initializer・ロケール・上書きしているビューにも追随する。doorkeeper のロケールとビューは 1-b-3-2 で合わせる（IMP-008） | 作業計画への返事で人間が決めた。今の挙動を残す理由がなく、雛形に合わせておけば gem の今後の版に追随しやすい。PLAN.md の 3 章の 2 の境目の 1 と CLAUDE.md に書いた |
| 手動確認 | 1-b-3-1 は devise を上げた後に 1 回、1-b-3-2 は doorkeeper 5.9.9 の後に 1 回 | 13 章の「いつ行うかは Step ごとに人間と決める」 |
| 道具 | `scripts/check-apps` を、gem を上げる前のコミットで入れる | 13 章の 4（人間が承認）。1-b-3 と Step 2 で使いながら直す |

### 作業計画からの変更点

- `scripts/check-apps` の無視リストを空にした bundler-audit は、計画では件数を情報として出すだけにしていた。出力の `Name:` の行は 1 つの advisory でも複数出て件数にならず、10 章の目的（解消した advisory を無視リストから消す）にも合わないので、「無視リストにあるのに報告されない ID」があれば失敗にする検査に変えた。devise を上げたときに、無視リストの devise の 2 件をこの検査で見つけた
- 手動確認の前に、RP・OP とも前回の手動確認からログインしたままで、RP の「Re Login」では OP のログイン画面が出ないと分かった。人間の判断で、OP のタブで JavaScript からログアウトのフォーム（`DELETE /users/sign_out`。CSRF のトークン付き）を送った
- 手動確認で、OP の画面に flash が出ないこと（元からの挙動）が分かり、人間の承認を得て docs/IMPROVEMENTS.md に IMP-010 を足した

### gem ごとの対応

| gem | バージョン | アプリ | 対応 |
|---|---|---|---|
| jbuilder | 2.13.0 → 2.15.1 | RP・OP | 動いたのは jbuilder だけ。`.jbuilder` のテンプレートはない。OP では doorkeeper の `ActionController::API` のコントローラーで新しい hook が走るが、応答のスナップショットは同じ |
| activerecord-session_store | 2.1.0 → 2.2.0 | RP | multi_json 1.15.0 が lock から外れた。セッションの JSON で `<>&` を escape しなくなった（DEF-7.0-38）。先に足したテストの期待値を直した |
| omniauth-rails_csrf_protection | 1.0.0 → 1.0.2 | RP | Gemfile に `'1.0.2'` を足して `bundle update` → 行を消して `bundle lock --local`。Gemfile は元のまま、lock はこの gem の 1 行だけが変わった |
| devise | 4.9.4 → 5.0.4 | OP | 動いたのは devise だけ。ビューの HTML（DEF-7.0-39・40）とログイン失敗の文言（DEF-7.0-41）が変わった。無視リストから CVE-2026-32700・CVE-2026-40295 を消した |
| （devise の initializer） | 4.8 の雛形 → 5.0.4 の雛形 | OP | 失敗の応答が 422、リダイレクトが 303 になった（DEF-7.0-42）。コメントアウトされた `secret_key`・`pepper` の例の値は、install のときに作られた乱数なので残した |

- ダウンロードした `.gem`（jbuilder・activerecord-session_store・omniauth-rails_csrf_protection・devise）の SHA-256 が、rubygems.org の値と同じことを確かめた
- lock に入れた default gem（json 2.6.1・bigdecimal 3.1.1・logger 1.5.0・base64 0.1.1、RP の cgi 0.3.7）と、Step 1 の一時固定（benchmark・securerandom・drb・mutex_m・ruby2_keywords）は動いていない
- gem の initializer は a-nti_manner_kick_course の検査の範囲の外なので、gem ごとに、`config/initializers` を読む直前に読み込み済みの部品（TIPS.md の「設定の値と応答の比較」）を、test と development で前後に書き出して比べた。どれも前後で同じだった。devise は、Devise の設定（responder・`navigational_formats`・`sign_in_after_change_password` など）と Rails の設定の値も前後で同じだった

### テストの追加

gem を上げる前に、テストで守られていない挙動を記録した。

| アプリ | テスト | 上げた後 |
|---|---|---|
| RP | セッションの JSON の `omniauth.origin` で、`<>&` が escape されている | activerecord-session_store 2.2.0 で落ち、DEF-7.0-38 の解説の根拠にした。期待値を直した |
| RP | CSRF のトークンのないログインの POST は、OP へリダイレクトせず `/auth/failure` へ（テストの中だけ `allow_forgery_protection` を有効にした） | omniauth-rails_csrf_protection 1.0.2 でも同じ |
| OP | ユーザー登録・ユーザー編集の、失敗と成功の応答のスナップショット 4 つ | devise 5.0.4 で失敗の 2 つの HTML が、initializer で 4 つのステータスが変わった |
| OP | 登録に成功するとユーザーが 1 人増える、パスワードを変えた後もログインしたまま | 同じ |

### 手動確認

devise を上げ、initializer を雛形に合わせた後に、`.claude/launch.json` から 3 アプリを起動してブラウザペインで確かめた（パスワードの入力は人間が操作）。

- OP のタブでログアウトのフォームを送ると、303 See Other で `/` に戻った
- RP の「Re Login」で OP のログイン画面が出た。誤ったパスワードで 2 回ログインし、どちらもログイン画面に戻った（メッセージは出ない。下）。サーバーのログには、warden の 401 と、描き直したログイン画面の 200 が出る（FailureApp がログを書いた後でステータスを 422 に置き換える。`devise-5.0.4/lib/devise/failure_app.rb` の `recall`）。ブラウザとは別のセッションの `curl` で、ダミーの誤ったパスワードでのログインが 422 で返ることを確かめた
- 正しいパスワードでログインすると、303 See Other で認可エンドポイントに戻り、同意画面を省いて（my_op のアプリにこのユーザーのトークンがあるため。Step 0-f-3 の条件）RP に戻り、「ログインしました」「Logged in as …」が出た
- OP のレイアウト（`app/views/layouts/application.html.erb`）は flash を描かないので、ログイン失敗のメッセージは出ない。タグ `rails-6.1` から変わっていない元からの挙動で、IMP-010 に記録した
- 手動確認用の環境: 作業の開始時に控えた 9 ファイルのハッシュが、手動確認の直前まで変わっていないことと、件数が Step 1 の手動確認の後と同じことを確かめた（Step 1-b-2 の後のハッシュの値は記録がないので比べていない）。手動確認で、OP の development DB は `oauth_access_grants` が 12 → 13 件、`oauth_access_tokens` が 31 → 32 件、RP の development DB は `sessions` が 10 件のまま（既にある行を更新）で、どちらもハッシュが変わった。RS の DB・署名鍵・`.env`・3 アプリの `tmp/development_secret.txt` は変わっていない。以降の基準は手動確認の後のハッシュ

### 遭遇した問題

1. `scripts/check-apps` の最初の版は、ログのファイルの番号を `$(...)` の中で増やしていたので、番号が親のシェルで進まず、すべての検査のログが同じファイルに上書きされていた。全部を流した結果の一覧で気づき、番号を親のシェルで増やすように直した（コミットの前）
2. コミットメッセージに `\u003c` と書いたつもりが、`<` になっていた。Claude Code のツールに渡す段階で `\u` の並びが Unicode の文字に変換されていた（Python でファイルに書いたときは崩れなかった）。push の前に、人間の承認を得て、RP のテストを足したコミットのメッセージを直し、その上の 11 コミットを cherry-pick で作り直した。作り直す前と後のツリーが同じことと、ほかのコミットのメッセージが同じことを確かめた。以降、`\u` を含むメッセージは Python でファイルに書いて `git commit -F` に渡した
3. OP のディレクトリで `git diff --name-only` の結果を `git add` に渡すと、`git diff` はリポジトリ直下からのパスを出すので、パスが見つからずに失敗した（コミットはされなかった）。パスを直接指定して `git add` した

### 確認結果

- `scripts/check-apps`（3 アプリと E2E）: 36 の検査がすべて通った。各コミットの前にも、対象のアプリと E2E で流した
- minitest: RS 11 runs・RP 31 → 33 runs・OP 51 → 57 runs、0 failures。`CI=1`（eager load あり）でも同じ件数で通る
- E2E: 10 passed。スナップショットの差分なし
- RuboCop: 3 アプリとも `no offenses detected`。`zeitwerk:check` は `All is good!`。`ANTI_MANNER=1 bin/rails runner 1` は test（`CI=1` 付きも）・development で `✅Congratulations!`。bundler-audit: `No vulnerabilities found`。無視リストを空にした bundler-audit で、無視リストの ID はすべて今も報告される（devise の 2 件は消した）。brakeman: `Security Warnings: 0`、`Ignored Warnings: 2`。`bin/rails runner` は 3 アプリとも 7.0.10
- 応答のスナップショットの変化は、DEF-7.0-39・40（devise のビュー）と DEF-7.0-42（devise の responder）だけ。どれも解説して返事をもらってから作り直した
- 手動確認用の環境: 作業の最後に、9 ファイルのハッシュが手動確認の後と同じだった

### コードレビュー（`/code-review`）

| 指摘 | 対応 |
|---|---|
| `scripts/check-apps` の無視リストの検査が、bundle-audit 自体の失敗を見ておらず、advisory のデータベースがないときなどに、無視リストの全 ID を「解消済み」と出す | 出力に結果の行（`Vulnerabilities found!`・`No vulnerabilities found`）がなければ、bundle-audit の失敗として扱うようにした。存在しない場所の advisory のデータベースを指す一時的なコピーで流し、「結果を読めなかった」で失敗することを確かめた（このとき bundle-audit がその場所へデータベースを取りに行こうとしたが、書き込めずに始まる前に失敗した。ダウンロードされたものはない） |
| 上の「手動確認」に「ハッシュが Step 1-b-2 の後と同じ」と書いたが、比べたのは作業の開始時に控えた値だけ | 確かめた範囲に書き直した |
| `--no-e2e` と `--e2e-only` を一緒に渡すと、何も流さず、bash 3.2 で unbound variable のエラーになる | 引数の誤り（終了コード 2）にした |
| `devise.rb` の `:unprocessable_entity` は、Rack 3.1 以上で非推奨になる（そのときの雛形は `:unprocessable_content`） | 申し送った。Rack を 3.1 以上にする Step で、雛形に合わせ直す（PLAN.md 7 章の devise の行、DEF-7.0-42） |
| defaults/rails-7.0.md の冒頭が、周辺 gem の記録の場所として 1-b-3-1 のブランチだけを指している | 1-b-3-1・1-b-3-2 のブランチを書き分けた |
| `scripts/check-apps` と CI に、同じ検査のコマンドが 2 か所ある | 申し送った。CI から `check-apps` を呼ぶかどうかは、スキルを作る PR で決める（PLAN.md 13 章の 4） |
| RP の CSRF のテストが、プロセス全体の設定 `allow_forgery_protection` を書き換えている | 今は並列化していないので、テストをスレッドで並列化するときに見直すと、テストのコメントに書いた |

コードレビューの後も、`scripts/check-apps`（3 アプリと E2E）の 36 の検査がすべて通ることを確かめた。

## Step 1-b-3-2: Rails 7.0 を必要とする周辺 gem（doorkeeper 系）（2026-10-09〜2026-10-10）

- ブランチ / PR: `upgrade/step1b-doorkeeper` / [#25](https://github.com/thinkAmi-sandbox/oidc_op_rp-sample/pull/25)
- バージョン: Ruby 3.1.7・Rails 7.0.10（変更なし）。OP の doorkeeper-openid_connect 1.8.9 → 1.8.11 → 1.10.1、doorkeeper 5.7.1 → 5.8.2 → 5.9.9。ostruct 0.5.2（一時固定）が lock に入った
- 追随した gem の雛形は、[defaults/rails-7.0.md](defaults/rails-7.0.md) の「周辺 gem（Step 1-b-3）」に記録した（DEF-7.0-43〜47）

### 作業計画で決めたこと

着手時に PLAN.md 8 章の手順で確かめ直し（サブエージェント 3 つ: doorkeeper 5.7.1 → 5.9.9、doorkeeper-openid_connect 1.8.9 → 1.10.1、アプリの使い方とテストの範囲）、作業計画を出して承認を得た。確かめたことと決めたことの一覧は PLAN.md の Step 1-b-3 の節（「1-b-3-2 の着手時に確かめ直したこと」以下）に移した。

| 論点 | 決めたこと | 理由 |
|---|---|---|
| 版と順番 | 1-b-3-1 の作業計画のまま（doorkeeper-openid_connect 1.8.11 → doorkeeper 5.8.2 → doorkeeper-openid_connect 1.10.1 → doorkeeper 5.9.9）。どの段も 1 gem だけを動かす | 新しい版は Ruby 3.2 以上かプレリリースだけ。lock のコピーで、どの段も 1 gem だけが動くことを確かめた |
| advisory | GHSA-8r7r-wh7x-27ff（doorkeeper-openid_connect `<= 1.10.3`。DCR の scope）は、DCR を有効にしていないので影響しない。修正版の 1.10.4 は Ruby 3.2 以上なので Step 2 の後 | DCR は既定で無効で、ルートも有効にしたときだけ足される |
| 先に足すテスト | クライアント認証（Basic だけ、Basic と本文の両方、Basic と別の `client_id`）、userinfo のトークンの渡し方（`access_token` 引数だけ、Bearer ヘッダーと引数の両方、scope の足りないトークン）、`prompt`・`max_age`、Webfinger、form_post での拒否 | 段ごとの変化をスナップショットの差分で見るため。Webfinger と form_post での拒否は、今は例外になるので `assert_raises` で記録した |
| B の扱い | 段ごとに止まり、スナップショットの差分を根拠に 1 つずつ人間に確かめる | CLAUDE.md の「アップグレードのルール」 |
| 雛形への追随 | gem をすべて上げた後に、initializer（doorkeeper・doorkeeper-openid_connect）→ ロケールとビュー（1 コミット）の順に行う。独自の設定と nonce の hidden field は残す | 5.9.1 で `:` がビューからロケールに移ったので、ロケールとビューを別のコミットにすると、どちらかのコミットで表示が崩れる |
| 手動確認 | 雛形に合わせた後に 1 回（introspection の流れまで） | 1-b-3-1 の作業計画のまま |

### 作業計画からの変更点

- 応答のスナップショットのヘルパー（`test/support/response_snapshot_helper.rb`）を、3 アプリで直した（人間が承認）。doorkeeper-openid_connect は OIDC のエラーをリダイレクトで返すとき、エラー応答のヘッダー（`Content-Type: application/json`・`WWW-Authenticate`・`Cache-Control: no-store`）を足したまま `redirect_to` するので、302 の本文は Rails のリダイレクトの HTML なのに `application/json` を名乗る。ヘルパーは `Content-Type` で JSON かどうかを決めて `JSON.parse` していたので、1.10.1 で `prompt=select_account` などがこの経路を通るようになると、比べる前に落ちた。JSON として読めない本文はテキストとして扱うようにした（下の「OIDC のエラーのリダイレクトのヘッダー」。コードレビューの後に、リダイレクトの応答だけに絞った）。1.10.1 の lock の変更を退避し、1.8.11・5.8.2 の状態で 3 アプリの検査と E2E を流してからコミットした
- 先に足した例外のテスト 2 本は、変化を起こしたコミットで置き換えた。Webfinger は 1.10.1 のコミットでスナップショット `webfinger` に、form_post での拒否はロケールとビューのコミットで、フォームを返すテストとスナップショット `authorize_form_post_deny` に
- 既存のテスト「登録されていない redirect_uri では、エラーの説明を 400 で表示する」を、前後の空白を除いて比べるように直した。雛形のエラー画面は `<pre>` の中で説明の前後を改行・字下げするので、`assert_select` の `text:` では一致しない（DEF-7.0-45）
- 残した nonce の hidden field にも、雛形にならって `id: nil` を付けた（DEF-7.0-45）
- doorkeeper のロケールで画面と introspect のエラーの文言が変わることは、計画では A としていた。画面の文字は B の例に挙がっているので、あらためて確かめ、A として追随すると人間が決めた（DEF-7.0-46）
- 手動確認の後に、IMP-011（`max_age` の判定に `auth_time_from_session` を使う）を docs/IMPROVEMENTS.md に足した（人間が承認）

### gem ごとの対応

| gem | バージョン | 対応 |
|---|---|---|
| doorkeeper-openid_connect | 1.8.9 → 1.8.11 | 一時固定（固定しないと 1.10.1 になり、doorkeeper 5.7 で discovery が壊れる）。依存の ostruct も 0.5.2（Ruby 3.1.7 の default gem）に一時固定した。ostruct はダウンロードされず、default gem が使われる |
| doorkeeper | 5.7.1 → 5.8.2 | 固定不要（1.8.11 が `< 5.9`） |
| doorkeeper-openid_connect | 1.8.11 → 1.10.1 | 固定不要（Ruby 3.1 で使える最新） |
| doorkeeper | 5.8.2 → 5.9.9 | 固定不要（1.10.1 が `< 6.0`、6.0 はプレリリースだけ）。GHSA-h5m9-42h9-vcq6（revoke の認可の不備。5.9.1 で修正）を解消した。ruby-advisory-db にない advisory なので、無視リストの変更はない |

- 一時固定は過去の Step と同じく、Gemfile に版を足して `bundle install` → 外して `bundle lock --local` → Gemfile が戻り、lock に固定した版が残ることを確かめた
- ダウンロードした `.gem`（doorkeeper-openid_connect 1.8.11・1.10.1、doorkeeper 5.8.2・5.9.9）の SHA-256 が、rubygems.org の値と同じことを確かめた
- epic と比べて OP の lock で変わったのは、doorkeeper・doorkeeper-openid_connect の版と依存の行、ostruct 0.5.2 の行だけ。lock に入れた default gem（json 2.6.1・bigdecimal 3.1.1・logger 1.5.0・base64 0.1.1）、Step 1 の一時固定（benchmark・securerandom・drb・mutex_m・ruby2_keywords）、jwt 2.10.3 は動いていない。Gemfile は変えていない

### 意図的な仕様変更

どれも gem の更新か雛形への追随に伴うもので、設定では元に戻せない。RP・RS は使わない経路か、値の変わらないもの。段ごとに人間に確かめた。

| 変化 | 前 | 後 | 版 | 確かめ方 |
|---|---|---|---|---|
| 認可要求の `max_age=0` | 同意画面（200） | ログアウトさせてログイン画面へ（302） | doorkeeper-openid_connect 1.8.11（#222） | スナップショット `authorize_max_age_zero` |
| トークン要求の成功の応答の `Pragma: no-cache` | なし | あり | doorkeeper 5.8.0（#1712） | スナップショット `token_*` の 5 件 |
| 認証のない introspect の `error_description` | `invalid_request.unknown` の文言 | `invalid_request.request_not_authorized` の文言（ロケールを合わせた後は、その 5.9.9 の文言） | doorkeeper 5.8.0（#1715） | スナップショット `introspect_error` |
| userinfo の JSON のキーの順 | `sub, email` | `email, sub` | doorkeeper-openid_connect 1.10.0（#273） | スナップショット `userinfo` ほか 2 件 |
| Webfinger | `NoMethodError`（`root_url`。OP に `root` のルートがない） | 200（`href` は issuer） | doorkeeper-openid_connect 1.10.0（#250） | スナップショット `webfinger` |
| 認可要求の `prompt=select_account` | 同意画面 | `account_selection_required` のエラーのリダイレクト | doorkeeper-openid_connect 1.10.0（#279） | スナップショット `authorize_prompt_select_account` |
| 認可要求の `prompt=none` と `max_age` | ログアウトさせてログイン画面へ | `login_required` のエラーのリダイレクト | doorkeeper-openid_connect 1.10.0（#275） | スナップショット `authorize_prompt_none_max_age` |
| 有効なトークンの introspect のキーの順 | `exp, iat` | `iat, exp` | doorkeeper 5.9.1（#1818） | スナップショット `introspect_active` |
| クライアント認証を 2 重に使うトークン要求（Basic と本文の両方に secret、Basic と別の `client_id`） | 200（Basic を使う） | 400 `invalid_request` | doorkeeper 5.9.5・5.9.6 | スナップショット `token_basic_and_body_auth`・`token_basic_and_other_client_id` |
| トークンを Bearer ヘッダーと `access_token` 引数の両方で渡す userinfo | 200 | 401 `invalid_token` | doorkeeper 5.9.7（6.0 で 400 `invalid_request` になる予定。CHANGELOG） | スナップショット `userinfo_bearer_and_param` |
| scope の足りないトークンの 403 | `WWW-Authenticate` なし | `insufficient_scope` の `WWW-Authenticate` あり | doorkeeper 5.9.1（#1795） | スナップショット `userinfo_insufficient_scope` |
| `response_mode=form_post` で拒否 | 上書きしていたビューが `NoMethodError` | `error=access_denied` を POST するフォーム（200） | ビューを 5.9.9 の雛形に合わせた（DEF-7.0-45） | テストとスナップショット `authorize_form_post_deny` |

#### `Pragma` の扱いの経緯

- doorkeeper 5.6.6（#1644）で、トークン応答とエラー応答から `Pragma: no-cache` が消えた。Step 0-f-3 では、0-f-1 で `Cache-Control` を記録だけにしたのにならい、消えたことを記録だけにした（上の Step 0-f-3「応答ヘッダーの前後比較」）
- その後、Step 1 で「挙動を変えない」の定義（PLAN.md の 3 章の 2）を決め、OP・RP・RS の間のやり取り（応答ヘッダーを含む）の変化は B として扱うことにした
- doorkeeper 5.8.0（#1712）で、トークン要求の成功の応答にだけ `Pragma: no-cache` が戻った（エラーの応答には戻っていない）。1-b-3-2 では、この定義に従って「意図的な仕様変更」として扱った（人間が承認）。RFC 6749 の 5.1 は、トークン応答に `Cache-Control: no-store` と `Pragma: no-cache` を付けることを求めている

### テストの追加

gem を上げる前に、OP に 11 本を足した（57 → 68 runs）。後で、例外を記録した 2 本を置き換え、form_post での拒否のスナップショットを 1 本足した（69 runs）。

| テスト | 足したときの挙動 | 変わった段 |
|---|---|---|
| スナップショット `token_basic_auth` | 200 | doorkeeper 5.8.2（`Pragma`） |
| スナップショット `token_basic_and_body_auth`・`token_basic_and_other_client_id` | 200（Basic を使う） | 5.8.2（`Pragma`）、5.9.9（400） |
| スナップショット `userinfo_access_token_param` | 200 | doorkeeper-openid_connect 1.10.1（キーの順） |
| スナップショット `userinfo_bearer_and_param` | 200 | 1.10.1（キーの順）、doorkeeper 5.9.9（401） |
| スナップショット `userinfo_insufficient_scope` | 403（本文なし） | 5.9.9（`WWW-Authenticate`） |
| スナップショット `authorize_prompt_select_account`・`authorize_prompt_none_max_age`・`authorize_max_age_zero` | 同意画面・ログイン画面へのリダイレクト・同意画面 | 1.8.11（`max_age=0`）、1.10.1（`prompt`） |
| Webfinger は落ちる（`discovery_test.rb`） | `NoMethodError` | 1.10.1 でスナップショット `webfinger` に置き換えた |
| form_post で拒否すると落ちる（`authorization_endpoint_test.rb`） | `ActionView::Template::Error` | ロケールとビューのコミットで、フォームを返すテストに置き換え、スナップショット `authorize_form_post_deny` を足した |

- 新しいファイルは `response_snapshot_token_auth_test.rb`（クライアント認証とトークンの渡し方）と `response_snapshot_authorization_prompt_test.rb`（`prompt`・`max_age`）
- 壊したときの確認: スナップショットの 1 件を書き換えると、そのテストだけが落ちる。`test/support/` に一時的に `root_url` を定義するパッチを置くと、Webfinger のテストが落ちる（確かめた後で消した）

### OIDC のエラーのリダイレクトのヘッダー

上の「作業計画からの変更点」のヘルパーの修正の前に、人間の求めで調べた。

- doorkeeper-openid_connect の `handle_oidc_error!` は、確かめたタグ（v1.2.0・v1.4.0・v1.5.0・v1.6.0・v1.7.0・v1.7.5）では `render json: error_response.body, status: :found, location: ...` で JSON の本文を返していたので、`Content-Type: application/json` と本文が合っていた。1.8.0 のコミット `d07ba31`（PR #138。doorkeeper 5.5 の form_post に対応するため、doorkeeper の `redirect_or_render` を使うようにした）で HTML のリダイレクトになったが、その前の `response.headers.merge!(error_response.headers)` が残った
- 1.10.5・2.0.0・master（2026-08-23 の a9ff52b まで）でも同じで、doorkeeper の `ErrorResponse#headers` も 5.9.9・6.0.0.rc2 で同じ。両方のリポジトリに、この件の issue・PR は見つからなかった
- OpenID Connect Core 1.0 の 3.1.2.6（Authentication Error Response）と RFC 6749 の 4.1.2.1 は、リダイレクトで `error`・`state` をクエリに付けることを決めているだけで、ヘッダーは決めていない。`WWW-Authenticate` は RFC 6750 の 3 章で保護されたリソースへのリクエストを拒むときのもので、`Content-Type` は RFC 9110 の 8.3 で本文のメディアタイプを示す。エラーの返し方と値は仕様どおりで、足されるヘッダーは仕様にないもの（`Content-Type` は本文と合わない）
- doorkeeper 本体の拒否のリダイレクト（スナップショット `authorize_deny`）は `text/html` で、`WWW-Authenticate` はない
- ブラウザと omniauth は 302 の `Location` だけを使うので、RP への実害はない

### 起動の途中の読み込み

- 各段で、a-nti_manner の検査（test・`CI=1`・development）が通った
- 範囲の外は、各段の前後に test と development で、`config/initializers` を読む直前と `initialize!` の後に読み込み済みの部品（`ActiveSupport` の `@loaded`）、doorkeeper のモデルが読み込まれているか、`filter_parameters` と `ActiveRecord::Base.filter_attributes` を書き出して比べた。変わったのは、doorkeeper 5.9.9 で `Doorkeeper::AccessToken` が起動の時点で読み込まれなくなったことだけ（5.9.2 の #1830 でモデルを遅延して読み込むようになった。`Doorkeeper::AccessGrant` は doorkeeper-openid_connect の `on_load(:active_record)` で読み込まれる）。読み込み済みの部品と `filter_parameters` は前後で同じ（development の `action_dispatch_request` は既知の web-console の分。IMP-009）

### 手動確認

ロケールとビューを雛形に合わせた後に、`.claude/launch.json` から 3 アプリを起動してブラウザペインで確かめた（パスワードの入力と同意は人間が操作）。

- ログイン（RP の my_op）: OP のログイン画面でログインした後、同意画面を省いて RP に戻り、「ログインしました」が出た。OP のログは、ログインが 303、認可エンドポイントが 302、トークン・userinfo・JWKS が 200
- introspection 用 RP: 前回のトークンは revoke 済みなので、雛形に合わせた同意画面が出て、Authorize の後、RS は正しいトークンで 200、`_bad` を付けたトークンで 401、revoke は 200、revoke の後は 401。RS が受け取った introspect は `active: true`（キーの順は `iat, exp`、`exp - iat = 600`）→ `active: false` が 2 回
- サーバーの出力: 3 アプリとも、エラー・warning・DEPRECATION の新しいものはない。RP の `/stylesheets/application.css` のルーティングのエラーは元からのもの（Sprockets を読み込んでいない）
- 手動確認用の環境: 作業の開始時に 9 ファイルのハッシュを控え、件数が Step 1-b-3-1 の手動確認の後と同じこと（OP `oauth_access_grants` 13・`oauth_access_tokens` 32、RP `sessions` 10・`op_users` 1）を確かめた。手動確認の直前にハッシュが同じことを確かめた。手動確認で、OP の development DB は `oauth_access_grants` が 13 → 15 件、`oauth_access_tokens` が 32 → 37 件（my_op 1・introspection 用 1（revoke 済み）・RS のクライアントクレデンシャル 3）、RP の development DB は `sessions` が 10 → 12 件になり、どちらもハッシュが変わった。RS の DB・署名鍵・`.env`・3 アプリの `tmp/development_secret.txt` は変わっていない。以降の基準は手動確認の後のハッシュ

### 遭遇した問題

1. lock のコピーで段ごとの解決を確かめるとき、zsh で `bundle lock --update $4` の `$4` に 2 つの gem 名を入れると、1 つの単語として渡されて `Could not find gem 'doorkeeper-openid_connect ostruct'` になった。`${=4}` にした（TIPS.md にある注意）。また、lock にない ostruct は `--update` で指定できないので、Gemfile に版を書いて `bundle lock` で確かめた
2. 先に足したテストの 2 本が、doorkeeper-openid_connect 1.10.1 で、スナップショットと比べる前に `JSON::ParserError` で落ちた。上の「作業計画からの変更点」のヘルパーの修正で直した

### 確認結果

- `scripts/check-apps`（3 アプリと E2E）: 36 の検査がすべて通った。gem・雛形のコミットの前には、OP と E2E で流した
- minitest: RS 11 runs・RP 33 runs・OP 57 → 69 runs、0 failures。`CI=1`（eager load あり）でも同じ件数で通る
- E2E: 10 passed。スナップショットの差分なし（userinfo・introspect のキーの順の変化は、キーを並べ替えて比べるので出ない）
- RuboCop: 3 アプリとも `no offenses detected`。`zeitwerk:check` は `All is good!`。`ANTI_MANNER=1 bin/rails runner 1` は test（`CI=1` 付きも）・development で `✅Congratulations!`。bundler-audit: `No vulnerabilities found`。無視リストを空にした bundler-audit で、無視リストの ID はすべて今も報告される。brakeman: `Security Warnings: 0`、`Ignored Warnings: 2`
- 応答のスナップショットの変化は、上の「意図的な仕様変更」と DEF-7.0-45・46 だけ。どれも人間に確かめてから作り直した
- `bin/rails s` は手動確認で 3 アプリとも起動した
- 手動確認用の環境: 上の「手動確認」

### コードレビュー（`/code-review`）

| 指摘 | 対応 |
|---|---|
| DEF-7.0-45 が、エラー画面の雛形がローカル変数 `error_response` を読み、`<pre>` の中で改行するようになった版を 5.6.7（#1676）・5.7.0（#1702）としているが、doorkeeper のタグのソースでは 5.6.5 から（5.6.4 までは 1 行） | DEF-7.0-45 を直した。5.7.0 の #1702 は `respond_to?` を `local_assigns` にした変更。v5.6.4・v5.6.5 のタグで確かめた |
| エラー画面のテストのコメントの「doorkeeper 5.7.0 からの雛形は」も同じ誤り | 5.6.5 に直した |
| 応答のスナップショットのヘルパーが、JSON の `Content-Type` のどの応答でも、読めない本文をテキストとして扱う。トークン応答などが壊れた JSON を返すようになると、JSON のキーで伏せる処理が効かないまま、`UPDATE_SNAPSHOTS` で本物のトークンがファイルに書かれうる | テキストとして扱うのをリダイレクト（`response.redirect?`）の応答だけに絞った（人間が承認。3 アプリ）。リダイレクト以外の応答で壊れた JSON を返すと `JSON::ParserError` で落ちることを、一時的なテストで確かめた（確かめた後で消した） |
| 上の「テストの追加」の「後で 1 本を置き換え」は、置き換えたのが 2 本（Webfinger・form_post での拒否） | 直した |
| 上の「OIDC のエラーのリダイレクトのヘッダー」の「1.2〜1.7.5」は、確かめたタグの範囲を超えている | 確かめたタグ（v1.2.0・v1.4.0・v1.5.0・v1.6.0・v1.7.0・v1.7.5）を書いた |
| DEF-7.0-45・46 を記録したコミット（a7738c6）が、その時点ではまだない LOG.md の Step 1-b-3-2 の節を指している（CLAUDE.md の「まだ存在しないものを現在形で書かない」） | 直さない。この PR の docs のコミットで節ができたので、PR の時点では参照先がある。履歴は書き換えない。今後は、参照する LOG.md の節を先に書く |
| ヘルパーが本文を 2 回 `JSON.parse` する（判定と整形） | 直さない（人間が承認）。応答 1 件ごとの小さな手間で、判定を分けたほうが読みやすい |

コードレビューの後も、`scripts/check-apps`（3 アプリと E2E）の 36 の検査がすべて通ることを確かめた。

## Step 2: Ruby 3.2（2026-10-10）

- ブランチ / PR: `upgrade/step2-ruby32` / [#26](https://github.com/thinkAmi-sandbox/oidc_op_rp-sample/pull/26)
- バージョン: Ruby 3.1.7 → 3.2.11 / Rails 7.0.10（変更なし）。Bundler 2.3.27 → 2.4.19（`BUNDLED WITH`）。lock の default gem を 3.2.11 の版に合わせ直した。nokogiri 1.18.10 → 1.19.4
- Ruby だけを上げる最初の Step。分かった手順は TIPS.md の「Ruby を上げる」にまとめた（スキル化の材料。PLAN.md の 13 章）
- 既定値への追随（A）と業務的な挙動の変化（B）は、どちらも起きなかった（下の「前後の比較」）。defaults/ への記録はない

### 作業計画で決めたこと

着手時に PLAN.md 8 章の手順で確かめ直し（サブエージェント 3 つ: Ruby 3.2.11 の事実、gem の対応、lock の解決）、作業計画を出して承認を得た。lock の解決の試行は、Plan モードではファイルを書けないので、承認の後に Ruby 3.2.11 を入れてから scratchpad のコピーで行った。確かめたことと決めたことの一覧は PLAN.md の Step 2 の節に移した。

| 論点 | 決めたこと | 理由 |
|---|---|---|
| 版 | 3.2.11 | 3.2 系の最新で最後のリリース。3.2 は EOL だが、マイナーを飛ばさない |
| lock の default gem | Ruby を上げるコミットの中で、3.2.11 の default gem の版に合わせ直す | 合わせ直さないと、旧版（json 2.6.1・bigdecimal 3.1.1 は C 拡張）を rubygems から落としてビルドすることになり、アプリが読む版も default gem からずれる |
| `BUNDLED WITH` | 3.2.11 の Bundler 2.4.19 | 2.3.27 のままだと、手元の Bundler 2.4.19 と CI の setup-ruby が bundler 2.3.27 を落として使う |
| gem の入れ直し | 前の版のキャッシュの `.gem` をコピーして `bundle install --local` | Ruby のマイナーで置き場所（`vendor/bundle/ruby/3.2.0`）が変わる。3 アプリで約 75 MB のダウンロードを避ける |
| PR に入れるもの | Ruby・`TargetRubyVersion`・nokogiri 1.19.4 | nokogiri は advisory の修正で、PLAN.md 6 章で Step 2 に入れると決めていた。Ruby を上げるコミットとは分けた |
| ほかの Ruby 3.2 以上を必要とする gem | サブステップ 2-b として別の PR | 1 つずつ上げる。web-console 4.3 は Rails 8 が必要なので Step 6、faraday-net_http は 3.0.2 のまま Step 8 で見直す（PLAN.md 7 章） |
| 手動確認 | 3 アプリの Ruby を上げた後に 1 回（introspection の流れまで） | 人間の指示 |

### 作業計画からの変更点

- gem の入れ直しは、計画の `bundle install --local` では動かず、`BUNDLE_CACHE_PATH` でコピーしたキャッシュを指した。RS・RP では、そのために default gem の `.gem` を落としてしまった（下の「遭遇した問題」1）。OP は人間の承認を得て `--no-cache` を付け、ダウンロードなしで入れた
- 計画では lock の試行で `bundle update --bundler=2.4.19` も試すつもりだったが、`BUNDLER_VERSION=2.4.19` で `bundle lock` を流すと `BUNDLED WITH` が 2.4.19 になったので、要らなかった
- CVE-2026-41316（erb）は、計画どおり記録と一緒に相談し、記録だけにした（下の「CVE-2026-41316（erb）」）

### gem ごとの対応

| gem | バージョン | 対応 |
|---|---|---|
| （Ruby） | 3.1.7 → 3.2.11 | `mise install ruby@3.2.11`。ruby-build 20260924 がソースからビルドし、Homebrew の OpenSSL 3.5.0・libyaml 0.2.5 にリンクした。落としたのは `ruby-3.2.11.tar.gz`（19,984,344 B）だけで、ruby-build の定義の SHA256 は告知の値と同じ |
| json / bigdecimal / logger / drb / mutex_m | 2.6.1 / 3.1.1 / 1.5.0 / 2.1.0 / 0.1.1 → 2.6.3 / 3.1.3 / 1.5.3 / 2.1.1 / 0.1.2 | 3.2.11 の default gem の版に合わせ直した（3 アプリ）。default gem から読まれることを確かめた |
| ostruct | 0.5.2 → 0.5.5 | 同上（OP） |
| base64 / cgi / ruby2_keywords | 0.1.1 / 0.3.7 / 0.0.5（変更なし） | 3.2.11 の default gem と同じ版（cgi は RP） |
| benchmark / securerandom | 0.3.0（変更なし） | 3.2.11 の default gem（0.2.1・0.2.2）は activesupport 7.0.10 の `>= 0.3` を満たさない |
| nokogiri | 1.18.10 → 1.19.4 | `bundle update nokogiri --conservative`。動いたのは nokogiri の 3 つのプラットフォームの行だけ。advisory 12 件（GHSA-5prr-v3j2-97mh ほか）を無視リストから消した |

- lock の試行（scratchpad のコピー。Ruby 3.2.11・`BUNDLER_VERSION=2.4.19`）: Gemfile の `ruby` を変えて default gem を固定して `bundle lock` → 固定を外して `bundle lock --local` で、3 アプリとも動いたのは default gem の行と `RUBY VERSION`（`ruby 3.2.11p268`）・`BUNDLED WITH` だけ。`PLATFORMS` は変わらない。この lock をアプリに持ち込んだ（アプリの Gemfile とコピーの Gemfile が同じことを `diff` で確かめた）
- C 拡張は Ruby 3.2 向けにビルドし直した（bootsnap・byebug・date・msgpack・nio4r・prism・puma・racc・websocket-driver、RP・OP は bindex、OP は bcrypt）。nokogiri・sqlite3 は arm64-darwin のプラットフォーム版の 3.2 のバイナリを使う
- ダウンロードした nokogiri 1.19.4-arm64-darwin（6,547,456 B。3 アプリで 1 回ずつ）の SHA-256 は rubygems.org の値と同じ
- epic と比べて lock で動いたのは、上の行と `RUBY VERSION`・`BUNDLED WITH` だけ。Step 1 の一時固定（benchmark・securerandom）、faraday-net_http 3.0.2、jwt 2.10.3、Gemfile の `ruby` 以外の行は動いていない

### CVE-2026-41316（erb）

- 2026-04-21 に公表された erb の advisory（`<= 6.0.3`）。信頼できないデータを `Marshal.load` するプロセスで、erb と activesupport を読み込んでいるとガジェットになる。Ruby 3.2.11 の default gem の erb 4.0.2 も、作業前の 3.1.7 の erb 2.2.3 も対象で、3.2 は EOL なので 3.2 の修正版は出ない
- 3 アプリには、信頼できないデータを `Marshal.load` する経路がない。アプリのコード（app・lib・config）に `Marshal` はなく、Cookie は JSON で直列化し（DEF-7.0-16）、RP のセッションストアも JSON、キャッシュは test・development とも `:null_store`（development は `tmp/caching-dev.txt` がない）
- 人間の判断で、Gemfile に erb を足さずに記録だけにした。Ruby 3.3.12 の default gem の erb は 4.0.3.1、3.4.11 は 4.0.4.1（修正版。GitHub のタグの `lib/erb/version.rb` で確かめた）なので、Step 4 で解消を確かめる（PLAN.md 7 章の erb の行）。default gem の erb は lock にないので、bundler-audit は検出しない

### 作業計画からの変更点

- RS の jwt を上げなかった。作業計画は jwt を「3 アプリ（RS は oauth2 の依存）」としていたが、決めたことの論点 4（直接の gem だけが方針の対象）と食い違っていた。3 アプリの lock を上げて検査を通した後、RS のコミットメッセージを書く段階で気づき、止まって人間に確かめた
  - 人間の質問に答えて、2.10.3 のままのリスクを確かめた。2.10.3 は CVE-2026-45363（GHSA-c32j-vqhx-rx3x、HMAC の空の鍵での検証のすり抜け）の修正版で、ほかの advisory はない。RS は jwt の処理を通らない（oauth2 2.0.25 の `lib/oauth2/strategy/assertion.rb` が `require` し、使わない assertion のグラントの `JWT.encode` だけが呼ぶ）。3 系の強化（RSA 2048 ビット以上、厳しい base64、検証前の payload の禁止）は検証する側のもので、RS には当たらない
  - ruby-jwt の `2-10-stable` は、2.10.2 以降は 2 回のバックポート（2025-06-29、2026-05-22 の CVE の修正）だけで、将来の修正が戻される保証はない。人間は、jwt だけを例外にするのではなく、epic の最後の段階で間接の gem もまとめて上げることを考えたいとし、伊藤さん式と ruby-jp のアップグレードガイドの間接の gem の扱いを調べた（PLAN.md の 14 章）
  - 人間の判断で、RS の lock の変更を戻し、2.10.3 のままにした。間接の gem をまとめて上げる段階で上げる

### 前後の比較

Ruby を上げる前（3.1.7）に、`scripts/check-apps` の結果と、起動の途中に読み込み済みの部品（`config/application.rb` の後・`config/initializers` の直前・`initialize!` の後。test・development）を書き出し、各アプリを上げた後と比べた。

- `scripts/check-apps`: 3.1.7 でも 3.2.11 でも 36 の検査がすべて通り、件数は同じ（下の「確認結果」）
- 応答のスナップショット（minitest）と E2E のスナップショット: 差分なし
- 起動の途中に読み込み済みの部品: 3 アプリとも test・development で前後が同じ（RP の `action_dispatch_request`、OP・RP の development の web-console の分は既知の IMP-009）
- テストの出力の警告: 前後とも OP の `auth_time_from_resource_owner` の DEPRECATION（IMP-011）だけ。Ruby の `warning:` の行はない。Ruby の非推奨の警告は既定で出ないので、コードレビューの後に 3.2.11 で `RUBYOPT=-W:deprecated` を付けて 3 アプリの minitest と development の eager load（`bin/rails runner 'Rails.application.eager_load!'`）を流し、`warning:` の行が 0 件なことを確かめた（3.1.7 では流していない）
- brakeman: EOLRuby の警告は「Support for Ruby 3.2.11 ended on 2026-03-31」になったが、fingerprint にメッセージは含まれないので、無視リストに当たったまま（`Ignored Warnings: 2`）。無視リストのメッセージは 3.1.7 のまま残した
- RuboCop: `TargetRubyVersion` を 3.2 にしても新しい指摘はない

### 手動確認

3 アプリの Ruby を上げた後（`TargetRubyVersion`・nokogiri の前）に、`.claude/launch.json` から 3 アプリを起動してブラウザペインで確かめた（同意は人間が操作）。3 アプリとも Puma の起動の出力に Ruby 3.2.11 が出た。

- ログイン（RP の my_op）: 人間が「Re Login」を押した。OP のセッションが前回の手動確認から残っていたので、ログイン画面を経ず、同意画面も省いて（my_op のアプリにこのユーザーの有効なトークンがあるため）RP に戻り、「ログインしました」が出た。OP のログは、認可エンドポイントが 302、トークン・userinfo・JWKS が 200。パスワードを入れる経路（devise のログイン）は、この手動確認では通っていない（minitest・E2E で確かめている）
- introspection 用 RP: 前回のトークンは revoke 済みなので同意画面が出て、Authorize の後、RS は正しいトークンで 200、`_bad` を付けたトークンで 401、revoke は 200、revoke の後は 401。RS が受け取った introspect は `active: true`（キーの順は `iat, exp`、`exp - iat = 600`）→ `active: false` が 2 回
- サーバーの出力: 3 アプリとも、エラー・warning・DEPRECATION の新しいものはない。RP の `/stylesheets/application.css` のルーティングのエラーは元からのもの
- 手動確認用の環境: 作業の開始時に 9 ファイルのハッシュを控え、件数が Step 1-b-3-2 の手動確認の後と同じこと（OP `oauth_access_grants` 15・`oauth_access_tokens` 37、RP `sessions` 12・`op_users` 1）を確かめた。手動確認の直前にハッシュが同じことを確かめた。手動確認で、OP の development DB は `oauth_access_grants` が 15 → 17 件、`oauth_access_tokens` が 37 → 42 件（my_op 1・introspection 用 1（revoke 済み）・RS のクライアントクレデンシャル 3）、RP の development DB は `sessions` が 12 件のまま（既にある行を更新）で、どちらもハッシュが変わった。RS の DB・署名鍵・`.env`・3 アプリの `tmp/development_secret.txt` は変わっていない。以降の基準は手動確認の後のハッシュ

### 遭遇した問題

1. 意図しないダウンロード: `bundle install --local` は、インストール先のキャッシュ（`vendor/bundle/ruby/3.2.0/cache`）ではなくアプリのキャッシュ（`cache_path`。既定は `vendor/cache`）しか見ないので、コピーした `.gem` が見つからずに止まった（何も入れていない）。`BUNDLE_CACHE_PATH` でコピーしたキャッシュを指して流し直すと入ったが、入れた後にアプリのキャッシュを最新にする処理が走り、キャッシュになかった default gem の `.gem`（base64 0.1.1・bigdecimal 3.1.3・ruby2_keywords 0.0.5・drb 2.1.1・logger 1.5.3・mutex_m 0.1.2・json 2.6.3、RP は cgi 0.3.7 も。1 つ 7〜87 KB）を、`--local` を付けていても rubygems.org から落とした。RS では出力の末尾だけを見ていて気づかず、RP で気づいて止まり、人間に報告した。落としたファイルの SHA-256 は rubygems.org の値と同じで、キャッシュに置かれただけでインストールはされていない（アプリは default gem を読む）。人間の承認を得て、ファイルはキャッシュに残し、OP は `--no-cache` を付けてダウンロードなしで入れた。TIPS.md の「Ruby を上げる」に書いた
2. Claude Code の hooks の安全チェックが、`git commit` と同じコマンド行の `grep -n` を `git commit -n`（`--no-verify`）と見なして止めた。コミットは別の呼び出しで流した（TIPS.md の「コミット」）
3. lock の試行のディレクトリを作り直そうとした `rm -rf` が、変数を使ったパスのために Claude Code の安全確認で止められた。新しいディレクトリだったので、消さずに作って進めた

### 確認結果

- `scripts/check-apps`（3 アプリと E2E）: 36 の検査がすべて通った。各アプリのコミットの前には、そのアプリと E2E で流した
- minitest: RS 11 runs・RP 33 runs・OP 69 runs、0 failures（3.1.7 と同じ）。`CI=1`（eager load あり）でも同じ件数で通る
- E2E: 10 passed。スナップショットの差分なし
- RuboCop: 3 アプリとも `no offenses detected`（`TargetRubyVersion: 3.2`）。`zeitwerk:check` は `All is good!`。`ANTI_MANNER=1 bin/rails runner 1` は test（`CI=1` 付きも）・development で `✅Congratulations!`。bundler-audit: `No vulnerabilities found`。無視リストを空にした bundler-audit で、無視リストの ID はすべて今も報告される（nokogiri の 12 件は消した）。brakeman: `Security Warnings: 0`、`Ignored Warnings: 2`
- `bin/rails s` は手動確認で、`bin/rails c` は作業の最後に、3 アプリとも起動した
- 手動確認用の環境: 上の「手動確認」。作業の最後に、9 ファイルのハッシュが手動確認の後と同じだった

### コードレビュー（`/code-review`）

| 指摘 | 対応 |
|---|---|
| 前後の比較で `warning:` の行を見ているが、Ruby の非推奨の警告は既定で出ない（`Warning[:deprecated]` は false）ので、Ruby 3.2 で非推奨になったものを見落とす | 3.2.11 で `RUBYOPT=-W:deprecated` を付けて 3 アプリの minitest と development の eager load を流し、警告が 0 件なことを確かめた（上の「前後の比較」）。TIPS.md の「Ruby を上げる」の前後の比較に足した |
| TIPS.md の Ruby の入れ方は mise 2026.5 系の挙動で、2026.8.0 からはビルド済みのもの（jdx/ruby）を落とす形が既定になる | TIPS.md に、手元の版と、mise を上げたら落とすものとサイズを確かめ直すことを書いた |
| PLAN.md 7 章の faraday-net_http を「Step 8 で見直す」とした根拠がない | Ruby 3.3.12 の default gem の net-http は 0.4.1、3.4.11 は 0.6.0（GitHub のタグの `lib/net/http.rb`）で、faraday-net_http 3.4.x の `net-http ~> 0.5` を満たすのは 3.4 から。根拠を 7 章に書いた |
| PLAN.md の Step 2 の「決めたこと」に、erb の扱いを「人間と決める」と書いたまま、決めた内容が別の行にある | 決めた内容の行を指すように直した |
| brakeman.ignore の EOLRuby のメッセージが Ruby 3.1.7 のまま | 直さない。fingerprint にメッセージは含まれず、無視リストに当たり続ける。Step 1 で EOLRails のメッセージを残したのと同じ扱いで、上の「前後の比較」と TIPS.md に書いてある |
| コピーしたキャッシュの `.gem` は、Bundler 2.4 の lock に checksum がないので、入れるときに照らし合わされない | 3 アプリの `vendor/bundle/ruby/3.2.0/cache` の `.gem` 360 個（重複を除いて 177）の SHA-256 が、すべて rubygems.org の値と同じことを確かめた。TIPS.md に確かめ方を足した |

## Step 2-b: Ruby 3.2 以上を必要とする周辺 gem（2026-10-10〜2026-10-11）

- ブランチ / PR: `upgrade/step2b-ruby32-gems` / [#27](https://github.com/thinkAmi-sandbox/oidc_op_rp-sample/pull/27)
- バージョン: Ruby 3.2.11・Rails 7.0.10（変更なし）。OP の doorkeeper-openid_connect 1.10.1 → 1.10.5。3 アプリの zeitwerk 2.6.18 → 2.7.5 → 2.8.3、byebug 12.0.0 → 13.0.0、simplecov 0.22.0 → 1.2.0、brakeman 7.1.1 → 8.0.6。byebug の依存の reline 0.6.0・io-console 0.6.0（一時固定）が lock に入り、simplecov の依存だった docile・simplecov-html・simplecov_json_formatter が lock から消えた
- 追随した gem の既定値・雛形は、[defaults/rails-7.0.md](defaults/rails-7.0.md) の「周辺 gem（Step 2-b）」に記録した（DEF-7.0-48〜50）。業務的な挙動の変化（B）は起きなかった
- gem を上げる手順で分かったことは、TIPS.md の「gem の更新」と「rails c を確かめる」にまとめた（スキル化の材料。PLAN.md の 13 章）

### 作業計画で決めたこと

着手時に PLAN.md 8 章の手順で確かめ直し（サブエージェント 3 つ: doorkeeper-openid_connect、byebug・reline・rack-mini-profiler、simplecov・zeitwerk・brakeman。lock の解決は `bundle lock --update <gem> --conservative --print` で lock を書かずに試した）、作業計画を出して承認を得た。確かめたことと決めたことの一覧は PLAN.md の Step 2-b の節に移した。

| 論点 | 決めたこと | 理由 |
|---|---|---|
| 順番 | doorkeeper-openid_connect → 雛形への追随 → zeitwerk 2.7.5 → 2.8.3 → byebug → simplecov → brakeman。1 gem ずつ、アプリごとに RS → RP → OP | doorkeeper-openid_connect は advisory の修正版なので最初（CLAUDE.md）。アプリの実行に関わる zeitwerk の後に、開発・テストの道具 |
| doorkeeper-openid_connect | `--patch --conservative` で 1.10.5。2.0.0 は対象外 | `--conservative` だけでは 2.0.0（メジャー。マイグレーションが要る）になる |
| zeitwerk | 2.7.5（一時固定）→ 2.8.3 | マイナーを飛ばさない。Rails v7.0.10 自身の lock が 2.7.3 |
| reline・io-console | reline 0.6.0・io-console 0.6.0 に一時固定 | byebug 13 は `reline >= 0.6.0` で、Ruby 3.2.11 の default gem の reline 0.3.2 では満たせない。reline は要件を満たす最小の版（Step 1 の benchmark・securerandom と同じ扱い）、io-console は default gem と同じ版（固定しないと C 拡張の 0.9.4 が入る） |
| brakeman | 8.0.6 | 8.1.0 は 2026-10-01 公開で、2 週間たっていない |
| rack-mini-profiler | 上げずに Step 3 に移す（人間が判断。CLAUDE.md の ①対応版を待つ） | 5.0.0 の railtie が Rails 7.1 の `Rails.env.local?` を使い、Rails 7.0 の development ではプロファイラーが無効になる |
| ほかの gem | `bundle outdated` に出る jwt 3.x と間接依存は動かさない | 2-b は Ruby 3.2 以上を必要とする gem だけ。jwt 3.x の時期は未定（PLAN.md 7 章） |
| 手動確認 | すべての gem を上げた後に 1 回（introspection の流れまで） | doorkeeper-openid_connect と、development の zeitwerk の読み込みを含めるため |

### 作業計画からの変更点

- simplecov は、計画で「DEF-7.0-50 の候補（記録するかも含めて確かめる）」としていた。出力の変化を解説し、DEF-7.0-50 として記録して追随すると人間が決めた。最新の 1.3.2 は Ruby 3.3 以上が必要で今は入らないので、1.3 系の変化（対象のファイルがないグループを省く、`rails` プロファイルのグループの並び）を確かめて DEF-7.0-50 に書き、1.3 は Step 4（Ruby 3.3）の後に上げることにした（人間の質問への回答。コードレビューで、Step 4 は Ruby だけを上げるので、その後のサブステップと書き直した）
- brakeman 8.0.6 で `RenderRCE` のチェックが増えた。警告の結果は変わらないので、DEF にせず、この節とコミットメッセージに記録した（人間が判断）
- 記録の後に、IMP-011 に、1.10.2 で増えた `auth_time_from_access_token`（grant ごとの `auth_time`。`max_age` の判定には使われない）も選べることを書き足した（人間が承認）

### gem ごとの対応

| gem | バージョン | 対応 |
|---|---|---|
| doorkeeper-openid_connect | 1.10.1 → 1.10.5 | OP。`bundle update doorkeeper-openid_connect --patch --conservative`。GHSA-8r7r-wh7x-27ff（1.10.4 で修正。DCR は無効なので影響しなかった）を解消した。ruby-advisory-db にない advisory なので、無視リストの変更はない |
| （雛形） | — | OP の initializer（DEF-7.0-48）とロケール（DEF-7.0-49）を 1.10.5 の雛形に合わせた。initializer は雛形の 1.10.1 → 1.10.5 の差分を `patch` で当て、独自の設定の印に当たって外れた 1 か所（`auth_time_from_access_token` の例）を手で足した。印の中の独自の設定と雛形との差分は前後で同じ |
| zeitwerk | 2.6.18 → 2.7.5 → 2.8.3 | 3 アプリ。2.7.5 は一時固定（Gemfile に版を足して `bundle install` → 外して `bundle lock --local`）、2.8.3 は `bundle update zeitwerk --conservative` |
| byebug | 12.0.0 → 13.0.0 | 3 アプリ。Gemfile に `io-console 0.6.0`・`reline 0.6.0` を足して `bundle update byebug --conservative` → 外して `bundle lock --local`。io-console は落とさず default gem を使い、ビルドもしなかった |
| simplecov | 0.22.0 → 1.2.0 | 3 アプリ。`bundle update simplecov --conservative`（1.3 は Ruby 3.3 以上なので 1.2.0 で止まる）。DEF-7.0-50 |
| brakeman | 7.1.1 → 8.0.6 | 3 アプリ。Gemfile の既にある行に一時的に `'8.0.6'` を書いて `bundle update brakeman --conservative` → 戻して `bundle lock --local`。racc は 1.5.2 のまま |

- ダウンロードした `.gem`（doorkeeper-openid_connect 1.10.5、zeitwerk 2.7.5・2.8.3、byebug 13.0.0、reline 0.6.0、simplecov 1.2.0、brakeman 8.0.6。OP 以外は 3 アプリで 1 回ずつ）の SHA-256 は、すべて rubygems.org の値と同じ
- epic と比べて lock で動いたのは、上の gem の行と、増えた reline・io-console、消えた docile・simplecov-html・simplecov_json_formatter だけ。lock に入れた default gem（json・bigdecimal・logger・base64・cgi・ostruct・drb・mutex_m・ruby2_keywords）、一時固定の gem（benchmark・securerandom・faraday-net_http・jwt 2.10.3）は動いていない。Gemfile は 3 アプリとも epic と同じ

### 前後の比較

- 起動の途中の読み込み: gem ごとに、上げる前後で、`config/application.rb` の後・`config/initializers` の直前・`initialize!` の後に読み込み済みの部品と、`filter_parameters`・`ActiveRecord::Base.filter_attributes` を test と development で書き出して比べた（TIPS.md の「設定の値と応答の比較」の方法）。変わったのは、doorkeeper-openid_connect 1.10.5 で `Doorkeeper::AccessGrant` が起動の時点で読み込まれなくなったことだけ。1.10.3（#308）で、`openid_request` の関連を `on_load(:active_record)` の `run_hooks` ではなく、モデルが読み込まれたとき（`AccessGrantExtension#included`）に足すようになったため。読み込んだ後の関連（`Doorkeeper::OpenidConnect::Request`）は同じ。1-b-3-2 で doorkeeper 5.9.9 が `Doorkeeper::AccessToken` を遅延して読み込むようになったのと同じ形
- 応答のスナップショット（minitest）と E2E のスナップショット: どの gem でも差分なし
- `-W:deprecated` を付けた development の eager load（`bin/rails runner 'Rails.application.eager_load!'`）: zeitwerk 以降の各段で、3 アプリとも `warning:` の行は 0
- テストの出力の警告: 前後とも OP の `auth_time_from_resource_owner` の DEPRECATION（IMP-011）だけ。1.10.5 でも文言は同じ
- byebug 13 を require しただけでは reline を読まない: コードレビューの後に、RS の development と test で `bin/rails runner` から `defined?(Reline)` が nil で、読み込み済みの readline 系のファイルは thor の `line_editor/readline.rb` だけなことを確かめた（byebug 13 は `byebug` を呼んだときに reline を読む）
- `bin/rails c`（byebug 13）: 擬似端末で起動して確かめた（TIPS.md の「rails c を確かめる」）。上げる前は reline 0.3.2・irb 1.6.2、上げた後は lock の reline 0.6.0・io-console 0.6.0 と default gem の irb 1.6.2 を読み、どちらも `IRB::RelineInputMethod` で、複数行の入力（`if true` … `end`）は `=> 42` を返した。`already activated` などの警告はない。違ったのは、`Rails.versi` に Tab を 1 回送ったとき、0.6.0 では `Rails.version` に補完され、0.3.2 では補完されなかったことだけ（擬似端末での模擬の結果で、原因は確かめていない）
- byebug: `bin/rails runner` の中で `byebug` を呼ぶと、12.0.0 でも 13.0.0 でも同じ位置（`rails runner` が文字列を評価した後の railties の行）で止まり、`next` の行き先も同じで、`continue` で抜けた。入力を読むのが Readline から Reline 0.6.0 になった
- simplecov: カバレッジの値（RS 33/33・RP 112/112・OP 14/14 で、どれも 100%）、集計の対象のファイル（RS 7・RP 15・OP 8）、`.last_run.json` は同じ。結果の行と `coverage/` の中身が変わった（DEF-7.0-50）
- brakeman: 3 アプリとも終了コード 0、`Security Warnings: 0`、`Ignored Warnings: 2`。JSON の出力で、警告と無視した警告の fingerprint・チェック名・メッセージが前後で同じことを確かめた。違うのは `Checks Run` に `RenderRCE`（8.0.0 で `CheckRender` から分かれた。対象は Rails 4.2.5 以下）が増えたことだけ

### 手動確認

すべての gem を上げた後に、`.claude/launch.json` から 3 アプリを起動してブラウザペインで確かめた（操作は人間）。3 アプリとも Puma の起動の出力に Rails 7.0.10 が出た。RP の画面には rack-mini-profiler 4.0.1 のバッジが出た。

- ログイン（RP の my_op）: 人間が「Re Login」を押した。OP のセッションが前回の手動確認から残っていたので、ログイン画面を経ず、同意画面も省いて（my_op のアプリにこのユーザーの有効なトークンがあるため）RP に戻った。OP のログは、認可エンドポイントが 302、トークン・userinfo・JWKS が 200。RP の ID トークンの検証（JWKS の取得と nonce の比較）も通った
- introspection 用 RP: 前回のトークンは revoke 済みなので同意画面が出て、Authorize の後、RS は正しいトークンで 200、`_bad` を付けたトークンで 401、revoke は 200、revoke の後は 401。RS が受け取った introspect は `active: true`（キーの順は `iat, exp`、`exp - iat = 600`）→ `active: false` が 2 回
- サーバーの出力: 3 アプリとも、エラー・warning・DEPRECATION の新しいものはない。RP の `/stylesheets/application.css` のルーティングのエラーは元からのもの
- 手動確認用の環境: 作業の開始時に 9 ファイルのハッシュを控え、件数が Step 2 の手動確認の後と同じこと（OP `oauth_access_grants` 17・`oauth_access_tokens` 42、RP `sessions` 12・`op_users` 1）を確かめた。手動確認の直前（サーバーを起動し直す前）にもハッシュが同じことを確かめた。手動確認で、OP の development DB は `oauth_access_grants` が 17 → 19 件、`oauth_access_tokens` が 42 → 47 件（my_op 1・introspection 用 1（revoke 済み）・RS のクライアントクレデンシャル 3）、RP の development DB は `sessions` が 12 件のまま（既にある行を更新）で、どちらもハッシュが変わった。RS の DB・署名鍵・`.env`・3 アプリの `tmp/development_secret.txt` は変わっていない。以降の基準は手動確認の後のハッシュ

### 遭遇した問題

1. `bin/rails c` を `script` コマンドの擬似端末で起動すると、Claude Code の Bash の環境に `TERM` がないため、reline 0.3.2 が terminfo を引けずに `rails/commands/console/console_command` の読み込みに失敗した。`TERM=xterm-256color` を付けると起動したが、reline がカーソル位置の問い合わせ（`ESC[6n`）を送って端末の返事を待つので、入力をパイプで流すだけでは止まったままになった（自分で起動したプロセスを止めた）。問い合わせに `ESC[1;1R` を返す Python の擬似端末のドライバー（scratchpad）で確かめた。TIPS.md に書いた
2. カバレッジの集計の対象を読み出すスクリプトの `ruby` が、mise を通さずに macOS 標準の Ruby 2.6 で動き、`_1` が使えずに落ちた。`mise exec -- ruby` にした（TIPS.md の「コマンドの実行」にある注意）
3. 手動確認を頼んだ後、人間がブラウザペインを開き直したときには、3 アプリのサーバーがアプリによって止められていた（約 11 時間前）。ハッシュと件数が変わっていないことを確かめてから、起動し直した
4. 手動確認の依頼で、RP の `/introspection` の画面が「Login」ボタンで流れを始めることを書いていなかったので、人間が画面を開いただけで止まった。ボタンを押すよう頼み直した

### 確認結果

- `scripts/check-apps`（3 アプリと E2E）: 36 の検査がすべて通った。各コミットの前には、そのアプリと E2E で流した
- minitest: RS 11 runs・RP 33 runs・OP 69 runs、0 failures（Step 2 と同じ）。`CI=1`（eager load あり）でも同じ件数で通る
- E2E: 10 passed。スナップショットの差分なし
- RuboCop: 3 アプリとも `no offenses detected`。`zeitwerk:check` は `All is good!`。`ANTI_MANNER=1 bin/rails runner 1` は test（`CI=1` 付きも）・development で `✅Congratulations!`。bundler-audit: `No vulnerabilities found`。無視リストを空にした bundler-audit で、無視リストの ID はすべて今も報告される。brakeman: `Security Warnings: 0`、`Ignored Warnings: 2`
- `bin/rails c` は擬似端末で、`bin/rails s` は手動確認で、3 アプリとも起動した
- 手動確認用の環境: 上の「手動確認」

### コードレビュー（`/code-review`）

| 指摘 | 対応 |
|---|---|
| PLAN.md 7 章と DEF-7.0-50 が simplecov 1.3 を「Step 4」で上げるとしているが、Step 4 は Ruby だけを上げる Step で、CLAUDE.md の「一度に上げるのは 1 つだけ」と食い違う | 「Step 4（Ruby 3.3）の後の周辺 gem のサブステップ」に直した（PLAN.md の Step 2-b と 7 章、DEF-7.0-50、この節の「作業計画からの変更点」） |
| PLAN.md の Step 2-b の rack-mini-profiler の行が、5.0.0 でバッジ・ヘッダーが出なくなることを事実として書いているが、確かめたのは `Rails.env.local?` が false になることだけ | ソースを読んでの推論（5.0.0 は入れていない）と書いた。Step 3 で上げるときに確かめる |
| byebug 13 を require しただけでは reline を読まない、という記述（PLAN.md・コミットメッセージ）を確かめた記録がない | 確かめて、上の「前後の比較」に書いた |
| brakeman 8.1.0 の時期の「次の Step の最初」が、gem を上げないスキル化の PR を指すのか Step 3 を指すのか曖昧 | 「Step 3 の最初」に直した（PLAN.md の Step 2-b と 7 章） |
| PLAN.md の Step 2-b の zeitwerk の行が、サブエージェントの API の突き合わせと、自分で確かめたことを区別していない | 区別して書いた |
| TIPS.md の「rails c を確かめる」の擬似端末のドライバーが scratchpad にしかなく、後の Step で再現できない | 直さない。13 章の振り分け（3 アプリに固有の道具は `scripts/`）に照らして、スキルを作る PR で `scripts/` に置くかを決める |

コードレビューの後も、`scripts/check-apps`（3 アプリと E2E）の 36 の検査がすべて通り、手動確認用の環境の 9 ファイルのハッシュが手動確認の後と同じことを確かめた。

## スキル化: `/rails-upgrade` のスキルと、Rails のマイナーを上げるときのスクリプト（2026-10-11）

- ブランチ / PR: `upgrade/skill-rails-upgrade` / [#28](https://github.com/thinkAmi-sandbox/oidc_op_rp-sample/pull/28)
- バージョン: Ruby 3.2.11・Rails 7.0.10（変更なし）。gem は上げていない。アプリのコードと lock も変えていない
- この節は、スキル化の PR で決めた記録の書き方（research の出口で節を作り、作業ごとに足していく。PLAN.md の 13 章の 3）にならい、作業の途中から書いている

### 作業計画で決めたこと

着手時に PLAN.md 8 章の手順で確かめ直し（サブエージェント 2 つ: Claude Code のスキルの仕様、Step 1 を再現する条件）、作業計画を出した。作業計画への返事の対話で、スキルの方向を人間と決め直してから承認を得た。確かめたことと決めたことの一覧は、PLAN.md の 6 章の「スキル化」と 13 章に移した。

| 論点 | 決めたこと | 理由 |
|---|---|---|
| スキルの方向 | 知識のある担当者が判断の要る所だけを確かめ、それ以外は AI が再現性のある形で進める。スキルの役割は、細部を知らないレビュアーに担当者が説明できる状態の PR を、毎回同じ形で作ること | 人間のチームでは、担当者だけではアップグレードを完了できず、レビュアーが PR を見て OK を出したら完了とする。担当者は、なぜ必要かを理解してレビュアーに説明する（人間の説明）。これまでの関門でも、人間は Rails と gem の知識を前提に AI の案を直してきた |
| Claude の知識 | スキルに一般的な Rails・Bundler の知識を書かない。解説は作業のたびに出典付きで作らせる | スキルには、手順の順番・関門・止まる条件・提示と記録の型だけを書く（人間の前提） |
| 理由をたどる仕組み | 理由の正本はコミット（1 コミット 1 理由）、PR 本文はコミットへの索引、雛形に合わせず残す設定はその場所のコメントに理由。DEF・LOG.md・IMP はこのリポジトリ固有の上乗せ | 人間のチームには DEF や LOG がない。このリポジトリも人間のチームも、PR をマージコミットで取り込むので、コミットのハッシュが残る（人間に確かめた） |
| 2 層 | 汎用の核（`.claude/skills/rails-upgrade/`）と、リポジトリ固有の設定（`.claude/rails-upgrade-project.md`）。試すのはこのリポジトリだけ | チームへ持ち出す前提にする。汎用の核は、このリポジトリ以外では試されていない仮説のまま epic に入る（人間が同意） |
| 作業の一覧 | patch を外し、rails-lock と research に含める。record を pr にする | patch は一度も通していない。PR 本文を作る作業として pr にした |
| Step 2-b の道具 | `compare-config`（起動の途中の読み込みの書き出しを統合）・`check-console`・`verify-gem-checksums`・`commit-per-app` を `scripts/` に入れる | Step 2-b のコードレビューで、この PR で決めるとした。関門と関門の間の決まった作業は、AI が止まらずに進める |
| CI から `check-apps` を呼ぶか | 呼ばない。`check-apps` の冒頭のコメントに、検査を足すときは ci.yml にも足すと書く | CI に mise がない、CI はステップごとに結果が画面に出る、CI だけの違い（署名鍵、bundler-audit の `--update`）がある |
| Rails に共通の道具の置き場所 | この PR では `scripts/` | このリポジトリで試す。チームへ持ち出すときに、汎用の核へ移すかを決める |

### 作業計画からの変更点

- スキルの試行（下の「スキルを試した結果」）の `pr` で、PR 本文の型を 3 か所直した（変更の一覧の 1 行の単位、記録だけのコミットの本文、追随の置き場所）
- スキルの試行（下の「スキルを試した結果」）で、スキル自身が 2 つの穴を挙げた。人間の承認を得て、記録の Step の節を research の出口で作り、各作業の出口で結果を足していく形にした（それまでは、作業ごとの結果をセッションの中の「記録の下書き」に控え、pr でまとめる形だった）。あわせて、PLAN.md のチェックリストの項目の先頭に作業名を付けることにし、この PR のチェックリストにも verify と pr の項目を足した

### スクリプトの確かめ方と結果

過去の Step の結果を再現できることを確かめてから、1 つずつコミットした。Step 1 は、タグ `rails-6.1-prepared` の後のコミットを scratchpad の worktree に出して再現した（各アプリの `vendor/bundle` は本体へのシンボリックリンク、mise にはコマンドにだけ `MISE_TRUSTED_CONFIG_PATHS` を付けた。OP の署名鍵は worktree の中の使い捨て）。Ruby 3.1.7（Bundler 2.3.27）と、Step 1 の lock の gem はすべて手元にあり、gem・Ruby のダウンロードはなかった。

| スクリプト | 確かめたこと |
|---|---|
| `scripts/compare-config` | Step 1 のグループ 8 の後（`89fb290`）と `load_defaults 7.0` の後（`400ed9c`）で、違うのは DEF-7.0-24（`ActionDispatch::Request.return_only_media_type_on_content_type`）の RP の test・development と OP の development だけ（記録と同じ。設定ファイルの値は前後とも同じで、クラスの値だけが違う）。Step 2-b の doorkeeper-openid_connect 1.10.5 の前後（`ac5b6fb`）で、違うのは `Doorkeeper::AccessGrant`（と `Doorkeeper::OpenidConnect::Request`）が起動の時点で読み込まれなくなったことだけ（記録と同じ）。今の 3 アプリで 2 回書き出して同じ |
| `scripts/resolve-lock` | タグの 3 アプリで Rails 7.0.10 を解決させると、Bundler が zeitwerk（RP・OP は annotate も）を挙げて止まり、外すと、動くのは Rails の構成 gem・zeitwerk 2.6.18・annotate 3.2.0、増えるのは benchmark・securerandom・drb・mutex_m（default gem と同じ名前として版が出る）、消えるのは sprockets 系（Step 1 と同じ）。Step 1 の一時固定の版を `--pin` で渡し、TIPS.md の続き（lock を持ち込み、Gemfile の rails を変えて `bundle lock`）を流すと、3 アプリの Gemfile と lock が `fb67546`・`a6e2bdf`・`8715abf` と同じ。今の epic で流すと、何も動かない |
| `scripts/restore-app-config` | `7e256b9` で 3 アプリに `yes a \| bin/rails app:update` → このスクリプトを流すと、`e363c55`・`8ca0c8c`・`8be19a1` のそのアプリのファイルと同じ（RP の `config/application.rb` の末尾の serializer の 3 行も戻る）。雛形から deprecation の行を消すと、項目を出して終了コード 1。今の epic で流すと、何も変えない |
| `scripts/check-console` | 3 アプリの development で、reline 0.6.0・irb 1.6.2・io-console 0.6.0・`IRB::RelineInputMethod`、Tab で `Rails.version` に補完、複数行の入力が `=> 42`（Step 2-b の記録と同じ）。`bin/rails runner` の中の byebug に `next`・`continue` を送れる。すぐに終わるコマンドでは終了コード 1 |
| `scripts/verify-gem-checksums` | 3 アプリの `ruby/3.2.0/cache` の `.gem` 379 個（重複を除いて 184 個）が、すべて rubygems.org の値と同じ。`--changed 467f288` で、Step 2-b で落とした gem だけを照合する（io-console は default gem を使ったので、キャッシュにないと出る） |
| `scripts/commit-per-app` | 使い捨てのブランチの worktree で、RP の変更を退避して RS をコミットできた（検査は 11 runs・E2E 10 passed）。RP の RuboCop の指摘ではコミットせず、ホームのパスを含むメッセージでは commit-msg の hook に止められてステージを外し、どちらも退避した OP の変更が戻った。ステージ済みの変更があると止まる。終わった後に worktree とブランチを消した |

### スキルを試した結果

人間が新しいセッションを Plan モードで開き、`/rails-upgrade` を試した。

- 引数なし（resume）: スキル化の途中で、チェックリストの残りが「スキルを試す」だけであること、前の Step の PR（#27）の取り込みと記録へのリンクのコミット（`2da733e`）を読み取り、次の作業を verify → pr とした。ファイルは変えずに止まった。取り込んだ後の次の Step は示さなかった（resume.md にそう書いていなかった）
- スキル自身が、2 つの穴を挙げた。①チェックリストの項目（「スキルを試す」）とスキルの作業名が結びつかず、作業を推測した ②pr の入口の条件「verify が終わっている」を、Step の途中で記録から判断する手がかりがない。上の「作業計画からの変更点」のとおりに直した。resume.md には、Step の最後の作業なら、取り込んだ後の次の Step も示すことを足した
- `pr`（Step 2-b の練習）: 「マージ済みの Step 2-b（PR #27）に当てて、PR 本文の下書きだけをチャットに出す。ファイルの変更・コミット・`/code-review`・CI の確認はしない」と添えて試した。下書きは templates.md の「PR 本文」の 6 つの節がそろい、実際の PR #27 の本文にある内容（版の表、GHSA の扱い、DEF-7.0-48〜50、業務的な挙動の変化なし、検査の件数、前後の比較、手動確認、見送ったこと）はすべて入っていた。PR #27 になかった「変更の一覧（コミットへの索引）」と「レビュアーに見てほしい所」が足され、見てほしい所の先頭は、OP の応答に関わる唯一の変更（doorkeeper-openid_connect）だった。下書きの言い回しのうち、LOG.md にないもの（zeitwerk の `nsfile`、initializer の `resource_owner_or_nil`）は、どちらもコミットメッセージにあった。ファイルは変えず、安全チェックを通し、最後に理解の関門として、レビュアーが聞きそうな「なぜ」を 3 つ挙げた
- `pr` の試行で、型の穴が 3 つ分かった。①変更の一覧をコミットごとに 1 行にすると 28 行になり、15 行は 3 アプリで同じ内容、10 行は記録・計画だけのコミットだった ②記録だけのコミット 10 個のうち 9 個に本文がなく、下書きは「なぜ」を差分と LOG.md から組み立て直した ③追随（A）が変更の一覧の行に埋もれ、PR #27 にあった「既定値・雛形への追随」の節にあたるものがない。人間の承認を得て、①変更の一覧は理由 1 つにつき 1 行（アプリごとのコミットはハッシュを並べ、記録・計画だけのコミットは最後の 1 行）②記録・計画だけのコミットも本文に何のための記録かを書く ③「業務的な挙動の変化」の節に、変わったが業務的な挙動ではないもの（追随）を並べる、に直した（templates.md・commit.md・pr.md）

### 遭遇した問題

1. `compare-config` の最初の版は、`ActiveJob::Base.queue_adapter` の inspect にプロセス ID が入り、2 回の書き出しが毎回違った。単純な型（文字列・数値・配列・ハッシュ・クラスなど）でない値は、クラス名だけを出すようにした
2. `compare-config` の関連の `inverse_of` の節は、読み込み済みのモデルしか見ないので、Step 2-b の確かめで、gem のモデルの読み込みの変化が「関連が消えた」ように見えた。アプリのモデル（`Rails.root` の下）だけを見るようにした（gem のモデルの読み込みの変化は「読み込み済みのモデル」の行に出る）
3. `restore-app-config` が、`git show` の出力を環境の既定の文字コード（US-ASCII）で読み、日本語のコメントで `ArgumentError`（invalid byte sequence）になった。UTF-8 として読むようにした
4. `verify-gem-checksums` の最初の版は、ruby 版の gem のときに API にプラットフォームを渡さず、java 版などのある gem（puma・json・nio4r・racc・date など。3 アプリで 27 個）が不一致に見えた。常に `platform=` を渡すようにした（Step 2 のコードレビューと同じ渡し方。TIPS.md の「gem の更新」に書いた）
5. Rails 7.1 では `ActiveSupport::Deprecation` をシングルトンとして使うこと自体が非推奨になり、test 環境の `:raise` で止まりうる。Step 3 で使うので、`compare-config` は `Rails.application.deprecators` があればそちらで警告を止める（Rails 7.1 では試していない）
6. 手元の Claude Code の CLI は 2.1.195 で、スキルを検査する `claude plugin validate .claude/skills`（2.1.233 以上）を使えなかった。frontmatter を Ruby の YAML で読み、`name` とディレクトリ名、SKILL.md の行数、リンク、「設定の◯◯」の見出し、指している TIPS.md・CLAUDE.md の節を、scratchpad のスクリプトで照合した

### 確認結果

- `scripts/check-apps`（3 アプリと E2E）: スキルを作った後に流し、36 の検査がすべて通った。minitest は RS 11 runs・RP 33 runs・OP 69 runs、0 failures（`CI=1` でも同じ）、E2E は 10 passed（Step 2-b と同じ）
- 手動確認用の環境: 作業の開始時に 9 ファイルのハッシュを控え、件数が Step 2-b の手動確認の後と同じこと（OP `oauth_access_grants` 19・`oauth_access_tokens` 47、RP `sessions` 12・`op_users` 1）を確かめた。スクリプトを確かめた後に、ハッシュが作業の開始時と同じだった
- verify（スキルを試して直した後）: アプリのディレクトリ・`e2e/`・`.github/` は epic と差分がない（アプリのコードと lock は変えていない）。`scripts/check-apps` の 36 の検査がすべて通り、件数は上と同じ。`bin/rails c` は `scripts/check-console` で 3 アプリとも起動し（上の「スクリプトの確かめ方と結果」）、`bin/rails s` は E2E で起動した。手動確認用の環境の 9 ファイルのハッシュは作業の開始時と同じ。追跡中の全ファイルと、この PR の 15 コミットのメッセージが、公開物の安全チェックを通った。ブラウザでの手動確認は、アプリを変えていないので行っていない
- 再現に使った scratchpad の worktree（タグ `rails-6.1-prepared` の後と、Step 2-b の前後）は消した。各アプリの `vendor/bundle` は本体へのリンクだったので、本体の gem は残っている

### コードレビュー（`/code-review`）

| 指摘 | 対応 |
|---|---|
| `compare-config` の出力先は既定で固定のディレクトリで、dump が同じラベルのディレクトリを空にしないので、アプリを絞って取り直すと、ほかのアプリの前の書き出しが残って diff に混ざる（冒頭のコメントの「なければ一時ディレクトリ」とも食い違う） | dump の始めに同じラベルのディレクトリを消すようにし、`/` を含むラベルを断るようにした。コメントを直した。3 アプリで取った後に OP だけを取り直すと、RS は「片方の書き出しがない」になることを確かめた |
| `compare-config` が arity 0 のメソッドしか読まないので、`delegate` などで引数が `(...)` になった読み出し（arity -1）は黙って飛ばされ、設定が効かなくなっても「同じ」に見えうる | 引数なしで呼べるもの（arity 0 と -1）を読むようにした。Step 1 と Step 2-b の再現（違うのは DEF-7.0-24 だけ、`Doorkeeper::AccessGrant` の読み込みだけ）と、今の 3 アプリで 2 回同じになることを確かめ直した |
| `check-console` は `CONSOLE_STEPS` を渡すと、子プロセスが落ちても終了コード 0 になる | 終了の状態が 0 でなければ終了コード 1 にした。`exit 3` で終わるコマンドで 1 になること、byebug で 0 になることを確かめた |
| 擬似端末のドライバーが、出力の末尾 200 バイトに `>` があればプロンプトとみなすので、起動の途中の出力（`=>` など）で、irb の準備の前に入力を送りうる | 端末の制御文字を除いた出力の末尾が `>` か `(byebug)` で終わるまで待つようにした。3 アプリで Step 2-b の記録と同じ表示になることを確かめ直した |
| `restore-app-config` が、HEAD にあって新しい雛形にない filter_parameters の要素をすべて戻すので、雛形が消した要素も独自の設定として戻してしまう | 戻すのを、スクリプトの一覧（`:code`）にある要素だけにし、ほかの要素は「雛形で消えた要素」として知らせるようにした。雛形から `:ssn` を消すと、戻さずに知らせることと、Step 1 の 3 アプリの再現を確かめ直した |
| `restore-app-config` が `config/application.rb` の最後の `end` の後の行を `split(/^end\n/)` で取るので、末尾に改行のないファイルでは、ほとんど全体を末尾に足しうる | 最後の `end` の行の位置から取るようにした |
| `resolve-lock` が、同じ gem の最初の行だけを固定するので、プラットフォームやグループごとに書いた 2 行目以降が固定されない | どの行も固定するようにした（このリポジトリの Gemfile に該当の行はない） |
| `resolve-lock` に `--gem rails='>= 7.0.10, < 7.1'` のようにカンマを含む要件を渡すと、1 つの文字列として Gemfile に書かれ、Bundler が読めない | 要件を分けて書くようにした。今の OP で解決できることを確かめた |
| `resolve-lock` は Gemfile のコピーで解決するので、Gemfile の場所からの相対パスの参照（`gemspec`、`eval_gemfile`、`ruby file:`、`path:`）が壊れる | 該当の行があれば、lock を読む前に行を出して止まるようにした（このリポジトリの Gemfile にはない）。`gemspec` を足した Gemfile のコピーで、終了コード 1 になることを確かめた。Step 1 の 3 アプリの lock の再現を確かめ直した |
| この PR で足した決まり（チェックリストの項目の先頭に作業名）に、この PR の「スキル化」のチェックリストのスクリプトとスキルの行が従っていない | 直さない。スキル化は、スキルの作業（gems・ruby など）の外で行った Step で、当てはまる作業名がない。作業名のある verify と pr の項目には付けた |

コードレビューの後に、`scripts/check-apps`（3 アプリと E2E）の 36 の検査がすべて通り（件数は上と同じ）、手動確認用の環境の 9 ファイルのハッシュが作業の開始時と同じことを確かめた。作り直した worktree は、確かめた後で消した。

## Step 3: Rails 7.1（2026-10-11）

- ブランチ / PR: `upgrade/step3-rails71` / [#29](https://github.com/thinkAmi-sandbox/oidc_op_rp-sample/pull/29)
- バージョン: Ruby 3.2.11（変更なし）/ Rails 7.0.10 → 7.1.6
- `/rails-upgrade` のスキルを実際の作業に使う最初の Step。スキルの手順・型・設定で、足りない・合わない・迷ったところは、作業を止めずに控えて、この節の最後の「スキルについて気づいたこと」に書く（スキルを直すかは人間が判断する）

### 作業計画で決めたこと

`/rails-upgrade research` で、Plan モードで調べた（サブエージェント 2 つ: アプリと gem のコードの Rails 7.1 への影響、Rails 7.1 と周辺 gem の一次の出典）。lock の解決は、scratchpad の lock のコピーに `scripts/resolve-lock`・`bundle lock --print` をかけて試した。作業計画を出し、論点を 1 つずつ人間と確かめてから承認を得た。調べたことの一覧と決めたことの全体は、PLAN.md の 6 章の「Step 3: Rails 7.1」に移した。

| 論点 | 決めたこと | 理由 |
|---|---|---|
| brakeman 8.1.0 の時期 | Step 3 の最初に上げる。公開から 2 週間の決まりの例外 | 計画では「Step 3 の最初」だったが、着手の日に公開から 10 日目だった。8.1.1 も advisory も出ておらず、先送りしても 2 週間たつ日（10-15）より前に次の Step に着手する見込みが高い（人間が判断） |
| secret_key_base のファイル | rails-lock で各アプリを 7.1 で初めて起動する前に、`tmp/development_secret.txt` を `tmp/local_secret.txt` にコピーする（元は残す）。TIPS.md の守るファイルを 12 にする | Rails 7.1 は `tmp/local_secret.txt` だけを読む（rails/rails#48471。ガイドへの追記は #52083）。コピーなら手動確認用の環境を作り直さず、7.0 以前のブランチでも同じ鍵で動く。人間が根拠（PR とガイドの節）を確かめてから同意した |
| connection_pool | 2.5.5 に一時固定し、Step 5 で見直す | 3.0 はキーワード引数だけで、Rails 7.1.6 の Redis・Memcache のキャッシュストアと合わない（rails/rails#56291）。Rails 7.2 も `< 3` に固定した（#56620） |
| 直接の gem の方針 | Ruby が対応していて特に不具合がなければ、Gemfile に書いた直接の gem は、上げられる時点で最新版に上げる。間接の gem は対象外 | 人間の方針。jwt 3.x の時期を確かめる中で出た。間接の gem は Rails や直接の gem の要件で動き、default gem に合わせた固定は意図したもの（人間が範囲を決めた） |
| jwt | Step 3 で 3.3.0（Rails を上げる前） | 方針による。当初の見立て（Step 3 では上げない）は取り下げた。3.0〜3.3 の破壊的な変更は、このリポジトリの使い方に当たらない見込み。gems の手順 1 で、RP の `my_op.rb` のオプションでの検証の効き方を gem のソースで確かめる |
| puma | Step 3 で 8.0.2（7.x は経由しない） | 方針による。advisory 2 件（CVE-2026-47736・47737）が解消する。7.0・8.0 の破壊的な変更のうち、効くのは keep-alive の既定値と応答ヘッダー名の小文字化だけ |
| omniauth-rails_csrf_protection | Step 3 で 2.0.1（7 章の「Step 7」を前倒し） | 方針による。Rails 8.1 未満では 1.0.2 と同じ処理 |
| doorkeeper-openid_connect 2.0.0 | Step 3 に入れず、直後のサブステップ 3-b で、意図的な仕様変更として扱う | マイグレーション（#243）と discovery の応答の変化（#333）があり、方針の「特に不具合がない」に当たらない |
| 手動確認の時期 | verify で 1 回。途中で前の Cookie やセッションに影響する変化が見つかったら、止まって相談し直す | 前の Cookie を読めなくする変更がない見込み（secret はコピー、`message_serializer` は古い形式も読める） |

順番は、PLAN.md の Step 3 のチェックリストのとおり（brakeman → jwt → puma → omniauth-rails_csrf_protection → Rails 7.1.6 → activerecord-session_store → rack-mini-profiler → `app:update` → RP の `autoload_lib_once` → `new_framework_defaults_7_1.rb` → `load_defaults 7.1`）。

### 作業計画からの変更点

| 変更 | 理由 |
|---|---|
| RS の jwt は 2.10.3 のまま（作業計画は「3 アプリ」） | RS の jwt は oauth2 の依存（間接の gem）で、直接の gem の方針の対象外だった。RS のコミットの前に気づき、人間に確かめた（PLAN.md の Step 3 の「着手後に決めたこと」） |
| Rails 7.1.6 の lock の前に、E2E の起動で `db:drop` と `db:setup`（RS は `db:create`）を別のプロセスで流すようにした | 1 つのプロセスで流すと、作り直した DB にスキーマが入らなかった（下の「遭遇した問題」。人間が判断） |
| activerecord-session_store 2.3.0 を、Rails 7.1.6 の直後ではなく同じコミットで上げた | 2.2.0 のままだと、Rails 7.1 でセッション Cookie から `SameSite=Lax` が消える（DEF-7.1-06。人間が判断） |
| `new_framework_defaults_7_1.rb` のグループ 5（`sanitizer_vendor`）をなくし、`log_file_size` とあわせて `load_defaults 7.1` に任せた | `sanitizer_vendor` の行は initializer の時点で `NameError` になり、`log_file_size` は initializer では効かない（下の「`new_framework_defaults_7_1.rb` を有効にした順番」。人間が判断） |
| `load_defaults 7.1` のコミットで、`backtrace_silencers.rb` に残す理由のコメントを足した | templates.md の「残す独自設定のコメント」に合わせた。7.0 のときはコミットメッセージにだけ書いていた（人間が承認） |
| verify の手動確認で、手動確認用の環境の守るファイルを 14 にした | Rails 7.1 で development の DB が WAL になり、RS の DB にテーブルができた（DEF-7.1-47・48。人間が判断） |

### 手動確認用の環境

作業の開始時（ブランチを切った後）に、9 ファイルのハッシュを控えた。件数は Step 2-b の手動確認の後と同じ（OP `oauth_access_grants` 19・`oauth_access_tokens` 47、RP `sessions` 12・`op_users` 1）。スキル化の PR では手動確認をしていないので、基準は Step 2-b の手動確認の後のまま。

- rails-lock で、人間に確かめて 3 アプリの `tmp/development_secret.txt` を `tmp/local_secret.txt` にコピーし、守るファイルを 12 にした（コピーの直後にハッシュを控え、元の 9 ファイルのハッシュが変わっていないことを確かめた）
- rails-defaults の後（`3d85c46` の時点）に、12 ファイルのハッシュが作業の開始時（`local_secret.txt` はコピーの直後）と同じことを確かめた。ハッシュの控えはセッションの scratchpad にしかないので、次のセッションは、始めた時点のハッシュをこの時点の続きとして控え直す
- rails-load-defaults の始め（`e539059` の時点）に 12 ファイルのハッシュを控え直し、`load_defaults 7.1` のコミット（各アプリの E2E を含む）の後も同じことを確かめた
- verify の手動確認の直前にも 12 ファイルのハッシュと件数が同じことを確かめた。手動確認で 3 アプリの development DB が初めて Rails 7.1 で開かれ、3 つの DB のハッシュが変わった（RS は DEF-7.1-47 のテーブル、3 つとも DEF-7.1-48 の WAL）。OP・RP には `-wal`・`-shm` が残った。守るファイルに OP・RP の `-wal` を足して 14 にし、手動確認の後のハッシュを新しい基準にした（人間が判断。TIPS.md）

### gem ごとの対応

| gem | バージョン | 対応 |
|---|---|---|
| brakeman | 8.0.6 → 8.1.0 | 3 アプリ。`bundle update brakeman --conservative`。lock で動いたのは brakeman だけ（racc は 1.5.2 のまま）。公開から 2 週間の決まりの例外（作業計画で人間が判断） |
| jwt | 2.10.3 → 3.3.0 | RP・OP。`bundle update jwt --conservative`。lock で動いたのは jwt だけ。上げる前に、RP の `my_op.rb` の `JWT.decode` まわりを `jwt-2.10.3/lib/jwt` と v3.3.0 のタグで比べた。`algorithm` のキー、鍵を探すブロックの呼び方、iss・aud・sub・exp・nbf の検証は同じで、`verify_iat` に渡していない leeway が増えただけ。変わったのは、構造の壊れたトークンと鍵がないときの例外クラスだけ（どちらも `JWT::DecodeError` のサブクラス）。既存のテストが nonce・kid・署名の鍵・iss・aud・exp の失敗の例外クラスを確かめているので、先に足すテストはなかった。RS は 2.10.3 のまま（下の「作業計画からの変更点」） |
| puma | 6.6.1 → 8.0.2 | 3 アプリ。Gemfile を `~> 6.0` → `~> 8.0` にして `bundle update puma --conservative`。lock で動いたのは puma だけ（nio4r は 2.5.9 のまま。C 拡張は 3 アプリでビルドした）。無視リストから CVE-2026-47736・47737 を消した。既定値の変化 3 つ（応答ヘッダー名の小文字化、keep-alive の既定値、既定の bind）を解説し、人間の返事を得て追随した（DEF-7.1-01〜03） |
| omniauth-rails_csrf_protection | 1.0.2 → 2.0.1 | RP。`bundle update omniauth-rails_csrf_protection --conservative`。lock で動いたのはこの gem だけ。入れた 1.0.2 と 2.0.1 の `token_verifier.rb` を比べ、Action Pack 8.1 未満の枝は 1.0.2 と同じ処理（`undef_method` に `defined?` の確かめが付いただけ）なことを確かめた。8.1 用の枝は Step 7 でもう一度確かめる |
| Rails | 7.0.10 → 7.1.6 | 3 アプリ（rails-lock）。7.0.10 は 7.0 系の最新なので、先に上げるパッチはなかった。`scripts/resolve-lock --gem 'rails=~> 7.1.6' --rails --unpin rails-dom-testing,erubi --pin cgi=0.3.7,irb=1.6.2,connection_pool=2.5.5,tsort=0.2.0` で解決した lock をアプリに持ち込み、Gemfile を `~> 7.1.6` にして `bundle lock`・`bundle install`。動いたのは Rails の構成 gem と rails-dom-testing 2.0.3 → 2.3.0・erubi 1.10.0 → 1.13.1。増えたのは cgi 0.3.7（RS・OP）・irb 1.6.2・tsort 0.2.0・connection_pool 2.5.5・rack-session 1.0.2・rackup 1.0.1・webrick 1.9.2（cgi・irb は default gem と同じ版で、落としていない）。作業計画に書いていなかった変化として、method_source 1.0.0 が lock から消えた（railties 7.0.10 の依存で、7.1.6 の依存にはない）。無視リストから CVE-2025-55193・CVE-2025-24293 を消し、残りのコメントの版を 7.1.6 に直した。7.1 で初めて起動する前に、人間に確かめて 3 アプリの `tmp/development_secret.txt` を `tmp/local_secret.txt` にコピーした（`cmp` で同じ中身。起動後の `Rails.application.secret_key_base` が元のファイルと同じことを確かめた） |
| activerecord-session_store | 2.2.0 → 2.3.0 | RP。Rails 7.1.6 と同じコミット（人間が判断）。Rails 7.1.6 だけでは、セッション Cookie の Set-Cookie から `SameSite=Lax` が消えた（DEF-7.1-06）。`bundle update activerecord-session_store --conservative` で、動いたのはこの gem だけ。generator の雛形は 2.2.0 と同じ |
| rack-mini-profiler | 4.0.1 → 5.0.0 | RP・OP。Gemfile を `~> 4.0` → `~> 5.0` にして `bundle update rack-mini-profiler --conservative`。lock で動いたのはこの gem だけ。generator の雛形は 4.0.1 と同じ。高度なデバッグ機能が development で既定で無効になった（DEF-7.1-09） |

- ダウンロードした `.gem` の SHA-256 は、すべて rubygems.org の値と同じ（`scripts/verify-gem-checksums <app> --changed <上げる前のコミット>`）

### `app:update` で採用したもの・戻したもの

3 アプリで `yes a | bin/rails app:update` を流し、`scripts/restore-app-config` で独自設定を戻してから、差分を人間が確かめた。項目ごとの解説は [defaults/rails-7.1.md](defaults/rails-7.1.md) の「`app:update` の雛形」。

| ファイル | 判断 | 理由 |
|---|---|---|
| `config/application.rb` の `config.autoload_lib` | RS・OP は採用、RP は採用しない | RS・OP の `lib` に読み込む Ruby のファイルはない。RP は `Omniauth::Strategies::MyOp` の `NameError` で `zeitwerk:check` が落ちるので、次のコミットで `autoload_lib_once` と inflector にした（DEF-7.1-10） |
| development・test・production の `enable_reloading` | 採用 | `cache_classes` と同じ設定（DEF-7.1-11） |
| development・test の `raise_on_missing_callback_actions` | 採用 | `only:`・`except:` を使っていない（DEF-7.1-12） |
| test の `show_exceptions = :rescuable` | 採用 | 非推奨の `false` がなくなる。例外を期待するテストはない（DEF-7.1-13） |
| development の `verbose_enqueue_logs` | 採用 | ジョブを使っていない（DEF-7.1-14） |
| production.rb | 採用 | 雛形に追従するだけ（DEF-7.1-15） |
| コメント、`bin/setup` | 採用 | DEF-7.1-16・17 |
| test の `deprecation = :raise`、`filter_parameter_logging.rb` の `:code` とコメント | 戻した | アプリの独自設定（`scripts/restore-app-config`） |
| `active_storage:update` のマイグレーション 3 本 | 採用しない | Active Storage を使っていない（DEF-7.1-18） |
| `new_framework_defaults_7_1.rb` | 足した（すべてコメント） | rails-defaults でグループごとに有効にする |

- RP の独自ストラテジー: `config/application.rb` に `config.autoload_lib_once(ignore: %w(assets tasks))` と `Rails.autoloaders.once.inflector.inflect("omniauth" => "OmniAuth")` を足し、`config/initializers/omniauth.rb` の `require` を消した（作業計画の案 B のまま）。once のローダーが `lib/omniauth/strategies/my_op.rb` を `OmniAuth::Strategies::MyOp` として扱い、main のローダーには `lib` がない（リロードしない）ことを確かめた
- 設定の値の比較（3 アプリの test・development）で変わったのは、DEF-7.1-12〜14 の値だけ。`autoload_lib_once` の前後では同じ。3 アプリの検査と E2E は、各コミットで通った

### `new_framework_defaults_7_1.rb` を有効にした順番

グループと順番は人間が決めた。各グループで、前後に `scripts/compare-config` で 3 アプリの test・development の値を書き出して比べ、すべての設定が新しい値になったことを確かめた（RP を含め、起動の途中の読み込みで効かない設定はなかった）。解説への返事の後に、アプリごとにコミットした。項目ごとの解説は [defaults/rails-7.1.md](defaults/rails-7.1.md) の「`load_defaults`（`new_framework_defaults_7_1.rb`）」。

| 順 | グループ | 設定 | 結果 |
|---|---|---|---|
| 1 | 使っていない機能 | 14 項目（暗号化、トランザクションのコールバック、関連の名前、`attr_readonly`、`serialize`、Marshal の形式、`has_secure_token`、BigDecimal のジョブの引数、キャッシュの有効期限、query log tags、`Parameters` の `==`） | 変わらない（DEF-7.1-19〜32） |
| 2 | DB の扱い | SQLite の文字列の厳しいモード、`belongs_to` の検証、トランザクションの `return` | 変わらない（DEF-7.1-33〜35） |
| 3 | テストだけ | `dom_testing_default_html_version` | テストの HTML の読み方だけ（DEF-7.1-36） |
| 4 | ログ | `precompile_filter_parameters`、`debug_exception_log_level` | 伏せる結果は同じ。ログのレベルの表示だけ（DEF-7.1-37・38） |
| 6 | 応答のヘッダー | `default_headers` | `X-Download-Options` がなくなる。スナップショットを作り直した（DEF-7.1-39） |
| 7 | Cookie・メッセージの形式 | `message_serializer`、`use_message_serializer_for_metadata` | OP のセッション Cookie の形式が変わる。7.1 は古い形式も読める（DEF-7.1-40・41） |

- グループ 1 で `action_text.sanitizer_vendor` を有効にすると、3 アプリとも `uninitialized constant Rails::HTML (NameError)` で起動しなかった。sprockets-rails を入れていないアプリでは、initializer の時点で rails-html-sanitizer が読み込まれていない（rails/rails#51246）。Rails 7.1.6 の `load_defaults 7.1` は `require "action_view/helpers"` してから値を決める（#51267）ので、2 つの `sanitizer_vendor` は `load_defaults 7.1` に任せた（人間が判断。グループ 5 はなくなった）
- グループ 4 の `log_file_size` は、initializer で有効にしても、ロガーが `initialize_logger` で先に作られているので、ログのファイルの上限は 1 MB のままだった。`load_defaults 7.1` に任せた（人間が判断）
- `compare-config` は、7.1 の設定のいくつかでクラスの値を書き出さなかったので、`scripts/lib/dump_config.rb` に 14 の値を足した（`2c74e3f`）。暗号化の `support_sha1_for_non_deterministic_encryption` は読み出す口がないので、previous の数で見た

### 非推奨警告と対応

| 警告 | 対応 |
|---|---|
| 3 アプリの `config/environments/test.rb` の `config.action_dispatch.show_exceptions = false`（Rails 7.1 で非推奨。例外が middleware まで届いたときだけ警告が出る） | `app:update` の雛形の `:rescuable` にした（DEF-7.1-13）。テストの出力に Rails 7.1 の DEPRECATION は出ていない。OP の `auth_time_from_resource_owner`（doorkeeper-openid_connect。IMP-011）は前からのもの |

### 意図的な仕様変更

なし。応答のスナップショット・E2E・verify の手動確認で、業務的な挙動の変化は見つからなかった。応答とファイルの変化はすべて既定値・雛形への追随として解説し、人間の返事を得た（[defaults/rails-7.1.md](defaults/rails-7.1.md) の DEF-7.1-01〜48）

### 前後の比較

上げる前（Step 3 の docs のコミットの後）に、次のものを書き出し、gem を上げるたびに取り直して比べる。
- `scripts/check-apps` の結果（3 アプリの検査と E2E）
- `scripts/compare-config dump`（3 アプリの test・development）
- `RUBYOPT=-W:deprecated` を付けた development の eager load の警告
- brakeman の JSON の出力

上げる前の値は次のとおり。
- minitest: RS 11 runs・RP 33 runs・OP 69 runs、0 failures（`CI=1` も同じ）
- E2E: 10 passed
- eager load の `warning:`・`DEPRECATION`: 3 アプリとも 0
- テストの出力の DEPRECATION: OP の `auth_time_from_resource_owner`（IMP-011）だけ

- brakeman 8.1.0
  - 3 アプリとも終了コード 0。JSON の出力の警告（0 件）と無視した警告（EOL の 2 件）の fingerprint・チェック名・メッセージ、実行したチェックの一覧は、8.0.6 と同じ
  - 設定の値と起動の途中の読み込み（`compare-config`）、eager load の警告、minitest・E2E の件数とスナップショット、テストの出力の DEPRECATION は、前と同じ
- jwt 3.3.0（RP・OP）
  - 3 アプリの lock を上げた状態で、3 アプリの検査と E2E がすべて通った。OP の ID トークン・JWKS・discovery の応答のスナップショットと、E2E の baseline（ID トークンのヘッダー・ペイロード、JWKS）に差分はない
  - 設定の値と起動の途中の読み込み、eager load の警告、テストの出力の DEPRECATION は、前と同じ
- puma 8.0.2
  - 3 アプリの検査と E2E がすべて通った。設定の値と起動の途中の読み込み、eager load の警告、テストの出力の DEPRECATION は、前と同じ。無視リストを空にした bundler-audit で、puma の 2 件が報告されなくなった
  - 応答のヘッダー: test 環境のアプリを `Puma::Server` に直接通し、RS の `/apples/show`（401）と OP の discovery（200）の生の応答を前後で比べた。ヘッダー名がすべて小文字になり、値と順番は同じ（DEF-7.1-01）。minitest の応答のスナップショットは puma を通らないので変わらない
  - puma の設定: 6.6.1 と 8.0.2 で `config/puma.rb` を読み込んだ後の値を比べた。`persistent_timeout` 20 → 65、`max_keep_alive` nil → 999、既定の bind が `0.0.0.0` → `[::]`。`bin/rails s` は host に localhost を渡すので、実際の bind は変わらない（DEF-7.1-02・03）
- omniauth-rails_csrf_protection 2.0.1
  - RP の検査（CSRF の失敗のテストを含む）と E2E が通った。設定の値と起動の途中の読み込み、eager load の警告は前と同じ
- Rails の前の 4 つの gem を上げた後、手動確認用の環境の 9 ファイルのハッシュは作業の開始時と同じ
- Rails 7.1.6（rails-lock）
  - 最初の検査で、RP 6 件・OP 11 件の応答のスナップショットの差分、bundler-audit（解消した 2 件が無視リストに残っていた）、E2E（下の「遭遇した問題」）が落ちた。RS の minitest、3 アプリの `zeitwerk:check`・起動の途中の読み込み・RuboCop・brakeman は通った
  - スナップショットの差分は、リダイレクトの本文がなくなったこと（RP 4 件・OP 11 件。DEF-7.1-04）、ルーティングの `redirect` の Content-Type に charset が付いたこと（RP 1 件。DEF-7.1-05）、RP のセッション Cookie から `SameSite=Lax` が消えたこと（RP 4 件。activerecord-session_store 2.3.0 で元に戻した。DEF-7.1-06）。解説して人間の返事を得てから、RP・OP のスナップショットを作り直した。作り直した差分は、この 3 つだけ
  - minitest の件数は同じで、assertion の数が RS 14 → 15・RP 69 → 71・OP 121 → 123 に増えた。activesupport 7.1 の `assert_nothing_raised` が `assert(true)` を数えるようになったため（`activesupport-7.1.6/lib/active_support/testing/assertions.rb`。3 アプリの `test/eager_load_test.rb` で 1 つずつ）。RP・OP のもう 1 つずつは、どの assertion かまで確かめていない
  - 書き換えた後に、3 アプリの検査と E2E がすべて通った。brakeman の無視した EOL の警告 2 件は、Rails 7.1.6 でも同じ fingerprint で当たる
  - development だけのヘッダー: rails-lock の前に書き出し（RS の `/apples/show`、RP のトップ、OP の discovery とログイン画面。E2E 用の DB で `Puma::Server` に通した）、rack-mini-profiler 5.0.0 の作業の始めに Rails 7.1.6 で取り直して比べた。RS の 401 が chunked から Content-Length 付きになり（DEF-7.1-07）、RP のトップの Server-Timing に `transaction.active_record` が増えた（DEF-7.1-08）。RP のトップと OP のログイン画面の Content-Length も変わったが、rack-mini-profiler が本文に入れる `data-ids` に前の要求の ID が積み上がるためで、Rails の版の違いではない。どちらも rails-lock のコミットの後に比べ、解説への返事もコミットの後にもらった
  - Rails 7.1 は SQLite を WAL で開く（rails/rails#49349）。手動確認用の development の DB は、まだ 7.1 で開いていない（journal mode は `delete` のまま）。verify の手動確認で開くと、DB のファイルが WAL になり、`-wal`・`-shm` のファイルができる見込み
- rack-mini-profiler 5.0.0（RP・OP）
  - Step 2-b で心配した、`Rails.env.local?` で development のプロファイラーが無効になることは起きない。Rails 7.1.6 の development では `Rails.env.local?` が true で、`authorization_mode` は `:allow_all` のまま
  - development の応答ヘッダー（`x-miniprofiler-*`、`__profilin` の Cookie）と、RP のトップのバッジの `<script>` の属性は前と同じ（gem の版のハッシュだけが変わった）。設定の値と起動の途中の読み込み、eager load の警告も前と同じ。RP・OP の検査と E2E が通った
- `load_defaults 7.1`（rails-load-defaults）
  - 3 アプリを `config.load_defaults 7.1` にし、`new_framework_defaults_7_1.rb` を消した。rails-defaults で一時的に足した設定はほかになかった
  - 前の書き出しを取る前に、`load_defaults 7.1` に任せた 5 つの設定のうち 3 つ（`add_autoload_paths_to_load_path`、`action_text.sanitizer_vendor`、`cache_format_version` が効く先の coder）の値を `compare-config` が拾えないと分かり、`scripts/lib/dump_config.rb` に足した（`269d6a0`）。足した後の書き出しを 2 回取り、同じだった
  - 設定の値（3 アプリの test・development）: 違うのは `load_defaults 7.1` に任せた 5 つの設定だけ（DEF-7.1-42〜46）で、6 つの書き出しで同じ違い。`new_framework_defaults_7_1.rb` で有効にしていた 22 の設定の値と、起動の途中に読み込み済みの部品は変わらない
  - 3 アプリの検査と E2E がすべて通った。minitest の件数と assertion の数（RS 11・15、RP 33・71、OP 69・123）と E2E（10 passed）は前と同じで、応答のスナップショットの差分はない。development の eager load の警告は前後とも 0
  - sanitizer を通るのは OP の `doorkeeper/applications/index.html.erb` の `simple_format` だけで、fixtures・手動確認用の DB の値（`sqlite3 -readonly` で読んだ）と改行・`&`・`<script>` を含む値で、HTML4 と HTML5 の出力が同じことを確かめた（DEF-7.1-45）
  - 7.1.6 の雛形の initializer は 7.0.10 と同じで、消すものはなかった。雛形にない `backtrace_silencers.rb` は残し、先頭に残す理由のコメントを足した（人間が承認。7.0 のときはコミットメッセージにだけ書いていた）
  - 解説（DEF-7.1-42〜46 と `backtrace_silencers.rb`）に人間の返事を得てから、記録（`173a321`）、RS `47a0dfc`・RP `52bafaa`・OP `7bca31e` の順にコミットした。RuboCop の `TargetRailsVersion` は 7.1 にして、3 アプリで新しい指摘がないことを確かめた（`c0853c8`）

### 手動確認

verify で、`.claude/launch.json` から 3 アプリを起動してブラウザペインで確かめた（操作は人間）。3 アプリとも Puma の起動の出力に Rails 7.1.6・Puma 8.0.2 が出た。

- 起動の直後に、RS の最初の要求で、手動確認用の RS の development DB に `schema_migrations` と `ar_internal_metadata` が作られた。止まって人間に確かめ、Rails 7.1 の未実行マイグレーションの検査の変化として受け入れた（DEF-7.1-47。下の「遭遇した問題」）
- ログイン（RP の my_op）: 人間が「Re Login」を押した。OP のログイン画面も同意画面も出ずに RP に戻った。前回の手動確認（Rails 7.0.10）で作った OP のセッション Cookie（Rails 7.0 の形式の暗号化 Cookie）を、Rails 7.1 の OP が読めた（DEF-7.1-41 の確かめ残し。secret_key_base は `tmp/local_secret.txt` にコピーしたもの）。OP のログは、認可エンドポイントが 302、トークン・userinfo・JWKS が 200。RP のセッションは、ログインで ID が入れ替わった
- introspection 用 RP: 前回のトークンは revoke 済みなので同意画面が出て、Authorize の後、RS は正しいトークンで 200、`_bad` を付けたトークンで 401、revoke（OP は 200）の後は 401。RS が受け取った introspect は `active: true`（キーの順は `iat, exp`、`exp - iat = 600`）→ `active: false` が 2 回。Step 2-b と同じ
- サーバーの出力: 3 アプリとも、エラー・warning・DEPRECATION の新しいものはない。RP の `/stylesheets/application.css` のルーティングのエラーは元からのもの
- 手動確認用の環境: 直前の件数は基準と同じ（OP `oauth_access_grants` 19・`oauth_access_tokens` 47、RP `sessions` 12・`op_users` 1）。手動確認で、OP の development DB は `oauth_access_grants` が 19 → 21 件、`oauth_access_tokens` が 47 → 52 件（my_op 1・introspection 用 1（revoke 済み）・RS のクライアントクレデンシャル 3）、RP の development DB は `sessions` が 12 件のまま（ID 24 の行が 25 に入れ替わった）。増えた行は `-wal` の中にある（サーバーを止めても本体に移らなかった）。署名鍵・`.env`・3 アプリの `tmp/development_secret.txt`・`tmp/local_secret.txt` は変わっていない。以降の基準は手動確認の後の 14 ファイルのハッシュ

### 遭遇した問題

| 問題 | 対応 |
|---|---|
| Rails 7.1.6 にすると、E2E のサーバーの起動を待つところで 120 秒のタイムアウトになった。OP はすべての要求に `ActiveRecord::PendingMigrationError` を返した（E2E 用の DB にテーブルがない）。`e2e/scripts/start-server.sh` は `bin/rails db:drop db:setup` を 1 つのプロセスで流していた | アプリの `tmp/` に作った確かめ用の DB で再現した。1 つのプロセスで `db:drop db:setup` を流すと最後に DB のファイルがなく、`db:setup` だけや、`db:drop` と `db:setup` を別のプロセスで流すとテーブルが入る。Rails 7.1 は SQLite を WAL で開き（rails/rails#49349。`activerecord-7.1.6/lib/active_record/connection_adapters/sqlite3_adapter.rb:733`）、`db:drop` が `-wal`・`-shm` も消す（#49435 の修正）。同じプロセスに残った接続との組み合わせが原因の見込みで、内部の経路までは確かめていない。人間に確かめ、Rails 7.1.6 の lock の前に、3 アプリの `db:drop` と `db:setup`（RS は `db:create`）を別のプロセスで流すようにした。Rails 7.0.10 のまま E2E が通ることを確かめてからコミットした |
| verify の手動確認で、RS を Rails 7.1 で起動すると、手動確認用の RS の development DB に `schema_migrations` と `ar_internal_metadata` が作られた。前の手動確認（Rails 7.0）では RS の DB は変わらなかった | 7.1 の `CheckPending` が `migration_context.open` を通り、`Migrator` の初期化で 2 つのテーブルを作るためと、`activerecord-7.1.6` と v7.0.10 のソースで確かめた。止まって人間に確かめ、追随として受け入れた（DEF-7.1-47）。元のファイルの写しがないので、手動確認の後のハッシュを新しい基準にした |
| 手動確認の後、サーバーを止めても OP・RP の `-wal` が残り、本体のファイルのコピーで数えると件数が増えていなかった。WAL になった RS の DB は、`-shm` がないと `sqlite3 -readonly` で開けなかった | Rails 7.1 は SQLite を WAL で開く（DEF-7.1-48）。件数は `-wal` を含めて読み取り専用で数え直した。人間に確かめ、DEF-7.1-48 を記録し、TIPS.md の守るファイルに `-wal` を足して、数え方を書いた |

### 確認結果

verify で、PLAN.md の 10 章の完了条件を確かめた。

- `scripts/check-apps`（3 アプリと E2E）: HEAD（`5eedf23`）で 36 の検査がすべて通った。各コミットの前には、そのアプリと E2E で流した
- minitest: RS 11 runs・15 assertions、RP 33・71、OP 69・123、0 failures。`CI=1`（eager load あり）でも同じ
- E2E: 10 passed。スナップショットの差分なし。E2E の起動で、E2E 用の DB を `db:drop` → `db:setup`（RS は `db:create`）で毎回作り直している
- RuboCop（`TargetRailsVersion: 7.1`）・`zeitwerk:check`・起動の途中の読み込みの検査（test・`CI=1`・development）・bundler-audit（無視リストに解消済みの ID がないかも）・brakeman: すべて通った（`check-apps` の項目）
- lock: Step 3 の始め（`d4a4a4a`）からの動きは「gem ごとの対応」のとおり。default gem に合わせた一時固定（json 2.6.3・bigdecimal 3.1.3・logger 1.5.3・base64 0.1.1・cgi 0.3.7・ostruct 0.5.5・reline 0.6.0・io-console 0.6.0 ほか）は動いておらず、Step 3 で固定した tsort 0.2.0・irb 1.6.2・connection_pool 2.5.5 は計画どおり
- `bin/rails c`: `scripts/check-console` で 3 アプリとも起動し、複数行の入力と Tab の補完が動いた（irb 1.6.2 は lock の版、reline 0.6.0）。`bin/rails s`: 手動確認で 3 アプリとも起動した
- 公開物の安全チェック: 各コミットの hooks で通った
- CI: push の後に確かめる（push は人間が行う）
- 手動確認用の環境: 上の「手動確認」

### コードレビュー（`/code-review`）

| 指摘 | 対応 |
|---|---|
| 手動確認用の環境で、WAL の development DB をファイルのハッシュで守る方法は壊れやすい（チェックポイントで `-wal` が本体に移って消える・縮む） | 直さない。手動確認用の development DB を開くのは手動確認のときだけで、ほかの検査は E2E 用の DB（`DATABASE_URL`）を使う。手動確認の後はハッシュを基準として取り直すので、手順の間でハッシュが変わるのは誰かが development DB を開いたときで、それを見つけるのが守る目的。中身の比較（`.dump`）は、`-shm` のない WAL の DB を読み取り専用で開けず、手順が複雑になる（人間が判断） |
| `e2e/scripts/start-server.sh` のコメントが、確かめていない原因（WAL）を事実として書いている | 直した。「見込み」の書き方にして、この節の「遭遇した問題」を指すようにした |
| `db:drop` と `db:setup` を別のプロセスに分けたのは、原因を突き止めないままの回避 | 直さない。原因の調査は Step 3 の範囲の外。リポジトリで同じプロセスで DB を消して作り直すのは、この起動スクリプトだけ（`git grep` で確かめた。ほかは過去の記録）。後の Step で同じ形の手順を足すときは、この節の「遭遇した問題」を見る（人間が判断） |
| DEF-7.1-47 の「E2E 用の RS の DB にも同じテーブルができる見込み」は、確かめられる事実になっている | 直した。`rails_resource_server/db/e2e.sqlite3` のコピーで 2 つのテーブルを確かめ、事実として書いた |

コードレビューの後も、`scripts/check-apps`（3 アプリと E2E）の 36 の検査がすべて通り、手動確認用の環境の 14 ファイルのハッシュが verify の手動確認の後と同じことを確かめた。

### スキルについて気づいたこと

research:

1. research の手順 4 は、設定の「作業ごとの参照」の research の行を指すが、その行には `--print` しかない。Rails のマイナーを上げる Step で使う `scripts/resolve-lock` は、rails-lock の行にしかない。research でも resolve-lock を使った
2. `resolve-lock` は、解決できないときにエラーに出た gem を `--unpin` に足して流し直す（7.1.6 では rails-dom-testing・erubi の 2 回）。zsh で引数を配列にせずに繰り返すと、`--unpin` の値が 1 語にならず「不明な引数」になった
3. advisory の確かめ方は、今の lock を無視リストなしで見る方法だけが書いてある。解決した lock（scratchpad）に `bundle-audit check <ディレクトリ>` をかけて、解消と増加を見る方法は書いていない。`--gemfile-lock` はアプリのディレクトリからの相対パスとして扱われた
4. PLAN.md が時期を「Step 3 の最初」と決めていた brakeman 8.1.0 が、着手の日にまだ 2 週間たっていなかった。計画で決めた時期と 2 週間の決まりが食い違ったときの扱いは、research に書いていない（今回は人間が例外とした）
5. research の手順 5（非推奨警告）は、今の版の警告しか確かめられない。新しい版の非推奨（`show_exceptions = false` など）は、ソースを読んで見込みを立てるしかない
6. 守るファイルが Rails の版で変わること（7.1 の `tmp/local_secret.txt`）を、research で確かめる項目がない
7. Plan モードで research を行ったが、`bundle-audit update` は advisory のデータベース（リポジトリの外）を書き換える
8. 「直接の gem は、上げられる時点で最新版に上げる」という方針が、research の対話で人間から出た。7 章の振り分けは「時期を決めた gem はその Step で」となっていて、今上げられるメジャーの更新を先送りしていた（jwt・puma・omniauth-rails_csrf_protection）。research の手順 3（周辺 gem の振り分け）は設定の「計画」を指すだけで、この方針を書く場所がない（今回は 7 章の冒頭に足した）
9. 「質問は 1 回に 1 論点」は、Plan モードの選択式の質問（AskUserQuestion）がフックで止められ、テキストで行った。論点が 9 つあり、計画の承認の前に 9 往復した。今回はそれでよかったが、論点が多いときの進め方（見立てに異論がなさそうなものをまとめて示すか）は書いていない
10. 設定の「手動確認用の環境」は「9 ファイル」としているが、指す先の TIPS.md の一覧には 6 ファイル（`tmp/development_secret.txt` の 3 つがない）しか書いていなかった。Step 3 の docs のコミットで、`development_secret.txt` と `local_secret.txt` を TIPS.md に足した

gems:

11. 作業計画の中の食い違い（jwt を「3 アプリ」としたことと、論点 4 の「直接の gem だけ」）を、research の出口でも gems の入口でも見つけられず、RS のコミットメッセージを書く段階で気づいた。gems の入口の条件に、上げる gem が作業計画の決まり（方針の範囲）に当たるかを確かめる手順がない

rails-lock:

12. `scripts/resolve-lock` の「消えた gem」は空だったが、アプリに持ち込んで `bundle lock` すると method_source が消えた。resolve-lock は旧 lock の gem をすべて Gemfile に `= 版` で書くので、新しい Rails が依存しなくなった gem も Gemfile の依存として残り、出力に出ない。持ち込んだ後の `git diff` で初めて分かった
13. rails-lock の手順は「lock の解決 → 照合 → アプリごとのコミット」だけで、次のものを想定していない
    - 新しい版で初めて起動する前の手動確認用の環境の操作（7.1 の `tmp/local_secret.txt`）
    - アプリの外の道具（E2E の起動）を直す変更が要ること
    - 新しい Rails を必要とする gem を、Rails と同じコミットで上げる判断（7 章の「Rails と同時か直後」の「同時」）。今回は、どれも「この手順にないことが要る」で止まって確かめた
14. 検査が落ちたときの最初の結果（スナップショットの差分が RP 6 件・OP 11 件、bundler-audit、E2E）を、どこまで調べてから止まるかの目安がない。今回は、原因を 3 種類に分けて全体を示し、1 論点ずつ確かめた
15. rails-lock の手順に、development だけのヘッダーを比べる手順がない（設定の「前後の比較」には「Rails を上げるとき: development だけのヘッダー」とある）。書き出しは取ったが、比べるのを後に回し、Rails 7.1.6 のコミットの後に差分（DEF-7.1-07・08）を見つけた。rails-lock の検査の後、コミットの前に比べる手順が要る

gems（Rails の直後）:

16. Claude Code の hooks の安全チェックは、`git commit` と同じコマンド行の `sed -n` も `--no-verify` として止める（TIPS.md の「コミット」に書いてあるとおり）。docs のコミットと、検査の結果を `sed -n` で読む行を 1 回の呼び出しにまとめて、止められた。コミットの手順（commit.md）にこの注意がなく、設定の「作業ごとの参照」からも TIPS.md の「コミット」を指していない

rails-defaults:

17. rails-defaults の手順は「設定が効いていないときは起動の途中の読み込みを疑う」としているが、`new_framework_defaults_*.rb` の雛形の行そのものが initializer では効かない・動かない場合（`log_file_size` はロガーの作られる時点、`sanitizer_vendor` は定数の読み込み）がある。どちらも `load_defaults` に任せる判断になったが、手順にこの選択肢がない
18. 書き出しの道具（`compare-config`）が、新しい版の設定のクラスの値を拾えるかは、版ごとに足す必要がある。rails-defaults の手順の最初に、新しい設定の値が書き出されるかを確かめる手順がない（今回はグループ 1 の比較で気づき、途中で足して基準を取り直した）

rails-load-defaults:

19. 18 と同じことが rails-load-defaults にもある。手順 1 は「前の書き出しを取る」だけで、`load_defaults` に任せた設定の値が書き出されるかを確かめる手順がない（今回は取る前に気づき、道具に足してから取った）
20. 手順 2 の `new_framework_defaults_*.rb` の削除を `git rm` で行うと、削除がステージされたまま残る。commit.md の注意のとおり外そうとしたが、消えたファイルは zsh のグロブ（`rails_*/...`）に当たらず、1 回目は外れていなかった。`scripts/commit-per-app` はアプリのディレクトリをステージするので、手順 2 はステージしない `rm` で足りる
21. 手順 3 は「消す initializer を決める」だけで、残す initializer（雛形にないファイル）に templates.md の「残す独自設定のコメント」を当てるかが書いていない。前の版（7.0）ではコメントを足していなかった。今回は解説の項目に入れて人間に確かめた

verify:

22. 手動確認の入口の条件は「手動確認用の環境が控えた状態と同じ」だが、新しい版で初めて開くことで手動確認用の環境が変わる（DB の形式、フレームワークが作るテーブル）ことを、手動確認の前に見込む手順がない。今回は、WAL は rails-lock で見込んでいたが、RS のテーブルは見込めず、起動した後に止まって確かめた。起動の前に DB の写しを取っておけば、元に戻す選択肢も残せた
23. 手動確認用の環境のハッシュで比べる方法は、SQLite が WAL になると、サーバーを止めた後も `-wal` が残り、`-shm` は読むだけで変わるので、そのままでは使えない。設定の「手動確認用の環境」は、DB の形式の変化を想定していない

## Step 3-b: doorkeeper-openid_connect 2.0.0（2026-10-11）

- ブランチ / PR: `upgrade/step3b-doorkeeper-oidc20` / [#30](https://github.com/thinkAmi-sandbox/oidc_op_rp-sample/pull/30)
- バージョン: Ruby 3.2.11（変更なし）/ Rails 7.1.6（変更なし）/ doorkeeper-openid_connect 1.10.5 → 2.0.0（OP）

### 作業計画で決めたこと

`/rails-upgrade research` で、Plan モードで調べた（gem の 1.10.5...2.0.0 の差分はサブエージェント 1 つ。要点は自分で gem のソースで確かめた）。lock は `bundle lock --print` で、書かずに試した。作業計画を出し、論点を 1 つずつ人間と確かめてから承認を得た。調べたことの一覧と決めたことの全体は、PLAN.md の 6 章の「Step 3-b」に書いた。

| 論点 | 決めたこと | 理由 |
|---|---|---|
| `post_logout_redirect_uris` のマイグレーション（#243） | 入れる。意図的な仕様変更（DB の列） | gem の CHANGELOG が「Migration required」と書いたアップグレードの手順で、境目 1（gem の雛形への追随）の側にあたる。コードは列がなくても動くが、その分岐は移行のためのもの。機能のコードは列がなくても読み込まれ、列は置き場所を足すだけなので、境目 5 の「使っていない機能を動かし始める」にはあたらない（人間が判断） |
| discovery の `authorization_response_iss_parameter_supported: false`（#333） | 意図的な仕様変更として受け入れる | 設定では消せない。値は OP の挙動のとおり（認可応答に `iss` を付けない）。RP・RS は discovery を読まない（人間が判断） |
| webfinger の `Content-Type` と `Access-Control-Allow-Origin: *`（#350） | 意図的な仕様変更として受け入れる | research で新しく見つかった。設定では戻せない。RP・RS・E2E は webfinger を呼ばない。公開の情報だけを返す応答（人間が判断） |
| 手動確認用の OP の development DB | verify の手動確認の直前に 1 回だけ migrate する。その前に本体と `-wal` を `rails_open_id_provider/tmp/manual_check_backup/` に写す。写しは PR が epic に入った後に、確かめてから消す | マイグレーションのファイルが入ると、development の OP は migrate するまで `PendingMigrationError` になる。Step 3 の「スキルについて気づいたこと」の 22 を踏まえ、元に戻す選択肢を残す（人間が判断） |

- コミットは OP だけで、gem を上げる → schema.rb を Rails 7.1 の形で書き出す → マイグレーションの順にする。schema.rb の書き出しの形の変化（`Schema[6.1]` → `Schema[7.1]` ほか）は research で新しく見つかった。マイグレーションと理由を分けるため、書き出すだけのコミットにする
- 応答のスナップショットと E2E の baseline は、gems の作業で実際の差分を示し、人間に確かめてから作り直す
- ダウンロード: doorkeeper-openid_connect 2.0.0（55,808 バイト、2026-09-22 公開）。人間が承認した

### 作業計画からの変更点

| 変更 | 理由 |
|---|---|
| マイグレーションの前に、annotate が `test/fixtures/users.yml` に足した注釈を、別のコミットにした（`04cafce`） | E2E 用の DB で `db:migrate` を流すと、annotate（`lib/tasks/auto_annotate_models.rake`、`'exclude_fixtures' => 'false'`）が users テーブルの注釈を `users.yml` に足した。`users.yml` は Step 0-d-2 で、OP の最後のマイグレーション（2021 年）より後に作ったので、初めて annotate が流れた。消しても `db:migrate` のたびに戻ってくるので、残して、マイグレーションとは理由を分けた（人間が判断） |
| gem を上げるコミットは、`scripts/commit-per-app` を使わず、同じ手順を手で行った | `commit-per-app` はステージ済みの変更があると止まり、アプリの外（`e2e/baseline/discovery.json`）をステージしない。RS・RP に変更がなく退避が要らないので、OP の検査と E2E を流してから、ファイルを指定してコミットした |

### 手動確認用の環境

作業の開始時（ブランチを切って最初のコミットの後）に、14 ファイルのハッシュを控えた。件数は Step 3 の手動確認の後と同じ（OP `oauth_access_grants` 21・`oauth_access_tokens` 52、RP `sessions` 12・`op_users` 1）。件数は、本体と `-wal` を scratchpad にコピーして数えた。

- gems の 3 つのコミットの後（`04e9396` の時点）も、14 ファイルのハッシュは作業の開始時と同じ。schema.rb の書き出しとマイグレーションは E2E 用の DB で行い、手動確認用の DB には触れていない
- verify の手動確認の直前に、3 アプリのサーバーが止まっていて、14 ファイルのハッシュと件数が作業の開始時と同じことを確かめた。OP の development DB の本体と `-wal` を `rails_open_id_provider/tmp/manual_check_backup/` に写し、写しのハッシュが元と同じこと、写しのコピーで件数が同じで `integrity_check` が ok なことを確かめた（写しは、PR が epic に入った後に、確かめてから消す）
- 人間に確かめてから、手動確認用の OP の development DB に `bin/rails db:migrate` を流した。annotate は「Model files unchanged.」で、schema.rb・`test/fixtures/users.yml` に差分はなく、`db:migrate:status` は up。`db:migrate` が閉じるときにチェックポイントが起き、`-wal` が 0 バイトになった（中身は本体に移った）。件数は同じ（`oauth_access_grants` 21・`oauth_access_tokens` 52）で、`oauth_applications` の 3 行の新しい列は NULL。ハッシュが変わったのは OP の DB の本体と `-wal` だけ

### gem ごとの対応

| gem | バージョン | 対応 |
|---|---|---|
| doorkeeper-openid_connect（OP） | 1.10.5 → 2.0.0 | `bundle update doorkeeper-openid_connect --conservative`。lock で動いたのはこの gem と依存の行（doorkeeper `< 6.0` → `< 7.0`）だけで、doorkeeper 5.9.9・一時固定・default gem は動いていない。落とした `.gem` は `scripts/verify-gem-checksums` で rubygems の SHA-256 と一致した。initializer（DEF-7.1-49）とロケール（DEF-7.1-50）を 2.0.0 の雛形に合わせた。initializer で OP が雛形から変えたところは、1.10.5 の雛形と比べても 2.0.0 の雛形と比べても同じ（足したのは雛形の 38 行だけ）（`8abc86d`） |

schema.rb とマイグレーション（OP）:

- `adf94ad`: `DATABASE_URL=sqlite3:db/e2e.sqlite3 bin/rails db:schema:dump` で、schema.rb を Rails 7.1 の形で書き出しただけのコミット（DEF-7.1-51）。research で test の DB のコピーから試しに書き出したものと同じ。今の schema.rb と新しい形の schema.rb を、それぞれ空の DB に `db:schema:load` で読み込み、`sqlite_master` の SQL が同じことを確かめた
- `04cafce`: annotate が `test/fixtures/users.yml` に足した注釈（上の「作業計画からの変更点」）
- `04e9396`: `rails generate doorkeeper:openid_connect:add_post_logout_redirect_uris` が作ったマイグレーションを、出力のまま入れた。前の doorkeeper-openid_connect のマイグレーション（`20210812142144`）と同じく `frozen_string_literal` はなく、RuboCop は `db/` を見ない。E2E 用の DB で `db:migrate` を流し、schema.rb の差分は列の行と版の日付だけ。`db:migrate:status` で up を確かめた。test の DB にも列ができた（`maintain_test_schema`）

### 意図的な仕様変更

PLAN.md の 6 章の「Step 3-b」の 3 つ。gems で、実際の差分を人間に示して確かめてから、応答のスナップショットと E2E の baseline を作り直した。

- discovery（`8abc86d`）: `discovery.txt`・`oauth_authorization_server.txt` の本文の `token_endpoint_auth_methods_supported` と `subject_types_supported` の間に `"authorization_response_iss_parameter_supported": false` の 1 行が増えた。E2E の `e2e/baseline/discovery.json` にも同じキーが増えた（キーは辞書順なので `authorization_endpoint` の次）。ほかの行は同じ
- webfinger（`8abc86d`）: `webfinger.txt` に `access-control-allow-origin: *` が増え、`content-type` が `application/json; charset=utf-8` → `application/jrd+json; charset=utf-8` になった（charset は Rails が付ける）。本文は同じ
- `post_logout_redirect_uris` の列（`04e9396`）: OP の `oauth_applications` に null 可の text の列が増えた。既にある行は NULL。応答のスナップショット（applications の画面を含む）は変わらない。手動確認用の DB は verify で migrate する

### 前後の比較

上げる前（Step 3-b の計画の docs のコミット `cc20ea8` の後）に、次のものを書き出し、各コミットの前に取り直して比べた。

- `scripts/check-apps` の結果（上げる前は 3 アプリの検査と E2E。36 項目すべて通った。RS 11・RP 33・OP 69 runs、0 failures（`CI=1` も同じ）、E2E 10 passed）
- `scripts/compare-config dump`（OP の test・development。RS・RP は変更がないので取っていない）
- `RUBYOPT=-W:deprecated` を付けた OP の development の eager load の警告（0 件）
- OP の brakeman の JSON の出力
- テストの出力の DEPRECATION（OP の `auth_time_from_resource_owner` だけ。IMP-011）

結果は次のとおり。

- doorkeeper-openid_connect 2.0.0: 上げた直後に OP の検査を流すと、minitest の応答のスナップショット 3 件（discovery・`oauth_authorization_server`・webfinger）と E2E の 1 件（discovery の baseline）だけが落ちた。ほかの 66 件と E2E の 9 件、RuboCop・`zeitwerk:check`・起動の途中の読み込み・bundler-audit・brakeman は通った。差分は上の「意図的な仕様変更」のとおりで、ほかの変化は混じっていない。OP の設定の値と起動の途中に読み込み済みの部品（initializer・ロケールを変えた後も）、eager load の警告、brakeman の警告と無視した警告・実行したチェック、テストの出力の DEPRECATION は前と同じ
- schema.rb の書き出し・注釈・マイグレーション: 各コミットの前に OP の検査と E2E が通った（OP 69 runs・0 failures、E2E 10 passed）。応答のスナップショットの差分はない

### 手動確認

verify で、マイグレーションを流した後に `.claude/launch.json` から 3 アプリを起動してブラウザペインで確かめた（操作は人間）。3 アプリとも Puma の起動の出力に Rails 7.1.6・Puma 8.0.2 が出た。OP は起動の後の最初の要求で未実行マイグレーションを調べ、エラーにならなかった。

- ログイン（RP の my_op）: 人間が「Re Login」を押した。OP のログイン画面も同意画面も出ずに RP に戻った。OP のログは、認可エンドポイントが 302、トークン・userinfo・JWKS が 200
- introspection 用 RP: 前回のトークンは revoke 済みなので同意画面が出て、Authorize の後、RS は正しいトークンで 200、`_bad` を付けたトークンで 401、revoke（OP は 200）の後は 401。RS が受け取った introspect は `active: true`（キーの順は `iat, exp`、`exp - iat = 600`）→ `active: false` が 2 回。Step 3 と同じ
- サーバーの出力: 3 アプリとも、エラー・warning・DEPRECATION の新しいものはない。RP の `/stylesheets/application.css` のルーティングのエラーは元からのもの
- 手動確認用の環境: 手動確認で、OP の development DB は `oauth_access_grants` が 21 → 23 件、`oauth_access_tokens` が 52 → 57 件（my_op 1・introspection 用 1（revoke 済み）・RS のクライアントクレデンシャル 3）、RP の development DB は `sessions` が 12 件のまま（ID 25 の行が 26 に入れ替わった）。`op_users` は 1 件のまま。OP・RP の DB の本体と `-wal` のハッシュが変わり、RS の DB・署名鍵・`.env`・3 アプリの `tmp/development_secret.txt`・`tmp/local_secret.txt` は変わっていない。以降の基準は手動確認の後の 14 ファイルのハッシュ

### 遭遇した問題

| 問題 | 対応 |
|---|---|
| E2E 用の DB で `db:migrate` を流すと、annotate が `test/fixtures/users.yml` に注釈を足した（research で見込めなかった） | 止まって人間に確かめ、注釈を残して別のコミットにした（上の「作業計画からの変更点」） |
| 手動確認用の OP の development DB に `db:migrate` を流すと、`-wal` が 0 バイトになった | `db:migrate` のプロセスが閉じるときにチェックポイントが起き、`-wal` の中身が本体に移ったと見ている（内部の経路までは確かめていない）。本体と `-wal` のコピーで件数が同じ（`oauth_access_grants` 21・`oauth_access_tokens` 52）で `integrity_check` が ok なことを確かめた。手動確認でサーバーを動かした後は、`-wal` がまた残った |

### 確認結果

verify で、PLAN.md の 10 章の完了条件を確かめた。

- `scripts/check-apps`（3 アプリと E2E）: HEAD（`5266ef9`）で 36 の検査がすべて通った。各コミットの前には、OP と E2E で流した
- minitest: RS 11 runs・15 assertions、RP 33・71、OP 69・123、0 failures。`CI=1`（eager load あり）でも同じ
- E2E: 10 passed。E2E の baseline の差分は、意図的な仕様変更の `discovery.json` だけ（作り直してコミットした）。E2E の起動で、E2E 用の DB を `db:drop` → `db:setup`（RS は `db:create`）で毎回作り直していて、新しい schema.rb から `post_logout_redirect_uris` の列ができる
- RuboCop・`zeitwerk:check`・起動の途中の読み込みの検査（test・`CI=1`・development）・bundler-audit（無視リストに解消済みの ID がないかも）・brakeman: すべて通った（`check-apps` の項目）。bundler-audit の無視リストは変わらない（この Step で解消した advisory はない）
- lock: epic（`522e5e9`）からの動きは、OP の doorkeeper-openid_connect 1.10.5 → 2.0.0 と依存の行だけ。default gem に合わせた一時固定と、Step 3 で固定した tsort・irb・connection_pool は動いていない
- `bin/rails c`: `scripts/check-console` で 3 アプリとも起動した。`bin/rails s`: 手動確認で 3 アプリとも起動した
- 公開物の安全チェック: 各コミットの hooks で通った
- CI: push の後に確かめる（push は人間が行う）
- 手動確認用の環境: 上の「手動確認用の環境」と「手動確認」

### コードレビュー（`/code-review`）

| 指摘 | 対応 |
|---|---|
| 注釈とマイグレーションのコミットのメッセージが、コミットの時点ではまだ行っていない verify の migrate を現在形で書いている（CLAUDE.md の「まだ存在しないものを現在形で書かない」） | 直した。push の前だったので、2 つのメッセージを予定と分かる形に書き直した（`8d1a987` → `04cafce`、`18d6f16` → `04e9396`。後に続く docs のコミットのハッシュも変わった）。ファイルの中身は書き直す前と同じ。この節のハッシュを新しいものに直した（人間が判断） |
| TIPS.md の「手動確認用の環境」に、OP の DB の写しと、migrate で `-wal` が空になることが書かれていない | 直した。TIPS.md に、写しの場所と消す時期（PR が epic に入った後に、人間に確かめてから。それまで `tmp/` を消さない）と、DB を正常に閉じた後に `-wal` が空になりうることを足した（人間が判断） |
| 新しいマイグレーションに `# frozen_string_literal: true` がない | 直さない。gem の generator の出力のまま入れると決めていて、前の doorkeeper-openid_connect のマイグレーション（`20210812142144`）とも同じ。既にあるマイグレーションの形はそろっておらず、RuboCop は `db/` を見ない。`db/` を RuboCop の対象にするときにまとめて見直す（人間が判断） |
| `post_logout_redirect_uris` の列を確かめる minitest がない（後の版の gem が列のないときの分岐を外したら、E2E の起動の失敗でしか気づけない） | 直さない。列を足したので、列のないときの分岐はもう通らない。列が NULL のアプリの保存は、E2E の起動の seeds（`Doorkeeper::Application.find_or_create_by!`）が gem の検証を通して行い、minitest は fixtures で読み込む。OP はこの列を読み書きせず、記録する OP の挙動がない。ログアウトの機能を作るときに、そこでテストを書く（人間が判断） |

コードレビューの後（書き直した後の HEAD）も、`scripts/check-apps`（3 アプリと E2E）の 36 の検査がすべて通り、手動確認用の環境の 14 ファイルのハッシュが verify の手動確認の後と同じことを確かめた。

### スキルについて気づいたこと

Step 3 と同じく、スキルの手順・型・設定で、足りない・合わない・迷ったところを控える（スキルを直すかは人間が判断する）。

research:

1. gem が求めるマイグレーションを流すと、アプリの道具（OP の annotate）が `db:migrate` の後に別のファイルを変えることを、research で見込めなかった。マイグレーションを流す作業は、ほかの作業より副作用（schema.rb の書き出しの形、annotate）が大きいが、research の手順に、マイグレーションの副作用を試す手順がない（schema.rb の書き出しの形は、DB のコピーから試して見つけた）

gems:

2. gems の手順は「gem を上げる」だけを想定していて、gem が求めるマイグレーション（generator を流す、DB を migrate する、schema.rb を書き出す）の手順と、どの DB で流すか（手動確認用の DB に触れない）が書いていない。今回は作業計画で決めた
3. `scripts/commit-per-app` は、アプリの外のファイル（E2E の baseline）を、アプリの変更と同じコミットに入れられない。応答の変化が E2E の baseline にも出る gem では、手で同じ手順を行うことになる。注釈だけのコミットのように、アプリの中の変更の一部だけをコミットするときも、退避を手で行った

## Step 4: Ruby 3.3（2026-10-12）

- ブランチ / PR: `upgrade/step4-ruby33` / [#31](https://github.com/thinkAmi-sandbox/oidc_op_rp-sample/pull/31)
- バージョン: Ruby 3.2.11 → 3.3.12 / Rails 7.1.6（変更なし）。Bundler 2.4.19 → 2.5.22（`BUNDLED WITH`）。lock の default gem を 3.3.12 の版に合わせ直した。erb の CVE-2026-41316 は default gem の erb 4.0.3.1 で解消した
- Ruby だけを上げる Step。既定値への追随（A）と業務的な挙動の変化（B）は、どちらも起きなかった（下の「前後の比較」）

### 作業計画で決めたこと

`/rails-upgrade research` で、Plan モードで調べた（サブエージェント 3 つ: Ruby 3.3 の事実、gem の対応、リポジトリの中の版の箇所。mise の入れ方、irb の依存、resolv を読む gem は自分で確かめた）。作業計画を出し、論点を 1 つずつ人間と確かめてから承認を得た。調べたことの一覧と決めたことの全体は、PLAN.md の 6 章の「Step 4」に書いた。lock の合わせ直しの試行は、Plan モードではファイルを書けないので、Ruby 3.3.12 を入れてから scratchpad のコピーで行う（Step 2 と同じ）。

| 論点 | 決めたこと | 理由 |
|---|---|---|
| 版 | 3.3.12 | 3.3 系の最新で最後のリリース（v3_3_13 のタグはない）。公開から 2 週間以上たち、erb の CVE-2026-41316 の修正版（erb 4.0.3.1）を含む |
| irb の合わせ直し | irb 1.13.1 にし、依存で増える rdoc・psych・stringio も 3.3.12 の default gem の版（6.6.3.1・5.1.2・3.1.1）に固定する | 8 章の 4 の方針どおり。落とさず、ビルドもしない。固定しないと最新の rdoc 8.1.0・psych 5.5.0・stringio 3.2.0 が入る。`rails c` の irb が 1.6.2 → 1.13.1 になるので、`scripts/check-console` で起動と入力を確かめる（人間が判断） |
| brakeman の無視リストの EOLRuby の項目 | 3 アプリとも、各アプリの Ruby を上げるコミットで消す | 3.3 は EOL でなくなり、無視の理由がなくなる。fingerprint は Ruby の版を含まないので、残すと 3.3 の EOL も黙って無視する（人間が判断） |
| resolv の CVE-2026-80212・80213 | Gemfile に足さず、記録だけにする（PLAN.md の 7 章の resolv の行） | research で新しく見つかった。3.2 の 0.2 系も 3.3 の 0.3.1 も対象で、Ruby を上げて増えるリスクではない。lock の gem で `Resolv` を使うのは bundler-audit と rubocop だけで、アプリの実行時には読まれない。Step 2 の erb と同じ扱い（人間が判断） |
| 手動確認 | 3 アプリの Ruby を上げた後（`TargetRubyVersion` の前）に 1 回。introspection の流れまで | Step 2 と同じ（人間が判断） |

- 上げないもの: rubocop・webmock（2 週間たった最新版が今の版）、simplecov 1.3（サブステップ 4-b）、faraday-net_http（Step 8）、connection_pool（Step 5）、reline（0.6.0 のまま。3.3.12 の default gem の 0.5.10 は byebug 13 の要件を満たさない）、mise（2026.5.10 のまま）
- ダウンロード: `ruby-3.3.12.tar.gz`（21,489,887 B、2026-07-16 公開）。作業計画で示し、入れる直前に改めて人間に確かめる

### 作業計画からの変更点

| 変更 | 理由 |
|---|---|
| RS で、前の版のキャッシュからコピーした `.gem` のうち、3.3.12 の default gem と同じ名前・版の 3 つ（benchmark 0.3.0・tsort 0.2.0・ruby2_keywords 0.0.5）を、`vendor/bundle/ruby/3.3.0` から消して入れ直した。RP・OP では、コピーするときに外した（OP は ruby2_keywords の `.gem` がなかったので 2 つ） | RS を入れた後、この 3 つが default gem ではなく `vendor/bundle` から読まれていた。Bundler は、キャッシュに `.gem` があると、同じ版の default gem があっても入れてそちらを読む。benchmark・tsort は 3.2.11 では本物の gem として入れていて、ruby2_keywords は Step 2 で意図せず落とした `.gem` が残っていた。版は同じで Ruby だけの gem なので挙動は変わらない見込みだが、CI（setup-ruby が新しく入れる）は同じ版の default gem を使い、手元と読む場所がずれるので、止まって人間に確かめた（人間が判断）。消したのは gitignore の対象の手元のファイルだけで、`3.2.0/cache` に元の `.gem` が残る。TIPS.md の「Ruby を上げる」に書いた |

- 追記（Step 4-b）: 「CI（setup-ruby が新しく入れる）は同じ版の default gem を使う」は、Bundler 2.4 までの振る舞いで、`BUNDLED WITH` 2.5.22 にした Step 4 からは誤りだった。Bundler 2.5.12 以上（rubygems/rubygems#7673）は、lock にある default gem と同じ版の gem も `vendor/bundle` に入れ、CI は Step 4 の PR から、これらを `vendor/bundle` から読んでいた。手元だけ default gem から読むずれを、Step 4-b で 3 アプリとも `vendor/bundle` に入れて直した（下の Step 4-b の「遭遇した問題」）

### 手動確認用の環境

作業の開始時（ブランチを切って最初のコミットの前）に、3 アプリのサーバーが止まっていることを確かめ、14 ファイルのハッシュを控えた（前のセッションの控えは残っていないので、これを Step 4 の基準にする）。件数は、本体と `-wal` を scratchpad にコピーして数え、Step 3-b の手動確認の後と同じだった（OP `oauth_access_grants` 23・`oauth_access_tokens` 57、RP `sessions` 12・`op_users` 1。どちらの DB も `integrity_check` は ok）。

- Step 3-b の verify で取った手動確認用の OP の development DB の写し（`rails_open_id_provider/tmp/manual_check_backup/`。migrate の前の本体と `-wal`）は、Step 3-b の PR が epic に入ったので、人間に確かめて消した。消した後も 14 ファイルのハッシュは控えと同じ。TIPS.md の項目は、写しの取り方と消す時期の一般の手順に書き直した
- ruby の作業の間（RS・RP・OP のコミットの前後）も、手動確認の直前まで、14 ファイルのハッシュは作業の開始時と同じ。書き出しと検査は、development でも E2E 用の DB（`DATABASE_URL=sqlite3:db/e2e.sqlite3`）を指した

### gem ごとの対応

| gem | バージョン | 対応 |
|---|---|---|
| （Ruby） | 3.2.11 → 3.3.12 | `mise install ruby@3.3.12`。ruby-build 20260924（最新のリリースと同じなので、mise は入れ直さなかった）がソースからビルドし、Homebrew の OpenSSL 3.5.0・libyaml 0.2.5 にリンクした。落としたのは `ruby-3.3.12.tar.gz`（21,489,887 B）だけ。入れた Ruby の default gem の版は、research で GitHub のタグから調べた版とすべて同じ。`ERB.version` は 4.0.3.1（CVE-2026-41316 の修正版）。`RUBY_PATCHLEVEL` は 206 |
| json / bigdecimal / logger / base64 / cgi / drb / mutex_m / io-console / irb / securerandom | 2.6.3 / 3.1.3 / 1.5.3 / 0.1.1 / 0.3.7 / 2.1.1 / 0.1.2 / 0.6.0 / 1.6.2 / 0.3.0 → 2.7.2 / 3.1.5 / 1.6.0 / 0.2.0 / 0.4.2 / 2.2.0 / 0.2.0 / 0.7.1 / 1.13.1 / 0.3.1 | 3.3.12 の default gem の版に合わせ直した（3 アプリ） |
| ostruct | 0.5.5 → 0.6.0 | 同上（OP） |
| rdoc / psych / stringio | （なし）→ 6.6.3.1 / 5.1.2 / 3.1.1 | irb 1.13.1 の依存で lock に増えた。3.3.12 の default gem の版に固定した（3 アプリ） |
| benchmark / tsort / ruby2_keywords | 0.3.0 / 0.2.0 / 0.0.5（変更なし） | 3.3.12 の default gem と同じ版 |
| reline | 0.6.0（変更なし） | 3.3.12 の default gem の 0.5.10 は、byebug 13 の `>= 0.6.0` を満たさない |

- lock の試行（scratchpad のコピー。Ruby 3.3.12・`BUNDLER_VERSION=2.5.22`）: Gemfile の `ruby` を変えて default gem を固定して `bundle lock` → 固定を外して `bundle lock --local` で、3 アプリとも動いたのは上の行と `RUBY VERSION`（`ruby 3.3.12p206`）・`BUNDLED WITH`（2.5.22）だけ。`PLATFORMS` は変わらず、Bundler 2.5 でも `CHECKSUMS` の節は増えない。この lock をアプリに持ち込んだ（アプリの Gemfile とコピーの Gemfile が同じことを `diff` で確かめた）
- gem の入れ直し: `3.2.0/cache` の `.gem` を `3.3.0/cache` にコピーし（上の 3 つを外した後は RS 125・RP 139・OP 181 個）、`BUNDLE_CACHE_PATH=vendor/bundle/ruby/3.3.0/cache mise exec -- bundle install --local --no-cache` で入れた。3 アプリとも `Fetching` の行はなく、キャッシュの `.gem` の数も増えていない。`scripts/verify-gem-checksums` で、キャッシュの `.gem` がすべて rubygems.org の SHA-256 と一致した。default gem と同じ版の gem はすべて default gem から読まれ、gem から読むのは reline 0.6.0 だけ
- C 拡張は Ruby 3.3 向けにビルドし直した（bootsnap・byebug・date・msgpack・nio4r・prism・puma・racc・websocket-driver、RP・OP は bindex、OP は bcrypt）。nokogiri・sqlite3 は arm64-darwin のプラットフォーム版の 3.3 のバイナリを使う
- brakeman の無視リスト: 3 アプリとも、EOLRuby の項目を消した（JSON を読んで項目を除き、書き戻した。差分は項目の削除だけ）。brakeman の結果は、警告 0、無視した警告は EOLRails の 1 件、使われない無視の項目は 0 件
- `TargetRubyVersion` を 3.3 にした（`bc1a335`）。3 アプリとも新しい指摘はない。RuboCop が読む値が 3.3 になることを `RuboCop::ConfigStore` で確かめた
- epic と比べて lock で動いたのは、上の行と `RUBY VERSION`・`BUNDLED WITH` だけ。一時固定の reline 0.6.0・connection_pool 2.5.5・faraday-net_http 3.0.2（RS・RP）、Gemfile の `ruby` 以外の行は動いていない

### 意図的な仕様変更

なし。既定値・雛形への追随（3 章の 2 の A）も、業務的な挙動の変化（B）も起きなかった（下の「前後の比較」）。defaults/ への記録はない

### 前後の比較

Ruby を上げる前（3.2.11。計画の docs のコミット `bfd0f4f` の後）に次のものを書き出し、各アプリを上げた後に取り直して比べた。

- `scripts/check-apps`: 3.2.11 で 36 の検査がすべて通った（RS 11・RP 33・OP 69 runs、0 failures。`CI=1` も同じ。E2E 10 passed）。各アプリを上げた後（`--app` とコミットの前の `commit-per-app`）も、件数は同じで、応答のスナップショットと E2E のスナップショットの差分はない
- `scripts/compare-config dump`（3 アプリ、test・development）: 3.2.11 で 2 回取って同じことを確かめた。上げた後の違いは、3 アプリの test・development とも、書き出しの道具が Rails 7.1 にない設定（`ActionDispatch::Request.return_only_media_type_on_content_type`）を読んだときの `NoMethodError` の文言だけ（`for ActionDispatch::Re…` → `for class ActionDispat…`。書き出しは値を途中で切る。Ruby 3.3 の NEWS の Feature #18285 で、メッセージが対象の `#inspect` を使わなくなった）。設定の値と起動の途中に読み込み済みの部品は同じ
- `RUBYOPT=-W:deprecated` を付けた minitest と development の eager load: 3.2.11 でも 3.3.12 でも、Ruby の `warning:` の行と bundled_gems の警告は 0 件。DEPRECATION は前後とも OP のテストの `auth_time_from_resource_owner`（IMP-011）だけ
- `scripts/check-console`（3 アプリの development）: 前は irb 1.6.2・io-console 0.6.0、後は irb 1.13.1・io-console 0.7.1（reline は 0.6.0 のまま）。前後とも、Tab の補完と複数行の入力ができ、終了の状態は 0
- brakeman の JSON: 警告は前後とも 0。無視した警告は EOLRails・EOLRuby → EOLRails。エラーと使われない無視の項目は 0 件で、実行したチェックは同じ

### 手動確認

3 アプリの Ruby を上げた後（`TargetRubyVersion` の前）に、`.claude/launch.json` から 3 アプリを起動してブラウザペインで確かめた（操作は人間）。3 アプリとも Puma の起動の出力に Ruby 3.3.12・Rails 7.1.6・Puma 8.0.2 が出た。

- ログイン（RP の my_op）: 人間が「Re Login」を押した。OP のログイン画面も同意画面も出ずに RP に戻り、「ログインしました」が出た。OP のログは、認可エンドポイントが 302、トークン・userinfo・JWKS が 200
- introspection 用 RP: 前回のトークンは revoke 済みなので同意画面が出て、Authorize の後、RS は正しいトークンで 200、`_bad` を付けたトークンで 401、revoke（OP は 200）の後は 401。RS が受け取った introspect は `active: true`（キーの順は `iat, exp`、`exp - iat = 600`）→ `active: false` が 2 回。Step 3-b と同じ
- サーバーの出力: 3 アプリとも、warning・DEPRECATION はない。エラーは、RP の `/stylesheets/application.css` と OP の同意画面の `/stylesheets/doorkeeper/application.css` のルーティングのエラーだけ。どちらも元からのもの（OP は `app/views/layouts/doorkeeper/application.html.erb` の `stylesheet_link_tag` が、アセットパイプラインのない OP で出す要求。これまでの記録には RP の分しか書いていなかった）
- 手動確認用の環境: 直前に、3 アプリのサーバーが止まっていて、14 ファイルのハッシュが作業の開始時と同じことを確かめた。手動確認で、OP の development DB は `oauth_access_grants` が 23 → 25 件、`oauth_access_tokens` が 57 → 62 件（my_op 1・introspection 用 1（revoke 済み）・RS のクライアントクレデンシャル 3）、RP の development DB は `sessions` が 12 件・`op_users` が 1 件のまま。どちらも `integrity_check` は ok。ハッシュが変わったのは OP・RP の DB の本体と `-wal` だけで、RS の DB・署名鍵・`.env`・3 アプリの `tmp/development_secret.txt`・`tmp/local_secret.txt` は変わっていない。以降の基準は手動確認の後の 14 ファイルのハッシュ

### 遭遇した問題

| 問題 | 対応 |
|---|---|
| RS で、default gem と同じ版の 3 つの gem が `vendor/bundle` から読まれた | 止まって人間に確かめ、消して入れ直した（上の「作業計画からの変更点」） |
| `ruby -e` の中に日本語の文字列を書くと、`invalid multibyte char (US-ASCII)` で読めない | 確かめるためのスクリプトをファイルにして流した（`-e` は ASCII だけで書く） |

### 確認結果

verify で、PLAN.md の 10 章の完了条件を確かめた。

- `scripts/check-apps`（3 アプリと E2E）: HEAD（`c913afe`）で 36 の検査がすべて通った。各アプリのコミットの前には、そのアプリと E2E で流した
- minitest: RS 11 runs・15 assertions、RP 33・71、OP 69・123、0 failures。`CI=1`（eager load あり）でも同じ
- E2E: 10 passed。応答のスナップショットと E2E のスナップショットの差分はない。E2E の起動で、E2E 用の DB を `db:drop` → `db:setup`（RS は `db:create`）で作り直している
- RuboCop（`TargetRubyVersion: 3.3`）・`zeitwerk:check`・起動の途中の読み込みの検査（test・`CI=1`・development）・bundler-audit（無視リストに解消済みの ID がないかも）・brakeman: すべて通った（`check-apps` の項目）。brakeman は 3 アプリとも `Security Warnings: 0`・`Ignored Warnings: 1`（EOLRails）で、使われない無視の項目はない。bundler-audit の無視リストは変わらない（この Step で解消した advisory はない。erb・resolv は default gem で lock にないので、bundler-audit の対象外）
- lock: epic（`34bc460`）からの動きは、default gem の合わせ直し（OP は ostruct も）、増えた rdoc・psych・stringio、`RUBY VERSION`・`BUNDLED WITH` だけ。一時固定の reline 0.6.0・connection_pool 2.5.5・faraday-net_http 3.0.2（RS・RP）と、benchmark・tsort・ruby2_keywords は動いていない
- `bin/rails c`: `scripts/check-console` で 3 アプリとも起動した（irb 1.13.1・reline 0.6.0・io-console 0.7.1。Tab の補完と複数行の入力ができた）。`bin/rails s`: 手動確認で 3 アプリとも起動した
- 公開物の安全チェック: 各コミットの hooks で通った
- CI: push の後に確かめる（push は人間が行う）
- 手動確認用の環境: HEAD で、14 ファイルのハッシュが手動確認の後の基準と同じ（上の「手動確認」）

### コードレビュー（`/code-review`）

| 指摘 | 対応 |
|---|---|
| TIPS.md の「Ruby を上げる」が、brakeman の EOLRuby の警告は無視リストに当たり続けると書いたまま（サポート中の Ruby に上げると使われない無視になり、Step 4 で消した） | 直した。EOL の Ruby の間は当たり続け、サポート中の Ruby に上げたら Ruby を上げるコミットで消す、と書き分けた（人間が判断） |
| PLAN.md の 7 章の Step 4 の行が、「見込み」「確かめる」のまま、または「（済）」がない（default gem の各行、base64 などの警告、erb） | 直した。合わせ直した行に「（済）」を付け、警告は出なかったこと、erb は解消したことを書いた（人間が判断） |
| PLAN.md の 8 章の 4 と TIPS.md の「gem の更新」が、benchmark・securerandom・tsort を「要件を満たす最小の版に固定した gem」としている（3.3.12 では default gem と同じ版） | 直した。3 つを default gem の版に合わせ直す側に移した。最小の版に固定した gem は reline だけ（人間が判断） |
| 設定（`.claude/rails-upgrade-project.md`）の ruby の行が、Ruby の版を持つファイルの一覧として、古い Step 2 の一覧（`mise where ruby@3.1.7` を含む）を指している | 直した。Step 4 の「調べたこと」の「Ruby の版を持つ箇所」を指すようにした（人間が判断） |
| キャッシュのコピーで default gem と同じ版の `.gem` を外す手順が TIPS.md の文だけで、今回は scratchpad の使い捨てのスクリプトで行った | 直さない。`scripts/` に道具を足すのは Step 4 の範囲を超える。下の「スキルについて気づいたこと」の 6 に足し、スキルを直すときに決める（人間が判断） |
| TIPS.md の gem の置き場所の例が「3.2 系は `3.2.0`」のまま | 直した。「3.3 系は `3.3.0`」にした（人間が判断） |
直した後（文書だけの変更）も、`scripts/check-apps`（3 アプリと E2E）の 36 の検査がすべて通り、件数は同じ。手動確認用の環境の 14 ファイルのハッシュは、手動確認の後の基準と同じ

### スキルについて気づいたこと

Step 3・3-b と同じく、スキルの手順・型・設定で、足りない・合わない・迷ったところを控える（スキルを直すかは人間が判断する）。

research:

1. ruby.md の手順 3（新しい Ruby の default gem の版を調べ、合わせ直す方針を決める）は、Ruby を入れた後の作業になっているが、版は GitHub のタグのソースから、増える依存（irb 1.13.1 の rdoc・psych・stringio）は rubygems.org の API から、research の時点で決められた。方針は判断の関門なので、research に前倒しできる。lock の試行だけは Ruby を入れた後になる（Plan モードではファイルを書けず、Ruby もない）
2. research の手順 2 の advisory の確かめ方（設定の「作業ごとの参照」の research の行）は、lock の gem を前提にしている。default gem（erb・resolv）の advisory は lock になく bundler-audit で検出できないので、ruby-lang.org の告知で見つけた（resolv の CVE-2026-80212・80213 は、research のサブエージェントが告知の一覧から見つけた）。Ruby を上げる Step で、Ruby の告知の脆弱性を確かめる項目がない
3. brakeman の EOLRuby の無視の項目が、Ruby を上げると使われない無視になることを、research でソースを読んで見つけた。ruby.md と設定の「前後の比較」に、無視リストの項目が当たり続けるかを見る手順がない（Step 2 では当たり続けた）

ruby:

4. ruby.md の手順 4 は、gem の入れ直しで「意図しないダウンロードが起きない」ことを見るが、前の版のキャッシュに新しい Ruby の default gem と同じ版の `.gem` があると、ダウンロードなしで入って default gem の代わりに読まれる。default gem から読まれるかは TIPS.md にしかなく、RS のコミットの前の確かめで気づいた（TIPS.md の「Ruby を上げる」に足した）。追記（Step 4-b）: default gem の代わりに `vendor/bundle` から読まれること自体は、Bundler 2.5 では CI と同じ状態で、問題ではなかった（上の「作業計画からの変更点」の追記）
5. `scripts/compare-config` の書き出しは、その版にない設定を読んだときの例外のメッセージも含むので、Ruby を上げると、アプリの設定が同じでも例外の文言（`NoMethodError`）の差分が出る。前後の比較の手順に、道具の出力の差分とアプリの差分を分ける目安がない

6. TIPS.md に足した、キャッシュのコピーで default gem と同じ版の `.gem` を外す手順は、今回は scratchpad の使い捨てのスクリプトで行った。`scripts/verify-gem-checksums` と同じく道具にすれば、Ruby を上げるたびに手で作らずに済む（コードレビューの指摘。直さずに、ここに控えた）

manual-check:

7. 手動確認でサーバーの出力を読むとき、元からあるエラー（RP の `/stylesheets/application.css`、OP の同意画面の `/stylesheets/doorkeeper/application.css`）の一覧が設定にも TIPS.md にもなく、新しいものかを判断するのに過去の記録とビューを探した（OP の分は、これまで記録していなかった）

## Step 4-b: simplecov 1.3.2（2026-10-12）

- ブランチ / PR: `upgrade/step4b-simplecov13` / [#32](https://github.com/thinkAmi-sandbox/oidc_op_rp-sample/pull/32)
- バージョン: Ruby 3.3.12・Rails 7.1.6（変更なし）。3 アプリの simplecov 1.2.0 → 1.3.2
- 追随した gem の既定値は、[defaults/rails-7.1.md](defaults/rails-7.1.md) の「周辺 gem（Step 4-b）」に記録した（DEF-7.1-52）。業務的な挙動の変化（B）は起きなかった
- lock にある default gem と同じ版の gem（16 個。OP は ostruct を足して 17 個）を、3 アプリとも `vendor/bundle` に入れた。Step 4 の後、手元は default gem から、CI は `vendor/bundle` から読んでいて、ずれていた（下の「遭遇した問題」）

### 作業計画で決めたこと

`/rails-upgrade research` で、Plan モードで調べた（サブエージェントは使わなかった。CHANGELOG とソースの差分は GitHub のタグ、版・依存・サイズは rubygems.org の API、lock の解決は `bundle lock --update simplecov --conservative --print`）。作業計画を出し、論点を 1 つずつ人間と確かめてから承認を得た。調べたことの一覧と決めたことの全体は、PLAN.md の 6 章の「Step 4-b」に書いた。

| 論点 | 決めたこと | 理由 |
|---|---|---|
| 版 | 1.3.2。公開から 2 週間の決まりの例外とする | 着手の日（10-12）は公開から 12 日目。脆弱性があれば既に報告されている時期と考えられ、advisory も出ていない。AI は、2 週間たった 1.3.1 にし、1.3.2 は Step 5 の最初に上げる案を出した（1.3.1 からの違いは、`parallelize` を使わない 3 アプリには効かない修正だけ）が、人間が 1.3.2 を選んだ。brakeman 8.1.0（Step 3。10 日目）に続く 2 例目 |
| 追随の記録 | DEF-7.1-52 の 1 項目（ファイルのないグループを外す、`rails` プロファイルのグループの並び順）。defaults/rails-7.1.md に「周辺 gem（Step 4-b）」の節を足す | どちらもグループの出し方の変化で、前例の DEF-7.0-50 も 1 項目にまとめた。Prism を読み込まなくなること（1.3.1）は既定値の変化ではないので、DEF-7.1-52 の影響とこの節に書く（人間が判断） |
| 手動確認 | 行わない。手動確認用の環境の 14 ファイルのハッシュを、作業の開始時と verify で比べる | simplecov は test グループで `require: false` で、development のサーバーでは読まれない。lock で動くのは simplecov だけ（人間が判断） |
| rubocop 1.92.0・webmock 3.27.0〜3.29.0 | この Step では扱わない。Step 5 の research の最初に確かめる | 公開から 1〜2 日で、2 週間たっていない（人間が判断） |

- ダウンロード: simplecov 1.3.2 の `.gem`（218,624 B）を、3 アプリで 1 回ずつ。作業計画で示し、承認を得た

### 手動確認用の環境

作業の開始時（ブランチを切って最初のコミットの前）に、3 アプリのサーバーが止まっていることを確かめ、14 ファイルのハッシュを控えた（前のセッションの控えは残っていないので、これを Step 4-b の基準にする）。件数は、本体と `-wal` を scratchpad にコピーして数え、Step 4 の手動確認の後と同じだった（OP `oauth_access_grants` 25・`oauth_access_tokens` 62、RP `sessions` 12・`op_users` 1。どちらの DB も `integrity_check` は ok）。OP の `tmp/manual_check_backup/` はない。最初のコミット（Step 4 の PR へのリンク）の後も、14 ファイルのハッシュは同じ

### 作業計画からの変更点

| 変更 | 理由 |
|---|---|
| lock にある default gem と同じ版の gem（json・bigdecimal・logger・base64・cgi・drb・mutex_m・io-console・irb・rdoc・psych・stringio・benchmark・securerandom・tsort・ruby2_keywords の 16 個。OP は ostruct 0.6.0 も）を、3 アプリとも `vendor/bundle` に入れた | RS の `bundle update` で、計画にないダウンロードとして起きた（下の「遭遇した問題」）。止まって原因を調べ、CI も同じものを入れて読んでいると分かった。手元を CI に揃える案と、Step 4 の状態（default gem から読む）に戻す案を示し、人間が CI に揃える案を選んだ |
| RP・OP は、`bundle update` の代わりに、`bundle lock --update simplecov --conservative` で lock だけを書き、RS で照合済みの `.gem` 17 個をキャッシュにコピーして、`BUNDLE_CACHE_PATH=vendor/bundle/ruby/3.3.0/cache mise exec -- bundle install --local --no-cache` で入れた。OP の ostruct 0.6.0 だけは `gem fetch` で落とした（11,776 B） | 同じものを 3 回落とさないため（人間が判断）。計画のダウンロードは simplecov の 3 回だったが、実際は RS の 17 個と OP の ostruct の 1 個 |

### gem ごとの対応

| gem | バージョン | 対応 |
|---|---|---|
| simplecov | 1.2.0 → 1.3.2 | 3 アプリ。RS は `bundle update simplecov --conservative`、RP・OP は上の入れ方。lock で動いたのは、3 アプリとも simplecov の 1 行だけ。DEF-7.1-52 |
| json ほか 16 個（OP は ostruct を足して 17 個） | 変更なし（lock の版のまま） | 読む場所が、default gem から `vendor/bundle` に変わった（3 アプリ。手元だけ。CI は Step 4 から `vendor/bundle`）。版は同じ |

- 照合: `scripts/verify-gem-checksums` で、3 アプリのキャッシュの `.gem` がすべて rubygems.org の SHA-256 と一致した（RS 142・RP 156・OP 199 個。落とした simplecov 1.3.2・16 個・ostruct 0.6.0 を含む）
- 読む場所: `bundle exec ruby -e` で、3 アプリとも lock の gem がすべて `vendor/bundle` から読まれ、default gem から読まれる gem は 0 個（RS 107・RP 117・OP 109 個）
- epic と比べて lock で動いたのは simplecov の行だけ。lock に入れた default gem の版、一時固定の reline 0.6.0・connection_pool 2.5.5・faraday-net_http 3.0.2（RS・RP）、Gemfile は動いていない
- advisory: simplecov の advisory はない（research）。bundler-audit の無視リストは変わらない

### 意図的な仕様変更

なし。gem の既定値への追随は DEF-7.1-52（カバレッジのレポートのグループの出し方。人間が追随と判断した）

### 前後の比較

simplecov を上げる前（`769ad12`。3 アプリとも default gem から読む状態）に次のものを書き出し、3 アプリを上げた後に取り直して比べた。

- `scripts/check-apps`: 前後とも 36 の検査がすべて通った（RS 11・RP 33・OP 69 runs、0 failures。`CI=1` も同じ。E2E 10 passed）。応答のスナップショットと E2E のスナップショットの差分はない。各アプリのコミットの前（`commit-per-app`）も同じ
- `scripts/compare-config dump`（3 アプリ、test・development）: 前を 2 回取って同じことを確かめた。前後で同じ
- `RUBYOPT=-W:deprecated` を付けた minitest と development の eager load: 前後とも、`warning:` の行は 0 件。DEPRECATION は前後とも OP のテストの `auth_time_from_resource_owner`（IMP-011）だけ
- カバレッジの出力（`coverage/`）: `coverage.json` の合計・ファイルごとの値（RS 7・RP 15・OP 8 ファイル）・エラーの欄、`.last_run.json`、テストの最後に出る結果の行（`Line coverage: 33 / 33 (100.00%)` など）、`coverage/` のファイルの一覧は前後で同じ。違ったのは、`coverage.json` と `.history.json` のグループ（空のグループが外れ、アルファベット順になった。DEF-7.1-52）と、`meta` の `simplecov_version`・`timestamp` だけ
- prism: テストの実行の終わりに `$LOADED_FEATURES` を見ると、前は 3 アプリとも prism 1.9.0 が読まれ、後は読まれない（1.3.1 から、Prism を branch・method のカバレッジで要るときだけ読む）

### 遭遇した問題

| 問題 | 対応 |
|---|---|
| RS の `bundle update simplecov --conservative` で、simplecov のほかに、lock にある default gem と同じ版の gem 16 個を rubygems.org から落とし、`vendor/bundle` に入れた（6 個は C 拡張をビルドした）。lock は simplecov の 1 行しか動かず、research の `--print` では見えなかった | 止まって人間に報告し、原因を調べた。Bundler 2.5.12 の rubygems/rubygems#7673 で、Bundler は lock にある default gem を普通の gem として扱い、入れるようになった（`bundler-2.5.22` の `lib/bundler/source/rubygems.rb` の `specs` は、default gem の spec を、rubygems.org などにないときだけ足す。`lib/bundler/rubygems_integration.rb` の `installed_specs` は default gem を除く）。Bundler 2.4.19 は、default gem の spec で rubygems.org の spec を上書きしていた（`:override_dupes`）。落とした 17 個の `.gem` は、すべて rubygems.org の SHA-256 と一致した |
| Step 4 の後、手元と CI で、default gem と同じ版の gem を読む場所がずれていた | CI のログで確かめた。Step 4 の PR の CI（`BUNDLED WITH` 2.5.22）は、各ジョブで 16 個（OP は ostruct を足して 17 個）を入れていた。Step 2 の CI（Bundler 2.4.19。キャッシュなしで 484 個を入れた）は、これらを入れていない。Step 4 は「CI は同じ版の default gem を使う」と考えて RS の 3 つを外し、`--local` で入れたので、手元だけ default gem から読んでいた（Bundler 2.4 までは正しかった前提）。人間の判断で、3 アプリとも `vendor/bundle` に入れて CI に揃えた。TIPS.md の「Ruby を上げる」と「gem の更新」を直した |

### 確認結果

verify で、PLAN.md の 10 章の完了条件を確かめた。手動確認は、作業計画で決めたとおり行わない。

- `scripts/check-apps`（3 アプリと E2E）: HEAD（`010827a`）で 36 の検査がすべて通った。各アプリのコミットの前には、そのアプリと E2E で流した
- minitest: RS 11 runs・15 assertions、RP 33・71、OP 69・123、0 failures。`CI=1`（eager load あり）でも同じ
- E2E: 10 passed。応答のスナップショットと E2E のスナップショットの差分はない。E2E の起動で、E2E 用の DB を `db:drop` → `db:setup`（RS は `db:create`）で作り直している
- RuboCop・`zeitwerk:check`・起動の途中の読み込みの検査（test・`CI=1`・development）・bundler-audit（無視リストに解消済みの ID がないかも）・brakeman: すべて通った（`check-apps` の項目）。bundler-audit は 3 アプリとも `No vulnerabilities found`。brakeman は 3 アプリとも `Security Warnings: 0`・`Ignored Warnings: 1`（EOLRails）
- lock: epic（`18f983f`）からの動きは、3 アプリとも simplecov の 1 行だけ。Gemfile は epic と同じ。lock に入れた default gem の版と、一時固定の reline 0.6.0・connection_pool 2.5.5・faraday-net_http 3.0.2（RS・RP）は動いていない
- `bin/rails c`: `scripts/check-console` で 3 アプリとも起動した（irb 1.13.1・reline 0.6.0・io-console 0.7.1。どれも `vendor/bundle` から読む。Tab の補完と複数行の入力ができ、終了の状態は 0）。`bin/rails s`: E2E の起動（`e2e/scripts/start-server.sh` が `bin/rails server` を起動する）で 3 アプリとも起動した
- 公開物の安全チェック: 各コミットの hooks で通った
- CI: push の後に確かめる（push は人間が行う）。lock の変化は simplecov だけなので、CI の入れ方は Step 4 と同じ見込み
- 手動確認用の環境: HEAD で、3 アプリのサーバーが止まっていて、14 ファイルのハッシュが作業の開始時の基準と同じ


### コードレビュー（`/code-review`）

| 指摘 | 対応 |
|---|---|
| Step 4 の記録（「作業計画からの変更点」と、スキルについて気づいたことの 4）に、「CI は同じ版の default gem を使う」という前提が、追記なしで残っている | 直した。前例の「追記（Step 1-b-3-2）」の形で、Step 4 の 2 か所に追記（Step 4-b）を足し、この節の「遭遇した問題」を指した。元の文は当時の記録として残した（人間が判断） |
| PLAN.md の 8 章の 4（Ruby を上げるときの手順）が、Bundler 2.5 で default gem と同じ版の gem も `vendor/bundle` に入れることに触れていない | 直した。手元も CI に揃えて入れること、そのための `.gem` を research でダウンロードの確認に入れることを書き、TIPS.md を指した（人間が判断） |
| PLAN.md の 7 章の simplecov の行で、1.3.2 に「（済）」がない | 直した（人間が判断） |
| PLAN.md の Step 4-b の節の「ダウンロード: 3 アプリで 1 回ずつ」が、実際と違う | 直した。計画の文は残し、実際に落としたもの（RS 17 個・OP の ostruct 1 個・RP 0 個）と、この節の「作業計画からの変更点」を書き足した（人間が判断） |
| TIPS.md の「CI は毎回これらを入れて読む」は、キャッシュが当たった実行では入れ直さないので不正確 | 直した。キャッシュの有無で分けて書き、CI のログで確かめるときはキャッシュなしで入れた実行を見る、とした（人間が判断） |

直した後（文書だけの変更）も、`scripts/check-apps`（3 アプリと E2E）の 36 の検査がすべて通り、件数は同じ。手動確認用の環境の 14 ファイルのハッシュは、作業の開始時の基準と同じ

### スキルについて気づいたこと

Step 3・3-b・4 と同じく、スキルの手順・型・設定で、足りない・合わない・迷ったところを控える（スキルを直すかは人間が判断する）。

research:

1. Step 3 の 4（計画で決めた時期と、公開から 2 週間の決まりが食い違ったときの扱い）が、また起きた。計画の時期（4-b）に、最新の 1.3.2 は 12 日目だった。brakeman 8.1.0（10 日目）に続き、人間が例外とした。2 回続いたので、例外の目安（何日目から、何を確かめれば例外にできるか）を書く場所があるとよい
2. research の手順 4（lock を書かずに解決の結果を試す。`--print`）は、lock の変化しか見えない。Bundler 2.5 が、lock にある default gem と同じ版の gem を `vendor/bundle` に入れること（rubygems/rubygems#7673）は lock に出ないので、ダウンロードの確認が実際より少なかった（計画は simplecov の 3 回、実際は RS の 17 個と OP の 1 個）。lock の gem のうち `vendor/bundle` にないものを数える手順が要る（TIPS.md の「gem の更新」に書いた）

gems:

3. gems の手順 4 は「lock で動いた gem を確かめる」だけで、`bundle update` の出力の `Fetching` の行を見る手順がない。今回は、出力を読んで lock にない入れ直しに気づいた
4. gems の手順 6（前後の比較）が指す設定の「前後の比較」に、テストだけで使う道具の出力（カバレッジ）の項目がない。Step 2-b と同じく、比べるもの（`coverage.json`・`.last_run.json`・結果の行・prism の読み込み）をその場で決めた

前後の比較・verify:

5. 手元と CI で、gem を読む場所（default gem か `vendor/bundle` か）が揃っているかを見る手順がない。Step 4 で生まれたずれ（CI は Bundler 2.5 で `vendor/bundle` から読み、手元は `--local` で入れて default gem から読んでいた）に、Step 4 の verify もコードレビューも気づかなかった。CI のログの `Installing` の行と、手元の `Gem.loaded_specs` を比べると分かる
6. Step 4 の「CI は同じ版の default gem を使う」は、Bundler 2.4 の振る舞いからの推測で、CI のログで確かめていなかった。CI の振る舞いを前提にする判断は、CI のログで確かめる、という決まりがない

## スキルの見直し: 作業の切り替えと確認のまとめ方（2026-10-12）

- ブランチ / PR: `upgrade/skill-workflow` / [#33](https://github.com/thinkAmi-sandbox/oidc_op_rp-sample/pull/33)
- バージョン: Ruby 3.3.12・Rails 7.1.6（変更なし）。gem は上げていない。アプリのコードと lock も変えていない

### 作業計画で決めたこと

Step 4-b の PR が epic に入った後、人間が、Step 4-b でスキルを使って気になったことを 3 つ挙げた（作業ごとにコマンドを打つ必要があり、ワークフローを覚えておかないと誤った作業に進むおそれがある。同じような確認が作業ごとに入る。PR の本文がコピーできる形で出ない）。Step 4-b の返事の回数を数え直し、原因になっているスキルの箇所を示して改善案を出した。論点を 1 つずつ人間と確かめてから承認を得た。決めたことの全体は、PLAN.md の 6 章の「スキルの見直し」と 13 章の 7 に書いた。

| 論点 | 決めたこと | 理由 |
|---|---|---|
| 作業の切り替え | 関門にしない。引数なしの `/rails-upgrade` で始め、作業の出口で次の作業に入る。作業名の指定がチェックリストと食い違えば止まる | Step 4-b の返事 16 回のうち 5 回が、作業を切り替えるコマンドだった。スキルは関門と関門の間を止まらずに進めるとしているのに、作業の境目だけ人間を待っていた（人間が判断） |
| 確認のまとめ方 | 前の論点のまとめを、次の論点と同じメッセージに載せ、「違っていれば指摘してください。指摘がなければ同意とみなします。」と書く。最後の論点で計画の承認も取る | まとめへの同意と、論点を決めた後の計画の承認が、判断を伴わない往復だった。人間は、選択式や、1 回の返事で掘り下げられない形を避けたいとした。文言は、時間が空いても黙っているとどう扱われるか分かるように、人間が提案した。2-a の形は、人間の求めで、Step 4-b の論点 1 のやり取りを例に、返事の 3 通り（同意、まとめが違う、次の論点を掘り下げる）で説明してから決めた |
| 貼るものの出し方 | PR のタイトルと本文などは、コピーできるブロックで出し、`gh pr create` のコマンドにタイトルと `--body-file` を入れる。質問の締めの文は論点名を主語にする | PR の本文をコピーできる形で出す依頼が、Step 4-b までに何度もあった。PR #32 のタイトルが、提案したものではなくブランチ名から作られた。「この案でよいですか」では何を指すか分かりにくい（人間の指摘） |
| 進め方 | Step 5 の前の小さな PR。Step 3〜4-b の「スキルについて気づいたこと」のほかの項目は扱わない | 今回の 3 つは、次の Step から効く。気づいたことの一覧は、直すかを別に決める（人間が判断） |

- 論点 2・3 の質問は、決めている途中の 2-a の形（まとめと次の論点を同じメッセージにする）で行った
- Step 3 の気づきの 9（論点が多いときの進め方）は、まとめへの同意の往復をなくすことで一部を片づける。論点の数そのものを減らす方法は、まだ決めていない

### 作業計画からの変更点

| 変更 | 理由 |
|---|---|
| research で Plan モードを使わない。research は、アプリと計画のファイルを変えない決まりで行い、書いてよいのは scratchpad と、決めた論点を足す記録の Step の節だけにした。決めた論点はそのたびに記録に足してコミットする（CLAUDE.md の「承認を待ってからファイルを変更する」に、この例外を書いた） | コードレビューで、最後の論点で計画の承認を取る形（論点 2 の 2-b）が、Plan モードの決まり（計画の承認はテキストで聞かず、承認の画面で求める）と食い違い、承認の二重化がなくならないと分かった。Plan モードのまま最後の論点を論点だけにする案、承認の画面で最後の論点を聞く案、Plan モードを使わない案を示し、人間が Plan モードを使わない案を選んだ。Plan モードは、これまで AI がファイルを書かない理由としてしか効いておらず、research で lock を試せない（Step 4）、決めた論点を書けない、という不便があった |

### 変えたもの

| コミット | 変えたもの |
|---|---|
| `63b1f05` | SKILL.md に「作業の進め方」の節を足した（引数なしで resume から始め、作業の出口で次の作業に入る。止まるのは関門だけ。作業名の指定がチェックリストと食い違えば止まる）。resume.md の手順 4 を「示して次の作業に入る」にし、ブランチは提案せずに切る。CLAUDE.md の「作業を始めるとき」を書き換えた |
| `cf9773c` | templates.md の「質問」を、前の論点のまとめ（決まった文言付き）と次の論点を 1 つのメッセージにする型にし、締めの文を論点名を主語にした。最後の論点で計画の承認も取る。research.md の関門を、最後の論点への返事を計画の承認とする形にした |
| `6ba77f2` | research.md を、Plan モードを使わず、決めた論点をそのたびに記録に足す形にした。計画に付けたダウンロードの確認は、計画の承認に含む（templates.md の最後の論点の締めの文も）。resume.md に、research の途中から続ける場合を足した。SKILL.md の Plan モードへの切り替えの文を消し、CLAUDE.md と PLAN.md（8 章の 1、13 章の 3・7）を直した |
| `31dc713` | SKILL.md に、`resume` の指定は引数なしと同じに扱う（チェックリストと比べない）と書いた |
| `fff553a` | templates.md の冒頭に、人間がそのまま貼るものはコピーできるブロックで出すと書き、「PR 本文」に「出し方」（タイトル、4 つのバッククォートの本文、ファイルのパス、`git push` と `gh pr create --title --body-file`）を足した。pr.md の手順 3 から指した |

### 確認結果

- 直したスキルを読み直し、各作業の出口（記録とチェックリストのコミット）が、SKILL.md の「作業の進め方」の「出口で次の作業に入る」と食い違わないことを確かめた。Step 4-b の流れをたどり直すと、返事は、開始の `/rails-upgrade` の 1 回と、関門（research の論点 4 つ。4 つ目で計画とダウンロードの承認も取る。計画にないダウンロードと案の選択、追随の解説、コードレビューの扱い）になる見込み。Plan モードへの切り替えと承認の画面はなくなる。pr の後の push と PR の作成は、これまでどおり人間が行う。まだ試していないので、Step 5 で確かめる（コードレビューの指摘で、Plan モードの承認の画面を数えていなかったところを直した）
- `scripts/check-apps`（3 アプリと E2E）: スキルを直すコミットの前に、36 の検査がすべて通った（アプリのコードと lock は変えていない）
- 公開物の安全チェック: 各コミットの hooks で通った。計画のコミットは、1 回目に `git commit` と同じコマンド行に `sed -n` を書いて hooks に止められた（Step 3 の気づきの 16 と同じ）。行を分けてコミットした
- 手動確認用の環境: 14 ファイルのハッシュは、Step 4-b の作業の開始時の基準と同じ
- 新しい流れを本当に試すのは、Step 5 の始め（`/rails-upgrade` だけで始める）。そこで分かったことは Step 5 の記録に書く

### コードレビュー（`/code-review`）

| 指摘 | 対応 |
|---|---|
| 最後の論点で計画の承認をテキストで取る形は、research を行う Plan モードの決まり（承認はテキストで聞かず、承認の画面で求める）と食い違い、承認の二重化がなくならない | research で Plan モードを使わないことにした（人間が判断。上の「作業計画からの変更点」）。`6ba77f2` |
| `/rails-upgrade resume` と打つと、`resume` はチェックリストの作業名にならないので、いつも食い違いとして止まる | 直した。`resume` は引数なしと同じに扱う（人間が判断。Step 5 の途中を例に、呼び方ごとの動きを説明してから決めた）。`31dc713` |
| 計画の承認に、ダウンロードの承認も含むかが書いていない | 直した。計画にダウンロードの確認の型を付けたときは、計画の承認に含む。計画の後で分かったダウンロードは別に止まる（人間が判断）。`6ba77f2` |
| research の途中でセッションが切れたときの扱いがない（Plan モードでは、決めた論点を記録に書けない） | 直した。決めた論点はそのたびに記録に足してコミットし、resume は、記録に論点があって計画にチェックリストがなければ、続きの論点から research を始める（人間が判断）。`6ba77f2` |
| 確認結果の「返事は開始の 1 回と関門になる」は、Plan モードの承認の画面を数えていない | 直した。Plan モードをやめたことに合わせて書き直し、まだ試していない見込みであることを書いた（人間が判断） |

- 論点の確かめは、この見直しで決めた形（前の論点のまとめを次の論点と同じメッセージに載せ、最後の論点で承認も取る）で行った
- 直した後も、`scripts/check-apps`（3 アプリと E2E）の 36 の検査がすべて通った。手動確認用の環境の 14 ファイルのハッシュは、Step 4-b の作業の開始時の基準と同じ

## Step 5: Rails 7.2（2026-10-12）

- ブランチ / PR: `upgrade/step5-rails72` / [#34](https://github.com/thinkAmi-sandbox/oidc_op_rp-sample/pull/34)
- バージョン: Ruby 3.3.12（変更なし）/ Rails 7.1.6 → 7.2.4。その前に sqlite3 1.7.3 → 2.9.6、OP の annotate 3.2.0 → annotaterb 4.25.0（RP は annotate を外した）
- 追随した Rails と gem の既定値・雛形は、[defaults/rails-7.2.md](defaults/rails-7.2.md) に記録した（DEF-7.2-01〜29）。業務的な挙動の変化（B）は起きなかった。bundler-audit の無視リストは空になった（Rails の 10 件、sqlite3 の 2 件が解消）
- スキルの見直し（[#33](https://github.com/thinkAmi-sandbox/oidc_op_rp-sample/pull/33)）の後、`/rails-upgrade` を引数なしで始めた最初の Step。resume から research へ止まらずに入り、research は Plan モードを使わずに行った

### 作業計画で決めたこと

`/rails-upgrade` の research で調べた（サブエージェント 2 つ: Rails 7.2 の事実、周辺 gem の事実。lock の解決、advisory、mutex_m の警告、sqlite3 と Rails 7.1 の組み合わせは自分で確かめた）。論点を 1 つずつ人間と確かめ、決まるたびにこの表に足す。

| 論点 | 決めたこと | 理由 |
|---|---|---|
| 1 sqlite3・annotaterb の順番 | Rails 7.2.4 の前に、sqlite3 2.9.6 → annotaterb の順で上げる | PLAN.md の「Rails 7.1 までは sqlite3 1.x のみ」は誤りで、Rails は 7.1.4 から 2.x を使える（`activerecord-7.1.6/CHANGELOG.md` の 7.1.4 の節）。今の 7.1.6 の lock で 2.9.6 にしても、動くのは sqlite3 の行だけ。annotaterb も Rails に依存しない。7 章の振り分けの 1（今の Rails のまま上げられる gem は前に）に当たり、sqlite3 は advisory 2 件の修正版で、DB のドライバーの変化と Rails の変化を別のコミットで検査できる（人間が判断） |
| 2 mutex_m | 3 アプリの Gemfile の test グループに `gem 'mutex_m'` を明示する（理由のコメント付き、版は書かない）。Rails 7.2.4 のコミットに入れる | activesupport 7.2 が依存から外し、lock から mutex_m 0.2.0 が消える。minitest 5.14.4 が `require "mutex_m"` するので、Ruby 3.3 の bundled_gems の警告がテストのたびに出る（再現した）。PLAN.md の 7 章の「警告が出たら明示」に当たる。明示すると lock は 0.2.0 のままで、`vendor/bundle` にもある。minitest を上げる案は、間接の gem で方針の外なので採らない（人間が判断） |
| 3 annotaterb の範囲 | OP は Gemfile を `annotaterb` にし、`bin/rails g annotate_rb:install` の雛形（`lib/tasks/annotate_rb.rake`・`.annotaterb.yml`）に追随して、旧 rake の値と違う 2 つ（`hide_limit_column_types`・`hide_default_column_types`）を `.annotaterb.yml` に移し、旧 rake を消す。注釈を付け直して差分が出ないことを E2E 用の DB で確かめる。RP は Gemfile を `annotaterb` にするだけで、generator は流さない | 今の使われ方と同じにする。OP は migrate の後に注釈を付けている。RP は gem があるだけで rake も注釈もなく、hook を入れると使っていない機能を動かし始める（3 章の 2 の境目 5）。旧 rake の `rubocop:disable` は、雛形の rake に `task` のブロックがないので要らなくなる見込み（人間が判断） |
| 4 rubocop・webmock | Step 5 では上げない。次の Step（6）の research の最初に、その時点の最新版と公開から 2 週間たっているかを確かめる。webmock を上げるときは、版ごとに RS の `body:` で照合するテストが通ることを見る | rubocop 1.92.0（10-10）・webmock 3.27.0〜3.29.0（10-10・10-11）は 2 週間たっていない（10-24・10-25）。人間の求めで webmock を掘り下げた。3 つの版は、メンテナーが 10-10〜10-11 に溜まった Issue・PR（2015 年からの 19 件）を片付けた区切りごとのリリースで、前の版の不具合を直す連続リリースではない（10-10 以降の新しい Issue・PR は 0 件）。3.28.0 の破壊的な変更（`to_rack` に `rack.session` を入れない。#985・#1093）は、Rails 7 のアプリを `to_rack` に渡すと落ちる不具合の修正で、3 アプリのテストは `to_rack` を使わない。Unreleased に次の版の変更（#1128）があり、待つ間に版が増えるおそれがある。開発・テスト用の道具で advisory もない（人間が判断） |
| 5 手動確認の時期 | verify で 1 回（`load_defaults 7.2` と `TargetRailsVersion` の後）。RP の my_op のログインと introspection 用 RP の流れ、OP の「Redirected to」行の `code=` を見る。直前に、3 アプリの development DB の本体と `-wal` を各アプリの `tmp/manual_check_backup/` に写す | sqlite3 2.x のドライバーと Rails 7.2 で、手動確認用の DB を初めて開く。Step 3 では 7.1 で初めて開いたときに DB が変わった（DEF-7.1-47・48）ので、元に戻す選択肢を残す（Step 3 の気づきの 22）。secret_key_base は 7.2.4 も `tmp/local_secret.txt` を読み（`master.key`・`SECRET_KEY_BASE` はない）、`load_defaults 7.2` に Cookie の形式を変える項目はない。全部が揃った状態で 1 回にすると、手動確認用の DB を開く回数が少ない（人間が判断）。この論点への返事で、作業計画（ダウンロードの確認を含む）の承認も得た |

- 上げないもの: rubocop・webmock（論点 4）、web-console 4.3.0（railties `>= 8.0`。Step 6）、rack 3.x（間接の gem）、minitest（論点 2）
- ダウンロード: sqlite3 2.9.6-arm64-darwin・annotaterb 4.25.0・Rails の構成 gem 7.2.4 の 13 個・tzinfo 2.0.6・useragent 0.16.11（計 5,244,416 B）。各 `.gem` は 1 回だけ落とし、照合してほかのアプリのキャッシュにコピーする。作業計画で示し、論点 5 への返事で承認を得た
- 調べたことの一覧と決めたことの全体は、PLAN.md の 6 章の「Step 5: Rails 7.2」に書いた。PLAN.md の 7 章の sqlite3 の行と、Step 3 の「調べたこと」の誤り（Rails 7.1 は sqlite3 1.x だけ）も直した

### 作業計画からの変更点

| 変更 | 理由 |
|---|---|
| RP は annotate を annotaterb に置き換えず、Gemfile から外した（論点 3 では「RP は gem だけ置き換える」としていた） | 追随の解説（DEF-7.2-01・02 の関門）で、人間が「そもそも RP では annotate が不要と考えてよいか」と確かめた。RP の annotate は、OP と同じ最初のコミット（`b422079`、2021-08-14）で Gemfile に入ったが、注釈の rake が足されたのも注釈が付いたのも OP だけで、RP には一度も注釈が付いていない（`git log -S'== Schema Information'`）。アップグレード中に動かしたのは、Step 1 で注釈の形を比べるためだけだった。使っていない gem を新しい gem に置き換える理由がないので外した。Step 1 で使われなくなった listen を外したのと同じ扱い（人間が判断）。annotaterb の `.gem` は RP で落として照合し、OP はそのコピーを使った |
| `app:update` の後、RP の `autoload_lib_once` と 3 アプリの puma の port を戻し、`scripts/lib/restore_app_config.rb` の一覧に足した（`b048482`） | どちらも道具の一覧になく、雛形に上書きされた。RP の `autoload_lib_once` は Step 3 の決定（DEF-7.1-10）、port は README の `rails s` の URL（業務的な挙動）なので、人間に確かめて残した（DEF-7.2-18） |
| rails-defaults の前に、`scripts/lib/dump_config.rb` に 4 つの値を足した（`70d77d1`） | `new_framework_defaults_7_2.rb` の 5 項目のうち 4 つが、設定しないと書き出しに出ず、前後を比べられなかった（Step 3 の気づきの 18 のとおり、最初に確かめた） |
| 手動確認用の環境の守るファイルを 14 から 12 にした（OP・RP の `-wal` を外した） | 手動確認の後、sqlite3 2.x の閉じ方の変化で `-wal` が本体に移って消えた（DEF-7.2-29）。中身は件数と `integrity_check` で確かめ、写しから戻さずに、手動確認の後の 12 ファイルを新しい基準にした（人間が判断）。TIPS.md と設定を直した |
| RS・OP の Rails の歓迎ページの `/icon.png` のエラーを、元からあるエラーの一覧に足した（`public/icon.png` は採用しないまま） | 手動確認で、7.2 の歓迎ページがアイコンを読むと分かった。development でルートを開いたときだけで、業務の流れには出ない（人間が判断。DEF-7.2-21 の補足。TIPS.md の「手動確認用の環境」） |

### 手動確認用の環境

作業の開始時（ブランチを切って最初のコミットの前）に、3 アプリのサーバーが止まっていることを確かめ、14 ファイルのハッシュを控えた（前のセッションの控えは残っていないので、これを Step 5 の基準にする）。件数は、本体と `-wal` を scratchpad にコピーして数え、Step 4 の手動確認の後と同じだった（OP `oauth_access_grants` 25・`oauth_access_tokens` 62、RP `sessions` 12・`op_users` 1。どちらの DB も `integrity_check` は ok）。OP の `tmp/manual_check_backup/` はない。最初のコミット（Step 4-b と見直しの PR へのリンク）の後も、14 ファイルのハッシュは同じ

### gem ごとの対応

| gem | バージョン | 対応 |
|---|---|---|
| sqlite3 | 1.7.3 → 2.9.6 | 3 アプリ。Gemfile を `~> 1.4` → `~> 2.9`。RS は `bundle update sqlite3 --conservative`（`Fetching` は sqlite3 2.9.6 の arm64-darwin 版だけ）。RP・OP は `bundle lock --update sqlite3 --conservative` で lock を書き、RS で照合した `.gem` をキャッシュにコピーして `BUNDLE_CACHE_PATH=vendor/bundle/ruby/3.3.0/cache mise exec -- bundle install --local --no-cache` で入れた。lock で動いたのは sqlite3 の 3 行だけ（Linux は `x86_64-linux-gnu` 版。`PLATFORMS` は変わらない）。`scripts/verify-gem-checksums` で 3 アプリとも rubygems.org の SHA-256 と一致した。無視リストから CVE-2026-54619・GHSA-mwm8-39rw-8826 を消した（`47ee48d`・`c400e4a`・`9bc8265`） |
| annotate → annotaterb | 3.2.0 → 4.25.0（OP） | Gemfile の `annotate` を `annotaterb` にして `bundle lock`、RP で照合した `.gem` をキャッシュにコピーして `--local` で入れた。`bin/rails g annotate_rb:install`（E2E 用の DB を指した）で `lib/tasks/annotate_rb.rake`・`.annotaterb.yml` を作り、旧 rake を消した。`.annotaterb.yml` の 2 つの値を旧 rake の値にし、rake は RuboCop に合わせて書き方を直した（DEF-7.2-01・02）。lock で動いたのは annotate・annotaterb の行だけ（`c05d34f`） |
| Rails | 7.1.6 → 7.2.4 | 3 アプリ（rails-lock）。7.1.6 は 7.1 系の最新なので、先に上げるパッチはなかった。`scripts/resolve-lock --gem 'rails=~> 7.2.4' --rails --unpin tzinfo` で解決した lock を持ち込み、Gemfile の rails を `~> 7.2.4` にし、test グループに mutex_m を理由のコメント付きで足して `bundle lock`。動いたのは Rails の構成 gem と tzinfo 2.0.4 → 2.0.6。増えたのは useragent 0.16.11 と `DEPENDENCIES` の mutex_m（lock の 0.2.0 のまま）。RS の `bundle install` で落としたのは 15 個（Rails の構成 gem 13・tzinfo・useragent）だけで、すべて rubygems.org の SHA-256 と一致した。RP・OP は照合した `.gem` をキャッシュにコピーして `--local` で入れた（`Installing` の 15 行だけ）。3 アプリとも lock の gem はすべて `vendor/bundle` にある。無視リストから Rails の 10 件を消し、3 アプリとも `ignore: []` になった。7.2.4 で初めて起動したときに、`Rails.application.secret_key_base` が `tmp/local_secret.txt` と同じことを確かめた（E2E 用の DB）。DEF-7.2-03〜10（`04e8c71`・`4f6e7e6`・`f4e67fc`） |
| tzinfo / useragent | 2.0.4 / （なし） → 2.0.6 / 0.16.11 | activesupport 7.2 の `tzinfo >= 2.0.5`、actionpack 7.2 の `useragent ~> 0.16`（Rails 7.2.4 と同じコミット） |
| mutex_m | 0.2.0（変更なし） | activesupport 7.2 の依存から外れ、3 アプリの Gemfile の test グループに明示した（論点 2。Rails 7.2.4 と同じコミット）。警告の比較で、bundled_gems の警告は出ていない |
| connection_pool | 2.5.5（変更なし） | activesupport 7.2.4 が `>= 2.2.5, < 3` なので、一時固定の理由がなくなった。lock は動いていない |
| annotate | 3.2.0 → （なし）（RP） | Gemfile から外した（上の「作業計画からの変更点」）。lock で消えたのは annotate の行だけ（rake は railties の依存で残る）。annotaterb 4.25.0 の `.gem` は、RP で `bundle install` したときに落とし（`Fetching` は annotaterb だけ）、`scripts/verify-gem-checksums` で rubygems.org の SHA-256 と一致した（`7a7aeaa`） |

### `app:update` で採用したもの・戻したもの

3 アプリで `yes a | bin/rails app:update`（DB は E2E 用）を流し、`scripts/restore-app-config` で独自設定を戻してから、差分を人間が確かめた。項目ごとの解説は [defaults/rails-7.2.md](defaults/rails-7.2.md) の「`app:update` の雛形」。

| ファイル | 判断 | 理由 |
|---|---|---|
| `config/application.rb` の `%w[assets tasks]` | RS・OP は採用 | 書き方だけ（DEF-7.2-11） |
| RP の `config/application.rb` の `autoload_lib_once` と inflector | 戻した | Step 3 で決めた独自設定（DEF-7.1-10）。雛形の `config.autoload_lib` に上書きされ、道具の一覧になく戻らなかったので、人間に確かめて戻し、一覧に足した（`b048482`） |
| development の `annotate_rendered_view_with_filenames` | 採用 | development の HTML にコメントが入るだけ（DEF-7.2-12） |
| development・test のメーラーの `default_url_options` | 採用 | メールを送らない（DEF-7.2-13） |
| test の `public_file_server.enabled` の削除 | 採用 | 既定が true（DEF-7.2-14） |
| 環境のファイルのコメントと書き方 | 採用 | DEF-7.2-15 |
| `filter_parameter_logging.rb` の `:email` | 採用 | ログと `inspect` だけ（DEF-7.2-16） |
| production.rb | 採用 | 雛形に追従するだけ（DEF-7.2-17） |
| `config/puma.rb` | 採用（port は戻した） | 3 アプリの port（3782・3781・3780）が雛形の 3000 になり、道具の一覧になかった。README の `rails s` はこの値で起動するので、人間に確かめて残し、雛形の書き方と理由のコメントにして、一覧に足した（DEF-7.2-18、`b048482`） |
| `bin/setup` | 採用 | DEF-7.2-19 |
| `bin/rubocop`・`bin/brakeman` | 採用しない | 使う場所がなく、`bin/brakeman` の `--ensure-latest` が 2 週間の決まりと食い違う（DEF-7.2-20） |
| `public/406-unsupported-browser.html`・`icon.png`・`icon.svg`（RP・OP） | 採用しない | `allow_browser` と PWA を使わない（DEF-7.2-21） |
| test の `deprecation = :raise`、`filter_parameter_logging.rb` の `:code` とコメント | 戻した | アプリの独自設定（`scripts/restore-app-config`） |
| `active_storage:update` のマイグレーション 3 本（RS） | 採用しない | Active Storage を使わない（DEF-7.0-14。道具で消した） |
| `new_framework_defaults_7_2.rb` | 足した（すべてコメント） | rails-defaults でグループごとに有効にする |

- コミット: RS `55348ca`・RP `bb57416`・OP `e1c65b4`

### `new_framework_defaults_7_2.rb` を有効にした順番

グループと順番は人間が決めた。各グループで、前後に `scripts/compare-config` で 3 アプリの test・development の値を書き出して比べ、すべての設定が新しい値になったことを確かめた（起動の途中の読み込みで効かない設定はなかった）。設定しないと書き出しに出ない 4 つの値（`config.yjit`・`RubyVM::YJIT.enabled?`・`ActiveJob::Base.enqueue_after_transaction_commit`・`ActiveRecord.validate_migration_timestamps`）は、前の書き出しを取る前に `scripts/lib/dump_config.rb` に足した（`70d77d1`。Step 3 の気づきの 18 のとおり、最初に確かめた）。解説への返事の後に、アプリごとにコミットした。項目ごとの解説は [defaults/rails-7.2.md](defaults/rails-7.2.md) の「`load_defaults 7.2`」。

| 順 | グループ | 設定 | 結果 |
|---|---|---|---|
| 1 | 使っていない機能 | `active_job.enqueue_after_transaction_commit`、`active_storage.web_image_content_types`、`active_record.postgresql_adapter_decode_dates` | 値だけが変わる（DEF-7.2-22〜24。`b14e242`・`edbf4c1`・`977dee7`） |
| 2 | マイグレーション | `active_record.validate_migration_timestamps` | 先の日付のマイグレーションはない。E2E 用の DB で `db:migrate:status`・`db:migrate` が通った（DEF-7.2-25。`65e903b`・`6943a9e`・`646888f`） |
| 3 | YJIT | `yjit` | development・test で YJIT が有効になる。結果は同じ（DEF-7.2-26。`fd35cb6`・`c274ef7`・`65f7ead`） |

- グループ 2 で確かめるために E2E 用の DB に `db:migrate` を流すと、RP・OP の `db/schema.rb` が書き出された（OP は見出しの `Schema[7.1]` → `Schema[7.2]`、RP は Rails 6.1 の形 → 7.2 の形）。この設定の変化ではないので戻した。次に RP・OP でマイグレーションを流すと同じ差分が出る（DEF-7.2-25 の補足）
- 3 グループとも、検査と E2E の件数は前と同じで、応答と E2E のスナップショットの差分はない。警告と development だけのヘッダーは、グループ 3 の前後で同じ。手動確認用の環境の 14 ファイルのハッシュは、作業の開始時と同じ

### `load_defaults 7.2`

- 3 アプリを `config.load_defaults 7.2` にし、`new_framework_defaults_7_2.rb` を消した（ステージしない `rm`。Step 3 の気づきの 20）。rails-defaults で一時的に足した設定はほかにない。前（YJIT の後の書き出し）と比べて、3 アプリの test・development の設定の値と起動の途中に読み込み済みの部品は同じ（DEF-7.2-27）
- 雛形にない initializer は `backtrace_silencers.rb` だけ（ほかは 7.2 の雛形にあるものか、アプリの独自のもの）。7.2 の railties が `BACKTRACE` を扱うので消した。RS の test で、ファイルの有無と `BACKTRACE` の有無の 4 通りで、絞り込んだ結果が同じことを確かめた（DEF-7.2-28）
- 解説（DEF-7.2-27・28）に人間の返事を得てから、記録（`3bea7b2`）、RS `8fb6c4a`・RP `305e0e6`・OP `ef7d27c` の順にコミットした。検査と E2E は通り、スナップショットの差分はない
- RuboCop の `TargetRailsVersion` を 7.2 にした（`8b857f5`）。3 アプリとも新しい指摘はない。`RuboCop::ConfigStore` で読む値が 7.2 になることを確かめた。rubocop-rails 2.38.0 に 7.2 を条件にする cop はない（8.0 を条件にする `Rails/StrongParametersExpect` はある）

### 非推奨警告と対応

| 警告 | 対応 |
|---|---|
| （出ていない）Rails 7.2 で activesupport が mutex_m に依存しなくなり、lock から消えると、minitest 5.14.4 の `require "mutex_m"` で Ruby 3.3 の bundled_gems の警告が出る（research で再現した） | 3 アプリの Gemfile の test グループに mutex_m を明示した（作業計画の論点 2）。この Step を通して、`RUBYOPT=-W:deprecated` を付けたテストと eager load の `warning:` は 0 件、DEPRECATION は前からある OP の `auth_time_from_resource_owner`（IMP-011）だけ |

### 意図的な仕様変更

なし。応答のスナップショット・E2E・verify の手動確認で、業務的な挙動の変化は見つからなかった。`app:update` が puma の port を雛形の 3000 にしたのは、URL が変わる（業務的な挙動）ので戻した（DEF-7.2-18）。応答とファイルの変化はすべて既定値・雛形への追随として解説し、人間の返事を得た（[defaults/rails-7.2.md](defaults/rails-7.2.md) の DEF-7.2-01〜29）

### 前後の比較

sqlite3 を上げる前（計画のコミット `9409e95` の後）に次のものを書き出し、3 アプリを上げた後に取り直して比べた。

- sqlite3 2.9.6
  - `scripts/check-apps`: 前後とも 36 の検査がすべて通った（RS 11・RP 33・OP 69 runs、0 failures。`CI=1` も同じ。E2E 10 passed）。応答のスナップショットと E2E のスナップショットの差分はない。各アプリのコミットの前（`commit-per-app`）も同じ
  - `scripts/compare-config dump`（3 アプリ、test・development）: 前を 2 回取って同じことを確かめた。前後で同じ
  - `RUBYOPT=-W:deprecated` を付けた minitest と development の eager load: 前後とも `warning:` は 0 件。DEPRECATION は前後とも OP の IMP-011 だけ
  - SQLite（development、E2E 用の DB）: ライブラリは 3.45.2 → 3.53.2。`journal_mode`（wal）・`synchronous`（1）・`foreign_keys`（1）は同じ
  - E2E 用の DB から書き出した schema.rb（RP・OP）: 前後で同じ。RP の commit 済みの schema.rb は Rails 6.1 の形のままで、書き出すと Rails 7.1 の形になる（前からの状態。OP は Step 3-b で書き出し直した）
  - 雛形と既定値の追随はない。業務的な挙動の変化もない
  - 手動確認用の環境の 14 ファイルのハッシュは、作業の開始時と同じ
- annotaterb（OP）・annotate を外す（RP）。前は sqlite3 の後の書き出し（その後アプリは変わっていない）
  - 旧 rake を消す前に annotaterb を流すと、旧 rake の `require 'annotate'` で `LoadError` になった。旧 rake を消してから流した
  - OP の注釈（E2E 用の DB）: 雛形の既定値のままでも「Model files unchanged」。2 つの値を引き継いで `annotaterb models --force` で書き直させても、`app/models/user.rb`・`test/fixtures/users.yml` の差分はない。`db:migrate --trace` の後に hook が `Annotating models` を流し、差分はない（schema.rb も同じ）
  - `scripts/compare-config dump`（3 アプリ、test・development）: 前後で同じ（RP・OP の development でも、起動の途中に読み込み済みの部品は同じ）
  - `RUBYOPT=-W:deprecated` を付けた minitest と development の eager load: 前後で同じ（`warning:` は 0 件、DEPRECATION は OP の IMP-011 だけ）
  - `scripts/check-apps`（各アプリのコミットの前の `commit-per-app`）: RP 33・OP 69 runs、0 failures（`CI=1` も同じ）、E2E 10 passed。スナップショットの差分はない。RuboCop は、雛形の rake を直す前は 3 つの指摘（`Style/FrozenStringLiteralComment`・`Style/StringLiterals`）、直した後は指摘なし
  - 業務的な挙動の変化はない。手動確認用の環境の 14 ファイルのハッシュは、作業の開始時と同じ
- Rails 7.2.4（rails-lock）。前は annotaterb の後の書き出しと、lock を変える前に取った development だけのヘッダー（2 回取って同じ）・brakeman の JSON・OP のテストのログの行数
  - `scripts/check-apps`: 36 の検査がすべて通った（RS 11・RP 33・OP 69 runs、0 failures。`CI=1` も同じ。E2E 10 passed）。応答のスナップショットと E2E のスナップショットの差分はない。各アプリのコミットの前（`commit-per-app`）も同じ
  - `scripts/compare-config dump`（3 アプリ、test・development）: 26 種類の違いがあり、すべて 6 つ（またはテストの 3 つ）の書き出しに共通。DEF-7.2-05〜10 に振り分けた
  - `RUBYOPT=-W:deprecated` を付けた minitest と development の eager load: 前後で同じ（`warning:` は 0 件、DEPRECATION は OP の IMP-011 だけ）。mutex_m の bundled_gems の警告は出ない
  - development だけのヘッダー（E2E 用の DB で Puma に通した。RS の `/apples/show`、RP のトップ、OP の discovery・ログイン画面。日付・ID・数値と `x-miniprofiler-ids` は伏せた）: RP のトップの Server-Timing に `start_transaction.active_record` が増えただけ（DEF-7.2-04）
  - brakeman: 警告 0、エラー 0、使われない無視の項目 0、チェックの数は同じ（79）。無視した EOLRails は同じ fingerprint で当たり、メッセージが「Rails 7.2.4 ended on 2026-08-09」になった
  - OP のテストのログ: 「Redirected to」行の `code=` が、72 行すべて `[FILTERED]` になった（DEF-7.2-03）。RP のテストのログの「Redirected to」行は変わらない
  - 手動確認用の環境の 14 ファイルのハッシュは、作業の開始時と同じ
- `app:update`（rails-app-update）。前は rails-lock の後の書き出し
  - `scripts/check-apps`: 36 の検査がすべて通った（件数は前と同じ）。応答のスナップショットと E2E のスナップショットの差分はない。各アプリのコミットの前（`commit-per-app`）も同じ
  - `scripts/compare-config dump`: 変わったのは、development・test のメーラーの `default_url_options`（DEF-7.2-13）、development の `annotate_rendered_view_with_filenames`（DEF-7.2-12）、`filter_parameters`・`ActiveRecord::Base.filter_attributes` の `email`（DEF-7.2-16）だけ。test の `public_file_server.enabled` は true のまま（DEF-7.2-14）
  - `RUBYOPT=-W:deprecated` の警告と development だけのヘッダー（本文の長さは伏せている）: 前後で同じ。development の HTML のビューの注釈は、`Rack::MockRequest` で OP のログイン画面（6 個）と RP のトップ（4 個）を数えた
  - 手動確認用の環境の 14 ファイルのハッシュは、作業の開始時と同じ

### 手動確認

verify で、`load_defaults 7.2` と `TargetRailsVersion` の後（`1ee85ff`）に、`.claude/launch.json` から 3 アプリを起動してブラウザペインで確かめた（操作は人間）。3 アプリとも Puma の起動の出力に Rails 7.2.4・Puma 8.0.2・`ruby 3.3.12 … +YJIT`、threads 3 が出た。

- 直前に、3 アプリのサーバーが止まっていて、14 ファイルのハッシュが作業の開始時と同じことを確かめ、3 アプリの development DB の本体と `-wal`（OP・RP）を `tmp/manual_check_backup/` に写した（写しのハッシュは元と同じ。作業計画の論点 5）
- ログイン（RP の my_op）: 人間が「Re Login」を押した。OP の認可エンドポイントが 302、トークン・userinfo・JWKS が 200。OP のログの「Redirected to」行は `code=[FILTERED]`（DEF-7.2-03 を development でも確かめた）
- introspection 用 RP: 同意画面と Authorize の後、RS は正しいトークンで 200、その後 401 が 2 回。RS が受け取った introspect は `active: true`（キーの順は `iat, exp`、`exp - iat = 600`）→ `active: false` が 2 回。Step 4 と同じ
- サーバーの出力: 3 アプリとも warning・DEPRECATION はない。エラーは、元からある RP の `/stylesheets/application.css` と OP の同意画面の `/stylesheets/doorkeeper/application.css` と、プレビューが起動時に開いた RS・OP のトップ（Rails の歓迎ページ）の `/icon.png`。`/icon.png` は 7.2 の歓迎ページがアイコンを読むためで、`public/icon.png` は採用しないままにした（人間が判断。DEF-7.2-21 の補足）。元からあるエラーの一覧を TIPS.md の「手動確認用の環境」に書いた（Step 4 の気づきの 7）
- 手動確認用の環境: 手動確認で、OP の development DB は `oauth_access_grants` が 25 → 27 件、`oauth_access_tokens` が 62 → 67 件（my_op 1・introspection 用 1（revoke 済み）・RS のクライアントクレデンシャル 3）、RP は `sessions` 12 件・`op_users` 1 件のまま。どちらも `integrity_check` は ok で、WAL のまま。サーバーを止めた後、OP・RP の `-wal`・`-shm` がなくなり、中身は本体に移っていた（sqlite3 2.x の閉じ方の変化。DEF-7.2-29）。人間に確かめ、守るファイルから OP・RP の `-wal` を外して 12 にし、手動確認の後の 12 ファイルのハッシュを新しい基準にした（変わったのは OP・RP の DB の本体だけ。RS の DB・署名鍵・`.env`・3 アプリの `tmp/development_secret.txt`・`tmp/local_secret.txt` は変わっていない）。TIPS.md と設定（`.claude/rails-upgrade-project.md`）を直した。写しは、この Step の PR が epic に入った後に、人間に確かめてから消す

### 遭遇した問題

| 問題 | 対応 |
|---|---|
| `app:update` で、RP の `autoload_lib_once` と 3 アプリの puma の port が雛形に上書きされ、`scripts/restore-app-config` で戻らなかった | 差分を読んで見つけ、止まって人間に確かめて戻した。道具の一覧に足した（`b048482`。上の「`app:update` で採用したもの・戻したもの」） |
| グループ 2 を確かめるために E2E 用の DB で `db:migrate` を流すと、RP・OP の `db/schema.rb` が書き出された | この設定の変化ではないので戻した（DEF-7.2-25 の補足） |
| 手動確認の後、OP・RP の `-wal` がなくなり、`-shm` のない WAL の DB の写しを `sqlite3 -readonly` で開けなかった | sqlite3 1.7.3 と 2.9.6 で、準備済みの文を残して終えるスクリプトを比べ、sqlite3 2.x の閉じ方の変化が原因と確かめた（DEF-7.2-29）。写しは `immutable=1` で開いて数えた。守るファイルを 12 にした（人間が判断） |
| `ruby -e` に日本語を書くと `invalid multibyte char`、zsh の `read` で特別な変数 `path` に値を入れると PATH が壊れる | スクリプトをファイルにした。変数の名前を変えた（使い捨てのコマンドだけ） |

### 確認結果

verify で、PLAN.md の 10 章の完了条件を確かめた。

- `scripts/check-apps`（3 アプリと E2E）: HEAD（`1ee85ff`）で 36 の検査がすべて通った。各コミットの前には、そのアプリと E2E で流した
- minitest: RS 11 runs・15 assertions、RP 33・71、OP 69・123、0 failures。`CI=1`（eager load あり）でも同じ
- E2E: 10 passed。応答のスナップショットと E2E のスナップショットの差分は、この Step を通して出なかった。E2E の起動で、E2E 用の DB を `db:drop` → `db:setup`（RS は `db:create`）で作り直している
- RuboCop（`TargetRailsVersion: 7.2`）・`zeitwerk:check`・起動の途中の読み込みの検査（test・`CI=1`・development）・bundler-audit（無視リストは空。解消済みの ID の検査も通る）・brakeman: すべて通った（`check-apps` の項目）。brakeman は 3 アプリとも `Security Warnings: 0`・`Ignored Warnings: 1`（EOLRails。Rails 7.2.4 でも同じ fingerprint）
- lock: epic（`38603d2`）からの動きは、Rails の構成 gem（7.2.4）、sqlite3 2.9.6、tzinfo 2.0.6、増えた useragent 0.16.11、RP の annotate を外したこと、OP の annotate → annotaterb 4.25.0、`DEPENDENCIES` の rails・sqlite3・mutex_m（と annotate の行）だけ。default gem に合わせた版と、一時固定の reline 0.6.0・connection_pool 2.5.5（7.2.4 で固定の理由がなくなった）・faraday-net_http 3.0.2（RS・RP）は動いていない
- `bin/rails c`: `scripts/check-console` で 3 アプリとも起動した（YJIT の有効の後。irb 1.13.1・reline 0.6.0。Tab の補完と複数行の入力ができた）。`bin/rails s`: 手動確認で 3 アプリとも起動した
- 公開物の安全チェック: 各コミットの hooks で通った
- CI: push の後に確かめる（push は人間が行う）。YJIT が CI の Ruby で使えるかも、そのときに CI のログで見る（DEF-7.2-26）
- 手動確認用の環境: 上の「手動確認」。HEAD で、12 ファイルのハッシュが手動確認の後の基準と同じ

### コードレビュー（`/code-review`）

| 指摘 | 対応 |
|---|---|
| development のメーラーの `default_url_options` の port が 3000 で、アプリの port と違う | 直さない。雛形どおりに追随すると決めた（DEF-7.2-13）。3 アプリはメールを送らず使われない。メールを使うときに直すことは DEF-7.2-13 に書いてある（人間が判断） |
| この節の「作業計画からの変更点」に、RP の annotate の件しかない | 直した。道具の追加、puma の port、守るファイル 14 → 12、`/icon.png` の扱いを表に足した（人間が判断） |
| mutex_m の明示は、古い minitest 5.14.4 の回避で、根本は minitest を上げること | 直さない。論点 2 で minitest は間接の gem として上げないと決めた。PLAN.md の 7 章の base64・mutex_m の行に、間接の gem をまとめて上げるときに外せることを足した（人間が判断） |
| `.annotaterb.yml` が gem の既定値を全部書き写していて、後の版の既定値の変化が隠れる | 直さない。generator の雛形に追随すると決めた（DEF-7.2-02）。後の版の既定値の変化は、gem を上げるときに雛形と比べる（人間が判断） |
| puma の port を戻すとき、上のコメントも HEAD のものに戻るので、雛形のコメントの変化が隠れる | 直さない。`restore_setting` は理由のコメントを一緒に戻す作り。下の「スキルについて気づいたこと」の 19 に控えた（人間が判断） |
| `autoload_lib_once` を戻す処理が、`restore_setting` と同じ探し方を書き直している | 直さない。道具の整理は Step 5 の範囲を超える。下の 20 に控えた（人間が判断） |
| DEF-7.2-12 のガイドの出典に、節の番号がない | 直した（3.11.16）（人間が判断） |

- 直した後（文書だけの変更）も、`scripts/check-apps`（3 アプリと E2E）の 36 の検査がすべて通り、件数は同じ。手動確認用の環境の 12 ファイルのハッシュは、手動確認の後の基準と同じ

### スキルについて気づいたこと

Step 3〜4-b と同じく、スキルの手順・型・設定で、足りない・合わない・迷ったところを控える（スキルを直すかは人間が判断する）。この Step は、スキルの見直し（#33）の流れを初めて試す Step でもある。

見直しの流れを試した結果（research まで）:

1. `/rails-upgrade` を引数なしで呼ぶと、resume（ブランチ、手動確認用の環境の控え、PR へのリンクのコミット）から research へ、止まらずに入れた。research は Plan モードを使わず、lock の試行・advisory・警告の再現を scratchpad で行えた
2. 確認のまとめ方: 論点は 5 つで、人間の返事は 6 回（論点 4 の掘り下げの依頼を含む）。前の論点のまとめを次の論点のメッセージに載せたので、まとめへの同意だけの往復はなかった。掘り下げの依頼は同じ論点のまま調べて答え、その後の返事で決めた。最後の論点（5）への返事で、作業計画とダウンロードの承認を取れた。決めた論点は、そのたびに記録に足してコミットした（4 回。論点 5 は計画を移すコミットに入れた）

resume:

3. ローカルの `epic/rails-8.1-upgrade` が origin より古く、#33 の取り込みが入っていなかった。resume の手順 2 は「ブランチを切る」だけで、切る前に epic を origin に合わせる手順がない。今回は fetch して早送りしてから切った

research:

4. Step 3 の気づきの 2（zsh で `--unpin` の値を配列にせずに繰り返すと「不明な引数」になる）に、また当たった
5. Step 3 の気づきの 12（resolve-lock の「消えた gem」に出ない）が、mutex_m でまた起きた。解決した lock を、Gemfile を書き換えたコピーに持ち込んで `bundle lock` するところまで試して見つけ、消えた gem を読むもの（minitest 5.14.4）を探して警告を再現した。resolve-lock の最後に `bundle lock` を流して差分を出せば、research の時点で見える
6. 計画の前提（PLAN.md の 7 章の「Rails 7.1 までは sqlite3 1.x のみ」）が誤っていて、順番が変わった。research の手順 3（周辺 gem の振り分け）は 7 章の時期を前提にしていて、時期の根拠を確かめ直す手順がない。今回はサブエージェントの報告から気づき、gem のソースで確かめた
7. ダウンロードの数え方（Step 4-b の気づきの 2）は、TIPS.md の手順のとおり、解決した lock の gem のうち `vendor/bundle` にないものを数え、手元と CI の置き場所も確かめた。数える道具がないので、scratchpad のスクリプトで行った

gems:

8. gems の手順は「gem を上げる」を想定していて、別の gem に置き換えること（annotate → annotaterb）は書いていない。置き換えでは、古い gem を読むファイル（旧 rake の `require 'annotate'`）を先に消さないと新しい gem の道具が動かず、gem を外したかどうかの比べ方（lock から消える gem、Bundler.require で読まれなくなるもの）も、その場で決めた
9. 計画で決めた範囲（論点 3 の「RP は gem だけ置き換える」）を、理解の関門の質問で人間が見直した（RP では annotate がそもそも不要）。research で gem の使われ方を確かめたが、「置き換える」を前提に範囲を決め、外す案を出さなかった。research の手順 3（周辺 gem の振り分け）に、使っていない gem を外す選択肢がない

rails-lock:

10. Step 3 の気づきの 15 のとおり、development だけのヘッダーの前を rails-lock の始め（lock を変える前）に取り、コミットの前に比べられた。ただし書き出しの道具がなく、Puma に通して毎回変わる値を伏せるスクリプトを scratchpad で作った。`x-miniprofiler-ids` は前の要求の ID が積み上がるので、1 回目の書き出しで 2 回分が食い違い、伏せる対象に足した（Step 3 の記録にある Content-Length の件と同じ原因）
11. `scripts/compare-config diff` の差分は 570 行あり、3 アプリ × 2 環境で同じ違いが繰り返されていた。同じ行をまとめると 26 種類だった。Rails のマイナーを上げると、`load_defaults` を変えなくても設定の値が変わる（非推奨の設定が外れる、クラスに設定が増える）ので、まとめて数える手順か道具があるとよい
12. 解説の項目の出典で、日本語版のガイドの本文を探すのに `ruby -e` へ日本語を書き、Step 4 の「遭遇した問題」と同じく `invalid multibyte char` になった。スクリプトをファイルにして読んだ

rails-app-update:

13. `scripts/restore-app-config` の一覧になかった独自設定が 2 つ（RP の `autoload_lib_once`、3 アプリの puma の port）、雛形に上書きされた。どちらも 7.1 では雛形が変わらなかったので、一覧に足す機会がなかった。手順 3 の「雛形にない独自設定が消えた」に当たり、差分を読んで見つけた。道具の一覧に足すのは手順 2 にあるが、HEAD との差分で独自設定（日本語のコメントや、雛形と違う値）が消えた箇所を機械的に拾う手順はない
14. 解説の材料として、development の HTML を `Rack::MockRequest` で読むときに、zsh の特別な変数 `path`（PATH と結びついている）に `read` で値を入れてしまい、後のコマンドが見つからなくなった（scratchpad の使い捨てのコマンド。TIPS.md の zsh の注意に足す候補）

verify:

15. Step 3 の気づきの 22・23 が、形を変えてまた起きた。手動確認用の DB の形は、Rails だけでなく DB のドライバーの gem（sqlite3 2.x の閉じ方）でも変わる。今回は作業計画で写しを取ると決めていたので、元に戻す選択肢は残っていたが、`-wal` が消えることは見込めず、手動確認の後に止まって確かめた。守るファイルの一覧が gem の振る舞いに依存している
16. 手動確認の操作を頼む前にブラウザペインが見えているかを確かめる手順（manual-check の手順 3）は、ペインが隠れていて、人間に開いてもらう往復が 1 回増えた。人間は開いた後、確かめの返事を待たずに 2 つの流れを済ませた

Step 全体（見直しの流れ）:

17. research の後も、作業の境目（gems → rails-lock → rails-app-update → rails-defaults → rails-load-defaults → verify → pr）では止まらず、「◯◯ が終わった。次は △△ に入る」と示して続けられた。人間の返事は、関門だけだった（research の論点 5 つと掘り下げ 1 回、annotaterb の解説と RP の annotate の掘り下げ、rails-lock・rails-app-update の解説、rails-defaults のグループの順と 3 グループの解説、rails-load-defaults の解説、手動確認の依頼（ペインを開く・操作）、`-wal` と `/icon.png` の論点）。関門の後の質問にも、前の論点のまとめを載せた
18. 理解の関門の解説は、項目ごとの型（種類・何が変わるか・なぜ・影響・提案・出典）で示し、返事の後に defaults/ に記録してから設定のコミットをする流れは、DEF の番号を先に決めてコメントやコミットメッセージから指すのに合っていた。一方で、解説の前に番号を決めてファイルのコメントに書いた（puma の port の DEF-7.2-18）ので、項目を足し引きすると番号がずれる心配があった

コードレビュー:

19. `scripts/restore-app-config` は、戻す設定の上に続くコメントも HEAD のものに戻すので、雛形がそのコメントを変えたときに、戻した後の差分には出ない。rails-app-update の手順 3（差分の振り分け）で、戻す前の差分（`app:update` の直後）も見る手順があるとよい（コードレビューの指摘。直さずに控えた）
20. `scripts/lib/restore_app_config.rb` の `autoload_lib_once` の戻し方は、`restore_setting` と同じ探し方を、雛形側の名前と続く行だけ変えて書き直した。設定ごとに「HEAD の探し方・雛形の探し方・続く行」を渡せる形にまとめられる（コードレビューの指摘。直さずに控えた）

## Step 6: Rails 8.0（2026-10-12）

- ブランチ / PR: `upgrade/step6-rails80` / [#35](https://github.com/thinkAmi-sandbox/oidc_op_rp-sample/pull/35)
- バージョン: Ruby 3.3.12（変更なし）/ Rails 7.2.4 → 8.0.5.1。その直後に RP・OP の web-console 4.2.1 → 4.3.0
- 追随した Rails と gem の既定値・雛形は、[defaults/rails-8.0.md](defaults/rails-8.0.md) に記録した（DEF-8.0-01〜27）。業務的な挙動の変化（B）は起きなかった。bundler-audit の無視リストは空のまま
- Rails 8.0.5.1 には、8-0-stable で直った不具合が 2 つ入っていない（起動の途中の `ActionController::Live` の読み込み（rails/rails#58145）、ルーティングを描く処理の競合（#58225））。前者は検査で 1 件だけ Step 7 まで許した（DEF-8.0-02）。Rails 8.0 のセキュリティ保守は 2026-11-07 まで

### 作業計画で決めたこと

`/rails-upgrade` の research で調べた（サブエージェント 2 つ: Rails 8.0 の事実、周辺 gem の事実。lock の解決と持ち込んだ後の `bundle lock`、advisory、cgi の読み込み、connection_pool、brakeman の EOL の条件と fingerprint、to_time の非推奨、CI の YJIT は自分で確かめた）。論点を 1 つずつ人間と確かめ、決まるたびにこの表に足す。

| 論点 | 決めたこと | 理由 |
|---|---|---|
| 1 lock の解決 | uri は Ruby 3.3.12 の default gem と同じ 0.13.3 に一時固定する（`--pin uri=0.13.3`）。RS・OP で cgi 0.4.2 が lock から消えるのは受け入れ、Gemfile に足さない。上限が外れる connection_pool 2.5.5・minitest 5.14.4・rack 2.2.24 は動かさない | activesupport 8.0.5.1 が `uri >= 0.13.1` を足し、固定しないと 1.1.2 が入る（default gem と同じ名前の依存は default gem の版に固定する。PLAN.md の 7 章・8 章）。cgi は actionpack・actionview・railties 8.0.5.1 が依存から外した（7.2 系は rails/rails#55043 で宣言、8-0-stable は #55102 で cgi から要るものだけを読む形）。resolve-lock の「消えた gem」には出ず、解決した lock を Gemfile を `~> 8.0.5` にしたコピーに持ち込んで `bundle lock --local` して見つけた。lock になくても default gem の同じ版（0.4.2）が読まれ、`-W:deprecated` でも警告は出ない（Step 5 の mutex_m と違う）。RP は activerecord-session_store の依存で残る。3 つの間接の gem は、8.0 で上限（`< 3`・`< 6`・`< 3.3`）が外れるが、lock はそのまま解決する。8.0.5.1 のキャッシュストアは `ConnectionPool.new(**pool_options)` で 3.x でも壊れない（人間が判断） |
| 2 to_time の非推奨 | rails-lock のコミットで、3 アプリの `config/application.rb` に `config.active_support.to_time_preserves_timezone = :zone` を理由のコメント付きで足す。rails-defaults で `new_framework_defaults_8_0.rb` の同じ項目に移し、`load_defaults 8.0` で消す。rails-lock の理解の関門で、DEF-8.0 の項目として解説する → rails-defaults で、移すと test が起動時に止まると分かり、`application.rb` に置いたまま `load_defaults 8.0` で消した（下の「作業計画からの変更点」） | 8.0.5.1 は after_initialize で、値が `:zone` 以外だと非推奨の警告を出す（`activesupport/lib/active_support.rb` の `to_time_preserves_timezone=`、`active_support/railtie.rb` の initializer）。`load_defaults 7.2` のままだと 5.0 の節の `:offset` が入り（`configuration.rb:119`）、test の `deprecation = :raise` で起動時に落ちる見込み。`:raise` を緩める案は非推奨の見落としを防ぐ設定を外すのでとらず、rails-lock と app:update・rails-defaults をまとめる案は 1 コミット 1 理由に反するのでとらない。`:zone` と `:offset` は表す時刻が同じで、違うのは戻り値が保つ情報（夏時間をまたぐ計算で差が出る）。3 アプリの app・config・lib・test に `to_time` はない（人間が判断） |
| 3 brakeman の pending EOL | rails-lock のコミットで、3 アプリの `config/brakeman.ignore` に Medium の `pending_eol_rails`（code 122）の項目を足す（fingerprint は brakeman の実際の出力で確かめる。note に Rails 8.0 の保守が 11-07 までで、Step 7 で 8.1 に上げることを書く）。Step 7 で使われない項目として外す。Step 7 は 11-07 までに epic に入れるのが望ましいことを、PLAN.md の Step 6 の節に書く | brakeman 8.1.0 の Rails 8.0 の EOL は 2026-11-07（`check_eol_rails.rb:28`）。EOL の 30 日前から Medium、60 日前から Low の code 122 を出し、EOL 以降は High の code 120（`eol_check.rb` の `check_eol_version`）。10-12 は 30 日以内なので、8.0.5.1 にした時点で Medium が出て、既定の確信度で check-apps と CI の brakeman が失敗する。fingerprint は「警告コード + code + location + file + confidence」の SHA-256 で、Rails の版は入らない（`warning.rb`）。今の項目（`120nilGemfile.lock0` → `d849…101c`）は計算と一致し、Medium の 122（`98b26f60…db42`）には当たらない。11-07 以降は今の項目で無視される。失敗を受け入れたまま進める案は検査の決まりに反し、確信度を変える案はほかの警告も見えなくなるのでとらない（人間が判断） |
| 4 web-console 4.3.0 | rails-lock の直後に、gems の作業として RP → OP の順に上げる（`bundle lock --update web-console --conservative`）。Gemfile の `'>= 4.1.0'` は変えない。許す IP の変化は、gem の既定値の変化として理解の関門で解説する | 4.3.0 は railties・actionview `>= 8.0` で、Rails 8.0.5.1 の後でないと入らない（4.2.1 も 8.0 を許す）。7 章の振り分けの 2（新しい Rails を必要とする gem は、Rails と同時か直後）に当たり、Step 3 の rack-mini-profiler 5.0.0 と同じ置き方。変化は development の例外画面のコンソールだけ（常に許す IP に `::ffff:127.0.0.0/104`、閉じるボタンの文字、8.1 より後で使う `first_non_proxy`。railtie・ミドルウェアの位置・IMP-009 の早い読み込みは同じ）。activemodel の依存が外れ、bindex は同じ版なので、落とすのは web-console 4.3.0 だけ（人間が判断） |
| 5 rubocop・webmock | Step 6 では上げない。次の Step（7）の research で、その時点の最新版と、公開から 2 週間たっているかを、もう一度確かめる（Step 5 と同じ決め方） | 10-12 の時点で、rubocop 1.92.0（10-10）・webmock 3.27.0・3.28.0（10-10）・3.29.0（10-11）は 2 週間たっていない（10-24・10-25）。Step 5 の時点から新しい版は出ていない。1.92.0 は `Lint/UselessAssignment` の新しい指摘（#14666）がありうる。webmock の 3.28.0 の破壊的な変更（`to_rack`）と Unreleased（RSpec の `have_been_requested.with`、#1128）は 3 アプリに当たらない。AI は、日付に結び付けた別のサブステップ（10-25 の後）を案にした（Step 7 の research が 10-24 より前に始まると、また送りになるため）。人間は、Step 7 の時期がまだ決まっていないので、次の Step の research で確かめる案にした。2 週間の決まりの例外にする案は、開発・テスト用の道具で advisory もなく急がないのでとらない（人間が判断） |
| 6 手動確認の時期 | verify で 1 回（`load_defaults 8.0` と `TargetRailsVersion` 8.0 の後）。RP の my_op のログインと introspection 用 RP の流れ、OP の「Redirected to」行の `code=`、サーバーの出力のエラー（TIPS.md の元からあるエラーの一覧と比べる）を見る。直前に、12 ファイルのハッシュが作業の開始時と同じことを確かめ、3 アプリの `development.sqlite3`（今は `-wal` がない）を `tmp/manual_check_backup/` に写す。Step 5 の写しは、research の出口で消す | Rails 8.0 で SQLite のトランザクションが `BEGIN immediate TRANSACTION` になり、`timeout` の扱いと接続の引数（`default_transaction_mode`）が変わる。web-console 4.3.0 は development だけで動く。DB のファイルの形は変わらない見込みだが、Step 3（7.1 で WAL）・Step 5（sqlite3 2.x で `-wal` が消えた）では、手動確認の後に初めて形の変化が分かったので、元に戻す選択肢を残す。Step 5 の写しは、#34 が epic に入ったので消してよい（TIPS.md の「手動確認用の環境」）。この論点への返事で、作業計画（ダウンロードの確認を含む）の承認と、Step 5 の写しを消すことの承認も得た（人間が判断） |

- 上げないもの: rubocop・webmock（論点 5）、connection_pool・minitest・rack（論点 1）、7.2 系のパッチ（7.2.4 が最新）
- 採用しないもの: `app:update` の Solid 系（`config/puma.rb` の `plugin :solid_queue`）。Kamal・Solid の設定ファイルと `bin/thrust` は `app:update` では作られない
- ダウンロード: Rails の構成 gem 8.0.5.1 の 13 個・uri 0.13.3・web-console 4.3.0（計 1,936,384 B）。各 `.gem` は 1 回だけ落とし、照合してほかのアプリのキャッシュにコピーする。作業計画で示し、論点 6 への返事で承認を得た
- 調べたことの一覧と決めたことの全体は、PLAN.md の 6 章の「Step 6: Rails 8.0」に書いた。7 章の web-console・rubocop・webmock・connection_pool・rack・cgi の行を直し、uri の行を足した。8 章の 4 と TIPS.md の「gem の更新」の default gem の一覧に uri を足した

### 作業計画からの変更点

| 変更 | 理由 |
|---|---|
| Rails 8.0.5.1 自身の起動の途中の読み込み（initializer `action_controller.live_streaming_excluded_keys` が `ActionController::Live`・`ActionDispatch::Response` を読み込む）を、検査で 1 件だけ Step 7 まで許すことにした。`scripts/check-load-hooks` を足し、check-apps と CI から呼ぶ（`9a53b51`） | rails-lock で、3 アプリの「起動の途中の読み込み」が test・`CI=1`・development で失敗した（research では見つけていなかった）。Rails の不具合（rails/rails#58145）で、8-0-stable の修正（#58276）は 8.0.5.1 に入っていない。自前のパッチは保守ができなくなるのでとらず（人間が判断）、未リリースの 8-0-stable・修正の入らない 8.0.4.1 もとらず、許す範囲を検出の hook と版・行で 1 件に絞った。隠れる分は、各作業の前後の compare-config の「読み込み済みの部品」で補う（DEF-8.0-02。人間が判断） |
| `to_time_preserves_timezone` は、rails-defaults で `new_framework_defaults_8_0.rb` に移さず、`config/application.rb` に置いたまま `load_defaults 8.0` で消すことにした（論点 2 では移すとしていた）。rails-defaults のグループ 1 は、application.rb と defaults のファイルのコメントを直すだけにした | 移すと 3 アプリの test が起動時に止まった。initializer `active_support.set_configs` は config/initializers より前に走り、その時点の `:offset` で非推奨の警告を出す（`activesupport-8.0.5.1/lib/active_support/railtie.rb:125-130`）。defaults のファイルの値が効かない不具合（rails/rails#54015）は #54017 で直ったが、警告は残っている。「application.rb で設定する」とガイドに書く #54449 はマージされずに閉じた。test の `:raise` を緩める案、2 か所に書く案はとらない（人間が判断。DEF-8.0-01） |
| rails-defaults のグループ 2（`action_dispatch.strict_freshness`）は、defaults のファイルで有効にせず、理由のコメントを付けてコメントのまま残した。値の変化は rails-load-defaults で確かめる | defaults のファイルで有効にしても、`ActionDispatch::Http::Cache::Request.strict_freshness` は false のままだった。ActionDispatch の railtie の initializer `action_dispatch.configure`（`actionpack-8.0.5.1/lib/action_dispatch/railtie.rb:79`）が、config/initializers より前に値を入れる（8-0-stable・8.1.4・main も同じ。Rails の Issue・PR に報告は見当たらない）。`load_defaults 8.0` なら入る。OP の `config/application.rb` に一時的に置いて効かせても、discovery への条件付きの要求 4 通り（`If-None-Match`・`If-Modified-Since` の組み合わせ）の応答は 200・304・304・200 で前と同じだった（ETag と 304 は `Rack::ETag`・`Rack::ConditionalGet` が出し、この設定は Rails の `request.fresh?` だけに効く）。一時的な設定を `application.rb` に足す案、効かないまま有効にする案はとらない（人間が判断） |

### 手動確認用の環境

作業の開始時（ブランチを切って最初のコミットの前）に、3 アプリのサーバーが止まっていることを確かめ、12 ファイルのハッシュを控えた（前のセッションの控えは残っていないので、これを Step 6 の基準にする）。development DB に `-wal` はなく、件数は本体を scratchpad にコピーして `immutable=1` で開いて数え、Step 5 の手動確認の後と同じだった（OP `oauth_access_grants` 27・`oauth_access_tokens` 67、RP `sessions` 12・`op_users` 1。どちらの DB も `integrity_check` は ok）。最初のコミット（Step 5 の PR へのリンク）の後も、12 ファイルのハッシュは同じ。research の出口で、Step 5 の手動確認の前に取った 3 アプリの `tmp/manual_check_backup/`（OP・RP は本体と `-wal`、RS は本体）を、人間に確かめて消した。消した後も 12 ファイルのハッシュは同じ


### gem ごとの対応

| gem | バージョン | 対応 |
|---|---|---|
| Rails | 7.2.4 → 8.0.5.1 | 3 アプリ（rails-lock）。7.2.4 は 7.2 系の最新なので、先に上げるパッチはなかった。`scripts/resolve-lock --gem 'rails=~> 8.0.5' --rails --pin uri=0.13.3` で解決した lock を持ち込み、Gemfile の rails を `~> 8.0.5` にして `bundle lock --local`（research で試した結果と同じ lock になった）。動いたのは Rails の構成 gem 13 個だけ。RS の `bundle install` で落としたのは 14 個（Rails の構成 gem 13・uri）だけで、`scripts/verify-gem-checksums` ですべて rubygems.org の SHA-256 と一致した。RP・OP は照合した `.gem` をキャッシュにコピーして `--local` で入れた（`Installing` の 14 行だけ。照合も一致）。3 アプリの `config/application.rb` に `to_time_preserves_timezone = :zone` を理由のコメント付きで足した（作業計画の論点 2。DEF-8.0-01）。3 アプリの `config/brakeman.ignore` に、Medium の `pending_eol_rails` の項目を足した（論点 3。fingerprint は brakeman の出力で `98b26f60…db42`、計算と一致）。DEF-8.0-01〜08（`5af2f8e`・`f0813df`・`8815d79`） |
| uri | （なし）→ 0.13.3 | activesupport 8.0 の `uri >= 0.13.1`。Ruby 3.3.12 の default gem と同じ版に一時固定した（論点 1。Rails 8.0.5.1 と同じコミット） |
| cgi | 0.4.2 → （なし）（RS・OP） | actionpack・actionview・railties 8.0 が依存から外し、RS・OP の lock から消えた（論点 1。受け入れた）。RP は activerecord-session_store の依存で 0.4.2 のまま |
| connection_pool・minitest・rack | 2.5.5・5.14.4・2.2.24（変更なし） | 8.0 で上限が外れたが、lock は動いていない（論点 1） |
| web-console | 4.2.1 → 4.3.0（RP・OP） | Rails 8.0.5.1 の直後（論点 4）。RP は `bundle lock --update web-console --conservative` と `bundle install`（`Fetching` は web-console 4.3.0 だけ）。OP は `--local` を付けると、ほかのプラットフォームの sqlite3 が手元になく解決できなかったので、付けずに lock を書き、RP で照合した `.gem` をキャッシュにコピーして `--local` で入れた（`Installing` は web-console だけ）。lock で動いたのは web-console の行だけ（依存から activemodel が外れ、bindex は同じ）。`scripts/verify-gem-checksums` で 2 アプリとも一致した。前後で、compare-config の設定の値と読み込み済みの部品（3 アプリの test・development）、警告、brakeman、development だけのヘッダーは同じ。Gemfile の `'>= 4.1.0'` は変えていない。DEF-8.0-09・10（`587b8f8`・`e68426d`） |

### `app:update` で採用したもの・戻したもの

3 アプリで `yes a | bin/rails app:update`（DB は E2E 用）を流し、戻す前の差分を控えてから `scripts/restore-app-config` で独自設定を戻し、差分を人間が確かめた。項目ごとの解説は [defaults/rails-8.0.md](defaults/rails-8.0.md) の「`app:update` の雛形」。

| ファイル | 判断 | 理由 |
|---|---|---|
| 環境のファイルのコメント、`cache-control` の小文字、test.rb の先頭の require | 採用 | 書き方だけ（DEF-8.0-11） |
| development の `cache_store` が常に `:memory_store` | 採用 | キャッシュを使っていない（DEF-8.0-12） |
| development の `query_log_tags_enabled = true` | 採用 | development のログだけ（DEF-8.0-13） |
| development・test の `disallowed_deprecation` の 2 行の削除 | 採用 | 一覧が空で、効き目がなかった（DEF-8.0-14） |
| test の `perform_caching = false` の 2 行の削除 | 採用 | cache_store が `:null_store` のまま（DEF-8.0-15） |
| test のメーラーの host が `example.com` | 採用 | メールを送らない（DEF-8.0-16） |
| `filter_parameter_logging.rb` の `:cvv`・`:cvc` | 採用 | ログと `inspect` だけ（DEF-8.0-17） |
| `config/puma.rb` のコメント | 採用（port は道具で戻した） | DEF-8.0-18 |
| `config/puma.rb` の `plugin :solid_queue` | 採用しない | 新しい構成（DEF-8.0-19） |
| `bin/setup` の変化と `bin/dev` | 採用 | DEF-8.0-20 |
| `bin/rubocop`・`bin/brakeman` | 採用しない | DEF-7.2-20 と同じ（DEF-8.0-21） |
| public の 404・422・500 の作り直しと `400.html`（RP・OP） | 採用 | production だけで使う（DEF-8.0-22） |
| `public/406-unsupported-browser.html`・`icon.png`・`icon.svg`（RP・OP） | 採用しない | DEF-7.2-21 と同じ（DEF-8.0-23） |
| production.rb | 採用 | 雛形に追従するだけ（DEF-8.0-24） |
| test の `deprecation = :raise`、puma の port、`filter_parameter_logging.rb` の `:code` とコメント、RP の `autoload_lib_once` と inflector | 戻した | アプリの独自設定（`scripts/restore-app-config`。戻せない項目はなかった） |
| `config/application.rb` の `to_time_preserves_timezone = :zone` | 手で戻した | rails-lock で足した一時的な設定（DEF-8.0-01。作業計画の論点 2）。雛形に上書きされた。rails-defaults で移すので、道具の一覧には足していない |
| `active_storage:update` のマイグレーション 3 本 | 採用しない | Active Storage を使わない（DEF-7.0-14。道具で消した） |
| `new_framework_defaults_8_0.rb` | 足した（すべてコメント） | rails-defaults でグループごとに有効にする |

- 戻す前の差分で、戻した設定（puma の port、test の deprecation）の上の雛形のコメントが 7.2.4 から変わっていないことを確かめた（Step 5 の気づきの 19）
- コミット: RS `ae985e1`・RP `22533d5`・OP `72960a1`

### `new_framework_defaults_8_0.rb` を有効にした順番

グループと順番は人間が決めた。前の書き出しを取る前に、`scripts/lib/dump_config.rb` に、クラスの値が書き出しに出ない 2 つの値（`ActionDispatch::Http::Cache::Request.strict_freshness`・`Regexp.timeout`）を足した（`5e3f661`。前の書き出しは 2 回取って同じ）。各グループで、前後に `scripts/compare-config` で 3 アプリの test・development の値を書き出して比べた。項目ごとの解説は [defaults/rails-8.0.md](defaults/rails-8.0.md) の「`load_defaults 8.0`」。

| 順 | グループ | 設定 | 結果 |
|---|---|---|---|
| 1 | 移すだけ | `active_support.to_time_preserves_timezone` | defaults のファイルに移すと、test が起動時に止まった（`active_support.set_configs` が config/initializers より前に古い値で警告を出す）。`config/application.rb` に置いたまま、コメントを直し、defaults のファイルに理由のコメントを足した（人間が判断。DEF-8.0-01。`68c91e2`・`804690b`・`642e3f0`） |
| 2 | 条件付きの GET | `action_dispatch.strict_freshness` | defaults のファイルで有効にしても、値が入らなかった（`action_dispatch.configure` が config/initializers より前に値を入れる）。理由のコメントを付けてコメントのまま残し、`load_defaults 8.0` で確かめる（人間が判断。`456a5b0`・`5bfd79d`・`22adc1e`） |
| 3 | プロセス全体 | `Regexp.timeout` | `nil` → `1.0`。ほかの値・検査・警告・development だけのヘッダーは同じ。ログに `Regexp::TimeoutError` はない（DEF-8.0-25。`9b7c580`・`c43f8d8`・`33b4471`） |

- 3 グループとも、検査と E2E の件数は前と同じで、応答と E2E のスナップショットの差分はない。読み込み済みの部品は同じ（DEF-8.0-02 で許した検出の後ろに、新しい読み込みは増えていない）。手動確認用の環境の 12 ファイルのハッシュは、作業の開始時と同じ

### `load_defaults 8.0`

- 3 アプリを `config.load_defaults 8.0` にし、`new_framework_defaults_8_0.rb` と、`config/application.rb` の一時的な `to_time_preserves_timezone`（DEF-8.0-01）を消した（ステージしない `rm`）。前（グループ 3 の後の書き出し）と比べて、値で変わったのは `action_dispatch.strict_freshness`（`ActionDispatch::Http::Cache::Request.strict_freshness`）の false → true だけ。`to_time_preserves_timezone` は `:zone`、`Regexp.timeout` は `1.0` のまま。読み込み済みの部品は同じ。OP の discovery への条件付きの要求 4 通りは、前後とも 200・304・304・200（DEF-8.0-26）
- 雛形にない initializer は、RP・OP の `permissions_policy.rb` だけ（すべてコメントで、7.2.4 の雛形と同じ。8.0 の雛形から外れた）。消した（DEF-8.0-27）。ほかは 8.0 の雛形にあるもの（`content_security_policy.rb`・`filter_parameter_logging.rb`・`inflections.rb`）か、アプリの独自のもの
- 解説（DEF-8.0-26・27）に人間の返事を得てから、記録（`c535756`）、RS `c5d02ae`・RP `2617461`・OP `edc7394` の順にコミットした。検査と E2E は通り、スナップショットの差分はない
- RuboCop の `TargetRailsVersion` を 8.0 にした（`ecbb970`）。3 アプリとも新しい指摘はない。`RuboCop::ConfigStore` で読む値が 8.0 になることを確かめた。rubocop-rails 2.38.0 で 8.0 を条件にする cop は `Rails/StrongParametersExpect` だけで、pending のまま無効（`NewCops: disable`）

### 非推奨警告と対応

| 警告 | 対応 |
|---|---|
| Rails 8.0 は `to_time_preserves_timezone` が `:zone` でないと非推奨の警告を出し、`load_defaults 7.2` の `:offset` のままでは、test の `deprecation = :raise` で起動時に止まった（initializer `active_support.set_configs`、`activesupport-8.0.5.1/lib/active_support/railtie.rb:128`） | `config/application.rb` で `:zone` を先に取り込んだ（DEF-8.0-01）。その後、`RUBYOPT=-W:deprecated` を付けたテストと eager load の `warning:` は 0 件、DEPRECATION は前からある OP の `auth_time_from_resource_owner`（IMP-011）だけ |

### 意図的な仕様変更

なし。応答のスナップショット・E2E・verify の手動確認で、業務的な挙動の変化は見つからなかった。応答とファイルの変化はすべて既定値・雛形への追随として解説し、人間の返事を得た（[defaults/rails-8.0.md](defaults/rails-8.0.md) の DEF-8.0-01〜27）。手動確認で見つかった起動の直後の RoutingError は、Rails の不具合で development の起動直後だけに起きる（DEF-8.0-03 の補足）

### 前後の比較

lock を変える前（`5359cc2` の後）に次のものを書き出し、3 アプリを上げた後に取り直して比べた。前の `scripts/compare-config dump` と development だけのヘッダーは 2 回取って同じことを確かめた。

- Rails 8.0.5.1（rails-lock）
  - `scripts/check-apps`: 前は 36 の検査がすべて通った（RS 11・RP 33・OP 69 runs、0 failures。`CI=1` も同じ。E2E 10 passed）。後は、3 アプリの「起動の途中の読み込み」の 9 項目が失敗した（DEF-8.0-02。上の「作業計画からの変更点」）。`scripts/check-load-hooks` にした後は 36 の検査がすべて通り、件数は同じ。応答のスナップショットと E2E のスナップショットの差分はない。各アプリのコミットの前（`commit-per-app`）も同じ
  - `scripts/compare-config dump`（3 アプリ、test・development）: 違いは DEF-8.0-01〜08 に振り分けた（`to_time_preserves_timezone`、読み込み済みの部品の `action_dispatch_response` とルーティングの遅れ、`enqueue_after_transaction_commit`、消えた 2 つの設定、`QueryLogs.tags_formatter`、パラメーターの解析の 2 つの設定）。ほかに `strict_freshness = false` が増えた（rails-defaults で扱う）
  - `RUBYOPT=-W:deprecated` を付けた minitest と development の eager load: 前後で同じ（`warning:` は 0 件、DEPRECATION は OP の IMP-011 だけ）
  - development だけのヘッダー（E2E 用の DB で Puma に通した。RS の `/apples/show`、RP のトップ、OP の discovery・ログイン画面。日付・ID・数値・`x-miniprofiler-ids` などは伏せた）: 前後で同じ
  - brakeman: 無視の項目を足す前は、3 アプリとも Medium の `pending_eol_rails`（「Support for Rails 8.0.5.1 ends on 2026-11-07」）で終了コード 3。足した後は警告 0、無視 1、チェックの数は同じ（79）。今ある High の EOLRails の項目は、11-07 まで当たらない
  - SQLite のトランザクション: RP・OP の test.log で、アプリの書き込みが `BEGIN immediate TRANSACTION`、transactional fixtures が `BEGIN deferred TRANSACTION` になった（DEF-8.0-04）
  - 手動確認用の環境の 12 ファイルのハッシュは、作業の開始時と同じ
- web-console 4.3.0（gems）。前は rails-lock の後の書き出し
  - `scripts/compare-config dump`（設定の値と読み込み済みの部品）、警告、brakeman、development だけのヘッダー: 前後で同じ。検査と E2E は、各アプリのコミットの前（`commit-per-app`）に通った（RP 33・OP 69 runs、E2E 10 passed）
- `app:update`（rails-app-update）。前は web-console の後の書き出し（その後アプリは変わっていない）
  - `scripts/check-apps`: 36 の検査がすべて通った（件数は前と同じ）。応答のスナップショットと E2E のスナップショットの差分はない。各アプリのコミットの前（`commit-per-app`）も同じ
  - `scripts/compare-config dump`: 変わったのは、development の `cache_store`（`Rails.cache` を含む。DEF-8.0-12）と query log tags（DEF-8.0-13）、`disallowed_deprecation` の 2 つの設定（DEF-8.0-14）、test の `perform_caching` の設定（DEF-8.0-15。クラスの値は書き出しに出ないので runner で確かめた）、test のメーラーの host（DEF-8.0-16）、`filter_parameters`・`filter_attributes` の `cvv`・`cvc`（DEF-8.0-17）だけ。読み込み済みの部品は同じ（DEF-8.0-02 で許した検出の後ろに、新しい読み込みは増えていない）
  - `RUBYOPT=-W:deprecated` の警告、brakeman、development だけのヘッダー: 前後で同じ
  - 手動確認用の環境の 12 ファイルのハッシュは、作業の開始時と同じ
- rails-defaults・rails-load-defaults。前はそれぞれ直前の書き出し。結果は上の「`new_framework_defaults_8_0.rb` を有効にした順番」「`load_defaults 8.0`」（変わった値は `Regexp.timeout`・`strict_freshness` だけ。読み込み済みの部品・警告・brakeman・development だけのヘッダーは同じ）

### 手動確認

verify で、`load_defaults 8.0` と `TargetRailsVersion` の後（`8ec70d3`）に、`.claude/launch.json` から 3 アプリを起動してブラウザペインで確かめた（操作は人間）。3 アプリとも Puma の起動の出力に Puma 8.0.2・`ruby 3.3.12 … +YJIT`・threads 3 が出た。

- 直前に、3 アプリのサーバーが止まっていて、12 ファイルのハッシュが作業の開始時と同じことを確かめ、3 アプリの development DB の本体（`-wal` はない）を `tmp/manual_check_backup/` に写した（写しのハッシュは元と同じ。作業計画の論点 6）
- ログイン（RP の my_op）: 人間が「Re Login」を押した（OP のセッションが残っていて、パスワードは求められなかった）。OP の認可エンドポイントが 302、トークン・userinfo・JWKS が 200。OP のログの「Redirected to」行は `code=[FILTERED]`
- introspection 用 RP: 同意画面と Authorize の後、RS は正しいトークンで 200、その後 401 が 2 回。RS が受け取った introspect は `active: true`（`exp - iat = 600`）→ `active: false` が 2 回。Step 5 と同じ
- サーバーの出力: 3 アプリとも warning・DEPRECATION はない。SQL のログに query log tags のコメントが付いた（DEF-8.0-13）。エラーは、元からある RP の `/stylesheets/application.css`・OP の `/stylesheets/doorkeeper/application.css`・OP の歓迎ページの `/icon.png` と、プレビューが起動の直後に同時に送った `HEAD "/"`・`GET "/"` の片方の `ActionController::RoutingError`（3 アプリ。RS は `GET`、RP・OP は `HEAD`）。後者は、Rails 8.0 のルーティングを最初の要求まで描く仕組みが、スレッドに対して安全でないため（rails/rails#58225 で直り、8.1.4 に入っている。8.0.5.1 にはない）。描き終わった後は、RS・OP の `HEAD`・`GET` とも 200。業務的な挙動ではないとして、DEF-8.0-03 の補足と TIPS.md の元からあるエラーの一覧に書いた
- 手動確認用の環境: OP の development DB は `oauth_access_grants` が 27 → 29 件、`oauth_access_tokens` が 67 → 72 件（my_op 1・introspection 用 1（revoke 済み）・RS のクライアントクレデンシャル 3。revoke 済みは 12 → 13）、RP は `sessions` 12 件・`op_users` 1 件のまま。どちらも `integrity_check` は ok。サーバーを止めた後、`-wal` は残っていない。ファイルの見出しは WAL のまま（`immutable=1` で開くと `journal_mode` は `delete` と出るので、見出しの 18・19 バイト目で確かめた）。変わったのは OP・RP の DB の本体だけで、RS の DB・署名鍵・`.env`・3 アプリの secret は変わっていない。手動確認の後の 12 ファイルのハッシュを新しい基準にした。写しは、この Step の PR が epic に入った後に、人間に確かめてから消す

### 遭遇した問題

| 問題 | 対応 |
|---|---|
| 3 アプリの「起動の途中の読み込み」が失敗した（`on_load(:action_dispatch_response)`。疑わしい行は `railties-8.0.5.1/lib/rails/initializable.rb:32`） | `ANTI_MANNER_DEBUG` のスタックトレースで、Rails 8.0.5.1 の initializer `action_controller.live_streaming_excluded_keys` が原因と分かった。8-0-stable の修正を一時的に `vendor/bundle` に当てて、ほかの検出がないことを確かめ（当てたファイルは戻した）、検査で 1 件だけ許した（上の「作業計画からの変更点」、DEF-8.0-02） |
| `to_time` の非推奨の警告が、research の見立て（after_initialize）より前の initializer `active_support.set_configs` で出た | 対処は見立てどおり（DEF-8.0-01）。記録の出典を実際の位置に直した |
| bundle-audit の `--gemfile-lock` の使い方を誤り、無視リストなしの検査が 0 件に見えた（research） | 古い lock で advisory が出ることを確かめてから、ディレクトリを渡す形で流し直した |
| `ruby -e` に日本語を書くと `invalid multibyte char`（research で PLAN.md を直すとき） | スクリプトをファイルにした（Step 4・5 と同じ） |
| プレビューが起動の直後に同時に送る `HEAD "/"`・`GET "/"` の片方が `ActionController::RoutingError` になった（手動確認） | 描き終わった後は 200 になることを確かめ、Rails の `RoutesReloader` がスレッドに対して安全でないこと（rails/rails#58225）が原因と分かった。業務的な挙動ではないので、DEF-8.0-03 の補足と TIPS.md に書いた |
| `git log -n` を `git commit` と同じコマンドに書くと、安全チェックの hook が `-n` を `git commit -n` と見て止めた | コマンドを分けた |

### 確認結果

verify で、PLAN.md の 10 章の完了条件を確かめた。

- `scripts/check-apps`（3 アプリと E2E）: `TargetRailsVersion` 8.0 のコミットの前に 36 の検査がすべて通った（その後は文書だけ）。各コミットの前には、そのアプリと E2E で流した。起動の途中の読み込みは、Step 7 まで `scripts/check-load-hooks` で Rails 8.0.5.1 自身の 1 件だけを許している（DEF-8.0-02）
- minitest: RS 11 runs・15 assertions、RP 33・71、OP 69・123、0 failures。`CI=1`（eager load あり）でも同じ
- E2E: 10 passed。応答のスナップショットと E2E のスナップショットの差分は、この Step を通して出なかった
- RuboCop（`TargetRailsVersion: 8.0`）・`zeitwerk:check`・起動の途中の読み込みの検査（test・`CI=1`・development）・bundler-audit（無視リストは空）・brakeman: すべて通った（`check-apps` の項目）。brakeman は 3 アプリとも `Security Warnings: 0`・`Ignored Warnings: 1`（Medium の `pending_eol_rails`。High の EOLRails の項目は 11-07 まで当たらない）
- lock: epic（`4b8e5c8`）からの動きは、Rails の構成 gem（8.0.5.1）、増えた uri 0.13.3（一時固定）、RS・OP から消えた cgi 0.4.2、RP・OP の web-console 4.3.0、`DEPENDENCIES` の rails だけ。default gem に合わせた版と、一時固定の reline 0.6.0・connection_pool 2.5.5・faraday-net_http 3.0.2（RS・RP）は動いていない
- `bin/rails c`: `scripts/check-console` で 3 アプリとも起動した（irb 1.13.1・reline 0.6.0。Tab の補完と複数行の入力ができた）。`bin/rails s`: 手動確認で 3 アプリとも起動した
- 公開物の安全チェック: 各コミットの hooks で通った
- CI: push の後に確かめる（push は人間が行う）。`scripts/check-load-hooks` を呼ぶ CI の 2 つのステップが、許した 1 件で通ることも、そのときに見る
- 手動確認用の環境: 上の「手動確認」。HEAD で、12 ファイルのハッシュが手動確認の後の基準と同じ

### コードレビュー（`/code-review`）

| 指摘 | 対応 |
|---|---|
| `scripts/check-load-hooks` は、許していない検出のときも `ANTI_MANNER_DEBUG` の表示（スタックトレースが 1 行の配列）だけを出すので、疑わしい行が読みにくい | 直した。許していない検出のときは、`ANTI_MANNER_DEBUG` なしでもう一度流して gem の短い表示（疑わしい行）を先に出し、その後にスタックトレース全体を出す（人間が判断） |
| 許す条件が `actionpack-8.0.5.1/...railtie.rb:35:` に固定なので、Step 7 の前に 8.0 系のパッチに上げると、また失敗する | 安全側に倒れる（失敗する）のは意図どおり。スクリプトの KNOWN の説明に、パッチに上げたら同じ initializer による検出かを確かめて `KNOWN_LINE` を直すことを書いた（人間が判断） |
| この節の「作業計画で決めたこと」の論点 2 の行が、「rails-defaults で移す」のまま | 直した。行の末尾に、移せなかったことと「作業計画からの変更点」への参照を足した（人間が判断） |
| `scripts/compare-config` は、設定のキーが消えるとクラスの値も出さない（test の `perform_caching` の false → true が書き出しの差分に出なかった） | 直さない。道具の作りの話で、Step 6 では runner で確かめて記録した（DEF-8.0-15、下の気づきの 14）。スキル・道具の見直しで扱う（人間が判断） |
| `bin/setup` は development の DB に `db:prepare` を流したうえで、サーバーも起動するようになった。手動確認用の DB を守ることが、スクリプトに書かれていない | 直さない。`db:prepare` は前からあり、DEF-8.0-20 に書いた。雛形のファイルに独自のコメントを足すと、次の `app:update` で上書きされ、`restore-app-config` の一覧も増える。README の仕上げ（PLAN.md の「仕上げ」）で、手動確認用の環境と一緒に書く（人間が判断） |

- 直した後も、`scripts/check-apps`（3 アプリと E2E）の 36 の検査がすべて通り、件数は同じ。手動確認用の環境の 12 ファイルのハッシュは、手動確認の後の基準と同じ

### スキルについて気づいたこと

Step 3〜5 と同じく、スキルの手順・型・設定で、足りない・合わない・迷ったところを控える（スキルを直すかは人間が判断する）。

resume:

1. ローカルの `epic/rails-8.1-upgrade` が origin より 49 コミット古く、#34 の取り込みが入っていなかった（Step 5 の気づきの 3 と同じ）。resume の手順 2 に、切る前に epic を origin に合わせる手順がない。今回は人間の指示にあったので、fetch して早送りしてから切った
2. 手動確認用の環境の 12 ファイルを、空白で区切った文字列の変数で `shasum` に渡すと、zsh は単語に分けずに 1 つの名前として渡し、失敗した（配列にして直した。Step 3 の気づきの 2 と同じ zsh の性質）

research:

3. resolve-lock の「消えた gem」に出ずに lock から消える gem が、また出た（RS・OP の cgi 0.4.2）。Step 3 の method_source、Step 5 の mutex_m に続いて 3 回目。Step 5 の気づきの 5 のとおり、持ち込んだ後の `bundle lock` まで試して見つけた
4. bundle-audit の `--gemfile-lock` に別のディレクトリの lock を渡す使い方を誤り、無視リストなしの検査で 0 件に見えた。advisory の残る古い lock で出ることを確かめてから、ディレクトリを渡す形に直した。「出ない」ことを確かめる検査は、出るはずの入力で先に確かめる必要がある
5. scratchpad では、mise がディレクトリの `.ruby-version` を読まない（`mise.toml` の trust がない）。`mise exec ruby@3.3.12 --` で版を渡した
6. CI の YJIT は、CI のログからは分からず（`ruby -v` は Rails の前の表示）、ruby-builder のビルドのログ（configure の `YJIT support: yes`）で確かめた。実行時に有効かを CI で見るには、CI に表示を足す必要がある
7. 2 週間の決まりで送った gem（rubocop・webmock）は、「次の Step の research で確かめる」と決めると、Step の間隔が短いとまた送りになる。日付に結び付ける案を出したが、人間は Step 7 の時期が決まっていないので、Step に結び付けたままにした（論点 5）
8. Step 5 の気づきの 12 と同じく、PLAN.md を直すスクリプトを `ruby -e` に日本語で書いて `invalid multibyte char` になった。スクリプトをファイルにした

rails-lock:

9. research は lock の解決と advisory まで試したが、新しい Rails でアプリを起動する検査（起動の途中の読み込み）は流さなかったので、Rails 8.0.5.1 自身の読み込み（DEF-8.0-02）を rails-lock で初めて見つけ、作業計画にない判断（検査の扱い）が要った。research で、解決した lock を入れた worktree か `vendor/bundle` のコピーで `scripts/check-apps --no-e2e` まで流せば、計画の段階で見える（ダウンロードを先に承認してもらう必要がある）
10. 「その系の最新パッチ」を選んでも、それがセキュリティ修正だけの版（8.0.5.1）だと、stable で直った不具合（#58276）が入っていない。research の版の選び方に、最新パッチと stable の差（`compare/v<版>...<系>-stable`）を見る手順がない
11. サブエージェントの見立て（`to_time` の警告は after_initialize で出る）は、結論は合っていたが位置が違った（initializer `active_support.set_configs`）。実際に流して確かめるまで、出典の位置は見立てとして扱う必要がある
12. 検出の gem は最初の 1 件で止まるので、検査で 1 件を許すと、その後ろが見えない。許すと決めたときに、隠れる分を補う比べ方（compare-config の読み込み済みの部品）を一緒に決める必要があった。スキルの「検査の失敗の原因が分からない」以外に、原因が分かっていて直せないときの扱い（①〜④）が、gem の未対応の場合しか書かれていない

rails-app-update:

13. `app:update` の雛形が、rails-lock で足した一時的な設定（`config/application.rb` の `to_time_preserves_timezone`）を上書きした。`scripts/restore-app-config` は決まった独自設定だけを戻すので、作業の途中で足した一時的な設定は、差分を読んで手で戻した。rails-lock で設定を足すときに、rails-app-update で上書きされることを見込んでおく必要がある
14. `scripts/compare-config` は、設定のキー（`config.action_controller.perform_caching` など）が消えると、そのキーに結び付けたクラスの値も出さないので、test の `perform_caching` が false → true になったことが書き出しの差分に出なかった。雛形の差分（行の削除）から気づき、runner で確かめた

rails-defaults:

15. `new_framework_defaults_8_0.rb` の 3 項目のうち 2 つ（`to_time_preserves_timezone`・`strict_freshness`）が、defaults のファイルからは扱えなかった（前者は警告で test が止まり、後者は値が入らない）。どちらも、railtie の initializer が config/initializers より前に値を読むため。rails-defaults の手順 3.3 は「値が変わらないときは起動の途中の読み込みを疑う」としているが、今回は読み込みではなく initializer の順番が原因だった。research で、defaults の各項目が「どの initializer で、いつ読まれるか」を確かめる手順があれば、計画の段階で分かった

verify:

16. 手動確認で、research・rails-lock の検査では出なかった Rails 8.0.5.1 の不具合（ルーティングを描く処理の競合）が、プレビューの起動直後の同時の要求で見つかった。E2E と minitest は要求を 1 つずつ送るので出ない。development を threads 3 の Puma で動かす手動確認が、同時の要求を試す唯一の場になっている
17. Step 5 の気づきの 16 と同じく、ブラウザペインが隠れていて、人間に開いてもらう往復が 1 回増えた。今回は依頼のメッセージに開き方と操作の順を一緒に書いたので、往復はその 1 回で済んだ

## Step 7: Rails 8.1（2026-10-12）

- ブランチ / PR: `upgrade/step7-rails81` / [#36](https://github.com/thinkAmi-sandbox/oidc_op_rp-sample/pull/36)
- バージョン: Ruby 3.3.12（変更なし）/ Rails 8.0.5.1 → 8.1.4
- 追随した Rails と gem の既定値・雛形・依存は、[defaults/rails-8.1.md](defaults/rails-8.1.md) に記録した（DEF-8.1-01〜29）。業務的な挙動の変化（B）は起きなかった。bundler-audit の無視リストは空のまま、brakeman の無視の項目はなくなった
- Rails 8.1 では、RP の omniauth-rails_csrf_protection 2.0.1 が起動の途中で `ActionController::Base` を読み込む（上流の #33）。検査で 1 件だけ許し、IMP-009 で見張る（DEF-8.1-07）

### 作業計画で決めたこと

`/rails-upgrade` の research で調べた（サブエージェント 2 つ: Rails 8.1 の事実、周辺 gem の事実。lock の解決と持ち込んだ後の `bundle lock`、advisory、benchmark の依存、brakeman の EOL、omniauth-rails_csrf_protection の 8.1 の分岐、`load_defaults 8.1` の各項目が読まれる時期、`app:update` が作るファイルは自分で確かめた）。論点を 1 つずつ人間と確かめ、決まるたびにこの表に足す。

| 論点 | 決めたこと | 理由 |
|---|---|---|
| 1 research で Rails 8.1.4 を起動して試す | 試す。scratchpad に HEAD の git worktree を作り、3 アプリに解決した lock と Gemfile（rails を `~> 8.1.4`）を置き、`BUNDLE_PATH` を本体の各アプリの `vendor/bundle` に向けて入れる。worktree で `scripts/check-apps --no-e2e` と `scripts/compare-config dump` を流す。本体の Gemfile・lock と手動確認用の環境は変えない。ダウンロード（Rails の構成 gem 8.1.4 の 13 個と action_text-trix 2.1.19。計 1,967,616 B）は、この論点への返事で承認を得た。RS で 1 回だけ落として照合し、RP・OP のキャッシュにコピーする | Step 6 では research で起動しなかったので、Rails 8.0.5.1 自身の起動の途中の読み込み（DEF-8.0-02）を rails-lock で初めて見つけた（Step 6 の気づきの 9）。今回は、RP の omniauth-rails_csrf_protection 2.0.1 が Rails 8.1 で require の時点に `ActionController::Base` を読み込むことが、コードからは見込まれる（`railtie.rb:2` → `token_verifier.rb:20-34` → v8.1.4 の `request_forgery_protection.rb` の `included do`。上流の cookpad/omniauth-rails_csrf_protection#33 は open）。検出の中身と、config/initializers の設定が効かなくなる範囲を、後の論点の前に実行で確かめる。落とした gem は rails-lock でそのまま使う（人間が判断） |
| 2 起動の途中の読み込み | ⑤ 検査で許す。omniauth-rails_csrf_protection 2.0.1 はそのまま使い、`scripts/check-load-hooks` の KNOWN を、DEF-8.0-02 の 1 件から、RP のこの gem の 1 件（`on_load(:action_controller_base)` と `omniauth-rails_csrf_protection-2.0.1/lib/omniauth/rails_csrf_protection/token_verifier.rb:26:`）に替える。スクリプトは残し、check-apps と CI はそのまま。隠れる分は、各作業の前後の compare-config の「読み込み済みの部品」で補う。gem が直ったら KNOWN を外す（PLAN.md の 7 章に書く）。RP の config/initializers に action_controller の設定を書かない | research の worktree（8.1.4、`load_defaults 8.0`）で、RP の test・`CI=1`・development の 3 つだけが失敗し、検出は `token_verifier.rb:26` の `config`（`config/application.rb:19` の Bundler.require → `railtie.rb:2` → `token_verifier.rb:34` の include）。この gem を `require: false` にすると検出は 0 件で、後ろに隠れた検出はない。原因は、Rails 8.1 の `ActiveSupport::Configurable` の非推奨（rails/rails#53970）で、`RequestForgeryProtection` が `config_accessor` から `delegate ..., to: :config` に変わり、gem の 8.1 の分岐（2.0.0 の 2cf722b）が `config` を `ActionController::Base.config` にしたため（include の `included do` がすぐに `config` を呼ぶ）。上流の cookpad/omniauth-rails_csrf_protection#33 は open で、直った版はない。影響は、RP の Base に config/initializers の action_controller の値が届かないこと（worktree で `asset_host`・`per_form_csrf_tokens` を initializer に書いて確かめた。8.0.5.1 の RP と 8.1.4 の OP には届く）。今の RP にそういう設定はなく、環境のファイルと `load_defaults` の値は届くので、今の挙動は変わらない。`new_framework_defaults_8_1.rb` の `escape_json_responses`・`action_on_path_relative_redirect` は RP の Base には効かない。①②は直った版も修正もないのでとれず、③（`after_initialize` で gem を読む）は CSRF の守りの組み込みをアプリで持つことになり、④（omniauth の組み込みの `AuthenticityTokenProtection` に置き換える）は、rack-protection を 2.2 以上に上げてもなお、失敗したときのリダイレクト先（`message=authenticity_error`）・test 環境の `allow_forgery_protection`・Origin の確かめが変わるのでとらない。gem は Rails の `verified_request?` をそのまま使うので守りが強く、今の挙動を変えずに済む（人間が判断） |
| 3 lock | uri 0.13.3 の一時固定は続ける。3 アプリで benchmark 0.3.0 が lock から消えるのは受け入れ、Gemfile に足さない。action_text-trix 2.1.19 は入れる。json 2.7.2・connection_pool 2.5.5・minitest 5.14.4・rack 2.2.24 は動かさない。PLAN.md の 7 章の benchmark の行に、Step 7 で lock から消えたことと、Step 8（Ruby 3.4）で見直すことを書く | `scripts/resolve-lock --gem 'rails=~> 8.1.4' --rails` は 3 アプリとも `--unpin` なしで解決し、動くのは Rails の構成 gem 13 個だけ。増えるのは action_text-trix 2.1.19（actiontext 8.1.4 の `~> 2.1.15`。依存は railties だけ）。解決した lock を Gemfile を `~> 8.1.4` にしたコピーに持ち込んで `bundle lock --local` すると、benchmark 0.3.0 が消える（resolve-lock の「消えた gem」には出ない）。activesupport 8.1.4 が依存から外し（632b2c5128）、Rails 8.1.4 も lock のほかの gem も require しない。require されても Ruby 3.3.12 の default gem の同じ 0.3.0 が読まれ、Ruby 3.3 の `bundled_gems.rb` の警告の一覧にない。worktree の `RUBYOPT=-W:deprecated` 付きのテストと eager load で `warning:` は 0 件（Step 6 の cgi と同じ）。activesupport 8.1.4 が足した json（rails/rails#55847）は、lock の 2.7.2（default gem と同じ版）のまま（人間が判断） |
| 4 brakeman の無視の項目 | rails-lock の Rails 8.1.4 のコミットで、3 アプリの `config/brakeman.ignore` の 2 つの項目（Medium の `pending_eol_rails` `98b26f60…db42`、High の `eol_rails` `d8492437…101c`）を両方消し、項目がなくなるのでファイルごと消す。TIPS.md の brakeman の期待する結果（`Ignored Warnings: 1`）を直す | brakeman 8.1.0 の Rails 8.1 の EOL は 2027-10-10（`check_eol_rails.rb:29`）で、2027-08-11 までは EOL の警告が出ない（`eol_check.rb:18-25`）。worktree の 8.1.4 で、3 アプリとも `Security Warnings: 0`、2 つの項目は「Obsolete Ignore Entries」に出た。fingerprint に Rails の版は入らないので、残すと 8.1 の EOL の警告も黙って無視する（Step 4 の EOLRuby と同じ理由）。High の項目の note の「アップグレードの途中」は、Step 7 で当てはまらなくなる（人間が判断） |
| 5 defaults の効かない項目と YJIT | `escape_js_separators_in_json` は、3 アプリの defaults のファイルで理由のコメントを付けてコメントのまま残し、`load_defaults 8.1` で値を確かめる（Step 6 の `strict_freshness` と同じ）。RP の `escape_json_responses`・`action_on_path_relative_redirect` も、RP の defaults のファイルでは同じ扱い（理由は論点 2 の gem）。RS・OP では defaults のファイルで有効にする。`remove_hidden_field_autocomplete` は、有効にするグループで追随の解説をしてから OP の応答のスナップショットを作り直し、同じコミットに入れる。`yjit` は雛形にないので、`load_defaults 8.1` のときに追随として解説し、Rails の既定値（development・test で false）に合わせる。グループの分け方と順番は rails-defaults の始めに決める | worktree の 8.1.4 で、各項目を defaults のファイルに置いたときと `load_defaults 8.1` にしたときの値を 3 アプリの test で確かめた。defaults のファイルから効かないのは、`escape_js_separators_in_json`（3 アプリ。initializer `active_support.set_configs` が config/initializers より前に写す。`activesupport/lib/active_support/railtie.rb:142-147`）と、RP の Base の action_controller の 2 項目（RS・OP と RP の API には効く）。`render_tracker` は、initializer `action_view.set_render_tracker` がアプリの `load_config_initializers` より後に走るので効く（サブエージェントの見立ての「効かない」は、実行で外れた）。`load_defaults 8.1` では 3 アプリとも全項目が入り、RP の Base にも入る。YJIT は 3 アプリの development・test で切れる（`configuration.rb:349`、#53746）。テストは、OP の応答のスナップショット 6 つ（差分は hidden の input の `autocomplete="off"` が消えることだけ）を除いて通った。アプリの `redirect_to` は RP の path ヘルパーだけで、OP のリダイレクト（devise・doorkeeper）は `/` で始まるパスか絶対 URL（人間が判断） |
| 6 rubocop・webmock | Step 7 では上げない。Step 8 の research で、その時点の最新版と、公開から 2 週間たっているかを確かめる（案 B。Step 5・6 と同じ決め方） | 10-13 の時点で、rubocop 1.92.0（10-10）・webmock 3.27.0〜3.29.0（10-10・10-11）は 2 週間たっていない（10-24・10-25）。research の途中で webmock 3.30.0（10-12。2 週間は 10-26）が出た。rubocop 1.92.0 は新しい cop がなく、`Lint/UselessAssignment` の新しい指摘（#14666）などで違反が出うる。webmock の 3.28.0 の `to_rack`、3.30.0 の RSpec の `with`・`disable_net_connect!(allow:)`、master の Unreleased の HTTP メソッドの照合（#821）は、3 アプリのテストに当たらない見込み。AI は、10-26 以降に 2 週間たった最新の版で区切る別のサブステップ（案 A）を案にした（人間が判断） |
| 7 手動確認と環境の片付け | 手動確認は verify で 1 回（`load_defaults 8.1` と `TargetRailsVersion` 8.1 の後）。RP の my_op のログインと introspection 用 RP の流れ、OP の「Redirected to」行の `code=`、サーバーの出力のエラーを見る。起動の直後の `HEAD "/"`・`GET "/"` が両方 200 なら、TIPS.md の元からあるエラーの一覧から DEF-8.0-03 を外す。直前に、12 ファイルのハッシュを確かめ、3 アプリの development DB を `tmp/manual_check_backup/` に写す。research の出口で、Step 6 の写しを消し、前のセッションの RS の puma（ポート 3992）を止め、research の worktree 2 つを外す | Rails の版を上げる。#58225 が直ったことは、要求を同時に送る手動確認でしか見えない（Step 6 の気づきの 16）。Rails 8.1.0 で SQLite の真偽値の書き方が変わるので、元に戻せるようにする。Step 6 の写しは、#35 が epic に入ったので消してよい（TIPS.md の「手動確認用の環境」）。この論点への返事で、作業計画の承認も得た（人間が判断） |

- 上げないもの: rubocop・webmock（論点 6）、json・connection_pool・minitest・rack（論点 3）、8.0 系のパッチ（8.0.5.1 が最新）
- 採用しないもの: `app:update` の Solid 系（`config/puma.rb` の `plugin :solid_queue`）。新しく作られる `config/ci.rb`・`bin/ci`・`bin/bundler-audit`・`config/bundler-audit.yml` は、rails-app-update の理解の関門で扱う
- ダウンロード: 論点 1 で承認を得て、research の中で済ませた（14 個、計 1,967,616 B。RS の `bundle install` で落としたのは 14 個だけで、`scripts/verify-gem-checksums rs` ですべて rubygems.org の SHA-256 と一致した。RP・OP は照合した `.gem` をキャッシュにコピーし、`--local --no-cache` で入れた。`Installing` は 14 行だけで、lock は解決したものと同じ）
- research の worktree: scratchpad に HEAD の git worktree を作り、3 アプリに解決した lock と Gemfile を置き、`vendor/bundle` を本体へのシンボリックリンクにした（mise は `MISE_TRUSTED_CONFIG_PATHS` で信頼させ、`mise trust` の設定は残していない。OP の署名鍵は worktree の中で使い捨てのものを作り、E2E 用の DB は本体から写した）。論点 2 の掘り下げのために、8.0.5.1 のままの worktree も作った。research の出口で 2 つとも外した
- 調べたことの一覧と決めたことの全体は、PLAN.md の 6 章の「Step 7: Rails 8.1」に書いた。7 章の devise・omniauth-rails_csrf_protection・rubocop・webmock・benchmark の行を直した

### 作業計画からの変更点

| 変更 | 理由 |
|---|---|
| 起動のたびの Active Storage の WARN を受け入れ（DEF-8.1-29）、使っていないフレームワークを読み込まないことを改善の候補にした（IMP-012） | 作業計画では見つけていなかった。rails-lock の時点から出ていたが、verify の手動確認のサーバーの出力で気づいた。`variant_processor = :disabled` を足す案はとらず、Rails の既定値の変化として受け入れた（人間が判断） |
| rails-defaults の前に、`scripts/lib/dump_config.rb` に 8.1 の 6 つの値の読み出しを足した（`6dc71cc`） | 設定のキーがないとクラスの値が書き出しに出ず、グループの前後を比べられなかったため（Step 6 の `5e3f661` と同じ） |
| IMP-009 に omniauth-rails_csrf_protection を書き足した（`e843a3f`） | 作業計画の論点 2 の後に、omniauth の組み込みの対策への置き換えを候補にするかを確かめたところ、置き換えは候補にせず、既にある IMP-009（起動の途中にフレームワークのクラスを読み込む gem）に足すことになった（人間が承認した） |

### 手動確認用の環境

作業の開始時（ブランチを切って最初のコミットの前）に、12 ファイルのハッシュを控えた（前のセッションの控えは残っていないので、これを Step 7 の基準にする）。development DB に `-wal` はなく、件数は本体を scratchpad にコピーして `immutable=1` で開いて数え、Step 6 の手動確認の後と同じだった（OP `oauth_access_grants` 29・`oauth_access_tokens` 72（revoke 済み 13）、RP `sessions` 12・`op_users` 1。どちらの DB も `integrity_check` は ok。見出しの 18・19 バイト目は 2・2 で WAL のまま）。

- 開始時に、前のセッション（Ruby 3.2 の頃の bundle）で起動した RS の puma（ポート 3992、10-11 から）が動いていた。RS の `development.log` に書き込んでいて、development DB は開いていなかった。research の出口で、人間に確かめて止めた（TERM）
- research の出口で、Step 6 の手動確認の前に取った 3 アプリの `tmp/manual_check_backup/`（本体だけ）を、人間に確かめて消した
- puma を止め、写しを消し、worktree を外した後も、12 ファイルのハッシュは開始時と同じ

### gem ごとの対応

| gem | バージョン | 対応 |
|---|---|---|
| Rails | 8.0.5.1 → 8.1.4 | 3 アプリ（rails-lock）。8.0.5.1 は 8.0 系の最新なので、先に上げるパッチはなかった。research で `scripts/resolve-lock --gem 'rails=~> 8.1.4' --rails` で解決した lock を持ち込み、Gemfile の rails を `~> 8.1.4` にして `bundle lock --local`（research で試した結果と同じ lock になった）。動いたのは Rails の構成 gem 13 個だけ。gem は research の worktree で入れてあり（論点 1）、`bundle install --local` で `Installing` はなかった。`scripts/verify-gem-checksums <アプリ> --changed HEAD` で、3 アプリとも 14 個が rubygems.org の SHA-256 と一致した。3 アプリの `config/brakeman.ignore` を消した（論点 4）。DEF-8.1-01〜09（RS `72ec831`・RP `a721c44`・OP `0067bcf`） |
| action_text-trix | （なし）→ 2.1.19 | actiontext 8.1.4 の依存（DEF-8.1-09） |
| benchmark | 0.3.0 → （なし） | activesupport 8.1.4 が依存から外し、3 アプリの lock から消えた（論点 3。受け入れた） |
| uri・json・connection_pool・minitest・rack | 0.13.3・2.7.2・2.5.5・5.14.4・2.2.24（変更なし） | 論点 3 |

- `scripts/check-load-hooks` は、許す組の一覧にして、RP の omniauth-rails_csrf_protection の組を足し（`f88f27a`）、3 アプリを上げた後に Rails 8.0.5.1 の組を消した（`cb01977`。check-apps と CI のコメントも直した）。最初のコミットの時点のアプリは 8.0.5.1 なので、新しいスクリプトが 8.0.5.1 の検出も許すことを、HEAD の worktree で確かめてからコミットした。各アプリのコミットの前（`commit-per-app`）は、そのアプリの検査と E2E が通った
- 解説（DEF-8.1-01〜09）に人間の返事を得てから、記録（`c86723f`）、上のコミットの順にした。IMP-009 の書き足し（`e843a3f`）は、その前に人間の承認を得た

### `app:update` で採用したもの・戻したもの

3 アプリで `yes a | bin/rails app:update`（DB は E2E 用）を流し、戻す前の差分を控えてから `scripts/restore-app-config` で独自設定を戻し、差分を人間が確かめた。項目ごとの解説は [defaults/rails-8.1.md](defaults/rails-8.1.md) の「`app:update` の雛形」。

| ファイル | 判断 | 理由 |
|---|---|---|
| development の `verbose_redirect_logs = true` | 採用 | development のログだけ（DEF-8.1-10） |
| production.rb の `assume_ssl`・`force_ssl` のコメント化と、コメントの句読点 | 採用 | 雛形に追従するだけ（DEF-8.1-11。`true` を残す案もあったが、人間が決まりどおりと判断した） |
| `config/puma.rb` のコメント | 採用（port は道具で戻した） | DEF-8.1-12 |
| `config/puma.rb` の `plugin :solid_queue` | 採用しない | 新しい構成（DEF-8.1-13。手で消した） |
| `content_security_policy.rb` の `content_security_policy_nonce_auto` のコメント（RP・OP） | 採用 | コメントだけ（DEF-8.1-14） |
| `bin/setup` の `--reset` | 採用 | 付けなければ同じ（DEF-8.1-15） |
| public の 400・404・422・500（RP・OP） | 採用 | production だけで使う（DEF-8.1-16） |
| `bin/rubocop`・`bin/brakeman` | 採用しない | DEF-8.0-21 と同じ（DEF-8.1-17） |
| `bin/bundler-audit`・`config/bundler-audit.yml` | 採用しない | 無視リストは `.bundler-audit.yml` の 1 か所（DEF-8.1-18） |
| `bin/ci`・`config/ci.rb` | 採用しない | 新しい構成。check-apps と CI が同じ役目（DEF-8.1-19） |
| `public/406-unsupported-browser.html`・`icon.png`・`icon.svg`（RP・OP） | 採用しない | DEF-8.0-23 と同じ（DEF-8.1-20） |
| test の `deprecation = :raise`、puma の port、`filter_parameter_logging.rb` の `:code` とコメント、RP の `autoload_lib_once` と inflector | 戻した | アプリの独自設定（`scripts/restore-app-config`。戻せない項目はなかった） |
| `active_storage:update` のマイグレーション 3 本 | 採用しない | Active Storage を使わない（DEF-7.0-14。道具で消した） |
| `new_framework_defaults_8_1.rb` | 足した（すべてコメント） | rails-defaults でグループごとに有効にする |

- 戻す前の差分で、戻した設定（puma の port、test の deprecation、RP の `autoload_lib`）の上の雛形のコメントが 8.0.5.1 から変わっていないことを確かめた（Step 5 の気づきの 19）。`config/application.rb`（RS・OP）・`test.rb`・`filter_parameter_logging.rb` は、戻した後に差分がない
- 前後で、`scripts/check-apps` の 36 の検査がすべて通り（件数は同じ）、応答と E2E のスナップショットの差分はない。`scripts/compare-config dump` で変わったのは development の `verbose_redirect_logs`（false → true）だけ。development だけのヘッダーも同じ。手動確認用の環境の 12 ファイルのハッシュは、作業の開始時と同じ
- 記録 `0d508a9`、コミット: RS `1c0ce7f`・RP `58ea88c`・OP `3f17437`

### `new_framework_defaults_8_1.rb` を有効にした順番

グループと順番は人間が決めた。前の書き出しを取る前に、`scripts/lib/dump_config.rb` に、設定しないとクラスの値が書き出しに出ない 6 つの値を足した（`6dc71cc`。前の書き出しは 2 回取って同じ）。各グループで、前後に `scripts/compare-config` で 3 アプリの test・development の値を書き出して比べた。項目ごとの解説は [defaults/rails-8.1.md](defaults/rails-8.1.md) の「`load_defaults 8.1`」。

| 順 | グループ | 設定 | 結果 |
|---|---|---|---|
| 1 | 内部の処理だけ | `render_tracker = :ruby`、`raise_on_missing_required_finder_order_columns = true` | 値だけが変わった（nil → `:ruby`、false → true）。fragment cache は使わず、モデルにはすべて主キーがある（DEF-8.1-21・22。記録 `649040b`、RS `9d4a61c`・RP `946d74f`・OP `4b0c04e`） |
| 2 | リダイレクト | `action_on_path_relative_redirect = :raise` | RS・OP は `:log` → `:raise`。`:log` のときも test.log に警告はなかった。RP は理由のコメント（DEF-8.1-07）を付けてコメントのまま（DEF-8.1-23。記録 `5ae62e0`、RS `b8056c0`・RP `4a8586c`・OP `bc210d5`） |
| 3 | JSON の書き方 | `escape_json_responses = false`、`escape_js_separators_in_json = false` | RS・OP の Base・API の `escape_json_responses` が true → false。今のスナップショットに書き換えられた文字はない。RP の `escape_json_responses` と、3 アプリの `escape_js_separators_in_json` は、理由のコメントを付けてコメントのまま（DEF-8.1-24・25。記録 `883ecb8`、RS `82c4484`・RP `6ef3f50`・OP `7619b55`。記録の直し `5213a29`） |
| 4 | hidden の autocomplete | `remove_hidden_field_autocomplete = true` | false → true。OP の応答のスナップショット 6 つで `autocomplete="off"` が消え（29 行）、解説の後に作り直して OP のコミットに入れた（DEF-8.1-26。記録 `711b9e3`、RS `fb1e098`・RP `61654b5`・OP `3b39b8a`） |

- 4 グループとも、検査と E2E の件数は前と同じ（グループ 4 の OP のスナップショットを除き、応答と E2E のスナップショットの差分はない）。`-W:deprecated` の警告と development だけのヘッダーも同じ。読み込み済みの部品は同じ（RP の DEF-8.1-07 の検出の後ろに、新しい読み込みは増えていない）。手動確認用の環境の 12 ファイルのハッシュは、作業の開始時と同じ
- defaults のファイルから効かなかった 3 つ（3 アプリの `escape_js_separators_in_json`、RP の action_controller の 2 項目）は、research の worktree で分かっていたとおりで、作業計画の論点 5 から変えていない

### `load_defaults 8.1`

- 3 アプリを `config.load_defaults 8.1` にし、`new_framework_defaults_8_1.rb` を消した（ステージしない `rm`）。前（グループ 4 の後の書き出し）と比べて、値で変わったのは、defaults のファイルからは効かなかった 3 アプリの `escape_js_separators_in_json`（true → false）と RP の `escape_json_responses`・`action_on_path_relative_redirect`、development・test の `config.yjit`・`RubyVM::YJIT.enabled?`（true → false）だけ。読み込み済みの部品は同じ（DEF-8.1-27・28）
- 雛形から消えた initializer はない（3 アプリの initializer は、8.1.4 の雛形にあるものか、アプリの独自のものだけ）
- 解説（DEF-8.1-27・28）に人間の返事を得てから、記録（`c14e828`）、RS `650ecf1`・RP `38d8dc1`・OP `ada7df7` の順にコミットした。検査と E2E は通り、スナップショットの差分はない。`-W:deprecated` の警告と development だけのヘッダーも同じ
- RuboCop の `TargetRailsVersion` を 8.1 にした（`ba14f44`）。3 アプリとも新しい指摘はない。`RuboCop::ConfigStore` で読む値が 8.1 になることを確かめた。rubocop-rails 2.38.0 に、Rails 8.1 を条件にする cop はない

### 非推奨警告と対応

| 警告 | 対応 |
|---|---|
| Rails 8.1.4 で、新しい非推奨の警告は出なかった。`RUBYOPT=-W:deprecated` を付けたテストと eager load の `warning:` は、各作業の前後とも 0 件、DEPRECATION は前からある OP の `auth_time_from_resource_owner`（IMP-011）だけ。omniauth-rails_csrf_protection 2.0.1 の `ActiveSupport::Configurable` は、Rails 8.1 では読まない分岐を通る | なし |
| 起動のたびに、Active Storage が image_processing gem がないことを Rails のログに WARN で出す（非推奨ではない） | 受け入れた（DEF-8.1-29）。使っていないフレームワークを読み込まないことを、改善の候補にした（IMP-012。人間が承認した） |

### 意図的な仕様変更

なし。応答のスナップショット・E2E・verify の手動確認で、業務的な挙動の変化は見つからなかった。応答とファイルの変化はすべて既定値・雛形・依存への追随として解説し、人間の返事を得た（[defaults/rails-8.1.md](defaults/rails-8.1.md) の DEF-8.1-01〜29）。OP の応答のスナップショットの変化は、hidden の input の `autocomplete="off"` が消えることだけ（DEF-8.1-26）

### 前後の比較

lock を変える前（`e843a3f` の後。アプリは research の開始時から変わっていない）に次のものを書き出し、3 アプリを上げた後に取り直して比べた。前の `scripts/compare-config dump` と development だけのヘッダーは 2 回取って同じことを確かめた（compare-config は research の worktree の前に取ったものとも同じ）。

- Rails 8.1.4（rails-lock）
  - `scripts/check-apps`: 前は 36 の検査がすべて通った（RS 11・RP 33・OP 69 runs、0 failures。`CI=1` も同じ。E2E 10 passed。起動の途中の読み込みの 9 項目は DEF-8.0-02 の組で許していた）。後も 36 の検査がすべて通り、件数は同じ。応答のスナップショットと E2E のスナップショットの差分はない。起動の途中の読み込みは、RS・OP の 6 項目が許す条件なしで通り、RP の 3 項目が omniauth-rails_csrf_protection の組で許された
  - `scripts/compare-config dump`（3 アプリ、test・development）: 違いは DEF-8.1-01〜07 に振り分けた（`to_time_preserves_timezone` のキー、開いたリダイレクトの設定、リダイレクトと Active Record の新しい設定、Active Storage のキー、読み込み済みの部品）
  - `RUBYOPT=-W:deprecated` を付けた minitest と development の eager load: 前後で同じ（`warning:` は 0 件、DEPRECATION は OP の IMP-011 だけ）
  - development だけのヘッダー（E2E 用の DB で Puma に通した。RS の `/apples/show`、RP のトップ、OP の discovery・ログイン画面。日付・ID・数値・`x-miniprofiler-ids` などは伏せた）: 前後で同じ
  - brakeman: 前は 3 アプリとも警告 0・無視 1。後は警告 0・無視 0（`config/brakeman.ignore` を消した）で、チェックの数は同じ（79）。research の worktree では、2 つの項目が「Obsolete Ignore Entries」に出ていた
  - SQLite: OP の test.log で、fixtures の INSERT の真偽値が `1` → `TRUE` になった（DEF-8.1-08）
  - 手動確認用の環境の 12 ファイルのハッシュは、作業の開始時と同じ
- `app:update`（rails-app-update）。前は rails-lock の後の書き出し。結果は上の「`app:update` で採用したもの・戻したもの」（変わった値は development の `verbose_redirect_logs` だけ）
- rails-defaults・rails-load-defaults。前はそれぞれ直前の書き出し。結果は上の「`new_framework_defaults_8_1.rb` を有効にした順番」「`load_defaults 8.1`」（各グループで、検査・スナップショット・`-W:deprecated` の警告・development だけのヘッダー・読み込み済みの部品を比べた）
- 比べていないもの: Rails のログ（`log/*.log`）の WARN・ERROR の行。Active Storage の WARN（DEF-8.1-29）は、これを比べていなかったので verify まで見えなかった（気づきの 14）

### 手動確認

verify で、`load_defaults 8.1` と `TargetRailsVersion` 8.1 の後（`bee5797`）に、`.claude/launch.json` から 3 アプリを起動してブラウザペインで確かめた（操作は人間）。3 アプリとも Puma 8.0.2・threads 3 で起動し、Ruby の版の表示に Step 6 にあった `+YJIT` は出なかった（DEF-8.1-28）。

- 直前に、3 アプリのサーバーが止まっていて、12 ファイルのハッシュが作業の開始時と同じことを確かめ、3 アプリの development DB の本体（`-wal` はない）を `tmp/manual_check_backup/` に写した（写しのハッシュは元と同じ。作業計画の論点 7）
- 起動の直後: プレビューが同時に送った `HEAD "/"`・`GET "/"` は、3 アプリとも両方 200。Step 6 の RoutingError（DEF-8.0-03）は出なくなった（rails/rails#58225 が 8.1.4 に入っている）。TIPS.md の元からあるエラーの一覧から外した
- ログイン（RP の my_op）: 人間が「Re Login」を押した（OP のセッションが残っていて、ログインと同意の画面は出なかった。Step 6 と同じ）。OP の認可エンドポイントが 302、トークン・userinfo・JWKS が 200。OP のログの「Redirected to」行は `code=[FILTERED]`。RP の「Redirected to」の次の行に `↳ app/controllers/sessions_controller.rb:10` などが出た（DEF-8.1-10。OP は doorkeeper の中のリダイレクトなので出ない）
- introspection 用 RP: 同意画面と Authorize の後、RS は正しいトークンで 200、その後 401 が 2 回。OP は introspect を 3 回、revoke を 1 回受けた。Step 6 と同じ
- サーバーの出力: 3 アプリとも warning・DEPRECATION はない。エラーは、元からある RP の `/stylesheets/application.css`・OP の `/stylesheets/doorkeeper/application.css`・RS と OP の歓迎ページの `/icon.png` の `ActionController::RoutingError` だけ。起動のたびに、Active Storage の image_processing gem の WARN が出た（DEF-8.1-29。rails-lock の時点から出ていたが、前後の比較では数えていなかった。人間が受け入れ、IMP-012 を足した）
- 手動確認用の環境: OP の development DB は `oauth_access_grants` が 29 → 31 件、`oauth_access_tokens` が 72 → 77 件（my_op 1・introspection 用 1（revoke 済み）・RS のクライアントクレデンシャル 3。revoke 済みは 13 → 14）、RP は `sessions` 12 件・`op_users` 1 件のまま。どちらも `integrity_check` は ok。サーバーを止めた後、`-wal` は残っていない。ファイルの見出しは WAL のまま（見出しの 18・19 バイト目で確かめた）。変わったのは OP・RP の DB の本体だけで、RS の DB・署名鍵・`.env`・3 アプリの secret は変わっていない。手動確認の後の 12 ファイルのハッシュを新しい基準にした。写しは、この Step の PR が epic に入った後に、人間に確かめてから消す

### 遭遇した問題

| 問題 | 対応 |
|---|---|
| research の worktree に RS の E2E 用の DB を `sqlite3 -readonly ... ".backup"` で写すと、0 バイトの写しになり `unable to open database file` が出た（`-wal`・`-shm` のない WAL の DB） | `-wal` がないのでデータは本体にあり、`cp` で写した（TIPS.md の「手動確認用の環境」と同じ性質） |
| research の worktree の compare-config の書き出しにだけ、ActiveStorage などのモデルの関連付けの行がなかった | `vendor/bundle` をシンボリックリンクにした worktree のときだけの違いで、本体では 8.0.5.1・8.1.4 とも出る。worktree の書き出しは、本体の前後の比較には使わなかった |
| 一時ファイルを消す `rm $WT/$d/...` が、Claude Code の安全チェックで止められた（変数が空だと根を指すため） | `"${WT:?}/${d:?}/..."` の形に直した |
| サブエージェントの見立て（`render_tracker` は defaults のファイルから効かない）が、実行で外れた | worktree で値と initializer の並び順を確かめ、論点 5 の材料を直した（下の気づきの 8） |
| DEF-8.1-24 の記録の `\u` の並びが、実際の文字（目に見えない U+2028・U+2029 を含む）になってコミットされた | Python で直した（`5213a29`・`123c837`。下の気づきの 13） |
| 起動のたびの Active Storage の WARN（DEF-8.1-29）に、rails-lock の前後の比較では気づかず、verify の手動確認で気づいた | 警告の数え方は `warning:`・`DEPRECATION` の行で、Rails のログの WARN を見ていなかった。人間が受け入れ、IMP-012 を足した（下の気づきの 14） |

### 確認結果

verify で、PLAN.md の 10 章の完了条件を確かめた。

- `scripts/check-apps`（3 アプリと E2E）: `TargetRailsVersion` 8.1 と記録のコミットの後（`bee5797`）に、36 の検査がすべて通った。各コミットの前には、そのアプリと E2E で流した。起動の途中の読み込みは、RP の omniauth-rails_csrf_protection の 1 件だけを `scripts/check-load-hooks` で許している（DEF-8.1-07）。RS・OP は許す条件なしで通る
- minitest: RS 11 runs・15 assertions、RP 33・71、OP 69・123、0 failures。`CI=1`（eager load あり）でも同じ
- E2E: 10 passed。応答のスナップショットの差分は、グループ 4 の OP の 6 つ（`autocomplete="off"` が消える。DEF-8.1-26）だけ。E2E のスナップショットの差分は、この Step を通して出なかった
- RuboCop（`TargetRailsVersion: 8.1`）・`zeitwerk:check`・起動の途中の読み込みの検査（test・`CI=1`・development）・bundler-audit（無視リストは空）・brakeman: すべて通った（`check-apps` の項目）。brakeman は 3 アプリとも `Security Warnings: 0`、無視の項目はない（`config/brakeman.ignore` を消した）
- lock: epic（`bb51ff5`）からの動きは、Rails の構成 gem（8.1.4）、増えた action_text-trix 2.1.19、3 アプリから消えた benchmark 0.3.0、`DEPENDENCIES` の rails だけ。default gem に合わせた版と、一時固定の uri 0.13.3・reline 0.6.0・connection_pool 2.5.5・faraday-net_http 3.0.2（RS・RP）は動いていない
- `bin/rails c`: `scripts/check-console` で 3 アプリとも起動した（irb 1.13.1・reline 0.6.0。Tab の補完と複数行の入力ができた）。`bin/rails s`: 手動確認で 3 アプリとも起動した
- 公開物の安全チェック: 各コミットの hooks で通った
- CI: push の後に確かめる（push は人間が行う）。`scripts/check-load-hooks` を呼ぶ CI の 2 つのステップが、RP で許した 1 件で通ることも、そのときに見る
- 手動確認用の環境: 上の「手動確認」。HEAD で、12 ファイルのハッシュが手動確認の後の基準と同じ

### コードレビュー（`/code-review`）

| 指摘 | 対応 |
|---|---|
| `scripts/lib/dump_config.rb` の「アプリのモデルだけを見る」が、モデルのファイルが `Rails.root` の下かで分けるので、アプリのディレクトリの中の `vendor/bundle` にある gem のモデル（ActiveStorage など）も含める | 直さない。同じ場所での前後の比較には影響しない（research の worktree の書き出しとの違いの原因だった）。Step 6 のコードレビューの 4 と同じく、道具の見直しで扱う（下の気づきの 16。人間が判断） |
| RP で omniauth-rails_csrf_protection の 1 件を許すと、その後ろの早い読み込みが CI で見えない（CI は compare-config を流さない） | 直さない。作業計画の論点 2 で、隠れる分を各作業の前後の compare-config で補うと決めた。IMP-009 で見張る（人間が判断） |
| production.rb の `assume_ssl`・`force_ssl` がコメントになり、production で HTTPS を強制しなくなる | 直さない。DEF-8.1-11 で、決まりどおり雛形に追従すると決めた（人間が判断） |
| `bin/setup --reset` は、RS では `db/schema.rb` がないので失敗し、RP・OP では手動確認用の DB を作り直す | 記録を直した。DEF-8.1-15 に、RS では失敗すること（流しては確かめていない）を書き足した。注意書きは README の仕上げで書く（人間が判断） |
| DEF-8.1-06 の「読み込みの時期は 8.0.5.1 と同じ」は、8.1.4 でしか流しておらず、8.0.5.1 はソースを読んだ見立て | 記録を直した。8.0.5.1 は同じ行（`activerecord-8.0.5.1/lib/active_record/errors.rb:444`）をソースで確かめた見立てだと書き分けた（人間が判断） |

- 直したのは記録だけで、アプリと道具のコードは変えていない

### スキルについて気づいたこと

Step 3〜6 と同じく、スキルの手順・型・設定で、足りない・合わない・迷ったところを控える（スキルを直すかは人間が判断する）。

resume:

1. ローカルの `epic/rails-8.1-upgrade` が origin より古く、#35 の取り込みが入っていなかった（Step 5 の気づきの 3、Step 6 の気づきの 1 と同じ）。人間の指示にあったので、fetch して早送りしてから切った
2. 前のセッション（Ruby 3.2 の頃）の調査で起動した RS の puma（ポート 3992）が残っていて、development.log に書き込んでいた。resume の手順 3 で手動確認用の環境を控えるときに、サーバーが動いていないかを確かめる手順がない（ps で見つけた）

research:

3. resolve-lock の「消えた gem」に出ずに lock から消える gem が、また出た（3 アプリの benchmark 0.3.0）。Step 3 の method_source、Step 5 の mutex_m、Step 6 の cgi に続いて 4 回目。持ち込んだ後の `bundle lock` まで試して見つけた
4. 新しい Rails を research で起動して試すには、ダウンロードが先に要る。templates.md の「質問」は、ダウンロードの承認を最後の論点（作業計画の承認）の返事に含める形なので、今回は最初の論点で先に承認をもらった
5. omniauth-rails_csrf_protection の Rails 8.1 の分岐による早い読み込みは、サブエージェントが gem のソースを読んで見つけた。research の手順 2 は「上げるものの事実」を調べるが、lock の gem が新しい Rails で別の分岐（`ActionPack.version` などの条件）を通るかを見る手順はない
6. 論点 2 で、人間は 5 回掘り下げた（何が問題か・なぜ 8.1 で起きたか・omniauth の組み込みの対策で足りるか・rack-protection を上げれば足りるか・gem のままのほうがよいか）。templates.md の「質問」は「本題・根拠・見立て」の型で、影響の具体例（実際に流した結果）、原因の版の差、とらない案の理由を出す決まりがない。最初の示し方に、影響を実行で示した例と、原因の差分を入れておけば、往復が減った
7. 論点 1 の試行（worktree）は、論点 2 の掘り下げでも使えた（8.0.5.1 と 8.1.4 で initializer の値が届くかを並べて試した）。比べるために、HEAD のままの worktree をもう 1 つ作った
8. サブエージェントの見立て（`render_tracker` は defaults のファイルから効かない）が、worktree で流すと外れた（initializer の並び順で、アプリの `load_config_initializers` より後に走っていた）。Step 6 の気づきの 11 と同じく、initializer の時期は、ソースを読むだけでなく `Rails.application.initializers.tsort_each` の並び順か、実際の値で確かめる必要がある。research で起動して試せたので、計画の段階で直せた
9. research の途中で日付が変わり、webmock 3.30.0（10-12）が出ていた。版の調べは research の始めに 1 回しているが、論点を決める直前にもう一度見る手順はない（論点 6 の直前に見直して気づいた）
10. 論点 5 の示し方で、AI は「3 アプリの `redirect_to` は path ヘルパーと絶対 URL だけ」と、確かめずにサブエージェントの調べから書いた。記録の前に grep で確かめ、言い方を直した（アプリの `redirect_to` は RP の path ヘルパーだけ）
11. 論点 7 で、research の出口の片付け（写しを消す・残っていたサーバーを止める・worktree を外す）を決めた。research.md の出口には、research で作ったもの（worktree など）を片付ける手順がない

rails-app-update:

12. `config/puma.rb` の `plugin :solid_queue` を、Step 6 に続いて手で消した。`scripts/restore-app-config` は独自設定を戻す道具で、採用しない雛形の行は消さない。毎回同じ判断（DEF-8.0-19・DEF-8.1-13）なので、道具の一覧に足すかを決めておくと手が減る

rails-defaults:

13. DEF-8.1-24 の記録で、`\u003c`・`\u2028` などの並びを heredoc で書いたところ、ツールに渡す段階で実際の文字（`<` と、目に見えない U+2028・U+2029）に変わり、そのままコミットした（TIPS.md の「コミット」の `\u` の性質が、コミットメッセージだけでなく、ファイルに書く文にも当たった）。後で気づき、Python で直した。`\u` を含む文を書くときは、ファイルでも Python で書き、U+2028・U+2029 が入っていないかを確かめる必要がある

verify:

14. 起動のたびの Active Storage の WARN（DEF-8.1-29）は、rails-lock から出ていたのに、前後の比較では見えなかった。設定の「前後の比較」の警告は、`RUBYOPT=-W:deprecated` の `warning:` と `DEPRECATION` の行を数えるだけで、Rails のログ（`log/*.log`）の WARN を見ていない。手動確認のサーバーの出力を読んで初めて気づいた。前後の比較に、test.log・development.log の WARN・ERROR の行（新しい種類のもの）を足すと、rails-lock の時点で見える
15. 手動確認の前に、ブラウザペインが隠れていて、表示してもらう往復が要った（Step 5 の気づきの 16、Step 6 の気づきの 17 と同じ）。今回も依頼に表示の仕方と操作の順を一緒に書いたので、往復は 1 回で済んだ

pr:

16. コードレビューで、`scripts/lib/dump_config.rb` のアプリのモデルの絞り込みが、`vendor/bundle` の gem のモデルも含めると分かった。research の worktree（`vendor/bundle` をシンボリックリンクにした）の書き出しとの違いは、これが原因だった。worktree で新しい Rails を試す手順をスキルに足すなら、道具がアプリのディレクトリの場所に頼っているところ（この絞り込み、`$LOAD_PATH` の除外）を見直す必要がある

## Step 8: Ruby 3.4（2026-10-13）

- ブランチ / PR: `upgrade/step8-ruby34` / [#37](https://github.com/thinkAmi-sandbox/oidc_op_rp-sample/pull/37)
- バージョン: Ruby 3.3.12 → 3.4.11 / Rails 8.1.4（変更なし）
- Rails と gem の既定値・雛形への追随はなかった（defaults/ に記録はない）。業務的な挙動の変化（B）は起きなかった。bundler-audit の無視リストは空のまま、brakeman の無視の項目はない
- Ruby 3.4.11 の default gem の json 2.9.1 が CVE-2026-54696 の対象なので、json は合わせ直さずに 2.21.2 に上げて Gemfile に明示した。RS・RP は ostruct を Gemfile に明示した。byebug の Ruby 3.4 の不具合は IMP-013 で見張る

### 作業計画で決めたこと

`/rails-upgrade` の research で調べた（サブエージェント 2 つ: Ruby 3.4 の事実、周辺 gem の事実。3.4.11 の版・tarball・ruby-build の定義、`bundled_gems.rb` の警告の一覧、resolv・net-http・erb・Bundler の版、合わせ直す版の依存、lock の gem が lock にない ostruct などを読むか、mise の ruby-build の更新、setup-ruby の版は自分で確かめた）。論点を 1 つずつ人間と確かめ、決まるたびにこの表に足す。

| 論点 | 決めたこと | 理由 |
|---|---|---|
| 1 版と、research で入れて試すか | 3.4.11 にする。research で入れ、scratchpad に HEAD の git worktree を作り、3 アプリを 3.4.11 にして、lock を 3.4.11 の default gem の版に合わせて解決し、`BUNDLE_PATH` を本体の各アプリの `vendor/bundle`（新しい `ruby/3.4.0`）に向けて入れる。worktree で `scripts/check-apps --no-e2e`、`RUBYOPT=-W:deprecated` の minitest と eager load、ログの WARN・ERROR、`scripts/check-console` を流し、faraday-net_http 3.4.4 も試す。本体の Gemfile・lock と手動確認用の環境は変えない。research の出口で worktree を外す。入れ方は `mise install ruby@3.4.11`（mise 2026.5.10 が、入れる前に ruby-build を最新のリリース v20261013 に取り直す）。ダウンロード（tarball 22,492,449 B、ruby-build の clone、`.gem` 16 個・計 1,207,808 B）は、この論点への返事で承認を得た。`.gem` は RS で 1 回だけ落として照合し、RP・OP のキャッシュにコピーする | 3.4.11 は 3.4 系の最新（2026-09-23）で、公開から 2 週間たち、resolv の CVE-2026-80212・80213 の修正版（0.7.2）を含む。3.3 系に 3.3.12 より新しい版はない。合わせ直した lock の解決（irb 1.14.3 の依存で erb・cgi が増える見込み）、RS・RP の ostruct の bundled_gems の警告、gem 側の chilled string の警告は、入れて流さないと分からない（Step 6 の気づきの 9、Step 7 の論点 1）。AI は、手元の ruby-build 20260924 を直接流して、公開から 1 日の ruby-build を落とさない案を推したが、人間は mise の普段の入れ方を選んだ |
| 2 lock の default gem の合わせ直し | json は、Ruby の前に gems の作業で 2.21.2 に上げる（Ruby 3.3.12 のまま、RS → RP → OP）。Gemfile にグループの外で `gem 'json', '~> 2.21', '>= 2.21.2'` と理由のコメントを付けて明示し、ruby の作業の合わせ直しの対象から外す。7 章の json の行に、直接の gem の「最新版に上げる」の例外（2 系にとどめる理由）を書く。json 2.21.2 の `.gem`（112,640 B）のダウンロードは、この論点への返事で承認を得た。ほかは、ruby の作業で 3.4.11 の版に合わせ直す（io-console 0.8.1・irb 1.14.3・logger 1.6.4・psych 5.2.2・rdoc 6.14.0・securerandom 0.4.1・stringio 3.1.2・uri 1.0.4、OP の ostruct 0.6.1。bundled gems に移った bigdecimal 3.1.8・drb 2.2.1・mutex_m 0.3.0 も、依存で増える erb 4.0.4.1（3 アプリ）・cgi 0.4.2（RS・OP）も 3.4.11 の版）。ruby2_keywords 0.0.5 が lock から消えるのは受け入れる。reline 0.6.0 は 3.4.11 の default gem と同じ版になり、合わせ直す側に移す。`BUNDLED WITH` は 2.6.9 | 試行で、3.4.11 の default gem の json 2.9.1 が CVE-2026-54696（GHSA-x2f5-4prf-w687、Low。`JSON.dump(obj, io)` などで IO に書き出すときのヒープバッファオーバーフロー。2.9.0〜2.19.8 が対象）の対象で、3 アプリの bundler-audit が落ちた。Ruby 4.0.7 の json 2.18.0 も対象で、ruby_3_4・ruby_4_0 のブランチにも修正版はない。AI は lock の 2.7.2（対象外）を残す案を推したが、人間は修正版に上げる案を選んだ（調べた範囲の対応は、どれも 2.19.9 以上に上げるもの。rails/rails-html-sanitizer #232 など）。2.21.2 は json の 4 つの advisory（CVE-2025-27788・CVE-2026-33210・54696・71847）のどれの対象でもなく、2 系で 2 週間たった最新（07-31）。activesupport 8.1.4 は `json >= 0` で、Rails v8.1.4 の開発用の lock は json 3.0.1。json 3 は既定値が変わる（重複キー・コメントで例外）ので別に判断する。Ruby の前の別の作業にするのは、json と Ruby の変化を別の前後の比較に分けるため。Gemfile の範囲の形は、下限を修正版、上限を 2 系という意図にするため（AI の案 a） |
| 3 標準ライブラリから外れた gem の明示 | RS・RP の Gemfile の「# 追加」の節に、`gem 'ostruct', require: false` を理由のコメントを付けて足す。版は Gemfile に書かず、lock の合わせ直しで 3.4.11 の default gem の 0.6.1 にする。ruby の作業の RS・RP のコミット（Ruby を上げるコミット）に入れる。rake を 13.2.0 以上に上げたとき（14 章の間接の gem の更新）に、行を外せるかを見直す（7 章に書く） | 試行で、RS・RP の minitest と E2E のサーバーの起動（`db:` タスク）で、rake 13.0.6 の `lib/rake.rb:33` が lock にない ostruct を読み、bundled_gems の警告が出た（`-W:deprecated` なしでも出る）。OP は doorkeeper-openid_connect の依存で lock にあり、出ない。Ruby 4.0 で ostruct は bundled gems になり、lock にないと読み込めなくなる見込み。試行で、`require: false` で明示すると警告は消え、lock に増えるのは ostruct だけで、development の起動で `OpenStruct` は読み込まれない。rake は 13.2.0 から ostruct を読まないが、railties の依存の間接の gem で、上げるとタスクの挙動を確かめる別の更新になる（案 b）。Step 5 の mutex_m と同じ考え方 |
| 4 faraday-net_http の一時固定 | ruby の作業の後に、gems の作業で faraday-net_http を 3.0.2 → 3.4.4 に上げる（RS → RP）。増える net-http は一時固定で 0.6.0（3.4.11 の default gem と同じ版）にし、Ruby を上げるたびに合わせ直す一覧（7 章・8 章の 4）に足す。3.0.2 の一時固定は外す（7 章の行を直す）。`.gem` は論点 1 で落として照合したものを使う | 3.0.2 に固定していた理由（3.4.x の `net-http ~> 0.5` を Ruby 3.3.12 の net-http 0.4.1 で満たせない）が、3.4.11 の net-http 0.6.0 でなくなる。faraday 2.14.4 は `< 3.5` なので 3.4.4（06-02）が上限。3.0.2 → 3.4.4 の変化は SSL・プロキシの機能の追加と本文の複製の直しで、RS・RP は localhost の http で SSL の設定もプロキシも使わない。試行で、lock で動くのは faraday-net_http と増える net-http だけで、RS・RP の minitest と E2E に差分はなかった。固定しないと net-http は `~> 0.5` の最新（0.10.0。2 週間たっていない）を取りにいく |
| 5 CI の setup-ruby の固定 | ruby の作業の最初のコミット（3 アプリの Ruby を上げる前）で、ci.yml の setup-ruby の 4 か所を v1.325.0 から v1.329.0（タグのコミット `651ff0d62c5c79bed6d53ec518387aae20e72c1a`）にする。v1.329.0 は 2026-10-12 公開で、公開から 2 週間の決まりの例外とする（人間が判断） | v1.325.0 の `ruby-builder-versions.json` は 3.4 系が 3.4.10 までで、`.ruby-version` を 3.4.11 にすると CI が Ruby を入れられない。3.4.11 は v1.326.0（09-23）で足された。v1.325.0 → v1.329.0 の差分の全文を読み、3.4.11 の追加、Windows の CRuby の一覧（v1.327.0）、Windows の MSYS1 の証明書のパスの 1 行（v1.328.0）、4.1.0-preview1 の追加（v1.329.0）だけで、ubuntu で 3.3.12・3.4.11 を入れる経路は変わらないことを確かめた。コミットの SHA で固定する。v1.329.0 の一覧にも 3.3.12 があるので、Ruby を順に上げる途中のコミットでも CI は Ruby を入れられる。AI は 2 週間たった最新の v1.327.0 を案にしたが、差分が小さいので最新にした |
| 6 rubocop・webmock を次に確かめる時期 | Step 8 では上げない。次に確かめるのは、Step 9 を行うならその research の最初、行わないなら仕上げの最初（7 章の rubocop 系・webmock の行に書く） | 着手の日（10-14）に、rubocop 1.92.0（10-10）・webmock 3.27.0〜3.30.0（10-10〜10-12）は 2 週間たっていない（10-24〜10-26 から）。rubocop-rails 2.38.0・rubocop-ast 1.50.0・rubocop-minitest 0.41.0 は最新。Step に結び付けるとまた送りになりやすい（Step 6 の気づきの 7）が、Step 9 を行うかは Step 8 の完了時に決まるので、どちらでも送り先が決まる。試行の worktree で、rubocop 1.91.0 の `TargetRubyVersion: 3.4` で 3 アプリとも指摘はなかった |
| 7 byebug 13.0.0 の Ruby 3.4 での不具合 | CLAUDE.md の ①（対応版を待つ）。byebug は 13.0.0 のままにし、`where` の不具合を 7 章の byebug の行に記録する。直った版が出たら、直接の gem の方針で上げる。debug gem への置き換えを IMP-013 に足した（人間が承認） | 試行で、3.4.11 の RS の `scripts/check-console`（`next`・`where`・`continue`）で、`where` だけが `undefined method 'Kernel.require' for class 'Kernel'` で失敗した（byebug#867。修正の #967 は 2026-04-25 にマージ、未リリース）。アプリのコードは byebug を呼ばず、業務的な挙動には関わらない。② GitHub の main は lock に git の参照が入り `.gem` を照合できない。④ debug gem への置き換えは開発の道具を替える改善で、epic の後に行う |
| 8 手動確認の時期と DB の写し | verify で 1 回、すべての変更（json、Ruby、`TargetRubyVersion`、faraday-net_http）の後に行う。直前に 12 ファイルのハッシュを確かめ、3 アプリの development DB を `tmp/manual_check_backup/` に写す。research の出口で、Step 7 の写し（3 アプリの `tmp/manual_check_backup/`）を消し、試行の worktree を外す。本体の各アプリの `vendor/bundle/ruby/3.4.0` は ruby の作業で使うので残す | RP・OP・RS の間のやり取りに関わる変更（Ruby 3.4.11、json 2.21.2、faraday-net_http 3.4.4）は minitest・スナップショット・E2E で確かめるが、ブラウザでの流れ（RP の my_op でのログインと introspection 用 RP）は手動確認で見る。Step 7 の写しは、#36 が epic に入ったので消してよい（TIPS.md の「手動確認用の環境」） |

### 作業計画からの変更点

| 変更 | 理由 |
|---|---|
| verify の手動確認で、3 アプリを 2 回起動した（1 回目の後、人間の操作の前に、アプリがプレビューを止めた） | 起動し直して確かめた。その間に RP の DB が変わり、ブラウザのセッションのクッキーも消えていたので、RP の `sessions` は 12 → 14 件になった（下の「手動確認」） |
| 各アプリのコミットの前の検査を、`RUBYOPT=-W:deprecated` を付けた `scripts/check-apps --app <アプリ>` で流し、通った作業ツリーをそのままコミットした（RP の json から） | commit-per-app 全体に `RUBYOPT` を付けると、git の hook（Ruby 2.6）まで渡って止まる（下の「遭遇した問題」）。ほかのアプリの変更はなく、退避は要らなかった |

### 手動確認用の環境

作業の開始時（ブランチを切って最初のコミットの前）に、12 ファイルのハッシュを控えた（前のセッションの控えは残っていないので、これを Step 8 の基準にする）。development DB に `-wal` はなく、件数は本体を scratchpad にコピーして `immutable=1` で開いて数え、Step 7 の手動確認の後と同じだった（OP `oauth_access_grants` 31・`oauth_access_tokens` 77（revoke 済み 14）、RP `sessions` 12・`op_users` 1。どちらの DB も `integrity_check` は ok。見出しの 18・19 バイト目は 2・2 で WAL のまま）。

- 開始時に、前のセッションのサーバーが残っていないことを、`ps` とポートの待ち受け（`lsof`）で確かめた
- Step 7 の手動確認の前に取った 3 アプリの `tmp/manual_check_backup/`（本体だけ）を、research の出口で、人間に確かめて消した（論点 8）
- research の試行の worktree（scratchpad）は、出口で外した。試行で入れた gem は、本体の各アプリの `vendor/bundle/ruby/3.4.0` に残っている（ruby の作業で使う）
- 写しを消し、worktree を外した後も、12 ファイルのハッシュは開始時と同じで、`-wal` はない

### gem ごとの対応

| gem | バージョン | 対応 |
|---|---|---|
| json | 2.7.2 → 2.21.2（3 アプリ。Ruby 3.3.12 のまま） | Gemfile の「# 追加」の節に `gem 'json', '~> 2.21', '>= 2.21.2'` と理由のコメントを足し、`bundle lock --update json --conservative` → `BUNDLE_CACHE_PATH=vendor/bundle/ruby/3.3.0/cache bundle install --local --no-cache`。lock で動いたのは json と `DEPENDENCIES` の json だけ。`.gem` は research で RS に落として照合したもの（3 アプリとも `scripts/verify-gem-checksums --changed HEAD` で一致）。RS `499fad1`、RP `e41919d`、OP `e2293a9`（作業計画の論点 2） |
| Ruby | 3.3.12 → 3.4.11（3 アプリ） | `.ruby-version`・Gemfile の `ruby` を 3.4.11 にし、lock の default gem を 3.4.11 の版に合わせ直した（Gemfile に版を一時的に足して `bundle lock` → 行を消して `bundle lock`）。RS `4636b45`、RP `c4cf11f`、OP `054c686`。lock は 3 アプリとも、research の試行の lock と json（2.21.2）・ostruct（0.6.1）だけが違う形になった。`.gem` は research で落として照合したものを `vendor/bundle/ruby/3.4.0/cache` から `--local --no-cache` で入れ、`Fetching` はない。`scripts/verify-gem-checksums --changed HEAD` は RS 14・RP 13・OP 14 個で一致。lock の gem は bundler を除いてすべて `vendor/bundle/ruby/3.4.0` から読まれる。Bundler の下で読まれる resolv は 0.7.2、erb は 4.0.4.1（3 アプリ）。CI の setup-ruby は、その前に v1.329.0 にした（`9b4b223`。論点 5）。RuboCop の `TargetRubyVersion` は 3.4 にした（`72175f1`。指摘なし。`Lint/ItWithoutArgumentsInBlock` は 3.4 で対象外になり、`Style/ItBlockParameter` は 3.4 から対象だが、どちらも pending で `NewCops: disable` のまま） |
| default gem（lock） | 3 アプリ: bigdecimal 3.1.5→3.1.8、drb 2.2.0→2.2.1、mutex_m 0.2.0→0.3.0、io-console 0.7.1→0.8.1、irb 1.13.1→1.14.3、logger 1.6.0→1.6.4、psych 5.1.2→5.2.2、rdoc 6.6.3.1→6.14.0、securerandom 0.3.1→0.4.1、stringio 3.1.1→3.1.2、uri 0.13.3→1.0.4。増えた: erb 4.0.4.1（3 アプリ）、cgi 0.4.2（RS・OP。RP は元からある）。消えた: ruby2_keywords 0.0.5（3 アプリ）。OP: ostruct 0.6.0→0.6.1 | 作業計画の論点 2。reline 0.6.0・base64 0.2.0・tsort 0.2.0・cgi 0.4.2（RP）は動いていない。`RUBY VERSION` 3.4.11p137、`BUNDLED WITH` 2.6.9 |
| ostruct | 0.6.1（RS・RP に追加） | Gemfile の「# 追加」の節に `gem 'ostruct', require: false` と理由のコメントを足した。Ruby を上げるコミットに入れた（論点 3） |
| faraday-net_http | 3.0.2 → 3.4.4（RS・RP。Ruby 3.4.11 の後） | Gemfile に faraday-net_http 3.4.4 と net-http 0.6.0 を一時的に足して `bundle lock --update faraday-net_http --conservative` → 行を消して `bundle lock --local`。lock で動いたのは faraday-net_http と、増えた net-http 0.6.0（一時固定。Ruby 3.4.11 の default gem と同じ版）だけ。`.gem` は research で落として照合したもの（`--changed HEAD` で 2 個とも一致）。net-http は `vendor/bundle` から読まれ、`Net::HTTP::VERSION` は 0.6.0。RS `905ec8a`、RP `3074896`（論点 4） |

### 非推奨警告と対応

| 警告 | 対応 |
|---|---|
| RS・RP: `rake-13.0.6/lib/rake.rb:33: warning: .../ostruct.rb was loaded from the standard library, but will no longer be part of the default gems starting from Ruby 4.0.0.`（Ruby 3.4 の bundled_gems の警告。`-W:deprecated` なしでも出る。minitest と E2E のサーバーの起動の `db:` タスクで出た） | Gemfile に `gem 'ostruct', require: false` を明示した（論点 3。Ruby を上げたコミット）。明示した後は出ない |
| chilled string（`RUBYOPT=-W:deprecated`） | 試行と各アプリの前後の比較で、minitest・E2E のサーバーの出力・development の eager load のどれにも出なかった |
| OP: doorkeeper-openid_connect の `auth_time_from_resource_owner` の DEPRECATION | 元からある（IMP-011）。Step 8 で変わっていない |

### 意図的な仕様変更

なし

### 前後の比較

- json（gems）: 作業の前（`718c5e3`）に `scripts/check-apps`（36 の検査と E2E がすべて通った）と `scripts/compare-config dump`（3 アプリの test・development）を取った。`RUBYOPT=-W:deprecated` の minitest・eager load・E2E の前の書き出しは、research で同じアプリのコードの本体で取ったものを使った。各アプリの後に、compare-config（そのアプリの test・development）は前と同じ。`RUBYOPT=-W:deprecated` を付けた `scripts/check-apps --app <アプリ>`（E2E を含む）は通り、警告は OP の IMP-011 の DEPRECATION だけ（前と同じ）。応答のスナップショットと E2E のスナップショットの差分はない
- Ruby（ruby）: 作業の前（`9b4b223`、3.3.12、json 2.21.2 の後）に、`RUBYOPT=-W:deprecated` を付けた `scripts/check-apps`（36 の検査と E2E がすべて通った）、`RUBYOPT=-W:deprecated` の minitest と development の eager load、test.log・development.log の新しい行、`scripts/compare-config dump`（3 アプリの test・development）、`scripts/check-console`（3 アプリ。irb 1.13.1）を取った。各アプリを 3.4.11 にした後に、同じものを取って比べた
  - 検査: 各アプリの 11 の検査と E2E が通った（minitest RS 11・RP 33・OP 69 runs、`CI=1` も同じ。E2E 10 passed）。応答のスナップショットと E2E のスナップショットの差分はない
  - 警告: `RUBYOPT=-W:deprecated` の minitest・E2E のサーバーの出力・development の eager load で、新しい警告はない（ostruct の bundled_gems の警告は、RS・RP で明示したので出ない。chilled string の警告は出ない。OP の IMP-011 の DEPRECATION は前と同じ）。development.log に WARN・ERROR の行はない
  - compare-config: 3 アプリとも test・development の違いは 3 行ずつで、どれも書き出しの道具が、もうない設定（`return_only_media_type_on_content_type`・`use_big_decimal_serializer`・`allow_deprecated_parameters_hash_equality`）を読んだときの `NoMethodError` のメッセージの開きの引用符（バッククォートからシングルクォートへ。Ruby 3.4 のエラーメッセージの形の変化。NEWS-3.4.0）。設定の値と読み込み済みの部品は変わっていない
  - `rails c`: 3 アプリとも起動し、Tab の補完と複数行の入力ができる（irb 1.14.3・reline 0.6.0・io-console 0.8.1）
- faraday-net_http（gems）: 前の書き出しは、Ruby を上げた直後の RS・RP のもの（その後の変更は `TargetRubyVersion` だけ）。各アプリの後に、compare-config（test・development）は前と同じ。`RUBYOPT=-W:deprecated` を付けた `scripts/check-apps --app <アプリ>`（E2E を含む。RS の introspection、RP の JWKS・トークン・introspection・RS への呼び出し）は通り、警告はない。応答のスナップショットと E2E のスナップショットの差分はない

### 手動確認

verify で、すべての変更（json 2.21.2、Ruby 3.4.11、`TargetRubyVersion` 3.4、faraday-net_http 3.4.4）の後（`e27a4b9`）に、`.claude/launch.json` から 3 アプリを起動してブラウザペインで確かめた（操作は人間）。RS・RP は、プレビューの出力で Ruby 3.4.11・Puma 8.0.2・threads 3 で起動したことを確かめた。OP は、出力の初め（起動の行）がプレビューに残っていなかったので、起動の行は確かめていない（要求に応えたことと、`.ruby-version` の 3.4.11 で動く mise の経路は確かめた）。

- 直前に、3 アプリのサーバーが止まっていて、12 ファイルのハッシュが作業の開始時と同じことを確かめ、3 アプリの development DB の本体（`-wal` はない）を `tmp/manual_check_backup/` に写した（写しのハッシュは元と同じ。作業計画の論点 8）
- 1 回目の起動（10:37）の後、人間の操作の前に、アプリがプレビューを止めた（11:07。`was stopped by the app`）。その間に、プレビューが起動の直後に RP のトップページを開いたので、RP の development DB だけが変わった（`sessions` 12 → 14）。21:54 に 3 アプリを起動し直して確かめた
- ログイン（RP の my_op）: 人間が「Login」を押した。OP のログイン画面が出て（Step 7 は OP のセッションが残っていて出なかった）、ログインの後、OP の認可エンドポイントが 302、トークン・userinfo・JWKS が 200。OP のログの「Redirected to」行は `code=[FILTERED]`
- introspection 用 RP: 同意画面と Authorize の後、RS は正しいトークンで 200、その後 401 が 2 回。OP はクライアントクレデンシャルのトークンを 3 回、introspect を 3 回、revoke を 1 回受けた。Step 7 と同じ
- 起動の直後: プレビューが同時に送った `HEAD "/"`・`GET "/"` は、RS・OP とも 200
- サーバーの出力: 3 アプリとも warning・DEPRECATION はない。エラーは、元からある RP の `/stylesheets/application.css`・OP の `/stylesheets/doorkeeper/application.css`・RS と OP の歓迎ページの `/icon.png` の `ActionController::RoutingError` だけ。Active Storage の image_processing gem の行（DEF-8.1-29）は、3 アプリとも起動のたびに development.log に出た（Step 7 と同じ）。`preview_logs` の検索では見つからなかったが、プレビューに残っていた出力は初めの部分が欠けていた（OP は起動の行もなかった）ので、サーバーの出力に出なかったとは言えない
- 手動確認用の環境: OP の development DB は `oauth_access_grants` が 31 → 33 件、`oauth_access_tokens` が 77 → 82 件（my_op 1・introspection 用 1（revoke 済み）・RS のクライアントクレデンシャル 3。revoke 済みは 14 → 15）。RP は `sessions` が 12 → 14 件、`op_users` は 1 件のまま。どちらも `integrity_check` は ok。サーバーを止めた後、`-wal` は残っていない。ファイルの見出しは WAL のまま（見出しの 18・19 バイト目で確かめた）。変わったのは OP・RP の DB の本体だけで、RS の DB・署名鍵・`.env`・3 アプリの secret は変わっていない。手動確認の後の 12 ファイルのハッシュを新しい基準にした。写しは、この Step の PR が epic に入った後に、人間に確かめてから消す
- RP の `sessions` が増えたこと（Step 7 までは手動確認の前後で 12 件のまま）: 増えたのは id 31（10:37。1 回目の起動の直後の、クッキーのない要求）と id 33（21:55。今回のログイン）で、前回（Step 7）のログインの行（id 30）が残った。Step 7 では、ブラウザに前回のセッションのクッキーが残っていて、ログインがその行を置き換えた。今回は、OP でもログイン画面が出たので、アプリがプレビューを止めたときにブラウザのセッションのクッキー（期限のないもの）が消えていた見込み（確かめたのは行の id と時刻、OP のログイン画面が出たこと）。行の中身の長さは前と同じ形（71・83 バイト）

### 遭遇した問題

| 問題 | 対応 |
|---|---|
| RS の json のコミットで、`scripts/commit-per-app` の中の E2E が webServer の起動待ち（120 秒）で時間切れになった。2 回目の commit-per-app は、ログのディレクトリを作ってから最初のログまで 16 分空いた | `pmset -g log` で、マシンが 09:23〜09:40、09:41〜09:57、09:58〜10:14 に Maintenance Sleep に入っていたと分かった（同じ時間の検査が止まっていた）。E2E だけを流し直すと通り、2 回目の commit-per-app も通ってコミットした |
| RP の json のコミットで、commit-per-app 全体に `RUBYOPT=-W:deprecated` を付けたため、git の hook（`scripts/check-public-safety`。macOS 標準の Ruby 2.6）に渡り、`ruby: invalid option -:` でコミットが止まった（検査はすべて通っていた） | 作業ツリーが検査の通ったときと同じことを確かめ、`RUBYOPT` なしでコミットした。OP からは、`RUBYOPT` を検査（`scripts/check-apps --app op`）だけに付け、通った作業ツリーをそのままコミットした |

### 確認結果

verify で、PLAN.md の 10 章の完了条件を確かめた。

- `scripts/check-apps`（3 アプリと E2E）: すべての変更と記録のコミットの後（`e27a4b9`）に、36 の検査がすべて通った。各コミットの前には、そのアプリと E2E を `RUBYOPT=-W:deprecated` 付きで流した
- minitest: RS 11 runs・15 assertions、RP 33・71、OP 69・123、0 failures。`CI=1`（eager load あり）でも同じ
- E2E: 10 passed。応答のスナップショットと E2E のスナップショットの差分は、この Step を通して出なかった
- RuboCop（`TargetRubyVersion: 3.4`）・`zeitwerk:check`・起動の途中の読み込みの検査（test・`CI=1`・development）・bundler-audit（無視リストは空。3 アプリとも `No vulnerabilities found`）・brakeman（3 アプリとも `Security Warnings: 0`）: すべて通った（`check-apps` の項目）
- lock: epic（`b5e4afd`）からの動きは、作業計画の論点 2・4 のとおり（合わせ直した default gem、json 2.21.2、増えた erb・cgi（RS・OP）・ostruct（RS・RP）・net-http（RS・RP）、消えた ruby2_keywords、faraday-net_http 3.4.4、`RUBY VERSION`・`BUNDLED WITH`、`DEPENDENCIES` の json・ostruct）。default gem に合わせていない固定（connection_pool 2.5.5・date 3.5.1・timeout 0.6.1・racc 1.5.2・minitest 5.14.4・rack 2.2.24）は動いていない
- `bin/rails c`: `scripts/check-console` で 3 アプリとも起動した（irb 1.14.3・reline 0.6.0・io-console 0.8.1。Tab の補完と複数行の入力ができた）。`bin/rails s`: 手動確認で 3 アプリとも起動した
- 公開物の安全チェック: 各コミットの hooks で通った
- CI: push の後に確かめる（push は人間が行う）。setup-ruby v1.329.0 で 3.4.11 を入れられることも、そのときに見る
- 手動確認用の環境: 上の「手動確認」。手動確認の後の 12 ファイルのハッシュを新しい基準にした

### コードレビュー（`/code-review`）

| 指摘 | 対応 |
|---|---|
| 手動確認の「3 アプリとも Ruby 3.4.11・Puma 8.0.2・threads 3 で起動した」は、OP については起動の行を確かめていない（プレビューに残っていた出力の初めが欠けていた） | 記録を直した。RS・RP は出力で確かめ、OP は起動の行を確かめていないと書き分けた（人間が判断） |
| 「Active Storage の行は `preview_logs` の出力には出なかった」は、残っていた出力が欠けていたので言えない | 記録を直した。development.log に出たことと、プレビューの出力では見つからなかったが欠けていたことを書いた（人間が判断） |
| `scripts/lib/dump_config.rb` が例外のメッセージをそのまま書き出すので、Ruby を上げるたびに引用符の違いが compare-config の差分に出る | 直さない。Step 7 のコードレビューの指摘（dump_config がアプリのディレクトリの場所に頼る）と同じく、道具の見直しで扱う（下の気づきの 16。人間が判断） |
| Gemfile の `gem 'json'` に `require: false` がなく、ostruct の行と揃っていない | 直さない。json は Rails が読むので、起動で読み込まれるものは変わらない（compare-config で前後同じ）。直すと 3 アプリのコミットと検査のやり直しが要る（人間が判断） |
| Gemfile の json のコメントが「Ruby 3.4 の default gem の json（2.9.1）」と版を書いていて、Ruby 4.0 で古くなる | 直さない。Ruby を上げる Step で json の扱いと一緒にコメントも直すことを、PLAN.md の 7 章の json の行に書き足した（人間が判断） |
| TIPS.md の「lock に入れた default gem」の一覧に、アプリの別（net-http は RS・RP だけなど）がない | 直した。net-http・cgi・ostruct がどのアプリに、何の依存で入っているかを書き足した（人間が判断） |

- 直したのは記録と TIPS.md・PLAN.md だけで、アプリと道具のコードは変えていない

### スキルについて気づいたこと

Step 3〜7 と同じく、スキルの手順・型・設定で、足りない・合わない・迷ったところを控える（スキルを直すかは人間が判断する）。

resume:

1. ローカルの `epic/rails-8.1-upgrade` が origin より古く、#36 の取り込みが入っていなかった（Step 5 の気づきの 3、Step 6 の気づきの 1、Step 7 の気づきの 1 と同じ）。人間の指示にあったので、fetch して早送りしてから切った。前のセッションのサーバーは、人間の指示にあったので `ps` と `lsof` で確かめた（Step 7 の気づきの 2）

research:

2. mise 2026.5.10 の `mise install` は、入れる前に ruby-build を GitHub の最新のリリースと比べ、違えばリポジトリを clone し直す。TIPS.md の「Ruby を上げる」は Step 4 の時点で「手元の ruby-build は最新と同じ」としていて、この clone がダウンロードの確認に入ることと、その版が公開から 2 週間たっていないことがある（今回は 1 日目）ことを書いていない
3. CI の setup-ruby の固定（v1.325.0）が 3.4.11 を持たなかった。Step 4 の「Ruby の版を持つ箇所」は「ci.yml は `.ruby-version` を読むので変えなくてよい」としていて、固定した setup-ruby が新しい版を持つかは、別に確かめる必要がある（Step 4 は `ruby-builder-versions.json` を見ていた）
4. research の途中で日付が変わった（10-13 → 10-14。Step 7 の気づきの 9 と同じ）
5. 新しい Ruby を research で試すときの worktree の作り方（`vendor/bundle` と `e2e/node_modules` を本体へのシンボリックリンクにする、OP の署名鍵を使い捨てで作る、E2E 用・テスト用の DB を写す、`MISE_TRUSTED_CONFIG_PATHS`）を、Step 7 の記録から組み立て直した。research.md に手順はない（Step 6 の気づきの 9、Step 7 の気づきの 4・11 と同じ）
6. resolve で消える gem が、また出た（3 アプリの ruby2_keywords 0.0.5。drb 2.2.1 が依存しなくなった）。Step 3・5・6・7 に続いて 5 回目。合わせ直した lock を実際に解決して見つけた
7. 8 章の 4 の「default gem の版に合わせ直す」は、合わせる先の版が advisory の対象でないことを前提にしていた。3.4.11 の json 2.9.1 が CVE-2026-54696 の対象だと、試行の bundler-audit で初めて分かった。research で、合わせ直す先の版を bundler-audit（無視リストなし）にかける手順があると、試行の前に分かる
8. TIPS.md の「Ruby を上げる」の、一時的に足した行を消して `bundle lock --local` する手順は、その版が入っていないと解決できない（試行で json を 2.7.2 に戻したときに失敗した）。メタデータだけを取る `bundle lock` に替えた
9. chilled string の警告は、通った経路でしか出ない。設定の「前後の比較」の `RUBYOPT=-W:deprecated` は minitest と eager load だけで、サーバーの経路は見ない。今回は E2E も `RUBYOPT=-W:deprecated` で流し、Playwright が出すサーバーの stderr を比べた
10. 論点 2・5 で、人間は掘り下げた（Gemfile への書き方、Ruby 4.0 で解決するか、世の中の対応、2 週間の決まりの例外にできるかの差分の中身）。Step 7 の気づきの 6 と同じく、最初の示し方に、次の 3 つを入れておけば往復が減った
    - 案ごとの具体的な書き方（Gemfile のどこに何を書くか）
    - 先の Step（Ruby 4.0）でどうなるか
    - 2 週間たっていない版の差分の中身
11. 論点 1 で、AI は mise を通さずに ruby-build を直接流す案を推したが、人間は mise の普段の入れ方を選んだ。mise が入れる前に ruby-build を取り直すことは、TIPS.md に書いていなかった（気づきの 2）

gems:

12. `RUBYOPT=-W:deprecated` を付けた検査とコミットを一度に流すには、commit-per-app に検査だけの環境変数を渡す口がない。全体に付けると git の hook（Ruby 2.6）まで渡って止まる。今回は、検査を `scripts/check-apps --app` で流してから、作業ツリーのままコミットした
13. マシンのスリープで検査が止まり、E2E が時間切れになった。止まった理由がスリープだと、`pmset -g log` で後から分かった。検査が普段より長いときや、時間切れのときに、まずスリープを疑う手順がない

verify:

14. 手動確認を頼んでから人間が操作するまでの間に、アプリがプレビューのサーバーを止めた（`was stopped by the app`）。人間の「表示した」の返事の後に `tabs_context` と `preview_list` で気づき、起動し直した。その間に、プレビューが開いた RP のトップページで RP の DB が変わり、ブラウザのセッションのクッキーも消えていて、手動確認の結果（RP の `sessions` の件数）が前の Step と比べにくくなった。manual-check.md の手順 3 は、操作を頼む前にブラウザの画面を確かめるだけで、操作の返事の後にサーバーが動き続けていたかを確かめる手順がない
15. 手動確認の前に、ブラウザペインが隠れていて、表示してもらう往復が要った（Step 5 の気づきの 16、Step 6 の気づきの 17、Step 7 の気づきの 15 と同じ）

pr:

16. コードレビューで、`scripts/lib/dump_config.rb` が例外のメッセージをそのまま書き出すので、Ruby を上げると、メッセージの形の変化（Ruby 3.4 の引用符）が compare-config の差分に出ると分かった。Step 7 の気づきの 16（アプリのディレクトリの場所に頼る）と合わせて、道具の見直しで扱う候補
17. 手動確認の記録で、`preview_logs` に残っている出力が初めから欠けていることがあり、起動の行や起動の直後の警告を後から確かめられなかった。manual-check.md の手順 4 は「サーバーの出力を読む」だけで、起動の直後に読む（残っているうちに控える）決まりがない

## Step 9: Ruby 4.0（2026-10-14）

- ブランチ / PR: `upgrade/step9-ruby40` / （PR 作成後に記入）
- バージョン: Ruby 3.4.11 → 4.0.9 / Rails 8.1.4（変更なし）

### 作業計画で決めたこと

`/rails-upgrade` の research で調べた（サブエージェント 4 つ: Ruby 4.0 の事実、lock の gem の 4.0 への対応、Bundler 2.6.9 → 4.0.20 の変化、合わせ直すとメジャー版をまたぐ gem の変化。4.0.7 の版・tarball・保守の状況・json の版・bundled gems の一覧、minitest 5.14.4 の Ruby の要件、mise の ruby-build の版、lock の試行と bundler-audit、Bundler 4 の lock の書き直しと CHECKSUMS、faraday・oauth2 が Content-Type を付けること、railties の minitest 6 への対応は自分で確かめた）。論点を 1 つずつ人間と確かめ、決まるたびにこの表に足す。

| 論点 | 決めたこと | 理由 |
|---|---|---|
| 1 Step 9 を行うか | 行う（PLAN.md の 14 章の未決事項）。research の前に、判断の材料を 1 論点として示した | 4.0 は公開から 10 か月で、パッチ版が 7 回出ている（4.0.7 は 2026-09-15）。主な gem の CI は 4.0 を含む。lock の gem で 4.0 に入らないのは minitest 5.14.4（`required_ruby_version` が `< 4.0`）だけで、Step 8 の json と同じく Ruby の前の gems の作業に分けられる。3.4 は normal maintenance で急ぐ理由はないが、外れる default gem と cgi の扱いを今の流れ（合わせ直し・前後の比較・試行）でまとめて片付けておくと、epic の後の保守が楽になる。リスク（Bundler 4 への移行、minitest を大きく上げること、byebug の `bt`（byebug#981））は、research の試行で確かめる |
| 2 版と、research で入れて試すか。版を固定するときの書き方 | 4.0.7 にする。research で `mise install ruby@4.0.7` で入れ、scratchpad に HEAD の git worktree を作り、3 アプリを 4.0.7 にして、lock を 4.0.7 の default gem・bundled gems の版に合わせて解決し（json は 2.21.2 のまま）、`BUNDLE_PATH` を本体の各アプリの `vendor/bundle`（新しい `ruby/4.0.0`）に向けて入れる。worktree で `scripts/check-apps`（E2E を含む）、`RUBYOPT=-W:deprecated` の minitest・eager load・E2E のサーバーの出力、ログの WARN・ERROR、`scripts/check-console`（byebug を含む）、`TargetRubyVersion: 4.0` の RuboCop を流し、minitest は 5.27.0 と 6.0.6 の両方を試す。本体の Gemfile・lock と手動確認用の環境は変えず、research の出口で worktree を外す。ダウンロード（tarball 23,937,964 B、`.gem` 18 個・計 1,460,736 B）は、この論点への返事で承認を得た。`.gem` は RS で 1 回だけ落として照合し、RP・OP のキャッシュにコピーする。ruby-build に新しいリリースが出ていて取り直しが起きるときは止まる。**版を固定するときは、一時固定（Gemfile に足して lock を解決し、行を消す）をやめ、Gemfile に版・理由のコメント・`require: false` を書く**（人間の希望）。4.0.7 の版に合わせ直す gem（bigdecimal・base64・drb・logger・rdoc・irb・reline・ostruct・erb・uri・psych・stringio・io-console・pp・prettyprint・securerandom・tsort）は Gemfile の 1 つのまとまりにして、理由を先頭に 1 つ書く。net-http・minitest は行ごとに理由を書く。前の Step からの lock だけの固定（connection_pool・rack・racc・date・timeout、RP の cgi）は Step 9 では動かさず、PLAN.md の 7 章に書いて、14 章の間接の gem の更新で扱う。8 章の 4 と TIPS.md の一時固定の手順は、research の出口でこの書き方に直す | 4.0.7 は 4.0 系の最新（2026-09-15）で、公開から 2 週間たっている。CI の setup-ruby v1.329.0 は 4.0.7 を持つ。Bundler 4.0.20 での lock の書き直しと `--local --no-cache`、minitest の版ごとのテストと simplecov、RP に残る cgi 0.4.2 のビルド、RS・OP で cgi が消えた後の `require 'cgi'`、net-http 0.9.1（0.7.0 から本文のある要求に Content-Type を自動で付けない。#207）での RP・RS・OP の間のやり取り（WebMock の minitest では検出できない）、byebug の `bt`（#981）は、入れて流さないと分からない。Bundler 4 が lock を書き直すのはファイルの形（`BUNDLED WITH`・`RUBY VERSION`）だけで、gem の版は動かない（rubygems v4.0.20 の `definition.rb:401-413`）。一時固定は Bundler の文書にある手順ではなく（man の `bundle-update`・`bundle-install` は、lock の版が更新を指定しない限り変わらないことだけを書く）、版は lock にしか残らない。Rails 自身の Gemfile（v8.1.4 の uri・connection_pool・json）と GitLab の Gemfile（logger・fugit・zeitwerk）は、間接の gem の制約を理由のコメント付きで Gemfile に書いている。lock だけの固定は、仕上げで入れる Dependabot の security updates から見ると固定ではない。4.0.7 の版に合わせる目的では範囲の制約では足りないので `=` で固定する。`require: false` がないと `Bundler.require` が起動のときに irb・rdoc・pp などを読み込む |
| 3 minitest の版と作業の順 | minitest を 5.14.4 → 6.0.6 にする（案 b）。Ruby の前に gems の作業で上げる（Ruby 3.4.11 のまま、RS → RP → OP）。Gemfile に `gem 'minitest', '6.0.6', require: false` と理由のコメント（5.14.4 は Ruby 4.0 に入らない）を書き、同じコミットで test グループの mutex_m の行（Step 5）を外す。`.gem` は research で落として照合したものを、3.4.0 のキャッシュにコピーして使う。assertions の件数の変化は、gems の作業の前後の比較で理由とともに記録する | minitest 5.14.4 は `required_ruby_version` が `>= 2.2, < 4.0` で Ruby 4.0 に入らない。6.0.6 は 6 系の最新（2026-05-01）で、Gemfile に書く直接の gem になるので 7 章の「直接の gem は最新版に」に当たる。Rails v8.1.4 の開発用の lock も 6.0.6 で、Rails は 8.1.2 から minitest 6 に対応している（#56434。railties 8.1.4 の `rails_plugin.rb:108`）。5.27.0（5 系の最終版）は post install message で 5 系の EOL を告げている。6.0.0（Ruby 4.0.7 の bundled gems の版）は 6.0.1〜6.0.6 の直しを含まない。試行で、3 アプリのテストはすべて通り、simplecov のカバレッジも出た。assertions の件数は RP 71 → 82、OP 123 → 129 になった（runs は同じ）。minitest 6 の `assert_operator`・`assert_predicate` が先に `assert_respond_to` を数え（minitest 6.0.6 の `assertions.rb:295`・`374`）、Rails の `assert_redirected_to`（actionpack 8.1.4 の `response.rb:71`）と `assert_select`（rails-dom-testing 2.3.0 の `selector_assertions.rb:347`）がそれを使うため。RP のテストごとの比較で、増えたのはリダイレクトと `assert_select` を確かめるテストだけだった。5.21.0 から mutex_m を読まず、lock に mutex_m を読むほかの gem はない。Ruby の前に分けるのは、minitest と Ruby の変化を別の前後の比較にするため（Step 8 の json と同じ） |
| 4 Ruby の版の見直し（論点 2 の後に 4.0.8・4.0.9 が出た） | 4.0.7 をやめて **4.0.9** にする（案 a。人間が選んだ）。Ruby 4.0.9・ruby-build v20261023・setup-ruby v1.334.0（`26e5b7d197ebf60545ee9667bcbace0be11ccaec`）を、公開から 2 週間の決まりの例外にする。4.0.9 は research の中で入れ、worktree での試行はやり直さない（ruby の作業で検査・E2E・前後の比較をすべて流す）。CI の setup-ruby の 4 か所は、ruby の作業の最初のコミットで v1.334.0 にする。ダウンロード（tarball 23,946,524 B、mise が取り直す ruby-build 約 3 MB）は、この論点への返事で承認を得た。`.gem` は増えない（4.0.7 のときに落として照合したものを使う）。入れた 4.0.7 は mise に残す | 論点 2 の返事の後（10-14 → 10-24）に、4.0.8（10-22、bugfix）と 4.0.9（10-23）が出た。4.0.9・3.4.12・3.3.13 は、正規表現のエンジン（Onigmo）の不具合の修正を含む（ruby-lang.org「Regexp compilation fixes related to GitLab's CVE-2026-89078, CVE-2026-93577, CVE-2026-97229 and CVE-2026-110264」、2026-10-23）。GitLab はリモートでのコード実行の CVE を付け、Ruby 自身は CVE を求めていない。4.0.7 は 3 つの修正のうち #13332 だけを含み、#19020（4.0.8）・#16801（4.0.9）を含まない。今の epic の 3.4.11 も対象。影響は、攻撃者が制御する文字列から正規表現を作るときだけで、3 アプリの `app`・`lib`・`config` にその書き方はなく、doorkeeper 5.9.9・rack 2.2.24 の `Regexp.union` は固定の文字列か設定から作る。AI は、影響の経路が見当たらないので 4.0.7 で進めて 2 週間後に 4.0.9 に上げる案 b を推したが、人間は、セキュリティの修正であることと、間接の gem での使い方を調べきれないことから、案 a を選んだ。4.0.7 → 4.0.9 の差分（94 ファイル）で版のファイルが変わったのは prism 1.8.1 → 1.8.2（lock は 1.9.0 で、合わせ直す対象ではない）だけで、bundled gems・Bundler 4.0.20・json 2.18.0・ABI は同じ。ruby-build v20261023 は定義の追加と OpenSSL の条件を `1.1.1-4.x.x` に広げた変更で、4.0.9 の定義の SHA256 は ruby-lang.org と同じ。setup-ruby v1.329.0 → v1.334.0 は 6 コミット（版の一覧、Windows の一覧、版が見つからないときのメッセージ、`rubygems:` の入力の版の比べ方を semver から `Gem::Version` に）で、ci.yml は `rubygems:` を使わない（`index.js:80`）。`dist/index.js` はモジュールごとに比べ、semver の削除とこれらの変更だけだと確かめた |
| 5 lock の合わせ直しと、Gemfile のまとまり | ruby の作業の各アプリの Ruby を上げるコミットで、Gemfile の「# 追加」の節の後に、4.0.9 の版に合わせ直す gem のまとまり（先頭に理由のコメントを 1 つ、各行は `= 版`・`require: false`）を書く。bundled gems は base64 0.3.0・bigdecimal 4.0.1・drb 2.2.3・irb 1.16.0・logger 1.7.0・ostruct 0.6.3・rdoc 7.0.4・reline 0.6.3、default gem は erb 6.0.7・io-console 0.8.2・net-http 0.9.1（RS・RP）・pp 0.6.3・prettyprint 0.2.0・psych 5.3.1・securerandom 0.4.1・stringio 3.2.0・tsort 0.2.0・uri 1.1.1。RS・RP の ostruct は今の行（rake 13.0.6 のため）に版を足し、コメントに 4.0.9 の版にすることを足す。OP の ostruct はまとまりに入れる。json の行はそのままにして、コメントを 4.0 の default gem の json（2.18.0）が CVE-2026-54696・CVE-2026-33210 の対象と直す。RS・OP から cgi 0.4.2 が消えるのは受け入れる。RP の cgi 0.4.2 は 0.4.2 のままにし、`-w` のときの「method redefined」の警告と、14 章の間接の gem の更新で cgi 0.5 系を見直すことを 7 章に書く。手順は、Ruby を上げる作業では、Gemfile を直して `BUNDLER_VERSION=4.0.20 bundle lock --local` → `git diff` → `BUNDLE_CACHE_PATH=vendor/bundle/ruby/4.0.0/cache bundle install --local --no-cache` → `scripts/verify-gem-checksums <アプリ> --changed HEAD`。minitest の作業（Ruby 3.4.11）では、照合済みの `.gem` を 3.4.0 のキャッシュにコピーし、Gemfile を直して目録だけを取る `bundle lock`（`--local` なし）→ `git diff` → `bundle install --local --no-cache` → 照合。8 章の 4 と TIPS.md の手順は research の出口でこの形に直す | 試行（4.0.7）で、lock で動いたのはまとまりの gem・minitest・増える pp・prettyprint（irb 1.15.0 からの依存）・消える mutex_m と cgi（RS・OP。erb 5.0.0 から依存しない）だけで、3 アプリの検査と E2E が通った。4.0.9 の default gem・bundled gems の版は、4.0.7 と prism（合わせ直す対象外）のほかは同じ。Ruby 4.0 の `lib/cgi.rb` は `cgi/escape` を読む stub で、Rails 8.1.4 は 4.0 で `cgi/util` を読まない。`-w` のときだけ、RS・OP で i18n 1.8.10 の `require 'cgi'` の警告、RP で cgi 0.4.2 の C 拡張が Ruby の `cgi/escape` のメソッドを定義し直す警告が出る。RP の cgi は activerecord-session_store の `cgi >= 0.3.6` で残り、論点 2 の「前の Step の lock だけの固定は動かさない」に当たる。`bundle lock` は Gemfile.lock だけを書く（scratchpad のコピーで流し、書き換わったのが Gemfile.lock だけで、`vendor/bundle`・`~/.bundle`・`~/.gem` は変わらないことを確かめた）。`--local` は rubygems.org につながず（`cli/lock.rb:68`）、候補は入れ済みの gem と、見つからないときの default gem だけ（`source/rubygems.rb:161-170`）で、キャッシュの `.gem` は候補にしない。ruby の作業で `--local` で正しい lock になるのは、版を `=` で決め、その版の `.gem` を照合して research の試行で本体の `vendor/bundle/ruby/4.0.0` に入れてあり（3 アプリとも、まとまりの版と minitest 6.0.6 の gemspec と `.gem` がそろっていることを確かめた）、入れ済みの gemspec の依存と Ruby の要件が rubygems.org と同じ（irb 1.16.0・minitest 6.0.6・rdoc 7.0.4 で比べた）だから。scratchpad のコピーで `bundle lock --local --print` を流し、rubygems.org につながずに試行と同じ解決になった。minitest の作業の `vendor/bundle/ruby/3.4.0` には minitest 6.0.6 が入っていないので、`--local` は使えない |
| 6 Bundler 4 の `platforms` の非推奨の警告 | 案 a。ruby の作業の各アプリの Ruby を上げるコミットで、byebug の `platforms: %i[mri mingw x64_mingw]` を `%i[mri windows]` に、tzinfo-data の `%i[mingw mswin x64_mingw jruby]` を `%i[windows jruby]` に直す（Rails の雛形の形）。既定値・雛形への追随（A）として DEF-8.1-30（種類「Ruby」）に記録し、コミットの前に理解の関門で解説する | Bundler 4.0.20 は `platforms:` の mingw・mswin を非推奨にし、`bundle lock`・`bundle install` で `[DEPRECATED] Platform :mingw, :mswin, :x64_mingw will be removed in the future. Please use platform :windows instead.` を出す（`bundler/dsl.rb:431-435`。2.6.9 は出さない。`bundle exec` とアプリの起動では出なかった）。Rails の雛形は 7.1 から `:windows`（rails/rails#46009、2022-09-15 マージ。`railties-8.1.4/lib/rails/generators/rails/app/templates/Gemfile.tt:13・56`）。`app:update` は Gemfile を上書きしないので、Rails を上げる Step では上がらなかった。scratchpad の RS の Gemfile のコピーで直して `bundle lock --local` を流し、lock は変わらず、警告も出なくなった。`:windows` は 2.6.9 でも使える（`bundler/current_ruby.rb:23`）。違いが出るのは Windows のときだけ |
| 7 byebug 13.0.0 の Ruby 4.0 での扱い | CLAUDE.md の ①（対応版を待つ）。byebug は 13.0.0 のままにする。research の出口で、IMP-013 の「現状」に Ruby 4.0 でも `where` が失敗することと byebug#981 を足し、「対象」の Gemfile の行を論点 6 の後の形（`platforms: %i[mri windows]`）に直し、「記録した Step」に 9 を足す。7 章の byebug の行にも Ruby 4.0 のことを書き足す（今ある項目の書き足しで、新しい項目は足さない） | 試行（4.0.7）の RS の `scripts/check-console` で、`next`・`continue` は動き（終了の状態は 0）、`where` は Ruby 3.4 と同じく `undefined method 'Kernel.require' for class 'Kernel'` で失敗した（byebug#867。直す #967 は未リリース）。byebug#981（Ruby 4.0 で、スタックに `public_send` があると `bt` が失敗する）は open で、コメントも新しい版もない（10-24 の時点で 13.0.0 が最新）。アプリのコードは byebug を呼ばず、業務的な挙動には関わらない。② は lock に git の参照が入り `.gem` を照合できず、④ debug gem への置き換え（IMP-013）は開発の道具を替える改善なので epic の後に行う（Step 8 の論点 7 と同じ） |
| 8 rubocop・webmock をいつ上げるか | 案 b。Step 9 では上げず、仕上げの最初の作業にする（仕上げのチェックリストの先頭に `gems: rubocop・webmock` を足す）。その日に公開から 2 週間たった最新にし、これ以上先に送らない。仕上げを 11-05 より前に始めるなら、rubocop を 1.92.0 にするか 1.92.1 を待つかを人間に確かめる | 10-24 の時点で、rubocop 1.92.0（10-10）と webmock 3.27.0・3.28.0（10-10）が 2 週間たった。rubocop 1.92.1（10-22）は 1.92.0 の誤り（多くは自動修正）を 96 件直していて 11-05 から、webmock 3.34.0（10-14）は 10-28 から 2 週間たつ。rubocop-rails 2.38.0・rubocop-ast 1.50.0・rubocop-minitest 0.41.0 は最新。webmock 3.27.0〜3.34.0 はマッチの改善と直しで、3.28.0 の `to_rack` の変更は 3 アプリのテストに当たらない（Step 5 の着手時）。どちらも開発・テストの道具で、業務的な挙動には関わらない。Step 9 を Ruby 4.0 に絞れる。送り先を仕上げのチェックリストで固定し、Step 6 の気づきの 7（送りが続く）を繰り返さない |
| 9 手動確認の時期と DB の写し | verify で 1 回、すべての変更（minitest 6.0.6、Ruby 4.0.9、Gemfile のまとまり、`:windows`、`TargetRubyVersion` 4.0）の後に行う。直前に 12 ファイルのハッシュを確かめ、3 アプリの development DB を `tmp/manual_check_backup/` に写す。research の出口で、Step 8 の写し（3 アプリの `tmp/manual_check_backup/`）を消す。この論点への返事を作業計画の承認とした | RP・OP・RS の間のやり取りは、Ruby 4.0.9 と net-http 0.9.1（本文のある要求に Content-Type を自動で付けない）で変わり得る。minitest は WebMock で差し替えるので検出できず、E2E とブラウザでの流れ（RP の my_op でのログインと introspection 用 RP）で確かめる。Step 8 の写しは、#37 が epic に入ったので消してよい（resume で確かめた問いに返事がなかったので、ここで改めて確かめた） |

### 手動確認用の環境

resume で、前のセッションのサーバーが残っていないこと（`ps` とポートの待ち受け）を確かめてから、12 ファイルのハッシュを控えた。件数は、本体を scratchpad にコピーして `immutable=1` で開いて数え、Step 8 の手動確認の後と同じだった（OP `oauth_access_grants` 33・`oauth_access_tokens` 82（revoke 済み 15）、RP `sessions` 14・`op_users` 1。どちらの DB も `integrity_check` は ok。見出しの 18・19 バイト目は 2・2 で WAL のまま。`-wal` はない）。

- research の途中（10-14 → 10-24）で scratchpad の中身が消え、ハッシュの控えもなくなった。resume のときにチャットに出した先頭 12 桁と比べ、12 ファイルとも同じだった。research の出口で控え直した
- research の試行の worktree（scratchpad）は、scratchpad と一緒に消えていた。git の記録は `git worktree prune` で片付けた。試行で入れた gem は、本体の各アプリの `vendor/bundle/ruby/4.0.0` に残っている（ruby の作業で使う）
- Step 8 の手動確認の前に取った 3 アプリの `tmp/manual_check_backup/` を、research の出口で、人間に確かめて消した（論点 9）。消した後も、12 ファイルのハッシュは開始時と同じで、`-wal` はない

### スキルについて気づいたこと

Step 3〜8 と同じく、スキルの手順・型・設定で、足りない・合わない・迷ったところを控える（スキルを直すかは人間が判断する）。

resume:

1. ローカルの `epic/rails-8.1-upgrade` が origin より古く、#37 の取り込みが入っていなかった（Step 5〜8 と同じ）。人間の指示にあったので、fetch して早送りしてから切った。前のセッションのサーバーは、人間の指示にあったので `ps` と `lsof` で確かめた（残っていなかった）
2. resume.md は、Step 8 の後の次の作業を「次の Step の始めなら research」と決める。ロードマップで任意の Step（Step 9）を行うかを決める手順がなく、その判断でブランチ名（`upgrade/step9-...` か仕上げの名前）が変わるので、手順 2・3（ブランチを切る・最初のコミット）を判断の後に回した。今回は人間の指示で、判断の材料を 1 論点として示した
3. 手動確認の写し（Step 8 の `tmp/manual_check_backup/`）を消すかの問いに返事がないまま、Step 9 を行うかの論点を示した（それぞれのメッセージで 1 論点）。返事は Step 9 の論点にだけあったので、写しは消さずに残し、research の手動確認の論点で改めて確かめることにした。resume で確かめることと、Step の始めの論点が重なるときの順番が決まっていない

research:

4. mise が使う ruby-build の置き場所（macOS では `~/Library/Caches/mise/ruby/ruby-build`）が TIPS.md にない。版（v20261013、最新）を確かめるのに探した。最新なら、入れるときに取り直しは起きない（Step 8 の気づきの 2）
5. サブエージェントの報告で、版や番号の食い違いがあった（Ruby 4.0.7 の bundled gems の minitest は 6.0.0、net-http の Content-Type の変更は issue #205 を直した PR #207）。報告どうしを突き合わせ、要点を一次の出典で確かめて拾えた（research の手順 2）
6. `cd` を含むコマンドで Bash の作業ディレクトリが変わり、次のコマンドがアプリやスキルのディレクトリで動いた（2 回）。TIPS.md の「コマンドの実行」の注意と同じ
7. research の途中で日付が変わり（10-14 → 10-24）、その間に scratchpad の中身（試行の worktree、作業計画の下書き、手動確認用の環境のハッシュの控え）が消えた。決めた論点は LOG.md にコミットしてあったので、聞き直さずに続けられた（research の手順 7 の狙いどおり）。ハッシュの控えは、resume でチャットに出した先頭 12 桁と比べて確かめた。設定の「手動確認用の環境」とスキルは、ハッシュの控えを scratchpad に置く前提で、消えたときの手順がない
8. 論点 2 の返事から論点 3 の返事までの 10 日の間に、Ruby 4.0.8・4.0.9（正規表現のエンジンの不具合の修正）が出て、決めた版（4.0.7）を見直す論点が増えた。research.md は、論点の間に時間が空いたときに、版と advisory を確かめ直す手順がない（Step 8 の気づきの 4 と同じく、日付が変わった）
9. 試行の worktree で、OP の署名鍵（`jwtRS256.key`）を先に作らずに `scripts/check-apps` を流し、OP の zeitwerk:check と minitest が `Errno::ENOENT` で落ちた（E2E の起動スクリプトが鍵を作った後に流し直して通った）。Step 8 の気づきの 5 の手順（OP の署名鍵を使い捨てで作る）が research.md にないので、また抜けた
10. minitest のテストごとの assertions の数を出すのに、`RUBYOPT=-r` で TracePoint を使う形は何も出さず、worktree の `test/test_helper.rb` に一時的に数行足す形にした。worktree は使い捨てなので本体は変えていない
11. 人間は、論点 2 で一時固定の書き方、論点 5 で `bundle lock --local` の中身（何を書くか、なぜネットワークなしで正しいか、何が条件か）を掘り下げた。掘り下げの中で、AI の「今回の手順は 2 つの条件を先に満たす」という説明が、Ruby 3.4.11 のまま行う minitest の作業には当たらないと分かり、手順を分けた。Step 8 の気づきの 10 と同じく、最初の示し方に、コマンドが書く・読むもの（ファイル・ネットワーク・入れ済みの gem）と、その前提が成り立つ作業の範囲を入れておけば、往復が減った
12. コミットのコマンドに `grep -n` を同じ呼び出しで続けたら、Claude Code の hooks（`scripts/check-public-safety --claude-hook`）が `git commit -n` と見なして止めた。コミットは単独の呼び出しにする
13. scratchpad の coverage のディレクトリを、シェルの変数を使った `rm -rf` で消そうとして、Claude Code の安全チェックに止められた（変数が空なら `/` になるため）。消さずに更新日時で比べる形に変えた
14. `ruby -e` に日本語を渡すときの `LC_ALL=ja_JP.UTF-8` を付け忘れ、`invalid multibyte character` で止まった（TIPS.md の「コマンドの実行」にある注意）
