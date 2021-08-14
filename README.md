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



