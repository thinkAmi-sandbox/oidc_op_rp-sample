class ApplicationController < ActionController::Base
  helper_method :current_user

  private

  def current_user
    # セッションのユーザーIDに紐づくOpUserが存在しない場合は、ログインしていないとみなす
    @current_user ||= OpUser.find_by(id: session[:user_id]) if session[:user_id]
  end
end
