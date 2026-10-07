# frozen_string_literal: true

# アプリより先に計測を始めないと、起動時に読み込まれるファイルのカバレッジが取れない
require 'simplecov'
SimpleCov.start 'rails'

ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'

# 外部への HTTP 通信はすべて遮断し、必要なものはテストごとに WebMock で差し替える
require 'webmock/minitest'
