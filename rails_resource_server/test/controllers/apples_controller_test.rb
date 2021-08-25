require "test_helper"

class ApplesControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    get apples_show_url
    assert_response :success
  end
end
