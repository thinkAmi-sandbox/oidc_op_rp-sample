import { expect, test } from "@playwright/test";
import { OP_URL, RP_URL, RS_URL } from "../support/apps";

test("OP の discovery が issuer を返す", async ({ request }) => {
  const response = await request.get(`${OP_URL}/.well-known/openid-configuration`);

  expect(response.status()).toBe(200);
  expect((await response.json()).issuer).toBe(OP_URL);
});

test("RP のトップページにログインボタンが出る", async ({ page }) => {
  await page.goto(RP_URL);

  await expect(page.getByRole("button", { name: "Login" })).toBeVisible();
});

test("RS はトークンなしのリクエストを 401 で拒否する", async ({ request }) => {
  const response = await request.get(`${RS_URL}/apples/show`);

  expect(response.status()).toBe(401);
});
