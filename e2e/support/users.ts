/** OP の db/seeds.rb で作る E2E 用のユーザー。同意画面の有無が実行順に左右されないよう、シナリオごとに分けている */
export const users = {
  login: "e2e-login@example.com",
  logout: "e2e-logout@example.com",
  resource: "e2e-resource@example.com",
  baseline: "e2e-baseline@example.com",
} as const;

/** seeds と同じダミーのパスワード */
export const E2E_PASSWORD = "e2e-dummy-password";
