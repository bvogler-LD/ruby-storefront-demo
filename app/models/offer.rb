class Offer < ApplicationRecord
  validates :subcategory_slug, :merchant, :title, :description, :discount_text, presence: true
  validates :position, presence: true, numericality: { only_integer: true, greater_than: 0 },
                       uniqueness: { scope: :subcategory_slug }

  scope :in_subcategory, ->(slug) { where(subcategory_slug: slug) }
  # The one ordering used everywhere, so both experiences show identical content.
  scope :ordered, -> { order(:position, :id) }
  scope :after_position, ->(position) { where("position > ?", position) }

  def self.final_position(slug)
    in_subcategory(slug).maximum(:position)
  end
end
