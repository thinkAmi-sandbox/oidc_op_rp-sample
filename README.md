# oidc_op_rp-sample

OpenID Provider and Relying Party samples written by Ruby.

Note: Make sure it's for practice and not a problem when you use it in production.

　  
## Tested Environment

- macOS
- Open ID Provider
  - Rails 6.1.4
  - doorkeeper 5.5.2
  - doorkeeper-openid_connect 1.8.0
  - devise 4.8.0
- Relying Party
  - Rails 6.1.4
  - omniauth 2.0.4
  - omniauth-oauth2 1.7.1

　  
## How to use

1. generate signing key in rails_open_id_provider directory

```
% ssh-keygen -t rsa -P "" -b 4096 -m PEM -f jwtRS256.key
```

2. run OP and RP

```
% rails s
```

　  
## Related Blog (Written in Japanese)

- [Railsとdoorkeeper-openid_connectやOmniAuth を使って、OpenID Connectの OpenID Provider と Relying Party を作ってみた - メモ的な思考的な](https://thinkami.hatenablog.com/entry/2021/08/14/224121)
- [doorkeeper製 OAuth 2.0 のAuthorization Serverにて、色々な状態のアクセストークンを使って Introspection エンドポイントの挙動を確認してみた - メモ的な思考的な](https://thinkami.hatenablog.com/entry/2021/08/22/182659)
