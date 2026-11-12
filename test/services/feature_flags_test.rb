require "test_helper"

class FeatureFlagsTest < ActiveSupport::TestCase
  def context = ShopperContext.for(user: nil, guest_uid: "guest-#{SecureRandom.uuid}")

  test "a missing or blank SDK key yields the fallback client and logs a warning" do
    log = StringIO.new
    [ nil, "", "   " ].each do |key|
      client = FeatureFlags.build_client(sdk_key: key, logger: Logger.new(log))
      assert_instance_of FeatureFlags::NullClient, client
      assert_equal "sdk_key_missing", client.status[:reason]
    end
    assert_match "LAUNCHDARKLY_SDK_KEY is not set", log.string
  end

  test "fallback client serves the default and drops events" do
    client = FeatureFlags::NullClient.new(reason: "sdk_key_missing")
    result = OfferListExperience.resolve(context, client: client)

    assert_equal "infinite_scroll", result.variation
    assert result.fallback?
    assert_equal false, client.track("offer_card_clicked", context.ld_context)
  end

  test "the SDK adapter reports a fallback when LaunchDarkly cannot supply a value" do
    # A real SDK client in offline mode: no network, every flag is unknown.
    offline = LaunchDarkly::LDClient.new("offline", LaunchDarkly::Config.new(offline: true, logger: Logger.new(nil)))
    client = FeatureFlags::SdkClient.new(sdk_key: "offline", logger: Logger.new(nil), ld_client: offline)

    evaluation = client.evaluate("shop-offer-list-experience", context.ld_context, "infinite_scroll")
    assert_equal "infinite_scroll", evaluation.value
    assert evaluation.fallback?
    assert client.track("offer_card_clicked", context.ld_context, { position: 1 })
  ensure
    offline&.close
  end

  test "status never includes the SDK key" do
    offline = LaunchDarkly::LDClient.new("sdk-secret-value", LaunchDarkly::Config.new(offline: true, logger: Logger.new(nil)))
    client = FeatureFlags::SdkClient.new(sdk_key: "sdk-secret-value", logger: Logger.new(nil), ld_client: offline)
    assert_no_match(/sdk-secret-value/, client.status.to_s)
  ensure
    offline&.close
  end

  test "flag and event keys match the LaunchDarkly resources" do
    assert_equal "shop-offer-list-experience", OfferListExperience.flag_key
    assert_equal %w[pagination infinite_scroll], OfferListExperience::VARIATIONS
    assert_equal "offer_card_impression", ExperimentEvents::IMPRESSION
    assert_equal "offer_card_clicked", ExperimentEvents::CLICK
    assert_equal "offer_list_end_reached", ExperimentEvents::LIST_END_REACHED
  end
end
