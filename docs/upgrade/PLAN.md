# Ruby / Rails アップグレード計画

この文書は、アップグレード作業の計画と進捗の正本である。判断の経緯や Step ごとの記録は [LOG.md](LOG.md) に書く。作業時のルールはリポジトリ直下の [CLAUDE.md](../../CLAUDE.md) を参照する。

## 1. 目的

| 項目 | 現在 | 目標 |
|---|---|---|
| Ruby | 3.0.1 | 3.4 系（Step 9 で 4.0 も任意で検討） |
| Rails | 6.1.4 | 8.1 系 |

手順は [伊藤さん式 Rails アップグレード](https://qiita.com/jnchito/items/0ee47108972a0e302caf) をベースにし、ruby-jp の [Ruby アップグレードガイド](https://scrapbox.io/ruby-jp/Ruby%E3%82%A2%E3%83%83%E3%83%97%E3%82%B0%E3%83%AC%E3%83%BC%E3%83%89%E3%82%AC%E3%82%A4%E3%83%89) / [Rails アップグレードガイド](https://scrapbox.io/ruby-jp/Rails%E3%82%A2%E3%83%83%E3%83%97%E3%82%B0%E3%83%AC%E3%83%BC%E3%83%89%E3%82%AC%E3%82%A4%E3%83%89) を参照しながら AI（Claude Code）と進める。

## 2. 対象範囲

| 区分 | 内容 |
|---|---|
| 対象 | `rails_open_id_provider`（OP, 3780）、`rails_relying_party_of_backend`（RP, 3781）、`rails_resource_server`（RS, 3782） |
| 対象外 | Next.js 製 RP（`nextjs_*`）。E2E にも含めない |
| 動作保証 | development / test 環境のみ。`production.rb` は `app:update` の雛形に追従するだけ |
| 作業順 | 3 アプリを同じ Step で一緒に上げる。コミットはアプリごとに分け、RS → RP → OP の順に作業する |

## 3. 基本方針

1. 一度に上げるのは 1 つだけ。Ruby・Rails・周辺 gem を同時に上げず、マイナーバージョンも飛ばさない
2. アップグレード中は挙動を変えない。例外は「意図的な仕様変更」として本計画に明記したものだけ
3. 脆弱性が公表されている gem の修正は即時に行う。設定の改善（PKCE 必須化、secret のハッシュ化など）は epic を main に取り込んだ後に別作業で行う
4. `app:update` が提案する新しい構成（Propshaft、Solid Queue/Cache/Cable、Kamal、Thruster など）は採用しない
5. 伊藤さん式の「ステージング確認・本番デプロイ」は、「3 アプリ通しの E2E ＋基準応答の比較＋ PR レビュー」に置き換える

## 4. ブランチと PR

| 項目 | 内容 |
|---|---|
| 固定 | `main`（タグ `rails-6.1`）。作業中は変更しない |
| epic | `epic/rails-8.1-upgrade`（`main` から作成。開始を示す空コミットあり） |
| 作業ブランチ | `upgrade/<step>-<内容>`。epic から切り、PR の向き先は epic |
| PR の単位 | Step 0 はサブステップ（0-a〜0-f）ごと。0-f の gem 更新は 1 PR 内で gem ごとにコミット。Step 1 以降は 1 Step = 1 PR |
| 取り込み | 最後に epic → main をマージコミットで取り込む（squash しない） |
| worktree | 作業用 worktree は epic を元にする |
| main への外部 PR | 入った場合は epic に main を取り込む |

## 5. ロードマップ

| Step | Ruby | Rails | 主な作業 |
|---|---|---|---|
| 準備 | 3.0.1 | 6.1.4 | 本計画・LOG・CLAUDE.md、公開物の安全チェック、直下の Gemfile 削除 |
| 0-a | **3.1.x** | **6.1.7.10** | 起動できる状態に戻す（必要最小限の gem のみ） |
| 0-b | 3.1 | 6.1 | **意図的な仕様変更**: アクセストークンの有効期限を 1 分 → 10 分 |
| 0-c | 3.1 | 6.1 | E2E（Playwright / oxlint / oxfmt）、seeds、基準応答の保存 |
| 0-d | 3.1 | 6.1 | RuboCop・bundler-audit・brakeman・SimpleCov の導入（既存違反は凍結）、minitest |
| 0-e | 3.1 | 6.1 | 既存コードの RuboCop 違反の修正 |
| 0-f | 3.1 | 6.1 | 周辺 gem の更新 |
| 1 | 3.1 | **7.0.x** | `sprockets-rails` 明示、`app:update`、`load_defaults 7.0` |
| 2 | **3.2** | 7.0 | Ruby のみ |
| 3 | 3.2 | **7.1.x** | `app:update`、`autoload_lib_once`（RP の独自ストラテジー対応） |
| 4 | **3.3** | 7.1 | Ruby のみ |
| 5 | 3.3 | **7.2.x** | `Rails.application.secrets` 削除への対応、sqlite3 2.x、annotate → annotaterb |
| 6 | 3.3 | **8.0.x** | puma 6 以上、Solid 系・Kamal 系の生成物は不採用 |
| 7 | 3.3 | **8.1.x** | 最終目標の Rails |
| 8 | **3.4** | 8.1 | 標準ライブラリから外れた gem の明示、chilled string 警告への対応 |
| 9（任意） | 4.0 | 8.1 | 依存 gem が対応済みなら実施 |
| 仕上げ | — | — | CI・Dependabot・README 更新、epic → main |

## 6. 各 Step の詳細

### 準備（このブランチ）

- [x] タグ `rails-6.1`、epic ブランチと開始の空コミット
- [x] 直下の `Gemfile` / `Gemfile.lock` を削除（`rails new` 実行用の残骸で、どこからも使われていない）
- [x] `.gitignore` に `.DS_Store` を追加
- [x] 公開物の安全チェック（`scripts/check-public-safety`、`.githooks/`、`.claude/settings.json`、`.public-safety-allow`）
- [x] `CLAUDE.md`、本計画、`LOG.md`

### Step 0-a: 起動できる状態に戻す

Ruby 3.0 系は OpenSSL 1.1 を必要とし、現在の macOS (arm64) では動かせないため、Ruby 3.1 に上げて起動できる状態に戻す。コードは変えず、バージョンの変更に留める。

- [x] mise で Ruby 3.1 の最新パッチ（3.1.7）を入れ、3 アプリの `.ruby-version` と Gemfile の `ruby` を更新
- [x] 各アプリに `mise.toml` を追加し、mise に `.ruby-version` を読ませる（利用者のグローバル設定に依存させない）
- [x] Rails を 6.1.7.10 に更新
- [x] mail を 2.8 系（2.8.1）に更新（2.7 は Ruby 3.1 で net-smtp を読み込めない）
- [x] `bundle lock --add-platform arm64-darwin`
- [x] Ruby 3.1 / clang 17 / OpenSSL 3 で動かない gem を最小限更新（nokogiri 1.18.10、sqlite3 1.7.3、nio4r 2.5.9、msgpack 1.4.5、RP の jwt 2.5.0、OP の json-jwt 1.14.0。理由は LOG.md）
- [x] `filter_parameter_logging` に `:code` を追加（`id_token`・`access_token`・`refresh_token`・`client_secret` は既存の `:token`・`:secret` の部分一致で対象済み）。OP の「Redirected to」行などに残る認可コードは、ローカル専用のため許容（LOG.md に記録）
- [x] 公開物の安全チェックに、認可コード・トークン・client_secret の値を検出するルールを追加
- [x] 3 アプリの `rails s` / `rails c` が起動することを確認し、ブラウザで一通り手動確認

### Step 0-b: アクセストークンの有効期限を 10 分にする（意図的な仕様変更）

- [x] OP の `access_token_expires_in` を `1.minute` → `10.minutes`
- [x] LOG.md に「意図的な仕様変更」として記録
- 理由: 一般的な長さに合わせる。1 分だと E2E のデバッグ中（Playwright の一時停止など）に期限切れになり、結果が不安定になる
- ID トークンの有効期限（doorkeeper-openid_connect の `expiration`、未設定で gem の既定値）は変更しない

### Step 0-c: E2E と基準応答

- [x] OP の `db/seeds.rb`: Doorkeeper アプリケーション 3 つ（`my_op` 用 RP、introspection 用 RP、RS）を、一目でダミーと分かる固定の client_id / secret で作成。ユーザーはシナリオごとに 1 人（同意画面の有無が実行順で変わらないようにするため）
- [x] RP / RS の E2E 用の環境変数 `.env_e2e`（ひな形ではなく E2E がそのまま読むファイルなので、`.env_e2e_template` から名前を変えた）。ダミーの secret は `.public-safety-allow` で除外（人間が承認）
- [x] OP の署名鍵は、E2E の起動時に `jwtRS256.key` がなければ生成し、あれば手動確認用の鍵を使う（毎回生成するには OP のコードの変更が必要なため、計画から変更）。秘密鍵はコミットしない
- [x] `e2e/` に Playwright を導入。`webServer` で 3 アプリを development 環境のまま起動し、`DATABASE_URL` で E2E 専用の DB（`db/e2e.sqlite3`）を毎回作り直す。手動確認用のサーバーが動いていれば起動に失敗する
- [x] `.gitignore` に `e2e/test-results/`、`e2e/playwright-report/`、`e2e/blob-report/`、`e2e/.auth/` を追加（生成した鍵は OP の `.gitignore` で無視済み）
- [x] oxlint ＋ oxfmt を導入（詳細は「9. Linter / Formatter」）
- [x] シナリオ
  - [x] ログイン: RP → OP でログイン → 同意 → RP に戻りユーザー情報が表示される（RP 側の ID トークン検証も通る）
  - [x] リソース取得: RP の introspection 画面は RS の応答を表示しない（標準出力に出すだけ）ため、E2E から RS を直接呼んで確かめる。E2E 自身が `my_op` 用 RP のクライアントとして取ったトークンで RS が 200 でりんごの情報を返す
  - [x] トークン失効: E2E が revoke した後、RS がそのトークンを拒否する。introspection 用 RP の画面から流した場合も、RP が revoke したトークンを RS が 401 で拒否し、introspect が `active: false` になる
  - [x] ログアウト: RP のセッションが破棄される。OP のセッションは残り、再ログインでは OP のログイン画面を経ない（現在の挙動の記録）
  - [x] 基準応答との比較: discovery、JWKS、トークン応答、ID トークン（ヘッダーとペイロード）、userinfo、introspect（有効・revoke 後）
- [x] 基準応答の比較ルール: 時刻・トークン・nonce・ユーザー ID は伏せる。JWKS と ID トークンのヘッダーは `kid` と `n` を伏せ、`kty`・`alg`・`use`・`e` を比べる。ID トークンは項目と `alg` を比べる。有効期間は `exp - iat` として残す（ID トークン 120、introspect 600）。トークン応答の `expires_in: 600` は伏せずに比べる。基準応答は `e2e/baseline/` にあり、更新は `npx playwright test --update-snapshots`

### Step 0-d: 静的解析・脆弱性チェック・minitest

- [ ] RuboCop（rubocop / rubocop-minitest / rubocop-rails）
  - リポジトリ直下に共通の `.rubocop.yml`、各アプリは `inherit_from: ../.rubocop.yml`。gem は各アプリの development / test グループ
  - `config/`、`bin/`、`db/` は対象外（`app:update` で上書きされる雛形のため）
  - 既存違反は `rubocop --auto-gen-config` で `.rubocop_todo.yml` に凍結
  - バージョンを固定し、`NewCops: disable`
- [ ] bundler-audit と brakeman。既存の警告は brakeman の除外ファイルに凍結し、新しい警告がないことを完了条件にする
  - bundler-audit では 0-a で残した advisory（nokogiri 1.18 系の 1.19 でしか直らないもの、json-jwt 1.14.0 の CVE-2023-51774）が出る。解消予定の Step（Step 2 / 0-f）を理由に添えて無視リストに入れる
- [ ] SimpleCov（`coverage/` は gitignore 対象）
- [ ] WebMock
- [ ] テスト（CLAUDE.md「テスト」の方針に従う）
  - OP: discovery、JWKS、Devise のログイン、認可コード → トークン → ID トークンの検証、userinfo、introspect（有効・期限切れ・失効済み・他クライアントのトークン）、revoke
    - 期限切れは境目の 2 本にし、0-b で決めた 10 分をテストに残す。「発行から 10 分ちょうどは `active: true`」「10 分を 1 秒過ぎると `active: false`」（doorkeeper 5.5.2 の判定は `現在時刻 > created_at + expires_in`）
  - RP: 独自ストラテジーの ID トークン検証（テスト内で生成した RSA 鍵 ＋ JWKS を WebMock で差し替え）、ログイン後の画面遷移、introspection 画面（OP・RS の応答を WebMock で差し替え）
  - RS: `apples/show` を有効・無効なトークンで呼んだとき（introspect の応答を WebMock で差し替え）
- [ ] OP の期限切れのテストを追加したら、`rails_relying_party_of_backend/app/controllers/introspections_controller.rb` のコメントアウトした期限切れの確認（`sleep 70`）を同じ PR で削除する。手動確認の名残で、期限切れの判定は OP の minitest、`active: false` の拒否は RS の minitest、3 アプリの通しは E2E の revoke で置き換わる

### Step 0-e: 既存コードの RuboCop 違反の修正

- [ ] SimpleCov でテストが通っていない箇所を確認。そこを直す場合は、先にテストを足すか Layout 系の修正だけにする
- [ ] 安全な自動修正（`-a`）はルールの分類ごとにまとめて適用
- [ ] 安全でない自動修正（`-A`）は 1 ルールずつ、変更内容を確認しながら適用
- [ ] ルール（または分類）ごとにコミット。見た目だけのコミットは `.git-blame-ignore-revs` に登録
- [ ] 完了条件: `.rubocop_todo.yml` が空になり削除できること
- 対象は `app/`、`lib/`、`test/`。`config/`、`bin/`、`db/` は対象外のまま

### Step 0-f: 周辺 gem の更新

「7. 周辺 gem の更新時期」に従う。メジャー更新は 1 gem ずつ、CHANGELOG を読んで対応し、E2E を流してからコミットする。

### Step 1〜9

「8. 各 Step 共通の手順」に従う。Step 固有の作業はロードマップの表のとおり。補足:

- **Step 1（Rails 7.0）**: `sprockets-rails` を Gemfile に明示（rails gem の依存から外れるため）。着手前に `bin/rails zeitwerk:check` を確認
- **Step 2（Ruby 3.2）**: nokogiri を 1.19 系の最新に上げ、1.18 系に残る advisory（GHSA-c4rq-3m3g-8wgx ほか）を解消する。1.19 系は Ruby 3.2 以上が必要なため 0-a では上げられなかった
- **Step 3（Rails 7.1）**: RP の独自ストラテジーを Zeitwerk に載せる（案 B）
  - `rails_relying_party_of_backend/config/application.rb` に以下を追加し、`app:update` が提案する `config.autoload_lib` は採用しない
    ```ruby
    config.autoload_lib_once(ignore: %w[assets tasks])
    Rails.autoloaders.once.inflector.inflect("omniauth" => "OmniAuth")
    ```
  - `config/initializers/omniauth.rb` の `require 'omniauth/strategies/my_op'` を削除
  - 理由: `lib/omniauth` は既定の推測で `Omniauth` になり、実際の `OmniAuth` と食い違う。また OmniAuth のミドルウェアは起動時に 1 回だけ作られるため、リロード対象にはできない。`autoload_lib_once` なら initializer からも使え、リロードもしない
  - 完了条件: `bin/rails zeitwerk:check`、RP の minitest、E2E のログインシナリオ
  - うまくいかない場合は案 A（`autoload_lib(ignore: %w[assets tasks omniauth])` ＋ `require`）に切り替え、LOG.md に理由を残す
- **Step 5（Rails 7.2）**: Rails 7.2 にした後で sqlite3 を 2.x へ（Rails 8.0 は 2.1 以上が必須のため前倒し）。annotate を annotaterb に置き換え（annotate は Rails 8 未対応）
  - Rails 7.2 から「Redirected to」行のクエリにも `filter_parameters` が適用される。OP のログでリダイレクト先の `code=` が `[FILTERED]` になることを確認する（0-a では Rails 6.1 の制約で残ることを許容した）
- **Step 6（Rails 8.0）**: `app:update` が生成する Solid 系・Kamal 系・Thruster 関連のファイルは採用しない

### 仕上げ

- [ ] GitHub Actions（minitest、E2E、RuboCop、oxlint、bundler-audit、brakeman、安全チェック）
- [ ] Dependabot（bundler、npm、GitHub Actions をまとまった単位で更新）。CI ができてから有効にする
- [ ] README の「Tested Environment」を更新。アップグレード前のコードはタグ `rails-6.1` にあること、Next.js 製 RP は新しい OP で確認していないことを書く
- [ ] README の「How to use」に Ruby の入れ方を書く。各アプリの `mise.toml` は初回に `mise trust` が必要なこと、Ruby のバージョンは `.ruby-version` と Gemfile の `ruby` の両方にあること（mise は Gemfile を優先して読む）
- [ ] 各バージョンのサポート終了時期の確認方法を本計画に追記（次回アップグレードへの備え）
- [ ] epic → main をマージコミットで取り込む

## 7. 周辺 gem の更新時期

各 Step の最初に `bundle outdated` を確認し、次の順で振り分ける。

1. 今の Rails のまま上げられる gem → Rails を上げる前に上げる
2. 新しい Rails を必要とする gem → Rails と同時か直後に上げる
3. 下の表で時期を決めた gem → その Step で上げる

| gem | 現在 | 時期 | 注意点 |
|---|---|---|---|
| mail | 2.7.1 | 0-a で 2.8.1（済） | Ruby 3.1 で起動するために必要。`--conservative` でも 2.9 系になるので一時的に固定して 2.8.1 にした |
| nokogiri | 1.12.3 | 0-a で 1.18.10（済）→ Step 2 で 1.19 系最新 | 1.12 は Ruby 3.1 のネイティブ版がない。1.19 系は Ruby 3.2 以上が必要 |
| jwt（RP、oauth2 経由の間接依存） | 2.2.3 | 0-a で 2.5.0（済）→ 0-f で 2.x 最新にして RP の Gemfile に明記 | RP の `lib/omniauth/strategies/my_op.rb` が直接使うのに Gemfile にない。OpenSSL 3 への対応は 2.5.0 から。RS は直接使わないので oauth2 の更新に任せる |
| json-jwt（OP、doorkeeper-openid_connect 経由） | 1.13.0 | 0-a で 1.14.0（済）→ 0-f で doorkeeper-openid_connect と一緒に外す | OpenSSL 3 への対応は 1.14.0 から。CVE-2023-51774 は未修正だが、OP は署名だけで decode しないため影響なし。0-f の後も残るなら 1.16.6 以上にする |
| nio4r / msgpack | 2.5.8 / 1.4.2 | 0-a で 2.5.9 / 1.4.5（済） | clang 17 で C 拡張がビルドできないため、同じマイナー内のパッチ版に更新 |
| thor（railties 経由） | 1.1.0 | 0-f | Ruby 3.1 で `DidYouMean::SPELL_CHECKERS.merge!` の非推奨警告が出る（起動には影響なし） |
| oauth2 / omniauth-oauth2 | 1.4.7 / 1.7.1 | 0-f（同時） | omniauth-oauth2 1.8 は oauth2 2.x が必要。RS が `OAuth2::Client` を直接使い、RP が独自ストラテジーを持つので最も壊れやすい。トークン取得時のクライアント認証方式の既定値の変化を確認 |
| faraday | 1.7.0 | 0-f（oauth2 の後） | RP と RS が直接呼んでいる。順番は依存関係を見て決める |
| doorkeeper / doorkeeper-openid_connect | 5.5.2 / 1.8.0 | 0-f（この順） | openid_connect の新しい版は JWT のライブラリが json-jwt から jwt に変わる。ID トークンの署名と JWKS を RP の検証も含めて確認。新しいマイグレーションが必要か確認 |
| devise | 4.8.0 | 0-f | Rails 8.1 対応は Step 7 の最初に再確認 |
| dotenv-rails | 2.7.6 | 0-f | 3.x で読み込み方が変わる |
| puma | 5.4 | 0-f で 6 系 | 7 系は後の Step で判断 |
| spring | 2.1.1 | 0-f で削除 | Rails 7 から標準で入らない |
| byebug / web-console / listen / rack-mini-profiler | — | 0-f | 開発・テスト用を先に上げる。listen 3.6.0 では `EventedFileUpdateChecker` の finalizer で `ThreadError` の警告が出る（LOG.md の Step 0-b）。更新後に出なくなるか確認 |
| sprockets-rails | 3.2.2（間接） | Step 1 で明示 | Rails 7.0 から rails gem の依存から外れる |
| sqlite3 | 1.4.2 | 0-a で 1.7.3（済。clang 17 で 1.4 系がビルドできないため 0-f から前倒し）→ Step 5 で 2.x | Rails 7.1 までは 1.x のみ、8.0 は 2.1 以上必須 |
| annotate | — | Step 5 で annotaterb に置換 | Rails 8 未対応 |
| activerecord-session_store | 2.0.0 | 各 Step の最初 | Rails を上げた後に `bundle update` が通らなければ Rails と同時に上げる |
| base64 / bigdecimal / mutex_m など | — | Step 4 で警告が出たら明示 → Step 8 で必須 | Ruby 3.4 で標準ライブラリから外れる |
| rubocop 系 / oxlint 系 | — | 各 Step の最初 | バージョン固定。更新は単独コミット |

annotate の Rails 8 対応状況と、oauth2 1.4 系の faraday 2 対応範囲は記憶ベース。Step 0-f の調査で gemspec を確認して確定させる。

## 8. 各 Step 共通の手順

1. **調査（Plan モード）**: Rails 公式アップグレードガイドの該当箇所、ruby-jp の各バージョンのナレッジページ、railsdiff.org、`bundle outdated`、メジャー更新する gem の CHANGELOG を確認し、Step の作業計画を出す。**人間の承認を待つ**
2. **周辺 gem → Rails のパッチ版を最新に → 非推奨警告の解消**: テスト環境で `config.active_support.deprecation = :raise`
3. **Rails のマイナーを上げる**
   - Gemfile を変えて `bundle update rails`
   - `bin/rails app:update` を全上書きで実行し、`git diff` で差分を振り分ける（独自設定は戻す、新しい構成は採用しない）。**差分は人間が確認する**
   - `new_framework_defaults_X_Y.rb` を 1 つずつ有効化してテスト → 全部有効になったら `load_defaults` を上げてファイルを削除
   - RuboCop の `TargetRailsVersion` を上げ、新しい指摘は別コミットで直す
4. **Ruby を上げる場合**: Ruby を上げてコミット → `TargetRubyVersion` を上げて新しい指摘を直す（別コミット）
5. **確認**: 「10. 完了条件」
6. **記録**: LOG.md を更新 → `/code-review` → PR（向き先は epic）

## 9. Linter / Formatter

| 対象 | ツール | 備考 |
|---|---|---|
| Ruby | rubocop ＋ rubocop-minitest ＋ rubocop-rails | 主目的はテストの書き方の規律（rubocop-minitest）。rubocop-rails はアップグレードの補助 |
| E2E（TypeScript） | oxlint ＋ oxfmt | 下記 |

oxlint / oxfmt の導入条件:

1. `oxlint`、`oxlint-tsgolint`、`oxfmt`、`eslint-plugin-playwright` のバージョンを `^` なしで固定。更新は単独コミット
2. `await` の付け忘れは型情報を使うモード（`typescript/no-floating-promises`）で検出する
3. Playwright 用ルールは JS プラグイン機能（アルファ版）で `eslint-plugin-playwright` を読み込み、`e2e/**` だけに適用する
4. oxfmt の `printWidth` を明示的に設定する（既定値 100 は Prettier の 80 と異なる）
5. 導入時に、わざと違反を入れたファイルで指摘が出ることを確認してから削除する（`await` の付け忘れ、`test.only`、`page.waitForTimeout`、Web ファーストでないアサーション）
6. JS プラグイン機能で問題が出たら Playwright 用ルールだけ ESLint に戻す。oxfmt で問題が出たら Prettier に切り替える

## 10. 完了条件（各 Step 共通）

- [ ] 3 アプリで `bin/rails c` と `bin/rails s` が起動する
- [ ] minitest が全件通る（非推奨警告は `:raise`）
- [ ] E2E が全件通り、基準応答との比較に差分がない
- [ ] RuboCop で新しい違反がない
- [ ] bundler-audit と brakeman で新しい警告がない
- [ ] `bin/rails zeitwerk:check` が通る（Step 1 以降）
- [ ] `db:drop db:setup` で空から作り直して E2E が通る（E2E の起動時に E2E 用の DB で毎回行われる。RS は `schema.rb` がないので `db:drop db:create`）
- [ ] 公開物の安全チェック（`scripts/check-public-safety --staged`）が通る
- [ ] LOG.md と本計画のチェックリストを更新した

## 11. 人間が判断するところ

- 各 Step の作業計画の承認
- `app:update` の差分の確認
- 新しい構成（Propshaft など）を採用するかどうか（今回は採用しない方針）
- gem が新しい Rails に未対応のときの方針の選択
- `.public-safety-allow` への追記
- PR のマージ

## 12. 既知のリスク

| リスク | 対策 |
|---|---|
| oauth2 2.x / faraday 2 / doorkeeper 系の更新で、アプリ間の通信が壊れる | 1 gem ずつ上げ、毎回 E2E を流す |
| doorkeeper-openid_connect の JWT ライブラリ変更で ID トークンや JWKS が変わる（Next.js 製 RP にも影響しうる） | 基準応答の比較で ID トークンの項目と `alg`、JWKS の構造を比べる |
| Rails 7.0 の `load_defaults` で Cookie の鍵生成方式が SHA256 に変わり、既存セッションが無効になる | サンプルなので許容。E2E は毎回新しいセッションで流す |
| Rails 7.1 で RP の独自ストラテジーが Zeitwerk の読み込みに失敗する | Step 3 の案 B で対応。失敗したら案 A |
| gem 更新でマイグレーションの追加が必要になる | gem 更新の手順で確認し、`db:drop db:setup` の完了条件で検出する |
| 時間に依存するテストが不安定になる | minitest は `travel_to`、E2E は期限切れを待たずに revoke で確認 |

## 13. スキル化の計画

Step 1 を一度手作業で通した後に、`/rails-upgrade` を入口とする 1 つのスキルを作る（作業名を引数で渡し、中身は参照用の別ファイルに分ける）。

| # | 作業 | 内容 |
|---|---|---|
| 1 | research | 調査と Step の計画作り（承認待ちで止まる） |
| 2 | gems | 周辺 gem の振り分けと更新 |
| 3 | patch | Rails のパッチ版の最新化と非推奨警告の解消 |
| 4 | rails-minor | Rails のマイナーバージョンアップ（`app:update` の振り分け、`load_defaults`、`TargetRailsVersion`） |
| 5 | ruby | Ruby のバージョンアップ（`TargetRubyVersion` の更新と指摘の修正を含む） |
| 6 | verify | 完了条件のチェック |
| 7 | record | LOG.md の記録（公開物の記載ルールに沿った置き換え → 安全チェック）、`/code-review`、PR 作成（`--base` 必須） |
| 8 | resume | PLAN.md と LOG.md から次の作業を判断 |

スキルには手順だけを書き、バージョン固有の知識は LOG.md に残す。

## 14. 未決事項

- [ ] 最終的に Ruby 4.0 まで上げるか（Step 8 完了時に判断）
- [x] `rails_open_id_provider/jwtRS256.key.example` の扱い（Step 0-c で判断）: 鍵の中身のないプレースホルダーで、どこからも参照されていなかったため、`.pub.example` と一緒に削除した

## 15. 決定済みの事項

- ローカルブランチ `feature/rails_migration_plan`（過去の計画とスキルの試作）は参照せず、知見も取り込まない。過去の前提に引きずられるのを避けるため。今回の作業では触れない
