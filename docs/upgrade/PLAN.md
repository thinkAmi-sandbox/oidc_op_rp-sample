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
5. 伊藤さん式の「ステージング確認・本番デプロイ」は、「3 アプリ通しの E2E ＋ OP の応答のスナップショットとの比較＋ PR レビュー」に置き換える

## 4. ブランチと PR

| 項目 | 内容 |
|---|---|
| 固定 | `main`（タグ `rails-6.1`）。作業中は変更しない |
| epic | `epic/rails-8.1-upgrade`（`main` から作成。開始を示す空コミットあり） |
| 作業ブランチ | `upgrade/<step>-<内容>`。epic から切り、PR の向き先は epic |
| PR の単位 | Step 0 はサブステップ（0-a〜0-f。0-d は 0-d-1・0-d-2・0-d-3、0-f は 0-f-1・0-f-2・0-f-3 に分ける）ごと。0-f の gem 更新は、各 PR の中で gem ごとにコミット。Step 1 以降は 1 Step = 1 PR |
| 取り込み | 最後に epic → main をマージコミットで取り込む（squash しない） |
| worktree | 作業用 worktree は epic を元にする |
| main への外部 PR | 入った場合は epic に main を取り込む |

## 5. ロードマップ

| Step | Ruby | Rails | 主な作業 |
|---|---|---|---|
| 準備 | 3.0.1 | 6.1.4 | 本計画・LOG・CLAUDE.md、公開物の安全チェック、直下の Gemfile 削除 |
| 0-a | **3.1.x** | **6.1.7.10** | 起動できる状態に戻す（必要最小限の gem のみ） |
| 0-b | 3.1 | 6.1 | **意図的な仕様変更**: アクセストークンの有効期限を 1 分 → 10 分 |
| 0-c | 3.1 | 6.1 | E2E（Playwright / oxlint / oxfmt）、seeds、OP の応答のスナップショットの保存 |
| 0-d | 3.1 | 6.1 | RuboCop・bundler-audit・brakeman・SimpleCov の導入（既存違反は凍結）、minitest、脆弱性のある gem の更新（0-d-3） |
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

### Step 0-c: E2E と OP の応答のスナップショット

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
  - [x] スナップショットとの比較: discovery、JWKS、トークン応答、ID トークン（ヘッダーとペイロード）、userinfo、introspect（有効・revoke 後）
- [x] スナップショットの比較ルール: 時刻・トークン・nonce・ユーザー ID は伏せる（JSON の型は `<TIMESTAMP:number>` のように残す）。JWKS と ID トークンのヘッダーは `kid` と `n` を伏せ、`kty`・`alg`・`use`・`e` を比べる。ID トークンは項目と `alg` を比べる。有効期間は `exp - iat` として残す（ID トークン 120、introspect 600）。トークン応答の `expires_in: 600` は伏せずに比べる。スナップショットは `e2e/baseline/` にあり、更新は `npx playwright test --update-snapshots`

### Step 0-d: 静的解析・脆弱性チェック・minitest

PR を 0-d-1（静的解析と脆弱性チェック）と 0-d-2（minitest）に分ける（理由は LOG.md の Step 0-d-1）。

#### 0-d-1: 静的解析と脆弱性チェック

- [x] RuboCop（rubocop / rubocop-minitest / rubocop-rails）
  - リポジトリ直下に共通の `.rubocop.yml`、各アプリは `inherit_from: [../.rubocop.yml, .rubocop_todo.yml]`（この順）。gem は各アプリの development / test グループ
  - `config/`、`bin/`、`db/` は対象外（`app:update` で上書きされる雛形のため）。同じ理由で、0-e で `config.ru` も対象外にした
  - 既存違反は `rubocop --auto-gen-config --no-exclude-limit` で `.rubocop_todo.yml` に凍結
  - バージョンを固定し、`NewCops: disable`
- [x] bundler-audit と brakeman。既存の advisory と警告は無視リスト（各アプリの `.bundler-audit.yml`、`config/brakeman.ignore`）に凍結し、新しいものがないことを完了条件にする
  - bundler-audit の既存の advisory は 1 アプリ 93〜94 件（20〜21 gem）で、当初の想定（nokogiri と json-jwt）より大幅に多い。gem ごとに解消する時期を書いて無視リストに入れた（内訳は LOG.md の Step 0-d-1）
  - Rails 6.1・Ruby 3.1 のまま修正版に上げられる gem（rack、puma、loofah など）は、0-d-3 で上げる（14 章で決定）
- [x] RS の既存のテスト（トークンなしで 200 を期待して落ちていた）を、現在の挙動（401）に直す

#### 0-d-2: minitest

- [x] SimpleCov（`coverage/` は gitignore 対象）
- [x] WebMock（外部への HTTP 通信はすべて遮断）
- [x] テスト（CLAUDE.md「テスト」の方針に従う。件数と記録した挙動は LOG.md の Step 0-d-2）
  - RP / RS のテスト用の環境変数は、ダミーの値の `.env.test` をコミットして渡す（dotenv は `.env` より先に読むので、手元の `.env` に左右されない）。secret の行は `.public-safety-allow` で除外した（人間が承認）
  - テストは `DISABLE_SPRING=1 bin/rails test` で流す（spring 経由ではアプリが SimpleCov より先に読み込まれ、起動時に読むファイルのカバレッジが取れない）。0-f-1 で spring を削除した後は `bin/rails test` だけでよい
  - OP: discovery、JWKS、Devise のログイン、認可コード → トークン → ID トークンの検証、userinfo、introspect（有効・期限切れ・失効済み・他クライアントの資格情報）、revoke
    - 期限切れは境目の 2 本にし、0-b で決めた 10 分をテストに残した。「発行から 10 分ちょうどは `active: true`」「10 分を 1 秒過ぎると `active: false`」（doorkeeper 5.5.2 の判定は `現在時刻 > created_at + expires_in`）
  - RP: 独自ストラテジーの ID トークン検証（テスト内で生成した RSA 鍵 ＋ JWKS を WebMock で差し替え）、ログイン後の画面遷移、introspection 画面（OP・RS の応答を WebMock で差し替え）。検証に失敗したときは、例外ではなく `/auth/failure` へのリダイレクトになる（omniauth 2.0.4 の挙動。LOG.md）
  - RS: `apples/show` を有効・無効なトークンで呼んだとき（introspect の応答を WebMock で差し替え）
- [x] テスト環境の `config.active_support.deprecation = :raise`（10 章の完了条件）
- [x] `rails_relying_party_of_backend/app/controllers/introspections_controller.rb` のコメントアウトした期限切れの確認（`sleep 70`）を削除した。期限切れの判定は OP の minitest、`active: false` の拒否は RS の minitest、3 アプリの通しは E2E の revoke で置き換わった

#### 0-d-3: 脆弱性のある gem の更新

0-d-1 で無視リストに凍結した advisory のうち、Rails 6.1・Ruby 3.1 のまま修正版に上げられる gem を上げる（人間の判断。LOG.md の Step 0-d-1）。CLAUDE.md の「脆弱性が公表されている gem の修正だけは即時に行ってよい」にあたる。0-d-2 の minitest ができてから行い、0-e より先に行う。

- [x] 対象: rack、puma、loofah・crass・rails-html-sanitizer、websocket-driver、globalid、mail、msgpack、faraday 1.x（RP・RS）、bcrypt（OP）。上げた版は LOG.md の Step 0-d-3
- [x] 1 gem ずつ（loofah・crass・rails-html-sanitizer は依存関係のため 1 組で）上げ、そのたびに minitest と E2E を流してからコミットする。コミットはアプリごとに分ける
- [x] 上げた gem の advisory を `.bundler-audit.yml` から消し、bundler-audit で報告されないことを確かめる
- 着手時の調査で決めたこと（人間が承認。理由は LOG.md の Step 0-d-3）
  - 上げる先: 修正版を含むマイナー系列の最新（マイナーはまたがない）。globalid だけは `--conservative` で 1.4.0 になるので、一時固定で 1.0.1 にした
  - default gem: logger は 1.5.0、base64 は 0.1.1（Ruby 3.1.7 の default gem と同じ版）に一時固定し、アプリが読む版を変えない
  - puma 5.6.9 で新しく対象に入る 2 件（PROXY protocol v1）は無視リストに入れ、7.2.1 以上に上げるときに解消する（7 章）
  - PR は 1 つ

### Step 0-e: 既存コードの RuboCop 違反の修正

- [x] SimpleCov でテストが通っていない箇所を確認。そこを直す場合は、先にテストを足すか Layout 系の修正だけにする
  - 通っていなかったのは生成物の基底クラス（channel・connection・job・mailer など）だけ。3 アプリに「アプリのコードをすべて読み込める」テスト（`Rails.application.eager_load!`）を足し、行カバレッジは 3 アプリとも 100% になった
- [x] 安全な自動修正（`-a`）はルールの分類ごとにまとめて適用
- [x] 安全でない自動修正（`-A`）は 1 ルールずつ、変更内容を確認しながら適用
- [x] ルール（または分類）ごとにコミット。見た目だけのコミットは `.git-blame-ignore-revs` に登録
- [x] 完了条件: `.rubocop_todo.yml` が空になり削除できること
- 対象は `app/`、`lib/`、`test/`。`config/`、`bin/`、`db/` は対象外のまま。todo にあった `Gemfile`・`Rakefile` も直し、`config.ru` は `app:update` で上書きされるので対象外にした
- 着手時の調査で決めたこと（人間が承認。理由は LOG.md の Step 0-e）
  - Rails/Output: `puts` のまま残し、`rubocop:disable` で囲む。logger にすると出力先が変わるため。logger への変更は epic を main に取り込んだ後の改善として扱う
  - Metrics（RS・RP のメソッド、OP の annotate の rake）: メソッドを分けず、`rubocop:disable` を付ける。既定の上限は新しいコードに効いたまま
  - Rails/RakeEnvironment（OP の annotate の rake）: `:environment` は足さず、`rubocop:disable` を付ける。Step 5 で見直す
  - Style/Documentation: 直下の `.rubocop.yml` で無効にする
  - Rails/HttpStatus・Style/FrozenStringLiteralComment・Style/ClassAndModuleChildren: 自動修正で直す
  - Bundler/OrderedGems・Bundler/DuplicatedGroup: 並べ替え、annotate を 1 つ目の `group :development` に移す。lock と依存の一覧が変わらないことを確かめた
  - PR は 1 つ

### Step 0-f: 周辺 gem の更新

「7. 周辺 gem の更新時期」に従う。メジャー更新は 1 gem ずつ、CHANGELOG を読んで対応し、E2E を流してからコミットする。

- 着手時の調査で決めたこと（人間が承認。理由は LOG.md の Step 0-f-1）
  - PR を 3 つに分ける。0-f-1（spring の削除、開発・テスト用の gem など）、0-f-2（RS・RP の jwt・oauth2・omniauth-oauth2・omniauth・faraday）、0-f-3（OP の doorkeeper・doorkeeper-openid_connect）。それぞれが epic に入ってから次を始める
  - 上げる先は、Ruby 3.1・Rails 6.1 で使える最新の版。ただし doorkeeper は 5.7.1、doorkeeper-openid_connect は 1.8.9 で止める（Rails 6 を外していない最後の組み合わせ）。上げない gem と、上げる時期は 7 章
  - 間接依存の gem は、上の更新で必要になったものしか動かさない（`--conservative`）
  - gem の既定値が変わって挙動が変わるもの（oauth2 2.x の `auth_scheme` など）は、設定で元の挙動に固定する。テストや E2E で守られていない挙動は、gem を上げる前にテストを足す
  - 例外として、doorkeeper-openid_connect が discovery に足す `code_challenge_methods_supported` は設定で消せないので、「意図的な仕様変更」として受け入れる（0-f-3）
  - spring を消すときは、`bin/spring`・`config/spring.rb` も消し、`bin/rails`・`bin/rake` を Rails 7.0 の雛形の形にする

#### 0-f-1: spring の削除と、開発・テスト用などの gem

- [x] spring を削除（`bin/` と `config/spring.rb`、E2E の起動スクリプトと `.claude/launch.json` の `DISABLE_SPRING` も）
- [x] byebug 12.0.0、web-console 4.2.1、listen 3.10.1、rack-mini-profiler 4.0.1、thor 1.5.0、bootsnap 1.26.0、jbuilder 2.13.0、puma 6.6.1、dotenv-rails 3.2.0、activerecord-session_store 2.1.0、devise 4.9.4（上げた版と確かめたことは LOG.md の Step 0-f-1）
- [x] thor の `DidYouMean::SPELL_CHECKERS.merge!` の警告が消えることを確かめた
- [x] listen の finalizer の警告は、3.10.1 でも出る。Step 1 の `app:update` で判断する（7 章）

#### 0-f-2: oauth2 系（RS・RP）

予定（決めた経緯は LOG.md の Step 0-f-1「作業計画で決めたこと」）:

- [ ] RS: jwt 2.10.3（oauth2 1.4.7 のうちに上げる）→ oauth2 2.0.25（`OAuth2::Client.new` に `auth_scheme: :request_body` を足す）→ faraday 2.14.4（faraday-net_http は 3.0.2 に一時固定）
- [ ] RP: テストを足す（トークン要求の本文に client_id・secret があり Authorization ヘッダーがないこと、`redirect_uri`）→ jwt を Gemfile に明記して 2.10.3 → oauth2 2.0.25 と omniauth-oauth2 1.9.0（`client_options` に `auth_scheme: :request_body`・`authorize_url`・`token_url` を明記）→ omniauth 2.1.4 → faraday を Gemfile に明記して 2.14.4
- [ ] 上げた gem の advisory（oauth2・jwt）を `.bundler-audit.yml` から消す

0-f-1 の作業計画のときに調べたこと（rubygems の API・gemspec・CHANGELOG・タグ間のソース。着手時に版と事実を確かめ直す）:

| gem | 分かったこと | テスト・E2E で守られているか |
|---|---|---|
| oauth2 2.0.25 | 依存は `faraday >= 0.17.3, < 4`・`jwt >= 1.0, < 4`・`logger ~> 1.2`・`rack < 4` ほか。新しく入るのは version_gem・snaky_hash・auth-sanitizer・anonymous_loader（RS は hashie 5.1.0 も）。`--conservative` を付けないと logger・jwt・faraday も動く | — |
| | 2.0.0 で `auth_scheme` の既定値が `:basic_auth` に、`authorize_url`・`token_url` の既定値が相対パス（`oauth/authorize`・`oauth/token`）になった。RP は `site` がパス付きなので、URL が `.../oauth/authorize/oauth/token` になる | RS の認証方式はテストあり。RP の認証方式はなし（先に足す）。RP の URL は認可要求・ログインのテストと E2E |
| | 応答の parse が snaky_hash になる（`raw_info` などのクラスが Hash から変わる。`id_token`・`sub`・`email` のキーは変わらない）。extra tokens の警告は 2.0.10 から既定で出ない。`raise_errors`・`token_method`・`get_token` の引数は同じ。`redirect_uri` はクエリが付いたまま送られる | クラスの変化はなし。`redirect_uri` はなし（先に足す） |
| omniauth-oauth2 1.9.0 | `oauth2 >= 2.0.2, < 3`、`omniauth ~> 2.0`。PKCE・`callback_url`・`client_options` の渡し方は 1.7.1 と同じ。1.8 で state の確認が error パラメーターの確認より先になり、1.9 で state を `secure_compare` で比べる。state のない error のコールバックは `csrf_detected` に、セッションに state がないと NoMethodError になる | エラーの経路はテストなし（LOG に記録する） |
| omniauth 2.1.4 | `callback_url` は 2.0.4 と同じ（クエリ付き）。`rack >= 2.2.3` と logger が依存に入る。rack-protection は `--conservative` なら 2.1.0 のまま（3.2.0 まで上げられる。4.x は rack 3 が必要） | — |
| jwt 2.10.3 | 依存は `base64 >= 0`（0.1.1 で足りる）。`my_op.rb` が使う `JWT.decode`（鍵を探すブロック付き）・`JWT::JWK::RSA.import` と、テストが使う `JWT::JWK::RSA.new(..., kid:)` で非推奨の警告は出ない。テストが期待する例外クラスも変わらない | RP の ID トークンの検証のテスト |
| faraday 2.14.4 | Ruby 3.0 以上。依存は `faraday-net_http >= 2.0, < 3.5`・json・logger。アプリの `Faraday.get` / `Faraday.post` の呼び方は変わらず、既定のミドルウェア（url_encoded と net_http）も同じ。User-Agent の文字列だけが変わる。faraday-multipart・faraday-retry・ruby2_keywords は lock から外れる見込み | RS・RP のテスト（WebMock）と E2E |
| faraday-net_http | 3.4.x は `net-http ~> 0.5`、3.1〜3.3 は `net-http >= 0` に依存し、default gem の net-http 0.3.0.1（net-http の新しい版は uri 0.12.4 も）を置き換える。3.0.2 は依存がない | — |

ダウンロード（0-f-1 の作業計画で承認済み。版が変わったら示し直す）: jwt 2.10.3（54 KB）、oauth2 2.0.25（78 KB）、omniauth-oauth2 1.9.0（12 KB）、omniauth 2.1.4（23 KB）、snaky_hash 2.0.7（40 KB）、version_gem 1.1.15（29 KB）、auth-sanitizer 0.2.3（44 KB）、anonymous_loader 0.1.3（35 KB）、hashie 5.1.0（54 KB、RS）、faraday 2.14.4（75 KB）、faraday-net_http 3.0.2（8 KB）

#### 0-f-3: doorkeeper 系（OP）

予定:

- [ ] テストを足す（ID トークンの `kid` が JWKS の `kid` と同じこと、同意画面を省く条件 2 本）
- [ ] doorkeeper 5.5.4 → doorkeeper-openid_connect 1.8.9（json-jwt が外れる。OP のテストの `JSON::JWT` を ruby-jwt に書き直す）→ doorkeeper 5.6.9 → 5.7.1。doorkeeper-openid_connect 1.8.0 は doorkeeper 5.6 未満を要求するので、交互に上げる
- [ ] **意図的な仕様変更**: discovery に `code_challenge_methods_supported: ["plain", "S256"]` が増える（doorkeeper-openid_connect 1.8.3 以上は PKCE の列があると出し、設定では消せない）。`e2e/baseline/discovery.json` を更新し、LOG.md に記録する
- [ ] 上書きしているビューを、上げた版の雛形と比べる
- [ ] 上げた gem の advisory（doorkeeper・json-jwt）を `.bundler-audit.yml` から消す

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
  - OP の `lib/tasks/auto_annotate_models.rake` の `rubocop:disable`（Metrics/BlockLength・Rails/RakeEnvironment。0-e で付けた）を、annotaterb が生成するファイルに合わせて見直す
  - Rails 7.2 から「Redirected to」行のクエリにも `filter_parameters` が適用される。OP のログでリダイレクト先の `code=` が `[FILTERED]` になることを確認する（0-a では Rails 6.1 の制約で残ることを許容した）
- **Step 6（Rails 8.0）**: `app:update` が生成する Solid 系・Kamal 系・Thruster 関連のファイルは採用しない

### 仕上げ

- [ ] GitHub Actions（minitest、E2E、RuboCop、oxlint、bundler-audit、brakeman、安全チェック）
- [ ] CI で OP の署名鍵 `rails_open_id_provider/jwtRS256.key` がないときの minitest の扱いを決める（OP は起動時に鍵を読む。0-d-2 では手動確認用の鍵を使った）
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
| mail | 2.7.1 | 0-a で 2.8.1（済）→ 0-d-3 で 2.9.1（済） | 0-a は Ruby 3.1 で起動するために必要。`--conservative` でも 2.9 系になるので一時的に固定して 2.8.1 にした。0-d-3 は advisory の修正 |
| nokogiri | 1.12.3 | 0-a で 1.18.10（済）→ Step 2 で 1.19 系最新 | 1.12 は Ruby 3.1 のネイティブ版がない。1.19 系は Ruby 3.2 以上が必要 |
| jwt（RP は直接使う。RS は oauth2 経由の間接依存） | 2.2.3 | 0-a で RP を 2.5.0（済）→ 0-f-2 で 2.10.3（RP は Gemfile に明記、RS は間接のまま） | RP の `lib/omniauth/strategies/my_op.rb` が直接使うのに Gemfile にない。OpenSSL 3 への対応は 2.5.0 から。advisory（CVE-2026-45363）の修正版は 2.10.3 / 3.2.0。oauth2 を 2.x にしても RS の jwt は上がらないので、RS は oauth2 1.4.7 のうちに jwt を上げる |
| json-jwt（OP、doorkeeper-openid_connect 経由） | 1.13.0 | 0-a で 1.14.0（済）→ 0-f-3 で外れる | OpenSSL 3 への対応は 1.14.0 から。CVE-2023-51774 は未修正だが、OP は署名だけで decode しないため影響なし。doorkeeper-openid_connect 1.8.4 で jwt に置き換わった。OP の minitest が json-jwt で ID トークンを検証しているので、0-f-3 で ruby-jwt に書き直す |
| nio4r / msgpack | 2.5.8 / 1.4.2 | 0-a で 2.5.9 / 1.4.5（済）。msgpack は 0-d-3 で 1.8.5（済） | 0-a は clang 17 で C 拡張がビルドできないため、同じマイナー内のパッチ版に更新。0-d-3 は advisory の修正 |
| thor（railties 経由） | 1.1.0 | 0-f-1 で 1.5.0（済） | 1.1.0 は Ruby 3.1 で `DidYouMean::SPELL_CHECKERS.merge!` の非推奨警告が出る（起動には影響なし）。1.2.0 で出なくなった。railties 6.1 は `~> 1.0` |
| oauth2 / omniauth-oauth2 | 1.4.7 / 1.7.1 | 0-f-2 で 2.0.25 / 1.9.0（同時） | omniauth-oauth2 1.9 は oauth2 2.0.2 以上が必要。RS が `OAuth2::Client` を直接使い、RP が独自ストラテジーを持つので最も壊れやすい。oauth2 2.x は `auth_scheme` の既定値が `:request_body` から `:basic_auth` に、`authorize_url`・`token_url` の既定値が相対パスに変わる（RP の `site` はパス付きなので URL が壊れる）。設定で元の挙動に固定する。advisory（CVE-2026-54603）は 2.0.22 で修正 |
| faraday | 1.7.0 | 0-d-3 で 1.10.6（済）→ 0-f-2 で 2.14.4（oauth2 の後） | oauth2 1.4.7 は faraday 2.0 未満を要求する（0-f で gemspec を確認）。RP と RS が直接呼んでいる（RP は Gemfile に明記する）。2.x の advisory は 2.14.3 で修正 |
| faraday-net_http（faraday 2 の依存） | — | 0-f-2 で 3.0.2 に一時固定 → Ruby を上げる各 Step で見直す | 3.1 以上は net-http gem に依存し、Ruby 3.1.7 の default gem の net-http・uri を置き換える。3.0.2 は依存がない |
| doorkeeper / doorkeeper-openid_connect | 5.5.2 / 1.8.0 | 0-f-3 で 5.7.1 / 1.8.9（交互に上げる）→ 5.8 以上・1.8.10 以上は Step 1 の後 → doorkeeper-openid_connect 1.10.2 以上は Step 2 の後 | openid_connect は 1.8.4 で JWT のライブラリが json-jwt から jwt に変わった（1.8.4〜1.8.7 は kid と `typ` が一時的に変わり、1.8.8 で戻った）。1.8.10 は Rails 6 のサポートをやめ、doorkeeper は 5.8.1 で CI から Rails 6 を外した。1.10.2 以上は Ruby 3.2 以上が必要。doorkeeper 5.5.2 の advisory（CVE-2023-34246）は 5.6.6 で修正されるが、openid_connect 1.8.0 は doorkeeper 5.6 未満を要求する。必須のマイグレーションはない（0-f の調査で確認） |
| devise | 4.8.0 | 0-f-1 で 4.9.4（済）→ Step 1 の後に 5.x | Rails 8.1 対応は Step 7 の最初に再確認。advisory 2 件は 5.x（5.0.4）でしか修正されず（4.9.4 も対象）、5.x は Rails 7.0 以上が必要（0-d-1 で確認） |
| dotenv-rails | 2.7.6 | 0-f-1 で 3.2.0（済） | 読むファイルの順番と、既にある環境変数を上書きしないことは 2.x と同じ。3.x はテストのたびに ENV を戻し、Rails のログに変数名を出す |
| puma | 5.4 | 0-d-3 で 5.6.9（済）→ 0-f-1 で 6.6.1（済）→ 7.2.1 以上 | 7 系に上げる時期は後の Step で判断。5.5.0 以降（6.6.1 も）は PROXY protocol v1 の advisory 2 件（CVE-2026-47736 / 47737）の対象で、修正版は 7.2.1 / 8.0.2 だけ。`set_remote_address proxy_protocol: :v1` を設定していないので影響しない（無視リストに入れた） |
| spring | 2.1.1 | 0-f-1 で削除（済） | Rails 7 から標準で入らない。`bin/spring`・`config/spring.rb` も消し、`bin/rails`・`bin/rake` を Rails 7.0 の雛形の形にした |
| byebug / web-console / listen / rack-mini-profiler | — | 0-f-1 で 12.0.0 / 4.2.1 / 3.10.1 / 4.0.1（済）→ Step 2 の後に byebug 13・web-console 4.3・rack-mini-profiler 5 | 次の版は Ruby 3.2 以上が必要。listen の `EventedFileUpdateChecker` の finalizer の `ThreadError` の警告（LOG.md の Step 0-b）は、3.10.1 でも出る（listen 側も未修正）。Rails 7.0 の development.rb の雛形には `file_watcher` の行がないので、Step 1 の `app:update` の差分で判断する |
| sprockets-rails | 3.2.2（間接） | Step 1 で明示 | Rails 7.0 から rails gem の依存から外れる |
| sqlite3 | 1.4.2 | 0-a で 1.7.3（済。clang 17 で 1.4 系がビルドできないため 0-f から前倒し）→ Step 5 で 2.x | Rails 7.1 までは 1.x のみ、8.0 は 2.1 以上必須 |
| annotate | 3.1.1 | Step 5 で annotaterb に置換 | 最後の版の 3.2.0 も `activerecord < 8.0` で、Rails 8 に対応しない（0-f で gemspec を確認）。注釈の出力が変わるので、3.2.0 には上げない |
| activerecord-session_store | 2.0.0 | 0-f-1 で 2.1.0（済）→ 各 Step の最初 | 2.2 以上は Rails 7.0 以上が必要。Rails を上げた後に `bundle update` が通らなければ Rails と同時に上げる |
| bootsnap / jbuilder / omniauth-rails_csrf_protection | 1.7.7 / 2.11.2 / 1.0.0 | 0-f-1 で bootsnap 1.26.0・jbuilder 2.13.0（済）→ jbuilder 2.14 以上は Step 1 の後、omniauth-rails_csrf_protection 2.x は Step 7 | jbuilder 2.14 以上は Rails 7.0 以上が必要。omniauth-rails_csrf_protection 2.0 の変化は Rails 8.1 だけが対象 |
| base64 / bigdecimal / mutex_m など | — | Step 4 で警告が出たら明示 → Step 8 で必須 | Ruby 3.4 で標準ライブラリから外れる |
| rubocop 系 / oxlint 系 | — | 各 Step の最初 | バージョン固定。更新は単独コミット |
| brakeman / bundler-audit | 7.1.1 / 0.9.3（0-d-1 で導入） | 各 Step の最初 | brakeman 8 系は Ruby 3.1 では入らない |
| simplecov / webmock | 0.22.0 / 3.26.4（0-d-2 で導入） | 各 Step の最初 | simplecov 1.x は Ruby 3.2 以上が必要（Step 2 の後に上げられる） |
| json（rubocop 経由） | 2.6.1（0-d-1 で lock に入った） | Ruby を上げる各 Step で合わせ直す（8 章の 4） | Ruby 3.1.7 の default gem と同じ版。そのままでは 3.0.2 が lock に入り、アプリが読む json が変わるため、一時固定で 2.6.1 にした |
| bigdecimal（webmock → crack 経由） | 3.1.1（0-d-2 で lock に入った） | Ruby を上げる各 Step で合わせ直す（8 章の 4） | Ruby 3.1.7 の default gem と同じ版。そのままでは 4.1.3 が lock に入り、アプリが読む bigdecimal が変わるため、一時固定で 3.1.1 にした |
| concurrent-ruby（Rails 経由） | 1.1.9 | Step 3 の後 | 1.3.5 以上は Rails 6.1 でも 7.0 でも起動しない（LOG.md の Step 0-a、Step 0-d-1）。advisory は 1.3.7 で解消する |
| rack / loofah・crass・rails-html-sanitizer / websocket-driver / globalid / bcrypt | — | 0-d-3（済） | advisory があり、Rails 6.1・Ruby 3.1 のまま修正版に上げられた。上げた版は LOG.md の Step 0-d-3（mail・msgpack・faraday・puma は上の行） |
| logger（mail 経由） | 1.5.0（0-d-3 で lock に入った） | Ruby を上げる各 Step で合わせ直す（8 章の 4） | Ruby 3.1.7 の default gem と同じ版。そのままでは 1.7.0 が lock に入り、アプリが読む logger が変わるため、一時固定で 1.5.0 にした |
| base64（websocket-driver 経由） | 0.1.1（0-d-3 で lock に入った） | Ruby を上げる各 Step で合わせ直す（8 章の 4） | Ruby 3.1.7 の default gem と同じ版。そのままでは 0.3.0 が lock に入り、アプリが読む base64 が変わるため、一時固定で 0.1.1 にした |
| cgi（activerecord-session_store 経由、RP） | 0.3.7（0-f-1 で lock に入った） | Ruby を上げる各 Step で合わせ直す（8 章の 4） | Ruby 3.1.7 の default gem と同じ版。そのままでは 0.5.2 が lock に入り、アプリが読む cgi が変わるため、一時固定で 0.3.7 にした |

## 8. 各 Step 共通の手順

1. **調査（Plan モード）**: Rails 公式アップグレードガイドの該当箇所、ruby-jp の各バージョンのナレッジページ、railsdiff.org、`bundle outdated`、メジャー更新する gem の CHANGELOG を確認し、Step の作業計画を出す。**人間の承認を待つ**
2. **周辺 gem → Rails のパッチ版を最新に → 非推奨警告の解消**: テスト環境で `config.active_support.deprecation = :raise`
3. **Rails のマイナーを上げる**
   - Gemfile を変えて `bundle update rails`
   - `bin/rails app:update` を全上書きで実行し、`git diff` で差分を振り分ける（独自設定は戻す、新しい構成は採用しない）。**差分は人間が確認する**
   - `new_framework_defaults_X_Y.rb` を 1 つずつ有効化してテスト → 全部有効になったら `load_defaults` を上げてファイルを削除
   - RuboCop の `TargetRailsVersion` を上げ、新しい指摘は別コミットで直す
4. **Ruby を上げる場合**: Ruby を上げてコミット → `TargetRubyVersion` を上げて新しい指摘を直す（別コミット）
   - lock に入れた default gem（json・bigdecimal・logger・base64・cgi）を、新しい Ruby の default gem の版に一時固定で合わせ直す。その Ruby で default gem でなくなったものは 7 章の表に従う
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
- [ ] E2E が全件通り、スナップショットとの比較に差分がない
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
| doorkeeper-openid_connect の JWT ライブラリ変更で ID トークンや JWKS が変わる（Next.js 製 RP にも影響しうる） | スナップショットの比較で ID トークンの項目と `alg`、JWKS の構造を比べる |
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

スキルには手順だけを書き、バージョン固有の知識は LOG.md に残す。コマンドの実行や確認の手順のコツ（[TIPS.md](TIPS.md)）は、スキルの参照用のファイルに移す。

## 14. 未決事項

- [ ] 最終的に Ruby 4.0 まで上げるか（Step 8 完了時に判断）
- [x] advisory があり、Rails 6.1・Ruby 3.1 のまま修正版に上げられる gem（7 章の表）を、いつ上げるか（Step 0-d-1 で人間が判断）: 脆弱性の修正だけのサブステップ 0-d-3 を設け、0-d-2 の後、0-e の前に上げる
- [x] `rails_open_id_provider/jwtRS256.key.example` の扱い（Step 0-c で判断）: 鍵の中身のないプレースホルダーで、どこからも参照されていなかったため、`.pub.example` と一緒に削除した

## 15. 決定済みの事項

- ローカルブランチ `feature/rails_migration_plan`（過去の計画とスキルの試作）は参照せず、知見も取り込まない。過去の前提に引きずられるのを避けるため。今回の作業では触れない
