# frozen_string_literal: true

require 'test_helper'

# RS の応答（ステータス・ヘッダー・本文）を test/snapshots/responses/ のスナップショットと比べる。
# OP とのやり取りは apples_controller_test.rb と同じく WebMock で差し替える
class ResponseSnapshotTest < ActionDispatch::IntegrationTest
  include ResponseSnapshotHelper

  test 'Authorization ヘッダーがないときの応答' do
    get apples_show_url

    assert_response_snapshot 'apples_show_without_token'
  end

  test 'introspect が active: true を返したときの応答' do
    stub_op_introspection(active: true)

    get apples_show_url, headers: { 'Authorization' => "Bearer #{SecureRandom.hex(16)}" }

    assert_response_snapshot 'apples_show_with_active_token'
  end

  test 'introspect が active: false を返したときの応答' do
    stub_op_introspection(active: false)

    get apples_show_url, headers: { 'Authorization' => "Bearer #{SecureRandom.hex(16)}" }

    assert_response_snapshot 'apples_show_with_inactive_token'
  end

  private

  def stub_op_introspection(active:)
    op = ENV.fetch('OIDC_PROVIDER_HOST')
    token_body = { access_token: SecureRandom.hex(16), token_type: 'Bearer', expires_in: 600, scope: 'introspection',
                   created_at: Time.now.to_i }
    stub_request(:post, "#{op}/oauth/token").to_return(**json_response(token_body))
    stub_request(:post, "#{op}/oauth/introspect").to_return(**json_response({ active: active }))
  end

  def json_response(body)
    { status: 200, body: body.to_json, headers: { 'Content-Type' => 'application/json' } }
  end
end
