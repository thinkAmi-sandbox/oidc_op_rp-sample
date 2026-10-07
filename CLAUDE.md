# CLAUDE.md

OpenID Connect の OpenID Provider（OP）、Relying Party（RP）、Resource Server（RS）を Rails で実装したサンプルリポジトリ。

| ディレクトリ | 役割 | ポート |
|---|---|---|
| `rails_open_id_provider/` | OP（doorkeeper / doorkeeper-openid_connect / devise） | 3780 |
| `rails_relying_party_of_backend/` | RP（omniauth / 独自ストラテジー `lib/omniauth/strategies/my_op.rb`） | 3781 |
| `rails_resource_server/` | RS（OP の introspection でアクセストークンを検証） | 3782 |
| `nextjs_*` | Next.js 製 RP。**今回のアップグレードの対象外** | — |

## 作業を始めるとき

1. `docs/upgrade/PLAN.md`（計画・進捗）と `docs/upgrade/LOG.md`（判断の記録）を読み、次に行う Step を確認する。コマンドの実行や確認の手順は `docs/upgrade/TIPS.md`（作業のコツ）を参照する
2. 現在のブランチを確認する。作業ブランチは `epic/rails-8.1-upgrade` から切る
3. クローン直後は `git config core.hooksPath .githooks` を実行して git hooks を有効にする。あわせて `git config blame.ignoreRevsFile .git-blame-ignore-revs` で、見た目だけのコミットを git blame から外す
4. Ruby は mise で管理する。各アプリの `mise.toml`（`.ruby-version` を読ませる設定）は、初回に各アプリのディレクトリで `mise trust` を実行しないと読まれない

## アップグレードのルール

- 一度に上げるのは 1 つだけ（Ruby / Rails / 周辺 gem を同時に上げない）。マイナーバージョンは飛ばさない
- アップグレード中は挙動を変えない。例外は PLAN.md に「意図的な仕様変更」として明記したものだけで、LOG.md に記録する
- 脆弱性が公表されている gem の修正だけは即時に行ってよい。設定の改善（PKCE 必須化、secret のハッシュ化など）は epic を main に取り込んだ後に別作業で行う
- `rails app:update` が提案する新しい構成（Propshaft、Solid Queue/Cache/Cable、Kamal、Thruster など）は採用しない
- テスト・E2E・RuboCop・安全チェックが通らない状態でコミットしない
- 動作保証は development / test 環境のみ。`config/environments/production.rb` は `app:update` の雛形に追従するだけにする
- gem が新しい Rails に未対応のときは、①対応版を待つ ②GitHub の未リリース版 ③自前パッチ ④別 gem に置換、の順で検討し、**どれを選ぶかは人間が判断する**
- Step が終わるたびに LOG.md を更新し、PLAN.md のチェックリストを更新する

## ブランチと PR

- `main` はアップグレード前の状態で固定する（タグ `rails-6.1`）。`main` に直接コミットしない
- 作業ブランチは `epic/rails-8.1-upgrade` から切り、名前は `upgrade/<step>-<内容>`（例: `upgrade/step0a-boot-ruby31`）
- **PR の向き先は `epic/rails-8.1-upgrade`**。`gh pr create --base epic/rails-8.1-upgrade` を必ず付ける
- PR 本文は `--body-file` で渡す（Claude Code hooks が本文を検査するため）
- epic への PR の取り込みも、epic → main の取り込みも、マージコミットで行う（squash・rebase はしない。`.git-blame-ignore-revs` のコミットのハッシュを残すため）

## 人間との分担

- 判断が必要なことは、1 回に 1 つの論点だけ、根拠（ファイルと行、調べた事実）と見立てを添えて、テキストで質問する
- 各 Step は、調査して作業計画を出し、人間の承認を待ってからファイルを変更する
- ダウンロードが発生するもの（gem、npm パッケージ、Playwright のブラウザ、Ruby / Node など）は、入れる前に名前・バージョン・サイズを示して確認する
- 手動確認用のローカル環境（各アプリの development DB、`.env`、OP の署名鍵）を消す・作り直す操作（`db:drop`、`db:reset`、seeds の投入など）は、実行する前に確認する
- ブラウザでのパスワードの入力と、OP の同意画面の「Authorize」は人間が行う。依頼するときは、ブラウザペインが画面に出ているかを確かめてから声をかける
- コミットメッセージ・ドキュメント・PR 本文では、まだ存在しないもの（これから作るテストなど）を現在形で書かない
- push と PR の作成は人間が行う。AI は PR のタイトルと本文を提案し、本文は `scripts/check-public-safety --message` を通してからチャットにも出す

## テスト

- アプリ内のテストは minitest（RSpec は導入しない）。外部通信は WebMock で差し替える
- テストは「現在の挙動を記録する」ためのもの。仕様は変えない。落ちたらまずアプリ側の変化を疑う
- 1 テスト 1 振る舞い。準備・実行・確認の順に書く。時間に依存するテストは `travel_to` で固定し、`sleep` は使わない
- 3 アプリ通しの E2E はリポジトリ直下の `e2e/`（Playwright）。E2E が通ることを各 Step の完了条件にする。実行方法は `e2e/README.md`

## 公開物への記載ルール

ドキュメント・コミットメッセージ・PR 本文・コードのコメントは公開物として扱い、ローカル環境の情報と秘密情報を書かない。

| 種類 | 書き方 |
|---|---|
| リポジトリ内のパス | リポジトリ相対パス（例: `rails_open_id_provider/config/initializers/doorkeeper.rb`） |
| gem 内のパス | `gem名-バージョン/` から書く（例: `doorkeeper-5.8.0/lib/doorkeeper/engine.rb`） |
| その他のローカルパス | `<HOME>` / `<RUBY_PREFIX>` / `<PREFIX>` / `<TMP>` に置き換える。ツールの規定の場所は `~/` 表記でよい |
| ユーザー名・ホスト名・プロンプト | 書かない。コマンドはプロンプトなしで書く |
| メールアドレス | 書かない（例示が必要なら `user@example.com`） |
| 環境情報 | 「macOS (arm64)」程度まで |
| トークン・秘密情報 | `<AUTH_CODE>`（認可コード） / `<ACCESS_TOKEN>` / `<ID_TOKEN>` / `<CLIENT_SECRET>` / `<REDACTED>` に置き換える。テスト用の値でもドキュメントには貼らない。ログを貼るときは、`[FILTERED]` になっていない値（OP の「Redirected to」行の `code=` など）が残っていないか確認する |
| 書いてよいもの | `localhost` のポート番号、gem / Ruby のバージョン、エラークラスとメッセージ |

- スタックトレースは全文を貼らず、エラークラス・メッセージ・アプリ側の行（相対パス）・最初の gem の行だけを残す
- テスト結果は件数と要約だけを書く（例: `42 runs, 0 failures`）
- `git add -A` / `git add .` は使わず、ファイルを指定してステージする
- `git commit --no-verify`（`-n`）は使わない

### 安全チェックの仕組み

- 検査本体は `scripts/check-public-safety`。`.githooks/pre-commit`・`.githooks/commit-msg` と `.claude/settings.json` の hooks から呼ばれる
- 指摘が出たら、出力の「修正案」に従って直す。リポジトリ配下の絶対パスは `scripts/check-public-safety --fix --files <path>` で自動置換できる
- 誤検出の除外は `.public-safety-allow` に書くが、**追記には人間の承認が必要**。AI が独断で追記したり、検出条件を緩めたりしない
