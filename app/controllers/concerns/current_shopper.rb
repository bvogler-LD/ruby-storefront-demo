# Derives the shopper's identity, and from it the LaunchDarkly context, purely
# from server-managed state (session + signed HTTP-only cookie). Nothing the
# browser sends in a request body or query string can select a context.
module CurrentShopper
  extend ActiveSupport::Concern

  GUEST_COOKIE = :guest_uid

  included do
    helper_method :current_user, :signed_in?, :shopper_context, :impression_state_end?
  end

  private

  def current_user
    return @current_user if defined?(@current_user)

    @current_user = session[:user_id] && User.find_by(id: session[:user_id])
  end

  def signed_in? = current_user.present?

  # Same object for flag evaluation and every event within a request.
  def shopper_context
    @shopper_context ||= ShopperContext.for(user: current_user, guest_uid: current_user ? nil : guest_uid)
  end

  # Stable, random, pseudonymous ID for anonymous shoppers. Created once and
  # reused on every later request, including after signing out again.
  def guest_uid
    existing = cookies.signed[GUEST_COOKIE]
    return existing if existing.is_a?(String) && existing.match?(/\Aguest-[0-9a-f-]{36}\z/)

    uid = "guest-#{SecureRandom.uuid}"
    cookies.signed.permanent[GUEST_COOKIE] = {
      value: uid,
      httponly: true,
      same_site: :lax,
      secure: Rails.env.production?
    }
    uid
  end

  # --- experiment bookkeeping kept in the server-managed session -------------

  # Remember that the flag was evaluated for this exact context, so metric
  # events are only accepted after an evaluation for the same context.
  def mark_exposed!
    session[:exposure] = shopper_context.fingerprint
  end

  def exposed? = session[:exposure] == shopper_context.fingerprint

  # Offers this context has already had an impression recorded for.
  def impression_state
    state = session[:impressions]
    unless state.is_a?(Hash) && state["fp"] == shopper_context.fingerprint
      state = { "fp" => shopper_context.fingerprint, "ids" => [], "end" => false }
    end
    state
  end

  def save_impression_state(state)
    session[:impressions] = state
  end

  def seen_offer_ids = impression_state["ids"]

  def impression_state_end? = impression_state["end"] == true
end
