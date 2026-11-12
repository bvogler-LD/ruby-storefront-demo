# Demo storefront settings. Everything here is non-secret and overridable by
# environment variable (see .env.example).
Rails.application.configure do
  positive_int = ->(name, default) do
    value = Integer(ENV.fetch(name, default), exception: false)
    value && value.positive? ? value : default
  end

  ratio = Float(ENV.fetch("IMPRESSION_VISIBLE_RATIO", 0.5), exception: false)
  ratio = 0.5 unless ratio && ratio.positive? && ratio <= 1

  config.x.shop.page_size = positive_int.call("SHOP_PAGE_SIZE", 24)
  # Impression rule: at least this share of the card visible...
  config.x.shop.impression_visible_ratio = ratio
  # ...continuously for this long. Counted once per offer per shopper session.
  config.x.shop.impression_dwell_ms = positive_int.call("IMPRESSION_DWELL_MS", 1000)

  config.x.launchdarkly.flag_key = ENV.fetch("LAUNCHDARKLY_FLAG_KEY", "shop-offer-list-experience").strip

  # The redacted context panel is for local development only.
  config.x.show_developer_panel = Rails.env.development?
end
