# frozen_string_literal: true

require 'test_helper'

# RP は使わないが、上書きしている doorkeeper のビュー（app/views/doorkeeper/authorizations/）を通る認可エンドポイントの経路
class AuthorizationEndpointTest < ActionDispatch::IntegrationTest
  include OauthFlowTestHelper

  test 'response_mode=form_post で同意すると、redirect_uri へ認可コードを POST するフォームを返す' do
    sign_in users(:user)

    params = authorization_params(nonce: SecureRandom.hex(16), code_verifier: SecureRandom.urlsafe_base64(48))

    post oauth_authorization_path, params: params.merge(response_mode: 'form_post')

    assert_select 'form[action=?][method=post] input[type=hidden][name=code][value=?]',
                  'http://localhost:3781/auth/my_op/callback', Doorkeeper::AccessGrant.last.token
  end

  # doorkeeper 5.6.7 から、エラー画面をエラーの種類に応じたステータスで返す（5.6.6 までは 200）
  test '登録されていない redirect_uri では、エラーの説明を 400 で表示する' do
    sign_in users(:user)

    params = authorization_params(nonce: SecureRandom.hex(16), code_verifier: SecureRandom.urlsafe_base64(48))

    get oauth_authorization_path, params: params.merge(redirect_uri: 'http://localhost:3781/unregistered/callback')

    assert_response :bad_request
    assert_select 'main pre', text: I18n.t('doorkeeper.errors.messages.invalid_redirect_uri')
  end

  test '同意画面で拒否すると、error=access_denied を付けて redirect_uri へリダイレクトする' do
    sign_in users(:user)

    delete oauth_authorization_path, params: authorization_params(nonce: SecureRandom.hex(16),
                                                                  code_verifier: SecureRandom.urlsafe_base64(48))

    assert_redirected_to %r{\Ahttp://localhost:3781/auth/my_op/callback\?error=access_denied&}
  end

  # 現在の挙動の記録。doorkeeper は拒否の応答をローカル変数 auth で form_post のビューに渡すが、
  # 上書きしているビューはインスタンス変数 @authorize_response を読み、拒否の経路では値が入らない
  test 'response_mode=form_post で拒否すると、上書きしている form_post のビューが落ちる' do
    sign_in users(:user)

    params = authorization_params(nonce: SecureRandom.hex(16), code_verifier: SecureRandom.urlsafe_base64(48))

    error = assert_raises(ActionView::Template::Error) do
      delete oauth_authorization_path, params: params.merge(response_mode: 'form_post')
    end
    assert_match(/undefined method `body' for nil/, error.message)
  end
end
