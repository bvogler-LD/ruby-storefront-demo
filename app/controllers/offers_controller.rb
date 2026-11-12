class OffersController < ApplicationController
  before_action :set_subcategory, only: %i[index batch]

  # GET /shop/:subcategory
  def index
    # Evaluate first: this is the exposure every later metric event relies on.
    @experience = OfferListExperience.resolve(shopper_context)
    mark_exposed!

    scope = Offer.in_subcategory(@subcategory.slug).ordered
    @total = scope.count
    @seen_ids = seen_offer_ids

    if @experience.pagination?
      @total_pages = [ (@total / page_size.to_f).ceil, 1 ].max
      @page = requested_page.clamp(1, @total_pages)
      @offers = scope.offset((@page - 1) * page_size).limit(page_size).to_a
    else
      @offers = scope.limit(page_size).to_a
      @has_more = @offers.size < @total
    end
  end

  # GET /shop/:subcategory/offers/batch?after=<position>
  def batch
    experience = OfferListExperience.resolve(shopper_context)
    mark_exposed!
    return render(json: { error: "not_available" }, status: :conflict) unless experience.infinite_scroll?

    after = Integer(params[:after].to_s, 10, exception: false)
    return render(json: { error: "invalid_after" }, status: :unprocessable_entity) if after.nil? || after.negative?

    scope = Offer.in_subcategory(@subcategory.slug).ordered.after_position(after)
    offers = scope.limit(page_size).to_a
    last_position = offers.last&.position || after

    render json: {
      html: render_to_string(partial: "offers/offer", collection: offers, formats: [ :html ],
                             locals: { seen_ids: seen_offer_ids }),
      next_after: last_position,
      has_more: Offer.in_subcategory(@subcategory.slug).after_position(last_position).exists?
    }
  end

  # GET /offers/:id
  def show
    @offer = Offer.find(params[:id])
    @subcategory = Subcategory.find(@offer.subcategory_slug)
  end

  # POST /offers/:id/click
  # The click is recorded here, on the server, before the browser navigates.
  def click
    offer = Offer.find(params[:id])

    if exposed?
      ExperimentEvents.new(shopper_context).click(position: offer.position)
    else
      # No flag evaluation for this context yet, so the click cannot be
      # attributed to a variation. Still take the shopper to the offer.
      Rails.logger.info("[experiment] click not tracked: no prior flag evaluation for this context")
    end

    # Always an internal, server-chosen destination: no open redirect.
    redirect_to offer_path(offer), status: :see_other
  end

  private

  def set_subcategory
    @subcategory = Subcategory.find(params[:subcategory]) or raise ActionController::RoutingError, "Not Found"
  end

  def requested_page
    Integer(params[:page].to_s, 10, exception: false) || 1
  end
end
