# frozen_string_literal: true

require 'test_helper'

# devise の registerable（ユーザー登録・編集）
class UserRegistrationTest < ActionDispatch::IntegrationTest
  test 'ユーザー登録に成功すると、ユーザーが 1 人増える' do
    assert_difference 'User.count', 1 do
      post user_registration_path,
           params: { user: { email: 'new-user@example.com', password: TEST_USER_PASSWORD,
                             password_confirmation: TEST_USER_PASSWORD } }
    end
  end

  # devise の sign_in_after_change_password（既定は true）
  test 'パスワードを変えた後も、ログインしたままになる' do
    sign_in users(:user)
    put user_registration_path,
        params: { user: { email: users(:user).email, password: 'new-password', password_confirmation: 'new-password',
                          current_password: TEST_USER_PASSWORD } }

    get edit_user_registration_path

    assert_response :ok
  end
end
