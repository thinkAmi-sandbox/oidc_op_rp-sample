import { expect, test } from "@playwright/test";
import { RP_URL } from "../support/apps";
import { approveConsent, signInToOp } from "../support/op";
import { users } from "../support/users";

test("RP からログアウトすると RP のセッションだけが破棄され、OP のセッションは残る", async ({
  page,
}) => {
  await page.goto(RP_URL);
  await page.getByRole("button", { name: "Login" }).click();
  await signInToOp(page, users.logout);
  await approveConsent(page);
  await expect(page.getByText(`Logged in as ${users.logout}`)).toBeVisible();

  await page.getByRole("link", { name: "Logout" }).click();

  await expect(page).toHaveURL(`${RP_URL}/`);
  await expect(page.getByText("ログアウトしました")).toBeVisible();
  await expect(page.getByText(`Logged in as ${users.logout}`)).toBeHidden();
  await expect(page.getByRole("button", { name: "Login" })).toBeVisible();

  // RP はログアウトを OP に伝えない（sessions_controller.rb のコメントのとおり）。
  // OP のセッションと同意済みのトークンが残るので、OP のログイン画面も同意画面も経ずに RP へ戻る
  await page.getByRole("button", { name: "Login" }).click();

  await expect(page).toHaveURL(`${RP_URL}/`);
  await expect(page.getByText("ログインしました")).toBeVisible();
  await expect(page.getByText(`Logged in as ${users.logout}`)).toBeVisible();
});
