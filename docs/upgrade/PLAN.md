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
     1. Rails 以外の gem の既定値の変化も、原則は A と同じく追随する。ただし OP・RP・RS の間のやり取りが変わるもの（oauth2 の `auth_scheme` のように、相手が受け付けなくなりうるもの）は B として扱い、その都度人間に確かめる。既存のやり取りの方法が不適切で、ライブラリに追随したほうがよい場合もあるため
     2. 描画される文字・遷移・送信内容が同じなら、Rails が出すタグの形が変わっても A（`button_to` の `<button>` など）
     3. A による追随が起きたら、コミットの前に、項目ごとに「何が変わるか・なぜ起きたか・今回のアプリへの影響・提案」を解説し、人間の返事をもらってからコミットする。出典として、Rails の PR・CHANGELOG・gem のソースに加え、日本語版の Rails ガイドに該当の節があればページと見出しを示す。ガイドは上げる先の版のページ（例: `https://railsguides.jp/v7.0/`）を使い、その版になければ最新版のページを使って、そう明記する。同じ内容を `docs/upgrade/defaults/`（Rails の版ごとのファイル）に ID を振って記録し、LOG.md とコミットメッセージからは ID で指す。記録は、返事をもらった後、設定のコミットより前の docs のコミットで足す（設定のコミットのメッセージから、既にある ID を指せるようにするため）。「意図的な仕様変更」は B を変えるときだけに使う
     4. アプリが意図して書いた設定（理由のコメントがある、業務に関わる）は残す。昔の雛形の値が残っているだけの設定は、新しい雛形に合わせる。迷うものはその都度人間に確かめる
     5. 既にある部品の設定・既定値の変化は A。gem・インフラ・部品を新しく足すもの（4 の新しい構成）と、使っていない機能を動かし始めるもの（Active Storage のマイグレーションなど）は採用しない
     6. 一度きりの移行の影響（Cookie の鍵の算出方式が変わり、ログインが一度切れるなど）は A として追随し、移行用のコードは書かない
     7. ログの出力の変化は A。アプリが足した伏せる対象（`filter_parameters` の `:code`）は 4 にあたるので残す
     8. A で E2E のスナップショット、または minitest の応答のスナップショット（Step 1-b-2）が変わったときは、理由を確かめたうえで更新し、LOG.md に書く。スナップショットの更新は、変化を起こしたコミットに一緒に入れる。B にあたる変化が出たら、更新せずに止まって人間に確かめる
3. 脆弱性が公表されている gem の修正は即時に行う。設定の改善（PKCE 必須化、secret のハッシュ化など）は epic を main に取り込んだ後に別作業で行う。見送った改善は [docs/IMPROVEMENTS.md](../IMPROVEMENTS.md) に記録する
4. `app:update` が提案する新しい構成（Propshaft、Solid Queue/Cache/Cable、Kamal、Thruster など）は採用しない
5. 伊藤さん式の「ステージング確認・本番デプロイ」は、「3 アプリ通しの E2E ＋ OP の応答のスナップショットとの比較＋ PR レビュー」に置き換える

## 4. ブランチと PR

| 項目 | 内容 |
|---|---|
| 固定 | `main`（タグ `rails-6.1`）。作業中は変更しない |
| タグ `rails-6.1-prepared` | Ruby 3.1.7 / Rails 6.1.7.10、Step 0 完了時点。epic の PR [#20](https://github.com/thinkAmi-sandbox/oidc_op_rp-sample/pull/20) のマージコミット |
| epic | `epic/rails-8.1-upgrade`（`main` から作成。開始を示す空コミットあり） |
| 作業ブランチ | `upgrade/<step>-<内容>`。epic から切り、PR の向き先は epic |
| PR の単位 | Step 0 はサブステップ（0-a〜0-g。0-d は 0-d-1・0-d-2・0-d-3、0-f は 0-f-1・0-f-2・0-f-3 に分ける）ごと。0-f の gem 更新は、各 PR の中で gem ごとにコミット。Step 1 以降は 1 Step = 1 PR（Step 1 の後のサブステップ 1-b は、1-b-1（起動の途中の読み込みの検出）・1-b-2（応答のスナップショットのテスト）・1-b-3（周辺 gem）の 3 つの PR に分ける） |
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
| 1-b | 3.1 | 7.0 | 起動の途中の読み込みを CI で検出する（1-b-1。a-nti_manner_kick_course）、3 アプリの応答のスナップショットのテスト（1-b-2）、Rails 7.0 以上を必要とする周辺 gem（1-b-3。devise 5.x、doorkeeper 5.8 以上など） |
| 2 | **3.2** | 7.0 | Ruby のみ |
| 3 | 3.2 | **7.1.x** | `app:update`、`autoload_lib_once`（RP の独自ストラテジー対応） |
| 4 | **3.3** | 7.1 | Ruby のみ |
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

- [ ] 3 アプリに `test/integration/response_snapshot_test.rb`（1 テスト 1 応答）、伏せる処理の `test/support/response_snapshot_helper.rb`（3 アプリで同じ内容）、スナップショットの `test/snapshots/responses/<名前>.txt` を足す（RS → RP → OP の順に、アプリごとのコミット）
- [ ] 実行ごとに同じになること（seed を変えて 2 回、`CI=1`）と、わざと壊すと落ちることを確かめる（確かめた後で戻す）
- [ ] 更新の方法と扱いを TIPS.md・CLAUDE.md に書く
- 着手時の作業計画で決めたこと（人間が承認）
  - 番号: この作業を 1-b-2 とし、周辺 gem を 1-b-3 に移す。ブランチは `upgrade/step1b-response-snapshot`
  - 対象の応答: Step 1 の書き出し（OP 20・RP 5・RS 2）に足して、RS 3・RP 11・OP 26。足すのは、RS の introspect が `active: false` の 401、RP の introspection 用の画面・認可要求・コールバック・コールバックの後の画面・ID トークンの検証に失敗したコールバック・`/auth/failure`、OP のログイン成功・`/users/sign_up`・クライアントクレデンシャルのトークン・revoke の後の introspect・同意画面を省く認可要求・`/oauth/applications`。`/oauth/authorized_applications`（fixtures の作成時刻を表示する）と `/oauth/applications/:id`（client secret を表示する）、使っていない経路は足さない
  - 時刻は各テストで `travel_to` で固定し、時刻の値（`created_at`・`iat`・`exp`）も伏せずに比べる
  - ヘッダーは名前を小文字にして並べ替える。値は比べ、`X-Request-Id`・`X-Runtime` と、本文から決まる `ETag`・`Content-Length` は値だけを伏せる（ヘッダーがあるかどうかは比べる）。`Set-Cookie` は名前と属性を比べ、値だけを伏せる
  - 伏せる値は、ヘッダー名・クエリのパラメーター名（`code`・`state`・`nonce`・`code_challenge`）・hidden field の名前・JSON のキー（`access_token`・`refresh_token`・`id_token`、JWKS の `n`・`kid`）で決める。文字列の形では伏せない。`client_id`・ユーザー ID（fixtures で決まる）・`expires_in` は伏せない
  - JSON の本文は、キーの順を変えずに整形する（E2E のスナップショットはキーを並べ替える）。伏せた値は E2E と同じく型を残す（`<ACCESS_TOKEN:string>`）
  - 更新は `UPDATE_SNAPSHOTS=1 bin/rails test`。ファイルがないときは、この環境変数がなければ失敗する（E2E の扱いにそろえる）。更新したときの扱いは 3 章の 2 の境目の 8
  - development だけの応答の差（`Server-Timing`、rack-mini-profiler・web-console）と、test 環境では出ない CSRF のトークンは、このテストでも E2E でも扱わない。Rails を上げる Step で、これまでどおり development の応答ヘッダーを `curl` で見る
  - CI は変えない（既存の `bin/rails test` がこのテストも流し、スナップショットのファイルは `public-safety` ジョブの検査の対象に入る）
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

1-b-2 が epic に入ってから、調べて作業計画を出す。候補は Step 1 の「決めたこと」と 7 章。

### Step 2〜9

「8. 各 Step 共通の手順」に従う。Step 固有の作業はロードマップの表のとおり。補足:

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

| gem | 現在 | 時期 | 注意点 |
|---|---|---|---|
| mail | 2.7.1 | 0-a で 2.8.1（済）→ 0-d-3 で 2.9.1（済） | 0-a は Ruby 3.1 で起動するために必要。`--conservative` でも 2.9 系になるので一時的に固定して 2.8.1 にした。0-d-3 は advisory の修正 |
| nokogiri | 1.12.3 | 0-a で 1.18.10（済）→ Step 2 で 1.19 系最新 | 1.12 は Ruby 3.1 のネイティブ版がない。1.19 系は Ruby 3.2 以上が必要 |
| jwt（RP は直接使う。RS は oauth2 経由の間接依存。OP はテストが直接使い、doorkeeper-openid_connect 1.8.4 以上の依存） | 2.2.3 | 0-a で RP を 2.5.0（済）→ 0-f-2 で 2.10.3（済。RP は Gemfile に明記、RS は間接のまま）→ 0-f-3 で OP に 2.10.3（済。test グループに明記。一時固定で入れた） | RP の `lib/omniauth/strategies/my_op.rb` が直接使うのに Gemfile にない。OpenSSL 3 への対応は 2.5.0 から。advisory（CVE-2026-45363）の修正版は 2.10.3 / 3.2.0。oauth2 を 2.x にしても RS の jwt は上がらないので、RS は oauth2 1.4.7 のうちに jwt を上げる |
| json-jwt（OP、doorkeeper-openid_connect 経由） | 1.13.0 | 0-a で 1.14.0（済）→ 0-f-3 で外れた（済） | OpenSSL 3 への対応は 1.14.0 から。CVE-2023-51774 は未修正だったが、OP は署名だけで decode しないため影響なし。doorkeeper-openid_connect 1.8.4 で jwt に置き換わった。OP の minitest は、0-f-3 で gem を上げる前に ruby-jwt に書き直した |
| nio4r / msgpack | 2.5.8 / 1.4.2 | 0-a で 2.5.9 / 1.4.5（済）。msgpack は 0-d-3 で 1.8.5（済） | 0-a は clang 17 で C 拡張がビルドできないため、同じマイナー内のパッチ版に更新。0-d-3 は advisory の修正 |
| thor（railties 経由） | 1.1.0 | 0-f-1 で 1.5.0（済） | 1.1.0 は Ruby 3.1 で `DidYouMean::SPELL_CHECKERS.merge!` の非推奨警告が出る（起動には影響なし）。1.2.0 で出なくなった。railties 6.1 は `~> 1.0` |
| oauth2 / omniauth-oauth2 | 1.4.7 / 1.7.1 | 0-f-2 で 2.0.25 / 1.9.0（済。同時） | omniauth-oauth2 1.9 は oauth2 2.0.2 以上が必要。RS が `OAuth2::Client` を直接使い、RP が独自ストラテジーを持つので最も壊れやすい。oauth2 2.x は `auth_scheme` の既定値が `:request_body` から `:basic_auth` に、`authorize_url`・`token_url` の既定値が相対パスに変わる（RP の `site` はパス付きなので URL が壊れる）。設定で元の挙動に固定する。advisory（CVE-2026-54603）は 2.0.22 で修正 |
| faraday | 1.7.0 | 0-d-3 で 1.10.6（済）→ 0-f-2 で 2.14.4（済。oauth2 の後。RP は Gemfile に明記） | oauth2 1.4.7 は faraday 2.0 未満を要求する（0-f で gemspec を確認）。RP と RS が直接呼んでいる（RP は Gemfile に明記する）。2.x の advisory は 2.14.3 で修正 |
| faraday-net_http（faraday 2 の依存） | — | 0-f-2 で 3.0.2 に一時固定（済）→ Ruby を上げる各 Step で見直す | 3.1 以上は net-http gem に依存し、Ruby 3.1.7 の default gem の net-http・uri を置き換える。3.0.2 は依存がない |
| doorkeeper / doorkeeper-openid_connect | 5.5.2 / 1.8.0 | 0-f-3 で 5.7.1 / 1.8.9（済。交互に上げた）→ 5.8 以上・1.8.10 以上は Step 1-b → doorkeeper-openid_connect 1.10.2 以上は Step 2 の後 | openid_connect は 1.8.4 で JWT のライブラリが json-jwt から jwt に変わった（1.8.4〜1.8.7 は kid と `typ` が一時的に変わり、1.8.8 で戻った）。1.8.10 は Rails 6 のサポートをやめ、doorkeeper は 5.8.1 で CI から Rails 6 を外した。1.10.2 以上は Ruby 3.2 以上が必要。doorkeeper 5.5.2 の advisory（CVE-2023-34246）は 5.6.6 で修正された（0-f-3）。必須のマイグレーションはない（0-f の調査で確認）。1.8.9 と 5.6.9 は一時固定で入れたので、版は lock にしか残らない。`--conservative` を付けても `bundle update doorkeeper-openid_connect` は 1.10.1 と jwt 3.3.0 になり、1.9.0〜1.10.4 は doorkeeper 5.8 未満で discovery が壊れる（1.10.5 の #329）。doorkeeper を 5.8 以上に上げてから openid_connect を上げる |
| devise | 4.8.0 | 0-f-1 で 4.9.4（済）→ Step 1-b で 5.x | Rails 8.1 対応は Step 7 の最初に再確認。advisory 2 件は 5.x（5.0.4）でしか修正されず（4.9.4 も対象）、5.x は Rails 7.0 以上が必要（0-d-1 で確認） |
| dotenv-rails | 2.7.6 | 0-f-1 で 3.2.0（済） | 読むファイルの順番と、既にある環境変数を上書きしないことは 2.x と同じ。3.x はテストのたびに ENV を戻し、Rails のログに変数名を出す |
| puma | 5.4 | 0-d-3 で 5.6.9（済）→ 0-f-1 で 6.6.1（済）→ 7.2.1 以上 | 7 系に上げる時期は後の Step で判断。5.5.0 以降（6.6.1 も）は PROXY protocol v1 の advisory 2 件（CVE-2026-47736 / 47737）の対象で、修正版は 7.2.1 / 8.0.2 だけ。`set_remote_address proxy_protocol: :v1` を設定していないので影響しない（無視リストに入れた） |
| spring | 2.1.1 | 0-f-1 で削除（済） | Rails 7 から標準で入らない。`bin/spring`・`config/spring.rb` も消し、`bin/rails`・`bin/rake` を Rails 7.0 の雛形の形にした |
| byebug / web-console / listen / rack-mini-profiler | — | 0-f-1 で 12.0.0 / 4.2.1 / 3.10.1 / 4.0.1（済）→ listen は Step 1 で外した（済）→ Step 2 の後に byebug 13・web-console 4.3・rack-mini-profiler 5 | 次の版は Ruby 3.2 以上が必要。listen の `EventedFileUpdateChecker` の finalizer の `ThreadError` の警告（LOG.md の Step 0-b）は、3.10.1 でも出る（listen 側も未修正）。Rails 7.0 の development.rb の雛形には `file_watcher` の行がない。Step 1 で雛形に合わせて行を消し、使われなくなる listen を Gemfile から外す（人間が判断）。Step 1 の手動確認で警告が出なくなったことを確かめた。web-console 4.2.1 は development で `ActionDispatch::Request` を initializer より前に読み込む（4.3.0 も同じ。docs/upgrade/defaults/rails-7.0.md の「補足」） |
| sprockets-rails | 3.2.2（間接） | Step 1 で lock から外れた（済。Gemfile には足さない） | Rails 7.0 から rails gem の依存から外れる。3 アプリとも `sprockets/railtie` を読み込んでいない。Gemfile に足すと `Bundler.require` で `sprockets/railtie` が読み込まれ、アセットパイプラインが有効になるので足さない（Step 1） |
| sqlite3 | 1.4.2 | 0-a で 1.7.3（済。clang 17 で 1.4 系がビルドできないため 0-f から前倒し）→ Step 5 で 2.x | Rails 7.1 までは 1.x のみ、8.0 は 2.1 以上必須 |
| annotate | 3.1.1 | Step 1 で 3.2.0（済）→ Step 5 で annotaterb に置換 | 3.1.1 は `activerecord < 7.0` で、Rails 7.0 にするには 3.2.0 が要る。3.2.0 も `activerecord < 8.0` で、Rails 8 に対応しない（0-f で gemspec を確認）。当初は「注釈の出力が変わるので 3.2.0 には上げない」としたが、Step 1 の調査で、OP の注釈に関わる差分はないと分かった。annotaterb の 4.23 以上は CI で Ruby 3.3 以上だけを試すので、置き換えは Step 5 のまま |
| activerecord-session_store | 2.0.0 | 0-f-1 で 2.1.0（済）→ Step 1-b | 2.2 以上は Rails 7.0 以上が必要。2.1.0 のまま Rails 7.0.10 で解決する（Step 1 の調査） |
| bootsnap / jbuilder / omniauth-rails_csrf_protection | 1.7.7 / 2.11.2 / 1.0.0 | 0-f-1 で bootsnap 1.26.0・jbuilder 2.13.0（済）→ jbuilder 2.14 以上と omniauth-rails_csrf_protection 1.0.2 は Step 1-b、omniauth-rails_csrf_protection 2.x は Step 7 | jbuilder 2.14 以上は Rails 7.0 以上が必要。omniauth-rails_csrf_protection 2.0 の変化は Rails 8.1 だけが対象 |
| base64 / bigdecimal / mutex_m など | — | Step 4 で警告が出たら明示 → Step 8 で必須 | Ruby 3.4 で標準ライブラリから外れる |
| a-nti_manner_kick_course | — | 1-b-1 で 0.5.0 を足す → Rails 8.2 以上で外すかを判断（今回の目標の外なので、epic の間は残す） | development・test だけ。Gemfile の先頭に置く。Rails 8.2 で入る Load hook guard（rails/rails#56201）は既定が警告だけで、`eager_load` が true のときは見ない。README によると、Rails 7.2 以上は `rails runner 1` の代わりに `rails boot` で起動できる |
| rubocop 系 / oxlint 系 | — | 各 Step の最初 | バージョン固定。更新は単独コミット |
| brakeman / bundler-audit | 7.1.1 / 0.9.3（0-d-1 で導入） | 各 Step の最初 | brakeman 8 系は Ruby 3.1 では入らない |
| simplecov / webmock | 0.22.0 / 3.26.4（0-d-2 で導入） | 各 Step の最初 | simplecov 1.x は Ruby 3.2 以上が必要（Step 2 の後に上げられる） |
| json（rubocop 経由） | 2.6.1（0-d-1 で lock に入った） | Ruby を上げる各 Step で合わせ直す（8 章の 4） | Ruby 3.1.7 の default gem と同じ版。そのままでは 3.0.2 が lock に入り、アプリが読む json が変わるため、一時固定で 2.6.1 にした |
| bigdecimal（webmock → crack 経由） | 3.1.1（0-d-2 で lock に入った） | Ruby を上げる各 Step で合わせ直す（8 章の 4） | Ruby 3.1.7 の default gem と同じ版。そのままでは 4.1.3 が lock に入り、アプリが読む bigdecimal が変わるため、一時固定で 3.1.1 にした |
| concurrent-ruby（Rails 経由） | 1.1.9 | Step 1 で 1.3.8（済。Rails 7.0.10 にした後） | 1.3.5 以上は Rails 6.1 と 7.0.8.7 では起動しない（LOG.md の Step 0-a、Step 0-d-1）。7.0.10 は activesupport が logger を require する（rails/rails#54264）。advisory は 1.3.7 で解消する |
| benchmark / securerandom / drb / mutex_m（activesupport 7.0.10 経由） | — | Step 1 で一時固定（済。0.3.0 / 0.3.0 / 2.1.0 / 0.1.1。drb の依存の ruby2_keywords 0.0.5 も lock に入った）→ Ruby を上げる各 Step で合わせ直す（8 章の 4） | activesupport 7.0.10 の依存。drb・mutex_m は Ruby 3.1.7 の default gem と同じ版。benchmark・securerandom は `>= 0.3` を要求し、default gem（どちらも 0.2.0）では満たせないので、要件を満たす最小の版にした |
| zeitwerk（railties 経由） | 2.4.2 | Step 1 で 2.6.18（済） | railties 7.0 は `~> 2.5`。2.7 は Ruby 3.2 以上が必要 |
| rack / loofah・crass・rails-html-sanitizer / websocket-driver / globalid / bcrypt | — | 0-d-3（済） | advisory があり、Rails 6.1・Ruby 3.1 のまま修正版に上げられた。上げた版は LOG.md の Step 0-d-3（mail・msgpack・faraday・puma は上の行） |
| logger（mail 経由） | 1.5.0（0-d-3 で lock に入った） | Ruby を上げる各 Step で合わせ直す（8 章の 4） | Ruby 3.1.7 の default gem と同じ版。そのままでは 1.7.0 が lock に入り、アプリが読む logger が変わるため、一時固定で 1.5.0 にした |
| base64（websocket-driver 経由） | 0.1.1（0-d-3 で lock に入った） | Ruby を上げる各 Step で合わせ直す（8 章の 4） | Ruby 3.1.7 の default gem と同じ版。そのままでは 0.3.0 が lock に入り、アプリが読む base64 が変わるため、一時固定で 0.1.1 にした |
| cgi（activerecord-session_store 経由、RP） | 0.3.7（0-f-1 で lock に入った） | Ruby を上げる各 Step で合わせ直す（8 章の 4） | Ruby 3.1.7 の default gem と同じ版。そのままでは 0.5.2 が lock に入り、アプリが読む cgi が変わるため、一時固定で 0.3.7 にした |

## 8. 各 Step 共通の手順

1. **調査（Plan モード）**: Rails 公式アップグレードガイドの該当箇所、ruby-jp の各バージョンのナレッジページ、railsdiff.org、`bundle outdated`、メジャー更新する gem の CHANGELOG を確認し、Step の作業計画を出す。**人間の承認を待つ**
   - 調べた事実と根拠（版の要件、CHANGELOG の該当箇所、テストや E2E で守られているか）は、作業計画（リポジトリの外のファイル）だけに残さない。承認を得たら、その Step の節に「調べたこと（着手時に確かめ直す）」として移す。後のサブステップや Step のために調べた分も、それぞれの節に移す
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
- [ ] CI（GitHub Actions）が通る（Step 0-g 以降）
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
