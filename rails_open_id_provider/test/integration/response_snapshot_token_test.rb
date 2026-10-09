# frozen_string_literal: true

require 'test_helper'

# OP のトークン・userinfo・introspect・revoke のエンドポイントの応答（ステータス・ヘッダー・本文）を、
# test/snapshots/responses/ のスナップショットと比べる。
# RP（my_op）・RS と同じ呼び方は oauth_flow_test_helper.rb を使う
class ResponseSnapshotTokenTest < ActionDispatch::IntegrationTest
  include OauthFlowTestHelper
  include ResponseSnapshotHelper

  # トークン応答の created_at と、introspect の iat・exp を伏せずに比べるため、時刻を固定する
  setup do
    travel_to Time.utc(2026, 1, 1, 0, 0, 0)
  end

  test '認可コードでのトークン要求の応答' do
    issue_tokens

    assert_response_snapshot 'token_authorization_code'
  end

  test '認可コードが誤っているトークン要求の応答' do
    application = oauth_applications(:my_op)

    post oauth_token_path, params: { grant_type: 'authorization_code', code: 'wrong-code',
                                     client_id: application.uid, client_secret: application.secret }

    assert_response_snapshot 'token_error'
  end

  test 'クライアントクレデンシャルでのトークン要求の応答' do
    resource_server_token

    assert_response_snapshot 'token_client_credentials'
  end

  test 'userinfo の応答' do
    access_token = issue_tokens['access_token']

    get oauth_userinfo_path, headers: { 'Authorization' => "Bearer #{access_token}" }

    assert_response_snapshot 'userinfo'
  end

  test 'アクセストークンなしの userinfo の応答' do
    get oauth_userinfo_path

    assert_response_snapshot 'userinfo_error'
  end

  test '有効なトークンの introspect の応答' do
    access_token = issue_tokens['access_token']

    introspect(access_token)

    assert_response_snapshot 'introspect_active'
  end

  test 'revoke したトークンの introspect の応答' do
    access_token = issue_tokens['access_token']
    revoke(access_token)

    introspect(access_token)

    assert_response_snapshot 'introspect_revoked'
  end

  test '認証のない introspect の応答' do
    access_token = issue_tokens['access_token']

    post oauth_introspect_path, params: { token: access_token }

    assert_response_snapshot 'introspect_error'
  end

  test 'revoke の応答' do
    access_token = issue_tokens['access_token']

    revoke(access_token)

    assert_response_snapshot 'revoke'
  end

  private

  # token_revocation_test.rb と同じく、トークンを発行したアプリ（my_op）の資格情報で revoke する
  def revoke(access_token)
    application = oauth_applications(:my_op)
    post oauth_revoke_path,
         params: { client_id: application.uid, client_secret: application.secret, token: access_token }
  end
end
