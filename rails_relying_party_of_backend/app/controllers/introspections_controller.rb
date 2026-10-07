# frozen_string_literal: true

class IntrospectionsController < ApplicationController
  def index; end

  # RS と OP の応答を標準出力で確かめるための出力。logger にすると出力先が変わるので puts のまま残す
  # rubocop:disable Rails/Output

  # RS への 3 通りの呼び出し（正しいトークン・不正なトークン・revoke 後）を順に読めるよう、メソッドを分けていない
  def callback # rubocop:disable Metrics/MethodLength
    auth_hash = request.env['omniauth.auth']
    access_token = auth_hash['credentials']['token']

    puts '================> CORRECT access_token'
    # Authorization Serverから受け取った access_token を使って、Resource Serverへリクエスト
    fetch_resource_server(access_token)

    # 不正な access_token を使って、Resource Serverへリクエスト
    puts '================> INCORRECT access_token'
    incorrect_access_token = "#{access_token}_bad"
    fetch_resource_server(incorrect_access_token)

    # Clientで access_token を revoke 後に、Resource Serverへリクエスト
    puts '================> REVOKE access_token'
    revoke_tokens(access_token)
    fetch_resource_server(access_token)

    redirect_to introspection_path, notice: access_token
  end

  private

  def fetch_resource_server(access_token)
    headers = { Authorization: "Bearer #{access_token}" }
    response = Faraday.get('http://localhost:3782/apples/show', {}, headers)
    response.tap do |r|
      puts '======> API'
      puts "STATUS: #{r.status}"
      puts "BODY  : #{r.body}"
      puts '<====== API'
    end
  end

  # revoke の要求と応答の出力を 1 か所で読めるよう、メソッドを分けていない
  def revoke_tokens(access_token) # rubocop:disable Metrics/MethodLength
    params = {
      client_id: ENV['CLIENT_ID_OF_INTROSPECTION'],
      client_secret: ENV['CLIENT_SECRET_OF_INTROSPECTION'],
      token: access_token
    }
    response = Faraday.post("#{ENV['OIDC_PROVIDER_HOST']}/oauth/revoke", params)
    response.tap do |r|
      puts '======> revocation'
      # puts r.header.all # 必要に応じてレスポンスヘッダを確認
      # puts '----------------'
      puts "STATUS: #{r.status}"
      puts "BODY  : #{r.body}"
      puts '<====== revocation'
    end
  end
  # rubocop:enable Rails/Output
end
