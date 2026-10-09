# frozen_string_literal: true

require 'test_helper'

# OP の認可エンドポイントと doorkeeper の管理画面の応答（ステータス・ヘッダー・本文）を、
# test/snapshots/responses/ のスナップショットと比べる。
# RP（my_op）・RS と同じ呼び方は oauth_flow_test_helper.rb を使う
class ResponseSnapshotAuthorizationTest < ActionDispatch::IntegrationTest
  include OauthFlowTestHelper
  include ResponseSnapshotHelper

  test '未ログインで認可エンドポイントに来たときの応答' do
    get oauth_authorization_path, params: new_authorization_params

    assert_response_snapshot 'authorize_without_login'
  end

  test '同意画面の応答' do
    sign_in users(:user)

    get oauth_authorization_path, params: new_authorization_params

    assert_response_snapshot 'authorize_consent'
  end

  test '登録されていない redirect_uri で認可エンドポイントに来たときのエラー画面の応答' do
    sign_in users(:user)

    get oauth_authorization_path,
        params: new_authorization_params.merge(redirect_uri: 'http://localhost:3781/unregistered/callback')

    assert_response_snapshot 'authorize_error'
  end

  test '同意画面で同意したときの応答' do
    sign_in users(:user)

    post oauth_authorization_path, params: new_authorization_params

    assert_response_snapshot 'authorize_approve'
  end

  test '同意画面で拒否したときの応答' do
    sign_in users(:user)

    delete oauth_authorization_path, params: new_authorization_params

    assert_response_snapshot 'authorize_deny'
  end

  test 'response_mode=form_post で同意したときの応答' do
    sign_in users(:user)

    post oauth_authorization_path, params: new_authorization_params.merge(response_mode: 'form_post')

    assert_response_snapshot 'authorize_form_post'
  end

  test '同意済みで同意画面を省いたときの応答' do
    issue_tokens

    get oauth_authorization_path, params: new_authorization_params

    assert_response_snapshot 'authorize_skip_consent'
  end

  test 'doorkeeper のアプリケーションの一覧画面の応答' do
    sign_in users(:user)

    get oauth_applications_path

    assert_response_snapshot 'oauth_applications'
  end

  private

  def new_authorization_params
    authorization_params(nonce: SecureRandom.hex(16), code_verifier: SecureRandom.urlsafe_base64(48))
  end
end
