# DEMO ONLY. Signs in as the single seeded demo user with one click and no
# password. This exists to exercise the anonymous -> signed-in context switch;
# it is not authentication and must not be used as a basis for real sign-in.
class DemoSessionsController < ApplicationController
  def create
    user = User.demo
    return redirect_to(root_path, alert: "Demo user is missing. Run bin/rails db:seed.") unless user

    # New session: per-context experiment bookkeeping starts fresh. The guest
    # cookie is left alone, so signing out returns to the same guest context.
    reset_session
    session[:user_id] = user.id
    redirect_to shop_subcategory_path(Subcategory.default.slug),
                notice: "Signed in as #{user.display_name} (demo). Your list style now follows your account."
  end

  def destroy
    reset_session
    redirect_to shop_subcategory_path(Subcategory.default.slug),
                notice: "Signed out. You are browsing as a guest again."
  end
end
