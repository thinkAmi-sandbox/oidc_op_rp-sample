import { expect, type Page } from "@playwright/test";
import { OP_URL } from "./apps";
import { E2E_PASSWORD } from "./users";

/** OP のログイン画面（Devise）にいる状態から、E2E 用のユーザーでログインする */
export async function signInToOp(page: Page, email: string): Promise<void> {
  await expect(page).toHaveURL(`${OP_URL}/users/sign_in`);
  await page.getByLabel("Email").fill(email);
  await page.getByLabel("Password").fill(E2E_PASSWORD);
  await page.getByRole("button", { name: "Log in" }).click();
}

/** OP の同意画面（doorkeeper）が出ていることを確かめてから、Authorize を押す */
export async function approveConsent(page: Page): Promise<void> {
  await expect(page.getByRole("heading", { name: "Authorization required" })).toBeVisible();
  await page.getByRole("button", { name: "Authorize" }).click();
}
