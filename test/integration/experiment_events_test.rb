require "test_helper"

class ExperimentEventsTest < ActionDispatch::IntegrationTest
  setup do
    seed_shop
    @client = use_flag_client("pagination")
  end

  def evaluation_context = @client.evaluations.last.context

  def assert_same_context(expected, actual)
    assert_equal [ expected.kind, expected.key ], [ actual.kind, actual.key ]
    assert_equal expected.fully_qualified_key, actual.fully_qualified_key
  end

  test "impressions are tracked with the context used for flag evaluation" do
    get list_path
    post_impressions 3, 1
    assert_response :success
    assert_equal 2, response.parsed_body["accepted"]

    events = @client.events_named("offer_card_impression")
    assert_equal [ 3, 1 ], events.map { |event| event.data[:position] }
    events.each do |event|
      assert_same_context evaluation_context, event.context
      assert_equal [ :position ], event.data.keys, "only the ordinal position is sent"
    end
  end

  test "the flag is evaluated before any metric event is sent" do
    get list_path
    post_impressions 1
    post click_offer_path(offer_at(1))

    assert_operator @client.evaluations.size, :>=, 1
    assert_equal 2, @client.events.size
  end

  test "repeat impressions for the same offer are not tracked again" do
    get list_path
    post_impressions 1, 2
    post_impressions 2, 3
    assert_equal({ "accepted" => 1, "duplicates" => 1 }, response.parsed_body.slice("accepted", "duplicates"))
    post_impressions 1, 2, 3
    assert_equal 0, response.parsed_body["accepted"]

    assert_equal [ 1, 2, 3 ], @client.events_named("offer_card_impression").map { |e| e.data[:position] }

    get list_path
    assert_select "[data-offer-card][data-seen]", 3
  end

  test "duplicate ids inside one request count once" do
    get list_path
    id = offer_at(5).id
    post events_impressions_path, params: { offer_ids: [ id, id, id.to_s ] }, as: :json
    assert_equal 1, @client.events.size
  end

  test "clicks are recorded server-side before redirecting to the offer" do
    get list_path
    offer = offer_at(7)
    post click_offer_path(offer)

    assert_redirected_to offer_path(offer)
    event = @client.events_named("offer_card_clicked").sole
    assert_same_context evaluation_context, event.context
    assert_equal({ position: 7 }, event.data)
  end

  test "click redirect ignores any client-supplied destination" do
    get list_path
    offer = offer_at(7)
    post click_offer_path(offer), params: { redirect_to: "https://evil.example", url: "//evil.example" }
    assert_redirected_to offer_path(offer)
  end

  test "end of list fires once, only when the final offer is seen" do
    get list_path(page: 3)
    post_impressions 59
    assert_empty @client.events_named("offer_list_end_reached")

    post_impressions 60
    assert response.parsed_body["end_reached"]
    post_impressions 60, 58

    event = @client.events_named("offer_list_end_reached").sole
    assert_same_context evaluation_context, event.context
    assert_equal({ position: 60 }, event.data)
  end

  test "seeing the last card of page one is not the end of the list" do
    get list_path
    post_impressions (1..24).to_a
    assert_empty @client.events_named("offer_list_end_reached")
  end

  test "end of list uses the same rule in infinite scroll" do
    @client = use_flag_client("infinite_scroll")
    get list_path
    post_impressions (1..24).to_a
    assert_empty @client.events_named("offer_list_end_reached")
    post_impressions 60
    assert_equal 1, @client.events_named("offer_list_end_reached").size
  end

  test "client-supplied identity and event names are ignored" do
    get list_path
    post events_impressions_path, as: :json, params: {
      offer_ids: [ offer_at(1).id ], context_key: "attacker", context: { kind: "user", key: "attacker" },
      event: "purchase", event_key: "purchase", position: 999
    }
    assert_response :success

    event = @client.events.sole
    assert_equal "offer_card_impression", event.event_key
    assert_same_context evaluation_context, event.context
    assert_equal({ position: 1 }, event.data)
  end

  test "malformed impression payloads are rejected and nothing is tracked" do
    get list_path
    valid = offer_at(1).id
    [
      {},
      { offer_ids: "1" },
      { offer_ids: [] },
      { offer_ids: [ "abc" ] },
      { offer_ids: [ -1 ] },
      { offer_ids: [ 0 ] },
      { offer_ids: [ 1.5 ] },
      { offer_ids: [ { id: valid } ] },
      { offer_ids: [ valid, 999_999 ] },
      { offer_ids: (1..51).to_a }
    ].each do |payload|
      post events_impressions_path, params: payload, as: :json
      assert_response :unprocessable_entity, "expected rejection of #{payload.inspect}"
    end
    assert_empty @client.events
  end

  test "events without a prior flag evaluation are rejected" do
    post_impressions 1
    assert_response :conflict

    post click_offer_path(offer_at(1))
    assert_redirected_to offer_path(offer_at(1))
    assert_empty @client.events
  end

  test "requests without a CSRF token are rejected" do
    get list_path
    ActionController::Base.allow_forgery_protection = true

    post_impressions 1
    assert_response :unprocessable_entity
    post click_offer_path(offer_at(1))
    assert_response :unprocessable_entity
    assert_empty @client.events

    token = css_select("meta[name=csrf-token]").first&.[]("content")
    get list_path
    token = css_select("meta[name=csrf-token]").first["content"]
    post events_impressions_path, params: { offer_ids: [ offer_at(1).id ] }, as: :json,
                                  headers: { "X-CSRF-Token" => token }
    assert_response :success
    assert_equal 1, @client.events.size
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  test "impression submissions are rate limited per shopper" do
    get list_path
    60.times { post_impressions 1 }
    assert_response :success
    post_impressions 2
    assert_response :too_many_requests
    assert_equal 1, @client.events.size
  end
end
