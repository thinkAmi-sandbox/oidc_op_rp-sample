# frozen_string_literal: true

require 'test_helper'

# RP（introspection 用）と同じく、client_id・client_secret・token を本文に入れて revoke する
class TokenRevocationTest < ActionDispatch::IntegrationTest
  include OauthFlowTestHelper

  test 'revoke すると 200 が返り、その後の introspect が active: false になる' do
    access_token = issue_tokens['access_token']
    my_op = oauth_applications(:my_op)

    post oauth_revoke_path, params: { client_id: my_op.uid, client_secret: my_op.secret, token: access_token }

    assert_response :ok

    introspect(access_token)

    assert_equal({ 'active' => false }, response.parsed_body)
  end
end
