# Rails 7.2 の既定値への追随

- 版: Rails 7.1.6 → 7.2.4（Ruby 3.3.12）
- Step: 5（ブランチ `upgrade/step5-rails72`）/ PR: （PR 作成後に記入）
- 記録のルールは [README.md](README.md)

## 一覧

| ID | 項目 | 種類 | 対象 | 扱い |
|---|---|---|---|---|
| DEF-7.2-01 | OP の注釈の rake を、annotaterb の雛形にする | 周辺 gem の雛形（annotaterb 4.25.0） | OP | 追随（RuboCop に合わせて書き方を直す） |
| DEF-7.2-02 | OP に `.annotaterb.yml` を足し、旧 rake の 2 つの値を引き継ぐ | 周辺 gem の雛形（annotaterb 4.25.0） | OP | 追随（2 つの値は旧 rake のまま） |

## 周辺 gem（Step 5）

Step 5 で、Rails 7.2.4 の前に annotate 3.2.0 を annotaterb 4.25.0 に置き換えたときの、gem の雛形への追随。置き換える理由と範囲は [PLAN.md](../PLAN.md) の Step 5 と [LOG.md](../LOG.md) の Step 5。RP は annotate を使っていなかったので、annotaterb に置き換えずに外した（雛形への追随ではないので、ここには項目を立てない。LOG.md の Step 5 の「作業計画からの変更点」）。

### DEF-7.2-01: OP の注釈の rake を、annotaterb の雛形にする

- 種類: 周辺 gem の雛形（annotate 3.2.0 → annotaterb 4.25.0。開発の道具）/ 対象: OP
- 何が変わるか: `lib/tasks/auto_annotate_models.rake` を消し、`bin/rails g annotate_rb:install` が作る `lib/tasks/annotate_rb.rake` にする
  - 前: annotate の generator の出力。`require 'annotate'`、`task :set_annotation_options` の中で全設定を `Annotate.set_defaults` に渡し、`Annotate.load_tasks`。Step 0-e で `task` の行に `rubocop:disable Metrics/BlockLength, Rails/RakeEnvironment` を付けていた
  - 後: development で、環境変数 `ANNOTATERB_SKIP_ON_DB_TASKS` がなければ、`require 'annotate_rb'` して `AnnotateRb::Core.load_rake_tasks` を呼ぶだけ。設定は rake に書かず、`.annotaterb.yml`（DEF-7.2-02）から読む。`task` のブロックがないので、2 つの `rubocop:disable` は要らなくなる
  - 雛形との違い: RuboCop の `Style/FrozenStringLiteralComment`・`Style/StringLiterals` に合わせて、マジックコメントを足し、2 つの文字列をシングルクォートにした。旧 rake も Step 0-e で同じ形に直していた。ファイルの先頭に理由のコメントを書いた
- なぜ: annotate 3.2.0 は `activerecord < 8.0` で Rails 8 に対応しないので、後継の annotaterb に置き換える（PLAN.md の 7 章）。annotaterb は旧 rake の設定も環境変数の設定も読まない（MIGRATION_GUIDE.md）。旧 rake の `require 'annotate'` は、残すと annotaterb がアプリの rake を読んだときに `LoadError` になる（試して起きた）
- 3 アプリへの影響: development の `db:migrate` の後に注釈を付ける動きは同じ（E2E 用の DB で `db:migrate --trace` を流し、`Annotating models` が出て、注釈の差分は出なかった）。test・CI では読まれない（`Rails.env.development?`）。annotaterb には Railtie がなく、rake のタスクはこの rake からだけ読まれる（`annotaterb-4.25.0/lib/annotate_rb/core.rb` の `load_rake_tasks`）
- 扱い: 追随（書き方だけ RuboCop に合わせる）
- 出典: `annotaterb-4.25.0/lib/generators/annotate_rb/install/install_generator.rb`・`annotaterb-4.25.0/lib/generators/annotate_rb/hook/templates/annotate_rb.rake`・`annotaterb-4.25.0/lib/annotate_rb/core.rb`、annotaterb の MIGRATION_GUIDE.md（v4.25.0）。Rails ガイドに該当の節はない（gem の雛形）
- コミット: OP（`replace annotate with annotaterb`）

### DEF-7.2-02: OP に `.annotaterb.yml` を足し、旧 rake の 2 つの値を引き継ぐ

- 種類: 周辺 gem の雛形（annotaterb 4.25.0。開発の道具）/ 対象: OP
- 何が変わるか: `bin/rails g annotate_rb:install` が、gem の既定値をすべて書き出した `.annotaterb.yml` を作る。旧 rake の値と既定値で違う 2 つを、旧 rake の値にした（`hide_limit_column_types`: 空 → `integer,bigint,boolean`、`hide_default_column_types`: 空 → `json,jsonb,hstore`）。2 行の上に、引き継ぐ理由のコメントを書いた。ほかの値（`position_in_*: before`、`classified_sort`、`show_indexes`、`show_foreign_keys`、`with_comment`、`exclude_tests: false`、`exclude_fixtures: false` など）は、旧 rake と同じ
- なぜ: annotaterb は設定を yml と引数だけから読み、2 つの既定値が annotate の旧 rake と違う（`annotaterb-4.25.0/lib/annotate_rb/options.rb` の `hide_default_column_types`・`hide_limit_column_types`）
- 3 アプリへの影響: 今の `users` の列には 2 つの設定が効く型がなく、既定値のままでも、2 つの値を引き継いで `annotaterb models --force` で書き直させても、`app/models/user.rb`・`test/fixtures/users.yml` の注釈は同じだった（E2E 用の DB）。引き継ぐのは、今後の列の追加で注釈の出し方を変えないため
- 扱い: 追随（2 つの値は旧 rake のまま）
- 出典: `annotaterb-4.25.0/lib/generators/annotate_rb/config/config_generator.rb`・`annotaterb-4.25.0/lib/annotate_rb/options.rb`、annotaterb の MIGRATION_GUIDE.md（v4.25.0）。Rails ガイドに該当の節はない（gem の雛形）
- コミット: OP（`replace annotate with annotaterb`）
