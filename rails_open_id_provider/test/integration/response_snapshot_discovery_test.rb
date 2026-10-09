# frozen_string_literal: true

require 'test_helper'

# OP の discovery・JWKS の応答（ステータス・ヘッダー・本文）を、test/snapshots/responses/ のスナップショットと比べる
class ResponseSnapshotDiscoveryTest < ActionDispatch::IntegrationTest
  include ResponseSnapshotHelper

  test 'discovery の応答' do
    get oauth_discovery_provider_path

    assert_response_snapshot 'discovery'
  end

  test '/.well-known/oauth-authorization-server の応答' do
    get '/.well-known/oauth-authorization-server'

    assert_response_snapshot 'oauth_authorization_server'
  end

  test 'JWKS の応答' do
    get oauth_discovery_keys_path

    assert_response_snapshot 'jwks'
  end
end
