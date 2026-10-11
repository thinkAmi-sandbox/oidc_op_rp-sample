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
| DEF-7.1-04 | リダイレクトの応答が本文を返さない | Rails の既定値 | RP・OP | 追随 |
| DEF-7.1-05 | ルーティングの `redirect` の Content-Type に charset が付く | Rails の既定値 | RP | 追随 |
| DEF-7.1-06 | activerecord-session_store 2.3.0 の変化（SameSite の既定ほか） | 周辺 gem の既定値（activerecord-session_store 2.3.0） | RP | 追随 |

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

## Rails 7.1.6 にしたときの変化（`load_defaults` によらないもの）

Gemfile の rails を `~> 7.1.6` にしただけで（`load_defaults 7.0` のまま）、応答のスナップショットに出た変化。

### DEF-7.1-04: リダイレクトの応答が本文を返さない

- 種類: Rails の既定値 / 対象: RP・OP（RS はリダイレクトしない）
- 何が変わるか: 301・302 の応答の本文 `<html><body>You are being <a href="...">redirected</a>.</body></html>` が空になる。ステータス・`Location`・ほかのヘッダーは同じ。コントローラーの `redirect_to`（OP 11 件: devise のログイン・ログアウト・登録・編集、doorkeeper の認可エンドポイントから RP のコールバックへ。RP 3 件: ログイン・ログアウト・introspection のコールバック）と、ルーティングの `redirect`（RP の `/auth/failure`）の両方
- なぜ: 今のブラウザはこの HTML を表示せず、送る分だけ無駄になる。HTML は W3C の検証でエラーになり（doctype・title がない）、サイト全体の適合性の検査で誤った指摘の原因になる（rails/rails#44554、7.1.0）
- 3 アプリへの影響: ブラウザも faraday も `Location` を見て進むので、画面の遷移・リダイレクト先・アプリ間のやり取りは変わらない。本文を読むコードはない。E2E（ログイン、OP の認可からの戻り、introspection の流れ）は Rails 7.1.6 で通った。応答のスナップショットを作り直した
- 扱い: 追随
- 出典: rails/rails#44554、`actionpack-7.1.6/CHANGELOG.md`（「Make `redirect_to` return an empty response body.」）、`actionpack-7.1.6/lib/action_dispatch/routing/redirection.rb`。Rails ガイド v7.1 の「Rails 7.1 リリースノート」と「Rails アップグレードガイド」に該当の節はない
- コミット: RP・OP（`update rails to 7.1.6`）

### DEF-7.1-05: ルーティングの `redirect` の Content-Type に charset が付く

- 種類: Rails の既定値 / 対象: RP（`config/routes.rb` の `/auth/failure` の `redirect('/')` だけ）
- 何が変わるか: `content-type: text/html` → `text/html; charset=UTF-8`
- なぜ: ペネトレーションテストで charset のない応答を指摘され、OWASP ASVS の 14.4.1（text/* の応答には安全な文字コードを書く）に合わせた（rails/rails#47758、7.1.0。CHANGELOG にはない）
- 3 アプリへの影響: 本文は空で、ブラウザは `Location` へ進むだけなので、表示は変わらない。コントローラーの `redirect_to` の Content-Type は前からこの形
- 扱い: 追随
- 出典: rails/rails#47758、`actionpack-7.1.6/lib/action_dispatch/routing/redirection.rb`。Rails ガイドに該当の節はない
- コミット: RP（`update rails to 7.1.6`）

### DEF-7.1-06: activerecord-session_store 2.3.0 の変化

- 種類: 周辺 gem の既定値（activerecord-session_store 2.2.0 → 2.3.0。Rails 7.1.6 と同じコミットで上げた）/ 対象: RP
- 何が変わるか（入れた 2.2.0 と 2.3.0 の `lib` の差分。generator の雛形は同じ）
  - セッション Cookie の `same_site` の既定を `request.cookies_same_site_protection` から取る。Rails 7.1 は、Cookie に `same_site: nil` があると SameSite を付けなくなり（actionpack 7.1 の CHANGELOG「Allow opting out of the `SameSite` cookie attribute」）、2.2.0 では rack 2.2 の `Rack::Session::Abstract::Persisted` が `same_site: nil` を入れるので、SameSite が消えていた。2.3.0 で 7.0 と同じ `SameSite=Lax` になる
  - セッションのデータが変わっておらず新しくもないときは、DB に書かない。同じ要求の中で読んだセッションの行を使い回す
  - 公開のセッション ID の文字コードが壊れていたら使わない。`secure_session_only` のオプションが増えた（既定は false で、今と同じ）
  - `session_id` 以外の列名を使うと非推奨の警告を出す（RP は `session_id` の列）。deprecator を `app.deprecators` に登録する
- なぜ: 2.3.0 で Rails 7.0 のサポートをやめ、Rails の CookieStore に合わせて SameSite の既定を入れた（コミット 121f9ff7。rails/rails#45501）
- 3 アプリへの影響: Set-Cookie は Rails 7.0 のときと同じ。データが変わらないときは、2.2.0 でも Active Record が変更なしとして UPDATE を出さなかった見込みで、DB に入るデータは変わらない。RP の sessions のテストは通った
- 扱い: 追随。Rails 7.1.6 の直後の予定だったが、Rails 7.1.6 だけでは SameSite が消えるので、同じコミットで上げた（人間が判断。CLAUDE.md の「gem が新しい Rails に未対応のとき」の ①）
- 出典: activerecord-session_store の GitHub の v2.3.0 のリリース、コミット 121f9ff7、`activerecord-session_store-2.3.0/lib/action_dispatch/session/active_record_store.rb`、`activerecord-session_store-2.3.0/lib/active_record/session_store/session.rb`、`actionpack-7.1.6/lib/action_dispatch/middleware/cookies.rb`、`rack-2.2.24/lib/rack/session/abstract/id.rb`。Rails ガイドに該当の節はない
- コミット: RP（`update rails to 7.1.6`）
