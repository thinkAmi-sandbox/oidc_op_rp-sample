# frozen_string_literal: true

require 'test_helper'

# RP（my_op）と同じ scope openid・nonce・PKCE S256 での認可コードフロー
class AuthorizationCodeFlowTest < ActionDispatch::IntegrationTest
  include OauthFlowTestHelper

  test '初回の認可要求では同意画面が出る' do
    sign_in users(:user)

    get oauth_authorization_path, params: authorization_params(nonce: SecureRandom.hex(16),
                                                               code_verifier: SecureRandom.urlsafe_base64(48))

    assert_response :ok
    assert_select 'input[type=submit][value=Authorize]'
  end

  test '同意すると、認可コードを付けて redirect_uri へリダイレクトする' do
    sign_in users(:user)

    post oauth_authorization_path, params: authorization_params(nonce: SecureRandom.hex(16),
                                                                code_verifier: SecureRandom.urlsafe_base64(48))

    assert_redirected_to %r{\Ahttp://localhost:3781/auth/my_op/callback\?code=[^&]+\z}
  end

  test 'トークン応答は Bearer で有効期限 600 秒、リフレッシュトークンは含まない' do
    tokens = issue_tokens

    assert_equal({ 'token_type' => 'Bearer', 'expires_in' => 600, 'scope' => 'openid' },
                 tokens.slice('token_type', 'expires_in', 'scope'))
    assert_not tokens.key?('refresh_token')
  end

  test 'ID トークンは JWKS の鍵で検証でき、iss・aud・sub・nonce と有効期間 120 秒を持つ' do
    nonce = SecureRandom.hex(16)
    id_token = issue_tokens(nonce: nonce)['id_token']
    get oauth_discovery_keys_path

    claims = JSON::JWT.decode(id_token, JSON::JWK::Set.new(response.parsed_body['keys']), [:RS256])

    assert_equal(
      { 'iss' => 'http://localhost:3780', 'aud' => oauth_applications(:my_op).uid, 'sub' => users(:user).id.to_s,
        'nonce' => nonce, 'lifetime' => 120 },
      claims.slice('iss', 'aud', 'sub', 'nonce').merge('lifetime' => claims['exp'] - claims['iat'])
    )
  end

  test 'userinfo はアクセストークンの持ち主の sub とメールアドレスを返す' do
    access_token = issue_tokens['access_token']

    get oauth_userinfo_path, headers: { 'Authorization' => "Bearer #{access_token}" }

    assert_equal({ 'sub' => users(:user).id.to_s, 'email' => users(:user).email }, response.parsed_body)
  end
end
