# frozen_string_literal: true

# OP とのやり取り（トークン・userinfo・JWKS）を WebMock で差し替え、
# 独自ストラテジー（lib/omniauth/strategies/my_op.rb）のログインの流れを実際に通すためのヘルパー
module MyOpTestHelper
  # ID トークンへの署名と JWKS に使う鍵。テストを流すたびに作る
  SIGNING_KEY = OpenSSL::PKey::RSA.generate(2048)
  SIGNING_KID = 'test-signing-key'

  OP_USER_SUB = '1'
  OP_USER_EMAIL = 'user@example.com'

  # POST /auth/<provider> で OP の認可エンドポイントへのリダイレクトを受け取り、そのクエリを返す
  def request_authorization(provider)
    post "/auth/#{provider}"
    Rack::Utils.parse_query(URI.parse(response.location).query)
  end

  # 認可要求の client_id と nonce に合う、正しい ID トークン。claims で項目を上書きできる
  def id_token_for(authorization, key: SIGNING_KEY, kid: SIGNING_KID, **claims)
    now = Time.now.to_i
    payload = { iss: ENV.fetch('ISSUER_OF_MY_OP'), aud: authorization['client_id'], sub: OP_USER_SUB,
                nonce: authorization['nonce'], iat: now, exp: now + 120 }
    JWT.encode(payload.merge(claims), key, 'RS256', { kid: kid })
  end

  def signing_jwk
    JWT::JWK::RSA.new(SIGNING_KEY.public_key, kid: SIGNING_KID).export
  end

  def stub_op(id_token:, access_token: SecureRandom.hex(16), keys: [signing_jwk])
    token_body = { access_token: access_token, token_type: 'Bearer', expires_in: 600, scope: 'openid',
                   created_at: Time.now.to_i, id_token: id_token }
    stub_request(:post, op_url('/oauth/token')).to_return(json_response(token_body))
    stub_request(:get, op_url('/oauth/userinfo')).to_return(json_response({ sub: OP_USER_SUB, email: OP_USER_EMAIL }))
    stub_request(:get, op_url('/oauth/discovery/keys')).to_return(json_response({ keys: keys }))
  end

  def receive_callback(provider, authorization)
    get "/auth/#{provider}/callback", params: { code: SecureRandom.hex(16), state: authorization['state'] }
  end

  # 認可要求 → 正しい ID トークンでのコールバックまでを通す
  def log_in_via_op(provider = 'my_op', access_token: SecureRandom.hex(16))
    authorization = request_authorization(provider)
    stub_op(id_token: id_token_for(authorization), access_token: access_token)
    receive_callback(provider, authorization)
  end

  def op_url(path)
    "#{ENV.fetch('OIDC_PROVIDER_HOST')}#{path}"
  end

  def json_response(body, status: 200)
    { status: status, body: body.to_json, headers: { 'Content-Type' => 'application/json' } }
  end
end
