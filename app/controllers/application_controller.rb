class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  around_filter :set_time_zone

  def set_time_zone(&block)
    timezone = current_user.try(:timezone) || 'UTC'
    Time.use_zone(timezone, &block)
  end

end
