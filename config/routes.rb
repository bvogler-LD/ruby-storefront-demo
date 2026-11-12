Rails.application.routes.draw do
  root "shop#index"

  # Offer-results page for one Shop subcategory: the experiment surface.
  get "shop/:subcategory", to: "offers#index", as: :shop_subcategory
  # Next batch of cards for the infinite-scroll experience.
  get "shop/:subcategory/offers/batch", to: "offers#batch", as: :shop_offer_batch

  resources :offers, only: :show do
    # Records the click server-side, then redirects to the offer.
    post :click, on: :member
  end

  namespace :events do
    resources :impressions, only: :create
  end

  # Demo-only sign-in. Not real authentication.
  resource :demo_session, only: %i[create destroy]

  # Local readiness diagnostics (no secrets).
  get "status", to: "status#show"
  get "up", to: "rails/health#show", as: :rails_health_check
end
