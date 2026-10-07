import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { parseEnv } from "node:util";

const repoRoot = resolve(__dirname, "..", "..");

/** リポジトリ直下からの相対パスで .env 形式のファイルを読む。process.env には入れない */
export function readEnvFile(pathFromRepoRoot: string): Record<string, string> {
  const parsed = parseEnv(readFileSync(resolve(repoRoot, pathFromRepoRoot), "utf8"));
  return Object.fromEntries(
    Object.entries(parsed).filter((entry): entry is [string, string] => entry[1] !== undefined),
  );
}
