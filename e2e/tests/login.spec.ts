import { expect, test } from "@playwright/test";
import { RP_URL } from "../support/apps";
import { approveConsent, signInToOp } from "../support/op";
import { users } from "../support/users";

test("RP から OP でログインして同意すると、RP にユーザーのメールアドレスが表示される", async ({
  page,
}) => {
  await page.goto(RP_URL);

  await page.getByRole("button", { name: "Login" }).click();
  await signInToOp(page, users.login);
  await approveConsent(page);

  // RP の独自ストラテジーが ID トークン（署名・iss・aud・nonce など）を検証できたときだけ、ここに来る
  await expect(page).toHaveURL(`${RP_URL}/`);
  await expect(page.getByText("ログインしました")).toBeVisible();
  await expect(page.getByText(`Logged in as ${users.login}`)).toBeVisible();
});
