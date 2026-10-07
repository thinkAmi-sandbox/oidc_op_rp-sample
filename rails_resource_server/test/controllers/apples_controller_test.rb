# frozen_string_literal: true

require 'test_helper'

class ApplesControllerTest < ActionDispatch::IntegrationTest
  test 'Authorization ヘッダーがないと 401 を返す' do
    get apples_show_url

    assert_response :unauthorized
  end
end
