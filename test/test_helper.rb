ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "support/recording_flag_client"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)

    SLUG = Subcategory.default.slug

    setup { @original_flag_client = FeatureFlags.client }
    teardown { FeatureFlags.client = @original_flag_client }

    def seed_shop(offer_count: 60)
      User.create!(public_id: User::DEMO_PUBLIC_ID, display_name: "Demo Shopper")
      offer_count.times do |index|
        Offer.create!(subcategory_slug: SLUG, position: index + 1, merchant: "Merchant #{index + 1}",
                      title: "Offer #{index + 1}", description: "Description #{index + 1}",
                      discount_text: "10% off", hue: index)
      end
    end

    def use_flag_client(assignment)
      FeatureFlags.client = RecordingFlagClient.new(assignment)
    end
  end
end

class ActionDispatch::IntegrationTest
  def list_path(**params) = shop_subcategory_path(SLUG, **params)

  def rendered_positions
    css_select("[data-offer-card]").map { |card| card["data-position"].to_i }
  end

  def rendered_experience
    css_select("[data-offer-list]").first["data-experience"]
  end

  def offer_at(position) = Offer.find_by!(subcategory_slug: SLUG, position: position)

  def post_impressions(*positions, **extra)
    ids = positions.flatten.map { |position| offer_at(position).id }
    post events_impressions_path, params: { offer_ids: ids, **extra }, as: :json
  end
end
