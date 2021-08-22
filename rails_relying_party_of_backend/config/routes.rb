Rails.application.routes.draw do
  # ルート設定
  root to: 'home#index'

  # 下のOPからのコールバックURIにマッチする前にマッチしたいのでここで設定
  # introspection_rp のコールバック先
  get 'auth/introspection/callback', to: 'introspections#callback'
  get 'introspection', to: 'introspections#index'

  # OPからのコールバックURI
  get 'auth/:provider/callback', to: 'sessions#create'

  # 認証に失敗したときのルーティング
  get 'auth/failure', to: redirect('/')

  # ログアウト
  get 'logout', to: 'sessions#destroy'
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end
