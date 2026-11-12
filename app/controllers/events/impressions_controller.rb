module Events
  # Receives "these cards became visible" reports from the browser.
  #
  # Trust model: the browser only reports offer IDs. The event name, the
  # LaunchDarkly context, and each card's position all come from the server.
  class ImpressionsController < ApplicationController
    MAX_BATCH = 50
    MAX_TRACKED_PER_SESSION = 500
    RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new

    # Per-context throttle (falls back to nothing shared between shoppers).
    rate_limit to: 60, within: 1.minute,
               by: -> { shopper_context.fingerprint },
               with: -> { render json: { error: "rate_limited" }, status: :too_many_requests },
               store: RATE_LIMIT_STORE

    # POST /events/impressions  { "offer_ids": [1, 2, 3] }
    def create
      ids = validated_offer_ids
      return render(json: { error: "invalid_offer_ids" }, status: :unprocessable_entity) unless ids

      # Events are only meaningful after the flag was evaluated for this context.
      return render(json: { error: "no_exposure" }, status: :conflict) unless exposed?

      offers = Offer.where(id: ids).index_by(&:id)
      return render(json: { error: "unknown_offer" }, status: :unprocessable_entity) unless offers.size == ids.size

      state = impression_state
      seen = state["ids"]
      new_ids = ids - seen
      new_ids = new_ids.first([ MAX_TRACKED_PER_SESSION - seen.size, 0 ].max)

      events = ExperimentEvents.new(shopper_context)
      end_reached_now = false

      new_ids.each do |id|
        offer = offers.fetch(id)
        events.impression(position: offer.position)

        # End of list = the final available offer was actually seen. The same
        # rule for both experiences; sent once per context per session.
        next if state["end"] || offer.position != Offer.final_position(offer.subcategory_slug)

        events.list_end_reached(position: offer.position)
        state["end"] = true
        end_reached_now = true
      end

      state["ids"] = seen + new_ids
      save_impression_state(state)

      render json: {
        accepted: new_ids.size,
        duplicates: ids.size - new_ids.size,
        end_reached: end_reached_now,
        session_total: state["ids"].size
      }
    end

    private

    # Returns a de-duplicated array of positive integers, or nil if the
    # payload is not exactly that.
    def validated_offer_ids
      raw = params[:offer_ids]
      return nil unless raw.is_a?(Array) && raw.size.between?(1, MAX_BATCH)

      ids = raw.map do |value|
        case value
        when Integer then value
        when String then value.match?(/\A[1-9]\d{0,9}\z/) ? value.to_i : nil
        end
      end
      return nil if ids.any? { |id| id.nil? || id <= 0 }

      ids.uniq
    end
  end
end
