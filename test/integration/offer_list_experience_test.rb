require "test_helper"

class OfferListExperienceTest < ActionDispatch::IntegrationTest
  setup { seed_shop }

  test "without LaunchDarkly configured the page falls back to infinite scroll" do
    assert_equal "fallback", FeatureFlags.client.status[:mode]

    get list_path
    assert_response :success
    assert_equal "infinite_scroll", rendered_experience
    assert_equal (1..24).to_a, rendered_positions
    assert_select "[data-scroll-sentinel]"
    assert_select "nav.pagination", false
  end

  test "status page reports fallback mode without secrets" do
    get status_path(format: :json)
    assert_response :success
    body = response.parsed_body
    assert_equal "fallback", body.dig("LaunchDarkly", "mode")
    assert_equal "infinite_scroll", body.dig("Flag", "fallback_variation")
    assert_no_match(/sdk-/, response.body)
  end

  test "an unexpected flag value is treated as fallback" do
    use_flag_client("carousel")
    get list_path
    assert_equal "infinite_scroll", rendered_experience
  end

  test "pagination variation renders exactly 24 cards per page with working links" do
    use_flag_client("pagination")

    get list_path
    assert_equal "pagination", rendered_experience
    assert_equal (1..24).to_a, rendered_positions
    assert_select "nav.pagination a[rel=next][href=?]", list_path(page: 2)
    assert_select "nav.pagination a[rel=prev]", false
    assert_select "[data-scroll-sentinel]", false

    get list_path(page: 2)
    assert_equal (25..48).to_a, rendered_positions
    assert_select "nav.pagination a[rel=prev][href=?]", list_path(page: 1)

    get list_path(page: 3)
    assert_equal (49..60).to_a, rendered_positions
    assert_select "nav.pagination a[rel=next]", false
  end

  test "pagination clamps out-of-range and invalid pages" do
    use_flag_client("pagination")

    get list_path(page: 99)
    assert_equal (49..60).to_a, rendered_positions

    get list_path(page: "abc")
    assert_equal (1..24).to_a, rendered_positions
  end

  test "page size is configurable" do
    use_flag_client("pagination")
    original = Rails.configuration.x.shop.page_size
    Rails.configuration.x.shop.page_size = 10
    get list_path(page: 6)
    assert_equal (51..60).to_a, rendered_positions
  ensure
    Rails.configuration.x.shop.page_size = original
  end

  test "infinite scroll serves 24 cards then further batches without duplicates" do
    use_flag_client("infinite_scroll")

    get list_path
    assert_equal "infinite_scroll", rendered_experience
    seen = rendered_positions
    assert_equal (1..24).to_a, seen
    assert_equal "true", css_select("[data-offer-list]").first["data-has-more"]

    after = 24
    loop do
      get shop_offer_batch_path(SLUG, after: after)
      assert_response :success
      batch = response.parsed_body
      positions = Nokogiri::HTML.fragment(batch["html"]).css("[data-offer-card]").map { |c| c["data-position"].to_i }
      assert_operator positions.size, :<=, 24
      assert_empty seen & positions, "batch repeated cards already shown"
      seen.concat(positions)
      after = batch["next_after"]
      break unless batch["has_more"]
    end

    assert_equal (1..60).to_a, seen
  end

  test "both experiences show the same offers in the same order" do
    use_flag_client("pagination")
    paginated = (1..3).flat_map { |page| get list_path(page: page); css_select("[data-offer-card]").map { |c| c["data-offer-id"] } }

    use_flag_client("infinite_scroll")
    get list_path
    scrolled = css_select("[data-offer-card]").map { |c| c["data-offer-id"] }
    [ 24, 48 ].each do |after|
      get shop_offer_batch_path(SLUG, after: after)
      scrolled.concat(Nokogiri::HTML.fragment(response.parsed_body["html"]).css("[data-offer-card]").map { |c| c["data-offer-id"] })
    end

    assert_equal paginated, scrolled
  end

  test "batch endpoint rejects bad input and is unavailable in pagination" do
    use_flag_client("infinite_scroll")
    get shop_offer_batch_path(SLUG, after: "-1")
    assert_response :unprocessable_entity
    get shop_offer_batch_path(SLUG, after: "1; drop table")
    assert_response :unprocessable_entity

    use_flag_client("pagination")
    get shop_offer_batch_path(SLUG, after: 24)
    assert_response :conflict
  end

  test "unknown subcategory is a 404" do
    get shop_subcategory_path("nope")
    assert_response :not_found
  end

  test "shoppers never see context details or the developer panel" do
    client = use_flag_client("pagination")
    get list_path
    key = client.evaluations.last.context.key
    assert_no_match(/#{Regexp.escape(key)}/, response.body)
    assert_select ".dev-panel", false
  end

  test "developer panel shows a redacted key only when enabled" do
    client = use_flag_client("pagination")
    Rails.configuration.x.show_developer_panel = true
    get list_path
    key = client.evaluations.last.context.key
    assert_select ".dev-panel"
    assert_no_match(/#{Regexp.escape(key)}/, response.body)
    assert_match "anonymous guest", response.body
  ensure
    Rails.configuration.x.show_developer_panel = false
  end
end
