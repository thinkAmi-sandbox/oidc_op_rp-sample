# frozen_string_literal: true

require 'test_helper'

class SessionsTest < ActionDispatch::IntegrationTest
  include MyOpTestHelper

  test '未ログインのトップに Login ボタンが出る' do
    get root_path

    assert_response :ok
    assert_select 'form[action="/auth/my_op"] button', 'Login'
  end

  test 'ログアウトすると、トップに「ログアウトしました」が出る' do
    log_in_via_op

    get logout_path

    assert_redirected_to root_path
    follow_redirect!

    assert_select 'p', 'ログアウトしました'
  end

  test 'ログアウトするとセッションのユーザーが消え、トップが未ログインの表示に戻る' do
    log_in_via_op

    get logout_path
    follow_redirect!

    assert_nil session[:user_id]
    assert_select 'form[action="/auth/my_op"] button', 'Login'
  end
end
