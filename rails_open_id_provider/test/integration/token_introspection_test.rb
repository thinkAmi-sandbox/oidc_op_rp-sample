# frozen_string_literal: true

require 'test_helper'

# RS と同じく、RS のクライアントクレデンシャルのトークン（introspection scope）で問い合わせる
class TokenIntrospectionTest < ActionDispatch::IntegrationTest
  include OauthFlowTestHelper

  test 'introspection scope を持つ RS のトークンで、my_op 用 RP に発行した有効なトークンを問い合わせると active: true' do
    access_token = issue_tokens['access_token']

    introspect(access_token)

    body = response.parsed_body

    assert_equal(
      { 'active' => true, 'scope' => 'openid', 'client_id' => oauth_applications(:my_op).uid,
        'token_type' => 'Bearer', 'lifetime' => 600 },
      body.slice('active', 'scope', 'client_id', 'token_type').merge('lifetime' => body['exp'] - body['iat'])
    )
  end

  test 'アクセストークンは発行からちょうど 10 分の時点では active: true' do
    freeze_time
    access_token = issue_tokens['access_token']
    travel 10.minutes

    introspect(access_token)

    assert_equal({ 'active' => true }, response.parsed_body.slice('active'))
  end

  test 'アクセストークンは発行から 10 分 1 秒で active: false' do
    freeze_time
    access_token = issue_tokens['access_token']
    travel 10.minutes + 1.second

    introspect(access_token)

    assert_equal({ 'active' => false }, response.parsed_body)
  end

  test 'revoke 済みのトークンは active: false' do
    access_token = issue_tokens['access_token']
    Doorkeeper::AccessToken.by_token(access_token).revoke

    introspect(access_token)

    assert_equal({ 'active' => false }, response.parsed_body)
  end

  test 'introspection scope を持たない別アプリの資格情報（Basic）で、RS のトークンを問い合わせると 200 で active: false' do
    target_token = resource_server_token
    my_op = oauth_applications(:my_op)
    credentials = ActionController::HttpAuthentication::Basic.encode_credentials(my_op.uid, my_op.secret)

    introspect(target_token, authorization: credentials)

    assert_response :ok
    assert_equal({ 'active' => false }, response.parsed_body)
  end
end
