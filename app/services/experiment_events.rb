# The fixed set of metric events this app sends to LaunchDarkly. Event keys are
# constants: nothing from the browser can choose an event name or a context.
class ExperimentEvents
  IMPRESSION = "offer_card_impression".freeze
  CLICK = "offer_card_clicked".freeze
  LIST_END_REACHED = "offer_list_end_reached".freeze

  def initialize(shopper_context, client: FeatureFlags.client)
    @context = shopper_context.ld_context
    @client = client
  end

  # One accepted visible card = one event. `position` is the card's 1-based
  # ordinal in the list; it is the only event data sent.
  def impression(position:) = @client.track(IMPRESSION, @context, { position: position })

  def click(position:) = @client.track(CLICK, @context, { position: position })

  def list_end_reached(position:) = @client.track(LIST_END_REACHED, @context, { position: position })
end
