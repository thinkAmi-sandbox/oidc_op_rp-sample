# frozen_string_literal: true

# annotaterb の generator（annotate_rb:install）の雛形。RuboCop に合わせて、マジックコメントを足し、
# 文字列をシングルクォートにした（docs/upgrade/defaults/rails-7.2.md の DEF-7.2-01）

# This rake task was added by annotate_rb gem.

# Can set `ANNOTATERB_SKIP_ON_DB_TASKS` to be anything to skip this
if Rails.env.development? && ENV['ANNOTATERB_SKIP_ON_DB_TASKS'].nil?
  require 'annotate_rb'

  # Can modify the config path here if needed - by default, it's .annotaterb.yml in the root of the project
  # AnnotateRb::ConfigFinder.config_path = ""
  AnnotateRb::Core.load_rake_tasks
end
