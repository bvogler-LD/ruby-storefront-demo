# Local demo readiness page. Shows configuration state only: never keys,
# tokens, or shopper identifiers.
class StatusController < ApplicationController
  def show
    shop = Rails.configuration.x.shop
    @status = {
      "LaunchDarkly" => FeatureFlags.client.status,
      "Flag" => {
        key: OfferListExperience.flag_key,
        variations: OfferListExperience::VARIATIONS,
        fallback_variation: OfferListExperience::DEFAULT
      },
      "Events" => [ ExperimentEvents::IMPRESSION, ExperimentEvents::CLICK, ExperimentEvents::LIST_END_REACHED ],
      "Shop" => {
        page_size: shop.page_size,
        impression_visible_ratio: shop.impression_visible_ratio,
        impression_dwell_ms: shop.impression_dwell_ms
      },
      "Data" => database_status,
      "App" => { rails_env: Rails.env, ruby: RUBY_VERSION, rails: Rails.version }
    }

    respond_to do |format|
      format.html
      format.json { render json: @status }
    end
  end

  private

  def database_status
    { connected: true, offers: Offer.count, demo_user_seeded: User.demo.present? }
  rescue ActiveRecord::ActiveRecordError => e
    { connected: false, error: e.class.name }
  end
end
