# frozen_string_literal: true

require 'test_helper'

# RP・RS は使わないが、OP が受け付けるクライアント認証とアクセストークンの渡し方の応答（ステータス・ヘッダー・本文）を、
# test/snapshots/responses/ のスナップショットと比べる。
# RP・RS は、クライアント認証を本文だけで送り、アクセストークンを 1 つの方法だけで渡す（oauth_flow_test_helper.rb）。
# doorkeeper 5.9.5〜5.9.7 から、クライアント認証やトークンの渡し方を 2 重に使う要求を拒む（docs/upgrade/PLAN.md の Step 1-b-3）
class ResponseSnapshotTokenAuthTest < ActionDispatch::IntegrationTest
  include OauthFlowTestHelper
  include ResponseSnapshotHelper

  # トークン応答の created_at を伏せずに比べるため、時刻を固定する
  setup do
    travel_to Time.utc(2026, 1, 1, 0, 0, 0)
  end

  test 'Basic 認証だけでのトークン要求の応答' do
    application = oauth_applications(:resource_server)

    post oauth_token_path, params: { grant_type: 'client_credentials', scope: 'introspection' },
                           headers: { 'Authorization' => basic_authorization(application) }

    assert_response_snapshot 'token_basic_auth'
  end

  test 'Basic 認証と本文の両方に同じクライアントの資格情報を入れたトークン要求の応答' do
    application = oauth_applications(:resource_server)

    post oauth_token_path, params: { grant_type: 'client_credentials', scope: 'introspection',
                                     client_id: application.uid, client_secret: application.secret },
                           headers: { 'Authorization' => basic_authorization(application) }

    assert_response_snapshot 'token_basic_and_body_auth'
  end

  test 'Basic 認証と本文で別のクライアントを指すトークン要求の応答' do
    post oauth_token_path, params: { grant_type: 'client_credentials', scope: 'introspection',
                                     client_id: oauth_applications(:my_op).uid },
                           headers: { 'Authorization' => basic_authorization(oauth_applications(:resource_server)) }

    assert_response_snapshot 'token_basic_and_other_client_id'
  end

  test 'access_token 引数だけで呼んだ userinfo の応答' do
    access_token = issue_tokens['access_token']

    get oauth_userinfo_path, params: { access_token: access_token }

    assert_response_snapshot 'userinfo_access_token_param'
  end

  test 'Bearer ヘッダーと access_token 引数の両方で呼んだ userinfo の応答' do
    access_token = issue_tokens['access_token']

    get oauth_userinfo_path, params: { access_token: access_token },
                             headers: { 'Authorization' => "Bearer #{access_token}" }

    assert_response_snapshot 'userinfo_bearer_and_param'
  end

  test 'openid の scope のないトークンで呼んだ userinfo の応答' do
    access_token = resource_server_token

    get oauth_userinfo_path, headers: { 'Authorization' => "Bearer #{access_token}" }

    assert_response_snapshot 'userinfo_insufficient_scope'
  end

  private

  def basic_authorization(application)
    ActionController::HttpAuthentication::Basic.encode_credentials(application.uid, application.secret)
  end
end
