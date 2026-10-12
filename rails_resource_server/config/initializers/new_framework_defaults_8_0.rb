# Be sure to restart your server when you modify this file.
#
# This file eases your Rails 8.0 framework defaults upgrade.
#
# Uncomment each configuration one by one to switch to the new default.
# Once your application is ready to run with all new defaults, you can remove
# this file and set the `config.load_defaults` to `8.0`.
#
# Read the Guide for Upgrading Ruby on Rails for more info on each option.
# https://guides.rubyonrails.org/upgrading_ruby_on_rails.html

###
# Specifies whether `to_time` methods preserve the UTC offset of their receivers or preserves the timezone.
# If set to `:zone`, `to_time` methods will use the timezone of their receivers.
# If set to `:offset`, `to_time` methods will use the UTC offset.
# If `false`, `to_time` methods will convert to the local system UTC offset instead.
#++
#
# このアプリでは config/application.rb で設定している。ここで設定すると、config/initializers より前の
# initializer（active_support.set_configs）が古い値を渡して非推奨の警告を出し、test の deprecation = :raise で
# 起動できない（rails/rails#54015・#54449、docs/upgrade/defaults/rails-8.0.md の DEF-8.0-01）
# Rails.application.config.active_support.to_time_preserves_timezone = :zone

###
# When both `If-Modified-Since` and `If-None-Match` are provided by the client
# only consider `If-None-Match` as specified by RFC 7232 Section 6.
# If set to `false` both conditions need to be satisfied.
#++
#
# ここで有効にしても効かない。ActionDispatch の railtie の initializer（action_dispatch.configure）が、config/initializers より前に
# ActionDispatch::Http::Cache::Request.strict_freshness に値を入れるため。load_defaults 8.0 で入る
# （docs/upgrade/PLAN.md の Step 6、LOG.md の Step 6 の「作業計画からの変更点」）
# Rails.application.config.action_dispatch.strict_freshness = true

###
# Set `Regexp.timeout` to `1`s by default to improve security over Regexp Denial-of-Service attacks.
#++
Regexp.timeout = 1
