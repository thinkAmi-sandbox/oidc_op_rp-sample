class AddPostLogoutRedirectUrisToOauthApplications < ActiveRecord::Migration[7.1]
  def change
    add_column :oauth_applications, :post_logout_redirect_uris, :text
  end
end
