# frozen_string_literal: true

require 'test_helper'

# introspection 用 RP（provider: introspection）でログインした後、コールバックで RS と OP の revoke を呼ぶ流れ
class IntrospectionsTest < ActionDispatch::IntegrationTest
  include MyOpTestHelper

  RESOURCE_SERVER_URL = 'http://localhost:3782/apples/show'

  setup do
    @access_token = SecureRandom.hex(16)
    @calls = []
    stub_request(:get, RESOURCE_SERVER_URL).to_return do |request|
      @calls << [:resource_server, request.headers['Authorization']]
      json_response({ name: 'シナノゴールド' })
    end
    stub_request(:post, op_url('/oauth/revoke')).to_return do |request|
      @calls << [:revoke, URI.decode_www_form(request.body).to_h]
      json_response({})
    end
  end

  test '/introspection に Login ボタンが出る' do
    get introspection_path

    assert_response :ok
    assert_select 'form[action="/auth/introspection"] button', 'Login'
  end

  test 'コールバックで、RS を正しいトークン・_bad を付けたトークンで呼び、revoke の後に正しいトークンで呼ぶ' do
    log_in_via_op('introspection', access_token: @access_token)

    revoke_params = { 'client_id' => ENV.fetch('CLIENT_ID_OF_INTROSPECTION'),
                      'client_secret' => ENV.fetch('CLIENT_SECRET_OF_INTROSPECTION'), 'token' => @access_token }

    assert_equal [
      [:resource_server, "Bearer #{@access_token}"],
      [:resource_server, "Bearer #{@access_token}_bad"],
      [:revoke, revoke_params],
      [:resource_server, "Bearer #{@access_token}"]
    ], @calls
  end

  test 'コールバックの後は /introspection に戻る' do
    log_in_via_op('introspection', access_token: @access_token)

    assert_redirected_to introspection_path
  end
end
