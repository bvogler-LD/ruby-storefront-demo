module FeatureFlags
  # Used when LaunchDarkly is not configured or unavailable. Always serves the
  # coded default and drops events, so the app stays usable.
  class NullClient
    def initialize(reason:, logger: nil)
      @reason = reason
      @logger = logger
    end

    def evaluate(_flag_key, _context, default)
      Evaluation.new(value: default, fallback: true, reason: @reason)
    end

    def track(event_key, _context, _data = nil)
      @logger&.debug("[feature_flags] fallback mode: dropped event #{event_key}")
      false
    end

    def status
      { mode: "fallback", configured: false, initialized: false, reason: @reason }
    end

    def postfork; end
    def flush; end
    def close; end
  end
end
