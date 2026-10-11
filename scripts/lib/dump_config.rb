# frozen_string_literal: true

# scripts/compare-config から、アプリのディレクトリで `bundle exec ruby` で呼ぶ。標準出力に次のものを書き出す。
#   1. 起動の途中に読み込み済みの部品（ActiveSupport.on_load の名前）。config/application.rb の後、
#      config/initializers の直前、initialize! の後の 3 か所
#   2. initialize! の後に読み込み済みの Active Record のモデル
#   3. filter_parameters と ActiveRecord::Base.filter_attributes
#   4. 各フレームワークの config.<名前> の値と、同じ名前のメソッドを持つクラス・モジュールに入った値
#      （Rails は設定をクラスに写すので、クラスの値が実際に効いている値）
#   5. 設定のキーと名前が違うため 4 で拾えない値
#   6. アプリのモデルの関連の inverse_of（eager load の後）
# 値はクラスを読み込んでから読み、非推奨の警告を止めて読む。オブジェクトの ID とローカルのパスは伏せる。
# 手順の中での使い方は docs/upgrade/TIPS.md の「設定の値と応答の比較」。

lines = []
loaded = lambda do
  ActiveSupport.instance_variable_get(:@loaded).select { |_, hooks| hooks.any? }.keys.map(&:to_s).sort.join(', ')
end

require './config/application'
lines << "## 読み込み済みの部品（config/application.rb の後）: #{loaded.call}"
Rails.application.initializer('compare_config', before: :load_config_initializers) do
  lines << "## 読み込み済みの部品（config/initializers の直前）: #{loaded.call}"
end
Rails.application.initialize!
lines << "## 読み込み済みの部品（initialize! の後）: #{loaded.call}"

# ActiveRecord::Base を参照すると読み込まれるので、読み込み済みのときだけ数える
models = if defined?(ActiveRecord) && ActiveRecord.autoload?(:Base).nil?
           ActiveRecord::Base.descendants.filter_map(&:name).sort
         else
           []
         end
lines << "## 読み込み済みのモデル（initialize! の後）: #{models.join(', ')}"

app_dir = Dir.pwd
bundle_dir = Bundler.bundle_path.to_s
# 値の型が単純なもの（文字列・数値・配列・ハッシュ・クラスなど）は inspect し、ほかのオブジェクトはクラス名だけにする。
# オブジェクトの inspect には、プロセス ID など実行ごとに変わる値が入るため
describe = lambda do |value|
  case value
  when nil, true, false, Numeric, String, Symbol, Regexp, Range, Pathname then value.inspect
  when Module then value.name || value.inspect
  when Array, Set then "[#{value.map { |v| describe.call(v) }.join(', ')}]"
  when Hash then "{#{value.map { |k, v| "#{describe.call(k)}=>#{describe.call(v)}" }.join(', ')}}"
  when Proc then "#<Proc #{value.source_location&.join(':')}>"
  else "#<#{value.class}>"
  end
end
normalize = lambda do |value|
  describe.call(value)
          .gsub(/0x[0-9a-f]{6,}/, '0x…')
          .gsub(bundle_dir, '<BUNDLE>')
          .gsub(app_dir, '<APP>')
end
# Rails 7.1 から、ActiveSupport::Deprecation をシングルトンとして使うこと自体が非推奨になる
silence = if Rails.application.respond_to?(:deprecators)
            ->(&block) { Rails.application.deprecators.silence(&block) }
          else
            ->(&block) { ActiveSupport::Deprecation.silence(&block) }
          end
read = lambda do |&block|
  normalize.call(silence.call(&block))
rescue StandardError => e
  "ERROR #{e.class}: #{e.message[0, 80]}"
end

# on_load の中で値が入る設定があるので、値を読む前にフレームワークのクラスを読み込む
framework_classes = %w[
  ActionView::Base ActionController::Base ActionController::API ActionDispatch::Request ActionDispatch::Response
  ActiveRecord::Base ActionMailer::Base ActiveJob::Base
]
framework_classes.each { |name| Object.const_get(name) if Object.const_defined?(name.split('::').first) }

lines << "## filter_parameters: #{read.call { Rails.application.config.filter_parameters.map(&:to_s).sort }}"
if defined?(ActiveRecord::Base)
  attributes = read.call { ActiveRecord::Base.filter_attributes.map(&:to_s).sort }
  lines << "## ActiveRecord::Base.filter_attributes: #{attributes}"
end

constant = ->(name) { Object.const_get(name) if Object.const_defined?(name) }
helper_modules = if defined?(ActionView::Helpers)
                   ActionView::Helpers.constants.sort.map { |c| "ActionView::Helpers::#{c}" }
                 else
                   []
                 end
receivers = {
  active_record: %w[ActiveRecord::Base ActiveRecord],
  action_controller: %w[ActionController::Base ActionController::API],
  action_view: %w[ActionView::Base] + helper_modules,
  action_dispatch: %w[ActionDispatch::Request ActionDispatch::Response ActionDispatch],
  action_mailer: %w[ActionMailer::Base],
  active_job: %w[ActiveJob::Base],
  active_storage: %w[ActiveStorage],
  active_support: %w[ActiveSupport ActiveSupport::Digest Digest::UUID]
}

config = Rails.application.config
receivers.each do |namespace, names|
  next unless config.respond_to?(namespace)

  options = config.public_send(namespace)
  lines << "## config.#{namespace}"
  options.keys.map(&:to_s).sort.each do |key|
    lines << "config.#{namespace}.#{key} = #{read.call { options[key.to_sym] }}"
    names.each do |name|
      receiver = constant.call(name)
      next unless receiver.is_a?(Module) && receiver.respond_to?(key)
      # 引数なしで呼べるもの（arity が 0 か、省略できる引数だけの -1）。委譲のメソッドは (...) で -1 になる
      next unless [0, -1].include?(receiver.method(key).arity)

      lines << "  #{name}.#{key} = #{read.call { receiver.public_send(key) }}"
    end
  end
end

lines << '## 設定のキーと名前が違う値'
extras = {
  'ActionController::Base._wrapper_options' => -> { ActionController::Base._wrapper_options.to_h },
  'ActionController::API._wrapper_options' => -> { ActionController::API._wrapper_options.to_h },
  'ActionDispatch::Request.return_only_media_type_on_content_type' => lambda {
    ActionDispatch::Request.return_only_media_type_on_content_type
  },
  'ActionMailer::Base.smtp_settings' => -> { ActionMailer::Base.smtp_settings },
  'ActionController::TestCase.executor_around_each_request' => lambda {
    require 'action_controller/test_case'
    ActionController::TestCase.executor_around_each_request
  },
  'ActiveSupport::TestCase の test helper' => lambda {
    require 'active_support/test_case'
    ActiveSupport::TestCase.ancestors.map(&:to_s).grep(/TestHelper/)
  },
  'ActiveSupport::Cache.format_version' => -> { ActiveSupport::Cache.format_version },
  'ActiveSupport::TimeWithZone.name を上書きしているか' => lambda {
    ActiveSupport::TimeWithZone.singleton_methods(false).include?(:name)
  },
  'Integer#to_s(:delimited)' => -> { 1000.to_s(:delimited) },
  'key generator の digest' => lambda {
    Rails.application.key_generator.instance_variable_get(:@key_generator).instance_variable_get(:@hash_digest_class)
  }
}
extras.each { |label, block| lines << "#{label} = #{read.call(&block)}" }

# gem のモデルは eager load でも読み込まれるとは限らず、読み込みの変化が関連の変化に見えてしまうので、アプリのモデルだけを見る
# （gem のモデルの読み込みの変化は、上の「読み込み済みのモデル」に出る）
lines << '## アプリのモデルの関連の inverse_of（eager load の後）'
Rails.application.eager_load!
if defined?(ActiveRecord::Base)
  app_models = ActiveRecord::Base.descendants.reject(&:abstract_class?).select do |model|
    model.name && Object.const_source_location(model.name)&.first.to_s.start_with?(Rails.root.to_s)
  end
  app_models.sort_by(&:name).each do |model|
    model.reflect_on_all_associations.each do |reflection|
      lines << "#{model.name}##{reflection.name} inverse_of=#{read.call { reflection.inverse_of&.name }}"
    end
  end
end

$stdout.puts lines
