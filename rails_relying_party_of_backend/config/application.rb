require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module RailsRelyingPartyOfBackend
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # 雛形の config.autoload_lib ではなく、lib を once のローダーで読む。lib/omniauth/strategies/my_op.rb は
    # 起動時に一度だけ作られる OmniAuth のミドルウェアが使うので、リロードしない。lib/omniauth は既定の推測では
    # Omniauth になるので、gem の OmniAuth に合わせる（docs/upgrade/defaults/rails-7.1.md の DEF-7.1-10、PLAN.md の Step 3）
    config.autoload_lib_once(ignore: %w(assets tasks))
    Rails.autoloaders.once.inflector.inflect("omniauth" => "OmniAuth")

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Don't generate system test files.
    config.generators.system_tests = nil
  end
end
