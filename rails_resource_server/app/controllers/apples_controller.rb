# frozen_string_literal: true

class ApplesController < ApplicationController
  before_action :validate_bearer_token
  def show
    render json: { name: 'シナノゴールド' }
  end

  private

  # トークンの取得から introspect の結果の判定までを 1 か所で読めるよう、メソッドを分けていない
  def validate_bearer_token # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    # Bearer トークンを取得
    authorization_header = request.headers['Authorization']
    return render status: :unauthorized if authorization_header.blank?

    access_token = authorization_header.gsub('Bearer ', '')
    return render status: :unauthorized if access_token.blank?

    # クライアントクレデンシャルフローで、Resource Serverのアクセストークンを取得する
    client = OAuth2::Client.new(ENV['CLIENT_ID_OF_RESOURCE_SERVER'],
                                ENV['CLIENT_SECRET_OF_RESOURCE_SERVER'],
                                site: ENV['OIDC_PROVIDER_HOST'],
                                # oauth2 2.x の既定値は Basic 認証。client_id と secret は本文で送る
                                auth_scheme: :request_body)
    oauth2_response = client.client_credentials.get_token(scope: 'introspection')

    # Faradayを使って、Introspectionエンドポイントで access_token を検証
    headers = { Authorization: "Bearer #{oauth2_response.token}" }
    params = { token: access_token }
    response = Faraday.post("#{ENV['OIDC_PROVIDER_HOST']}/oauth/introspect", params, headers)

    # introspect の応答を標準出力で確かめるための出力。logger にすると出力先が変わるので puts のまま残す
    # rubocop:disable Rails/Output
    response.tap do |r|
      puts '======> introspection'
      puts "STATUS: #{r.status}"
      puts "BODY  : #{r.body}"
      puts '<====== introspection'
    end
    # rubocop:enable Rails/Output

    body = JSON.parse(response.body)
    render status: :unauthorized if response.status == 401 || body['active'] == false
  end
end
