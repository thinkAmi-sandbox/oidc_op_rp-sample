# Rails 7.1 の既定値への追随

- 版: Rails 7.0.10 → 7.1.6（Ruby 3.2.11）
- Step: 3（ブランチ `upgrade/step3-rails71`）/ PR: （PR 作成後に記入）
- 記録のルールは [README.md](README.md)

## 一覧

| ID | 項目 | 種類 | 対象 | 扱い |
|---|---|---|---|---|
| DEF-7.1-01 | puma が応答ヘッダー名を小文字で返す | 周辺 gem の既定値（puma 8.0.2） | 3 アプリ | 追随 |
| DEF-7.1-02 | puma の keep-alive の既定値が変わる | 周辺 gem の既定値（puma 8.0.2） | 3 アプリ | 追随 |
| DEF-7.1-03 | puma の既定の bind のアドレスが IPv6 になる | 周辺 gem の既定値（puma 8.0.2） | 3 アプリ | 追随（実際の bind は変わらない） |

## 周辺 gem（Step 3）

Step 3 で、Rails 7.1 にする前と直後に上げる周辺 gem で起きた、gem の既定値・雛形の変化。上げた版と順番は [PLAN.md](../PLAN.md) の Step 3。

### DEF-7.1-01: puma が応答ヘッダー名を小文字で返す

- 種類: 周辺 gem の既定値（puma 6.6.1 → 8.0.2）/ 対象: RS・RP・OP（puma で動かす development。E2E と手動確認で使う）
- 何が変わるか: puma が返す応答のヘッダー名が、すべて小文字になる（`X-Frame-Options: SAMEORIGIN` → `x-frame-options: SAMEORIGIN`、`Content-Type` → `content-type` など）。値と順番は同じ。test 環境のアプリを puma に直接通し、RS の `/apples/show`（401）と OP の discovery（200）の生の応答を前後で比べて確かめた
- なぜ: puma 7.0.0 の破壊的な変更（puma#3704。元は #3305、報告は #3250）。それまで puma は `Content-Length` などの一部のヘッダーの名前の書き方を自分で決めていて、ヘッダーを小文字で持つ Rack 3 のアプリでは、アプリが返した形と食い違った。常に小文字にそろえた
- 3 アプリへの影響: HTTP のヘッダー名は大文字と小文字を区別しない（RFC 9110 の 5.1）。RP・RS は OP・RS の応答を faraday で読み、`Faraday::Utils::Headers` は名前を小文字にそろえて引く（`faraday-2.14.4/lib/faraday/utils/headers.rb:52`）。アプリのコードは応答のヘッダーを読まない（RS が読む `Authorization` はリクエストのヘッダー）。minitest の応答のスナップショットは puma を通らないので同じ。E2E は通った
- 扱い: 追随
- 出典: puma の History.md の 7.0.0（Breaking changes）、puma#3305・#3250。Rails の外の gem なので、Rails ガイドに該当の節はない
- コミット: RS・RP・OP（`update puma to 8.0.2`）

### DEF-7.1-02: puma の keep-alive の既定値が変わる

- 種類: 周辺 gem の既定値（puma 6.6.1 → 8.0.2）/ 対象: RS・RP・OP（development）
- 何が変わるか: `config/puma.rb` を読み込んだ後の値で、`persistent_timeout`（接続を開けておく秒数）が 20 → 65、`max_keep_alive`（1 つの接続で受ける要求の上限）が nil → 999。ほかの値（threads・workers・`worker_timeout` など）は同じ（6.6.1 と 8.0.2 で書き出して比べた）
- なぜ: puma 7.0.0 で、ロードバランサーのアイドルのタイムアウト（AWS ALB の既定は 60 秒）より短いと、閉じかけの接続に要求が来て 502 になることがあるので 65 秒にした（#3378）。7.0 で入った keep-alive の扱いの上限を、nginx の既定（1000）にならって 999 にした（#3719）
- 3 アプリへの影響: 同じ接続を使い回す時間と回数だけが変わり、応答の中身は変わらない。`config/puma.rb` はどちらも設定していない。production は動作保証の外
- 扱い: 追随（`config/puma.rb` に古い値を書かない）
- 出典: puma の History.md の 7.0.0、puma#3378・#3719
- コミット: RS・RP・OP（`update puma to 8.0.2`）

### DEF-7.1-03: puma の既定の bind のアドレスが IPv6 になる

- 種類: 周辺 gem の既定値（puma 6.6.1 → 8.0.2）/ 対象: RS・RP・OP
- 何が変わるか: puma の設定だけで見ると、bind が `tcp://0.0.0.0:<ポート>` → `tcp://[::]:<ポート>`（IPv6 のインターフェースがあるとき）
- なぜ: puma 8.0.0 の破壊的な変更（puma#3847）
- 3 アプリへの影響: ない。`bin/rails s` は development で host に `localhost` を渡し（`railties-7.0.10/lib/rails/commands/server/server_command.rb:219`）、Rack handler は host があると bind を消して作り直す（`puma-8.0.2/lib/rack/handler/puma.rb:96`）ので、puma の既定の bind は使われない。`.claude/launch.json` も E2E の `e2e/scripts/start-server.sh` も `bin/rails s` で起動する
- 扱い: 追随（何もしない）
- 出典: puma の History.md の 8.0.0、上の 2 つのソースの行
- コミット: RS・RP・OP（`update puma to 8.0.2`）
