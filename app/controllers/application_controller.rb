class ApplicationController < ActionController::Base
  include CurrentShopper

  # CSRF protection is on by default for every non-GET request.
  protect_from_forgery with: :exception

  helper_method :developer_panel?, :page_size

  private

  def developer_panel? = Rails.configuration.x.show_developer_panel

  def page_size = Rails.configuration.x.shop.page_size
end
