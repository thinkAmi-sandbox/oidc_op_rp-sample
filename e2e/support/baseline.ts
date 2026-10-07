/**
 * 基準応答（e2e/baseline/*.json）と比べるための整形。
 * 毎回変わる値（トークン・時刻・nonce・鍵）は伏せ、構造と固定の値を比べる。
 * キーは並べ替えて、項目の順番の違いを差分にしない。
 */

const MASKS: Record<string, string> = {
  access_token: "<ACCESS_TOKEN>",
  refresh_token: "<REFRESH_TOKEN>",
  id_token: "<ID_TOKEN>",
  created_at: "<TIMESTAMP>",
  iat: "<TIMESTAMP>",
  exp: "<TIMESTAMP>",
  auth_time: "<TIMESTAMP>",
  nonce: "<NONCE>",
  // ユーザーの ID。seeds の順番で変わるので伏せ、ID トークンと userinfo で一致することは別に確かめる
  sub: "<USER_ID>",
  // JWKS と ID トークンのヘッダー。署名鍵は環境ごとに違う
  kid: "<KID>",
  n: "<MODULUS>",
};

function maskValue(value: unknown): unknown {
  if (Array.isArray(value)) {
    return value.map(maskValue);
  }
  if (value !== null && typeof value === "object") {
    return Object.fromEntries(
      Object.keys(value)
        .sort()
        .map((key) => {
          const child = (value as Record<string, unknown>)[key];
          return [key, key in MASKS ? MASKS[key] : maskValue(child)];
        }),
    );
  }
  return value;
}

/** exp と iat がある場合は、伏せる前に有効期間（秒）を「exp - iat」として残す */
function withLifetime(value: Record<string, unknown>): Record<string, unknown> {
  if (typeof value.exp === "number" && typeof value.iat === "number") {
    return { ...value, "exp - iat": value.exp - value.iat };
  }
  return value;
}

/** 基準応答のファイルに書く形（伏せた JSON、末尾に改行）にする */
export function toBaseline(value: Record<string, unknown>): string {
  return `${JSON.stringify(maskValue(withLifetime(value)), null, 2)}\n`;
}

/** JWT の各部（ヘッダー・ペイロード）を JSON として読む。署名の検証はしない（RP の検証はログインのシナリオで確かめる） */
export function decodeJwt(jwt: string): {
  header: Record<string, unknown>;
  payload: Record<string, unknown>;
} {
  const [header, payload] = jwt
    .split(".")
    .slice(0, 2)
    .map((part) => JSON.parse(Buffer.from(part, "base64url").toString("utf8")));
  return { header, payload };
}
