# E2E

OP（`rails_open_id_provider`）・RP（`rails_relying_party_of_backend`）・RS（`rails_resource_server`）を通した Playwright の E2E。

## 準備（初回のみ）

各アプリの Ruby の準備（`mise trust` と `bundle install`）を済ませておく。Node.js の版は `.node-version` にあり、mise（`mise.toml` の設定で読む）と GitHub Actions の `actions/setup-node` の両方が読む。

```bash
cd e2e
mise trust
mise install
npm ci
npx playwright install chromium
```

## 実行

手動確認用のサーバー（`.claude/launch.json` など）は止めておく。E2E は同じポート（3780〜3782）で 3 アプリを起動する。動いていると起動に失敗する。

```bash
cd e2e
npm test
```

- 3 アプリは development 環境のまま、E2E 専用の DB（各アプリの `db/e2e.sqlite3`）で起動する。DB は毎回作り直す（`scripts/start-server.sh`）
- RP / RS の環境変数は各アプリの `.env_e2e` を使う。手元の `.env` より優先される
- OP の署名鍵 `rails_open_id_provider/jwtRS256.key` がなければ作る。あれば手動確認用の鍵をそのまま使う
- 失敗したときのトレースとレポートは `test-results/` と `playwright-report/` に出る。Cookie やトークン（手元では手動確認用の署名鍵で署名した ID トークン）が入るので公開しない（gitignore 対象）
- 起動スクリプト（`scripts/start-server.sh`）は、mise があれば `mise exec` で各アプリの `.ruby-version` の Ruby を使い、なければ PATH の Ruby を使う

## CI（GitHub Actions）

`.github/workflows/ci.yml` の `e2e` ジョブが、手元と同じ `npm test` を流す。

- Ruby は `ruby/setup-ruby`（各アプリの `.ruby-version`）、Node.js は `actions/setup-node`（`.node-version`）で入れる。mise は使わない
- ブラウザは手元と同じ headless shell だけを、毎回 `npx playwright install --with-deps --only-shell chromium` で入れる
- OP の署名鍵は、起動スクリプトが毎回新しく作る
- 失敗したときは、`test-results/`・`playwright-report/` と 3 アプリの `log/development.log` を artifact `e2e-failure` に 7 日残す。リポジトリは public なので、サインインした誰でも取得できる。中のトークン・Cookie・署名鍵は CI の使い捨ての環境のもので、ユーザーの資格情報は元からリポジトリにあるダミー
