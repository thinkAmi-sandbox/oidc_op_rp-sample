---
name: rails-upgrade
description: Ruby / Rails のアップグレードを、決めた順番・関門・提示の型で進める。人間が `/rails-upgrade [作業名]` と打ったときだけ使う。作業名がなければ、計画と記録から次の作業を判断する（resume）。
argument-hint: "[resume|research|gems|ruby|rails-lock|rails-app-update|rails-defaults|rails-load-defaults|verify|pr]"
disable-model-invocation: true
---

# Rails のアップグレード

指定された作業: `$ARGUMENTS`（空なら resume）

## このスキルの役割

- 知識のある担当者が、関門で判断し、説明を理解する。関門と関門の間は、AI が決めた手順で止まらずに進める
- アップグレードは担当者だけでは完了しない。細部を知らないレビュアーが PR を見て OK を出したら完了。だから、担当者がレビュアーに説明できる状態の PR を、毎回同じ形で作る
- レビュアーの物差しは 1 つ。「業務的な挙動が変わっていない。変わるなら、意図的な仕様変更として書かれている」。業務的な挙動の定義は設定の「業務的な挙動の定義」

## 最初に読むもの

1. リポジトリ固有の設定 `${CLAUDE_PROJECT_DIR}/.claude/rails-upgrade-project.md`。このスキルの「設定の◯◯」は、このファイルの節を指す。文書の場所・アプリの一覧・道具は、ここから引く
2. 設定の「作業のルール」「計画」「記録」と、下の表の作業のファイル

## 全作業の約束

- このスキルには、手順の順番・関門・止まる条件・提示と記録の型だけを書いてある。Rails・Bundler の一般的な知識は書いていない。解説と判断の材料は、作業のたびに一次の出典（PR、CHANGELOG、gem のソース、ガイドの節）で確かめて示す。記憶だけで書かない
- 関門は 2 種類
  - 判断の関門: 担当者が決める。作業計画、版の選択と一時固定、ダウンロード、業務的な挙動の変化、未対応の gem の方針、手動確認の時期
  - 理解の関門: 担当者がレビュアーに説明できるようにする。既定値・雛形への追随の解説（[explain.md](explain.md)）
- 関門では [templates.md](templates.md) の型で示し、返事を待つ。関門の間は止まらずに進める
- 質問は 1 回に 1 論点（[templates.md](templates.md) の「質問」）
- 理由の正本はコミット（1 コミット 1 理由）。PR 本文はコミットへの索引。雛形に合わせずに残す設定は、その場所のコメントに理由を書く（[commit.md](commit.md)）
- 手動確認用の環境（設定の「手動確認用の環境」）には触れない。作業の前後で変わっていないことを確かめる
- 公開物の記載ルール（設定の「作業のルール」）に従う。コミットメッセージ・記録・PR 本文はすべて公開物
- 次のときは止まって、型で示す: 判断の関門にあたるものが出た、業務的な挙動が変わった、検査の失敗の原因が分からない、この手順にないことが要る

## 作業

| 作業 | 内容 | ファイル |
|---|---|---|
| resume | 計画と記録から次の作業を判断し、作業の始めの準備をする | [resume.md](resume.md) |
| research | 調査と作業計画 | [research.md](research.md) |
| gems | 周辺 gem を 1 つずつ上げる | [gems.md](gems.md) |
| ruby | Ruby を上げる | [ruby.md](ruby.md) |
| rails-lock | Rails のマイナー（必要なら先にパッチ）を上げたときの lock の解決 | [rails-lock.md](rails-lock.md) |
| rails-app-update | `app:update` の振り分け | [rails-app-update.md](rails-app-update.md) |
| rails-defaults | `new_framework_defaults_*.rb` をグループごとに有効にする | [rails-defaults.md](rails-defaults.md) |
| rails-load-defaults | `load_defaults` を上げる | [rails-load-defaults.md](rails-load-defaults.md) |
| verify | 完了条件の確認 | [verify.md](verify.md) |
| pr | 記録、コードレビュー、PR のタイトルと本文 | [pr.md](pr.md) |

作業をまたぐ手順: 理解の関門 [explain.md](explain.md)、コミット [commit.md](commit.md)、前後の比較 [before-after.md](before-after.md)、手動確認 [manual-check.md](manual-check.md)、提示と記録の型 [templates.md](templates.md)

作業名が表にないときは、表を示して、どの作業かを尋ねる。
