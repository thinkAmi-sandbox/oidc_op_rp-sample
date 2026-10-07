import { createHash, randomBytes } from "node:crypto";
import { expect, type APIRequestContext, type Page } from "@playwright/test";
import { OP_URL, RP_URL, RS_URL, rpEnv, rsEnv } from "./apps";
import { approveConsent, signInToOp } from "./op";

/** E2E が my_op 用 RP のクライアントとして取ったトークン応答と、認可リクエストに付けた nonce */
export type CodeFlowResult = {
  tokenResponse: Record<string, unknown>;
  nonce: string;
};

const MY_OP_REDIRECT_URI = `${RP_URL}/auth/my_op/callback`;

function randomString(): string {
  return randomBytes(32).toString("base64url");
}

/**
 * E2E 自身が my_op 用 RP のクライアントとして認可コードフローを行い、トークン応答を返す。
 * RP と同じく scope は openid、nonce と PKCE（S256）を付ける。
 * RP のコールバック URL へのリダイレクトは横取りするので、RP 本体には認可コードが届かない。
 */
export async function authorizeAsMyOpClient(
  page: Page,
  request: APIRequestContext,
  email: string,
): Promise<CodeFlowResult> {
  const state = randomString();
  const nonce = randomString();
  const codeVerifier = randomString();
  const codeChallenge = createHash("sha256").update(codeVerifier).digest("base64url");

  await page.route(`${MY_OP_REDIRECT_URI}?**`, (route) =>
    route.fulfill({ status: 200, contentType: "text/plain", body: "callback captured by E2E" }),
  );

  const authorizeUrl = new URL(`${OP_URL}/oauth/authorize`);
  authorizeUrl.search = new URLSearchParams({
    response_type: "code",
    client_id: rpEnv.CLIENT_ID_OF_MY_OP,
    redirect_uri: MY_OP_REDIRECT_URI,
    scope: "openid",
    state,
    nonce,
    code_challenge: codeChallenge,
    code_challenge_method: "S256",
  }).toString();
  await page.goto(authorizeUrl.toString());
  await signInToOp(page, email);
  await approveConsent(page);

  await page.waitForURL(`${MY_OP_REDIRECT_URI}?**`);
  const callbackParams = new URL(page.url()).searchParams;
  expect(callbackParams.get("state")).toBe(state);
  const authorizationCode = callbackParams.get("code");
  expect(authorizationCode).toBeTruthy();

  const response = await request.post(`${OP_URL}/oauth/token`, {
    form: {
      grant_type: "authorization_code",
      code: authorizationCode ?? "",
      redirect_uri: MY_OP_REDIRECT_URI,
      client_id: rpEnv.CLIENT_ID_OF_MY_OP,
      client_secret: rpEnv.CLIENT_SECRET_OF_MY_OP,
      code_verifier: codeVerifier,
    },
  });
  expect(response.status()).toBe(200);

  return { tokenResponse: await response.json(), nonce };
}

/** RS と同じく、RS のクライアントでクライアントクレデンシャルフローのトークン（scope: introspection）を取る */
async function fetchResourceServerToken(request: APIRequestContext): Promise<string> {
  const response = await request.post(`${OP_URL}/oauth/token`, {
    form: {
      grant_type: "client_credentials",
      client_id: rsEnv.CLIENT_ID_OF_RESOURCE_SERVER,
      client_secret: rsEnv.CLIENT_SECRET_OF_RESOURCE_SERVER,
      scope: "introspection",
    },
  });
  expect(response.status()).toBe(200);
  return (await response.json()).access_token;
}

/** RS と同じ方法（RS のトークンを Bearer で付ける）で OP の introspect を呼ぶ */
export async function introspect(
  request: APIRequestContext,
  accessToken: string,
): Promise<Record<string, unknown>> {
  const response = await request.post(`${OP_URL}/oauth/introspect`, {
    headers: { Authorization: `Bearer ${await fetchResourceServerToken(request)}` },
    form: { token: accessToken },
  });
  expect(response.status()).toBe(200);
  return response.json();
}

/** my_op 用 RP のクライアントとして、アクセストークンを revoke する */
export async function revokeAsMyOpClient(
  request: APIRequestContext,
  accessToken: string,
): Promise<void> {
  const response = await request.post(`${OP_URL}/oauth/revoke`, {
    form: {
      client_id: rpEnv.CLIENT_ID_OF_MY_OP,
      client_secret: rpEnv.CLIENT_SECRET_OF_MY_OP,
      token: accessToken,
    },
  });
  expect(response.status()).toBe(200);
}

/** アクセストークンを Bearer で付けて、RS の API を呼ぶ */
export function fetchApple(request: APIRequestContext, accessToken: string) {
  return request.get(`${RS_URL}/apples/show`, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
}
