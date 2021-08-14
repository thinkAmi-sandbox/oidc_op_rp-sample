require 'omniauth-oauth2'

module OmniAuth
  module Strategies
    class MyOp < OmniAuth::Strategies::OAuth2
      # Give your strategy a name.
      option :name, 'my_op'

      # This is where you pass the options you would pass when
      # initializing your consumer from the OAuth gem.
      option :client_options, {
        site: "#{ENV['OIDC_PROVIDER_HOST']}/oauth/authorize"
      }

      # scope=openid としてリクエスト
      option :scope, 'openid'

      # PKCEを使うように設定
      option :pkce, true

      uid do
        raw_info['sub']
      end

      info do
        {
          email: raw_info['email']
        }
      end

      extra do
        # access_token.params に hash として id_token が入っている
        # (他に、token_type='Bearer', scope='openid', created_at=<timestamp> が入ってる)
        id_token = access_token['id_token']

        {
          raw_info: raw_info,
          id_token_payload: id_token_payload(id_token, raw_info['sub']),
          id_token: id_token
        }
      end

      def raw_info
        # raw_infoには、/userinfo エンドポイントから取得できる情報を入れる
        # 参考：userinfoエンドポイントのレスポンス
        #   {"sub"=>"1", "email"=>"foo@example.com"}
        @raw_info ||= access_token.get("#{ENV['oidc_provider_host']}/oauth/userinfo").parsed
      end

      def authorize_params
        # 認証リクエスト時のパラメータを追加するため、メソッドをオーバーライド
        super.tap do |params|
          # params[:prompt] = 'consent' # 必要に応じて追加
          params[:nonce] = generate_nonce
        end
      end

      private

      def generate_nonce
        session['omniauth.nonce'] = SecureRandom.urlsafe_base64
      end

      def nonce_from_session
        # nonceは再利用できないので、取り出したらsessionから消しておく
        session.delete('omniauth.nonce')
      end

      def id_token_payload(id_token, subject_from_userinfo)
        # decodeできない場合はエラーを送出する
        payload, _header = JWT.decode(
          id_token, # JWT
          nil, # key: 署名鍵を動的に探すのでnil https://github.com/jwt/ruby-jwt#finding-a-key
          true, # verify: IDトークンの検証を行う
          { # options
            algorithm: 'RS256', # 署名は公開鍵方式なので、RS256を指定
            iss: ENV['ISSUER_OF_MY_OP'],
            verify_iss: true,
            aud: ENV['CLIENT_ID_OF_MY_OP'],
            verify_aud: true,
            sub: subject_from_userinfo,
            verify_sub: true,
            verify_expiration: true,
            verify_not_before: true,
            verify_iat: true
          }
        ) do |jwt_header|
          # このブロックの中で、OPの公開鍵情報を取得
          # IDトークンのヘッダーのkidと等しい公開鍵情報を取得
          key = fetch_public_keys.find do |k|
            k['kid'] == jwt_header['kid']
          end

          # 等しいkidが見当たらない場合はエラー
          raise JWT::VerificationError if key.blank?

          # 公開鍵の作成
          # https://stackoverflow.com/a/57402656
          JWT::JWK::RSA.import(key).public_key
        end

        # nonceの確認
        verify_nonce!(payload)

        payload
      end

      def fetch_public_keys
        # Faradayはすでにインストールされている
        response = Faraday.get("#{ENV['OIDC_PROVIDER_HOST']}/oauth/discovery/keys")
        keys = JSON.parse(response.body)

        # たとえ公開鍵が1本だけでも、keysのvalueはArray
        puts keys # デバッグ用
        keys['keys']
      end

      def verify_nonce!(payload)
        # debug用
        nonce = nonce_from_session
        puts "session ===> #{nonce}"
        puts "payload ===> #{payload['nonce']}"
        return if payload['nonce'] && payload['nonce'] == nonce

        raise JWT::VerificationError
      end
    end
  end
end
