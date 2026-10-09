# frozen_string_literal: true

require 'test_helper'

# 独自ストラテジー my_op で、OP からのコールバックを受けてログインするまでの流れ
class MyOpLoginTest < ActionDispatch::IntegrationTest
  include MyOpTestHelper

  test 'ログインボタンで、scope openid・nonce・PKCE S256 を付けて OP の認可エンドポイントへリダイレクトする' do
    authorization = request_authorization('my_op')

    assert_redirected_to(/\A#{Regexp.escape(op_url('/oauth/authorize'))}\?/)
    assert_equal(
      { 'client_id' => ENV.fetch('CLIENT_ID_OF_MY_OP'), 'response_type' => 'code', 'scope' => 'openid',
        'redirect_uri' => 'http://www.example.com/auth/my_op/callback', 'code_challenge_method' => 'S256' },
      authorization.slice('client_id', 'response_type', 'scope', 'redirect_uri', 'code_challenge_method')
    )
    assert_predicate authorization['nonce'], :present?
  end

  # test 環境では allow_forgery_protection が false なので、このテストの中だけ有効にする。
  # トークンの確認は omniauth-rails_csrf_protection（OmniAuth の request_validation_phase）が行う。
  # この設定はプロセス全体に効くので、テストをスレッドで並列化するときは見直す（今は並列化していない）
  test 'CSRF のトークンのないログインの POST は、OP へリダイレクトせず /auth/failure へリダイレクトする' do
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    post '/auth/my_op'

    assert_redirected_to '/auth/failure?message=ActionController%3A%3AInvalidAuthenticityToken&strategy=my_op'
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  test 'トークン要求に、認可要求の code_challenge に対応する code_verifier を付ける' do
    authorization = request_authorization('my_op')
    stub_op(id_token: id_token_for(authorization))

    receive_callback('my_op', authorization)

    assert_requested(:post, op_url('/oauth/token')) do |request|
      verifier = URI.decode_www_form(request.body).to_h['code_verifier'].to_s
      Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false) == authorization['code_challenge']
    end
  end

  test 'トークン要求では、client_id と client_secret を本文で送り、Authorization ヘッダーを付けない' do
    authorization = request_authorization('my_op')
    stub_op(id_token: id_token_for(authorization))

    receive_callback('my_op', authorization)

    assert_requested(:post, op_url('/oauth/token')) do |request|
      body = URI.decode_www_form(request.body).to_h
      body['client_id'] == ENV.fetch('CLIENT_ID_OF_MY_OP') &&
        body['client_secret'] == ENV.fetch('CLIENT_SECRET_OF_MY_OP') &&
        request.headers['Authorization'].nil?
    end
  end

  test 'トークン要求の redirect_uri は、認可要求の redirect_uri にコールバックのクエリ（code・state）が付いたもの' do
    authorization = request_authorization('my_op')
    stub_op(id_token: id_token_for(authorization))

    receive_callback('my_op', authorization)

    expected = "#{authorization['redirect_uri']}?#{request.query_string}"

    assert_requested(:post, op_url('/oauth/token')) do |token_request|
      URI.decode_www_form(token_request.body).to_h['redirect_uri'] == expected
    end
  end

  test 'ID トークンが正しいとログインでき、トップにメッセージとメールアドレスが出る' do
    log_in_via_op

    assert_redirected_to root_path
    follow_redirect!

    assert_select 'p', 'ログインしました'
    assert_select 'strong', OP_USER_EMAIL
  end

  test 'ID トークンが正しいと、userinfo の sub とメールアドレスで OpUser が作られる' do
    assert_difference 'OpUser.count', 1 do
      log_in_via_op
    end

    assert_equal(
      { 'provider' => 'my_op', 'uid' => OP_USER_SUB, 'email' => OP_USER_EMAIL },
      OpUser.last.attributes.slice('provider', 'uid', 'email')
    )
  end
end
