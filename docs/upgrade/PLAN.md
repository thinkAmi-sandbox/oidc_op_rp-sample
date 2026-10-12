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
2. アップグレード中は、各システムの業務的な挙動を変えない。Rails の既定値の変化には追随する。定義は次のとおり（Step 1 の着手時に人間と決めた。Step 0 の判断は見直さない）
   - **A. Rails の既定値・雛形の変化**: 追随する。例: `load_defaults` の各設定、`app:update` の雛形、Rails の既定の応答ヘッダー、Rails のヘルパーが出すタグの形。追随しないと、版を上げるたびに古い既定値のままで問題がないかを確かめ続けることになり、セキュリティや性能の改善も取り込めない
   - **B. 各システムの業務的な挙動**: 変えない。例: 画面に描画される文字、アプリが持つ URL・ルーティング、画面遷移とリダイレクト先、OP・RP・RS の間のやり取り（認可要求・トークン要求・ID トークン・userinfo・introspect）、DB に入るデータ。変えるときは「意図的な仕様変更」として本計画に明記し、LOG.md に記録する
   - 境目の扱い
     1. Rails 以外の gem の既定値の変化も、原則は A と同じく追随する。ただし OP・RP・RS の間のやり取りが変わるもの（oauth2 の `auth_scheme` のように、相手が受け付けなくなりうるもの）は B として扱い、その都度人間に確かめる。既存のやり取りの方法が不適切で、ライブラリに追随したほうがよい場合もあるため。gem の generator の雛形（initializer、ロケール、アプリが上書きしているビュー）にも、`app:update` の雛形と同じく追随する（Step 1-b-3 で人間が決めた。gem の今後の版に追随しやすくするため）
     2. 描画される文字・遷移・送信内容が同じなら、Rails が出すタグの形が変わっても A（`button_to` の `<button>` など）
     3. A による追随が起きたら、コミットの前に、項目ごとに「何が変わるか・なぜ起きたか・今回のアプリへの影響・提案」を解説し、人間の返事をもらってからコミットする。出典として、Rails の PR・CHANGELOG・gem のソースに加え、日本語版の Rails ガイドに該当の節があればページと見出しを示す。ガイドは上げる先の版のページ（例: `https://railsguides.jp/v7.0/`）を使い、その版になければ最新版のページを使って、そう明記する。同じ内容を `docs/upgrade/defaults/`（Rails の版ごとのファイル）に ID を振って記録し、LOG.md とコミットメッセージからは ID で指す。記録は、返事をもらった後、設定のコミットより前の docs のコミットで足す（設定のコミットのメッセージから、既にある ID を指せるようにするため）。「意図的な仕様変更」は B を変えるときだけに使う
     4. アプリが意図して書いた設定（理由のコメントがある、業務に関わる）は残す。昔の雛形の値が残っているだけの設定は、新しい雛形に合わせる。迷うものはその都度人間に確かめる
     5. 既にある部品の設定・既定値の変化は A。gem・インフラ・部品を新しく足すもの（4 の新しい構成）と、使っていない機能を動かし始めるもの（Active Storage のマイグレーションなど）は採用しない
     6. 一度きりの移行の影響（Cookie の鍵の算出方式が変わり、ログインが一度切れるなど）は A として追随し、移行用のコードは書かない
     7. ログの出力の変化は A。アプリが足した伏せる対象（`filter_parameters` の `:code`）は 4 にあたるので残す
     8. A で E2E のスナップショット、または minitest の応答のスナップショット（Step 1-b-2）が変わったときは、理由を確かめたうえで更新し、LOG.md に書く。スナップショットの更新は、変化を起こしたコミットに一緒に入れる。B にあたる変化が出たら、更新せずに止まって人間に確かめる
3. 脆弱性が公表されている gem の修正は即時に行う。設定の改善（PKCE 必須化、secret のハッシュ化など）は epic を main に取り込んだ後に別作業で行う。見送った改善は [docs/IMPROVEMENTS.md](../IMPROVEMENTS.md) に記録する
4. `app:update` が提案する新しい構成（Propshaft、Solid Queue/Cache/Cable、Kamal、Thruster など）は採用しない
5. 伊藤さん式の「ステージング確認・本番デプロイ」は、「3 アプリ通しの E2E ＋ 応答のスナップショット（E2E の OP の応答と、Step 1-b-2 からの 3 アプリの minitest の応答）との比較＋ PR レビュー」に置き換える

## 4. ブランチと PR

| 項目 | 内容 |
|---|---|
| 固定 | `main`（タグ `rails-6.1`）。作業中は変更しない |
| タグ `rails-6.1-prepared` | Ruby 3.1.7 / Rails 6.1.7.10、Step 0 完了時点。epic の PR [#20](https://github.com/thinkAmi-sandbox/oidc_op_rp-sample/pull/20) のマージコミット |
| epic | `epic/rails-8.1-upgrade`（`main` から作成。開始を示す空コミットあり） |
| 作業ブランチ | `upgrade/<step>-<内容>`。epic から切り、PR の向き先は epic |
| PR の単位 | Step 0 はサブステップ（0-a〜0-g。0-d は 0-d-1・0-d-2・0-d-3、0-f は 0-f-1・0-f-2・0-f-3 に分ける）ごと。0-f の gem 更新は、各 PR の中で gem ごとにコミット。Step 1 以降は 1 Step = 1 PR（Step 1 の後のサブステップ 1-b は、1-b-1（起動の途中の読み込みの検出）・1-b-2（応答のスナップショットのテスト）・1-b-3（周辺 gem）に分け、1-b-3 はさらに 1-b-3-1（RP の gem・jbuilder・devise）と 1-b-3-2（doorkeeper 系）の 2 つの PR に分ける） |
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
| 0-g | 3.1 | 6.1 | CI（GitHub Actions）。仕上げから前倒し |
| 1 | 3.1 | **7.0.x** | annotate 3.2.0、`app:update`、`load_defaults 7.0`、concurrent-ruby 1.3.7 |
| 1-b | 3.1 | 7.0 | 起動の途中の読み込みを CI で検出する（1-b-1。a-nti_manner_kick_course）、3 アプリの応答のスナップショットのテスト（1-b-2）、Rails 7.0 以上を必要とする周辺 gem（1-b-3-1: jbuilder・activerecord-session_store・omniauth-rails_csrf_protection・devise 5.x、1-b-3-2: doorkeeper 5.9・doorkeeper-openid_connect 1.10） |
| 2 | **3.2** | 7.0 | Ruby、nokogiri 1.19（advisory の解消） |
| 2-b | 3.2 | 7.0 | Ruby 3.2 以上を必要とする周辺 gem（doorkeeper-openid_connect 1.10.5、zeitwerk 2.7・2.8、byebug 13、simplecov 1.2、brakeman 8.0。rack-mini-profiler 5 は Step 3 に移した） |
| スキル化 | 3.2 | 7.0 | `/rails-upgrade` のスキルと、Rails のマイナーを上げるときのスクリプト（13 章） |
| 3 | 3.2 | **7.1.x** | 直接の gem（brakeman 8.1、jwt 3.3、puma 8、omniauth-rails_csrf_protection 2.0）、`app:update`、`autoload_lib_once`（RP の独自ストラテジー対応）、activerecord-session_store 2.3、rack-mini-profiler 5 |
| 3-b | 3.2 | 7.1 | doorkeeper-openid_connect 2.0（**意図的な仕様変更**: マイグレーション、discovery と webfinger の応答の変化） |
| 4 | **3.3** | 7.1 | Ruby のみ |
| 4-b | 3.3 | 7.1 | simplecov 1.3.2（Ruby 3.3 以上を必要とする周辺 gem） |
| スキルの見直し | 3.3 | 7.1 | `/rails-upgrade` の作業の切り替え、確認のまとめ方、人間が貼るものの出し方（13 章の 7） |
| 5 | 3.3 | **7.2.x** | `Rails.application.secrets` 削除への対応、sqlite3 2.x、annotate → annotaterb |
| 6 | 3.3 | **8.0.x** | puma 6 以上、Solid 系・Kamal 系の生成物は不採用 |
| 7 | 3.3 | **8.1.x** | 最終目標の Rails |
| 8 | **3.4** | 8.1 | 標準ライブラリから外れた gem の明示、chilled string 警告への対応 |
| 9（任意） | 4.0 | 8.1 | 依存 gem が対応済みなら実施 |
| 仕上げ | — | — | Dependabot・README 更新、epic → main |

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
  - Rails/Output: `puts` のまま残し、`rubocop:disable` で囲む。logger にすると出力先が変わるため。logger への変更は epic を main に取り込んだ後の改善として扱う（IMPROVEMENTS.md の IMP-003）
  - Metrics（RS・RP のメソッド、OP の annotate の rake）: メソッドを分けず、`rubocop:disable` を付ける。既定の上限は新しいコードに効いたまま
  - Rails/RakeEnvironment（OP の annotate の rake）: `:environment` は足さず、`rubocop:disable` を付ける。Step 5 で見直す（Step 5 で、annotaterb の雛形の rake に `task` のブロックがなく、要らなくなった。DEF-7.2-01）
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
  - 例外として、doorkeeper-openid_connect が discovery に足す `code_challenge_methods_supported` は設定で消せないので、「意図的な仕様変更」として受け入れる（0-f-3）。0-f-3 の着手時に、同じく設定で戻せない `/.well-known/oauth-authorization-server` の追加と、認可エンドポイントのエラー画面のステータスの変化も加えた（人間が承認）
  - spring を消すときは、`bin/spring`・`config/spring.rb` も消し、`bin/rails`・`bin/rake` を Rails 7.0 の雛形の形にする

#### 0-f-1: spring の削除と、開発・テスト用などの gem

- [x] spring を削除（`bin/` と `config/spring.rb`、E2E の起動スクリプトと `.claude/launch.json` の `DISABLE_SPRING` も）
- [x] byebug 12.0.0、web-console 4.2.1、listen 3.10.1、rack-mini-profiler 4.0.1、thor 1.5.0、bootsnap 1.26.0、jbuilder 2.13.0、puma 6.6.1、dotenv-rails 3.2.0、activerecord-session_store 2.1.0、devise 4.9.4（上げた版と確かめたことは LOG.md の Step 0-f-1）
- [x] thor の `DidYouMean::SPELL_CHECKERS.merge!` の警告が消えることを確かめた
- [x] listen の finalizer の警告は、3.10.1 でも出る。Step 1 の `app:update` で判断する（7 章）

#### 0-f-2: oauth2 系（RS・RP）

決めた経緯は LOG.md の Step 0-f-1「作業計画で決めたこと」、作業の記録は LOG.md の Step 0-f-2。

- [x] RS: jwt 2.10.3（oauth2 1.4.7 のうちに上げる）→ oauth2 2.0.25（`OAuth2::Client.new` に `auth_scheme: :request_body` を足す）→ faraday 2.14.4（faraday-net_http は 3.0.2 に一時固定）
- [x] RP: テストを足す（トークン要求の本文に client_id・secret があり Authorization ヘッダーがないこと、`redirect_uri`）→ jwt を Gemfile に明記して 2.10.3 → oauth2 2.0.25 と omniauth-oauth2 1.9.0（`client_options` に `auth_scheme: :request_body`・`authorize_url`・`token_url` を明記）→ omniauth 2.1.4 → faraday を Gemfile に明記して 2.14.4
- [x] 上げた gem の advisory（oauth2・jwt）を `.bundler-audit.yml` から消す
- [x] gem は RS・RP の両方で同じ順に上げた（jwt → oauth2 → faraday。RP は oauth2 の後に omniauth）

0-f-1 の作業計画のときに調べたこと（rubygems の API・gemspec・CHANGELOG・タグ間のソース）。0-f-2 の着手時（2026-10-08）に、版・依存・advisory と、作業に関わる事実を確かめ直した（確かめた範囲は LOG.md の Step 0-f-2「着手時に確かめ直したこと」）:

| gem | 分かったこと | テスト・E2E で守られているか |
|---|---|---|
| oauth2 2.0.25 | 依存は `faraday >= 0.17.3, < 4`・`jwt >= 1.0, < 4`・`logger ~> 1.2`・`rack < 4` ほか。新しく入るのは version_gem・snaky_hash・auth-sanitizer・anonymous_loader（RS は hashie 5.1.0 も）。`--conservative` を付けないと logger・jwt・faraday も動く | — |
| | 2.0.0 で `auth_scheme` の既定値が `:basic_auth` に、`authorize_url`・`token_url` の既定値が相対パス（`oauth/authorize`・`oauth/token`）になった。RP は `site` がパス付きなので、URL が `.../oauth/authorize/oauth/token` になる | RS の認証方式はテストあり。RP の認証方式はなし（先に足す）。RP の URL は認可要求・ログインのテストと E2E |
| | 応答の parse が snaky_hash になる（`raw_info` などのクラスが Hash から変わる。`id_token`・`sub`・`email` のキーは変わらない）。extra tokens の警告は 2.0.10 から既定で出ない。`raise_errors`・`token_method`・`get_token` の引数は同じ。`redirect_uri` はクエリが付いたまま送られる | クラスの変化はなし。`redirect_uri` はなし（先に足す） |
| omniauth-oauth2 1.9.0 | `oauth2 >= 2.0.2, < 3`、`omniauth ~> 2.0`。PKCE・`callback_url`・`client_options` の渡し方は 1.7.1 と同じ。1.7.2 で state の確認が error パラメーターの確認より先になり（0-f-2 で直した）、1.9 で state を `secure_compare` で比べる。state のない error のコールバックは `csrf_detected` に、セッションに state がないと NoMethodError になる | エラーの経路はテストなし（LOG に記録する） |
| omniauth 2.1.4 | `callback_url` は 2.0.4 と同じ（クエリ付き）。`rack >= 2.2.3` と logger が依存に入る。rack-protection は `--conservative` なら 2.1.0 のまま（3.2.0 まで上げられる。4.x は rack 3 が必要） | — |
| jwt 2.10.3 | 依存は `base64 >= 0`（0.1.1 で足りる）。`my_op.rb` が使う `JWT.decode`（鍵を探すブロック付き）・`JWT::JWK::RSA.import` と、テストが使う `JWT::JWK::RSA.new(..., kid:)` で非推奨の警告は出ない。テストが期待する例外クラスも変わらない | RP の ID トークンの検証のテスト |
| faraday 2.14.4 | Ruby 3.0 以上。依存は `faraday-net_http >= 2.0, < 3.5`・json・logger。アプリの `Faraday.get` / `Faraday.post` の呼び方は変わらず、既定のミドルウェア（url_encoded と net_http）も同じ。User-Agent の文字列だけが変わる。faraday-multipart・faraday-retry・ruby2_keywords は lock から外れる見込み | RS・RP のテスト（WebMock）と E2E |
| faraday-net_http | 3.4.x は `net-http ~> 0.5`、3.1〜3.3 は `net-http >= 0` に依存し、default gem の net-http 0.3.0.1（net-http の新しい版は uri 0.12.4 も）を置き換える。3.0.2 は依存がない | — |

ダウンロード（0-f-1 の作業計画で承認済み。版が変わったら示し直す）: jwt 2.10.3（54 KB）、oauth2 2.0.25（78 KB）、omniauth-oauth2 1.9.0（12 KB）、omniauth 2.1.4（23 KB）、snaky_hash 2.0.7（40 KB）、version_gem 1.1.15（29 KB）、auth-sanitizer 0.2.3（44 KB）、anonymous_loader 0.1.3（35 KB）、hashie 5.1.0（54 KB、RS）、faraday 2.14.4（75 KB）、faraday-net_http 3.0.2（8 KB）

#### 0-f-3: doorkeeper 系（OP）

決めた経緯と作業の記録は LOG.md の Step 0-f-3。

- [x] テストを足す（kid 2 本、同意画面を省く条件 2 本、form_post・エラー画面・同意の拒否 3 本）
- [x] jwt を OP の Gemfile の test グループに明記して 2.10.3（一時固定）にし、OP のテストの `JSON::JWT` を ruby-jwt に書き直す（gem を上げる前）
- [x] doorkeeper 5.5.4 → doorkeeper-openid_connect 1.8.9（一時固定。json-jwt が外れる）→ doorkeeper 5.6.9（一時固定）→ 5.7.1。doorkeeper-openid_connect 1.8.0 は doorkeeper 5.6 未満を要求するので、交互に上げた
- [x] **意図的な仕様変更**（設定では戻せない。LOG.md の Step 0-f-3「意図的な仕様変更」）
  - discovery に `code_challenge_methods_supported: ["plain", "S256"]` が増える（doorkeeper-openid_connect 1.8.3 以上は PKCE の列があると出す）。`e2e/baseline/discovery.json` を更新した
  - `/.well-known/oauth-authorization-server` が増え、discovery と同じ応答を返す（1.8.1 以上）
  - 認可エンドポイントのエラー画面の HTTP ステータスが 200 → 400（`invalid_client`・`unauthorized_client` は 401）になる（doorkeeper 5.6.7 以上）
- [x] 上書きしているビューを、上げた版の雛形と比べる（ビューは変えない。新しい雛形に合わせるのは docs/IMPROVEMENTS.md の IMP-008）
- [x] 上げた gem の advisory（doorkeeper・json-jwt）を `.bundler-audit.yml` から消す

0-f-1 の作業計画のときに調べたこと（サブエージェントの調査）。0-f-3 の着手時（2026-10-08）に gem のソース・CHANGELOG で確かめ直し、違っていたところを直した（直した箇所は LOG.md の Step 0-f-3「PLAN の表から直したこと」）:

| 対象 | 分かったこと | テスト・E2E で守られているか |
|---|---|---|
| 版の組み合わせ | doorkeeper-openid_connect は 1.8.0・1.8.1 が `doorkeeper < 5.6`（json-jwt）、1.8.2・1.8.3 が `< 5.7`（1.8.3 は json-jwt 1.15.0 以上）、1.8.4〜1.8.8 が `< 5.7`（jwt 2.5 以上）、1.8.9 が `< 5.8`、1.8.10・1.8.11 が `< 5.9`（Ruby 3.1 以上。1.8.11 は ostruct も）、1.9.0〜1.10.1 が `< 6.0`。doorkeeper は 5.6.3 から Ruby 2.7 以上 | — |
| マイグレーション | doorkeeper 5.5.2 → 5.7.1 で必須のものはない（雛形の差分は列の並びだけ）。doorkeeper-openid_connect は 1.8.9 まで新しいものはない（generators は 1.8.0 と 1.8.9 で同じ）。2.0.0 は `post_logout_redirect_uris` の列を足すマイグレーションが必要（2.0.0.beta1 の #243） | `db:drop db:setup` で E2E 用の DB を作り直している |
| doorkeeper の新しい設定 | `force_pkce`、`revoke_previous_client_credentials_token`、`revoke_previous_authorization_code_token`、`custom_access_token_attributes` などはすべて opt-in。`pkce_code_challenge_methods` は 5.8.0 で入る設定で、5.7.1 は今と同じく plain・S256 を受け付ける。`client_credentials_methods`（Basic・本文）の既定値は今と同じ | — |
| 同意画面を省く条件 | 5.6.0〜5.6.2 は有効なトークンしか見ない不具合があり（doorkeeper#1542）、5.6.3 で期限切れも含める挙動に戻った。5.6.6 で「confidential のアプリ」という条件が加わった（doorkeeper#1646、CVE-2023-34246 の修正）。seeds と fixtures のアプリは 3 つとも confidential | OP のテスト（期限切れでも省く、revoke 済みなら出す）と E2E の logout（有効なトークンで省く） |
| 期限切れの判定・introspect | `expirable.rb` は変わらない（`現在時刻 > created_at + expires_in`）。introspect の項目も同じ（並びだけが変わる） | OP のテスト（10 分ちょうど・10 分 1 秒）と E2E のスナップショット（キーを並べ替えて保存） |
| 応答ヘッダー | トークン応答と OAuth のエラー応答から `Pragma: no-cache` が消える（5.6.6 #1644。5.8.0 #1712 で戻る）。gem は `Cache-Control: no-store, no-cache` を返すが、Rails 6.1 が `no-store` にまとめるので値は変わらない | スナップショットは本文だけなので、前後の応答ヘッダーを比べて LOG.md に記録した |
| client_credentials | 5.6.0.rc2（#1558）から、scope を付けない要求は、アプリの scopes に既定の `openid` がないと失敗する。RS とテストは `scope=introspection` を付ける | RS のテストと E2E |
| 認可エンドポイントのエラー画面 | 5.6.7（#1676）から、エラーに応じたステータス（400・401）で返す（意図的な仕様変更） | OP のテスト |
| ビューの上書き | `app/views/doorkeeper/` の 12 ファイルと `app/views/layouts/doorkeeper/` の 2 ファイルは、5.5.2 の雛形と同じ。`authorizations/new.html.erb` だけが nonce の hidden field を 2 つ足している。雛形は 5.6.6 で `error`（ローカル変数 `error_response`）、5.7.0（#1702）で `form_post`（ローカル変数 `auth`）が変わったが、上書きしているビューが読むインスタンス変数は 5.7.1 でも入る。5.6.0.rc1（#1552）で雛形の hidden field の重複 ID がなくなった | OP のテスト（同意画面・form_post・エラー画面・拒否）と E2E |
| ID トークン・JWKS | 1.8.4 で JWT のライブラリが json-jwt から jwt に変わった。kid は 1.8.4・1.8.5 だけ鍵の SHA256 になり、1.8.6 で RFC 7638 の thumbprint に戻った。ヘッダーの `typ` は 1.8.4〜1.8.7 で消え、1.8.8 で戻った。`auth_time` は出ないまま、`exp - iat` は 120 のまま。JWKS の項目（kty・n・e・kid・use・alg）は同じ。手動確認用の鍵の kid は前後で同じ | OP のテスト（kid が RFC 7638 の thumbprint、ID トークンの kid が JWKS と同じ）、構造と `alg` は E2E のスナップショット、RP の検証は E2E のログイン |
| discovery | 1.8.3 から、PKCE の列があると `code_challenge_methods_supported: ["plain", "S256"]` を出す。1.8.1 から `/.well-known/oauth-authorization-server` でも同じ応答を返す。1.8.2（#170）から discovery と userinfo の基底が `ApplicationMetalController` になったが、応答ヘッダーと Cookie は変わらない。ほかの項目は同じ | E2E のスナップショット（意図的な仕様変更として更新） |
| 使っていない経路の変化 | 1.8.4（#183）で、`prompt=consent` でもログインしていないユーザーには同意画面を出さない。RP は `prompt` を使わない | なし |
| OP のテスト | `test/integration/authorization_code_flow_test.rb` の `JSON::JWT.decode` を、gem を上げる前に ruby-jwt の `JWT.decode`（JWKS を渡す）に書き直した。jwt は test グループに明記した | — |
| 後の Step に関わること | 1.10.0 で、独自の claim を先に混ぜる順番（#273）、`prompt=select_account`（#279）、`prompt=none` と `max_age`（#275）が変わる。doorkeeper-openid_connect 1.9.0 以上は doorkeeper 5.8 以上にある `pkce_code_challenge_methods` を呼び、1.9.0〜1.10.4 は doorkeeper 5.8 未満で discovery が壊れる（5.5 では起動時に NameError。1.10.5 の #329 で直った）。1.9.0 には Dynamic Client Registration の advisory（CVE-2026-44476。OP では無効）がある。doorkeeper 5.9.5〜5.9.7 は、複数のクライアント認証方式やトークンの渡し方を同時に使う要求を拒む | — |

ダウンロード（0-f-1 の作業計画で承認済み。0-f-3 の着手時に版とサイズが同じことを確かめた）: doorkeeper 5.5.4（100 KB）・5.6.9（104 KB）・5.7.1（104 KB）、doorkeeper-openid_connect 1.8.9（24 KB）、jwt 2.10.3（54 KB。OP の `vendor/bundle` に入れた）

### Step 0-g: CI（GitHub Actions）

当初は仕上げで設定する計画だったが、Step 1 以降は変更が大きいので、Step 1 の前に前倒しした（人間の判断。理由は LOG.md の Step 0-g）。Dependabot は「一度に上げるのは 1 つだけ」とぶつかるので、仕上げに残す。

- [x] GitHub Actions（minitest、E2E、RuboCop、oxlint・oxfmt、bundler-audit、brakeman、zeitwerk:check、安全チェック）
- [x] CI で OP の署名鍵 `rails_open_id_provider/jwtRS256.key` がないときの minitest の扱いを決める（OP は起動時に鍵を読む。0-d-2 では手動確認用の鍵を使った）
- [x] 3 アプリの lock に `x86_64-linux` を足す（gem の版は変えない）
- [x] CI で E2E を流せるようにする（Node の版を `e2e/.node-version` に置く、`e2e/scripts/start-server.sh` を mise がなくても動くようにする）
- 着手時の調査で決めたこと（人間が承認。理由は LOG.md の Step 0-g）
  - ジョブ: `rails`（3 アプリの matrix。RuboCop・`zeitwerk:check`・minitest・bundler-audit・brakeman を順に流し、前の検査が失敗しても後の検査を流す）、`e2e`（oxlint・oxfmt・Playwright）、`public-safety`（安全チェック）、`ci-result`（3 つの結果をまとめる。ブランチ保護で必須にするのはこれだけ）
  - 動かす条件: epic と main への PR、epic と main への push、手動（`workflow_dispatch`）。`upgrade/*` への push と、paths の絞り込みはなし
  - ランナーは `ubuntu-24.04` に固定する。Ruby は `ruby/setup-ruby` で各アプリの `.ruby-version` を読み、`bundler-cache` で各アプリの `vendor/bundle` をキャッシュする。Node は `actions/setup-node` で `e2e/.node-version` を読む
  - OP の署名鍵: CI の `rails` ジョブで、OP のときだけ、起動する検査の前に E2E の起動スクリプトと同じ方法で作る。アプリのコードは変えない。E2E は起動スクリプトが作る
  - E2E: ブラウザは `npx playwright install --with-deps --only-shell chromium`（手元と同じ headless shell）で、キャッシュしない。失敗したときは、レポート・トレースと 3 アプリの `log/development.log` を artifact に 7 日残す（中の値は CI の使い捨ての環境のもの）
  - 安全チェック: 追跡中の全ファイルを `--files` で、PR（push は前後の範囲）のコミットメッセージを `--message` で検査する。PR のタイトル・本文は検査しない
  - action はコミットの SHA で固定し、版を行末のコメントに書く。公開から 2 週間以上たった版を使う。`permissions` は `contents: read` だけ
  - ブランチ保護（設定は人間）: ルールセットで、epic への PR に `ci-result` の通過を必須にする。`main` は epic を取り込むまでワークフローがないので、仕上げで対象に足す（LOG.md の Step 0-g「ブランチ保護の設定」）

調べたこと（着手時の 2026-10-08）:

| 項目 | 分かったこと |
|---|---|
| Ruby 3.1.7 | `ruby/setup-ruby` v1.325.0 の `ruby-builder-versions.json` に 3.1.7 がある。ビルド済みの Ruby は `ubuntu-22.04`・`ubuntu-24.04` にあり、`ubuntu-26.04` にはない（ruby-builder の toolcache）。`ubuntu-latest` は使わない |
| Ruby の版の読ませ方 | setup-ruby は `ruby-version` を省くと、`working-directory` の `.ruby-version` を最初に読む。各アプリの `mise.toml` は settings だけ |
| bundle のキャッシュ | `bundler-cache: true` は、lock があると `bundle config --local deployment true`（frozen。置き場所は `vendor/bundle`）で入れる。Bundler は lock の `BUNDLED WITH`（2.3.27） |
| lock のプラットフォーム | 3 アプリとも `arm64-darwin`・`x86_64-darwin-19` だけ。epic の lock のコピーで `bundle lock --add-platform x86_64-linux` を試すと、増えるのは nokogiri 1.18.10（`x86_64-linux-gnu`）・sqlite3 1.7.3（`x86_64-linux`）の行と `PLATFORMS` の 1 行だけ。ffi・bcrypt・puma などは元から ruby プラットフォームで、Linux ではソースからビルドされる |
| Node の版 | `actions/setup-node` の `node-version-file` は `.nvmrc`・`.node-version`・`.tool-versions`・`package.json` を読み、`mise.toml` は読まない |
| E2E の起動スクリプト | `e2e/scripts/start-server.sh` は `mise exec --` で `ruby`・`bin/rails` を呼ぶので、mise のない CI では動かない |
| OP の署名鍵 | `rails_open_id_provider/config/initializers/doorkeeper_openid_connect.rb` が起動時に `jwtRS256.key` を読む。minitest と `zeitwerk:check` も起動するので鍵が要る。テストは鍵の中身に依存しない |
| RP・RS の環境変数 | 起動時は `ENV[...]` を読むだけで、`.env` がなくても起動する。テストはコミット済みの `.env.test`、E2E は `.env_e2e` を読む |
| 安全チェック | 追跡中の全ファイルを `--files` に渡すと通る。`main` から epic までの 204 コミット（マージコミット 11 を含む）のメッセージも、`--message` で全部通る |
| Playwright のブラウザ | 設定は headless の既定のままなので、手元も headless shell で流れている。Playwright の CI の文書（playwright.dev の Continuous Integration）は、復元にかかる時間がダウンロードと同じくらいなので、ブラウザのバイナリのキャッシュを勧めていない |
| action の版 | `actions/checkout` v7.0.1、`ruby/setup-ruby` v1.325.0、`actions/setup-node` v6.5.0、`actions/upload-artifact` v7.0.1（どれも公開から 2 週間以上たった版） |

### Step 1: Rails 7.0

「8. 各 Step 共通の手順」に従い、Ruby 3.1.7 のまま Rails を 7.0.10 に上げる。着手時の作業計画で決めたこと（人間が承認。経緯は LOG.md の Step 1）:

- [x] annotate 3.1.1 → 3.2.0（RP・OP。Rails 6.1 のうちに上げた。前後で注釈の出力が同じことを確かめた）
- [x] Rails 6.1.7.10 → 7.0.10（`load_defaults 6.1` のまま）。`.bundler-audit.yml` から CVE-2024-54133 を消した。drb 2.1.0 の依存の ruby2_keywords 0.0.5（Ruby 3.1.7 の default gem と同じ版）も入った（人間が承認）
- [x] `bin/rails app:update`（差分は人間が確認した）
- [x] listen を Gemfile から外した
- [x] `new_framework_defaults_7_0.rb` をグループごとに有効にした（下の表の順。項目ごとの解説は [defaults/rails-7.0.md](defaults/rails-7.0.md)）
- [x] RP の session_store の serializer の設定を、`config/application.rb` から `config/initializers/session_store.rb` の `ActiveSupport.on_load(:active_record)` に移した（グループ 3 の前。理由は defaults/rails-7.0.md の「補足」）
- [x] `load_defaults 7.0` にし、不要になった initializer を消した
- [x] RuboCop の `TargetRailsVersion` を 7.0 にした（新しい指摘なし）
- [x] concurrent-ruby 1.1.9 → 1.3.8（advisory 3 件の修正。計画では 1.3.7 だったが、1.3 系の最新の 1.3.8 にした（人間が承認））
- 決めたこと
  - 上げる先は 7.0 系の最新の 7.0.10。activesupport 7.0.10 が足した依存のうち、drb・mutex_m は Ruby 3.1.7 の default gem と同じ版（2.1.0・0.1.1）に、default gem の版では要件を満たせない benchmark・securerandom は要件を満たす最小の版（どちらも 0.3.0）に一時固定する
  - sprockets-rails は Gemfile に足さない（下の「調べたこと」の Sprockets の行。当初の計画から変更）
  - annotate は 3.2.0 に上げ、annotaterb への置き換えは Step 5 のまま（当初は「3.2.0 には上げない」としていた。7 章）
  - Rails 7.0 以上を必要とする周辺 gem（devise 5.x、doorkeeper 5.8 以上と doorkeeper-openid_connect 1.8.10 以上、jbuilder 2.14 以上、activerecord-session_store 2.2 以上、omniauth-rails_csrf_protection 1.0.2）は、サブステップ 1-b として別の PR にする。Step 1 が epic に入ってから調べて作業計画を出す
  - `app:update` の差分: アプリ独自の設定（RP の `config/application.rb` の session_store の serializer、`test.rb` の `deprecation = :raise`、`filter_parameter_logging.rb` の `:code`）は戻す。development.rb の `file_watcher` の行が消えることと `server_timing = true` は雛形に合わせる。`test.rb` の `cache_classes`・`eager_load` も雛形に合わせる。RS の `config/application.rb` は、雛形どおり個別の require を `require "rails/all"` にする（読み込むフレームワークとミドルウェアは同じで、initializer の順番だけが変わる）。`db/schema.rb` の `ActiveRecord::Schema[6.1]` は採用し、`active_storage:update` が足すマイグレーションは採用しない（Active Storage は使っていない）
  - `X-XSS-Protection`、`button_to`、`stylesheet_link_tag` の `media` の変化（下の表の 5〜7）と、Cookie の鍵の算出方式（8）は、3 章の 2 の A（Rails の既定値への追随）にあたる。Cookie のローテーション用のコードは入れない（12 章）
  - コミットは段階ごとに、アプリごと（RS → RP → OP）に分ける。PR は 1 つ
  - 着手後に決めたこと: 「挙動を変えない」の定義（3 章の 2）。Rails の既定値への追随は、コミットの前に項目ごとに解説し、`docs/upgrade/defaults/` に記録する。ブラウザでの手動確認は、Cookie の鍵の算出方式（グループ 8）の前後を比べられる時点で 1 回行い、`load_defaults 7.0` の後は値の比較と自動の検査だけにした

`new_framework_defaults_7_0.rb` を有効にする順番:

| 順 | 設定 | 見込みの挙動 | 確かめ方 |
|---|---|---|---|
| 1 | `cookies_serializer`（RP・OP は既に `:json`）、`wrap_parameters_by_default`（initializer と同じ）、`remove_deprecated_time_with_zone_name`、`use_rfc4122_namespaced_uuids`、`smtp_timeout`、`active_storage.*` の 3 つ、`return_only_request_media_type_on_content_type`、`automatic_scope_inversing` | 変わらない（3 アプリとも該当の処理を通らないか、既に同じ値） | minitest・E2E |
| 2 | `verify_foreign_keys_for_fixtures`、`executor_around_test_case` | テストだけ | minitest |
| 3 | `partial_inserts = false`、`hash_digest_class = SHA256`、`disable_to_s_conversion`、`cache_format_version = 7.0` | INSERT の列だけ変わる（入る値は同じ）。ETag の計算とキャッシュは使っていない | minitest・E2E。RP は値で確かめる（下の「調べたこと」） |
| 4 | `raise_on_open_redirects` | 変わらない | OP の外部へのリダイレクトのテスト・E2E |
| 5 | `default_headers`（`X-XSS-Protection` が `1; mode=block` → `0`。3 アプリの全応答） | 変わる（Rails の既定値への追随） | 応答の前後比較 |
| 6 | `button_to_generates_button_tag`（OP の devise の `/users/edit` の「Cancel my account」） | 変わる（Rails の既定値への追随） | 応答の前後比較 |
| 7 | `apply_stylesheet_media_default = false`（OP の doorkeeper のレイアウトの `<link>` から `media="screen"` が消える。RP は `media: 'all'` を明示している） | 変わる（Rails の既定値への追随） | 応答の前後比較 |
| 8 | `key_generator_hash_digest_class = SHA256` | OP の既存のセッション Cookie が読めなくなる。RP のセッション Cookie は署名のない ID だけ、RS は Cookie を使わない | 手動確認（古い Cookie を持ったブラウザ） |

調べたこと（着手時の 2026-10-08。作業計画のときにサブエージェントで調べ、要点は自分で確かめた）:

| 項目 | 分かったこと |
|---|---|
| Rails 7.0 の版 | 最新は 7.0.10（2025-10-28。リリースノートは 7.0.9 を参照する形）。Ruby `>= 2.7.0`。1 つ前は 7.0.8.7（2024-12-10）。6.1 系の最新は 6.1.7.10 のまま |
| 7.0.8.7 → 7.0.10 | activesupport が `require "logger"` するようになった（rails/rails#54264）。activesupport が `base64`・`benchmark >= 0.3`・`bigdecimal`・`drb`・`logger >= 1.4.2`・`mutex_m`・`securerandom >= 0.3`、actionpack が `racc` を依存に足した。Ruby 3.1.7 の default gem は benchmark 0.2.0・securerandom 0.2.0・drb 2.1.0・mutex_m 0.1.1。racc は lock の 1.5.2 のまま |
| Rails 6.1 の非推奨警告 | 3 アプリの `log/development.log`・`log/test.log` に `DEPRECATION` の行はない。minitest は `:raise` で通る |
| zeitwerk:check | 着手前に 3 アプリとも `All is good!` |
| bundle の解決 | epic の lock のコピーで、Rails の構成 gem 以外を今の版に固定して解決させると、動くのは zeitwerk（2.4.2 → 2.6.18。railties 7.0 が `~> 2.5` を要求し、2.7 は Ruby 3.2 以上）と annotate（RP・OP。3.1.1 は `activerecord < 7.0`）だけ。sprockets・sprockets-rails は lock から消える |
| 固定しない場合 | Gemfile の rails を変えて `bundle lock` するだけで、`--conservative` を付けても globalid・marcel・mini_mime・date が動き、RP・OP では jwt 3.3.0・jbuilder 2.15.1・json 3.0.2、OP では devise 5.0.4・doorkeeper-openid_connect 1.10.1（doorkeeper 5.7 で discovery が壊れる版）になる |
| Rails 7.0 を必要とする周辺 gem | devise 4.9.4・doorkeeper 5.7.1・doorkeeper-openid_connect 1.8.9・jbuilder 2.13.0・activerecord-session_store 2.1.0・responders・web-console・dotenv-rails・omniauth 系は、今の版のまま Rails 7.0.10 で解決する |
| advisory | Rails 7.0 にすると actionpack の CVE-2024-54133 が解消する。Rails 7.0 系の advisory は 7.0.8.7 と 7.0.10 で同じで、6.1 にない advisory は増えない（ローカルの advisory DB は 2026-10-06） |
| Sprockets | 3 アプリとも `config/application.rb` の `require "sprockets/railtie"` がコメントアウトされていて、Sprockets は読み込まれていない。`sprockets-rails-3.2.2/lib/sprockets/rails.rb` は `Rails::Railtie` があると `sprockets/railtie` を require するので、Gemfile に足すと `Bundler.require` でアセットパイプラインが有効になる |
| annotate 3.2.0 | `activerecord >= 3.2, < 8.0`。3.1.1 からの差分で注釈の出力に関わるのは、改行を含むカラムコメント・空間型・globalize だけ。自動実行のフックはどちらも migrate・rollback 系だけで、E2E の `db:setup` では動かない。RP には rake タスクがない |
| RuboCop | `TargetRailsVersion: 7.0` にした設定を scratchpad に置いて 3 アプリを流すと、新しい指摘はない |
| development.rb の `file_watcher` | Rails 6.1 の雛形は `config.file_watcher = ActiveSupport::EventedFileUpdateChecker` を出すが、7.0 の development.rb と Gemfile の雛形には file_watcher の行も listen もない |
| `raise_on_open_redirects` | 判定はホスト名だけで、ポートは見ない。doorkeeper 5.7.1 は `allow_other_host: true` を渡す。omniauth のリダイレクトは Rack の 302。RP の `redirect_to` はパスだけ |
| RP の session_store の serializer | `rails_relying_party_of_backend/config/application.rb` の末尾の `ActiveRecord::SessionStore::Session.serializer = :json` が、`initialize!` より前に `ActiveRecord::Base` を読み込む。`new_framework_defaults_7_0.rb` に書いた AR::Base の設定は RP では効かず、`load_defaults 7.0` で効く見込み。後で、`disable_to_s_conversion` は `load_defaults 7.0` でも効かないと分かり、RP `77c26df` で設定を initializer の `ActiveSupport.on_load(:active_record)` に移した（[defaults/rails-7.0.md](defaults/rails-7.0.md) の「補足」） |
| backtrace_silencers.rb | `BACKTRACE` 環境変数の扱いは railties 7.0.10 にない。7.0 の雛形からは消えたが、この initializer は残す（Step 3 で見直す） |
| `app:update` | sprockets と test_unit の railtie を読み込んでいないので、Sprockets とテストの雛形は飛ばされる。`db/schema.rb` を `ActiveRecord::Schema[6.1].define` に書き換え、`active_storage:update` で Active Storage のマイグレーションを 3 本足す。7.0 の雛形から消えた `application_controller_renderer.rb`・`mime_types.rb`・`cookies_serializer.rb`・`wrap_parameters.rb`・`backtrace_silencers.rb` は消さない |

### Step 1-b: 起動の途中の読み込みの検出、応答のスナップショットのテストと、Rails 7.0 を必要とする周辺 gem

PR を 1-b-1（起動の途中の読み込みの検出）・1-b-2（応答のスナップショットのテスト）・1-b-3（周辺 gem）に分ける。1-b-1 と 1-b-2 を先に epic に入れ、1-b-3 で gem を上げたときに、gem が起動の途中に Rails の部品を読み込むようになれば CI で分かり、応答が変われば PR のスナップショットの差分で分かるようにする（人間が判断。経緯は LOG.md の Step 1-b-1・1-b-2）。当初は周辺 gem を 1-b-2 としていたが、1-b-2 の着手時に 1-b-3 に移した。

#### 1-b-1: 起動の途中の読み込みを CI で検出する

Step 1 で、RP の `config/application.rb` の serializer の設定が起動の途中で `ActiveRecord::Base` を読み込み、`new_framework_defaults_7_0.rb` の設定が黙って無視された（[defaults/rails-7.0.md](defaults/rails-7.0.md) の「補足」）。これを Step ごとの手作業ではなく、CI で毎回検出する。

- [x] 3 アプリの Gemfile の先頭に a-nti_manner_kick_course 0.5.0 を足す（RS → RP → OP の順に、gem だけのコミット）
- [x] CI の `rails` ジョブに、`ANTI_MANNER=1 bin/rails runner 1` を test と development で流すステップを足す
- [x] わざと壊して、検出されることを確かめる（確かめた後で戻した）
- [x] 検出できる範囲と、手で確かめる範囲（ほかの gem の initializer、`config/initializers`、`action_dispatch_request`）を 12 章・TIPS.md に書く
- 着手時の作業計画で決めたこと（人間が承認）
  - Gemfile: `ruby` の行の直後、`gem 'rails'` より前に `gem 'a-nti_manner_kick_course', groups: %i[development test]` と書く。`group :development, :test do ... end` のブロックにすると、既にある同じグループのブロックと重なり、RuboCop の `Bundler/DuplicatedGroup` の指摘になるため（`dotenv-rails` と同じ書き方）。版は Gemfile で固定せず、lock に任せる
  - CI: `zeitwerk:check` の後、minitest の前に、test と development の 2 ステップを足す（OP の署名鍵を作るステップより後）。`ANTI_MANNER` と `RAILS_ENV` はステップの `env` にだけ付ける。`ANTI_MANNER` があると gem が `eager_load!` の前で起動を終了コード 0 で終えるので、ジョブ全体に付けると minitest などが何も検査せずに成功するため
  - 壊すと落ちることは手元で確かめる（RS の `config/application.rb` で `ActiveRecord::Base` を参照、RP で Step 1 の前の serializer の設定に戻す、OP の initializer で `ActionController::Base` を参照）。検出できない範囲として、OP の initializer で `ActionDispatch::Request` を参照しても通ることも確かめる
  - 着手後に決めたこと: OP の initializer で `ActionController::Base` を参照しても検出されなかった（下の「検出できる範囲」）。gem はこのまま使い、検出できない範囲は手で確かめる（人間が判断。自前の検査を足す案は採らなかった。経緯は LOG.md の Step 1-b-1）
  - 外す時期: Rails 8.2 以上（今回の目標の外）。epic の間は残す（7 章）

調べたこと（着手時の 2026-10-09）:

| 項目 | 分かったこと |
|---|---|
| 版 | 0.5.0（2026-01-04）が最新。`.gem` は 8,704 バイト。依存は `activesupport >= 7.0.0`・`railties >= 7.0.0`。MIT |
| gem 名と読み込み | gem 名は `a-nti_manner_kick_course`、lib は `a/nti_manner_kick_course.rb`。Bundler.require は名前の `-` を `/` にしたファイルを読む。Gemfile の順に require するので、先頭に置けば `require "rails/all"` の後、アプリのほかの gem より先に読まれる |
| 動き | require された時点で、環境変数 `ANTI_MANNER` があれば、監視する部品の `ActiveSupport.on_load` にフックを仕込む。initializer `anti_manner`（`before: :eager_load!`。走る位置は下の「検出できる範囲」）まで何も走らなければ「✅Congratulations!」を出して終了コード 0 で `exit` し、その前にフックが走れば、疑わしい行を出して終了コード 1 で止まる（`ANTI_MANNER_DEBUG=1` でスタックトレース全部）。環境変数がなければ Railtie を足すだけで何もしない。Rails 7.1 以下は `rails runner 1` で起動する（README） |
| 監視する部品 | `action_controller`・`active_record`・`action_view`・`active_job`・`action_mailer` など 39 個。`action_dispatch_request` は含まない（`action_dispatch_response`・`action_dispatch_integration_test` は含む）。そのため、RP の activerecord-session_store と、RP・OP の development の web-console による `ActionDispatch::Request` の早い読み込み（[IMPROVEMENTS.md](../IMPROVEMENTS.md) の IMP-009）は検出できない |
| Rails 8.2 の Load hook guard | rails/rails#56201（2026-02-11 に main へ）は当初 `action_dispatch_request` も監視したが、rails/rails#56901（2026-02-27）で外れた（production では routes を読むときに初期化の途中で読み込まれるため）。既定は警告だけ（`:log`）で、`eager_load` が true のときは見ない。railties の最新は 8.1.4 で、8.2 は出ていない |
| 検出できる範囲（作業の途中で分かった） | initializer `anti_manner` には `before: :eager_load!` しか指定がないので、Railtie の読み込みの順（Gemfile の先頭）の位置、つまり Rails の各フレームワークの initializer の直後で検査を終える。OP の test では 217 個中 103 番目で、アプリの `load_config_initializers` は 150 番目、`eager_load!` は 211 番目。検出できるのは `config/application.rb`、`Bundler.require` で gem を require するとき、`config/environments/*.rb`、Rails 自身の initializer。ほかの gem の initializer（web-console・devise・doorkeeper など）と `config/initializers/*.rb` は検出できない。Gemfile の末尾に置いても、アプリの `config/initializers` より前に終える点は変わらず、ほかの gem の require を見られなくなる |
| RuboCop | `Bundler/DuplicatedGroup` は `group` のブロックを数え、`gem` の `groups:` は数えない。`Bundler/OrderedGems` は `-`・`_` を無視して並べ、コメントで区切る |

#### 1-b-2: 3 アプリの応答のスナップショットのテスト

Step 1 では、3 アプリの主な応答（ステータス・ヘッダー・本文）を使い捨ての統合テストで書き出し、前後で diff して Rails の既定値への追随（DEF-7.0-15・33〜35）を見つけた。この比べ方を、毎回の minitest と CI で流れるスナップショットのテストにする。PR のスナップショットの差分を、既定値への追随の解説の根拠にし、1-b-3（doorkeeper 5.8 で `Pragma` が戻るなど）や仕上げの Dependabot の更新でも変化に気づけるようにするため。アプリのコードと設定は変えない。

- [x] 3 アプリに `test/integration/response_snapshot_test.rb`（1 テスト 1 応答。OP は RuboCop の `Metrics/ClassLength` のため、領域ごとに `response_snapshot_<領域>_test.rb` の 4 つに分けた）、伏せる処理の `test/support/response_snapshot_helper.rb`（3 アプリで同じ内容）、スナップショットの `test/snapshots/responses/<名前>.txt` を足す（RS → RP → OP の順に、アプリごとのコミット）
- [x] 実行ごとに同じになること（seed を変えて 2 回、`CI=1`）と、わざと壊すと落ちることを確かめる（確かめた後で戻す）
- [x] 更新の方法と扱いを TIPS.md・CLAUDE.md に書く
- 着手時の作業計画で決めたこと（人間が承認）
  - 番号: この作業を 1-b-2 とし、周辺 gem を 1-b-3 に移す。ブランチは `upgrade/step1b-response-snapshot`
  - 対象の応答: Step 1 の書き出し（OP 20・RP 5・RS 2）に足して、RS 3・RP 11・OP 26。足すのは、RS の introspect が `active: false` の 401、RP の introspection 用の画面・認可要求・コールバック・コールバックの後の画面・ID トークンの検証に失敗したコールバック・`/auth/failure`、OP のログイン成功・`/users/sign_up`・クライアントクレデンシャルのトークン・revoke の後の introspect・同意画面を省く認可要求・`/oauth/applications`。`/oauth/authorized_applications`（fixtures の作成時刻を表示する）と `/oauth/applications/:id`（client secret を表示する）、使っていない経路は足さない
  - 時刻は各テストで `travel_to` で固定し、時刻の値（`created_at`・`iat`・`exp`）も伏せずに比べる
  - ヘッダーは名前を小文字にして並べ替える。値は比べ、`X-Request-Id`・`X-Runtime` と、本文から決まる `ETag`・`Content-Length` は値だけを伏せる（ヘッダーがあるかどうかは比べる）。`Set-Cookie` は名前と属性を比べ、値だけを伏せる
  - 伏せる値は、ヘッダー名・クエリのパラメーター名（`code`・`state`・`nonce`・`code_challenge`）・hidden field の名前・JSON のキー（`access_token`・`refresh_token`・`id_token`、JWKS の `n`・`kid`）で決める。文字列の形では伏せない。`client_id`・ユーザー ID（fixtures で決まる）・`expires_in` は伏せない
  - JSON の本文は、キーの順を変えずに整形する（E2E のスナップショットはキーを並べ替える）。伏せた値は E2E と同じく型を残す（`<ACCESS_TOKEN:string>`）
  - 更新は `UPDATE_SNAPSHOTS=1 bin/rails test`。ファイルがないときは、この環境変数がなければ失敗する（E2E の扱いにそろえる）。更新したときの扱いは 3 章の 2 の境目の 8
  - development だけの応答の差（`Server-Timing`、rack-mini-profiler・web-console）と、test 環境では出ない CSRF のトークンは、このテストでも E2E でも扱わない。Rails を上げる Step で、これまでどおり development の応答ヘッダーを `curl` で見る
  - CI は変えない（既存の `bin/rails test` がこのテストも流し、スナップショットのファイルは `public-safety` ジョブの検査の対象に入る）。コードレビューの後に、3 アプリのヘルパーが同じかを `diff` で比べるステップを `rails` ジョブに足した（人間が判断）
  - PR は 1 つ

調べたこと（着手時の 2026-10-09）:

| 項目 | 分かったこと |
|---|---|
| Step 1 の書き出しの道具 | 1 テストで全応答を順に書き出す形。正規表現で伏せ、`client_id`・`sub`・`iat`・`exp`・`created_at` まで伏せていた。ETag も伏せていた |
| test 環境の CSRF | `allow_forgery_protection = false` なので、`csrf_meta_tags` も `authenticity_token` も出ない |
| 時刻 | 使い捨てのテストで `travel_to` で時刻を固定すると、トークン応答の `created_at`、introspect の `exp`・`iat`、ID トークンの `iat`・`exp` は 2 回流して同じだった |
| ユーザー ID・client_id | fixtures の ID はラベルから決まり、2 回流して同じ。client_id は fixtures と `.env.test` の固定のダミー |
| 実行ごとに変わる値 | OP: doorkeeper が作るトークン・認可コード、JWKS の `n`・`kid`（署名鍵は手元と CI で違う）、ID トークン。RP: omniauth が作る `state`・`nonce`・`code_challenge`。共通: Cookie の値、`X-Request-Id`、`X-Runtime`。fixtures の `created_at` は `travel_to` の前に入るので実時刻（`/oauth/authorized_applications` が表示する） |
| 安全チェック | `oauth-param` ルールはキー名と 8 文字以上の値で検出し、`<ACCESS_TOKEN>` のような山かっこの置き換えは検出しない。HTML の hidden field の値は検出しない |
| CI | `rails` ジョブが各アプリで `bin/rails test`（`CI=true` で eager load）を流し、`public-safety` ジョブが追跡中の全ファイルを検査する |
| E2E のスナップショット | `e2e/baseline/*.json`。JSON のキーを並べ替え、伏せた値は型を残す。ないときは黙って作らず、更新は `npx playwright test --update-snapshots` |

#### 1-b-3: Rails 7.0 を必要とする周辺 gem

1-b-2 が epic に入ってから調べ、作業計画を出して承認を得た（2026-10-09）。PR を 1-b-3-1（RP の gem・jbuilder・devise）と 1-b-3-2（doorkeeper 系）に分ける。経緯と作業の記録は LOG.md の Step 1-b-3-1。gem の既定値・雛形への追随は [defaults/rails-7.0.md](defaults/rails-7.0.md) の「周辺 gem（Step 1-b-3）」（DEF-7.0-38 から）。

1-b-3-1（ブランチ `upgrade/step1b-rails70-gems`）:

- [x] PLAN.md 13 章（スキル化の計画）を、Step 1 の振り返りに合わせて見直す（人間が承認）
- [x] `scripts/check-apps`（3 アプリの検査と E2E をまとめて流す。13 章の 5）
- [x] 先にテストを足す（RP: セッションの JSON の escape、CSRF のトークンのないログインの POST。OP: ユーザー登録・編集の失敗と成功の応答のスナップショット 4 つ、登録でユーザーが増えること、パスワードを変えた後もログインしたままなこと）
- [x] jbuilder 2.13.0 → 2.15.1（RP → OP）
- [x] activerecord-session_store 2.1.0 → 2.2.0（RP。DEF-7.0-38）
- [x] omniauth-rails_csrf_protection 1.0.0 → 1.0.2（RP。一時固定）
- [x] devise 4.9.4 → 5.0.4（OP。DEF-7.0-39〜41）。無視リストから advisory 2 件を消した
- [x] OP の `config/initializers/devise.rb` を devise 5.0.4 の雛形に合わせる（DEF-7.0-42。失敗の応答が 422、リダイレクトが 303）
- [x] ブラウザで手動確認（devise を上げた後に 1 回）

1-b-3-2（ブランチ `upgrade/step1b-doorkeeper`。1-b-3-1 が epic に入ってから始める）:

- [x] 先にテストを足す（下の「1-b-3-2 の着手時の作業計画で決めたこと」の表）
- [x] doorkeeper-openid_connect 1.8.9 → 1.8.11（一時固定。ostruct は 0.5.2 に一時固定）→ doorkeeper 5.7.1 → 5.8.2 → doorkeeper-openid_connect 1.10.1 → doorkeeper 5.9.9（どの段も 1 gem だけを動かした）。GHSA-h5m9-42h9-vcq6 を解消した
- [x] OP・RP・RS の間のやり取りが変わるもの（下の「B の候補」の表）は B として段ごとに止まって確かめ、設定で戻せないものは「意図的な仕様変更」にする（下の「1-b-3-2 の意図的な仕様変更」）
- [x] 応答のスナップショットのヘルパーで、JSON として読めない本文をテキストとして扱う（3 アプリ。作業の途中で人間が承認）
- [x] doorkeeper・doorkeeper-openid_connect の initializer を、上げた版の雛形に合わせる（独自の設定は残す。DEF-7.0-43・44）
- [x] doorkeeper・doorkeeper-openid_connect のロケールと、上書きしているビューを雛形に合わせる（IMP-008。nonce の hidden field は残す。DEF-7.0-45〜47）
- [x] `response_mode=form_post` で拒否したときに OP のビューが落ちるか（調査での推測）を確かめる（着手時。5.7.1 でも落ちる元からの挙動。下の表）
- [x] ブラウザで手動確認（雛形に合わせた後に、introspection の流れまで 1 回）

1-b-3-2 の意図的な仕様変更（設定では戻せない。段ごとに人間が承認。経緯と確かめ方は LOG.md の Step 1-b-3-2「意図的な仕様変更」）:

- 認可要求の `max_age=0` で再認証する（doorkeeper-openid_connect 1.8.11）
- トークン要求の成功の応答に `Pragma: no-cache` が戻る（doorkeeper 5.8.0。0-f-3 では消えたことを記録だけにしていた）
- 認証のない introspect の `error_description` が `request_not_authorized` の文言になる（doorkeeper 5.8.0）
- userinfo の JSON のキーの順が `email, sub` になる（doorkeeper-openid_connect 1.10.0）
- Webfinger が落ちずに、issuer を `href` にした 200 を返す（doorkeeper-openid_connect 1.10.0）
- `prompt=select_account` が `account_selection_required`、`prompt=none` と `max_age` が `login_required` のエラーになる（doorkeeper-openid_connect 1.10.0）
- introspect のキーの順が `iat, exp` になる（doorkeeper 5.9.1）
- クライアント認証を 2 重に使うトークン要求を 400、トークンを 2 つの方法で渡す要求を 401 で拒む（doorkeeper 5.9.5〜5.9.7）
- scope の足りないトークンの 403 に `insufficient_scope` の `WWW-Authenticate` が付く（doorkeeper 5.9.1）
- `response_mode=form_post` で拒否すると、落ちずに `error=access_denied` を POST するフォームを返す（ビューを雛形に合わせた）

着手時の作業計画で決めたこと（人間が承認）:

- 上げる先は、Ruby 3.1.7・Rails 7.0.10 で使える最新の版（0-f と同じ方針）
- omniauth-rails_csrf_protection は、Gemfile に版の制約がないと 2.0.1 に解決されるので、1.0.2 に一時固定する（2.x は Step 7。7 章）
- doorkeeper は、GHSA-h5m9-42h9-vcq6（revoke の認可の不備。`< 5.9.1`）を直すため 5.9.x まで上げる。この advisory は ruby-advisory-db にないので、bundler-audit は検出しない
- doorkeeper-openid_connect は 1.9.0（CVE-2026-44476）を飛ばして 1.10.1 にする。1.10.2 以上は Ruby 3.2 以上が必要（Step 2 の後）
- activerecord-session_store 2.2.0 で DB に入る JSON の文字列が変わる（読み戻す値は同じ）のは、3 章の 2 の A として扱う（DEF-7.0-38）
- gem の generator の雛形（initializer、ロケール、上書きしているビュー）にも追随する（3 章の 2 の境目の 1。作業計画への返事で人間が決めた）。doorkeeper のロケールとビューを合わせるため、IMP-008 を 1-b-3-2 で行う
- 手動確認は、1-b-3-1 で devise を上げた後に 1 回、1-b-3-2 で doorkeeper 5.9.9 の後に 1 回

調べたこと（着手時の 2026-10-09。サブエージェント 3 つで調べ、要点は自分で確かめた）:

| 対象 | 分かったこと |
|---|---|
| 版 | jbuilder 2.15.1（2026-05-26。2.14 以上は Rails 7.0 以上）、activerecord-session_store 2.2.0（2.3.0 は Rails 7.1 以上）、omniauth-rails_csrf_protection 1.0.2（2024-05-10）、devise 5.0.4（2026-05-08。`railties >= 7.0`）、doorkeeper 5.8.2（2025-04-04）・5.9.9（2026-09-24）、doorkeeper-openid_connect 1.8.11（`doorkeeper < 5.9`、`ostruct >= 0.5`）・1.10.1（`doorkeeper < 6.0`、Ruby 3.1 で使える最新）。doorkeeper 5.9.1 は `rails db:seed` で NameError（5.9.2 で修正）、5.9.7 は解析できない本文で ParseError（5.9.9 で修正）、5.9.4・5.9.8 は公開されていない |
| lock の解決 | `bundle lock --update <gem> --conservative --print` で、jbuilder・devise・omniauth-rails_csrf_protection はその gem だけが動き、activerecord-session_store は multi_json 1.15.0 が lock から消える。doorkeeper-openid_connect を固定せずに上げると 1.10.1 になり、doorkeeper 5.7.1 のままでは discovery が壊れる。doorkeeper だけを上げても、1.8.9 が `< 5.8` なので動かない。lock の default gem（json・bigdecimal・logger・base64・cgi）と jwt 2.10.3 は、どの試行でも動かない |
| ostruct | doorkeeper-openid_connect 1.8.11 以上の依存。Ruby 3.1.7 の default gem は 0.5.2。固定しないと 0.6.3 が入る |
| devise 5 | 応答のステータスの既定値は 200・302 のまま（新しいアプリの雛形だけが 422・303）。ビューの `<br>` が `<p>` に、`_error_messages` の `data-turbo-cache` が `data-turbo-temporary` に、ログイン失敗の文言が `Invalid email or password.` になる。OP が使っていない機能の変更（`Devise.secret_key` の求め方、削除された API、ログインしていないときの HTML 以外のログアウトの 401）は影響しない。responders・warden・bcrypt は動かない |
| activerecord-session_store 2.2.0 | `JsonSerializer` が `MultiJson` から Ruby 標準の `JSON` になり、Active Support の JSON の encoder を通らない（`<>&` を escape しない）。serializer の設定の方法、テーブル、`ActionDispatch::Request` を `Bundler.require` の時点で読み込むこと（IMP-009）は変わらない |
| jbuilder 2.15 | Railtie が `on_load(:action_controller_api)` を使う。OP では doorkeeper の `ActionController::API` のコントローラーで走るが、応答は変わらない。RP・OP に `.jbuilder` のテンプレートはない |
| omniauth-rails_csrf_protection 1.0.2 | TokenVerifier のスレッドの競合の修正だけ。トークンの確かめ方は同じ |
| doorkeeper 5.8〜5.9.9 | トークン応答に `Pragma: no-cache` が戻る（5.8.0 #1712）。認証のない introspect の `error_description` が `request_not_authorized` の文言になる（5.8.0 #1715）。クライアント認証を 2 つ同時に使う要求・Basic と `client_id` が別のクライアントを指す要求・トークンを 2 つの方法で渡す要求を拒む（5.9.5〜5.9.7）。拒否のときに client・redirect_uri を検証し、script スキームの redirect_uri を拒む（5.9.9）。`pkce_code_challenge_methods` などの新しい設定は既定値で今と同じ。必須のマイグレーションはない（public クライアント用の任意のものは採用しない）。5.9.1（#1784）でロケールの項目名の末尾のコロンを文言に移し、ビューの `:` を消した |
| doorkeeper-openid_connect 1.10 | userinfo の JSON のキーの並びが、独自の claim の後に `sub` になる（#273。`sub` を上書きさせないため）。Webfinger の `href` が `root_url`（末尾に `/`）から `issuer` になる（#250）。`prompt=select_account` がエラーになり（#279）、`prompt=none` と `max_age` の扱いが変わる（#275）。RP はどちらも送らない |
| 上書きしているビュー | 5.9.9 でも、コントローラーがインスタンス変数（`@pre_auth`・`@authorize_response`）を入れるので、今のビューで動く |
| テストで守られていない挙動（1-b-3-2 で先に足す） | Webfinger、クライアント認証の 2 重、トークンの 2 重の渡し方 |

1-b-3-2 の着手時に確かめ直したこと（2026-10-09。サブエージェント 3 つで gem のタグのソース・CHANGELOG とアプリの使い方を調べ、要点は自分でソースと手元の実行で確かめた）:

| 項目 | 分かったこと |
|---|---|
| 版 | 上の表と同じ。doorkeeper 5.9.9 は公開から 15 日。これより新しいのは doorkeeper 6.0.0.rc1・rc2（プレリリース。Ruby 3.2 以上）と doorkeeper-openid_connect 1.10.2〜1.10.5・2.0.0（Ruby 3.2 以上）だけ。`.gem` のサイズは doorkeeper-openid_connect 1.8.11 が 24,576 B、1.10.1 が 38,400 B、doorkeeper 5.8.2 が 109,056 B、5.9.9 が 119,808 B |
| advisory | GHSA-h5m9-42h9-vcq6 は doorkeeper のリポジトリの advisory にだけあり、ruby-advisory-db（上流の 2026-10-08 まで）にも GitHub の Advisory Database にもない。新しく GHSA-8r7r-wh7x-27ff（CVE-2026-70665。doorkeeper-openid_connect `<= 1.10.3`、修正版 1.10.4 は Ruby 3.2 以上）が出ていた。Dynamic Client Registration（DCR）の endpoint が scope を検証しない件で、これもリポジトリの advisory にだけある。DCR は既定で無効（`dynamic_client_registration` の既定値は false で、ルートもそのときだけ足す）で、OP は有効にしていないので影響しない |
| lock の解決 | lock のコピーで、①Gemfile に doorkeeper-openid_connect 1.8.11 と ostruct 0.5.2 を書いて `bundle lock` → 外して `bundle lock --local` ②③④ `bundle lock --update <gem> --conservative` を順に試すと、どの段も 1 gem だけが動き（②doorkeeper 5.8.2、③doorkeeper-openid_connect 1.10.1、④doorkeeper 5.9.9）、ostruct は 0.5.2 のまま、ほかの gem は動かない |
| マイグレーション | doorkeeper 5.8.0 で増えた雛形（`oauth_applications.secret` の NOT NULL を外す）は public クライアント用の任意のもの。5.9.9 のコードは新しい列を要らない。doorkeeper-openid_connect は 1.10.1 までマイグレーションの雛形が変わらない |
| RP・RS の送り方 | RP・RS・E2E はクライアント認証を本文だけで送る（oauth2 2.0.25 の `auth_scheme: :request_body` は Authorization ヘッダーを付けない）。トークンは 1 つの方法だけで渡す（userinfo は Bearer ヘッダー、RS の introspect は Bearer ヘッダーと本文の `token`）。RP は `prompt`・`max_age`・`response_mode` を送らない |
| Webfinger | OP の routes に `root` がないので、doorkeeper-openid_connect 1.8.9 では `NoMethodError`（`root_url`）で落ちる（test 環境で確かめた）。1.10.0（#250）で `href` が issuer になり、200 を返すようになる見込み |
| form_post で拒否 | 調査での推測は正しいが、5.7.1 でも既に落ちる元からの挙動。`doorkeeper-5.7.1/app/controllers/doorkeeper/authorizations_controller.rb` の `destroy` → `redirect_or_render` はローカル変数 `auth` を渡して `form_post` を描くが、上書きしているビューは `@authorize_response` を読み、拒否の経路では誰も入れない（doorkeeper-openid_connect の `handle_oidc_error!` は `new` のときだけ）。5.9.9 まで同じ。ビューを雛形（`auth.body`）に合わせると直る |
| 起動の途中の読み込み | doorkeeper 5.9.1（#1804）〜5.9.2（#1830）で、モデルの読み込みが `to_prepare` の `constantize` から、Mixin の `included` での遅延の読み込みに変わる。doorkeeper-openid_connect 1.10.0（#241）は `run_hooks` を `on_load(:active_record)` で包む。doorkeeper 5.9.1（#1802）は filter_parameters の追加を `to_prepare` に移す |
| ロケール | OP の `config/locales/doorkeeper.en.yml` は 5.7.1 の gem の `en.yml` から `forbidden_token` を除いたもの。5.9.9 の `en.yml` とは、`:` がロケール側に移った項目（5.9.1 #1784）、文言の直し（`not_match_configured`・`blank_redirect_uri`・`request_not_authorized`・`invalid_redirect_uri`）、PKCE のエラーの複数形、増えた項目（`invalid_code_challenge`・`multiple_client_auth_methods`・`forbidden_token`）が違う。`doorkeeper_openid_connect.en.yml` は 1.10.1 で 3 項目が増える |

1-b-3-2 で B の候補になる変化（どれも設定では戻せない。段ごとに止まって確かめる）:

| 段 | 変化 | 出典 |
|---|---|---|
| doorkeeper 5.8.2 | トークン要求の成功の応答に `Pragma: no-cache` が戻る | 5.8.0 #1712 |
| doorkeeper 5.8.2 | 認証のない introspect の `error_description` が `unknown` の文言から `request_not_authorized` の文言になる（ステータスは 400 のまま） | 5.8.0 #1715（5.7.1 は reader が private で、`try` が nil を返していた） |
| doorkeeper-openid_connect 1.8.11 | `max_age=0` で再認証する。`max_age` を `prompt` より先に処理する | 1.8.11 #222・#224 |
| doorkeeper-openid_connect 1.10.1 | userinfo の JSON のキーの順が `sub, email` から `email, sub` になる | 1.10.0 #273 |
| doorkeeper-openid_connect 1.10.1 | Webfinger が落ちなくなり、`href` が issuer の 200 を返す | 1.10.0 #250 |
| doorkeeper-openid_connect 1.10.1 | `prompt=select_account` が `account_selection_required` のエラーになる（OP のブロックは空）。`prompt=none` と `max_age` で `login_required` になる | 1.10.0 #279・#275 |
| doorkeeper 5.9.9 | introspect の本文のキーの順が `exp, iat` から `iat, exp` になる | 5.9.1 #1818 |
| doorkeeper 5.9.9 | クライアント認証を 2 重に使う要求（Basic と本文の両方に secret、Basic と別の `client_id`）を 400 `invalid_request` で拒む。トークンを 2 つの方法で渡すと、トークンがないものとして扱う | 5.9.5〜5.9.7 |
| doorkeeper 5.9.9 | トークンの scope が足りない 403 の `error` が `insufficient_scope` になり、`WWW-Authenticate` が付く | 5.9.1 #1795 |
| doorkeeper 5.9.9 | 拒否のときに client・redirect_uri を確かめ、script スキームの redirect_uri を拒む | 5.9.9 |
| 雛形への追随 | form_post で拒否すると、落ちずに `error=access_denied` を POST するフォームを返す | 上の「form_post で拒否」 |

1-b-3-2 の着手時の作業計画で決めたこと（人間が承認）:

- 版・順番・一時固定は上の「着手時の作業計画で決めたこと」のまま。GHSA-8r7r-wh7x-27ff は DCR を使っていないので影響しない。1.10.4 以上は Step 2 の後（7 章）
- 先に足すテスト（OP。今の挙動を記録する）

  | テスト | 今の挙動 |
  |---|---|
  | トークン要求を Basic だけで | 200 |
  | Basic と本文の両方に同じクライアントの secret | 200（Basic を使う） |
  | Basic と本文で別の `client_id` | 200（Basic を使う） |
  | userinfo を `access_token` 引数だけで | 200 |
  | userinfo を Bearer ヘッダーと `access_token` 引数の両方で | 200 |
  | userinfo を `openid` のないトークンで | 403 |
  | 認可要求の `prompt=select_account`、`prompt=none` と `max_age`、`max_age=0` | 同意画面・ログイン画面へのリダイレクト・同意画面 |
  | Webfinger | `NoMethodError`（test 環境は例外を投げる） |
  | `response_mode=form_post` で拒否 | `NoMethodError` |

- gem の雛形への追随は、gem をすべて上げた後に、initializer（doorkeeper・doorkeeper-openid_connect）→ ロケールとビュー（`:` がロケールとビューの間を動くので 1 コミット）の順に行う。独自の設定と、nonce の hidden field は残す。雛形と同じになるビューも、generator が出すものなので消さない
- public クライアント用のマイグレーションは採用しない（DEF に「採用しない」で残す）
- 手動確認は、雛形に合わせた後に 1 回（introspection の流れまで）
- ダウンロードは doorkeeper-openid_connect 1.8.11・1.10.1、doorkeeper 5.8.2・5.9.9（サイズは上の表）。ostruct 0.5.2 は default gem なので落とさない見込み

### Step 2: Ruby 3.2

「8. 各 Step 共通の手順」の 4 に従い、Rails 7.0.10 のまま Ruby を 3.1.7 から 3.2.11 に上げる。Ruby だけを上げる最初の Step。着手時の作業計画で決めたこと（人間が承認。経緯は LOG.md の Step 2）:

- [x] Ruby 3.1.7 → 3.2.11（RS → RP → OP の順に、アプリごとのコミット）。`.ruby-version`・Gemfile の `ruby`・lock の `RUBY VERSION`・`BUNDLED WITH`（2.4.19）と、lock の default gem を同じコミットで合わせ直す
- [x] ci.yml の `runs-on` のコメントを、ランナーを固定する理由に直す（ランナーは ubuntu-24.04 のまま）
- [x] ブラウザで手動確認（3 アプリの Ruby を上げた後に、introspection の流れまで 1 回）
- [x] RuboCop の `TargetRubyVersion` を 3.2 にする（新しい指摘なし）
- [x] nokogiri 1.18.10 → 1.19.4（RS → RP → OP）。無視リストから nokogiri の advisory 12 件を消す
- 決めたこと
  - 版は 3.2 系の最新の 3.2.11。3.2 は EOL だが、マイナーを飛ばさない（3 章の 1）
  - lock の default gem は、3.2.11 の default gem の版に合わせ直す（json 2.6.3・bigdecimal 3.1.3・logger 1.5.3・drb 2.1.1・mutex_m 0.1.2、OP の ostruct 0.5.5）。base64 0.1.1・cgi 0.3.7・ruby2_keywords 0.0.5 は 3.2.11 でも同じ版。benchmark・securerandom は 0.3.0 のまま（3.2.11 の default gem の 0.2.1・0.2.2 は activesupport 7.0.10 の `>= 0.3` を満たさない）。合わせ直さないと、旧版の gem を rubygems から落としてビルドすることになるので、Ruby を上げるコミットに入れる
  - `BUNDLED WITH` は 3.2.11 の Bundler（2.4.19）にする。2.3.27 のままだと、Bundler 2.4.19 と setup-ruby が bundler 2.3.27 を落として使う。Step 0-a で Ruby に付属の Bundler の版になったのと同じ扱い
  - gem は `vendor/bundle/ruby/3.2.0` に入れ直しになる。今のキャッシュ（`vendor/bundle/ruby/3.1.0/cache` の `.gem`）を `ruby/3.2.0/cache` にコピーして `bundle install --local` にし、gem のダウンロードを避ける
  - Step 2 の PR に入れるのは、Ruby・`TargetRubyVersion`・nokogiri だけ。nokogiri は advisory の修正（3 章の 3）で、Ruby を上げるコミットとは分ける
  - ほかの Ruby 3.2 以上を必要とする gem（doorkeeper-openid_connect 1.10.5、byebug 13、rack-mini-profiler 5、simplecov 1.2、zeitwerk 2.7 以上、brakeman 8）は、サブステップ 2-b として別の PR にする。Step 2 が epic に入ってから調べて作業計画を出す（1-b-3 と同じ形）。スキル化（13 章）は 2-b の後
  - CVE-2026-41316（erb）は、この Step では gem を足さずに記録し、扱いを記録と一緒に人間と決める（下の「調べたこと」の erb の行。決めた内容は次の「着手後に決めたこと」）
  - 着手後に決めたこと（人間が承認）: gem の入れ直しは `bundle install --local --no-cache` にする（`--no-cache` がないと、キャッシュにない default gem の `.gem` を rubygems.org から落とす。RS・RP で起きた。LOG.md の Step 2「遭遇した問題」）。CVE-2026-41316 は、3 アプリに信頼できないデータを `Marshal.load` する経路がないので記録だけにし、default gem の erb が修正版になる Step 4（Ruby 3.3.12 の erb は 4.0.3.1）で解消を確かめる（7 章の erb の行）
  - 手動確認は、3 アプリの Ruby を上げた後に 1 回（introspection の流れまで）

調べたこと（着手時の 2026-10-10。サブエージェント 3 つで調べ、要点は自分で確かめた）:

| 項目 | 分かったこと |
|---|---|
| 版 | 3.2 系の最新は 3.2.11（2026-03-27）。3.2.10 は 2026-01-14。3.2.11 の告知は 3.2 の最後のリリースと明記し、3.2 は EOL（ruby-lang.org の branches のページでは 2026-04-01）。`ruby-3.2.11.tar.gz` は 19,984,344 B |
| mise | mise 2026.5.10 は既定で ruby-build でソースからビルドする（precompiled が既定になるのは 2026.8.0 から）。手元の ruby-build 20260924 は 3.2.11 の定義を持ち、Homebrew の openssl@3・libyaml があれば OpenSSL のソースを落とさない。手元の Ruby 3.2.3 には別に入れた Bundler 4.0.6 があり、素の `bundle` が 4.0.6 で動くので、試行には使わない |
| CI | `ruby/setup-ruby` v1.325.0（固定中のコミット）の `ruby-builder-versions.json` に 3.2.11 がある。ruby-builder に `ruby-3.2.11-ubuntu-24.04-x64.tar.gz` があり、ubuntu-26.04 版もある。setup-ruby は lock の `BUNDLED WITH` の版を `gem install` する |
| Bundler | 3.2.11 の default は Bundler 2.4.19・RubyGems 3.4.19。lock の `BUNDLED WITH` が実行中の版と違うと、`bundle install` は lock の版を落として切り替える（Bundler 2.3.0 から。`BUNDLER_VERSION` を付けると切り替えない） |
| default gem（3.1.7 → 3.2.11） | json 2.6.1→2.6.3、bigdecimal 3.1.1→3.1.3（default gem のまま）、logger 1.5.0→1.5.3、ostruct 0.5.2→0.5.5、drb 2.1.0→2.1.1（ruby2_keywords に依存したまま）、mutex_m 0.1.1→0.1.2、benchmark 0.2.0→0.2.1、securerandom 0.2.0→0.2.2、net-http 0.3.0.1→0.4.1、uri 0.12.4→0.12.5、erb 2.2.3→4.0.2、psych 4.0.4→5.0.1。base64・cgi・ruby2_keywords は同じ |
| lock の解決 | lock のコピーで、Ruby 3.2.11・Bundler 2.4.19 の下で、Gemfile の `ruby` を変えて default gem を固定して `bundle lock` → 固定を外して `bundle lock --local` すると、3 アプリとも動くのは default gem の 5 つ（OP は ostruct も）と `RUBY VERSION`（`ruby 3.2.11p268`）・`BUNDLED WITH`（2.4.19）だけ。`PLATFORMS` は変わらない。続けて `bundle lock --update nokogiri --conservative` を試すと、nokogiri の 3 つのプラットフォームの行だけが 1.19.4 になる |
| 3.2 で動かない gem | lock の全 124 項目（3 アプリの和）で、required_ruby_version が 3.2.11 を外すものはない（nokogiri 1.18.10 は `< 3.5.dev`、sqlite3 1.7.3 は `< 3.4.dev`）。nokogiri・sqlite3 の arm64-darwin 版は 3.2 のバイナリを含む。x86_64 版は rubygems.org の情報だけ |
| ソースからビルドする gem | bootsnap・byebug・date・msgpack・nio4r・prism・puma・racc・websocket-driver（3 アプリ）、bindex（RP・OP）、bcrypt（OP） |
| 消えた API | Ruby 3.2 で `File.exists?`・`Dir.exists?`・`Kernel#=~`・`taint` 系・`Fixnum`・`Bignum`・`Random::DEFAULT` などが消えた（NEWS for 3.2.0）。アプリ（app・lib・config・test・db・bin、scripts、e2e/scripts）にはない。gem の該当箇所（tzinfo 2.0.4・bootsnap の `untaint`、hashie・msgpack の `Fixnum` など）は版の判定で守られている。gem の中の `Kernel#=~` は grep では探せないので、テストで確かめる |
| RuboCop | `TargetRubyVersion: 3.2` にした設定のコピーで 3 アプリを流すと、新しい指摘はない（3.2 でだけ通る構文のファイルで、設定が効くことを確かめた） |
| brakeman | 7.1.1 は Ruby 3.2 の EOL を 2026-03-31 として持つ。fingerprint にメッセージは含まれないので、無視リストの EOLRuby の項目に当たり続ける見込み |
| Ruby の版に依存する箇所 | `.ruby-version`・Gemfile の `ruby`・lock（3 アプリ）、`.rubocop.yml` の `TargetRubyVersion`、ci.yml のコメント、TIPS.md の `mise where ruby@3.1.7`。`mise.toml`・`.claude/launch.json`・`e2e/scripts/start-server.sh` は版を持たない |
| nokogiri 1.19.4 | 2026-06-18。Ruby `>= 3.2`。無視リストの nokogiri の 12 件は 1.19.1〜1.19.4 で直る。1.19.0 は対応する Ruby の変更だけ。arm64-darwin の `.gem` は 6,547,456 B |
| erb（CVE-2026-41316） | 2026-04-21 公表。erb `<= 6.0.3` で、信頼できないデータを `Marshal.load` すると、erb と activesupport を読み込んだプロセスでガジェットになる。修正版は erb 4.0.3.1・4.0.4.1・6.0.1.1・6.0.4 以上。3.2.11 の erb 4.0.2 も 3.1.7 の erb 2.2.3 も対象で、Ruby を上げて増えるものではない。default gem の erb は lock になく、bundler-audit は検出しない。修正版を使うには Gemfile に erb を足す必要がある。3 アプリは Cookie を JSON で直列化し（DEF-7.0-16）、RP のセッションも JSON |

Ruby 3.2 以上を必要とする gem（2-b の候補。2-b の着手時に確かめ直す）:

| gem | 今 → 候補 | 分かったこと |
|---|---|---|
| doorkeeper-openid_connect | 1.10.1 → 1.10.5（2026-07-09） | GHSA-8r7r-wh7x-27ff は 1.10.4 で修正（DCR は無効なので影響しない）。1.10.2 で空の必須 claim が例外になり、grant ごとの `auth_time` が入る。2.0.0 はマイグレーションが要る |
| byebug | 12.0.0 → 13.0.0 | reline `>= 0.6` を依存に足す（3.2.11 の default は 0.3.2） |
| web-console | 4.2.1 → 4.3.0 | actionview・railties `>= 8.0` が必要。Step 6 まで上げられない |
| rack-mini-profiler | 4.0.1 → 5.0.0 | Gemfile の `~> 4.0` を変える必要がある。development の既定値が変わる |
| simplecov | 0.22.0 → 1.2.0 | 1.3 は Ruby 3.3 以上。1.0 で `test/` を集計から外すなど、出力が変わる |
| zeitwerk | 2.6.18 → 2.7.5 / 2.8.3 | Ruby `>= 3.2`。Rails 7.0 での動作は未確認 |
| brakeman | 7.1.1 → 8.0.6 | 警告の種類が変わりうる |
| faraday-net_http | 3.0.2（一時固定） | 3.4.x は net-http `~> 0.5` で、3.2.11 の default の 0.4.1 では満たせない。3.1〜3.3 は `net-http >= 0` で、lock に net-http が増える |

### Step 2-b: Ruby 3.2 以上を必要とする周辺 gem

Step 2 が epic に入ってから調べ、作業計画を出して承認を得た（2026-10-10）。Ruby 3.2.11・Rails 7.0.10 のまま、Ruby 3.1 のために止めていた周辺 gem を上げる。経緯と作業の記録は LOG.md の Step 2-b。

- [x] doorkeeper-openid_connect 1.10.1 → 1.10.5（OP）。GHSA-8r7r-wh7x-27ff の修正版を含む
- [x] doorkeeper-openid_connect の initializer とロケールを 1.10.5 の雛形に合わせる（独自の設定は残す。DEF-7.0-48・49）
- [x] zeitwerk 2.6.18 → 2.7.5 → 2.8.3（3 アプリ）
- [x] byebug 12.0.0 → 13.0.0（3 アプリ。依存の reline 0.6.0・io-console 0.6.0 は一時固定）
- [x] simplecov 0.22.0 → 1.2.0（3 アプリ。DEF-7.0-50）
- [x] brakeman 7.1.1 → 8.0.6（3 アプリ）
- [x] ブラウザで手動確認（すべての gem を上げた後に、introspection の流れまで 1 回）
- 着手時の作業計画で決めたこと（人間が承認）
  - 順番: doorkeeper-openid_connect（advisory の修正版なので最初）→ 雛形への追随 → zeitwerk 2.7.5 → 2.8.3 → byebug → simplecov → brakeman。1 gem ずつ、アプリごとに RS → RP → OP の順でコミットする。PR は 1 つ
  - doorkeeper-openid_connect は `bundle update doorkeeper-openid_connect --patch --conservative` で 1.10.5 にする（`--conservative` だけでは 2.0.0 になる）。2.0.0 はメジャーで、マイグレーションが要るので対象外（7 章）
  - zeitwerk は 2.7.5 を一時固定で入れてから、2.8.3 にする（マイナーを飛ばさない。Rails 7.0.10 自身の lock が 2.7.3）
  - byebug 13 の依存のうち、reline は「default gem の版では要件を満たせないものは、要件を満たす最小の版」（Step 1 の benchmark・securerandom と同じ扱い）で 0.6.0 に、io-console は default gem の版（0.6.0）に一時固定する
  - brakeman は 8.0.6 にする（8.1.0 は 2026-10-01 公開で、2 週間たっていない）。8.1.0 は Step 3 の最初に上げる（スキル化の PR では gem を上げない。7 章）
  - rack-mini-profiler 5.0.0 は上げず、Step 3（Rails 7.1）に移す（人間が判断。CLAUDE.md の ①対応版を待つ）。5.0.0 の railtie が Rails 7.1 の `Rails.env.local?` を使い、Rails 7.0 の development ではプロファイラーが無効になるため（下の「調べたこと」）
  - gem の雛形への追随（A）は、項目ごとに解説して返事をもらってから、[defaults/rails-7.0.md](defaults/rails-7.0.md) に DEF-7.0-48 から記録する
  - 2-b の対象は Ruby 3.2 以上を必要とする gem だけにする。`bundle outdated` に出るほかの gem（jwt 3.x、間接依存）は動かさない（7 章）
  - 手動確認は、すべての gem を上げた後に 1 回（doorkeeper-openid_connect と、development の zeitwerk の読み込みを含めるため）
  - 着手後に決めたこと（人間が判断）: simplecov 1.x の出力の変化は DEF-7.0-50 として記録して追随する。最新の 1.3 系は Ruby 3.3 以上が必要なので、Step 4（Ruby 3.3）の後の周辺 gem のサブステップで上げる（Step 4 は Ruby だけを上げる）。brakeman 8.0.6 で増えたチェック（`RenderRCE`）は警告の結果を変えないので、DEF にせず LOG.md に記録する

調べたこと（着手時の 2026-10-10。rubygems の API、`bundle outdated`、3 アプリでの `bundle lock --update <gem> --conservative --print`（lock を書かずに解決の結果だけを出す）、GitHub のタグのソースと CHANGELOG。ソースと CHANGELOG はサブエージェント 3 つで調べ、要点は自分で確かめた）:

| gem | 版・要件 | 分かったこと |
|---|---|---|
| doorkeeper-openid_connect | 1.10.5（2026-07-09。Ruby `>= 3.2`、`doorkeeper >= 5.5, < 6.0`・`jwt >= 2.5`・`ostruct >= 0.5`。36,864 B） | 1.10.2（#312）で、ID トークンの `iss`・`sub`・`aud`・`exp`・`iat` が nil か空なら `MissingRequiredClaim` を出す（OP は `issuer` が固定値、`sub` が `resource_owner.id`、`aud` が uid なので起きない）。1.10.2（#304）で、grant ごとの `auth_time` を返す `auth_time_from_access_token` が増えた（opt-in。列とマイグレーションは増えない）。`max_age` の判定は 1.10.5 も `auth_time_from_session` → 非推奨の `auth_time_from_resource_owner` の順で、IMP-011 の状況は変わらない。1.10.3（#308）で、`openid_request` の関連を `on_load(:active_record)` の `run_hooks` から `AccessGrantExtension#included` で足すようになった。1.10.4 で GHSA-8r7r-wh7x-27ff（DCR の scope）を直した（DCR は既定で無効のまま）。1.10.5（#329）は doorkeeper 5.8 未満の discovery の修正で、5.9.9 では値が同じ。雛形は、initializer がコメントだけの差分、ロケールが `missing_required_claim` の 1 つの追加、マイグレーションは同じ |
| doorkeeper-openid_connect 2.0.0 | 2026-09-22 | メジャー。`post_logout_redirect_uris` の列を足すマイグレーション（#243）、`id_token token` の応答の変更、設定・定数の削除、discovery・Webfinger・JWKS の変化がある |
| byebug | 13.0.0（2026-01-15。Ruby `>= 3.2.0`、`reline >= 0.6.0`。85,504 B） | readline をやめて reline を使う（#909・#905）。IRB は `irb` コマンドのときだけ読む（#824）。`require 'byebug'`（`Bundler.require`）では reline を読まず、`byebug` を呼んだときに読む。固定しないと reline 0.7.0 と io-console 0.9.4（C 拡張）が lock に入る |
| reline / io-console | reline 0.6.0（2024-12-16。`io-console ~> 0.5`。51,712 B）。Ruby 3.2.11 の default gem は reline 0.3.2・io-console 0.6.0・irb 1.6.2（`reline >= 0.3.0`） | lock に reline が入ると、`bin/rails c` の irb 1.6.2（default gem。lock にない）も lock の reline を読む。irb 1.6.2 が使う Reline の API は、reline 0.6.0〜0.7.0 にすべて残っている（ソースの突き合わせ。reline の CI は irb の master しか試していない）。reline が使う io-console の機能は 0.6.0 にある |
| rack-mini-profiler | 5.0.0（2026-08-21。Ruby `>= 3.2.0`） | `lib/mini_profiler_rails/railtie.rb` が、4.0.1 の `Rails.env.development? \|\| Rails.env.test?` を `Rails.env.local?` に変えた（#661。CHANGELOG にはない）。`local?` は Rails 7.1 で入ったもので、Rails 7.0.10 では `StringInquirer` の `method_missing` で false になる（OP の development で確かめた）。そのため development でも `authorization_mode = :allow_authorized` になり、バッジ・`x-miniprofiler-*` ヘッダー・Cache-Control の書き換えが出なくなる見込み（5.0.0 は入れておらず、ここはソースを読んでの推論）。gemspec の開発時の依存は `rails >= 7.1` |
| simplecov | 1.2.0（2026-09-04。Ruby `>= 3.2`、依存なし。212,992 B）。1.3 は Ruby 3.3 以上 | docile・simplecov-html・simplecov_json_formatter が lock から消える（HTML と JSON の formatter は本体に取り込まれた）。`rails` プロファイルの集計の対象は同じ（`test/` は 0.22 でも除外）。結果の行が stdout から stderr に移り、文言が変わる。`coverage/` は 1 ファイルの `index.html`（1.1.0）と `coverage.json`、`.history.json`（1.2.0）などになる。`rails` プロファイルに `merge_subprocesses true` が入る。最低カバレッジを設定していないので、終了コードは変わらない |
| zeitwerk | 2.7.5（2026-02-19。41,472 B）、2.8.3（2026-08-01。44,032 B）。どちらも Ruby `>= 3.2` | Rails v7.0.10 自身の lock が zeitwerk 2.7.3。Rails 7.0.10 が呼ぶ API（`Loader.new`・`push_dir`・`setup`・`on_load`・`on_unload`・`eager_load_all`・`reload`、zeitwerk:check が読むエラーの文言）は、2.7.5・2.8.3 に同じ形で残る（サブエージェントがソースを突き合わせた結果。自分で確かめたのは、上げた後の zeitwerk:check・eager load・テスト・E2E・手動確認が通ること）。2.8.0〜2.8.2 の collapse の回帰は 2.8.3 で直った（Rails 7.0 とアプリは collapse を使わない）。lock で zeitwerk に依存するのは railties だけ |
| brakeman | 8.0.6（2026-08-12。Ruby `>= 3.2.0`、`racc >= 0`。1,630,208 B）。8.1.0 は 2026-10-01 | fingerprint の計算、ignore ファイルの形式、終了コード、`--no-pager -q` は 7.1.1 と同じ。増えたチェックは Rails 4.2.5 以下が対象の `CheckRenderRCE` だけ。Ruby 3.2・Rails 7.0 の EOL の日付は同じ |
| advisory | — | ローカルの ruby-advisory-db（2026-10-06）と GitHub の Advisory Database に、上の版と reline・io-console の advisory はない。GHSA-8r7r-wh7x-27ff は今もリポジトリの advisory にだけある |
| lock の解決 | — | 3 アプリで `--print` を試すと、どの gem も、その gem（byebug は reline・io-console も、simplecov は依存の 3 つ）だけが動く。何も指定しないと、doorkeeper-openid_connect は 2.0.0、zeitwerk は 2.8.3、brakeman は 8.1.0 になる。`--patch` を付けると doorkeeper-openid_connect は 1.10.5 になる。lock の default gem と一時固定の gem は、どの試行でも動かない |
| ほかの gem（`bundle outdated`） | — | Ruby 3.2 を必要とする直接の gem は上の表ですべて（web-console 4.3 は Rails 8 も必要で Step 6）。今の Ruby・Rails で上げられるものは、jwt 3.3.0（RP・OP）と間接依存（hashie・responders・i18n・tzinfo・minitest・rack-test など）だけ |

### スキル化

Step 2-b が epic に入ってから確かめ直し、作業計画を出して承認を得た（2026-10-11）。`/rails-upgrade` のスキルと、Rails のマイナーを上げるときの道具を作る。gem は上げず、アプリのコードと lock は変えない。スキルの方向と構成は 13 章。経緯は LOG.md の「スキル化」。

- [x] `scripts/compare-config`（設定の値と、起動の途中に読み込み済みの部品の書き出しと前後の比較）
- [x] `scripts/resolve-lock`（旧 lock の gem を固定し、指定した gem だけを外して解決させる）
- [x] `scripts/restore-app-config`（`app:update` の後に、アプリの独自設定を戻す）
- [x] `scripts/check-console`（`rails c` を擬似端末で起動して入力を試す）
- [x] `scripts/verify-gem-checksums`（キャッシュの `.gem` の SHA-256 を rubygems.org の値と比べる）
- [x] `scripts/commit-per-app`（ほかのアプリの変更を退避し、検査してからコミットする）
- [x] スキルの汎用の核（`.claude/skills/rails-upgrade/`）と、リポジトリ固有の設定（`.claude/rails-upgrade-project.md`）
- [x] スキルを試す（新しいセッションで、引数なしと `pr`）
- [x] verify
- [x] pr
- 着手時の作業計画で決めたこと（人間が承認）
  - スキルの方向: 知識のある担当者が判断の要る所だけを確かめ、それ以外は AI が再現性のある形で進める。担当者だけでは完了せず、細部を知らないレビュアーが PR を見て OK を出したら完了とするフローを前提に、「担当者が説明できる状態の PR を、毎回同じ形で作る」ことをスキルの役割にする（作業計画への返事の対話で決めた。13 章の 1）
  - 2 層: 汎用の核（ワークフロー・関門・型）と、リポジトリ固有の設定に分けて作る。試すのはこのリポジトリだけで、チームでの検証は後に回す（汎用の核は仮説のまま epic に入る）
  - 作業の一覧: patch を外し、rails-lock と research に含める。record は `pr` にする（13 章の 3）
  - Step 2-b の scratchpad の道具（起動の途中の読み込みの書き出し、`rails c` の擬似端末のドライバー、SHA-256 の照合、アプリごとに退避して検査してコミットする道具）を `scripts/` に入れる。起動の途中の読み込みの書き出しは `compare-config` に統合する（Step 2-b のコードレビューで、この PR で決めるとした）
  - CI から `scripts/check-apps` を呼ばない（1-b-3-1 のコードレビューで、この PR で決めるとした。13 章の 5）
  - Rails に共通の道具（`compare-config`・`resolve-lock` など）も、この PR では `scripts/` に置く。チームへ持ち出すときに、汎用の核へ移すかを決める
  - スクリプトは、Step 1 と Step 2-b の結果を再現できることを確かめてからコミットする（13 章の 5 の「確かめ方」）

調べたこと（着手時の 2026-10-11）:

| 項目 | 分かったこと |
|---|---|
| 13 章の作業の一覧と手作業 | Step 1-b-3・2・2-b を通した結果と比べると、resume に前の PR へのリンクのコミットと手動確認用の環境の控え、research に Plan モードでの lock の試行（`--print`）と非推奨警告の確かめ、gems の関門に追随の解説、verify に `rails c` の確かめ方、record に PR 本文の型とコードレビューの記録がなかった。ruby の関門は Step 2 の前に書いたため「—」のままで、実際は Ruby のダウンロード、default gem の合わせ直しの版、意図しないダウンロード（`--no-cache`）、手動確認の時期が関門だった。patch は一度も通していない（6.1.7.10・7.0.10 とも、その時点の最新パッチだった） |
| Claude Code のスキル | 公式の文書（code.claude.com の Skills のページ。2026-10-10 更新）による。`.claude/skills/<name>/SKILL.md` が `/<name>` になる（`.claude/commands/` は同じ仕組みに統合された）。frontmatter の `name` は小文字・数字・ハイフンで 64 文字まで、`description` は 1,024 文字まで。`disable-model-invocation: true` で、人間が打ったときだけ動き、説明も常時の文脈に入らない。引数は `$ARGUMENTS`・`$0`。参照ファイルは SKILL.md から 1 段の相対リンクで指し、必要なときに読まれる。SKILL.md は 500 行以下を勧めている。`${CLAUDE_PROJECT_DIR}` は SKILL.md の本文で置き換わる。検査の `claude plugin validate .claude/skills` は 2.1.233 以上で、手元の CLI は 2.1.195 |
| Step 1 を再現する条件 | タグ `rails-6.1-prepared` は `cedf13d`（PR #20 のマージ）。Ruby 3.1.7（Bundler 2.3.27）は mise に入っている。タグから Step 1 のマージ `20321ed` までの lock の gem は、3 アプリの `vendor/bundle/ruby/3.1.0`（ビルド済みの C 拡張も）にあるか、Ruby 3.1.7 の default gem（bigdecimal・json・logger・drb・mutex_m・base64・ruby2_keywords・cgi）。x86_64 の nokogiri・sqlite3 は手元では要らない |
| Step 1 のコミット | rails 7.0.10 は RS `fb67546`・RP `a6e2bdf`・OP `8715abf`、`app:update` は RS `e363c55`・RP `8ca0c8c`・OP `8be19a1`（独自設定は同じコミットの中で戻した）、グループ 8 の後は `89fb290`、`load_defaults 7.0` は RS `fd3eb40`・RP `b1f3552`・OP `400ed9c`。`app:update` で戻した独自設定は、3 アプリの `config/environments/test.rb` の `deprecation = :raise`、`config/initializers/filter_parameter_logging.rb` のコメントと `:code`、RP の `config/application.rb` の末尾の serializer の設定（`77c26df` で initializer に移した）。Active Storage のマイグレーション 3 本は採用しなかった |
| 元になる道具 | Step 1 の scratchpad に、設定の値の書き出し、lock の固定と解決、独自設定の戻しの道具が、Step 2-b の scratchpad に、起動の途中の読み込みの書き出し、`rails c` の擬似端末のドライバー、SHA-256 の照合、アプリごとのコミットの道具が残っていた。アプリごとのコミットの道具は、コミットが失敗すると退避した変更を戻さなかった |
| Step 1 の書き出しの結果 | Step 1 の scratchpad の書き出しで、`load_defaults 7.0` の前後で違うのは DEF-7.0-24 の値だけ（OP は development だけ）。記録（defaults/rails-7.0.md の「`load_defaults 7.0`」）と同じ |
| PR 本文 | PR #27 の本文は、概要、既定値・雛形への追随、業務的な挙動の変化、確認したこと、見送ったことの節でできている。コミットへの索引と、レビュアーに見てほしい所の節はない |

### Step 3: Rails 7.1

スキル化の PR が epic に入ってから、`/rails-upgrade research` で調べた。作業計画を出し、承認を得た（2026-10-11）。Ruby 3.2.11 のまま Rails を 7.1.6 に上げる。Rails の前に、今の Rails で上げられる直接の gem を上げ、Rails の直後に、Rails 7.1 を必要とする gem を上げる。経緯と作業の記録は LOG.md の Step 3。

- [x] gems: brakeman 8.1.0（3 アプリ）
- [x] gems: jwt 3.3.0（RP・OP。RS は間接の依存なので 2.10.3 のまま。下の「着手後に決めたこと」）
- [x] gems: puma 8.0.2（3 アプリ。Gemfile `~> 6.0` → `~> 8.0`。DEF-7.1-01〜03）
- [x] gems: omniauth-rails_csrf_protection 2.0.1（RP）
- [x] rails-lock: Rails 7.1.6（3 アプリ。DEF-7.1-04・05）
- [x] gems: activerecord-session_store 2.3.0（RP。Rails 7.1.6 と同じコミットで上げた。DEF-7.1-06。下の「着手後に決めたこと」）
- [x] gems: rack-mini-profiler 5.0.0（RP・OP。Gemfile `~> 4.0` → `~> 5.0`。DEF-7.1-09）
- [x] rails-app-update（DEF-7.1-10〜18）
- [x] rails-app-update: RP の autoload_lib_once（案 B のまま。案 A には切り替えていない）
- [x] rails-defaults（グループ 1〜4・6・7。DEF-7.1-19〜41）
- [x] rails-load-defaults（DEF-7.1-42〜46。RuboCop の `TargetRailsVersion` 7.1）
- [x] verify（手動確認で DEF-7.1-47・48 を見つけた。CI は push の後）
- [x] pr

着手時の作業計画で決めたこと（人間が承認。論点は 1 つずつ確かめた）:

- 直接の gem の方針（research の対話で人間が決めた）: Ruby が対応していて特に不具合がなければ、Gemfile に書いた直接の gem は、上げられる時点で最新版に上げる。間接の gem は対象外で、Rails・直接の gem・advisory で必要になったときだけ動かす（default gem に合わせた固定は続ける）。7 章の振り分けに足した
- 順番は次のとおり。1 gem ずつ、アプリごとに RS → RP → OP の順でコミットする。PR は 1 つ
  1. brakeman
  2. jwt
  3. puma
  4. omniauth-rails_csrf_protection
  5. Rails 7.1.6
  6. activerecord-session_store
  7. rack-mini-profiler
  8. `app:update`
  9. RP の `autoload_lib_once`
  10. `new_framework_defaults_7_1.rb`
  11. `load_defaults 7.1`
- brakeman 8.1.0 は、公開から 2 週間の決まりの例外として、Step 3 の最初に上げる（人間が判断）。公開は 2026-10-01 で、着手の日（10-11）は 10 日目。8.1.1 も advisory も出ていない。先送りしても、10-15 より前に次の Step に着手する見込みが高い
- jwt は 3.3.0 に上げる（方針）。gems の手順 1 で、RP の `my_op.rb` の `JWT.decode` のオプションでの検証が 3.3.0 でも同じに効くかを gem のソースで確かめる。守られていない検証の項目があれば、先にテストを足す
- puma は 7.x を経由せず 8.0.2 に上げる（方針）。CVE-2026-47736・47737 を無視リストから消す
- omniauth-rails_csrf_protection は、7 章の「Step 7」を前倒しして 2.0.1 に上げる（方針）。Rails 8.1 にするとき（Step 7）に、8.1 用の枝に切り替わるので、もう一度確かめる
- doorkeeper-openid_connect 2.0.0 は Step 3 に入れず、Step 3 が epic に入った直後のサブステップ 3-b で、意図的な仕様変更として扱う。マイグレーション（#243）と discovery の応答の変化（#333）があり、方針の「特に不具合がない」に当たらないため
- Rails 7.1.6 の依存のうち、cgi 0.3.7・irb 1.6.2 は Ruby 3.2.11 の default gem の版に一時固定する。tsort は default gem（0.1.1）では要件を満たせないので、要件を満たす最小の 0.2.0 にする。connection_pool は 2.5.5 に一時固定し、Step 5 で見直す（下の「調べたこと」）
- Rails 7.1 は secret_key_base を `tmp/local_secret.txt` から読む。rails-lock で各アプリを 7.1 で初めて起動する前に、`tmp/development_secret.txt` を `tmp/local_secret.txt` にコピーする。元のファイルは残し、コピーの直前にもう一度確かめる。手動確認用の環境の守るファイルは 12 になる（TIPS.md）
- RP の独自ストラテジーは、Zeitwerk の once のローダーに載せる（案 B）
  - `rails_relying_party_of_backend/config/application.rb` に以下を足す。`app:update` が提案する `config.autoload_lib` は RP では採用しない（RS・OP は差分を見て関門で決める）
    ```ruby
    config.autoload_lib_once(ignore: %w[assets tasks])
    Rails.autoloaders.once.inflector.inflect("omniauth" => "OmniAuth")
    ```
  - `config/initializers/omniauth.rb` の `require 'omniauth/strategies/my_op'` を消す
  - 理由は次の 2 つ。`autoload_lib_once` なら initializer からも使え、リロードもしない
    - `lib/omniauth` は既定の推測で `Omniauth` になり、実際の `OmniAuth` と食い違う
    - OmniAuth のミドルウェアは起動時に 1 回だけ作られるので、リロードの対象にできない
  - 完了条件: `bin/rails zeitwerk:check`、RP の minitest、E2E のログイン
  - うまくいかない場合は案 A（`autoload_lib(ignore: %w[assets tasks omniauth])` ＋ `require`）に切り替え、LOG.md に理由を残す
- `backtrace_silencers.rb` は 3 アプリとも残す。`BACKTRACE` 環境変数を railties が扱うのは 7.2 からなので、Step 5 で見直す（Step 5 で消した。DEF-7.2-28）
- `new_framework_defaults_7_1.rb` のグループと順は、rails-defaults の関門で決める。記録は `docs/upgrade/defaults/rails-7.1.md`（`DEF-7.1-<連番>`）
- 手動確認は verify で 1 回にする。途中で前の Cookie やセッションに影響する変化が見つかったら、止まって時期を相談し直す
- 着手後に決めたこと（人間が判断）
  - E2E の起動（`e2e/scripts/start-server.sh`）で、`db:drop` と `db:setup`（RS は `db:create`）を別のプロセスで流す。Rails 7.1 では 1 つのプロセスで流すと、作り直した DB にスキーマが入らない。Rails 7.1.6 の lock の前に、別のコミットにした
  - RP は activerecord-session_store 2.3.0 を Rails 7.1.6 と同じコミットで上げる。2.2.0 のままだと、Rails 7.1 でセッション Cookie から `SameSite=Lax` が消える（CLAUDE.md の「gem が新しい Rails に未対応のとき」の ①。DEF-7.1-06）
  - `new_framework_defaults_7_1.rb` のグループと順番: 1 使っていない機能 → 2 DB の扱い → 3 テストだけ → 4 ログ → 6 応答のヘッダー → 7 Cookie・メッセージの形式。`action_view.sanitizer_vendor`・`action_text.sanitizer_vendor`（雛形の行は initializer の時点で `Rails::HTML` がなく `NameError`。rails/rails#51246）と `log_file_size`（ロガーは initializer より前に作られる）は、`add_autoload_paths_to_load_path`・`cache_format_version` と同じく `load_defaults 7.1` に任せる（グループ 5 はなくなった）
  - RS の jwt は 2.10.3 のままにする。作業計画は jwt を「3 アプリ」としていたが、RS の jwt は oauth2 の依存（間接の gem）で、直接の gem の方針の対象外だった（RS のコミットの前に気づいた）
  - 2.10.3 は CVE-2026-45363 の修正版で、ほかの advisory はない。RS は jwt の処理を通らない（oauth2 の assertion のグラントだけが `JWT.encode` を使う）。ruby-jwt の `2-10-stable` はバックポートだけで、将来の修正が戻されないおそれはある。そのため、間接の gem は epic の最後の段階でまとめて上げることを考える（14 章）

調べたこと（着手時の 2026-10-11）。調べた材料は次のとおりで、ソースと CHANGELOG はサブエージェント 2 つで調べ、要点は自分で確かめた。
- rubygems の API と `bundle outdated`
- scratchpad の lock のコピーでの `scripts/resolve-lock`・`bundle lock --print`、解決した lock への bundler-audit
- GitHub のタグのソースと CHANGELOG、Rails ガイド v7.1

| 項目 | 分かったこと |
|---|---|
| Rails の版 | 7.1.6（2025-10-28、Ruby `>= 2.7.0`）が 7.1 系の最後の版で、7.0・7.1 とも EOL（rubyonrails.org の 2025-10-29 の告知）。7.0.10 は 7.0 系の最新なので、先に上げるパッチはない。7.1.5.2 → 7.1.6 で変わったのは Active Record と Action Cable だけ |
| advisory | 7.1.6 の lock（scratchpad）に bundler-audit（DB は 2026-10-10）をかけると、CVE-2025-55193（activerecord）と CVE-2025-24293（activestorage）が解消し、新しい advisory はない（3 アプリとも 16 → 14 件）。puma 8.0.2 で CVE-2026-47736・47737 も解消する |
| lock の解決 | `scripts/resolve-lock --gem 'rails=~> 7.1.6' --rails` で、動かすしかない gem は rails-dom-testing（`~> 2.2`）と erubi（`~> 1.11`）だけ。新しく入るのは connection_pool・rack-session 1.0.2・rackup 1.0.1・webrick 1.9.2・tsort・irb・cgi（RS・OP）。timeout は lock の 0.6.1 で `>= 0.4.0` を満たす |
| default gem と同じ名前の依存 | 固定しないと cgi 0.5.2・irb 1.18.0 が入る。irb 1.18.0 は rdoc 8.1.0・rbs・erb 6.0.7・pp・prettyprint も連れてくる。cgi 0.3.7・irb 1.6.2（Ruby 3.2.11 の default gem）に固定すると、これらは入らない |
| connection_pool | activesupport 7.1.6 は `>= 2.2.5` で、そのままでは 3.0.2 が入る。3.0 はキーワード引数だけを受け付ける。Rails 7.1.6 の Redis・Memcache のキャッシュストアは位置引数で渡す（`activesupport/lib/active_support/cache/redis_cache_store.rb:153`）ので、`ArgumentError` になる。7-1-stable は直らないまま終わり、7-2-stable は `< 3` に固定した（rails/rails#56291・#56620）。3 アプリは memory_store・null_store だけを使う |
| rackup・rack-session | rack 2 用の 1.x は空の gem。rackup 1.0.1 は webrick に依存する。Rails は `rackup/server` がないと rack 2.2 の `Rack::Server` に戻る（`railties-7.1.6/lib/rails/rackup/server.rb`） |
| secret_key_base のファイル | rails/rails#48471（7.1.0）で `tmp/development_secret.txt` が `tmp/local_secret.txt` に変わり、7.1 は前のファイルを読まない（`railties-7.1.6/lib/rails/application.rb` の `generate_local_secret`）。railties の CHANGELOG にはなく、後から rails/rails#52083 がガイドに足した（Rails ガイド v7.1 のアップグレードガイドの 2.1「development環境とtest環境のsecret_key_baseファイル名が変更された」）。何もしないと、OP の development のセッション Cookie が読めなくなる。RP のセッション Cookie は署名のない ID、RS は Cookie を使わない |
| Rails 7.1 の非推奨 | 3 アプリの `config/environments/test.rb:31` の `show_exceptions = false` が非推奨。警告は、例外が middleware まで届いたときだけ出る（`actionpack-7.1.6/lib/action_dispatch/middleware/exception_wrapper.rb` の `show?`）。`app:update` の雛形は `:rescuable` にする。`Rails.application.secrets`・位置引数の coder の `serialize`・`ActiveSupport::Deprecation` のシングルトンは、アプリでも gem でも使っていない。devise・web-console・dotenv は自分の deprecator を登録しているが、warn を呼ぶ経路を通らない。7.0 の今のログに `DEPRECATION` の行はない |
| `app:update`（7.1.6） | `config/application.rb` に `config.autoload_lib(ignore: %w(assets tasks))` を足す（`load_defaults` は 7.0 のまま）。Dockerfile・`.ruby-version`・routes・`database.yml` は作らない、変えない（railties v7.1.6 の `framework.rake`・`app_updater.rb`）。主な雛形の変化は次のとおり（railsdiff/rails-new-output の v7.0.10...v7.1.6）<br>・development.rb: `enable_reloading`、`verbose_enqueue_logs`、`raise_on_missing_callback_actions`<br>・test.rb: `enable_reloading`、`show_exceptions = :rescuable`<br>・production.rb: `force_ssl` が有効、ログは STDOUT<br>・`permissions_policy.rb`<br>・`bin/setup` |
| `new_framework_defaults_7_1.rb` | 28 項目。見込みは次のとおり<br>・応答が変わる: `default_headers`（`X-Download-Options` が消える）<br>・Cookie・メッセージの形式: `message_serializer`・`use_message_serializer_for_metadata`（OP のセッション Cookie の形式。古い形式も読める）<br>・テストだけ: `dom_testing_default_html_version`<br>・ほかは、アプリが使っていない機能か、設定の値だけ（`sqlite3_adapter_strict_strings_by_default` は、生の SQL がないので影響しない）<br>`add_autoload_paths_to_load_path` と `cache_format_version` は、initializer では効かず `config/application.rb` に書く |
| RP の独自ストラテジー | `config/initializers/omniauth.rb:1` が `require` で読む（`lib` は `$LOAD_PATH` にあり、autoload はされていない）。`add_autoload_paths_to_load_path = false` になっても `lib` は `$LOAD_PATH` に残る（ガイド v7.1 の 2.2・2.3）。`lib/assets`・`lib/tasks` は `.keep` だけ |
| `backtrace_silencers.rb` | railties の `backtrace_cleaner.rb` が `BACKTRACE` を扱うのは v7.2.3 からで、v7.1.6 にはない |
| RuboCop | `TargetRailsVersion: 7.1` にした設定を scratchpad に置いて 3 アプリを流すと、新しい指摘はない |
| brakeman 8.1.0 | 2026-10-01、Ruby `>= 3.2.0`。検証の正規表現の検査を Active Record 以外のモデルにも広げた（3 アプリに `validates ... format` はない）。Rails 7.1 の位置引数の `enum` に対応した。EOL の一覧では Rails 7.1 は 2025-10-01 に終了 |
| jwt 3.3.0 | 2026-09-11、Ruby `>= 2.5`、依存は base64。`--conservative` で動くのは jwt だけ。3.0〜3.3 の破壊的な変更は、このリポジトリの使い方に当たらない見込み（ruby-jwt の CHANGELOG.md・UPGRADING.md）<br>・RSA 2048 ビット以上: OP の鍵は 4096、RP のテストの鍵は 2048<br>・claim の検証の API の削除: RP は `JWT.decode` のオプションで検証している<br>・base64 のデコードを厳しくした<br>・例外の階層: RP のテストが期待する例外クラスは残る |
| puma 8.0.2 | 2026-05-27、Ruby `>= 3.0`、`nio4r ~> 2.0`（lock の 2.5.9 のまま）。動くのは puma だけ。7.0・8.0 の破壊的な変更（puma の History.md）のうち、効くのは keep-alive の既定値と応答ヘッダー名の小文字化（puma#3305）だけ。`config/puma.rb` はフックも workers も使わず、production は動作保証の外。8.0.2 にも rack 2 用の `lib/rack/handler/puma.rb` がある |
| omniauth-rails_csrf_protection 2.0.1 | 2025-12-10、`actionpack >= 4.2`。v1.0.2...v2.0.1 の `token_verifier.rb` は、Action Pack 8.1 以上だけ別の枝を通り、8.1 未満は 1.0.2 と同じ処理。RP の `my_op_login_test.rb:24`（CSRF の失敗）と E2E が守る |
| activerecord-session_store 2.3.0 | 2026-07-13。actionpack・activerecord・railties `>= 7.1`。Cookie の SameSite の既定をリクエストの `cookies_same_site_protection` から取る、`sessid` 列が非推奨（RP は `session_id` 列）、空の COMMIT をしない（GitHub の v2.3.0 のリリース） |
| rack-mini-profiler 5.0.0 | 2026-08-21、Ruby `>= 3.2.0`。railtie が `Rails.env.local?` を使う（v4.0.1...v5.0.0）。development の高度なデバッグ機能が既定で無効になった（#645） |
| doorkeeper-openid_connect 2.0.0 | 2026-09-22、Ruby `>= 3.2`。`post_logout_redirect_uris` の列のマイグレーションが必須（#243）。discovery に `authorization_response_iss_parameter_supported` が常に出る（#333。v2.0.0 の `discovery_controller.rb:65`）。doorkeeper 6.0 は rc2（2026-09-24） |
| 直接の gem の残り | 上げないものは次のとおり。ほかの直接の gem はすべて最新<br>・rubocop 1.92.0・webmock 3.27 以上: 2 週間たっていない<br>・simplecov 1.3: Ruby 3.3<br>・sqlite3 2.x: Rails 7.1 は 1.x だけ（誤り。Rails は 7.1.4 から 2.x を使える。Step 5 の着手時に分かった）<br>・web-console 4.3: Rails 8.0 |

### Step 3-b: doorkeeper-openid_connect 2.0.0（意図的な仕様変更）

Step 3 が epic に入ってから、`/rails-upgrade research` で調べた。作業計画を出し、論点を 1 つずつ確かめてから承認を得た（2026-10-11）。Ruby 3.2.11・Rails 7.1.6 のまま、OP の doorkeeper-openid_connect だけを 1.10.5 → 2.0.0 に上げる。doorkeeper は 5.9.9 のまま（6.0 は rc）。経緯と作業の記録は LOG.md の Step 3-b。

- [x] gems: doorkeeper-openid_connect 2.0.0（OP。initializer・ロケールを雛形に合わせた。DEF-7.1-49・50）
- [x] gems: schema.rb を Rails 7.1 の形で書き出す（OP。DEF-7.1-51）
- [x] gems: `post_logout_redirect_uris` のマイグレーション（OP。その前に、annotate が `test/fixtures/users.yml` に足した注釈を別のコミットにした）
- [x] verify（手動確認の直前に、手動確認用の OP の DB の写しを取ってから migrate した。CI は push の後）
- [x] pr

意図的な仕様変更（3 章の 2 の B。人間が 1 つずつ判断した）:

1. OP の `oauth_applications` に `post_logout_redirect_uris`（text、null 可、既定値なし）の列を足す（#243）
   - gem の CHANGELOG（v2.0.0.beta1）が「Migration required」と書いたアップグレードの手順で、境目 1（gem の雛形への追随）の側にあたる
   - 列は RP-Initiated Logout の登録 URI の置き場。機能のコードは列がなくても読み込まれ、列はその置き場所を足すだけなので、境目 5 の「使っていない機能を動かし始める」にはあたらないと判断した
   - コードは列がなくても動く（getter は `[]`、検証は飛ばす、setter だけが例外）が、この分岐は移行のためのもので、後の版で外れるおそれがある
2. discovery（`/.well-known/openid-configuration` と `/.well-known/oauth-authorization-server`）に `"authorization_response_iss_parameter_supported": false` が出る（#333）
   - 値は doorkeeper の `issuer` の設定の有無で決まり、doorkeeper 5.9.9 にはその設定がないので `false`。設定では消せない
   - 認可応答に `iss` は付かず、値は OP の挙動のとおり。RP・RS は discovery を読まない
3. webfinger の応答の `Content-Type` が `application/jrd+json` になり、`Access-Control-Allow-Origin: *` が付く（#350）
   - 設定では戻せない。RP・RS・E2E は webfinger を呼ばない。公開の情報（issuer の URL）だけを返す応答

着手時の作業計画で決めたこと（人間が承認）:

- コミットは OP だけで、次の順にする。PR は 1 つ
  1. gem を上げる（lock、initializer・ロケールの雛形への追随、応答のスナップショット 3 つと E2E の `discovery.json`）
  2. schema.rb を Rails 7.1 の形で書き出すだけ
  3. マイグレーション
- 応答のスナップショット（`discovery.txt`・`oauth_authorization_server.txt`・`webfinger.txt`）と E2E の `e2e/baseline/discovery.json` は、gems の作業で実際の差分を示し、人間に確かめてから作り直す
- schema.rb の書き出しとマイグレーションは、E2E 用の DB（`DATABASE_URL=sqlite3:db/e2e.sqlite3`）で行い、手動確認用の DB には触れない
- 手動確認用の OP の development DB は、verify の手動確認の直前に 1 回だけ migrate する
  - マイグレーションのファイルが入ると、development の OP は migrate するまで、すべての要求が `ActiveRecord::PendingMigrationError` になる
  - 流す前に、サーバーが止まっていて 14 ファイルのハッシュと件数が基準と同じことを確かめる
  - 本体と `-wal` を `rails_open_id_provider/tmp/manual_check_backup/`（gitignore）に写し、写しのハッシュが元と同じことを確かめる。`-shm` は開くときに作り直されるので写さない。scratchpad はセッションをまたいで残らないので使わない
  - 流した後に、schema.rb・`app/models/user.rb`（annotate）に差分がないこと、件数、`db:migrate:status` を確かめる
  - 戻すときは、サーバーを止めて写しを戻し、`-shm` を消す（その場で人間に確かめる）
  - 写しは、Step 3-b の PR が epic に入った後に、確かめてから消す
  - LOG.md の Step 3 の「スキルについて気づいたこと」の 22（元に戻す選択肢を残す）を踏まえた
- 一時固定は要らない。手動確認は verify で 1 回

調べたこと（着手時の 2026-10-11）。gem の 1.10.5...2.0.0 の差分はサブエージェントで調べ、要点（discovery の値、列がないときの挙動、webfinger、雛形の差分）は自分で gem のソースで確かめた。

| 項目 | 分かったこと |
|---|---|
| 版・要件 | 2.0.0 は 2026-09-22 公開。Ruby `>= 3.2`。依存は doorkeeper `>= 5.5, < 7.0`（1.10.5 は `< 6.0`）・jwt `>= 2.5`・ostruct `>= 0.5`。2.0.1 は出ていない（rubygems の API、`doorkeeper-openid_connect-2.0.0/doorkeeper-openid_connect.gemspec`） |
| lock | `bundle lock --update doorkeeper-openid_connect --conservative --print` で動くのは、この gem と依存の行だけ。doorkeeper 5.9.9・jwt 3.3.0・ostruct 0.5.5・default gem・一時固定は動かない |
| advisory | 試した lock に bundler-audit（DB は 2026-10-10）をかけても、今と同じ（無視リストのもの）。この gem の advisory（GHSA-8r7r-wh7x-27ff ほか）は 1.10.5 に当たらない。2.0.0 の CHANGELOG の「Security」の項（DCR の既定の scope）は advisory がなく、OP は DCR を有効にしていない |
| `post_logout_redirect_uris`（#243） | `rails generate doorkeeper:openid_connect:add_post_logout_redirect_uris` が `add_column :oauth_applications, :post_logout_redirect_uris, :text` のマイグレーションを作る（`.../templates/add_post_logout_redirect_uris.rb.erb`）。end_session のエンドポイントは gem になく、discovery の `end_session_endpoint` も変わらない。列がないとき、getter は `[]`、検証は飛ばし、setter だけが `ActiveModel::MissingAttributeError`（`.../orm/active_record/mixins/application.rb`）。列を読むのは DCR だけ。Step 3 の着手時の「マイグレーションが必須」は CHANGELOG の記述で、コードは列がなくても動く |
| discovery（#333） | `token_endpoint_auth_methods_supported` と `subject_types_supported` の間に出る。値は `Doorkeeper::OpenidConnect.doorkeeper_issuer.present?`（v2.0.0 の `discovery_controller.rb` の 61〜65 行）。doorkeeper 5.9.9 には `issuer` の設定がない（`doorkeeper-5.9.9/lib` に `option :issuer` がない）ので `false`。gem が認可応答に `iss` を付けるのは `id_token` の応答と doorkeeper に issuer があるときだけで、OP は当たらない |
| webfinger（#350） | RFC 7033 に合わせ、`Access-Control-Allow-Origin: *` と `content_type: "application/jrd+json"` で返す（v2.0.0 の `discovery_controller.rb` の 17〜23 行）。本文は変わらない |
| ほかの破壊的な変更 | `jws_private_key`・`jws_public_key` の削除、`IdTokenToken` の削除と `HybridIdTokenConcern` → `AtHashConcern` の改名、カスタムの `id_token_class` は既定のクラスを継承する、DCR の既定値。OP はどれも使わない。ほかに、エッジケースの 500 が 4xx になるもの（不正な形の `max_age`、所有者のないトークンの userinfo）と、resource owner かアプリケーションのないトークンに id_token を付けないもの（OP の client_credentials は `scope: introspection` だけ）がある（`CHANGELOG.md`、compare v1.10.5...v2.0.0） |
| ID トークン・JWKS・userinfo・token | 正常な流れでは同じ（ヘッダーの `typ`・`kid`、claim の順、RS256 の JWKS） |
| gem の雛形 | initializer は +38 行で、コメントだけ（issuer を doorkeeper から引くフォールバックの説明、`id_token_class`・`user_info_class`）。ロケールは +18 行（`post_logout_redirect_uris` の属性名とエラー文言）。OP の initializer・ロケールは 1.10.5 の雛形に合わせてある |
| schema.rb の書き出し | OP は 2021 年からマイグレーションがなく、schema.rb は `ActiveRecord::Schema[6.1]` のまま。マイグレーションを流すと、Rails 7.0 からの書き出しの形になる（`Schema[7.1]`、datetime の `precision` の書き方、`define` の後の空行）。列の精度の中身は同じ（test の DB のコピーから scratchpad に書き出して確かめた。activerecord 7.0 の CHANGELOG の「Dump the database schema containing the current Rails version」、rails/rails#42297） |
| RP・RS への影響 | RP は discovery を読まず、JWKS の URL を直接使う（`rails_relying_party_of_backend/lib/omniauth/strategies/my_op.rb:124`）。RP は OP にログアウトを伝えない（E2E の `logout.spec.ts`） |
| 守っているテスト | discovery は OP の `discovery.txt`・`oauth_authorization_server.txt`（応答のスナップショット）、`discovery_test.rb`（キーを絞る）、E2E の `discovery.json`。webfinger は `webfinger.txt` |
| 手動確認用の DB | DB の本体と `-wal` のコピーを Rails で開いて閉じても、`-wal` は残った（チェックポイントされない） |

### Step 4: Ruby 3.3

Step 3-b が epic に入ってから、`/rails-upgrade research` で調べた。作業計画を出し、論点を 1 つずつ確かめてから承認を得た（2026-10-12）。「8. 各 Step 共通の手順」の 4 に従い、Rails 7.1.6 のまま Ruby を 3.2.11 から 3.3.12 に上げる。経緯と作業の記録は LOG.md の Step 4。

- [x] ruby: RS（Ruby 3.3.12、lock の default gem、`BUNDLED WITH` 2.5.22、brakeman の無視リストの EOLRuby の項目を消す）
- [x] ruby: RP（同上）
- [x] ruby: OP（同上）
- [x] ruby: RuboCop の `TargetRubyVersion` を 3.3 にする
- [x] verify（手動確認は、3 アプリの Ruby を上げた後、`TargetRubyVersion` の前に行った。結果は LOG.md の Step 4 の「手動確認」と「確認結果」。CI は push の後）
- [x] pr

着手時の作業計画で決めたこと（人間が 1 つずつ判断した）:

1. 版は 3.3.12。3.3 系の最新で最後のリリース（ruby/ruby に v3_3_13 のタグはない）。公開から 2 週間以上たち、erb の修正版を含む
2. lock の default gem は、3.3.12 の default gem の版に合わせ直す（8 章の 4）。irb を 1.13.1 にすると、依存の rdoc・psych・stringio が lock に増える。この 3 つも 3.3.12 の default gem の版（6.6.3.1・5.1.2・3.1.1）に固定する。7 章に行を足し、Ruby を上げるたびに合わせ直す一覧に入れる。`rails c` の irb が 1.6.2 → 1.13.1 になるので、`scripts/check-console` で起動と入力を確かめる
3. brakeman の無視リストの EOLRuby の項目は、3 アプリとも、各アプリの Ruby を上げるコミットで消す。3.3 は EOL でなくなり、無視の理由がなくなる。fingerprint は Ruby の版を含まないので、残すと 3.3 の EOL も黙って無視する。Step 2 で、直った nokogiri の advisory を無視リストから消したのと同じ考え方
4. resolv の CVE-2026-80212・80213 は、Gemfile に足さずに記録だけにする（7 章の resolv の行）。アプリの実行時には読まれず、Ruby を上げて増えるリスクではない。Step 2 の erb と同じ扱い
5. 手動確認は、3 アプリの Ruby を上げた後（`TargetRubyVersion` の前）に 1 回。introspection の流れまで。直前に、手動確認用の環境の 14 ファイルのハッシュと件数が作業の開始時と同じことを確かめる

- 上げないもの
  - rubocop・webmock: 2 週間たった最新版が今の版（1.91.0・3.26.4）
  - simplecov 1.3: Step 4 の後のサブステップ（4-b）。Step 4 が epic に入ってから調べる
  - faraday-net_http: Step 8（3.3.12 の net-http も 0.4.1）
  - connection_pool: Step 5
  - reline: 0.6.0 のまま（3.3.12 の default gem の 0.5.10 は、byebug 13 の `>= 0.6.0` を満たさない）
  - mise: 2026.5.10 のまま（3.3.12 を入れるのに要らない）
- gem の入れ直しは、Step 2 と同じく、前の版のキャッシュの `.gem` を `vendor/bundle/ruby/3.3.0/cache` にコピーして `bundle install --local --no-cache` で行う。lock の合わせ直しは、Ruby 3.3.12 を入れてから scratchpad のコピーで試す（Plan モードではファイルを書けない）
- コミットは RS → RP → OP の Ruby、`TargetRubyVersion` の順。PR は 1 つ

調べたこと（着手時の 2026-10-12）。Ruby 3.3 の事実、gem の対応、リポジトリの中の版の箇所を、サブエージェント 3 つで調べ、要点（mise の入れ方、irb の依存、resolv を読む gem）は自分で確かめた。

| 項目 | 分かったこと |
|---|---|
| 版 | 3.3 系の最新は 3.3.12（2026-07-16）。3.3.11 は 2026-03-26。3.3 は security maintenance で、EOL は 2027-03-31（予定。ruby-lang.org の branches のページ）。`ruby-3.3.12.tar.gz` は 21,489,887 B で、SHA256 は告知と ruby-build の定義で同じ |
| mise | 2026.5.10 は、`experimental` が false で `ruby.compile` が未設定なので、ruby-build でソースからビルドする。ビルドの前に、ruby-build の最新のリリース（GitHub の API）と手元の版を比べ、違えば git clone で入れ直す（mise v2026.5.10 の `src/plugins/core/ruby.rs` の `update_ruby_build`）。手元の ruby-build 20260924 は最新のリリースと同じで、3.3.12 の定義を持つ。`~/.default-gems` はないので、入れた後の `gem install` も起きない |
| default gem（3.2.11 → 3.3.12） | json 2.6.3→2.7.2、bigdecimal 3.1.3→3.1.5、logger 1.5.3→1.6.0、base64 0.1.1→0.2.0、cgi 0.3.7→0.4.2、ostruct 0.5.5→0.6.0、drb 2.1.1→2.2.0（ruby2_keywords に依存したまま）、mutex_m 0.1.2→0.2.0、io-console 0.6.0→0.7.1、irb 1.6.2→1.13.1、reline 0.3.2→0.5.10、securerandom 0.2.2→0.3.1、benchmark 0.2.1→0.3.0、tsort 0.1.1→0.2.0、erb 4.0.2→4.0.3.1、psych 5.0.1→5.1.2、rdoc 6.5.1.1→6.6.3.1、stringio 3.0.4→3.1.1、timeout 0.3.1→0.4.1、date 3.3.3→3.3.4。net-http 0.4.1・ruby2_keywords 0.0.5 は同じ。racc は bundled gem になった（1.7.3）。Bundler 2.5.22・RubyGems 3.5.22（GitHub のタグ v3_3_12 のソース） |
| 一時固定の見直し | benchmark 0.3.0・tsort 0.2.0 は、3.3.12 の default gem と同じ版になる（lock は動かない）。securerandom は default gem の 0.3.1 で activesupport の `>= 0.3` を満たす。reline は default gem の 0.5.10 では byebug 13 の `>= 0.6.0` を満たさない。lock の date 3.5.1・timeout 0.6.1・racc 1.5.2・minitest 5.14.4 は default gem に合わせた固定ではないので動かさない |
| irb 1.13.1 の依存 | `rdoc >= 4.0.0`・`reline >= 0.4.2`（irb 1.6.2 は reline だけ）。rdoc 6.6.3.1 は `psych >= 4.0.0`、psych 5.1.2（ruby 版）は `stringio`。固定しないと rdoc 8.1.0・psych 5.5.0・stringio 3.2.0 が入る（rubygems.org の API） |
| 3.3 で動かない gem | lock の全 gem で、required_ruby_version が 3.3.12 を外すものはない（sqlite3 1.7.3 は `< 3.4.dev`、nokogiri 1.19.4 は `< 4.1.dev`）。nokogiri・sqlite3 の arm64-darwin 版は 3.3 のバイナリを含む |
| bundled_gems の警告 | 3.3.12 で警告を出すのは abbrev・base64・bigdecimal・csv・drb・getoptlong・mutex_m・nkf・observer・resolv-replace・rinda・syslog と racc（`lib/bundled_gems.rb`）。Bundler の下で、lock にない gem を標準ライブラリから読んだときだけ出る。base64・bigdecimal・drb・mutex_m・racc は 3 アプリの lock にある。lock の gem で、lock にない対象を require するのは brakeman の CSV の報告（`csv`）だけ。アプリのコードに対象の require はない（テストは `Base64` を require せずに使う） |
| NEWS 3.3.0 | 引数なしの `it`、非リテラルのブロックを渡す `lambda` は、アプリのコードにない。`NoMethodError` のメッセージの形が変わったが、テスト・スナップショット・E2E にエラー文言を比べるものはない |
| erb（CVE-2026-41316） | 3.3.12 の default gem の erb は 4.0.3.1（修正版。`lib/erb/version.rb`。3.3.12 の告知にも記載） |
| resolv（CVE-2026-80212・80213） | 2026-08-27 告知。DNS の応答によるメモリの枯渇と、長すぎるホスト名での検証のすり抜け。resolv `<= 0.3.1`・0.4.0〜0.7.1 が対象で、3.3 の 0.3.1 も 3.2 の 0.2 系も当たる（0.2 系は修正なし。3.3 の修正版 0.3.2 は 3.3.12 に入っていない）。Net::HTTP・TCPSocket は OS のリゾルバを使うので対象外。lock の gem で `Resolv` を使うのは bundler-audit（`lib/bundler/audit/scanner.rb`。Gemfile の source のホストを引く）と rubocop（`Style/IpAddresses` の正規表現）だけ |
| brakeman | 8.1.0 は 3.3 の EOL を 2027-03-31 として持つ（`checks/check_eol_ruby.rb`）。3.3.12 では EOLRuby の警告が出ず、無視リストの項目は「Obsolete Ignore Entries」に出る（終了コードは 0。`--ensure-no-obsolete-ignore-entries` を付けたときだけ止まる）。`Ignored Warnings` は 2 → 1。fingerprint は警告のコード・場所・確度から作り、Ruby の版を含まない（`warning.rb`）。2027-01-30 から pending EOL（コード 123）が出る |
| CI | setup-ruby v1.325.0（固定中のコミット）の `ruby-builder-versions.json` に 3.3.12 があり、`ruby-3.3.12-ubuntu-24.04-x64.tar.gz` がある。ci.yml は `.ruby-version` を読むので変えなくてよい。setup-ruby は lock の `BUNDLED WITH` の Bundler を使う |
| Ruby の版を持つ箇所 | 3 アプリの `.ruby-version`・Gemfile の `ruby`・lock、`.rubocop.yml` の `TargetRubyVersion`、TIPS.md の `mise where ruby@3.2.11` と brakeman の期待値。scripts（`verify-gem-checksums` は `RbConfig` からキャッシュの場所を作る）・`mise.toml`・`.claude/launch.json`・e2e は版を持たない |
| RuboCop | 1.91.0 に `minimum_target_ruby_version 3.3` の cop はない |
| 直接の gem | rubocop 1.92.0（2026-10-10）・webmock 3.27.0〜3.29.0（10-10・10-11）は 2 週間たっていない。simplecov 1.3.1（09-24）は 2 週間たち、1.3.2（09-30）は 10-14 に 2 週間。1.3 系は Ruby `>= 3.3`。CHANGELOG の Unreleased は Ruby `>= 3.4` にする予定 |
| gem の入れ直し | 置き場所が `vendor/bundle/ruby/3.3.0` に変わる。`3.2.0/cache` の `.gem` は RS 128・RP 142・OP 183 個（計約 104 MB）。C 拡張は 3.3 向けにビルドし直す（bootsnap・byebug・date・msgpack・nio4r・prism・puma・racc・websocket-driver、RP・OP は bindex、OP は bcrypt） |

### Step 4-b: simplecov 1.3.2

Step 4 が epic に入ってから、`/rails-upgrade research` で調べた。作業計画を出し、論点を 1 つずつ確かめてから承認を得た（2026-10-12）。Ruby 3.3.12・Rails 7.1.6 のまま、Ruby 3.3 以上を必要とする simplecov 1.3 系に上げる（Step 2-b では 1.2.0 で止めた。7 章）。経緯と作業の記録は LOG.md の Step 4-b。

- [x] gems: simplecov 1.2.0 → 1.3.2（RS）
- [x] gems: simplecov 1.2.0 → 1.3.2（RP）
- [x] gems: simplecov 1.2.0 → 1.3.2（OP）
- [x] gems: lock にある default gem と同じ版の gem を、3 アプリとも `vendor/bundle` に入れる（CI に揃える。LOG.md の Step 4-b の「作業計画からの変更点」。人間が判断）
- [x] verify（手動確認は行わない。手動確認用の環境の 14 ファイルのハッシュを、作業の開始時の基準と比べた。結果は LOG.md の Step 4-b の「確認結果」。CI は push の後）
- [x] pr

着手時の作業計画で決めたこと（人間が 1 つずつ判断した）:

1. 版は 1.3.2。公開から 2 週間の決まりの例外とする（人間が判断）。公開は 2026-09-30 で、着手の日（10-12）は 12 日目。脆弱性があれば既に報告されている時期と考えられ、advisory も出ていない。1.3.1 からの lib の違いは `exit_handling.rb` の 1 か所だけ。`bundle update simplecov --conservative` で 1.3.2 になるので、Gemfile に版を書く一時固定は要らない
2. 追随の記録は DEF-7.1-52 の 1 項目にする。ファイルのないグループをレポートから外すことと、`rails` プロファイルのグループの並び順は、どちらもグループの出し方の変化で、前例の DEF-7.0-50 も simplecov の出力の変化を 1 項目にまとめた。defaults/rails-7.1.md に「周辺 gem（Step 4-b）」の節を足し、DEF-7.0-50 の「後の版で変わること」から指す。Prism を読み込まなくなること（1.3.1）は既定値の変化ではないので、DEF-7.1-52 の影響と LOG.md に書く。解説（理解の関門）は、gems で前後の `coverage.json` を比べてから出す
3. 手動確認は行わない。simplecov は 3 アプリとも test グループで `require: false` で、development のサーバー（手動確認・E2E）では読まれない。lock で動くのは simplecov だけ。業務的な挙動は、応答のスナップショットと E2E で確かめる
4. rubocop 1.92.0（2026-10-10）・webmock 3.27.0〜3.29.0（10-10・10-11）は、この Step では扱わない。公開から 1〜2 日で、2 週間たっていない。Step 5 の research の最初に確かめる（rubocop 1.92.0 は 10-24、webmock 3.29.0 は 10-25 から）

- 上げないもの: rails・sqlite3（Step 5）、web-console（Step 6）。`bundle outdated --only-explicit` に出たが、時期は 7 章で決まっている
- ダウンロード: simplecov 1.3.2 の `.gem`（218,624 B）を、3 アプリで 1 回ずつ。`scripts/verify-gem-checksums` で rubygems.org の SHA-256 と照合する。実際に落としたのは、RS の 17 個（simplecov と、lock にある default gem と同じ版の 16 個）と OP の ostruct 0.6.0 で、RP は落としていない（LOG.md の Step 4-b の「作業計画からの変更点」）
- コミットは RS → RP → OP。その前に、DEF-7.1-52 を記録する docs のコミット。PR は 1 つ
- 前後の比較: 設定の「前後の比較」の項目（`check-apps`、`compare-config dump`、`RUBYOPT=-W:deprecated` の警告）に、カバレッジの出力（`coverage/coverage.json` の `total`・ファイルごとの値・`groups` の名前と順と中身、`.last_run.json`、テストの最後に出る結果の行）と、テストの実行で prism が読まれるかを足す

調べたこと（着手時の 2026-10-12）。

| 項目 | 分かったこと |
|---|---|
| 版と公開日 | 1.3.0 は 2026-09-12、1.3.1 は 09-24、1.3.2 は 09-30。1.3 系は Ruby `>= 3.3`。runtime の依存はない。`.gem` は 1.3.1・1.3.2 とも 218,624 B（rubygems.org の API） |
| Unreleased | Ruby 3.3 のサポートを外し、3.4 以上を必要とする（CHANGELOG の main）。Ruby 3.3 の間に入れられるのは 1.3 系が最後になる見込み |
| 1.3.0 の変化（効くもの） | ファイルがないグループを、HTML のレポート・`coverage.json`・履歴から外す。`rails` プロファイルのグループを、アルファベット順（Channels, Controllers, Helpers, Jobs, Libraries, Mailers, Models, Views）に宣言する。グループの中身は同じ（CHANGELOG の 1.3.0 の Upgrade notes・Enhancements、simplecov のタグ v1.2.0 と v1.3.2 の `lib/simplecov/profiles/rails.rb`・`lib/simplecov/result_processing.rb` の差分） |
| 空のグループ（1.2.0 の `coverage.json`） | RS は Helpers・Views・Libraries、RP は Views、OP は Views・Libraries。これらが外れる見込み。行のカバレッジ（3 アプリとも 100%）と、集計の対象のファイル（RS 7・RP 15・OP 8）は変わらない見込み |
| 1.3.0 の変化（効かないもの） | 読み込まれていない空のファイルの branch・method を 100% と数える（3 アプリは行だけを取る）。テンプレートの `# simplecov:disable` と、`cover` が `.erb` などに当たったときの警告（`cover_views` を使わず、`rails` プロファイルの対象は `{app,lib}/**/*.rb`）。CLI の `--annotate`（使っていない）。`coverage.json` の schema は 1.3 のまま |
| 1.3.1 の変化 | Prism を `require 'simplecov'` の時点では読まず、branch・method で要るときだけ読む（1.2.0 は読み込みの時点で `require "prism"` する）。3 アプリの lock には prism 1.9.0（rubocop の依存）があり、今はテストの実行で読まれている。ほかは JRuby on Windows と Rails main の `cover_views` の修正 |
| 1.3.2 の変化 | 結果を先に集めたとき（Rails 8.1.4 の `parallelize_teardown`）でも、終了時に HTML を書く（`exit_handling.rb` の 1 行）。3 アプリは `parallelize` を使わない |
| 結果の行 | 1.2.0 → 1.3.2 の lib の差分に、結果の行を書くコードの変更はない |
| lock の解決 | `bundle lock --update simplecov --conservative --print` で、3 アプリとも simplecov 1.2.0 → 1.3.2 の 1 行だけが動く。default gem に合わせた固定と、一時固定の reline・connection_pool・faraday-net_http は動かない |
| advisory | simplecov の advisory は、ruby-advisory-db・GitHub Advisory Database・simplecov のリポジトリのどれにもない |
| 業務的な挙動 | simplecov は test グループで `require: false`。development では読まれない。CI と `check-apps` はカバレッジの結果の行を読まず、最低カバレッジもない |
| ほかの直接の gem | `bundle outdated --only-explicit` で出たのは rails・rubocop・simplecov・sqlite3・webmock、RP・OP の web-console。公開から 2 週間たった（とした）のは simplecov だけ |

### スキルの見直し: 作業の切り替えと確認のまとめ方

Step 4-b が epic に入った後、Step 5 の前に、Step 4-b で `/rails-upgrade` を使って気になったこと（人間の指摘）を直す。作業計画を出し、論点を 1 つずつ確かめてから承認を得た（2026-10-12）。アプリのコードと lock は変えない。決めたことは 13 章の 7。経緯は LOG.md の「スキルの見直し」。

- [x] 作業の切り替えを関門にしない（SKILL.md・resume.md・CLAUDE.md）
- [x] 確認のまとめ方（templates.md・research.md）
- [x] 人間が貼るものの出し方（templates.md・pr.md）
- [x] verify（結果は LOG.md の「スキルの見直し」の「確認結果」。本当に試すのは Step 5 の始め）
- [x] pr

着手時の作業計画で決めたこと（人間が 1 つずつ判断した）:

1. 作業の切り替えは関門にしない。引数なしの `/rails-upgrade` で、チェックリストの最初の未完了の項目の作業から始め、各作業の出口の条件を満たしたら、「◯◯ が終わった。次は △△ に入る」と 1 行で示して次の作業に入る。止まるのは関門だけ。作業名を付けて呼んだときは、チェックリストの次の作業と違えば、止まって確かめる（手順を飛ばさないため）。CLAUDE.md の「Step の作業は、人間が `/rails-upgrade [作業名]` で始める」を書き換える
2. 確認のまとめ方。前の論点の結論のまとめを、次の論点と同じメッセージの先頭に区切り線で分けて示し、「違っていれば指摘してください。指摘がなければ同意とみなします。」と書く（まとめへの同意だけの往復をなくす。時間が空いても扱いが分かるように、文言を決める。文言は人間の提案）。最後の論点の質問で、決めたことを並べ直して計画の承認も取る（論点を決めた後の承認の重複をなくす）。掘り下げと「1 回に 1 論点」は変えない
3. 人間が貼るもの（PR のタイトルと本文、PR やレビューへのコメント）は、コピーできるブロックで出す。タイトルは ```` ```text ````、本文は 4 つのバッククォートの ```` ````markdown ````、本文のファイルのパスと、`git push`・`gh pr create --title ... --body-file ...` の `bash` のブロックを添える。質問の締めの文は、論点名を主語にする（「論点 N（<論点名>）は、この見立てでよいですか」。人間の提案）
4. Step 5 の前の小さな PR にする。LOG.md の Step 3〜4-b の「スキルについて気づいたこと」のほかの項目は扱わない
5. （コードレビューで決めた）research で Plan モードを使わない。`resume` の指定は引数なしと同じに扱う。計画に付けたダウンロードの確認は、計画の承認に含む。research で決めた論点は、そのたびに記録に足す（LOG.md の「スキルの見直し」の「コードレビュー」）

### Step 5: Rails 7.2

Step 4-b とスキルの見直しが epic に入ってから、`/rails-upgrade` の research で調べた（Plan モードは使っていない）。作業計画を出し、論点を 1 つずつ確かめてから承認を得た（2026-10-12）。Ruby 3.3.12 のまま Rails を 7.1.6 から 7.2.4 に上げる。その前に、今の Rails で上げられる sqlite3 2.9.6 と annotaterb を上げる。経緯と作業の記録は LOG.md の Step 5。

- [x] gems: sqlite3 2.9.6（3 アプリ。Gemfile `~> 1.4` → `~> 2.9`。bundler-audit の無視リストから sqlite3 の 2 件を消す）
- [x] gems: annotate → annotaterb 4.25.0（OP。`annotate_rb:install` の雛形、`.annotaterb.yml` に旧 rake の 2 つの値、旧 rake の削除。DEF-7.2-01・02）。RP は annotate を外す（着手後に決めた）
- [x] rails-lock: Rails 7.2.4（3 アプリ。tzinfo 2.0.6・useragent 0.16.11 が増え、mutex_m を Gemfile に明示する。無視リストから Rails の 10 件を消す。connection_pool の一時固定の理由がなくなる。DEF-7.2-03〜10）
- [x] rails-app-update（DEF-7.2-11〜21。RP の `autoload_lib_once` と 3 アプリの puma の port は戻し、道具の一覧に足した）
- [x] rails-defaults（`new_framework_defaults_7_2.rb`。グループ 1 使っていない機能 → 2 マイグレーション → 3 YJIT。DEF-7.2-22〜26）
- [x] rails-load-defaults（`load_defaults 7.2`、RuboCop の `TargetRailsVersion` 7.2、`backtrace_silencers.rb` を消した。DEF-7.2-27・28）
- [x] verify（手動確認は、写しを取ってから 1 回。sqlite3 2.x で `-wal` が消え、守るファイルを 12 にした。DEF-7.2-29。CI は push の後）
- [ ] pr

着手時の作業計画で決めたこと（人間が 1 つずつ判断した）:

1. 順番は sqlite3 2.9.6 → annotaterb → Rails 7.2.4。Rails は 7.1.4 から sqlite3 2.x を使える（`activerecord-7.1.6/CHANGELOG.md` の 7.1.4 の節）ので、7 章の振り分けの 1 に当たる。7 章の sqlite3 の行と Step 3 の「調べたこと」の「Rails 7.1 は 1.x だけ」は誤りだった（直した）。sqlite3 は advisory 2 件の修正版で、DB のドライバーの変化と Rails の変化を別のコミットで検査できる
2. mutex_m は、3 アプリの Gemfile の test グループに明示する（理由のコメント付き、版は書かない）。Rails 7.2.4 のコミットに入れる。activesupport 7.2 が依存から外し、lock から消えると、minitest 5.14.4 の `require "mutex_m"` で Ruby 3.3 の bundled_gems の警告が出る（7 章の base64 などの行の「警告が出たら明示」）。minitest は間接の gem なので上げない
3. annotaterb: OP は Gemfile を `annotaterb` にし、`bin/rails g annotate_rb:install` の雛形（`lib/tasks/annotate_rb.rake`・`.annotaterb.yml`）に追随する。旧 rake の値と annotaterb の既定値で違う `hide_limit_column_types`（`integer,bigint,boolean`）・`hide_default_column_types`（`json,jsonb,hstore`）を `.annotaterb.yml` に移し、旧 rake（`rubocop:disable` を含む）を消す。注釈を付け直して差分が出ないことを E2E 用の DB で確かめる。RP は Gemfile を `annotaterb` にするだけで generator は流さない（rake も注釈もなく、hook を入れると使っていない機能を動かし始める）。着手後に、RP は annotate を使っていなかったので、annotaterb に置き換えずに外すことにした（人間が判断。LOG.md の Step 5 の「作業計画からの変更点」）
4. rubocop 1.92.0・webmock 3.27.0〜3.29.0 は Step 5 では上げない。公開から 2 週間たっていない（10-24・10-25）。Step 6 の research の最初に、その時点の最新版で確かめる。webmock の 3 つの版は、メンテナーが溜まった Issue・PR を片付けた区切りごとのリリースで、3.28.0 の破壊的な変更（`to_rack` の `rack.session`）は 3 アプリのテストに当たらない（LOG.md の Step 5）
5. 手動確認は verify で 1 回。直前に、3 アプリの development DB の本体と `-wal` を `tmp/manual_check_backup/` に写す（TIPS.md の「手動確認用の環境」）。OP の「Redirected to」行の `code=` も見る

- 上げないもの: rubocop・webmock（上の 4）、web-console 4.3.0（railties `>= 8.0`。Step 6）、rack 3.x（間接の gem。actionpack 7.2.4 は `rack >= 2.2.4, < 3.3`）、minitest（上の 2）
- ダウンロード: sqlite3 2.9.6-arm64-darwin（3,245,568 B）、annotaterb 4.25.0（65,536 B）、Rails の構成 gem 7.2.4 の 13 個（計 1,839,616 B）、tzinfo 2.0.6（79,360 B）、useragent 0.16.11（14,336 B）。計 5,244,416 B。各 `.gem` は 1 回だけ落として `scripts/verify-gem-checksums` で照合し、ほかのアプリのキャッシュにコピーして `--local` で入れる（Step 4-b の入れ方）。default gem と同じ名前の依存は増えない
- 前後の比較: 設定の「前後の比較」の項目（`check-apps`、`compare-config dump`、`RUBYOPT=-W:deprecated` の警告、development だけのヘッダー（rails-lock のコミットの前に比べる））に、brakeman の EOLRails の無視の項目が 7.2.4 でも当たるかと、OP のテストのログの「Redirected to」行の `code=` を足す
- コミットはアプリごとに RS → RP → OP。PR は 1 つ

調べたこと（着手時の 2026-10-12）。Rails 7.2 の事実と周辺 gem の事実をサブエージェント 2 つで調べ、lock の解決、advisory、mutex_m の警告、sqlite3 と Rails 7.1 の組み合わせ、「Redirected to」の処理、annotaterb の既定値、secret_key_base の読み方は自分で確かめた。

| 項目 | 分かったこと |
|---|---|
| Rails の版 | 7.2.4（2026-09-24、Ruby `>= 3.1.0`）が 7.2 系の最新。7.1.6 は 7.1 系の最新で、先に上げるパッチはない。7.2 のセキュリティ保守は 2026-08-09 に終わっている（endoflife.date。brakeman 8.1.0 の `check_eol_rails.rb` も同じ日）。7.2.4 はその後の版 |
| lock の解決 | `scripts/resolve-lock --gem 'rails=~> 7.2.4' --rails --unpin tzinfo` で、3 アプリとも動くのは Rails の構成 gem と tzinfo 2.0.4 → 2.0.6（activesupport 7.2 は `>= 2.0.5`）だけ。増えるのは useragent 0.16.11（actionpack 7.2 の依存）。解決した lock を、Gemfile を `~> 7.2.4` にしたコピーに持ち込んで `bundle lock` すると、mutex_m 0.2.0 が消える（resolve-lock の出力の「消えた gem」には出ない。Step 3 の method_source と同じ） |
| 依存の要件（7.2.4） | activesupport: `connection_pool >= 2.2.5, < 3`（上限は 7.2.4 から。7-2-stable の 0b6af0411a）、`minitest >= 5.1, < 6`、mutex_m は依存から外れた。actionpack: `rack >= 2.2.4, < 3.3`、`useragent ~> 0.16`。railties: `irb ~> 1.13`、`tsort >= 0.2`、`rackup >= 1.0.0`。default gem と同じ名前の依存は増えない |
| mutex_m | minitest 5.14.4 は `lib/minitest.rb:3` で `require "mutex_m"` する。lock にないと、Ruby 3.3.12 で `mutex_m was loaded from the standard library, but will no longer be part of the default gems starting from Ruby 3.4.0` の警告が出る（minitest 5.14.4 だけの Gemfile で再現した）。Gemfile に明示すると、lock は 0.2.0 のまま `DEPENDENCIES` に足される。minitest は 5.21.0 で mutex_m を使わなくなった |
| advisory | 無視リストなしの bundle-audit（DB は 2026-10-10）で、7.2.4 の lock は Rails の 10 件（actionview CVE-2026-33168、activestorage CVE-2026-33173・33174・33195・33202・33658・66066、activesupport CVE-2026-33169・33170・33176）が 3 アプリとも解消する。sqlite3 1.7.3 の CVE-2026-54619（2.9.5 で修正）・GHSA-mwm8-39rw-8826（2.9.6 で修正）は、sqlite3 2.9.6 で解消する |
| sqlite3 2.9.6 | 2026-08-11、Ruby `>= 3.2`。arm64-darwin・x86_64-linux-gnu のプラットフォーム版がある。Rails は 7.1.4 から 2.x を使え（7.1.6・7.2.4 の adapter は `>= 1.4`）、8.0 は `>= 2.1`。今の 7.1.6 の lock でも 7.2.4 の lock でも、動くのは sqlite3 の行だけ（Linux は `x86_64-linux-gnu` 版。`PLATFORMS` は変わらない）。2.0 の破壊的な変更（`execute` のバインドは配列だけ、結果の freeze、`Translator` の削除）と 2.1 の fork の安全策は、アプリが sqlite3 の API を直接使わず、puma の workers も使わないので当たらない見込み |
| annotaterb 4.25.0 | 2026-09-17、Ruby `>= 3.0`、依存は activerecord・activesupport `>= 6.0`。lock で動くのは annotate → annotaterb の行だけ。旧 rake の設定は読まない（MIGRATION_GUIDE.md）。`annotate_rb:install` は `lib/tasks/annotate_rb.rake`（development で `ANNOTATERB_SKIP_ON_DB_TASKS` がなければ `AnnotateRb::Core.load_rake_tasks`。migrate の後に注釈を付ける）と、既定値の `.annotaterb.yml` を作る。見出し・列・インデックス・外部キーの行の書式は 3.2.0 と同じ。旧 rake の値と既定値で違うのは `hide_limit_column_types`・`hide_default_column_types` だけ（v4.25.0 の `lib/annotate_rb/options.rb`）。v4.23.0 から CI は Ruby 3.3 以上だけを試す |
| annotate の使われ方 | OP は旧 rake で development の migrate の後に注釈を付け、`app/models/user.rb`・`test/fixtures/users.yml` に注釈がある。RP は Gemfile にあるだけで、rake のファイルも注釈もない |
| 「Redirected to」 | rails/rails#51131（7.2.0）で、`ActionDispatch::Http::FilterRedirect#filtered_location` が、`filter_redirect` に当たらないときにクエリの値に `filter_parameters` をかける（v7.2.4 の `filter_redirect.rb`）。専用の設定はない。今の OP の `log/test.log` では、`code=` の付いた「Redirected to」行（6,431 行）の値がすべて生のまま |
| `Rails.application.secrets` | 7.2.0 で削除（rails/rails#49624）。アプリにも lock の gem にも使う箇所はなく（rubocop-rails の cop の説明文だけ）、`config/secrets.yml` もない |
| secret_key_base | 7.2.4 は `ENV["SECRET_KEY_BASE"]` → credentials → `tmp/local_secret.txt` の順（`railties` の `application/configuration.rb`）。3 アプリとも `master.key` がなく、`.env` にも `SECRET_KEY_BASE` はないので、今と同じファイルを読む。守るファイルは 14 のまま |
| 非推奨警告 | 7.1 の非推奨で 7.2 で消える API（`show_exceptions` の true/false、`ActiveSupport::Deprecation` のシングルトン、`Parameters` と Hash の比較など）は 3 アプリで使っていない。7.2 で新しく非推奨になる `ActiveRecord::Base.connection` は警告を出さない。Step 4-b の前後の比較で、テストの DEPRECATION は OP の IMP-011 だけ、eager load の警告は 0（その後アプリのコードは変わっていない） |
| `backtrace_silencers.rb` | 7.2.0 で railties の `backtrace_cleaner.rb` が `BACKTRACE` を扱う（rails/rails#50563・#51670）。3 アプリのファイルの残す理由（Rails 7.1 の railties になく、このファイルだけが担う）がなくなる。雛形には 7.0 からない |
| `app:update`（7.2.4） | 主な雛形の変化（railsdiff/rails-new-output の v7.1.6...v7.2.4）<br>・development.rb: `annotate_rendered_view_with_filenames = true`、mailer の `default_url_options`<br>・test.rb: `public_file_server.enabled` の削除、mailer の `default_url_options`<br>・production.rb、`config/puma.rb`（threads の既定 3、workers などの削除）<br>・`filter_parameter_logging.rb` に `:email`<br>・`bin/setup`、`bin/rubocop`・`bin/brakeman` の追加（Gemfile に rubocop・brakeman があるので作られる見込み）<br>・public の 406 のページとアイコン（RS は API なので作らない）<br>Dockerfile・`.github`・`.rubocop.yml`・`allow_browser`・PWA は新しいアプリだけ |
| `new_framework_defaults_7_2.rb` | 5 項目: `yjit`（Ruby 3.3 以上で有効）、`active_job.enqueue_after_transaction_commit`、`active_storage.web_image_content_types`、`active_record.postgresql_adapter_decode_dates`、`active_record.validate_migration_timestamps`。ジョブ・Active Storage・PostgreSQL は使っていない |
| アップグレードガイド（v7.2） | 2.1「active_job.queue_adapterコンフィグがすべてのテストで尊重されるようになった」、2.2「alias_attributeが元の属性のカスタムメソッドをバイパスするようになった」。ジョブと `alias_attribute` は使っていない |
| ほかの直接の gem | devise 5.0.4・doorkeeper 5.9.9・doorkeeper-openid_connect 2.0.0・activerecord-session_store 2.3.0・jbuilder 2.15.1・omniauth-rails_csrf_protection 2.0.1・rack-mini-profiler 5.0.0・bootsnap 1.26.0・dotenv-rails 3.2.0・a-nti_manner_kick_course 0.5.0 は最新で、Rails 7.2 を許す。annotate 3.2.0 は `activerecord < 8.0`。web-console 4.3.0 は railties `>= 8.0`。rack は 2.2.24 のままなので、devise の `error_status` の非推奨（rack 3.1）は効かない。7.2.4 は `ActionController::UnknownHttpMethod` の応答を 500 から 405 にした |
| gem の置き場所 | 今の lock の gem は 3 アプリとも全部 `vendor/bundle` にある。7.2.4 の lock で足りないのは 15 個（Rails の構成 gem 13・tzinfo・useragent）。手元（`bundle config get path`）も CI（setup-ruby の `bundler-cache`）も `vendor/bundle` から読む |
| rubocop・webmock | rubocop 1.92.0（10-10）。1.91 系のパッチはない。webmock 3.27.0・3.28.0（10-10）・3.29.0（10-11）。3 アプリのテストは `stub_request(...).to_return` と `assert_requested`（RS は `body:` のハッシュで照合）だけを使い、`to_rack`・`hash_excluding` は使わない |

### Step 2〜9

「8. 各 Step 共通の手順」に従う。Step 固有の作業はロードマップの表のとおり。補足:

- **Step 3（Rails 7.1）**: 上の「Step 3: Rails 7.1」の節（rack-mini-profiler 5.0.0 と RP の独自ストラテジーの案 B は、そこに移した）
- **Step 3-b**: 上の「Step 3-b: doorkeeper-openid_connect 2.0.0」の節
- **Step 4（Ruby 3.3）**: 上の「Step 4: Ruby 3.3」の節
- **Step 4-b**: 上の「Step 4-b: simplecov 1.3.2」の節
- **Step 5（Rails 7.2）**: 上の「Step 5: Rails 7.2」の節（sqlite3 2.x、annotate → annotaterb と OP の旧 rake の `rubocop:disable` の見直し、「Redirected to」行の `code=` の確かめは、そこに移した。0-a では Rails 6.1 の制約で `code=` が残ることを許容した）
- **Step 6（Rails 8.0）**: `app:update` が生成する Solid 系・Kamal 系・Thruster 関連のファイルは採用しない

### 仕上げ

- [ ] Dependabot（bundler、npm、GitHub Actions をまとまった単位で更新）。CI ができてから有効にする
- [ ] README の「Tested Environment」を更新。アップグレード前のコードはタグ `rails-6.1` にあること、Next.js 製 RP は新しい OP で確認していないことを書く
- [ ] README の「How to use」に Ruby の入れ方を書く。各アプリの `mise.toml` は初回に `mise trust` が必要なこと、Ruby のバージョンは `.ruby-version` と Gemfile の `ruby` の両方にあること（mise は Gemfile を優先して読む）
- [ ] 各バージョンのサポート終了時期の確認方法を本計画に追記（次回アップグレードへの備え）
- [ ] epic → main をマージコミットで取り込む
- [ ] ルールセット `upgrade-branches`（Step 0-g）の対象に `main` を足す。epic を取り込んだ後に行う（取り込む前は、`main` から切ったブランチの PR で CI が動かず、`ci-result` が待ちのままになる）

## 7. 周辺 gem の更新時期

各 Step の最初に `bundle outdated` を確認し、次の順で振り分ける。

1. 今の Rails のまま上げられる gem → Rails を上げる前に上げる
2. 新しい Rails を必要とする gem → Rails と同時か直後に上げる
3. 下の表で時期を決めた gem → その Step で上げる

Gemfile に書いた直接の gem は、Ruby が対応していて特に不具合がなければ、上げられる時点で最新版に上げる（Step 3 の着手時に人間が決めた）。業務的な挙動が変わるもの（doorkeeper-openid_connect 2.0 など）は、意図的な仕様変更として別のサブステップにする。間接の gem は対象外で、Rails・直接の gem・advisory で必要になったときだけ動かす（default gem に合わせた固定は続ける）。

| gem | 現在 | 時期 | 注意点 |
|---|---|---|---|
| mail | 2.7.1 | 0-a で 2.8.1（済）→ 0-d-3 で 2.9.1（済） | 0-a は Ruby 3.1 で起動するために必要。`--conservative` でも 2.9 系になるので一時的に固定して 2.8.1 にした。0-d-3 は advisory の修正 |
| nokogiri | 1.12.3 | 0-a で 1.18.10（済）→ Step 2 で 1.19.4（済。advisory 12 件を解消） | 1.12 は Ruby 3.1 のネイティブ版がない。1.19 系は Ruby 3.2 以上が必要 |
| jwt（RP は直接使う。RS は oauth2 経由の間接依存。OP はテストが直接使い、doorkeeper-openid_connect 1.8.4 以上の依存） | 2.2.3 | 0-a で RP を 2.5.0（済）→ 0-f-2 で 2.10.3（済。RP は Gemfile に明記、RS は間接のまま）→ 0-f-3 で OP に 2.10.3（済。test グループに明記。一時固定で入れた）→ Step 3 で RP・OP を 3.3.0（済。Rails 7.1 にする前）。RS（間接の依存）は 2.10.3 のまま、間接の gem をまとめて上げるときに上げる（14 章） | RP の `lib/omniauth/strategies/my_op.rb` が直接使うのに Gemfile にない。OpenSSL 3 への対応は 2.5.0 から。advisory（CVE-2026-45363）の修正版は 2.10.3 / 3.2.0。oauth2 を 2.x にしても RS の jwt は上がらないので、RS は oauth2 1.4.7 のうちに jwt を上げる。3.x は Ruby 3.2 を必要としないので Step 2-b の対象外とした。Step 3 の着手時に、直接の gem の方針で上げると決めた。3.0〜3.3 の破壊的な変更（RSA 2048 ビット以上、claim の検証の API の削除、厳しい base64、例外の階層）は、このリポジトリの使い方に当たらない見込み |
| json-jwt（OP、doorkeeper-openid_connect 経由） | 1.13.0 | 0-a で 1.14.0（済）→ 0-f-3 で外れた（済） | OpenSSL 3 への対応は 1.14.0 から。CVE-2023-51774 は未修正だったが、OP は署名だけで decode しないため影響なし。doorkeeper-openid_connect 1.8.4 で jwt に置き換わった。OP の minitest は、0-f-3 で gem を上げる前に ruby-jwt に書き直した |
| nio4r / msgpack | 2.5.8 / 1.4.2 | 0-a で 2.5.9 / 1.4.5（済）。msgpack は 0-d-3 で 1.8.5（済） | 0-a は clang 17 で C 拡張がビルドできないため、同じマイナー内のパッチ版に更新。0-d-3 は advisory の修正 |
| thor（railties 経由） | 1.1.0 | 0-f-1 で 1.5.0（済） | 1.1.0 は Ruby 3.1 で `DidYouMean::SPELL_CHECKERS.merge!` の非推奨警告が出る（起動には影響なし）。1.2.0 で出なくなった。railties 6.1 は `~> 1.0` |
| oauth2 / omniauth-oauth2 | 1.4.7 / 1.7.1 | 0-f-2 で 2.0.25 / 1.9.0（済。同時） | omniauth-oauth2 1.9 は oauth2 2.0.2 以上が必要。RS が `OAuth2::Client` を直接使い、RP が独自ストラテジーを持つので最も壊れやすい。oauth2 2.x は `auth_scheme` の既定値が `:request_body` から `:basic_auth` に、`authorize_url`・`token_url` の既定値が相対パスに変わる（RP の `site` はパス付きなので URL が壊れる）。設定で元の挙動に固定する。advisory（CVE-2026-54603）は 2.0.22 で修正 |
| faraday | 1.7.0 | 0-d-3 で 1.10.6（済）→ 0-f-2 で 2.14.4（済。oauth2 の後。RP は Gemfile に明記） | oauth2 1.4.7 は faraday 2.0 未満を要求する（0-f で gemspec を確認）。RP と RS が直接呼んでいる（RP は Gemfile に明記する）。2.x の advisory は 2.14.3 で修正 |
| faraday-net_http（faraday 2 の依存） | — | 0-f-2 で 3.0.2 に一時固定（済）→ Step 2 で見直し、3.0.2 のまま → Step 8（Ruby 3.4）で見直す（Ruby 3.3.12 の default gem の net-http は 0.4.1、3.4.11 は 0.6.0 で、3.4.x の `~> 0.5` を満たすのは 3.4 から。Step 2 のコードレビューで確かめた） | 3.1 以上は net-http gem に依存し、Ruby 3.1.7 の default gem の net-http・uri を置き換える。3.0.2 は依存がない。3.4.x は net-http `~> 0.5` で、Ruby 3.2.11 の default gem の net-http 0.4.1 では満たせない（Step 2）。3.1〜3.3 は `net-http >= 0` で、lock に net-http が増える |
| doorkeeper / doorkeeper-openid_connect | 5.5.2 / 1.8.0 | 0-f-3 で 5.7.1 / 1.8.9（済。交互に上げた）→ 1-b-3-2 で doorkeeper-openid_connect 1.8.11 → doorkeeper 5.8.2 → doorkeeper-openid_connect 1.10.1 → doorkeeper 5.9.9（済。initializer・ロケール・ビューを雛形に合わせた）→ Step 2-b で doorkeeper-openid_connect 1.10.5（済。`--patch --conservative`。`--conservative` だけでは 2.0.0 になる。initializer・ロケールを雛形に合わせた）→ 2.0.0 は Step 3-b（意図的な仕様変更として扱う。Step 3 の着手時に決めた。マイグレーション・discovery・webfinger の変化と判断は 6 章の「Step 3-b」の節） | doorkeeper-openid_connect 1.10.1 は GHSA-8r7r-wh7x-27ff（DCR の scope。`<= 1.10.3`）の対象だが、DCR を有効にしていないので影響しない（1-b-3-2 の着手時）。修正版の 1.10.4 は Ruby 3.2 以上なので、Step 2-b で上げる。2.0.0 はメジャーで、`post_logout_redirect_uris` の列を足すマイグレーション（#243）が要り、応答も変わる（Step 2-b の着手時）。doorkeeper 6.0 では、トークンを 2 つの方法で渡す要求が 401 から 400 `invalid_request` になる（5.9.7 の CHANGELOG）ので、6.0 に上げるときに `userinfo_bearer_and_param` のスナップショットを見る。openid_connect は 1.8.4 で JWT のライブラリが json-jwt から jwt に変わった（1.8.4〜1.8.7 は kid と `typ` が一時的に変わり、1.8.8 で戻った）。1.8.10 は Rails 6 のサポートをやめ、doorkeeper は 5.8.1 で CI から Rails 6 を外した。1.10.2 以上は Ruby 3.2 以上が必要。doorkeeper 5.5.2 の advisory（CVE-2023-34246）は 5.6.6 で修正された（0-f-3）。必須のマイグレーションはない（0-f の調査で確認）。1.8.9 と 5.6.9 は一時固定で入れたので、版は lock にしか残らない。`--conservative` を付けても `bundle update doorkeeper-openid_connect` は 1.10.1 になり（jwt は test グループに明記した後は 2.10.3 のまま。1-b-3 の調べ）、1.9.0〜1.10.4 は doorkeeper 5.8 未満で discovery が壊れる（1.10.5 の #329）。doorkeeper を 5.8 以上に上げてから openid_connect を上げる |
| devise | 4.8.0 | 0-f-1 で 4.9.4（済）→ 1-b-3-1 で 5.0.4（済。advisory 2 件を解消。initializer を雛形に合わせた） | Rails 8.1 対応は Step 7 の最初に再確認。advisory 2 件は 5.x（5.0.4）でしか修正されず（4.9.4 も対象）、5.x は Rails 7.0 以上が必要（0-d-1 で確認）。initializer の `config.responder.error_status = :unprocessable_entity` は、Rack 3.1 以上で非推奨になる（そのときの雛形は `:unprocessable_content`）。Rack を 3.1 以上にする Step で、雛形に合わせ直す（テストの `assert_response :unprocessable_entity` も） |
| dotenv-rails | 2.7.6 | 0-f-1 で 3.2.0（済） | 読むファイルの順番と、既にある環境変数を上書きしないことは 2.x と同じ。3.x はテストのたびに ENV を戻し、Rails のログに変数名を出す |
| puma | 5.4 | 0-d-3 で 5.6.9（済）→ 0-f-1 で 6.6.1（済）→ Step 3 で 8.0.2（済。7.x は経由しない。直接の gem の方針。DEF-7.1-01〜03） | 7.0・8.0 の破壊的な変更のうち効くのは keep-alive の既定値と応答ヘッダー名の小文字化だけ（Step 3 の着手時）。5.5.0 以降（6.6.1 も）は PROXY protocol v1 の advisory 2 件（CVE-2026-47736 / 47737）の対象で、修正版は 7.2.1 / 8.0.2 だけ。`set_remote_address proxy_protocol: :v1` を設定していないので影響しない（無視リストに入れた） |
| spring | 2.1.1 | 0-f-1 で削除（済） | Rails 7 から標準で入らない。`bin/spring`・`config/spring.rb` も消し、`bin/rails`・`bin/rake` を Rails 7.0 の雛形の形にした |
| byebug / web-console / listen / rack-mini-profiler | — | 0-f-1 で 12.0.0 / 4.2.1 / 3.10.1 / 4.0.1（済）→ listen は Step 1 で外した（済）→ Step 2-b で byebug 13.0.0（済）→ rack-mini-profiler 5.0.0 は Step 3（済。Rails 7.1.6 の直後。DEF-7.1-09）→ web-console 4.3 は Step 6 | 次の版は Ruby 3.2 以上が必要。rack-mini-profiler 5.0.0 は railtie で Rails 7.1 の `Rails.env.local?` を使い、Rails 7.0 の development ではプロファイラーが無効になるので、Rails 7.1 にした後に上げる（Step 2-b の着手時に人間が判断）。web-console 4.3.0 は actionview・railties 8.0 以上も必要（Step 2 の着手時）。byebug 13 は reline `>= 0.6` を依存に足す。rack-mini-profiler 5 は Gemfile の `~> 4.0` を変える必要がある。listen の `EventedFileUpdateChecker` の finalizer の `ThreadError` の警告（LOG.md の Step 0-b）は、3.10.1 でも出る（listen 側も未修正）。Rails 7.0 の development.rb の雛形には `file_watcher` の行がない。Step 1 で雛形に合わせて行を消し、使われなくなる listen を Gemfile から外す（人間が判断）。Step 1 の手動確認で警告が出なくなったことを確かめた。web-console 4.2.1 は development で `ActionDispatch::Request` を initializer より前に読み込む（4.3.0 も同じ。docs/upgrade/defaults/rails-7.0.md の「補足」） |
| sprockets-rails | 3.2.2（間接） | Step 1 で lock から外れた（済。Gemfile には足さない） | Rails 7.0 から rails gem の依存から外れる。3 アプリとも `sprockets/railtie` を読み込んでいない。Gemfile に足すと `Bundler.require` で `sprockets/railtie` が読み込まれ、アセットパイプラインが有効になるので足さない（Step 1） |
| sqlite3 | 1.4.2 | 0-a で 1.7.3（済。clang 17 で 1.4 系がビルドできないため 0-f から前倒し）→ Step 5 で 2.9.6（済。Rails 7.2.4 の前） | Rails は 7.1.4 から 2.x を使える（`activerecord-7.1.6/CHANGELOG.md` の 7.1.4 の節。Step 5 の着手時に分かった。それまでの「Rails 7.1 までは 1.x のみ」は誤り）。8.0 は 2.1 以上必須。1.7.3 の advisory 2 件（CVE-2026-54619・GHSA-mwm8-39rw-8826）は 2.9.6 で解消する |
| annotate | 3.1.1 | Step 1 で 3.2.0（済）→ Step 5 で annotaterb 4.25.0 に置換（済。Rails 7.2.4 の前。OP は generator の雛形に追随（DEF-7.2-01・02）。RP は使っていなかったので外した） | 3.1.1 は `activerecord < 7.0` で、Rails 7.0 にするには 3.2.0 が要る。3.2.0 も `activerecord < 8.0` で、Rails 8 に対応しない（0-f で gemspec を確認）。当初は「注釈の出力が変わるので 3.2.0 には上げない」としたが、Step 1 の調査で、OP の注釈に関わる差分はないと分かった。annotaterb の 4.23 以上は CI で Ruby 3.3 以上だけを試すので、置き換えは Step 5 のまま |
| activerecord-session_store | 2.0.0 | 0-f-1 で 2.1.0（済）→ 1-b-3-1 で 2.2.0（済。multi_json が lock から外れた）→ Step 3 で 2.3.0（済。Rails 7.1.6 と同じコミット。2.2.0 は Rails 7.1 でセッション Cookie の SameSite を落とす。DEF-7.1-06） | 2.2 以上は Rails 7.0 以上が必要。2.1.0 のまま Rails 7.0.10 で解決する（Step 1 の調査） |
| bootsnap / jbuilder / omniauth-rails_csrf_protection | 1.7.7 / 2.11.2 / 1.0.0 | 0-f-1 で bootsnap 1.26.0・jbuilder 2.13.0（済）→ 1-b-3-1 で jbuilder 2.15.1・omniauth-rails_csrf_protection 1.0.2（済。後者は一時固定で入れた）→ Step 3 で omniauth-rails_csrf_protection 2.0.1（済。直接の gem の方針で Step 7 から前倒し） | jbuilder 2.14 以上は Rails 7.0 以上が必要。omniauth-rails_csrf_protection 2.0 の変化は Rails 8.1 だけが対象（8.1 未満は 1.0.2 と同じ処理）。Step 7 で 8.1 用の枝に切り替わるときにもう一度確かめる |
| base64 / bigdecimal / mutex_m など | — | Step 4 で警告が出たら明示（出なかったので明示していない。済）→ Step 5 で mutex_m を明示（済。Rails 7.2.4 で activesupport の依存から外れ、minitest 5.14.4 の `require "mutex_m"` で警告が出る）→ Step 8 で必須 | Ruby 3.4 で標準ライブラリから外れる。Ruby 3.3 の警告は、Bundler の下で lock にない gem を標準ライブラリから読んだときだけ出る。base64・bigdecimal・drb・mutex_m・racc は 3 アプリの lock にあるので、出ない見込みだった（Step 4 の着手時）。Ruby 3.3.12 の `RUBYOPT=-W:deprecated` を付けたテストと eager load で、出なかった（Step 4 の前後の比較） |
| a-nti_manner_kick_course | — | 1-b-1 で 0.5.0 を足す → Rails 8.2 以上で外すかを判断（今回の目標の外なので、epic の間は残す） | development・test だけ。Gemfile の先頭に置く。Rails 8.2 で入る Load hook guard（rails/rails#56201）は既定が警告だけで、`eager_load` が true のときは見ない。README によると、Rails 7.2 以上は `rails runner 1` の代わりに `rails boot` で起動できる |
| rubocop 系 / oxlint 系 | — | 各 Step の最初（rubocop 1.92.0 は 2026-10-10 公開で、Step 4-b の着手時に 2 週間たっていない。Step 5 の着手時（10-12）もたっていないので、Step 6 の最初に確かめる） | バージョン固定。更新は単独コミット |
| brakeman / bundler-audit | 7.1.1 / 0.9.3（0-d-1 で導入） | 各 Step の最初（brakeman 8.0.6 は Step 2-b（済）、8.1.0 は Step 3 の最初。公開から 2 週間の決まりの例外（人間が判断）） | brakeman 8 系は Ruby 3.1 では入らない。8.1.0 は 2026-10-01 公開で、Step 2-b の時点では 2 週間たっていない |
| simplecov / webmock | 0.22.0 / 3.26.4（0-d-2 で導入） | 各 Step の最初（simplecov 1.2.0 は Step 2-b（済。DEF-7.0-50）、1.3.2 は Step 4-b（済。公開から 2 週間の決まりの例外。人間が判断。DEF-7.1-52）。webmock は Step 4 の着手時も 3.26.4。3.27.0〜3.29.0（10-10・10-11）は Step 4-b・Step 5 の着手時に 2 週間たっていないので、Step 6 の最初に確かめる。3.28.0 の破壊的な変更（`to_rack` の `rack.session`）は 3 アプリのテストに当たらない（Step 5 の着手時）） | simplecov 1.x は Ruby 3.2 以上が必要。1.3 は Ruby 3.3 以上（Step 2 の着手時）。1.3.1（2026-09-24）・1.3.2（09-30）。CHANGELOG の Unreleased は Ruby 3.4 以上にする予定（Step 4 の着手時）で、Ruby 3.3 の間は 1.3 系が最後になる見込み |
| json（rubocop 経由） | 2.6.1（0-d-1 で lock に入った） | Step 2 で 2.6.3（済）→ Step 4 で 2.7.2（済）→ Ruby を上げる各 Step で合わせ直す（8 章の 4） | Ruby 3.1.7 の default gem と同じ版。そのままでは 3.0.2 が lock に入り、アプリが読む json が変わるため、一時固定で 2.6.1 にした |
| bigdecimal（webmock → crack 経由） | 3.1.1（0-d-2 で lock に入った） | Step 2 で 3.1.3（済）→ Step 4 で 3.1.5（済）→ Ruby を上げる各 Step で合わせ直す（8 章の 4） | Ruby 3.1.7 の default gem と同じ版。そのままでは 4.1.3 が lock に入り、アプリが読む bigdecimal が変わるため、一時固定で 3.1.1 にした |
| concurrent-ruby（Rails 経由） | 1.1.9 | Step 1 で 1.3.8（済。Rails 7.0.10 にした後） | 1.3.5 以上は Rails 6.1 と 7.0.8.7 では起動しない（LOG.md の Step 0-a、Step 0-d-1）。7.0.10 は activesupport が logger を require する（rails/rails#54264）。advisory は 1.3.7 で解消する |
| benchmark / securerandom / drb / mutex_m（activesupport 7.0.10 経由） | — | Step 1 で一時固定（済。0.3.0 / 0.3.0 / 2.1.0 / 0.1.1。drb の依存の ruby2_keywords 0.0.5 も lock に入った）→ Step 2 で drb 2.1.1・mutex_m 0.1.2（済。benchmark・securerandom は 0.3.0、ruby2_keywords は 0.0.5 のまま）→ Step 4 で drb 2.2.0・mutex_m 0.2.0・securerandom 0.3.1（済。benchmark 0.3.0 は Ruby 3.3.12 の default gem と同じ版になり動かない。benchmark・securerandom は、ここから default gem の版に合わせ直す側。ruby2_keywords は 0.0.5 のまま）→ Step 5 で mutex_m は activesupport 7.2 の依存から外れ、Gemfile に明示した（済。上の base64 などの行）→ Ruby を上げる各 Step で合わせ直す（8 章の 4） | activesupport 7.0.10 の依存。drb・mutex_m は Ruby 3.1.7 の default gem と同じ版。benchmark・securerandom は `>= 0.3` を要求し、default gem（どちらも 0.2.0。Ruby 3.2.11 は 0.2.1・0.2.2）では満たせないので、要件を満たす最小の版にした |
| zeitwerk（railties 経由） | 2.4.2 | Step 1 で 2.6.18（済）→ Step 2-b で 2.7.5 → 2.8.3（済） | railties 7.0 は `~> 2.5`。2.7 は Ruby 3.2 以上が必要。Rails v7.0.10 自身の lock は 2.7.3（Step 2-b の着手時） |
| reline / io-console（byebug 13 経由） | — | Step 2-b で reline 0.6.0・io-console 0.6.0 を一時固定（済）→ Step 4 で io-console 0.7.1（済。reline は 0.6.0 のまま。Ruby 3.3.12 の default gem の 0.5.10 では満たせない）→ Ruby を上げる各 Step で見直す（8 章の 4） | byebug 13 は `reline >= 0.6.0` に依存し、Ruby 3.2.11 の default gem の reline 0.3.2 では満たせない。reline は要件を満たす最小の版（Step 1 の benchmark・securerandom と同じ扱い）、io-console は default gem と同じ版にした。固定しないと reline 0.7.0 と io-console 0.9.4（C 拡張）が入る。lock の reline は、`bin/rails c` の irb（default gem）も読む |
| tsort / irb / cgi（railties・actionpack 7.1 経由） | — | Step 3 で tsort 0.2.0・irb 1.6.2・cgi 0.3.7（RS・OP。RP は既にある）に一時固定（済）→ Step 4 で irb 1.13.1・cgi 0.4.2（済。tsort 0.2.0 は Ruby 3.3.12 の default gem と同じ版になり動かない。tsort は、ここから default gem の版に合わせ直す側。irb の依存は下の rdoc の行）→ Ruby を上げる各 Step で合わせ直す（8 章の 4） | irb・cgi は Ruby 3.2.11 の default gem と同じ版。固定しないと irb 1.18.0（rdoc・rbs・erb・pp・prettyprint を連れてくる）と cgi 0.5.2 が入る。tsort は railties 7.1 が `>= 0.2` を要求し、default gem の 0.1.1 では満たせないので、要件を満たす最小の版にする（Step 3 の着手時） |
| connection_pool（activesupport 7.1 経由） | — | Step 3 で 2.5.5 に一時固定（済）→ Step 5（Rails 7.2.4）で一時固定の理由がなくなった（済。lock は 2.5.5 のまま。activesupport 7.2.4 が `>= 2.2.5, < 3`。7-2-stable の 0b6af0411a。Step 5 の着手時） | 固定しないと 3.0.2 が入る。3.0 はキーワード引数だけを受け付け、Rails 7.1.6 の Redis・Memcache のキャッシュストア（位置引数で渡す）が `ArgumentError` になる（rails/rails#56291）。7-1-stable は直らず、7-2-stable は `< 3` に固定した（#56620）。3 アプリは memory_store・null_store だけを使う（Step 3 の着手時） |
| rack | 2.2.24（間接） | 3.x は時期未定 | Rails 7.1 から rack 3 を使える。間接の gem なので Step 3 では動かさない。Rails 7.1 が足す rack-session・rackup は rack 2 用の 1.x（Step 3 の着手時） |
| rack / loofah・crass・rails-html-sanitizer / websocket-driver / globalid / bcrypt | — | 0-d-3（済） | advisory があり、Rails 6.1・Ruby 3.1 のまま修正版に上げられた。上げた版は LOG.md の Step 0-d-3（mail・msgpack・faraday・puma は上の行） |
| logger（mail 経由） | 1.5.0（0-d-3 で lock に入った） | Step 2 で 1.5.3（済）→ Step 4 で 1.6.0（済）→ Ruby を上げる各 Step で合わせ直す（8 章の 4） | Ruby 3.1.7 の default gem と同じ版。そのままでは 1.7.0 が lock に入り、アプリが読む logger が変わるため、一時固定で 1.5.0 にした |
| base64（websocket-driver 経由） | 0.1.1（0-d-3 で lock に入った） | Step 2 は同じ版（0.1.1）→ Step 4 で 0.2.0（済）→ Ruby を上げる各 Step で合わせ直す（8 章の 4） | Ruby 3.1.7 の default gem と同じ版。そのままでは 0.3.0 が lock に入り、アプリが読む base64 が変わるため、一時固定で 0.1.1 にした |
| cgi（activerecord-session_store 経由、RP） | 0.3.7（0-f-1 で lock に入った） | Step 2 は同じ版（0.3.7）→ Step 4 で 0.4.2（3 アプリ。済）→ Ruby を上げる各 Step で合わせ直す（8 章の 4） | Ruby 3.1.7 の default gem と同じ版。そのままでは 0.5.2 が lock に入り、アプリが読む cgi が変わるため、一時固定で 0.3.7 にした |
| ostruct（doorkeeper-openid_connect 1.8.11 以上経由、OP） | — | 1-b-3-2 で 0.5.2 に一時固定（済）→ Step 2 で 0.5.5（済）→ Step 4 で 0.6.0（済）→ Ruby を上げる各 Step で合わせ直す（8 章の 4） | Ruby 3.1.7 の default gem と同じ版。固定しないと 0.6.3 が lock に入り、アプリが読む ostruct が変わる |
| rdoc / psych / stringio（irb 1.13.1 経由） | — | Step 4 で rdoc 6.6.3.1・psych 5.1.2・stringio 3.1.1 に一時固定（済）→ Ruby を上げる各 Step で合わせ直す（8 章の 4） | irb 1.13.1 は `rdoc >= 4.0.0`、rdoc 6.6.3.1 は `psych >= 4.0.0`、psych 5.1.2 は `stringio` に依存する。どれも Ruby 3.3.12 の default gem と同じ版。固定しないと rdoc 8.1.0・psych 5.5.0（C 拡張）・stringio 3.2.0（C 拡張）が入る（Step 4 の着手時に人間が判断） |
| resolv（default gem。lock にない） | — | Step 8 で見直す | CVE-2026-80212・80213（2026-08-27 告知。resolv `<= 0.3.1`・0.4.0〜0.7.1）は、Ruby 3.2.11 の 0.2 系（修正なし）も 3.3.12 の 0.3.1 も対象。3.3 の修正版 0.3.2 は 3.3.12 に入っていない。Net::HTTP・TCPSocket は OS のリゾルバを使うので対象外。lock の gem で `Resolv` を使うのは bundler-audit と rubocop（開発用の道具）だけで、アプリの実行時には読まれないので、Gemfile に足さずに記録だけにした（Step 4 で人間が判断）。lock にないので bundler-audit は検出しない |
| erb（default gem。lock にない） | — | Step 4 で CVE-2026-41316 を解消（済。Ruby 3.3.12 の default gem の erb 4.0.3.1。入れた Ruby の `ERB.version` で確かめた） | CVE-2026-41316（erb `<= 6.0.3`）は、Ruby 3.1.7 の erb 2.2.3 も 3.2.11 の 4.0.2 も対象。3 アプリに信頼できないデータを `Marshal.load` する経路はないので、Gemfile に足さずに記録だけにした（Step 2 で人間が判断）。Ruby 3.3.12 の default gem は 4.0.3.1、3.4.11 は 4.0.4.1（どちらも修正版）。lock にないので bundler-audit は検出しない |

## 8. 各 Step 共通の手順

スキル化の PR から、この手順は `/rails-upgrade` のスキル（作業ごとの入口の条件・手順・関門・出口と、提示と記録の型。13 章）で進める。下の手順は、スキルが指す決まりとして残す。

1. **調査（スキル化の後は Plan モードを使わない。13 章の 7）**: Rails 公式アップグレードガイドの該当箇所、ruby-jp の各バージョンのナレッジページ、railsdiff.org、`bundle outdated`、メジャー更新する gem の CHANGELOG を確認し、Step の作業計画を出す。**人間の承認を待つ**
   - 調べた事実と根拠（版の要件、CHANGELOG の該当箇所、テストや E2E で守られているか）は、作業計画（リポジトリの外のファイル）だけに残さない。承認を得たら、その Step の節に「調べたこと（着手時に確かめ直す）」として移す。後のサブステップや Step のために調べた分も、それぞれの節に移す
2. **周辺 gem → Rails のパッチ版を最新に → 非推奨警告の解消**: テスト環境で `config.active_support.deprecation = :raise`
3. **Rails のマイナーを上げる**
   - Gemfile を変えて `bundle update rails`
   - `bin/rails app:update` を全上書きで実行し、`git diff` で差分を振り分ける（独自設定は戻す、新しい構成は採用しない）。**差分は人間が確認する**
   - `new_framework_defaults_X_Y.rb` を 1 つずつ有効化してテスト → 全部有効になったら `load_defaults` を上げてファイルを削除
   - RuboCop の `TargetRailsVersion` を上げ、新しい指摘は別コミットで直す
4. **Ruby を上げる場合**: Ruby を上げてコミット → `TargetRubyVersion` を上げて新しい指摘を直す（別コミット）
   - lock に入れた default gem（json・bigdecimal・logger・base64・cgi・ostruct・drb・mutex_m・ruby2_keywords・io-console・irb、Step 4 から irb の依存の rdoc・psych・stringio と、default gem と同じ版になった benchmark・securerandom・tsort）を、新しい Ruby の default gem の版に一時固定で合わせ直す。default gem の版では要件を満たせず、要件を満たす最小の版に固定した gem（reline。benchmark・securerandom・tsort は Step 4 で default gem と同じ版になり、合わせ直す側に移った）は、新しい Ruby の default gem の版で要件を満たせるようになるかを見る。Ruby を上げるコミットに入れ、`BUNDLED WITH` もその Ruby の Bundler の版にする（Step 2）。その Ruby で default gem でなくなったものは 7 章の表に従う。Bundler 2.5.12 以上は、lock にある default gem と同じ版の gem も `vendor/bundle` に入れ、CI もそこから読むので、手元も揃えて入れる（Step 4-b で決めた）。そのための `.gem`（前の版のキャッシュにないもの）は、research でダウンロードの確認に入れる。手順は TIPS.md の「Ruby を上げる」と「gem の更新」
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
- [ ] minitest が全件通る（非推奨警告は `:raise`）。`CI=1`（eager load あり）でも通る
- [ ] 起動の途中の読み込みの検査（`ANTI_MANNER=1 bin/rails runner 1`）が test・development で通る（Step 1-b-1 以降）
- [ ] E2E が全件通り、スナップショットとの比較に差分がない
- [ ] RuboCop で新しい違反がない
- [ ] bundler-audit と brakeman で新しい警告がない
- [ ] 無視リストを空にした設定で bundler-audit を流し、解消した advisory を無視リストから消した
- [ ] lock に入れた default gem と、一時固定した gem の版が、意図せず動いていない（7 章）
- [ ] `bin/rails zeitwerk:check` が通る（Step 1 以降）
- [ ] `db:drop` → `db:setup` で空から作り直して E2E が通る（E2E の起動時に E2E 用の DB で毎回行われる。Step 3 から別のプロセスで流す。RS は `schema.rb` がないので `db:drop` → `db:create`）
- [ ] 公開物の安全チェック（`scripts/check-public-safety --staged`）が通る
- [ ] CI（GitHub Actions）が通る（Step 0-g 以降）
- [ ] 手動確認用の環境（TIPS.md の「手動確認用の環境」のファイル）のハッシュが、作業の前後で同じ（手動確認をした Step は、手動確認の後の値を新しい基準にする）
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
| Rails 7.0 の `load_defaults` で Cookie の鍵生成方式が SHA256 に変わり、既存セッションが無効になる | サンプルなので許容し、ローテーション用のコードは入れない（Step 1 で人間が判断）。対象は OP のセッション Cookie だけ（RP のセッション Cookie は署名のない ID）。E2E は毎回新しいセッションで流す。Step 1 の手動確認で、OP だけが一度ログアウトした状態になることを確かめた（DEF-7.0-36） |
| gem やアプリのコードが、フレームワークのクラス（`ActiveRecord::Base` など）を initializer より前に読み込み、`new_framework_defaults_*.rb` の設定が黙って無視される | 有効にする前後で、test と development の両方の値を `rails runner` で書き出して比べる（Step 1 で RP と web-console で起きた。docs/upgrade/defaults/rails-7.0.md の「補足」）。1-b-1 から、`config/application.rb` と gem の require による読み込みは、CI で a-nti_manner_kick_course が test と development の両方で検出する。ほかの gem の initializer、`config/initializers`、監視の一覧にない `action_dispatch_request`（RP の activerecord-session_store、RP・OP の development の web-console）は検出できないので、引き続き TIPS.md の「設定の値と応答の比較」の方法で手で確かめる |
| Rails 7.1 で RP の独自ストラテジーが Zeitwerk の読み込みに失敗する | Step 3 の案 B で対応。失敗したら案 A |
| gem 更新でマイグレーションの追加が必要になる | gem 更新の手順で確認し、`db:drop db:setup` の完了条件で検出する |
| 時間に依存するテストが不安定になる | minitest は `travel_to`、E2E は期限切れを待たずに revoke で確認 |

## 13. スキル化の計画

1-b-3 と Step 2（Ruby 3.2）・2-b を手作業で通した後に、`/rails-upgrade` を入口とする 1 つのスキルを作る（作業名を引数で渡し、中身は参照用の別ファイルに分ける）。スキルと、下の 5 の「スキル化の PR」のスクリプトを 1 つの PR にし、Step 3 の前に epic に入れる。当初は Step 1 の後に作る計画だったが、Step 1 の後の振り返り（2026-10-09）で振り分けの基準・作業の分け方・作る時期を見直し、スキル化の着手時（2026-10-11）に、スキルの方向と 2 層の構成を人間と決めた。

### 1. スキルの方向（スキル化の着手時に人間と決めた）

- 知識のある担当者が、判断の要る所だけを確かめ、それ以外は AI が再現性のある形で進める
- 担当者だけではアップグレードを完了できない。細部を知らないレビュアーが PR を見て OK を出したら完了とするフローを前提にする。担当者は、なぜ必要かを理解したうえでレビュアーに説明する。スキルの役割は、担当者が説明できる状態の PR を、毎回同じ形で作ること
- レビュアーの物差しは 1 つ。「業務的な挙動（画面、URL、遷移、システム間のやり取り、DB）が変わっていない。変わるなら意図的な仕様変更として書かれている」
- Claude が元から持っている一般的な知識（Rails・Bundler の説明）はスキルに書かない。解説は作業のたびに出典付きで作らせる。スキルが決めるのは、順番・関門・止まる条件・提示と記録の型
- 理由をたどる仕組み: 理由の正本はコミット（1 コミット 1 理由）、PR 本文はコミットへの索引、雛形に合わせず残す独自設定は、その場所のコメントに理由を書く。PR をマージコミットで取り込み、コミットのハッシュが残ることが前提（このリポジトリも、人間のチームも同じ）。DEF（defaults/）・LOG.md・IMP（IMPROVEMENTS.md）への記録は、このリポジトリ固有の上乗せ
- 2 層: 汎用の核（ワークフロー・関門・型）と、リポジトリ固有の設定に分ける。スキル化の PR で分けて作るが、試すのはこのリポジトリだけ（チームでの検証は後に回す）

### 2. 振り分けの基準

| 置き場所 | 書くもの |
|---|---|
| スキルの汎用の核（`.claude/skills/rails-upgrade/`） | 作業ごとの入口の条件・手順・関門・出口の条件と記録、提示と記録の型。リポジトリの文書の名前は持たず、リポジトリ固有の設定を通して指す |
| リポジトリ固有の設定（`.claude/rails-upgrade-project.md`） | 文書の場所、アプリの一覧とコミットの順、検査のコマンド、業務的な挙動の定義、記録の上乗せ、手動確認用の環境。中身は指すだけで写さない |
| リポジトリのスクリプト（`scripts/`） | 3 アプリに固有の道具と、Rails に共通の道具。スキルから呼ぶ。Rails に共通の道具は、チームへ持ち出すときに汎用の核へ移すかを決める |
| PLAN.md・LOG.md・[defaults/](defaults/) | 人間が決めること、版ごとの知識、一度きりのこと |
| [TIPS.md](TIPS.md) | コマンドのつまずきと、使えたやり方。スキルは該当の節を指し、中身を写さない |

### 3. 作業と関門

関門は 2 種類に分ける。判断の関門は、担当者が決めるもの。理解の関門は、担当者がレビュアーに説明できるようにするもので、解説への返事がコミットメッセージ（このリポジトリでは DEF の記録）になり、PR の索引からたどれる。関門と関門の間（検査、lock の解決、`app:update` の後の独自設定の戻し、記録と PR 本文の下書き）は、AI が止まらずに進める。

| # | 作業 | 内容 | 判断の関門 | 理解の関門 |
|---|---|---|---|---|
| 1 | resume | PLAN.md と LOG.md から次の作業を判断する。Step の最初に、前の PR へのリンクのコミットと、手動確認用の環境の控えを行う | — | — |
| 2 | research | 調査と Step の作業計画（8 章の 1）。lock の試行（`--print` と scratchpad のコピー。スキルの見直しの後は Plan モードを使わない）、非推奨警告の確かめ。調べたことを PLAN.md の Step の節に移す | 作業計画の承認 | — |
| 3 | gems | 周辺 gem の振り分け（7 章）と、1 gem ずつの更新。守られていない挙動のテストを先に足す。gem ごとの前後の比較、SHA-256 の照合、無視リストの消し込み、gem の雛形への追随 | ダウンロード、一時固定、B にあたる変化（3 章の 2）、未対応の gem の方針 | gem の既定値・雛形への追随 |
| 4 | ruby | Ruby のバージョンアップ（8 章の 4） | Ruby のダウンロード、default gem の合わせ直しの版、手動確認の時期 | — |
| 5 | rails-lock | Rails のマイナーを上げたときの lock の解決。今のマイナーの最新パッチでなければ、先に同じ方法でパッチを上げる | default gem を置き換える依存の一時固定、依存で増えた gem のダウンロード | — |
| 6 | rails-app-update | `app:update` の振り分け | 差分の確認 | 雛形への追随 |
| 7 | rails-defaults | `new_framework_defaults_*.rb` をグループごとに有効にする繰り返し | グループの順 | 各グループの既定値への追随 |
| 8 | rails-load-defaults | `load_defaults` を上げ、`new_framework_defaults_*.rb` と不要になった initializer を消す。`TargetRailsVersion` を上げる | — | 既定値への追随 |
| 9 | verify | 完了条件（10 章）の確認 | 手動確認の時期 | — |
| 10 | pr | 記録（このリポジトリでは LOG.md）、`/code-review` と指摘の記録、PR のタイトルと本文の提案（PR 本文の型。`scripts/check-public-safety --message` を通す）、PR の後の CI の読み方 | push と PR の作成（人間が行う） | PR 本文が説明できる形になっているか |

当初の 4（rails-minor）を 5〜8 に分け、既定値への追随の解説と記録は、作業をまたぐ手順（`explain.md`）にした。当初の patch（Rails のパッチ版の最新化と非推奨警告）は、一度も通していない（6.1.7.10・7.0.10 とも、その時点の最新パッチだった）ので、rails-lock と research に含めた。当初の record は、PR 本文を作る作業として pr にした。作業をまたぐ手順（理解の関門、コミットの単位、前後の比較、手動確認）は、参照用のファイルに 1 つずつ書く。提示の型（作業計画、質問、ダウンロードの確認、追随の解説、業務的な挙動の変化での停止、コミットの報告、PR 本文、残す独自設定のコメント）は `templates.md` にまとめる。

セッションをまたいでも続きから始められるよう、記録（LOG.md）の Step の節は research の出口で作り、各作業の出口で結果を足し、pr で仕上げる。チェックリストの項目には、先頭に作業名を付ける（resume が項目から作業を推測しないようにするため）。どちらも、スキル化の PR で `/rails-upgrade` を試したときに、スキル自身が挙げた穴（Step の途中では、どこまで終わったかを判断する手がかりが記録にない。項目と作業名が結びつかない）から決めた。

### 4. スキルに書く要点（Step 1・2・2-b で分かったこと）

- rails-lock: `--conservative` を付けても周辺の gem まで動くので、旧 lock の gem を固定し、Rails の構成 gem だけを外して解決させる（`scripts/resolve-lock`）
- rails-app-update: 全上書き → アプリの独自設定を戻す（`scripts/restore-app-config`）→ 使わない機能のマイグレーションを消す → 差分を担当者が確認する
- rails-defaults: グループを決める → 設定の値を test と development の両方で前後比較する（`scripts/compare-config`）→ 応答のスナップショットの差分を見る → 解説（理解の関門）→ 返事 → 記録 → アプリごとのコミット
- gems・ruby: 前後の比較（`scripts/compare-config`、`-W:deprecated`、スナップショット、reline や irb が動くときは `scripts/check-console`）と、落とした `.gem` の照合（`scripts/verify-gem-checksums`）。コマンドのつまずきは TIPS.md の「gem の更新」「Ruby を上げる」
- アプリごとのコミット: ほかのアプリの変更を退避し、そのアプリだけで検査と E2E を流してからコミットする（`scripts/commit-per-app`）
- verify: 10 章（`CI=1` の minitest、無視リストを空にした bundler-audit、lock の default gem の版、`rails c`、手動確認用の環境のハッシュを含む）
- 手動確認: ブラウザペインが画面に出ているかを確かめてから、パスワードの入力と同意を人間に頼む。いつ行うかは Step ごとに人間と決める

### 5. リポジトリのスクリプト

| スクリプト | 中身 | 入れる時期・PR | 確かめ方 |
|---|---|---|---|
| （済）起動の途中の読み込みの検出 | a-nti_manner_kick_course と CI のステップ | 1-b-1 | — |
| （済）応答のスナップショット | 各アプリの minitest | 1-b-2 | — |
| （済）`scripts/check-apps` | 3 アプリの検査（RuboCop、`zeitwerk:check`、起動の途中の読み込み（test・development）、minitest（`CI=1` も）、bundler-audit、brakeman）と E2E。アプリと検査を引数で絞れる | 1-b-3-1 | 1-b-3 と Step 2・2-b で使い、CI と同じ結果になった。CI から呼ぶかは、スキル化の PR で「呼ばない」と決めた（CI に mise がない、CI はステップごとに結果が画面に出る、CI だけの違い（署名鍵、bundler-audit の `--update`）がある）。同じ検査のコマンドが 2 か所にあるので、検査を足すときは両方に足す |
| `scripts/compare-config` | 起動の途中に読み込み済みの部品（`config/application.rb` の後・`config/initializers` の直前・`initialize!` の後）、起動の時点で読み込み済みのモデル、`filter_parameters`、設定の値（クラスに入った値）を test・development で書き出し、前後を比べる | スキル化の PR | Step 1 の `load_defaults 7.0` のコミットの前後で流し、違うのが DEF-7.0-24 だけになること。Step 2-b の doorkeeper-openid_connect 1.10.5 の前後で流し、違うのが `Doorkeeper::AccessGrant` の読み込みだけになること |
| `scripts/resolve-lock` | lock のコピーで、旧 lock の gem を固定し、指定した gem だけを外して解決させ、動く gem を出す | スキル化の PR | タグ `rails-6.1-prepared` の lock で Rails 7.0.10 を解決し、Step 1 の結果（動くのは zeitwerk と annotate だけ）と同じになること。一時固定の版を渡して続けると、Step 1 の lock と同じになること |
| `scripts/restore-app-config` | `app:update` の後に、アプリの独自設定（一覧はスクリプトが持つ）を戻し、使わない機能のマイグレーションを消す | スキル化の PR | タグ `rails-6.1-prepared` の後の Step 1 のコミットを worktree に出して Rails 7.0.10 で `app:update` を流し、Step 1 の `app:update` のコミットと同じになること |
| `scripts/check-console` | `rails c` を擬似端末で起動して入力を試す（Step 2-b の擬似端末のドライバー） | スキル化の PR | 3 アプリで、Step 2-b の記録と同じ表示になること |
| `scripts/verify-gem-checksums` | キャッシュの `.gem` の SHA-256 を rubygems.org の値と比べる | スキル化の PR | Step 2 のコードレビューと同じく、3 アプリのキャッシュがすべて一致すること |
| `scripts/commit-per-app` | ほかのアプリの変更を退避し、そのアプリの検査と E2E を流してからコミットし、退避を戻す | スキル化の PR | 使い捨てのブランチで、成功・検査の失敗・コミットメッセージの検査の失敗のどれでも、退避した変更が戻ること |

Rails のマイナーを上げるときにしか使わない `compare-config`・`resolve-lock`・`restore-app-config` は、Step 3 より前に実際の作業で試せないので、Step 1 を再現して確かめる。

### 6. スキルにしないもの

| もの | 置き場所 |
|---|---|
| 版の選び方などの判断 | PLAN.md・LOG.md |
| 版ごとの設定の中身 | defaults/ |
| 一度きりの修正（RP の serializer の件など） | LOG.md・defaults/ |
| Rails・Bundler の一般的な知識 | 書かない（解説は作業のたびに出典付きで作る） |
| push・PR の作成 | 人間 |
| CI の結果の読み方 | TIPS.md |

### 7. 使ってみて直したこと（Step 4-b の後に人間と決めた）

Step 4-b で、人間が返事をした 16 回のうち、判断を伴うものは 8 回だった。残りは、作業の切り替えのコマンド（5 回）、まとめへの同意と、論点を決めた後の計画の承認（2 回）、PR の本文をコピーできる形で出す依頼（1 回）だった。

- 作業の切り替えは関門にしない。関門と関門の間は止まらずに進める、という 1 の方向を、作業の境目にも当てる。人間が入力するのは、Step の始めの `/rails-upgrade` と、関門での返事だけになる。作業名の指定は、やり直しと飛ばしのために残し、チェックリストと食い違えば止まる
- 確認は、理解したうえで決められる形（選択式にしない、同じ論点のまま掘り下げられる、1 回に 1 論点）を保ったまま、往復を減らす。前の論点のまとめを次の論点と同じメッセージに載せ、最後の論点で計画の承認も取る
- 人間が貼るものは、コピーできるブロックで出す
- research で Plan モードを使わない。Plan モードは、計画の承認をテキストで聞くことを禁じ、承認の画面を必ず出すので、最後の論点で計画の承認を取る形と食い違う（コードレビューで分かった）。research は、アプリと計画のファイルを変えない決まりで行い、書いてよいのは scratchpad と、決めた論点を足す記録の Step の節だけにする。決めた論点はそのたびに記録に足し、セッションが切れても続きから始められるようにする

## 14. 未決事項

- [ ] 最終的に Ruby 4.0 まで上げるか（Step 8 完了時に判断）
- [ ] 間接の依存の gem（Gemfile.lock にだけある gem）を、epic の最後の段階でまとめて上げるか。時期、まとめ方（一度に 1 つの決まりとの折り合い）、default gem に合わせた一時固定の扱いを、人間と相談して決める（Step 3 の着手後に人間が提案。RS の jwt 2.10.3 はそのときに上げる）。伊藤さん式（Qiita「永久保存版！？伊藤さん式・Railsアプリのアップグレード手順」の 4-d・7）は、引数なしの `bundle update` で、結果として間接の gem もまとめて上げる。ruby-jp の「Railsアップグレードガイド」「Rubyアップグレードガイド」は、gem の更新の手順を個別の記事へのリンクに任せていて、間接の gem の記述はない（Step 3 で調べた）
- [x] advisory があり、Rails 6.1・Ruby 3.1 のまま修正版に上げられる gem（7 章の表）を、いつ上げるか（Step 0-d-1 で人間が判断）: 脆弱性の修正だけのサブステップ 0-d-3 を設け、0-d-2 の後、0-e の前に上げる
- [x] `rails_open_id_provider/jwtRS256.key.example` の扱い（Step 0-c で判断）: 鍵の中身のないプレースホルダーで、どこからも参照されていなかったため、`.pub.example` と一緒に削除した

## 15. 決定済みの事項

- ローカルブランチ `feature/rails_migration_plan`（過去の計画とスキルの試作）は参照せず、知見も取り込まない。過去の前提に引きずられるのを避けるため。今回の作業では触れない
