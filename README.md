# oidc_op_rp-sample

OpenID Provider and Relying Party samples written by Ruby and Next.js.

Note: Make sure it's for practice and not a problem when you use it in production.

　  
## Tested Environment

- macOS
- Open ID Provider
  - `rails_open_id_provider`
    - Rails 6.1.4
    - doorkeeper 5.5.2
    - doorkeeper-openid_connect 1.8.0
    - devise 4.8.0
- Relying Party by Rails
  - `rails_relying_party_of_backend`
    - Rails 6.1.4
    - omniauth 2.0.4
    - omniauth-oauth2 1.7.1
- Relying Party by Next.js
  - `nextjs_relying_party_of_express_with_all_required`
    - Next.js 11.1.2
    - express 4.17.1
    - express-openid-connect 2.5.0
- Relying Party by Next.js and TypeScript
  - `nextjs_relying_party_of_express_with_all_required`
    - Next.js 11.1.2
    - express 4.17.1
    - express-openid-connect 2.5.0
    - TypeScript 4.4.3

　  
## How to use

1. generate signing key in rails_open_id_provider directory

```
% ssh-keygen -t rsa -P "" -b 4096 -m PEM -f jwtRS256.key
```

2. run OP and RP by Rails

```
% rails s
```

3. run RP by Next.js

```
% yarn run dev
```

　  
## Related Blog (Written in Japanese)

- [Railsとdoorkeeper-openid_connectやOmniAuth を使って、OpenID Connectの OpenID Provider と Relying Party を作ってみた - メモ的な思考的な](https://thinkami.hatenablog.com/entry/2021/08/14/224121)
- [doorkeeper製 OAuth 2.0 のAuthorization Serverにて、色々な状態のアクセストークンを使って Introspection エンドポイントの挙動を確認してみた - メモ的な思考的な](https://thinkami.hatenablog.com/entry/2021/08/22/182659)
- [Next.js + express-openid-connect を使って、バックエンドで OpenID Provider と通信する Relying Party を作ってみた - メモ的な思考的な](https://thinkami.hatenablog.com/entry/2021/09/07/232621)
- [Next.js と express-openid-connect を使って、認証が必要/不要な各ページを持つ Relying Party を作ってみた - メモ的な思考的な](https://thinkami.hatenablog.com/entry/2021/09/13/233923)
- [Next.js と express-openid-connect を使った Relying Party を TypeScript 化してみた - メモ的な思考的な](https://thinkami.hatenablog.com/entry/2021/09/19/225604)