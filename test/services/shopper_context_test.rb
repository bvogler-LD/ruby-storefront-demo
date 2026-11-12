require "test_helper"

class ShopperContextTest < ActiveSupport::TestCase
  test "guest context is an anonymous user-kind context keyed by the guest uid" do
    context = ShopperContext.for(user: nil, guest_uid: "guest-123")
    assert_equal [ "user", "guest-123", true ], [ context.kind, context.key, context.anonymous? ]
  end

  test "signed-in context is keyed by the user's public id and carries no personal data" do
    user = User.create!(public_id: "shopper-abc", display_name: "Private Name")
    context = ShopperContext.for(user: user, guest_uid: "guest-123")

    assert_equal [ "user", "shopper-abc", false ], [ context.kind, context.key, context.anonymous? ]
    assert_no_match(/Private Name/, context.ld_context.to_json)
  end

  test "redacted key and fingerprint do not reveal the key" do
    context = ShopperContext.for(user: nil, guest_uid: "guest-2f1c9a52-aaaa-bbbb-cccc-1234567890ab")
    assert_not_includes context.redacted_key, context.key
    assert_not_includes context.fingerprint, "guest"
    assert_equal context.fingerprint, ShopperContext.for(user: nil, guest_uid: context.key).fingerprint
  end

  test "an invalid identity is refused rather than sent" do
    assert_raises(ArgumentError) { ShopperContext.for(user: nil, guest_uid: "") }
  end
end
