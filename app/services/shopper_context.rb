# The only place that turns an application identity into a LaunchDarkly context.
#
# Flag evaluation and every metric event go through here, so they always use
# the same context kind and key for a given identity.
#
# Identity mapping (demo):
#   signed in  -> kind "user", key = User#public_id (stable application ID)
#   anonymous  -> kind "user", key = guest UID from an HTTP-only signed cookie,
#                 marked anonymous
#
# Both use kind "user" so the experiment has one randomization unit. Signing in
# switches to the signed-in key; identities are deliberately not merged.
#
# To adapt this for a real storefront: pass the application-provided anonymous UID as
# `guest_uid` and the signed-in visitor ID as the user's stable ID. Nothing
# else in the app needs to change. No name, email, phone, or other personal
# data is ever added to the context.
class ShopperContext
  KIND = "user".freeze

  attr_reader :ld_context

  def self.for(user:, guest_uid:)
    if user
      new(LaunchDarkly::LDContext.create({ key: user.public_id, kind: KIND }))
    else
      new(LaunchDarkly::LDContext.create({ key: guest_uid, kind: KIND, anonymous: true }))
    end
  end

  def initialize(ld_context)
    raise ArgumentError, "invalid shopper context: #{ld_context.error}" unless ld_context.valid?

    @ld_context = ld_context
  end

  def kind = ld_context.kind
  def key = ld_context.key
  def anonymous? = ld_context.get_value(:anonymous) == true

  # Opaque, non-reversible identifier for this context. Safe to keep in the
  # session or show in the developer panel; it is not sent to LaunchDarkly.
  def fingerprint
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, "#{kind}:#{key}")[0, 12]
  end

  # Developer-facing representation that never shows the full key.
  def redacted_key
    "#{key[0, 8]}…(#{key.length} chars, fingerprint #{fingerprint})"
  end
end
