import { expect, test } from "@playwright/test";
import { OP_URL } from "../support/apps";
import { decodeJwt, toBaseline } from "../support/baseline";
import { authorizeAsMyOpClient, introspect, revokeAsMyOpClient } from "../support/oauth";
import { users } from "../support/users";

// 基準応答は e2e/baseline/ にある。意図して変わったときだけ `npx playwright test --update-snapshots` で更新する

test("discovery が基準応答と一致する", async ({ request }) => {
  const response = await request.get(`${OP_URL}/.well-known/openid-configuration`);

  expect(response.status()).toBe(200);
  expect(toBaseline(await response.json())).toMatchSnapshot("discovery.json");
});

test("JWKS が基準応答と一致する（kid と n は伏せる）", async ({ request }) => {
  const response = await request.get(`${OP_URL}/oauth/discovery/keys`);

  expect(response.status()).toBe(200);
  expect(toBaseline(await response.json())).toMatchSnapshot("jwks.json");
});

test("認可コードフローのトークン応答・ID トークン・userinfo・introspect が基準応答と一致する", async ({
  page,
  request,
}) => {
  const { tokenResponse, nonce } = await authorizeAsMyOpClient(page, request, users.baseline);
  const accessToken = String(tokenResponse.access_token);
  const idToken = decodeJwt(String(tokenResponse.id_token));

  const userinfoResponse = await request.get(`${OP_URL}/oauth/userinfo`, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  expect(userinfoResponse.status()).toBe(200);
  const userinfo = await userinfoResponse.json();
  const activeIntrospection = await introspect(request, accessToken);
  await revokeAsMyOpClient(request, accessToken);
  const revokedIntrospection = await introspect(request, accessToken);

  // 伏せる値のうち、他の応答や要求と一致すべきものは先に確かめる
  expect(idToken.payload.nonce).toBe(nonce);
  expect(userinfo.sub).toBe(idToken.payload.sub);
  // 1 回のフローで得た応答をまとめて比べる。最初の差分で止まらず、すべての差分を報告するよう soft にする
  expect.soft(toBaseline(tokenResponse)).toMatchSnapshot("token.json");
  expect.soft(toBaseline(idToken.header)).toMatchSnapshot("id-token-header.json");
  expect.soft(toBaseline(idToken.payload)).toMatchSnapshot("id-token-payload.json");
  expect.soft(toBaseline(userinfo)).toMatchSnapshot("userinfo.json");
  expect.soft(toBaseline(activeIntrospection)).toMatchSnapshot("introspect-active.json");
  expect.soft(toBaseline(revokedIntrospection)).toMatchSnapshot("introspect-revoked.json");
});
