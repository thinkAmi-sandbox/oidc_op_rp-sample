# frozen_string_literal: true

Doorkeeper::OpenidConnect.configure do

  # =======> 変更開始
  issuer { 'my_op' }
  # issuer do |resource_owner, application|
  #   'issuer string'
  # end
  # <======= 変更終了

  # =======> 変更開始
  # https://stackoverflow.com/questions/13147277/rails-path-of-file
  signing_key File.read(Rails.root.join('jwtRS256.key'))
  # signing_key <<~KEY
  #   -----BEGIN RSA PRIVATE KEY-----
  #   ....
  #   -----END RSA PRIVATE KEY-----
  # KEY
  # <======= 変更終了

  subject_types_supported [:public]

  # =======> 変更開始
  resource_owner_from_access_token do |access_token|
    User.find_by(id: access_token.resource_owner_id)
  end
  # resource_owner_from_access_token do |access_token|
  #   # Example implementation:
  #   # User.find_by(id: access_token.resource_owner_id)
  # end
  # <======= 変更終了

  auth_time_from_resource_owner do |resource_owner|
    # Example implementation:
    # resource_owner.current_sign_in_at
  end

  # =======> 変更開始
  reauthenticate_resource_owner do |resource_owner, return_to|
    store_location_for resource_owner, return_to
    sign_out resource_owner
    redirect_to new_user_session_url
  end
  # reauthenticate_resource_owner do |resource_owner, return_to|
  #   # Example implementation:
  #   # store_location_for resource_owner, return_to
  #   # sign_out resource_owner
  #   # redirect_to new_user_session_url
  # end
  # <======= 変更終了

  # Depending on your configuration, a DoubleRenderError could be raised
  # if render/redirect_to is called at some point before this callback is executed.
  # To avoid the DoubleRenderError, you could add these two lines at the beginning
  #  of this callback: (Reference: https://github.com/rails/rails/issues/25106)
  #   self.response_body = nil
  #   @_response_body = nil
  select_account_for_resource_owner do |resource_owner, return_to|
    # Example implementation:
    # store_location_for resource_owner, return_to
    # redirect_to account_select_url
  end

  # =======> 変更開始
  subject do |resource_owner, _application|
    resource_owner.id
  end
  # subject do |resource_owner, application|
  #   # Example implementation:
  #   # resource_owner.id
  #
  #   # or if you need pairwise subject identifier, implement like below:
  #   # Digest::SHA256.hexdigest("#{resource_owner.id}#{URI.parse(application.redirect_uri).host}#{'your_secret_salt'}")
  # end
  # <======= 変更終了

  # Protocol to use when generating URIs for the discovery endpoint,
  # for example if you also use HTTPS in development
  # protocol do
  #   :https
  # end

  # Expiration time on or after which the ID Token MUST NOT be accepted for processing. (default 120 seconds).
  # expiration 600

  # =======> 変更開始
  claims do
    # normal_claimはclaimのalias
    normal_claim :email, scope: :openid do |resource_owner|
      resource_owner.email
    end
  end
  # Example claims:
  # claims do
  #   normal_claim :_foo_ do |resource_owner|
  #     resource_owner.foo
  #   end

  #   normal_claim :_bar_ do |resource_owner|
  #     resource_owner.bar
  #   end
  # end
  # <======= 変更終了
end
