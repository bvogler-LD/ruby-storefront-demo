require "test_helper"

class ShopperIdentityTest < ActionDispatch::IntegrationTest
  setup do
    seed_shop
    # Stand-in for LaunchDarkly bucketing: guests land in control, the demo
    # user in treatment, so the switch on sign-in is observable.
    @client = use_flag_client(->(context) { context.key == User::DEMO_PUBLIC_ID ? "infinite_scroll" : "pagination" })
  end

  test "an anonymous shopper keeps one stable guest context across requests" do
    3.times { get list_path }
    contexts = @client.evaluations.map(&:context)

    assert_equal 1, contexts.map(&:key).uniq.size
    assert_match(/\Aguest-[0-9a-f-]{36}\z/, contexts.first.key)
    assert_equal "user", contexts.first.kind
    assert_equal true, contexts.first.get_value(:anonymous)
  end

  test "the guest id lives in an http-only cookie" do
    get list_path
    set_cookie = Array(response.headers["Set-Cookie"]).join("\n")
    guest_cookie = set_cookie.lines.find { |line| line.start_with?("guest_uid=") }
    assert guest_cookie, "expected a guest_uid cookie"
    assert_match(/httponly/i, guest_cookie)
    assert_no_match(/#{@client.evaluations.last.context.key}/, guest_cookie, "cookie value must not be the raw id")
  end

  test "different browsers get different guest contexts" do
    get list_path
    first_key = @client.evaluations.last.context.key

    open_session { |other| other.get list_path }
    refute_equal first_key, @client.evaluations.last.context.key
  end

  test "a signed-in shopper uses the app user's stable id and minimal attributes" do
    post demo_session_path
    get list_path
    context = @client.evaluations.last.context

    assert_equal User::DEMO_PUBLIC_ID, context.key
    assert_equal "user", context.kind
    assert_not context.get_value(:anonymous)
    assert_equal %i[key kind], context.to_h.keys.sort, "no extra attributes (name, email, ...) are sent"
  end

  test "signing in switches to the signed-in user's context and assignment" do
    get list_path
    guest_key = @client.evaluations.last.context.key
    assert_equal "pagination", rendered_experience
    post_impressions 1
    post click_offer_path(offer_at(2))

    post demo_session_path
    follow_redirect!
    assert_equal "infinite_scroll", rendered_experience, "signed-in user gets their own assignment"
    assert_match "Signed in as Demo Shopper", response.body
    post_impressions 1
    post click_offer_path(offer_at(2))

    before, after = @client.events.partition { |event| event.context.key == guest_key }
    assert_equal %w[offer_card_impression offer_card_clicked], before.map(&:event_key)
    assert_equal %w[offer_card_impression offer_card_clicked], after.map(&:event_key)
    assert(after.all? { |event| event.context.key == User::DEMO_PUBLIC_ID })
    assert(before.all? { |event| event.context.get_value(:anonymous) == true })

    delete demo_session_path
    follow_redirect!
    assert_equal guest_key, @client.evaluations.last.context.key, "signing out returns to the same guest"
    assert_equal "pagination", rendered_experience
  end

  test "events are not accepted for the signed-in context until the flag is evaluated for it" do
    get list_path
    post demo_session_path # new context, no evaluation yet

    post_impressions 1
    assert_response :conflict
    assert_empty @client.events
  end
end
