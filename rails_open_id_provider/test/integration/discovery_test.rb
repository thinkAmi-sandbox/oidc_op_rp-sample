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

  # 現在の挙動の記録。RP・RS は使わない。doorkeeper-openid_connect 1.8.9 の Webfinger は href に root_url を使うが、
  # OP の routes には root がない
  test 'Webfinger は root_url がなくて落ちる' do
    error = assert_raises(NoMethodError) do
      get '/.well-known/webfinger', params: { resource: 'acct:user@example.com' }
    end
    assert_match(/undefined method `root_url'/, error.message)
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

  # JWT のライブラリが json-jwt から ruby-jwt に変わっても kid の値が変わらないよう、作り方をライブラリなしで書く
  test 'JWKS の kid は、署名鍵の公開鍵の RFC 7638 の thumbprint' do
    get oauth_discovery_keys_path

    signing_key = OpenSSL::PKey::RSA.new(Doorkeeper::OpenidConnect.configuration.signing_key)
    # RFC 7638 は、必須のメンバーだけを辞書順に並べ、空白なしの JSON にしたものの SHA-256 を求める
    members = { e: Base64.urlsafe_encode64(signing_key.e.to_s(2), padding: false), kty: 'RSA',
                n: Base64.urlsafe_encode64(signing_key.n.to_s(2), padding: false) }
    expected_kid = Base64.urlsafe_encode64(Digest::SHA256.digest(members.to_json), padding: false)

    assert_equal expected_kid, response.parsed_body['keys'].first['kid']
  end
end
