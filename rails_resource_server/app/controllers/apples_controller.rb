class ApplesController < ApplicationController
  before_action :validate_bearer_token
  def show
    render json: { name: 'シナノゴールド' }
  end

  private

  def validate_bearer_token
    # Bearer トークンを取得
    authorization_header = request.headers['Authorization']
    return render status: 401 if authorization_header.blank?

    access_token = authorization_header.gsub('Bearer ', '')
    return render status: 401 if access_token.blank?

    # クライアントクレデンシャルフローで、Resource Serverのアクセストークンを取得する
    client = OAuth2::Client.new(ENV['CLIENT_ID_OF_RESOURCE_SERVER'],
                                ENV['CLIENT_SECRET_OF_RESOURCE_SERVER'],
                                site: ENV['OIDC_PROVIDER_HOST'])
    oauth2_response = client.client_credentials.get_token(scope: 'introspection')

    # Faradayを使って、Introspectionエンドポイントで access_token を検証
    headers = { Authorization: "Bearer #{oauth2_response.token}" }
    params = { token: access_token }
    response = Faraday.post("#{ENV['OIDC_PROVIDER_HOST']}/oauth/introspect", params, headers)

    response.tap do |r|
      puts '======> introspection'
      puts "STATUS: #{r.status}"
      puts "BODY  : #{r.body}"
      puts '<====== introspection'
    end

    body = JSON.parse(response.body)
    render status: 401 if response.status == 401 || body['active'] == false
  end
end
