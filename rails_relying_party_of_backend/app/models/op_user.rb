class OpUser < ApplicationRecord
  def self.find_or_create_from_auth_hash!(auth_hash)
    # auth_hash の中身
    # {
    #   "provider"=>"my_op",
    #   "uid"=>"1",
    #   "info"=>#<OmniAuth::AuthHash::InfoHash email="foo@example.com">,
    #   "credentials"=>#<OmniAuth::AuthHash
    #     expires=true
    #     expires_at=1628605105
    #     token="ACCESS_TOKEN">,
    #   "extra"=>#<OmniAuth::AuthHash
    #     id_token="HEADER.PAYLOAD.SIGNATURE"
    #     id_token_payload=#<Hashie::Array [
    #       #<OmniAuth::AuthHash
    #         aud="einUOs09X1VB8N9H_ZBo7iVVCRc2Qzc6eRUyiWQQHJU"
    #         exp=1628598025
    #         iat=1628597905
    #         iss="http://localhost:3780"
    #         sub="1">,
    #       #<OmniAuth::AuthHash
    #         alg="RS256"
    #         kid="Aa28UkVlSquSf4rtBSwDX0XnNda8et8y2OoUZV3EBg0"
    #         typ="JWT">
    #     ]>
    #     raw_info=#<OmniAuth::AuthHash
    #       email="foo@example.com"
    #       sub="1"
    # >>}
    provider = auth_hash[:provider]
    uid = auth_hash[:uid]
    email = auth_hash[:info][:email]

    OpUser.find_or_create_by!(provider: provider, uid: uid) do |op_user|
      op_user.email = email
    end
  end
end
