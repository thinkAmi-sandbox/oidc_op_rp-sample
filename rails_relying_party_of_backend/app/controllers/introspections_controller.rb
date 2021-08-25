class IntrospectionsController < ApplicationController
  def index
  end

  def callback
    auth_hash = request.env['omniauth.auth']
    access_token = auth_hash['credentials']['token']

    puts '================> CORRECT access_token'
    # Authorization Serverから受け取った access_token を使って、Resource Serverへリクエスト
    fetch_resource_server(access_token)

    # 不正な access_token を使って、Resource Serverへリクエスト
    puts '================> INCORRECT access_token'
    incorrect_access_token = "#{access_token}_bad"
    fetch_resource_server(incorrect_access_token)

    # 有効期限切れの access_token を使って、Resource Serverへリクエスト
    # puts '================> EXPIRED access_token'
    # sleep 70
    # fetch_resource_server(access_token)

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

  def revoke_tokens(access_token)
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
end
