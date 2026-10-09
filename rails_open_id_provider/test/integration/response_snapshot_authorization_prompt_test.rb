# frozen_string_literal: true

require 'test_helper'

# RP は送らないが、認可要求の prompt・max_age の応答（ステータス・ヘッダー・本文）を、
# test/snapshots/responses/ のスナップショットと比べる。
# doorkeeper-openid_connect 1.8.11・1.10.0 で扱いが変わる（docs/upgrade/PLAN.md の Step 1-b-3）。
# OP の auth_time_from_resource_owner は値を返さないので、max_age を付けると再認証の対象になる
class ResponseSnapshotAuthorizationPromptTest < ActionDispatch::IntegrationTest
  include OauthFlowTestHelper
  include ResponseSnapshotHelper

  test 'ログイン済みで prompt=select_account を付けた認可要求の応答' do
    sign_in users(:user)

    get oauth_authorization_path, params: new_authorization_params.merge(prompt: 'select_account')

    assert_response_snapshot 'authorize_prompt_select_account'
  end

  test '同意済みで prompt=none と max_age を付けた認可要求の応答' do
    issue_tokens

    get oauth_authorization_path, params: new_authorization_params.merge(prompt: 'none', max_age: 600)

    assert_response_snapshot 'authorize_prompt_none_max_age'
  end

  test 'ログイン済みで max_age=0 を付けた認可要求の応答' do
    sign_in users(:user)

    get oauth_authorization_path, params: new_authorization_params.merge(max_age: 0)

    assert_response_snapshot 'authorize_max_age_zero'
  end

  private

  def new_authorization_params
    authorization_params(nonce: SecureRandom.hex(16), code_verifier: SecureRandom.urlsafe_base64(48))
  end
end
