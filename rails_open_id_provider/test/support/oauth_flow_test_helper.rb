# frozen_string_literal: true

# RP（my_op）・RS と同じ呼び方で OP のエンドポイントを呼ぶためのヘルパー
module OauthFlowTestHelper
  # RP と同じく scope openid・nonce・PKCE S256 を付けた認可要求のパラメーター
  def authorization_params(nonce:, code_verifier:, application: oauth_applications(:my_op))
    { client_id: application.uid, redirect_uri: application.redirect_uri, response_type: 'code', scope: 'openid',
      nonce: nonce, code_challenge: pkce_challenge(code_verifier), code_challenge_method: 'S256' }
  end

  def pkce_challenge(code_verifier)
    Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false)
  end

  # 同意画面で Authorize を押したときと同じ POST をし、リダイレクト先の認可コードを返す
  def approve_authorization(params)
    post oauth_authorization_path, params: params
    Rack::Utils.parse_query(URI.parse(response.location).query)['code']
  end

  # ログイン → 同意 → トークン要求までを通し、トークン応答を返す
  def issue_tokens(nonce: SecureRandom.hex(16), application: oauth_applications(:my_op))
    sign_in users(:user)
    code_verifier = SecureRandom.urlsafe_base64(48)
    code = approve_authorization(authorization_params(nonce: nonce, code_verifier: code_verifier))
    post oauth_token_path, params: {
      grant_type: 'authorization_code', code: code, redirect_uri: application.redirect_uri,
      client_id: application.uid, client_secret: application.secret, code_verifier: code_verifier
    }
    response.parsed_body
  end

  # RS と同じく、クライアントクレデンシャルで introspection 用のトークンを取る
  def resource_server_token
    application = oauth_applications(:resource_server)
    post oauth_token_path, params: {
      grant_type: 'client_credentials', scope: 'introspection',
      client_id: application.uid, client_secret: application.secret
    }
    response.parsed_body['access_token']
  end

  # 既定では RS と同じく、RS のトークンを Bearer で付けて問い合わせる
  def introspect(token, authorization: "Bearer #{resource_server_token}")
    post oauth_introspect_path, params: { token: token }, headers: { 'Authorization' => authorization }
  end
end
