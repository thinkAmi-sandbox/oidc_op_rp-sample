import { defineConfig, devices } from "@playwright/test";
import { OP_URL, RP_URL, RS_URL, rpEnv, rsEnv } from "./support/apps";

// 各アプリは development 環境のまま、E2E 専用の DB を使う（scripts/start-server.sh）
const E2E_DATABASE_URL = "sqlite3:db/e2e.sqlite3";

export default defineConfig({
  testDir: "./tests",
  // 3 アプリは 1 プロセスずつで、DB は sqlite のため、テストは 1 つずつ流す
  fullyParallel: false,
  workers: 1,
  forbidOnly: true,
  retries: 0,
  reporter: [["list"], ["html", { open: "never" }]],
  use: {
    // トレースやスクリーンショットには Cookie やトークンが入る。保存先は gitignore 対象
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
  },
  projects: [{ name: "chromium", use: { ...devices["Desktop Chrome"] } }],
  // ポートは手動確認用と同じ（issuer や RS の URL がコードに固定されているため）。
  // 手動確認用のサーバーが動いているときに、その DB へ E2E を流さないよう、既存のサーバーは使わない
  webServer: [
    {
      name: "OP",
      command: "scripts/start-server.sh op",
      url: `${OP_URL}/.well-known/openid-configuration`,
      env: { DATABASE_URL: E2E_DATABASE_URL },
      reuseExistingServer: false,
      timeout: 120_000,
    },
    {
      name: "RP",
      command: "scripts/start-server.sh rp",
      url: RP_URL,
      env: { ...rpEnv, DATABASE_URL: E2E_DATABASE_URL },
      reuseExistingServer: false,
      timeout: 120_000,
    },
    {
      name: "RS",
      command: "scripts/start-server.sh rs",
      // トークンなしでは 401 を返す。Playwright は 401 も起動済みとみなす
      url: `${RS_URL}/apples/show`,
      env: { ...rsEnv, DATABASE_URL: E2E_DATABASE_URL },
      reuseExistingServer: false,
      timeout: 120_000,
    },
  ],
});
