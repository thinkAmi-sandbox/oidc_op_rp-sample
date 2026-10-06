# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# E2E（リポジトリ直下の e2e/）用のユーザーと Doorkeeper アプリケーションを作る。
# client_id / secret / パスワードは一目でダミーと分かる固定値で、本物の値ではない。
# client_id / secret は rails_relying_party_of_backend/.env_e2e と rails_resource_server/.env_e2e の値と揃える。

# 同意画面は、同じアプリ・ユーザー・scope の revoke されていないトークンがあると省かれる。
# シナリオの実行順や単独実行で同意画面の有無が変わらないよう、シナリオごとにユーザーを分ける
E2E_PASSWORD = 'e2e-dummy-password'
%w[login logout resource baseline].each do |scenario|
  User.find_or_create_by!(email: "e2e-#{scenario}@example.com") do |user|
    user.password = E2E_PASSWORD
  end
end

[
  {
    name: 'RP (my_op)',
    uid: 'e2e-dummy-rp-my-op-client-id',
    secret: 'e2e-dummy-rp-my-op-client-secret',
    redirect_uri: 'http://localhost:3781/auth/my_op/callback',
    scopes: 'openid'
  },
  {
    name: 'RP (introspection)',
    uid: 'e2e-dummy-rp-introspection-client-id',
    secret: 'e2e-dummy-rp-introspection-client-secret',
    redirect_uri: 'http://localhost:3781/auth/introspection/callback',
    scopes: 'openid introspection'
  },
  {
    name: 'Resource Server',
    uid: 'e2e-dummy-rs-client-id',
    secret: 'e2e-dummy-rs-client-secret',
    redirect_uri: 'urn:ietf:wg:oauth:2.0:oob',
    scopes: 'introspection'
  }
].each do |attributes|
  Doorkeeper::Application.find_or_create_by!(uid: attributes[:uid]) do |application|
    application.assign_attributes(attributes.merge(confidential: true))
  end
end
