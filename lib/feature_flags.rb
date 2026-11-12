# Small adapter boundary around the LaunchDarkly server-side SDK.
#
# The rest of the app talks to `FeatureFlags.client`, which responds to:
#
#   evaluate(flag_key, context, default) -> FeatureFlags::Evaluation
#   track(event_key, context, data = nil) -> true/false
#   status                               -> Hash (never contains secrets)
#   close
#
# `context` is always a real LaunchDarkly::LDContext, including in tests, so
# identity/correlation behaviour is exercised rather than mocked away.
#
# These files live in lib/ (not autoloaded/reloaded) because exactly one client
# is created per process and must survive development code reloads.
require "ldclient-rb"

module FeatureFlags
  # value:    the variation served (or the default when falling back)
  # fallback: true when LaunchDarkly did not supply the value
  # reason:   short machine-readable explanation, safe to log
  Evaluation = Struct.new(:value, :fallback, :reason, keyword_init: true) do
    def fallback? = fallback
  end

  class << self
    attr_writer :client

    def client
      @client ||= NullClient.new(reason: "not_initialized")
    end

    # Builds the single process-wide client from the environment.
    def build_client(sdk_key:, logger:, force_null: false)
      if force_null
        NullClient.new(reason: "disabled_in_this_environment", logger: logger)
      elsif sdk_key.to_s.strip.empty?
        logger&.warn("[feature_flags] LAUNCHDARKLY_SDK_KEY is not set. Running in fallback mode: " \
                     "flags return their coded defaults and no events are sent.")
        NullClient.new(reason: "sdk_key_missing", logger: logger)
      else
        SdkClient.new(sdk_key: sdk_key.strip, logger: logger)
      end
    rescue StandardError => e
      # Never let flag infrastructure stop the storefront from booting.
      logger&.error("[feature_flags] LaunchDarkly client failed to start (#{e.class}). Using fallback mode.")
      NullClient.new(reason: "sdk_error", logger: logger)
    end
  end
end

require_relative "feature_flags/null_client"
require_relative "feature_flags/sdk_client"
