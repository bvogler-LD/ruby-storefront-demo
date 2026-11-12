# Resolves which offer-list experience a shopper gets.
#
# The value always comes from a LaunchDarkly evaluation for the shopper's
# context. The app never assigns a variation itself; when LaunchDarkly cannot
# supply one it serves the fixed default below.
class OfferListExperience
  PAGINATION = "pagination".freeze           # control
  INFINITE_SCROLL = "infinite_scroll".freeze # treatment
  VARIATIONS = [ PAGINATION, INFINITE_SCROLL ].freeze

  # Served when LaunchDarkly is not configured, unreachable, or returns an
  # unexpected value. Infinite scroll is the storefront's current experience.
  DEFAULT = INFINITE_SCROLL

  Result = Data.define(:variation, :fallback, :reason) do
    def pagination? = variation == PAGINATION
    def infinite_scroll? = variation == INFINITE_SCROLL
    def fallback? = fallback

    def label = pagination? ? "Pagination" : "Infinite scroll"
  end

  def self.flag_key = Rails.configuration.x.launchdarkly.flag_key

  def self.resolve(shopper_context, client: FeatureFlags.client)
    evaluation = client.evaluate(flag_key, shopper_context.ld_context, DEFAULT)

    if VARIATIONS.include?(evaluation.value)
      Result.new(variation: evaluation.value, fallback: evaluation.fallback?, reason: evaluation.reason)
    else
      Rails.logger.warn("[feature_flags] #{flag_key} returned an unexpected value; serving #{DEFAULT}")
      Result.new(variation: DEFAULT, fallback: true, reason: "unexpected_value")
    end
  end
end
