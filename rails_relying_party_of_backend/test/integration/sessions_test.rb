# frozen_string_literal: true

require 'test_helper'

class SessionsTest < ActionDispatch::IntegrationTest
  include MyOpTestHelper

  test '未ログインのトップに Login ボタンが出る' do
    get root_path

    assert_response :ok
    assert_select 'form[action="/auth/my_op"] button', 'Login'
  end

  # serializer の設定は config/initializers/session_store.rb の on_load(:active_record) にある。
  # 設定が効かないと、既定の :marshal（Base64 の Marshal）で保存される
  test 'セッションは sessions テーブルに JSON で保存する' do
    post '/auth/my_op'

    session_record = ActiveRecord::SessionStore::Session.last
    raw_data = session_record.read_attribute(ActiveRecord::SessionStore::Session.data_column_name)

    assert_equal session_record.data, JSON.parse(raw_data)['value']
  end

  # JSON の文字列にするとき、< > & を escape しない（activerecord-session_store 2.2.0 の JsonSerializer は Ruby 標準の
  # JSON.dump で書き、Active Support の JSON の encoder を通らない。DEF-7.0-38）。omniauth は Referer を omniauth.origin に入れる
  test 'セッションの JSON は、< > & を escape せずに保存する' do
    post '/auth/my_op', headers: { 'Referer' => 'http://www.example.com/?a=1&b=<x>' }

    session_record = ActiveRecord::SessionStore::Session.last
    raw_data = session_record.read_attribute(ActiveRecord::SessionStore::Session.data_column_name)

    assert_includes raw_data, '"omniauth.origin":"http://www.example.com/?a=1&b=<x>"'
  end

  test 'ログアウトすると、トップに「ログアウトしました」が出る' do
    log_in_via_op

    get logout_path

    assert_redirected_to root_path
    follow_redirect!

    assert_select 'p', 'ログアウトしました'
  end

  test 'ログアウトするとセッションのユーザーが消え、トップが未ログインの表示に戻る' do
    log_in_via_op

    assert_predicate session[:user_id], :present?

    get logout_path
    follow_redirect!

    assert_nil session[:user_id]
    assert_select 'form[action="/auth/my_op"] button', 'Login'
  end
end
