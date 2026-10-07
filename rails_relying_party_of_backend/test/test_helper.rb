# frozen_string_literal: true

# アプリより先に計測を始めないと、起動時に読み込まれるファイルのカバレッジが取れない
require 'simplecov'
SimpleCov.start 'rails'

ENV['RAILS_ENV'] ||= 'test'
# omniauth は RACK_ENV が development のときだけ認証の失敗を例外にして外へ出す。
# 手元の RACK_ENV によって /auth/failure へのリダイレクトの記録が変わらないよう、test に固定する
ENV['RACK_ENV'] = 'test'
require_relative '../config/environment'
require 'rails/test_help'

# 外部への HTTP 通信はすべて遮断し、必要なものはテストごとに WebMock で差し替える
require 'webmock/minitest'

Dir[File.expand_path('support/**/*.rb', __dir__)].each { |file| require file }
