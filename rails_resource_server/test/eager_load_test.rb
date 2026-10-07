# frozen_string_literal: true

require 'test_helper'

# テストの環境は eager_load が false なので、どのテストからも使われないクラス
# （生成物の基底クラスなど）は読み込まれない。ここですべて読み込み、クラス本体が動くことを確かめる
class EagerLoadTest < ActiveSupport::TestCase
  test 'アプリのコードをすべて読み込める' do
    assert_nothing_raised { Rails.application.eager_load! }
  end
end
