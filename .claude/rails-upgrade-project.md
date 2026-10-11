# /rails-upgrade のリポジトリ固有の設定

`.claude/skills/rails-upgrade/` のスキル（汎用の核）が「設定の◯◯」として指す節。このリポジトリの文書・道具・アプリの一覧を引くための索引で、中身は指す先の文書にあり、ここには写さない。スキルの方向と、このファイルを分けた理由は docs/upgrade/PLAN.md の 13 章。

## 作業のルール

- CLAUDE.md（アップグレードのルール、人間との分担、テスト、公開物への記載ルール、安全チェックの仕組み）
- 出典の決まり（PR・CHANGELOG・gem のソースと、上げる先の版の日本語版 Rails ガイドの節）: CLAUDE.md の「アップグレードのルール」
- gem が新しい Rails に未対応のときの選び方（①〜④。決めるのは人間）: CLAUDE.md の「アップグレードのルール」
- 採用しない新しい構成（Propshaft、Solid 系、Kamal、Thruster など）: CLAUDE.md の「アップグレードのルール」
- 公開物の安全チェック: `scripts/check-public-safety`（`--staged`・`--files`・`--message`）

## 計画

- docs/upgrade/PLAN.md
  - ロードマップ: 5 章。Step ごとのチェックリストと「調べたこと」: 6 章
  - 周辺 gem の更新時期と、lock に入れた default gem・一時固定した gem の一覧: 7 章
  - 各 Step 共通の手順（Ruby を上げるときの default gem の合わせ直しを含む）: 8 章
  - 完了条件: 10 章
- 版の選び方: 公開から 2 週間以上たった版（PLAN.md の Step 0-g・2-b の決めたこと）。マイナーは飛ばさない（3 章の 1）

## 記録

- docs/upgrade/LOG.md: Step ごとの節（先頭の「記録のテンプレート」の形）。節は research の出口で作り（作業計画で決めたこと）、各作業の出口で結果を足し、pr で仕上げる（スキル化の PR で決めた。それまでは Step の最後にまとめて書いていた）。前の Step の PR へのリンクは、次の Step の最初のコミットで足す（「docs: link the step ... pull request in the upgrade log」）
- PLAN.md のチェックリストの項目は、先頭に作業名を付ける（例: `- [ ] gems: doorkeeper 5.9.9`、`- [ ] verify`、`- [ ] pr`）
- 記録の上乗せ
  - 既定値・雛形への追随: docs/upgrade/defaults/（Rails の版ごとのファイル。ID は `DEF-<版>-<連番>`。記録のルールは defaults/README.md）。理解の関門の返事をもらったら、設定のコミットより前の docs のコミットで記録する
  - 見送った改善: docs/IMPROVEMENTS.md（ID は `IMP-<連番>`。足すときは人間の承認が要る）
  - 意図的な仕様変更（業務的な挙動を変えるもの）: PLAN.md の Step の節と LOG.md
- コミットメッセージ: 英語の Conventional Commits（件名は `build(<アプリのディレクトリ>):`・`chore(...)`・`docs:` など）。本文に理由を書き、記録の上乗せの ID を `Refs: DEF-7.0-01` のように指す。末尾に Co-Authored-By。`\u` を含むときは TIPS.md の「コミット」

## 業務的な挙動の定義

- docs/upgrade/PLAN.md の 3 章の 2（A: Rails の既定値・雛形の変化 → 追随する。B: 各システムの業務的な挙動 → 変えない。境目の扱い 1〜8）

## アプリの一覧とコミットの順

| 順 | 略称 | ディレクトリ | 役割 | ポート |
|---|---|---|---|---|
| 1 | rs | `rails_resource_server/` | RS | 3782 |
| 2 | rp | `rails_relying_party_of_backend/` | RP | 3781 |
| 3 | op | `rails_open_id_provider/` | OP | 3780 |

- コミットはアプリごとに、RS → RP → OP の順。PR は Step ごとに 1 つ（PLAN.md の 2 章・4 章）
- E2E（`e2e/`）は 3 アプリを通して流す。`nextjs_*` は対象外

## 検査のコマンド

- `scripts/check-apps`（3 アプリの検査と E2E。`--app rs|rp|op`、`--no-e2e`、`--e2e-only`）。個々のコマンドと期待する結果は TIPS.md の「確認のコマンド」
- CI（`.github/workflows/ci.yml`）も同じ検査を流す。CI は `check-apps` を呼ばない（PLAN.md の 13 章の 5）

## 道具

| 道具 | 使う作業 |
|---|---|
| `scripts/check-apps` | すべて（検査と E2E） |
| `scripts/compare-config` | 前後の比較（設定の値と、起動の途中に読み込み済みの部品） |
| `scripts/resolve-lock` | rails-lock（lock の解決） |
| `scripts/restore-app-config` | rails-app-update（独自設定の戻し） |
| `scripts/check-console` | verify・前後の比較（`rails c`、byebug） |
| `scripts/verify-gem-checksums` | gems・ruby・rails-lock（落とした・コピーした `.gem` の照合） |
| `scripts/commit-per-app` | コミット（ほかのアプリの変更を退避 → 検査 → コミット → 戻す） |

使い方は各スクリプトの `--help` と、下の「作業ごとの参照」の TIPS.md の節。

## 作業ごとの参照

| 作業 | 見るところ |
|---|---|
| research | TIPS.md の「gem の更新」（`--print` で lock を書かずに試す、`--patch`、advisory の確かめ方）。advisory は ruby-advisory-db にないものがある（gem のリポジトリの advisory も見る。LOG.md の Step 1-b-3-1）。非推奨警告は TIPS.md の「確認のコマンド」 |
| gems | TIPS.md の「gem の更新」（一時固定、default gem と同じ名前の依存、SHA-256）、PLAN.md の 7 章。gem の雛形への追随の前例は defaults/ の「周辺 gem」の節 |
| ruby | TIPS.md の「Ruby を上げる」、PLAN.md の 8 章の 4。Ruby の版を持つファイルは PLAN.md の Step 2 の「調べたこと」の「Ruby の版に依存する箇所」 |
| rails-lock | TIPS.md の「gem の更新」（Rails のマイナーを上げるときの lock の解決） |
| rails-app-update | PLAN.md の 8 章の 3。前例は defaults/rails-7.0.md の「`app:update` の雛形」 |
| rails-defaults | TIPS.md の「設定の値と応答の比較」「応答のスナップショット」。前例は PLAN.md の Step 1 の「`new_framework_defaults_7_0.rb` を有効にする順番」と defaults/rails-7.0.md |
| verify | PLAN.md の 10 章、TIPS.md の「確認のコマンド」「rails c を確かめる」「手動確認用の環境」 |
| pr | CLAUDE.md の「ブランチと PR」、TIPS.md の「CI の結果を読む」 |

## 前後の比較

変更の前に取り、後に取って比べるもの（TIPS.md の「Ruby を上げる」の前後の比較、「設定の値と応答の比較」）。

- `scripts/check-apps` の結果と件数（応答のスナップショットと E2E のスナップショットの差分を含む）
- `scripts/compare-config dump <ラベル>`（3 アプリ、test と development）
- `RUBYOPT=-W:deprecated` を付けた development の eager load とテストの警告の行（TIPS.md の「Ruby を上げる」）
- reline・irb が動くとき: `scripts/check-console`
- brakeman を上げるとき: JSON の出力の警告の fingerprint（LOG.md の Step 2-b）
- Rails を上げるとき: development だけのヘッダー（TIPS.md の「設定の値と応答の比較」の最後）

## 手動確認用の環境

- 守るファイルと確かめ方: TIPS.md の「手動確認用の環境」（9 ファイルのハッシュ、件数は `sqlite3 -readonly`）
- 基準の件数: LOG.md の最後の手動確認の節

## 手動確認

- 起動: `.claude/launch.json` の設定でプレビューから 3 アプリを起動する（TIPS.md の「手動確認用の環境」）
- パスワードの入力と同意は人間が行う。頼む前にブラウザペインが画面に出ているかを確かめる（CLAUDE.md の「人間との分担」）
- 流れ: RP の my_op でのログインと、introspection 用 RP の流れ（「Login」ボタンから。LOG.md の Step 2-b の「手動確認」）

## ブランチと PR

- CLAUDE.md の「ブランチと PR」（作業ブランチは `epic/rails-8.1-upgrade` から `upgrade/<step>-<内容>`、PR の向き先は epic、本文は `--body-file`、マージコミットで取り込む）
- push と PR の作成は人間が行う。AI はタイトル（日本語）と本文を提案し、本文は `scripts/check-public-safety --message` を通す
