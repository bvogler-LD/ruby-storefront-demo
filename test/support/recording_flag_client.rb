# Test double for the FeatureFlags client boundary only. It stands in for the
# LaunchDarkly service (bucketing + event intake) and records every call with
# the real LaunchDarkly::LDContext the app built, so identity and correlation
# behaviour is asserted against real contexts.
class RecordingFlagClient
  Evaluated = Struct.new(:flag_key, :context)
  Tracked = Struct.new(:event_key, :context, :data)

  attr_reader :evaluations, :events

  # assignment: a variation String for everyone, or a callable taking the
  # LDContext and returning the variation (stands in for LaunchDarkly bucketing).
  def initialize(assignment)
    @assignment = assignment
    @evaluations = []
    @events = []
  end

  def evaluate(flag_key, context, _default)
    @evaluations << Evaluated.new(flag_key, context)
    value = @assignment.respond_to?(:call) ? @assignment.call(context) : @assignment
    FeatureFlags::Evaluation.new(value: value, fallback: false, reason: "fallthrough")
  end

  def track(event_key, context, data = nil)
    @events << Tracked.new(event_key, context, data)
    true
  end

  def events_named(key) = events.select { |event| event.event_key == key }

  def status = { mode: "launchdarkly", configured: true, initialized: true, reason: "connected" }
  def flush; end
  def close; end
end
