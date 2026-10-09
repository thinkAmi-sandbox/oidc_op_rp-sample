# ActiveRecordにセッションを保存
Rails.application.config.session_store :active_record_store, :key => '_my_app_session'

# 中身を見やすくするよう、JSON形式で保存
# config/application.rb で設定すると、起動の途中で ActiveRecord::Base が読み込まれ、
# config/initializers の Active Record などの設定（new_framework_defaults_*.rb など）が反映されなくなる。
# そのため、ActiveRecord::Base が読み込まれたときに設定する
ActiveSupport.on_load(:active_record) do
  ActiveRecord::SessionStore::Session.serializer = :json
end
