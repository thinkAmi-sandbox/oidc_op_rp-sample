class IntrospectionsController < ApplicationController
  def index
  end

  def callback
    auth_hash = request.env['omniauth.auth']
    access_token = auth_hash['credentials']['token']

    puts '================> access_token'
    # introspection エンドポイントへリクエスト
    post_introspection(access_token)
    # userinfo エンドポイントへリクエスト
    fetch_userinfo(access_token)

    # access_tokenを不正な値にして、各エンドポイントへリクエスト
    # https://stackoverflow.com/questions/8580304/are-strings-in-ruby-mutable
    puts '================> BAD access_token'
    bad_token = access_token + 'bad'
    post_introspection(bad_token)
    fetch_userinfo(bad_token)

    # access_tokenを時間切れにしてリクエスト
    # revokeと同時に検証できないので注意
    # puts '================> EXPIRE access_token'
    # sleep 70
    # post_introspection(bad_token)
    # fetch_userinfo(bad_token)

    # access_tokenをrevoke後に、各エンドポイントへリクエスト
    puts '================> REVOKE access_token'
    revoke_tokens(access_token)
    post_introspection(bad_token)
    fetch_userinfo(bad_token)

    redirect_to root_path, notice: access_token
  end

  private

  def post_introspection(access_token)
    params = {
      client_id: ENV['CLIENT_ID_OF_INTROSPECTION'],
      client_secret: ENV['CLIENT_SECRET_OF_INTROSPECTION'],
      token: access_token
    }
    response = Faraday.post("#{ENV['OIDC_PROVIDER_HOST']}/oauth/introspect", params)
    response.tap do |r|
      puts '======> introspection'
      # puts r.headers # 必要に応じてレスポンスヘッダを確認
      # puts '---------------------'
      puts "STATUS: #{r.status}"
      puts "BODY  : #{r.body}"
      puts '<====== introspection'
    end
  end

  def fetch_userinfo(access_token)
    headers = {
      Authorization: "Bearer #{access_token}"
    }
    response = Faraday.get("#{ENV['OIDC_PROVIDER_HOST']}/oauth/userinfo",
                           {},
                           headers)

    response.tap do |r|
      puts '======> userinfo'
      # https://rubydoc.info/gems/httpclient/HTTP/Message/Headers
      # puts r.header.all # 必要に応じてレスポンスヘッダを確認
      # puts '----------------'
      puts "STATUS: #{r.status}"
      puts "BODY  : #{r.body}"
      puts '<====== userinfo'
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
      puts '======> introspection'
      # puts r.header.all # 必要に応じてレスポンスヘッダを確認
      # puts '----------------'
      puts "STATUS: #{r.status}"
      puts "BODY  : #{r.body}"
      puts '<====== introspection'
    end
  end
end
