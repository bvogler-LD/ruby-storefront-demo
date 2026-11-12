module FeatureFlags
  # Wraps one LaunchDarkly::LDClient. The SDK client is thread-safe and is
  # created once per process (see config/initializers/launchdarkly.rb).
  class SdkClient
    INIT_TIMEOUT_SECONDS = 5

    def initialize(sdk_key:, logger:, ld_client: nil)
      @logger = logger
      config = LaunchDarkly::Config.new(logger: logger)
      @ld = ld_client || LaunchDarkly::LDClient.new(sdk_key, config, INIT_TIMEOUT_SECONDS)
      unless @ld.initialized?
        logger&.warn("[feature_flags] LaunchDarkly did not initialize within #{INIT_TIMEOUT_SECONDS}s. " \
                     "Serving coded defaults until it connects.")
      end
    end

    def evaluate(flag_key, context, default)
      detail = @ld.variation_detail(flag_key, context, default)
      reason = detail.reason || {}
      errored = reason[:kind] == "ERROR"
      Evaluation.new(
        value: detail.value,
        fallback: errored,
        reason: errored ? "sdk_#{reason[:errorKind].to_s.downcase}" : reason[:kind].to_s.downcase
      )
    rescue StandardError => e
      @logger&.error("[feature_flags] evaluation of #{flag_key} failed (#{e.class}); serving default")
      Evaluation.new(value: default, fallback: true, reason: "sdk_exception")
    end

    def track(event_key, context, data = nil)
      @ld.track(event_key, context, data)
      true
    rescue StandardError => e
      @logger&.error("[feature_flags] track #{event_key} failed (#{e.class})")
      false
    end

    def status
      initialized = @ld.initialized?
      {
        mode: initialized ? "launchdarkly" : "fallback",
        configured: true,
        initialized: initialized,
        reason: initialized ? "connected" : "sdk_not_initialized"
      }
    end

    # Call in each forked worker (Puma cluster mode, Spring, ...).
    def postfork = @ld.postfork
    def flush = @ld.flush
    def close = @ld.close
  end
end
