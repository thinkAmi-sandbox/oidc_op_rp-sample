require 'omniauth/strategies/my_op'

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :my_op,
           ENV['CLIENT_ID_OF_MY_OP'],
           ENV['CLIENT_SECRET_OF_MY_OP']

  # ストラテジーの設定内容を上書きする場合は、以下のように追加しても良い
  # 参考: https://github.com/auth0/omniauth-auth0#additional-authentication-parameters
  # {
  #   authorize_params: {
  #     scope: 'openid profile',
  #     prompt: 'none'
  #   }
  # }
end