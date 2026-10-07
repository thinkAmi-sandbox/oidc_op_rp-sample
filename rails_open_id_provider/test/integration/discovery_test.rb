# frozen_string_literal: true

require 'test_helper'

class DiscoveryTest < ActionDispatch::IntegrationTest
  test 'discovery に issuer・署名アルゴリズム・サポートする scope と subject type が出る' do
    get oauth_discovery_provider_path

    assert_response :ok
    assert_equal(
      { 'issuer' => 'http://localhost:3780', 'id_token_signing_alg_values_supported' => ['RS256'],
        'scopes_supported' => %w[openid introspection], 'subject_types_supported' => ['public'] },
      response.parsed_body.slice('issuer', 'id_token_signing_alg_values_supported', 'scopes_supported',
                                 'subject_types_supported')
    )
  end

  test 'JWKS に署名鍵の公開鍵が 1 つだけ RS256 の署名用として出る' do
    get oauth_discovery_keys_path

    keys = response.parsed_body['keys']

    assert_equal 1, keys.size
    assert_equal({ 'kty' => 'RSA', 'alg' => 'RS256', 'use' => 'sig', 'e' => 'AQAB' },
                 keys.first.slice('kty', 'alg', 'use', 'e'))
  end

  test 'JWKS の n が、設定した署名鍵（jwtRS256.key）の公開鍵と一致する' do
    get oauth_discovery_keys_path

    signing_key = OpenSSL::PKey::RSA.new(Doorkeeper::OpenidConnect.configuration.signing_key)
    expected_n = Base64.urlsafe_encode64(signing_key.n.to_s(2), padding: false)

    assert_equal expected_n, response.parsed_body['keys'].first['n']
  end
end
