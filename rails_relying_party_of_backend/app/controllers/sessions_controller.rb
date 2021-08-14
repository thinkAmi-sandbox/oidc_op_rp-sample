class SessionsController < ApplicationController
  # ログイン情報しかセッションに入れていないため、セッション情報の移し替えは不要
  before_action :reset_session

  def create
    op_user = OpUser.find_or_create_from_auth_hash!(request.env['omniauth.auth'])
    session[:user_id] = op_user.id
    redirect_to root_path, notice: 'ログインしました'
  end

  def destroy
    # 今のところ、OPのセッションはそのまま残る
    redirect_to root_path, notice: 'ログアウトしました'
  end
end
