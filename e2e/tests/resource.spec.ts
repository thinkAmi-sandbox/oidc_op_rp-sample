import { expect, test } from "@playwright/test";
import { RP_URL } from "../support/apps";
import {
  authorizeAsMyOpClient,
  fetchApple,
  introspect,
  revokeAsMyOpClient,
} from "../support/oauth";
import { approveConsent, signInToOp } from "../support/op";
import { users } from "../support/users";

// RP の introspection 画面は RS の応答を画面に出さず、サーバーの標準出力に出すだけなので、
// RS が受け付ける・拒否することは、E2E から RS を直接呼んで確かめる

test("introspection 用 RP でログインすると、RP が revoke したトークンを RS は拒否する", async ({
  page,
  request,
}) => {
  await page.goto(`${RP_URL}/introspection`);
  await page.getByRole("button", { name: "Login" }).click();
  await signInToOp(page, users.resource);
  await approveConsent(page);

  // コールバックで RP は RS を 3 回呼び（正しいトークン・改ざんしたトークン・revoke 後のトークン）、
  // 最後に revoke 済みのアクセストークンを flash に出して introspection 画面へ戻る
  await expect(page).toHaveURL(`${RP_URL}/introspection`);
  const notice = page.getByRole("paragraph");
  await expect(notice).toHaveText(/^\s*[\w-]+\s*$/);
  const revokedToken = (await notice.textContent())?.trim() ?? "";

  expect((await fetchApple(request, revokedToken)).status()).toBe(401);
  expect(await introspect(request, revokedToken)).toEqual({ active: false });
});

test("有効なトークンでは RS がりんごの情報を返し、revoke した後は拒否する", async ({
  page,
  request,
}) => {
  const { tokenResponse } = await authorizeAsMyOpClient(page, request, users.resource);
  const accessToken = String(tokenResponse.access_token);

  const before = await fetchApple(request, accessToken);
  expect(before.status()).toBe(200);
  expect(await before.json()).toEqual({ name: "シナノゴールド" });

  await revokeAsMyOpClient(request, accessToken);

  expect((await fetchApple(request, accessToken)).status()).toBe(401);
});
