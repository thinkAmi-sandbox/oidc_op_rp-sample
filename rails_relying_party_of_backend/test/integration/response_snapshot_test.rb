# frozen_string_literal: true

require 'test_helper'

# RP の応答（ステータス・ヘッダー・本文）を test/snapshots/responses/ のスナップショットと比べる。
# OP・RS とのやり取りは、ほかの統合テストと同じく WebMock で差し替える
class ResponseSnapshotTest < ActionDispatch::IntegrationTest
  include MyOpTestHelper
  include ResponseSnapshotHelper

  # introspection 用 RP のコールバックの後の画面に、flash でそのまま出る値。毎回同じ本文になるよう固定する
  INTROSPECTION_ACCESS_TOKEN = 'snapshot-introspection-access-token'

  test '未ログインのトップの応答' do
    get root_path

    assert_response_snapshot 'home'
  end

  test 'ログインボタンを押したときの、OP の認可エンドポイントへのリダイレクト' do
    post '/auth/my_op'

    assert_response_snapshot 'auth_my_op_request'
  end

  test 'OP からのコールバックでログインしたときの応答' do
    log_in_via_op

    assert_response_snapshot 'auth_my_op_callback'
  end

  test 'ログインした後のトップの応答' do
    log_in_via_op

    follow_redirect!

    assert_response_snapshot 'home_logged_in'
  end

  test 'ID トークンの検証に失敗したコールバックの応答' do
    authorization = request_authorization('my_op')
    stub_op(id_token: id_token_for(authorization, nonce: SecureRandom.urlsafe_base64))

    receive_callback('my_op', authorization)

    assert_response_snapshot 'auth_my_op_callback_failure'
  end

  test '/auth/failure の応答' do
    get '/auth/failure', params: { message: 'JWT::VerificationError', strategy: 'my_op' }

    assert_response_snapshot 'auth_failure'
  end

  test 'ログアウトの応答' do
    log_in_via_op

    get logout_path

    assert_response_snapshot 'logout'
  end

  test 'introspection 用 RP の画面の応答' do
    get introspection_path

    assert_response_snapshot 'introspection'
  end

  test 'introspection 用 RP のログインボタンを押したときの、OP の認可エンドポイントへのリダイレクト' do
    post '/auth/introspection'

    assert_response_snapshot 'auth_introspection_request'
  end

  test 'introspection 用 RP のコールバックの応答' do
    stub_resource_server_and_revoke

    log_in_via_op('introspection', access_token: INTROSPECTION_ACCESS_TOKEN)

    assert_response_snapshot 'auth_introspection_callback'
  end

  test 'introspection 用 RP のコールバックの後の画面の応答' do
    stub_resource_server_and_revoke
    log_in_via_op('introspection', access_token: INTROSPECTION_ACCESS_TOKEN)

    follow_redirect!

    assert_response_snapshot 'introspection_after_callback'
  end

  private

  # introspections_test.rb と同じく、コールバックが呼ぶ RS と OP の revoke を差し替える
  def stub_resource_server_and_revoke
    stub_request(:get, 'http://localhost:3782/apples/show').to_return(json_response({ name: 'シナノゴールド' }))
    stub_request(:post, op_url('/oauth/revoke')).to_return(json_response({}))
  end
end
