# Shop landing page. Deliberately not part of the experiment.
class ShopController < ApplicationController
  def index
    @subcategories = Subcategory.all
  end
end
