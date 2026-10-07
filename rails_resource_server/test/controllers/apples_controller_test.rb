# frozen_string_literal: true

require 'test_helper'

class ApplesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @access_token = SecureRandom.hex(16)
    @resource_server_token = SecureRandom.hex(16)
  end

  test 'Authorization ヘッダーがないと 401 を返す' do
    get apples_show_url

    assert_response :unauthorized
  end

  test 'Bearer のあとのトークンが空だと 401 を返す' do
    get apples_show_url, headers: { 'Authorization' => 'Bearer ' }

    assert_response :unauthorized
  end

  test 'introspect が active: true を返すと 200 でりんごの情報を返す' do
    stub_token_request
    stub_introspection(status: 200, body: { active: true })

    get apples_show_url, headers: bearer_header

    assert_response :ok
    assert_equal({ 'name' => 'シナノゴールド' }, response.parsed_body)
  end

  test 'introspect のための RS のトークンを、クライアントクレデンシャルで OP に要求する' do
    stub_token_request
    stub_introspection(status: 200, body: { active: true })

    get apples_show_url, headers: bearer_header

    assert_requested :post, op_url('/oauth/token'), body: {
      'grant_type' => 'client_credentials',
      'scope' => 'introspection',
      'client_id' => ENV.fetch('CLIENT_ID_OF_RESOURCE_SERVER'),
      'client_secret' => ENV.fetch('CLIENT_SECRET_OF_RESOURCE_SERVER')
    }
  end

  test 'introspect に、受け取ったトークンと RS のトークンを渡す' do
    stub_token_request
    stub_introspection(status: 200, body: { active: true })

    get apples_show_url, headers: bearer_header

    assert_requested :post, op_url('/oauth/introspect'),
                     body: { 'token' => @access_token },
                     headers: { 'Authorization' => "Bearer #{@resource_server_token}" }
  end

  test 'introspect が active: false を返すと 401 を返す' do
    stub_token_request
    stub_introspection(status: 200, body: { active: false })

    get apples_show_url, headers: bearer_header

    assert_response :unauthorized
  end

  test 'introspect が 401 を返すと 401 を返す' do
    stub_token_request
    stub_introspection(status: 401, body: { error: 'invalid_token', error_description: 'The access token is invalid' })

    get apples_show_url, headers: bearer_header

    assert_response :unauthorized
  end

  private

  def bearer_header
    { 'Authorization' => "Bearer #{@access_token}" }
  end

  def op_url(path)
    "#{ENV.fetch('OIDC_PROVIDER_HOST')}#{path}"
  end

  def stub_token_request
    body = { access_token: @resource_server_token, token_type: 'Bearer', expires_in: 600, scope: 'introspection',
             created_at: Time.now.to_i }
    stub_request(:post, op_url('/oauth/token')).to_return(**json_response(200, body))
  end

  def stub_introspection(status:, body:)
    stub_request(:post, op_url('/oauth/introspect')).to_return(**json_response(status, body))
  end

  def json_response(status, body)
    { status: status, body: body.to_json, headers: { 'Content-Type' => 'application/json' } }
  end
end
