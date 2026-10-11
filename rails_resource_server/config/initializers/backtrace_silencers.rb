# Rails 7.0 から雛形にないファイルだが残す。BACKTRACE 環境変数でバックトレースの絞り込みを外す処理は、
# Rails 7.1 の railties になく、このファイルだけが担う。Step 5（Rails 7.2）で見直す
# （docs/upgrade/defaults/rails-7.0.md の DEF-7.0-37、docs/upgrade/defaults/rails-7.1.md の「load_defaults 7.1」）

# Be sure to restart your server when you modify this file.

# You can add backtrace silencers for libraries that you're using but don't wish to see in your backtraces.
# Rails.backtrace_cleaner.add_silencer { |line| /my_noisy_library/.match?(line) }

# You can also remove all the silencers if you're trying to debug a problem that might stem from framework code
# by setting BACKTRACE=1 before calling your invocation, like "BACKTRACE=1 ./bin/rails runner 'MyClass.perform'".
Rails.backtrace_cleaner.remove_silencers! if ENV["BACKTRACE"]
