# frozen_string_literal: true

require 'test_helper'

class UserSignInTest < ActionDispatch::IntegrationTest
  test '正しいパスワードでログインできる' do
    post user_session_path, params: { user: { email: users(:user).email, password: TEST_USER_PASSWORD } }

    assert_redirected_to '/'
    assert_equal 'Signed in successfully.', flash[:notice]
  end

  test '誤ったパスワードではログインできず、ログイン画面にメッセージが出る' do
    post user_session_path, params: { user: { email: users(:user).email, password: SecureRandom.hex(8) } }

    assert_response :ok
    assert_equal 'Invalid email or password.', flash[:alert]
  end

  test '未ログインで認可エンドポイントに来ると、ログイン画面へリダイレクトする' do
    get oauth_authorization_path, params: { client_id: oauth_applications(:my_op).uid, response_type: 'code' }

    assert_redirected_to new_user_session_path
  end
end
