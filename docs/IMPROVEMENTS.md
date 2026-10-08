# 将来の改善点

Ruby / Rails のアップグレード中は挙動を変えない方針（[docs/upgrade/PLAN.md](upgrade/PLAN.md) の 3 章）のため、見送った改善を記録する。着手するのは、`epic/rails-8.1-upgrade` を `main` に取り込んだ後。

## 記録のルール

- アップグレードの各 Step で「対応しない（元からの挙動）」とした改善は、ここに足す。足すかどうかは人間が承認する
- 項目には変わらない ID（`IMP-001` から連番）を振る。LOG.md・コミット・PR からは ID で指し、内容を重複させない
- 経緯には確かめた事実と、LOG.md の該当箇所を書く。推測は推測と書く
- 着手したら一覧の「状態」を更新し、節に PR を書き足す。やめたときも理由を書いて残す
- 公開物として扱う（[CLAUDE.md](../CLAUDE.md) の「公開物への記載ルール」）

種別は、セキュリティの設定 / 挙動の変更 / コードの整理 / 性能 の 4 つ。

## 一覧

| ID | 内容 | アプリ | 種別 | 状態 |
|---|---|---|---|---|
| IMP-001 | PKCE を必須にし、S256 だけを受け付ける | OP | セキュリティの設定 | 未着手 |
| IMP-002 | client secret とトークンをハッシュ化して保存する | OP | セキュリティの設定 | 未着手 |
| IMP-003 | 確認用の `puts` を logger に変える | RS・RP | 挙動の変更 | 未着手 |
| IMP-004 | Authorization ヘッダーの `Bearer ` の接頭辞を確かめる | RS | 挙動の変更 | 未着手 |
| IMP-005 | トークン要求の `redirect_uri` からコールバックのクエリを外す | RP | 挙動の変更 | 未着手 |
| IMP-006 | 独自ストラテジーの `site` を OP のベース URL に直す | RP | コードの整理 | 未着手 |
| IMP-007 | introspect 用のトークンを使い回す | RS | 性能 | 未着手 |

## IMP-001: PKCE を必須にし、S256 だけを受け付ける

- 対象: `rails_open_id_provider/config/initializers/doorkeeper.rb`
- 現状: PKCE の列はある（`oauth_access_grants` の `code_challenge`・`code_challenge_method`）が、PKCE を付けない認可要求も受け付ける。方式は plain と S256 の両方を受け付ける（`doorkeeper-5.5.2/lib/doorkeeper/oauth/pre_authorization.rb` の `validate_code_challenge_method` は、`code_challenge` が空なら通し、方式は `plain` か `S256` を通す）
- 改善案: PKCE のない認可コードフローを拒み、方式を S256 だけにする
- 経緯: CLAUDE.md と PLAN.md の 3 章で、設定の改善の例として「PKCE 必須化」を挙げていた。doorkeeper の `force_pkce` は 5.7.1 で入ったが、対象は confidential でないクライアントだけ（doorkeeper の CHANGELOG の #1705）。seeds のアプリは 3 つとも confidential（`rails_open_id_provider/db/seeds.rb`）なので、`force_pkce` だけでは必須にならない。方式を絞る `pkce_code_challenge_methods` は 5.8.0 で入った（#1735）
- 見送った理由: 設定の改善は epic を main に取り込んだ後に行う（PLAN.md の 3 章）
- 確かめ方: RP は PKCE（S256）を送っている（RP の認可要求のテスト）。必須化を確かめる OP のテストは、先に足す
- 記録した Step: 準備（計画）

## IMP-002: client secret とトークンをハッシュ化して保存する

- 対象: `rails_open_id_provider/config/initializers/doorkeeper.rb`
- 現状: `hash_application_secrets`・`hash_token_secrets` はコメントアウトのままで、client secret とトークンは平文で DB に入る
- 改善案: どちらも有効にする。既存の行の扱い（`fallback: :plain` など）、seeds、E2E が secret を読む方法への影響は、着手時に確かめる
- 経緯: CLAUDE.md と PLAN.md の 3 章で、設定の改善の例として「secret のハッシュ化」を挙げていた
- 見送った理由: 設定の改善は epic を main に取り込んだ後に行う（PLAN.md の 3 章）
- 確かめ方: E2E のログインと introspection。ハッシュ化した値が DB に入ることを確かめる OP のテストは、先に足す
- 記録した Step: 準備（計画）

## IMP-003: 確認用の `puts` を logger に変える

- 対象: `rails_resource_server/app/controllers/apples_controller.rb`、`rails_relying_party_of_backend/app/controllers/introspections_controller.rb`、`rails_relying_party_of_backend/lib/omniauth/strategies/my_op.rb`
- 現状: introspect・RS・revoke の応答と、JWKS・nonce の比較を `puts` で標準出力に出している。`rubocop:disable Rails/Output` で囲んでいる
- 改善案: `Rails.logger` に変え、`rubocop:disable` を外す
- 経緯: LOG.md の Step 0-e「Rails/Output」。logger にすると `log/development.log` にも残り（nonce や JWKS を含む）、`rails test` の出力には出なくなるので、出力先が変わる
- 見送った理由: アップグレード中は挙動を変えない
- 確かめ方: 出力の中身はテストで確かめていない。E2E の `resource.spec.ts` は、RP の introspection 画面が RS の応答を画面に出さないことを前提にしている
- 記録した Step: 0-e

## IMP-004: Authorization ヘッダーの `Bearer ` の接頭辞を確かめる

- 対象: `rails_resource_server/app/controllers/apples_controller.rb` の `validate_bearer_token`
- 現状: `gsub('Bearer ', '')` で取り除くだけなので、`Basic` などのヘッダーの値も、そのまま introspect に渡る
- 改善案: `Bearer ` で始まらないときは、introspect を呼ばずに 401 を返す
- 経緯: LOG.md の Step 0-e「コードレビュー」
- 見送った理由: アップグレード中は挙動を変えない
- 確かめ方: RS のテストは、ヘッダーがないとき・`Bearer ` の後が空のときの 401 を確かめている。接頭辞が違うときのテストは、先に足す
- 記録した Step: 0-e

## IMP-005: トークン要求の `redirect_uri` からコールバックのクエリを外す

- 対象: `rails_relying_party_of_backend/lib/omniauth/strategies/my_op.rb`
- 現状: トークン要求の `redirect_uri` は、コールバックの URL に `?code=...&state=...` が付いたもの（omniauth の `callback_url` がクエリを含むため）。認可要求の `redirect_uri` にはクエリがない
- 改善案: ストラテジーで `callback_url` を上書きし、クエリのない URL を送る。RFC 6749 の 4.1.3 は、トークン要求の `redirect_uri` が認可要求と同じであることを求めている
- 経緯: LOG.md の Step 0-a「ログへの出力」。OP のログの Parameters に、認可コードを含む `redirect_uri` がそのまま残る（キー名で判定する `filter_parameters` では伏せられない）。Step 0-f-2 で、この挙動を記録するテストを足した
- 見送った理由: アップグレード中は挙動を変えない
- 確かめ方: RP のテスト「トークン要求の redirect_uri は、認可要求の redirect_uri にコールバックのクエリ（code・state）が付いたもの」を、新しい挙動に合わせて書き直す。E2E のログイン
- 記録した Step: 0-a（テストは 0-f-2）

## IMP-006: 独自ストラテジーの `site` を OP のベース URL に直す

- 対象: `rails_relying_party_of_backend/lib/omniauth/strategies/my_op.rb`
- 現状: `site` が `http://localhost:3780/oauth/authorize`。oauth2 2.x では、`authorize_url: '/oauth/authorize'`・`token_url: '/oauth/token'` を絶対パスで明記して、1.4.7 と同じ URL にしている
- 改善案: `site` を `ENV['OIDC_PROVIDER_HOST']` にし、`authorize_url`・`token_url` の明記を外す（oauth2 2.x の既定値の相対パスで、同じ URL になる）
- 経緯: 最初のコミット（2021-08-14「add OP/RP app」）から同じ値。同じ日のブログ記事（README の「Related Blog」の 1 つ目）では「site で認証リクエストのエンドポイントを指定」としているが、oauth2 の `site` は OP のベース URL。oauth2 1.4.7 は既定値が `/` で始まるので `site` のパスを捨て、動いていた（LOG.md の Step 0-f-2「URL の既定値が相対パスになった経緯」）
- 見送った理由: アップグレード中は挙動を変えない
- 確かめ方: RP の認可要求・トークン要求の URL のテスト、E2E のログイン
- 記録した Step: 0-f-2

## IMP-007: introspect 用のトークンを使い回す

- 対象: `rails_resource_server/app/controllers/apples_controller.rb` の `validate_bearer_token`
- 現状: RS へのリクエストのたびに `OAuth2::Client` を作り、クライアントクレデンシャルで introspect 用のトークンを取り直す。RP の introspection 画面の 1 回の流れで、OP への `/oauth/token` の要求が 3 回あり、OP のアクセストークンが 3 行増える（LOG.md の Step 0-f-2「手動確認」）
- 改善案: 有効期限（10 分）の間はトークンを使い回す。置き場所（プロセス内・Rails のキャッシュ）と、期限切れや revoke のときの取り直しは、着手時に決める
- 経緯: LOG.md の Step 0-f-2「コードレビュー」
- 見送った理由: アップグレード中は挙動を変えない
- 確かめ方: RS のテストは、リクエストごとにトークンを要求することを前提にしている。使い回しと取り直しのテストは、先に足す
- 記録した Step: 0-f-2
