# frozen_string_literal: true

require 'test_helper'

# 独自ストラテジー my_op の ID トークンの検証。
# 検証で出た例外は omniauth 2.0.4 が rescue して env['omniauth.error'] に残し、
# RACK_ENV が development でなければ /auth/failure へリダイレクトする（現在の挙動の記録）
class MyOpIdTokenVerificationTest < ActionDispatch::IntegrationTest
  include MyOpTestHelper

  setup do
    @authorization = request_authorization('my_op')
  end

  test 'nonce が認可要求のものと違うと、JWT::VerificationError でログインに失敗する' do
    stub_op(id_token: id_token_for(@authorization, nonce: SecureRandom.urlsafe_base64))

    assert_login_failed_with JWT::VerificationError
  end

  test 'ID トークンの kid が JWKS にないと、JWT::VerificationError でログインに失敗する' do
    stub_op(id_token: id_token_for(@authorization, kid: 'unknown-key'))

    assert_login_failed_with JWT::VerificationError
  end

  test 'JWKS にない鍵で署名されていると、JWT::VerificationError でログインに失敗する' do
    stub_op(id_token: id_token_for(@authorization, key: OpenSSL::PKey::RSA.generate(2048)))

    assert_login_failed_with JWT::VerificationError
  end

  test 'iss が OP と違うと、JWT::InvalidIssuerError でログインに失敗する' do
    stub_op(id_token: id_token_for(@authorization, iss: 'http://localhost:9999'))

    assert_login_failed_with JWT::InvalidIssuerError
  end

  test 'aud が自分の client_id と違うと、JWT::InvalidAudError でログインに失敗する' do
    stub_op(id_token: id_token_for(@authorization, aud: ENV.fetch('CLIENT_ID_OF_INTROSPECTION')))

    assert_login_failed_with JWT::InvalidAudError
  end

  test 'ID トークンの有効期限（発行から 120 秒）を過ぎると、JWT::ExpiredSignature でログインに失敗する' do
    freeze_time
    stub_op(id_token: id_token_for(@authorization))
    travel 121.seconds

    assert_login_failed_with JWT::ExpiredSignature
  end

  private

  def assert_login_failed_with(error_class)
    receive_callback('my_op', @authorization)

    assert_redirected_to %r{/auth/failure\?message=[^&]+&strategy=my_op\z}
    assert_instance_of error_class, request.env['omniauth.error']
    assert_nil session[:user_id]
  end
end
