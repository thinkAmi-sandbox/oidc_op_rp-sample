# Be sure to restart your server when you modify this file.

# Configure parameters to be filtered from the log file. Use this to limit dissemination of
# sensitive information. See the ActiveSupport::ParameterFilter documentation for supported
# notations and behaviors.
# 部分一致のため、OIDC の access_token / id_token / refresh_token は :token で、client_secret は :secret で、
# 認可コードの code と PKCE の code_verifier は :code で伏せられる
Rails.application.config.filter_parameters += [
  :passw, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :code
]
