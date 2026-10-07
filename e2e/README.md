# E2E

OP（`rails_open_id_provider`）・RP（`rails_relying_party_of_backend`）・RS（`rails_resource_server`）を通した Playwright の E2E。

## 準備（初回のみ）

各アプリの Ruby の準備（`mise trust` と `bundle install`）を済ませておく。

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
- 失敗したときのトレースとレポートは `test-results/` と `playwright-report/` に出る。Cookie やトークンが入るので公開しない（gitignore 対象）
