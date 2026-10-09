# frozen_string_literal: true

require 'test_helper'

# OP の devise の画面（ログイン・ユーザー登録・編集・ログアウト）の応答（ステータス・ヘッダー・本文）を、
# test/snapshots/responses/ のスナップショットと比べる
class ResponseSnapshotDeviseTest < ActionDispatch::IntegrationTest
  include ResponseSnapshotHelper

  test 'ログイン画面の応答' do
    get new_user_session_path

    assert_response_snapshot 'users_sign_in'
  end

  test '誤ったパスワードでログインしたときの応答' do
    post user_session_path, params: { user: { email: users(:user).email, password: 'wrong-password' } }

    assert_response_snapshot 'users_sign_in_failure'
  end

  test '正しいパスワードでログインしたときの応答' do
    post user_session_path, params: { user: { email: users(:user).email, password: TEST_USER_PASSWORD } }

    assert_response_snapshot 'users_sign_in_success'
  end

  test 'ユーザー登録画面の応答' do
    get new_user_registration_path

    assert_response_snapshot 'users_sign_up'
  end

  test 'ユーザー編集画面の応答' do
    sign_in users(:user)

    get edit_user_registration_path

    assert_response_snapshot 'users_edit'
  end

  test 'ログアウトの応答' do
    sign_in users(:user)

    delete destroy_user_session_path

    assert_response_snapshot 'users_sign_out'
  end
end
